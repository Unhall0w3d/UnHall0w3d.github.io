import { access, readdir, readFile } from "node:fs/promises";
import { constants } from "node:fs";
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

async function exists(target) {
  try {
    await access(target, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function resolvesToOutput(urlPath) {
  const decoded = decodeURIComponent(urlPath.split(/[?#]/)[0]);
  if (decoded === "/") return exists(path.join(dist, "index.html"));

  const relative = decoded.replace(/^\//, "");
  if (decoded.endsWith("/")) return exists(path.join(dist, relative, "index.html"));
  if (path.extname(relative)) return exists(path.join(dist, relative));

  return (await exists(path.join(dist, `${relative}.html`))) ||
    (await exists(path.join(dist, relative, "index.html")));
}

const files = await walk(dist);
const htmlFiles = files.filter((file) => file.endsWith(".html"));
const failures = new Set();

for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  const attributes = html.matchAll(/\b(?:href|src)=(?:"([^"]+)"|'([^']+)')/g);

  for (const match of attributes) {
    let target = match[1] ?? match[2];
    if (!target || target.startsWith("#") || /^(?:mailto:|tel:|data:|javascript:)/.test(target)) continue;

    if (/^https?:\/\//.test(target)) {
      if (!/^https?:\/\/(?:www\.)?nocthoughts\.com(?:[/:]|$)/i.test(target)) continue;
      const url = new URL(target);
      target = url.pathname;
    }

    if (!target.startsWith("/")) {
      const sourcePath = `/${path.relative(dist, file).replace(/index\.html$/, "")}`;
      target = new URL(target, `${siteOrigin}${sourcePath}`).pathname;
    }

    if (!(await resolvesToOutput(target))) {
      failures.add(`${path.relative(root, file)} -> ${target}`);
    }
  }
}

const legacySitemap = await readFile(path.join(root, "docs/rebuild/legacy-sitemap.xml"), "utf8");
const legacyUrls = [...legacySitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => new URL(match[1]).pathname);
for (const legacyUrl of legacyUrls) {
  if (!(await resolvesToOutput(legacyUrl))) failures.add(`legacy sitemap -> ${legacyUrl}`);
}

const postPages = files.filter((file) => /\/\d{4}\/\d{2}\/\d{2}\/[^/]+\.html$/.test(file));
if (postPages.length !== 52) failures.add(`expected 52 post pages; found ${postPages.length}`);

if (failures.size > 0) {
  console.error("Site validation failed:\n" + [...failures].sort().map((failure) => `- ${failure}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log(`Validated ${htmlFiles.length} HTML files, ${postPages.length} posts, ${legacyUrls.length} legacy URLs, and all local links/assets.`);
}
