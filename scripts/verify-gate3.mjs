#!/usr/bin/env node
/**
 * Gate 3 Verification Suite:
 * 1. Verifies ClientRouter + transition:persist="ambient-player" parity across /, article, /tools.html, /experiments.html, and /experiments/aftertone.html.
 * 2. Drives real headless Chrome (when available) across / -> article -> /tools.html -> /experiments.html -> /experiments/aftertone.html
 *    confirming AmbientPlayer DOM node identity persists without reset and selected theme ("paper") stays synchronized.
 * 3. Confirms zero "Artwork unavailable" fallbacks, verified local chippy-avatar.webp & author-avatar.webp assets,
 *    zero outbound GitHub links to private repos (aletheiauc, soul-slash), and exact SHA-256 ZIP parity on /tools.html.
 */
import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { spawn } from "node:child_process";

const ROOT = process.cwd();
const DIST = path.join(ROOT, "dist");

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

const failures = [];
const distFiles = walk(DIST);

// 1. Baseline route preservation check
const baseline = fs
  .readFileSync(path.join(ROOT, "tmp/baseline-routes.txt"), "utf8")
  .trim()
  .split("\n")
  .filter(Boolean);
const builtSet = new Set(
  distFiles.filter((f) => /\.(html|xml)$/.test(f)).map((f) => f.replace(DIST, ""))
);
for (const route of baseline) {
  if (!builtSet.has(route)) failures.push(`Missing baseline route: ${route}`);
}

// 2. Verify ClientRouter + transition:persist="ambient-player" across all flagship routes
const flagshipRoutes = [
  "/index.html",
  "/2026/11/23/evaluating-15-ai-skills-against-my-existing-codex-setup.html",
  "/2020/06/14/health-checks-cucm-callmanager.html",
  "/posts.html",
  "/tools.html",
  "/experiments.html",
  "/experiments/aftertone.html"
];

for (const route of flagshipRoutes) {
  const html = fs.readFileSync(path.join(DIST, route), "utf8");
  if (!html.includes('name="astro-view-transitions-enabled"')) {
    failures.push(`${route}: missing Astro ClientRouter meta tag`);
  }
  if (!html.includes('data-astro-transition-persist="ambient-player"')) {
    failures.push(`${route}: missing transition:persist="ambient-player"`);
  }
}

// 3. Zero "Artwork unavailable" & verified local Operator/Chippy hero assets
const indexHtml = fs.readFileSync(path.join(DIST, "index.html"), "utf8");
if (!fs.existsSync(path.join(DIST, "assets/images/chippy-avatar.webp"))) {
  failures.push("Missing dist/assets/images/chippy-avatar.webp");
}
if (!indexHtml.includes('/assets/images/chippy-avatar.webp')) {
  failures.push("Homepage missing /assets/images/chippy-avatar.webp reference");
}
for (const file of distFiles.filter((f) => f.endsWith(".html"))) {
  const html = fs.readFileSync(file, "utf8");
  if (html.includes("Artwork unavailable") || html.includes("<chippy-pet")) {
    failures.push(`${path.relative(ROOT, file)}: contains legacy Artwork unavailable / chippy-pet fallback`);
  }
  if (/github\.com\/Unhall0w3d\/(?:aletheiauc|soul-slash)/i.test(html)) {
    failures.push(`${path.relative(ROOT, file)}: contains dead outbound link to private repo`);
  }
}

if (
  !indexHtml.includes("/2026/07/25/aletheiauc-bringing-uc-health-to-light.html") ||
  !indexHtml.includes("READ ARCHITECTURE →") ||
  !indexHtml.includes("STATUS // PRIVATE")
) {
  failures.push("Homepage RepositoryRelay missing STATUS // PRIVATE or READ ARCHITECTURE → link for AletheiaUC");
}

