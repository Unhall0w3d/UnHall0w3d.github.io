#!/usr/bin/env node
/**
 * Gate 2 Verification Suite:
 * 1. Confirms self-hosted @fontsource .woff2 assets exist in dist/_astro/ and zero external font/CSS/JS requests exist in dist/.
 * 2. Confirms astro-expressive-code dual-theme selectors and UI primitives (Badge, ValidationScope) render in dist/.
 * 3. Audits WCAG 2.1 AA (>= 4.5:1) contrast across primary text, secondary text, muted telemetry, badges, and buttons in all themes.
 */
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const DIST = path.join(ROOT, "dist");
const TOKENS_CSS = fs.readFileSync(path.join(ROOT, "src/styles/tokens.css"), "utf8");

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

function parseHex(hex) {
  const clean = hex.trim().replace(/^#/, "");
  const n = parseInt(clean, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function parseColor(raw) {
  const v = raw.trim();
  if (v.startsWith("#")) return [...parseHex(v), 1];
  const m = v.match(/^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([0-9.]+))?\s*\)$/i);
  if (!m) throw new Error(`Unsupported color token value: ${raw}`);
  return [Number(m[1]), Number(m[2]), Number(m[3]), m[4] === undefined ? 1 : Number(m[4])];
}

function composite(fgRgba, bgRgb) {
  const [r, g, b, a] = fgRgba;
  return [
    Math.round(r * a + bgRgb[0] * (1 - a)),
    Math.round(g * a + bgRgb[1] * (1 - a)),
    Math.round(b * a + bgRgb[2] * (1 - a))
  ];
}

function luminance([r, g, b]) {
  const lin = [r, g, b].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}

function contrastRatio(rgbA, rgbB) {
  const l1 = luminance(rgbA);
  const l2 = luminance(rgbB);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

// 1. Parse theme blocks from src/styles/tokens.css
const themeNames = ["aftertone", "paper", "polar", "cyberpunk", "moss-brass"];
const baseVars = {};
const themeVars = Object.fromEntries(themeNames.map((n) => [n, {}]));

const blockRegex = /([^{}]+)\{([^{}]+)\}/g;
for (const match of TOKENS_CSS.matchAll(blockRegex)) {
  const selector = match[1].trim();
  const body = match[2];
  const props = {};
  for (const propMatch of body.matchAll(/(--[a-z0-9-]+)\s*:\s*([^;]+);/gi)) {
    props[propMatch[1]] = propMatch[2].replace(/\/\*[\s\S]*?\*\//g, "").trim();
  }
  if (selector.includes(":root")) Object.assign(baseVars, props);
  for (const name of themeNames) {
    if (selector.includes(`[data-theme="${name}"]`)) {
      Object.assign(themeVars[name], props);
    }
  }
}

const failures = [];
const summaryRows = [];

for (const name of themeNames) {
  const vars = { ...baseVars, ...themeVars[name] };
  const canvas = parseColor(vars["--bg-canvas"]).slice(0, 3);
  const surface = parseColor(vars["--bg-surface"]).slice(0, 3);
  const elevated = parseColor(vars["--bg-surface-elevated"]).slice(0, 3);

  const primary = parseColor(vars["--text-primary"]).slice(0, 3);
  const secondary = parseColor(vars["--text-secondary"]).slice(0, 3);
  const muted = parseColor(vars["--text-muted"]).slice(0, 3);

  const signal = parseColor(vars["--accent-signal"]).slice(0, 3);
  const signalInk = parseColor(vars["--accent-signal-ink"]).slice(0, 3);
  const onSignal = parseColor(vars["--text-on-signal"]).slice(0, 3);
  const signalSoftOnSurface = composite(parseColor(vars["--accent-signal-soft"]), surface);
  const signalSoftOnElevated = composite(parseColor(vars["--accent-signal-soft"]), elevated);

  const verifiedInk = parseColor(vars["--accent-verified-ink"]).slice(0, 3);
  const verifiedSoftOnSurface = composite(parseColor(vars["--accent-verified-soft"]), surface);
  const verifiedSoftOnElevated = composite(parseColor(vars["--accent-verified-soft"]), elevated);

  const dangerInk = parseColor(vars["--accent-danger-ink"]).slice(0, 3);
  const dangerSoftOnSurface = composite(parseColor(vars["--accent-danger-soft"]), surface);

  const checks = [
    ["text-primary / bg-canvas", contrastRatio(primary, canvas), 4.5],
    ["text-primary / bg-surface", contrastRatio(primary, surface), 4.5],
    ["text-primary / bg-elevated", contrastRatio(primary, elevated), 4.5],
    ["text-secondary / bg-canvas", contrastRatio(secondary, canvas), 4.5],
    ["text-secondary / bg-surface", contrastRatio(secondary, surface), 4.5],
    ["text-secondary / bg-elevated", contrastRatio(secondary, elevated), 4.5],
    ["text-muted / bg-canvas", contrastRatio(muted, canvas), 4.5],
    ["text-muted / bg-surface", contrastRatio(muted, surface), 4.5],
    ["text-muted / bg-elevated", contrastRatio(muted, elevated), 4.5],
    ["badge-signal / soft-surface", contrastRatio(signalInk, signalSoftOnSurface), 4.5],
    ["badge-signal / soft-elevated", contrastRatio(signalInk, signalSoftOnElevated), 4.5],
    ["badge-verified / soft-surface", contrastRatio(verifiedInk, verifiedSoftOnSurface), 4.5],
    ["badge-verified / soft-elevated", contrastRatio(verifiedInk, verifiedSoftOnElevated), 4.5],
    ["badge-danger / soft-surface", contrastRatio(dangerInk, dangerSoftOnSurface), 4.5],
    ["badge-neutral / bg-elevated", contrastRatio(secondary, elevated), 4.5],
    ["btn-primary (text-on-signal / signal)", contrastRatio(onSignal, signal), 4.5],
    ["btn-ghost (text-primary / bg-surface)", contrastRatio(primary, surface), 4.5]
  ];

  let minRatio = Infinity;
  for (const [label, ratio, min] of checks) {
    if (ratio < min) {
      failures.push(`[${name}] ${label}: ${ratio.toFixed(2)}:1 < ${min}:1`);
    }
    if (ratio < minRatio) minRatio = ratio;
  }

  summaryRows.push({
    theme: name,
    primaryCanvas: contrastRatio(primary, canvas).toFixed(2),
    secondarySurface: contrastRatio(secondary, surface).toFixed(2),
    mutedElevated: contrastRatio(muted, elevated).toFixed(2),
    badgeSignal: contrastRatio(signalInk, signalSoftOnSurface).toFixed(2),
    badgeVerified: contrastRatio(verifiedInk, verifiedSoftOnSurface).toFixed(2),
    btnPrimary: contrastRatio(onSignal, signal).toFixed(2),
    minRatio: minRatio.toFixed(2)
  });
}

// 2. Audit self-hosted fonts & zero external font/script/stylesheet URLs in dist/
const distFiles = walk(DIST);
const woff2Files = distFiles
  .filter((f) => f.endsWith(".woff2"))
  .map((f) => path.basename(f));

for (const family of ["space-grotesk", "inter", "jetbrains-mono"]) {
  if (!woff2Files.some((f) => f.includes(family))) {
    failures.push(`Missing self-hosted .woff2 bundle in dist/ for ${family}`);
  }
}

for (const file of distFiles) {
  if (!/\.(html|css)$/i.test(file)) continue;
  const content = fs.readFileSync(file, "utf8");
  const rel = path.relative(ROOT, file);

  if (/fonts\.googleapis\.com|fonts\.gstatic\.com|use\.typekit\.net/i.test(content)) {
    failures.push(`${rel}: contains external font CDN reference`);
  }
  if (file.endsWith(".html")) {
    for (const m of content.matchAll(/<link\b[^>]*rel=["']stylesheet["'][^>]*href=["']([^"']+)["']/gi)) {
      if (/^https?:\/\//i.test(m[1])) failures.push(`${rel}: external stylesheet ${m[1]}`);
    }
    for (const m of content.matchAll(/<script\b[^>]*src=["']([^"']+)["']/gi)) {
      if (/^https?:\/\//i.test(m[1])) failures.push(`${rel}: external script ${m[1]}`);
    }
  }
  if (file.endsWith(".css")) {
    for (const m of content.matchAll(/url\(\s*["']?(https?:\/\/[^"')]+)["']?\s*\)/gi)) {
      failures.push(`${rel}: external CSS url(${m[1]})`);
    }
  }
}

// 3. Audit Expressive Code & UI primitives in built output
const ecCss = distFiles.find((f) => /\/_astro\/ec\..*\.css$/.test(f));
if (!ecCss) {
  failures.push("Missing built Expressive Code stylesheet in dist/_astro/ec.*.css");
} else {
  const ecContent = fs.readFileSync(ecCss, "utf8");
  if (!ecContent.includes('[data-theme="paper"]')) {
    failures.push("Expressive Code stylesheet missing [data-theme=\"paper\"] selector");
  }
  if (!ecContent.includes('[data-theme="aftertone"]')) {
    failures.push("Expressive Code stylesheet missing [data-theme=\"aftertone\"] selector");
  }
}

const sampleToolPost = path.join(
  DIST,
  "2026/09/11/updating-cucm-blf-labels-with-python.html"
);
const postHtml = fs.readFileSync(sampleToolPost, "utf8");
if (!postHtml.includes("expressive-code")) {
  failures.push("Sample post missing rendered astro-expressive-code block");
}
if (!postHtml.includes("af-validation-scope") || !postHtml.includes("af-badge")) {
  failures.push("Sample tool post missing rendered ValidationScope / Badge primitives");
}

console.log(`Self-hosted .woff2 font files in dist/_astro/: ${woff2Files.length}`);
console.log("WCAG 2.1 AA Contrast Summary (all checked pairs >= 4.50:1):");
console.table(summaryRows);

if (failures.length > 0) {
  console.error("Gate 2 FAILURES:\n" + failures.map((f) => `- ${f}`).join("\n"));
  process.exit(1);
}
console.log("Gate 2 PASS: 0 external font/asset requests, Expressive Code dual-theme verified, and 85/85 contrast pairs >= 4.5:1 AA.");
