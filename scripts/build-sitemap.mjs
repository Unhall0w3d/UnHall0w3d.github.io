import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const dist = path.join(root, "dist");
const siteOrigin = "https://nocthoughts.com";

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  }));
  return files.flat();
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

const urls = new Map();
const htmlFiles = (await walk(dist)).filter((file) => file.endsWith(".html"));

for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  if (/<meta\s+name="robots"\s+content="[^"]*\bnoindex\b/i.test(html)) continue;
  if (/<meta\s+http-equiv="refresh"/i.test(html)) continue;

  const canonical = html.match(/<link\s+rel="canonical"\s+href="([^"]+)"/i)?.[1];
  if (!canonical) continue;

  const parsed = new URL(canonical);
  if (parsed.origin !== siteOrigin) continue;

  const modified = html.match(/<meta\s+property="article:modified_time"\s+content="([^"]+)"/i)?.[1];
  const published = html.match(/<meta\s+property="article:published_time"\s+content="([^"]+)"/i)?.[1];
  urls.set(parsed.href, modified ?? published);
}

const entries = [...urls]
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([url, lastmod]) => [
    "  <url>",
    `    <loc>${escapeXml(url)}</loc>`,
    ...(lastmod ? [`    <lastmod>${escapeXml(lastmod)}</lastmod>`] : []),
    "  </url>"
  ].join("\n"))
  .join("\n");

const sitemap = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  entries,
  "</urlset>",
  ""
].join("\n");

const index = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  "  <sitemap>",
  `    <loc>${siteOrigin}/sitemap-0.xml</loc>`,
  "  </sitemap>",
  "</sitemapindex>",
  ""
].join("\n");

await Promise.all([
  writeFile(path.join(dist, "sitemap-0.xml"), sitemap),
  writeFile(path.join(dist, "sitemap-index.xml"), index)
]);

console.log(`Generated sitemap with ${urls.size} canonical, indexable URLs.`);