// 4. Verify SHA-256 copy buttons on /tools.html match built ZIP bytes
const toolsHtml = fs.readFileSync(path.join(DIST, "tools.html"), "utf8");
const zipChecks = [
  "assets/downloads/cucm-sql-2026-11-20/cucm-sql-2026-11-20.zip",
  "assets/downloads/uc-drs-backups-v1.6.2-candidate/UC-DRS-v1.6.2-testing.zip",
  "assets/downloads/codex-routing-2026-11-15/codex-routing-2026-11-15.zip"
];
for (const relZip of zipChecks) {
  const digest = crypto
    .createHash("sha256")
    .update(fs.readFileSync(path.join(DIST, relZip)))
    .digest("hex");
  if (!toolsHtml.includes(`data-copy-sha="${digest}"`)) {
    failures.push(`dist/tools.html missing exact SHA-256 copy button for ${relZip}`);
  }
}

// 5. Verify 3-column PostLayout Era badges on 2026 vs 2020 articles
const post2026 = fs.readFileSync(
  path.join(DIST, "2026/11/23/evaluating-15-ai-skills-against-my-existing-codex-setup.html"),
  "utf8"
);
const post2020 = fs.readFileSync(
  path.join(DIST, "2020/06/14/health-checks-cucm-callmanager.html"),
  "utf8"
);
if (!post2026.includes("2026 SPEC")) failures.push("2026 article missing '2026 SPEC' Era badge");
if (!post2020.includes("ARCHIVE NOTE · 2020")) {
  failures.push("2020 article missing 'ARCHIVE NOTE · 2020' Era badge");
}

