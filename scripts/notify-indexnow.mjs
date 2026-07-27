import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const siteOrigin = "https://nocthoughts.com";
const siteHost = new URL(siteOrigin).host;
const endpoint = "https://api.indexnow.org/indexnow";
const publicRoot = path.join(process.cwd(), "public");

const [baseSha, headSha, ...options] = process.argv.slice(2);
const dryRun = options.includes("--dry-run");

if (!baseSha || !headSha) {
  throw new Error("Usage: node scripts/notify-indexnow.mjs <base-sha> <head-sha> [--dry-run]");
}

if (/^0+$/.test(baseSha)) {
  console.log("IndexNow skipped: no prior deployment commit was supplied.");
  process.exit(0);
}

const keyFiles = (await readdir(publicRoot))
  .filter((name) => /^[A-Za-z0-9-]{8,128}\.txt$/.test(name));

const validKeys = [];
for (const name of keyFiles) {
  const value = (await readFile(path.join(publicRoot, name), "utf8")).trim();
  if (`${value}.txt` === name) validKeys.push({ key: value, name });
}

if (validKeys.length !== 1) {
  throw new Error(`Expected exactly one valid IndexNow key file; found ${validKeys.length}.`);
}

const [{ key, name: keyFile }] = validKeys;
const { stdout } = await execFileAsync("git", [
  "diff",
  "--name-only",
  "--diff-filter=ACDMRT",
  baseSha,
  headSha
]);

const changedFiles = stdout.split("\n").map((file) => file.trim()).filter(Boolean);
const changedUrls = new Set();

function addUrl(pathname) {
  changedUrls.add(new URL(pathname, siteOrigin).href);
}

for (const file of changedFiles) {
  const post = file.match(/^src\/content\/posts\/(\d{4})-(\d{2})-(\d{2})-(.+)\.mdx?$/);
  if (post) {
    const [, year, month, day, slug] = post;
    addUrl(`/${year}/${month}/${day}/${slug}.html`);
    addUrl("/");
    addUrl("/posts.html");
    continue;
  }

  const standalonePages = new Map([
    ["src/content/pages/about.md", "/about.html"],
    ["src/content/pages/privacy-policy.md", "/privacypolicy.html"],
    ["src/pages/about.astro", "/about.html"],
    ["src/pages/privacypolicy.astro", "/privacypolicy.html"],
    ["src/pages/posts/index.astro", "/posts.html"],
    ["src/pages/categories/index.astro", "/categories.html"],
    ["src/pages/tags/index.astro", "/tags.html"]
  ]);

  if (standalonePages.has(file)) {
    addUrl(standalonePages.get(file));
    continue;
  }

  if (
    file === "src/pages/index.astro" ||
    file.startsWith("src/components/Operator") ||
    file.startsWith("src/components/Repository")
  ) {
    addUrl("/");
  }
}

const urlList = [...changedUrls].sort();
if (urlList.length === 0) {
  console.log("IndexNow skipped: this deployment did not add, update, or delete a public content URL.");
  process.exit(0);
}

const payload = {
  host: siteHost,
  key,
  keyLocation: `${siteOrigin}/${keyFile}`,
  urlList
};

if (dryRun) {
  console.log(`IndexNow dry run: ${urlList.length} changed URLs would be submitted.`);
  console.log(urlList.join("\n"));
  process.exit(0);
}

const response = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json; charset=utf-8" },
  body: JSON.stringify(payload),
  signal: AbortSignal.timeout(20_000)
});

if (response.status !== 200 && response.status !== 202) {
  const detail = (await response.text()).trim();
  throw new Error(`IndexNow returned HTTP ${response.status}${detail ? `: ${detail}` : ""}`);
}

console.log(`IndexNow accepted ${urlList.length} changed URLs with HTTP ${response.status}.`);
