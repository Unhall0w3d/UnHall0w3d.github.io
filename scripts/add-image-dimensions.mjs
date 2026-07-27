import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";

const root = process.cwd();
const contentRoot = path.join(root, "src/content");
const publicRoot = path.join(root, "public");

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map((entry) => {
    const target = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(target) : [target];
  }));
  return files.flat();
}

const files = (await walk(contentRoot)).filter((file) => /\.mdx?$/.test(file));
let updatedFiles = 0;
let updatedImages = 0;

for (const file of files) {
  const source = await readFile(file, "utf8");
  const imageTags = [...source.matchAll(/<img\b[^>]*>/gi)];
  let output = source;

  for (const match of imageTags.reverse()) {
    const tag = match[0];
    if (/\bwidth\s*=/.test(tag) && /\bheight\s*=/.test(tag)) continue;

    const src = tag.match(/\bsrc=(?:"([^"]+)"|'([^']+)')/i)?.slice(1).find(Boolean);
    if (!src?.startsWith("/") || src.startsWith("//")) continue;

    const imagePath = path.join(publicRoot, decodeURIComponent(src.split(/[?#]/)[0]).replace(/^\//, ""));
    let metadata;
    try {
      metadata = await sharp(imagePath).metadata();
    } catch {
      continue;
    }
    if (!metadata.width || !metadata.height) continue;

    const dimensions = ` width="${metadata.width}" height="${metadata.height}"`;
    const replacement = tag.replace(/\s*\/?>$/, (ending) => `${dimensions}${ending}`);
    output = `${output.slice(0, match.index)}${replacement}${output.slice(match.index + tag.length)}`;
    updatedImages += 1;
  }

  if (output !== source) {
    await writeFile(file, output);
    updatedFiles += 1;
  }
}

console.log(`Added intrinsic dimensions to ${updatedImages} images across ${updatedFiles} content files.`);