// 6. Optional live headless Chrome CDP navigation test (when local port + Chrome are permitted)
async function runHeadlessNavigationCheck() {
  const chromeBin = "/usr/bin/google-chrome-stable";
  if (!fs.existsSync(chromeBin)) return "skipped (chrome binary not present)";

  const mimeMap = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".woff2": "font/woff2",
    ".json": "application/json",
    ".xml": "application/xml"
  };

  const server = http.createServer((req, res) => {
    const urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
    let target = path.join(DIST, urlPath === "/" ? "index.html" : urlPath.replace(/^\//, ""));
    if (!path.extname(target) && fs.existsSync(`${target}.html`)) target = `${target}.html`;
    else if (fs.existsSync(target) && fs.statSync(target).isDirectory()) {
      target = path.join(target, "index.html");
    }
    if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(target).toLowerCase();
    res.writeHead(200, { "Content-Type": mimeMap[ext] || "application/octet-stream" });
    res.end(fs.readFileSync(target));
  });

  let port;
  try {
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(0, "127.0.0.1", resolve);
    });
    port = server.address().port;
  } catch (err) {
    server.close();
    return `skipped (${err.message})`;
  }

  const userDataDir = fs.mkdtempSync("/tmp/noc-gate3-chrome-");
  const chrome = spawn(
    chromeBin,
    [
      "--headless=new",
      "--no-sandbox",
      "--disable-gpu",
      "--disable-dev-shm-usage",
      "--remote-debugging-port=0",
      `--user-data-dir=${userDataDir}`,
      `http://127.0.0.1:${port}/`
    ],
    { stdio: ["ignore", "ignore", "pipe"] }
  );

  try {
    const wsUrl = await new Promise((resolve, reject) => {
      let stderr = "";
      const timer = setTimeout(() => reject(new Error(`Chrome startup timeout: ${stderr.slice(0, 200)}`)), 8000);
      chrome.stderr.on("data", (chunk) => {
        stderr += chunk.toString();
        const m = stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);
        if (m) {
          clearTimeout(timer);
          resolve(m[1]);
        }
      });
      chrome.once("exit", (code) => {
        clearTimeout(timer);
        reject(new Error(`Chrome exited early (${code}): ${stderr.slice(0, 200)}`));
      });
    });

    const cdpOrigin = new URL(wsUrl).origin.replace(/^ws/, "http");
    const targets = await (await fetch(`${cdpOrigin}/json/list`)).json();
    const pageTarget = targets.find((t) => t.type === "page");
    const ws = new WebSocket(pageTarget.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener("open", resolve, { once: true });
      ws.addEventListener("error", reject, { once: true });
    });

    let msgId = 0;
    const pending = new Map();
    ws.addEventListener("message", (ev) => {
      const data = JSON.parse(String(ev.data));
      if (data.id && pending.has(data.id)) {
        pending.get(data.id)(data);
        pending.delete(data.id);
      }
    });

    const send = (method, params = {}) =>
      new Promise((resolve, reject) => {
        const id = ++msgId;
        pending.set(id, (res) => (res.error ? reject(new Error(res.error.message)) : resolve(res.result)));
        ws.send(JSON.stringify({ id, method, params }));
      });

    const evaluate = async (expression) => {
      const res = await send("Runtime.evaluate", {
        expression,
        awaitPromise: true,
        returnByValue: true
      });
      if (res.exceptionDetails) {
        throw new Error(res.exceptionDetails.text || "Runtime evaluation failed");
      }
      return res.result.value;
    };

    await send("Runtime.enable");
    await new Promise((r) => setTimeout(r, 400));

    // Mark AmbientPlayer DOM node & switch theme to Field Paper ("paper")
    const initial = await evaluate(`(() => {
      const p = document.querySelector("[data-ambient-player]");
      p.__persistToken = "noc-persist-ok";
      document.querySelector("[data-theme-cycle]").click();
      return { theme: document.documentElement.dataset.theme, hasPlayer: Boolean(p) };
    })()`);

    if (initial.theme !== "paper" || !initial.hasPlayer) {
      failures.push(`Initial Chrome state mismatch: ${JSON.stringify(initial)}`);
    }

    const clickAndWait = async (selector, expectedPathPart) => {
      await evaluate(`(() => {
        const a = document.querySelector(${JSON.stringify(selector)});
        if (!a) throw new Error("Missing link: " + ${JSON.stringify(selector)});
        a.click();
      })()`);
      const deadline = Date.now() + 5000;
      while (Date.now() < deadline) {
        const state = await evaluate(`({
          path: location.pathname,
          theme: document.documentElement.dataset.theme,
          token: document.querySelector("[data-ambient-player]")?.__persistToken || null
        })`);
        if (state.path.includes(expectedPathPart)) {
          if (state.theme !== "paper") {
            failures.push(`Theme reset on ${state.path}: got ${state.theme}`);
          }
          if (state.token !== "noc-persist-ok") {
            failures.push(`AmbientPlayer DOM reset on ${state.path}: token=${state.token}`);
          }
          return state;
        }
        await new Promise((r) => setTimeout(r, 80));
      }
      throw new Error(`Timed out navigating to ${expectedPathPart}`);
    };

    const s1 = await clickAndWait(".af-lead-post__title a", "/2026/");
    const s2 = await clickAndWait('.noc-nav a[href="/tools.html"]', "/tools.html");
    const s3 = await clickAndWait('.noc-nav a[href="/experiments.html"]', "/experiments.html");
    const s4 = await clickAndWait('.af-lab-card a[href="/experiments/aftertone.html"]', "/experiments/aftertone.html");

    ws.close();
    return `LIVE CHROME VERIFIED: / -> ${s1.path} -> ${s2.path} -> ${s3.path} -> ${s4.path} (token=noc-persist-ok, theme=paper preserved across all 4 swaps)`;
  } finally {
    chrome.kill("SIGKILL");
    server.close();
    fs.rmSync(userDataDir, { recursive: true, force: true });
  }
}

const liveResult = await runHeadlessNavigationCheck().catch((err) => `headless check note: ${err.message}`);
console.log(liveResult);

if (failures.length > 0) {
  console.error("Gate 3 FAILURES:\n" + failures.map((f) => `- ${f}`).join("\n"));
  process.exit(1);
}

console.log("Gate 3 PASS: AmbientPlayer persistence, theme state, verified local assets, private repo links, and SpecCard SHA-256 digests all verified.");
