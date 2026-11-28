#!/usr/bin/env node
/**
 * Gate 4 Automated Playwright Browser Acceptance Suite (Spec §6 Gate 4):
 * - Tests at 1440x900 (desktop) and 390x844 (mobile) in both "aftertone" and "paper" themes across:
 *   /, /posts.html, /tools.html, /experiments.html, one 2026 article, one 2019-2023 archive article,
 *   and /experiments/aftertone.html interactive 5-station progression.
 * - Verifies:
 *   1. document.documentElement.scrollWidth <= window.innerWidth (zero horizontal overflow)
 *   2. Above-the-fold at 390x844: primary headline/controls and Aftertone post-5th-save action cue visible without scrolling
 *   3. Zero console errors, zero failed network requests (status >= 400), zero broken images (naturalWidth === 0)
 *   4. Build-time Satori OpenGraph PNG cards (1200x630) resolve 200 OK via og:image meta tags
 *   5. Keyboard-only flow: open Ctrl+K / ⌘K, search "BLF" via Pagefind WASM, navigate to result,
 *      switch theme (including legacy Easter-egg theme), toggle ambient player, jump to Toolbox category & verify download links.
 */
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { chromium } from "playwright";

const ROOT = process.cwd();
const DIST = path.join(ROOT, "dist");

const MIME_MAP = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".json": "application/json; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".webp": "image/webp",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".zip": "application/zip",
  ".txt": "text/plain; charset=utf-8",
  ".md": "text/markdown; charset=utf-8",
  ".csv": "text/csv; charset=utf-8",
  ".sql": "text/plain; charset=utf-8",
  ".py": "text/plain; charset=utf-8",
  ".ps1": "text/plain; charset=utf-8",
  ".tcl": "text/plain; charset=utf-8"
};

function startStaticServer() {
  const server = http.createServer((req, res) => {
    const rawUrl = decodeURIComponent((req.url || "/").split("?")[0]);
    let target = path.join(DIST, rawUrl === "/" ? "index.html" : rawUrl.replace(/^\//, ""));
    if (!path.extname(target) && fs.existsSync(`${target}.html`)) {
      target = `${target}.html`;
    } else if (fs.existsSync(target) && fs.statSync(target).isDirectory()) {
      target = path.join(target, "index.html");
    }

    if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end(`Not found: ${rawUrl}`);
      return;
    }

    const ext = path.extname(target).toLowerCase();
    const bytes = fs.readFileSync(target);
    res.writeHead(200, {
      "Content-Type": MIME_MAP[ext] || "application/octet-stream",
      "Content-Length": bytes.length
    });
    res.end(bytes);
  });

  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      resolve({ server, port: server.address().port });
    });
  });
}

function readPngDimensions(buf) {
  // PNG IHDR width @ offset 16, height @ offset 20 (big-endian uint32)
  if (buf.length < 24 || buf[0] !== 0x89 || buf[1] !== 0x50) return null;
  return {
    width: buf.readUInt32BE(16),
    height: buf.readUInt32BE(20)
  };
}

const ROUTES = [
  { path: "/", name: "Homepage (Signal Console)", foldSelector: ".af-console-hero__actions a" },
  { path: "/posts.html", name: "Signal Archive", foldSelector: "[data-pillar-chip]" },
  { path: "/tools.html", name: "Field Toolbox", foldSelector: ".af-tools-jump a" },
  { path: "/experiments.html", name: "Signal Lab Hub", foldSelector: ".af-lab-card__cta-wrap a" },
  {
    path: "/2026/11/23/evaluating-15-ai-skills-against-my-existing-codex-setup.html",
    name: "2026 Spec Article",
    foldSelector: ".af-article__header h1"
  },
  {
    path: "/2020/06/14/health-checks-cucm-callmanager.html",
    name: "2020 Archive Article",
    foldSelector: ".af-article__header h1"
  },
  {
    path: "/experiments/aftertone.html",
    name: "Aftertone Instrument",
    foldSelector: "#save"
  }
];

const VIEWPORTS = [
  { label: "desktop-1440x900", width: 1440, height: 900 },
  { label: "mobile-390x844", width: 390, height: 844 }
];

const THEMES = ["aftertone", "paper"];

const failures = [];
const matrixStats = {
  cellsChecked: 0,
  consoleErrors: 0,
  failedRequests: 0,
  brokenImages: 0,
  ogCardsVerified: 0
};

const { server, port } = await startStaticServer();
const origin = `http://127.0.0.1:${port}`;

const browser = await chromium.launch({
  executablePath: "/usr/bin/google-chrome-stable",
  args: ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
});

try {
  // 1. Matrix: 2 Viewports x 2 Themes x 7 Flagship Routes
  for (const vp of VIEWPORTS) {
    for (const theme of THEMES) {
      const context = await browser.newContext({
        viewport: { width: vp.width, height: vp.height }
      });

      // Seed explicit theme before any page loads (Zero FOUC verification)
      await context.addInitScript((t) => {
        try {
          localStorage.setItem("noc-thoughts.theme", t);
        } catch {}
      }, theme);

      const page = await context.newPage();

      // Stub external YouTube iframe API in offline test mode so toggle tests never hit WAN
      await page.route("https://www.youtube.com/**", (route) =>
        route.fulfill({ status: 200, contentType: "application/javascript", body: "/* offline stub */" })
      );

      const cellErrors = [];
      page.on("console", (msg) => {
        if (msg.type() === "error") {
          matrixStats.consoleErrors++;
          cellErrors.push(`console.error: ${msg.text()}`);
        }
      });
      page.on("pageerror", (err) => {
        matrixStats.consoleErrors++;
        cellErrors.push(`pageerror: ${err.message}`);
      });
      page.on("response", (res) => {
        if (res.status() >= 400) {
          matrixStats.failedRequests++;
          cellErrors.push(`HTTP ${res.status()} on ${res.url()}`);
        }
      });

      for (const route of ROUTES) {
        const label = `[${vp.label} | ${theme} | ${route.path}]`;
        cellErrors.length = 0;

        await page.goto(`${origin}${route.path}`, { waitUntil: "networkidle" });
        matrixStats.cellsChecked++;

        // Confirm theme initialized accurately
        const activeTheme = await page.evaluate(() => document.documentElement.dataset.theme);
        if (activeTheme !== theme) {
          failures.push(`${label} expected data-theme="${theme}", got "${activeTheme}"`);
        }

        // Confirm zero horizontal overflow
        const overflow = await page.evaluate(() => ({
          scrollWidth: document.documentElement.scrollWidth,
          innerWidth: window.innerWidth
        }));
        if (overflow.scrollWidth > overflow.innerWidth) {
          failures.push(
            `${label} horizontal overflow: scrollWidth=${overflow.scrollWidth} > innerWidth=${overflow.innerWidth}`
          );
        }

        // Above-the-fold check at 390x844 before any scrolling
        if (vp.width === 390 && vp.height === 844) {
          const h1Box = await page.locator("h1").first().boundingBox();
          if (!h1Box || h1Box.y < 0 || h1Box.y + h1Box.height > 844) {
            failures.push(`${label} primary H1 not visible above the fold: ${JSON.stringify(h1Box)}`);
          }
          const ctrlBox = await page.locator(route.foldSelector).first().boundingBox();
          if (!ctrlBox || ctrlBox.y < 0 || ctrlBox.y + ctrlBox.height > 844) {
            failures.push(
              `${label} primary control (${route.foldSelector}) not visible above the fold at 390x844: ${JSON.stringify(ctrlBox)}`
            );
          }
        }

        // Verify og:image meta resolves to valid 1200x630 PNG (or valid experiment preview image)
        const ogImageHref = await page
          .locator('meta[property="og:image"]')
          .first()
          .getAttribute("content");
        if (!ogImageHref) {
          failures.push(`${label} missing meta[property="og:image"]`);
        } else {
          const ogPath = new URL(ogImageHref).pathname;
          const ogRes = await fetch(`${origin}${ogPath}`);
          if (ogRes.status !== 200) {
            failures.push(`${label} og:image ${ogPath} returned HTTP ${ogRes.status}`);
          } else if (ogPath.endsWith(".png")) {
            const buf = Buffer.from(await ogRes.arrayBuffer());
            const dims = readPngDimensions(buf);
            if (!dims || dims.width !== 1200 || dims.height !== 630) {
              failures.push(`${label} og:image ${ogPath} invalid PNG dims: ${JSON.stringify(dims)}`);
            } else {
              matrixStats.ogCardsVerified++;
            }
          }
        }

        // Force lazy images in visible & hidden tabs to eager-load so we verify 100% of <img> assets
        const brokenImgs = await page.evaluate(async () => {
          const imgs = [...document.querySelectorAll("img")];
          for (const img of imgs) {
            if (img.loading === "lazy") img.loading = "eager";
            if (!img.complete) {
              await new Promise((resolve) => {
                img.addEventListener("load", resolve, { once: true });
                img.addEventListener("error", resolve, { once: true });
                setTimeout(resolve, 2000);
              });
            }
          }
          return imgs
            .filter((img) => !img.complete || img.naturalWidth === 0)
            .map((img) => img.getAttribute("src") || "<missing-src>");
        });

        if (brokenImgs.length > 0) {
          matrixStats.brokenImages += brokenImgs.length;
          failures.push(`${label} broken images: ${brokenImgs.join(", ")}`);
        }

        if (cellErrors.length > 0) {
          failures.push(`${label} runtime errors: ${cellErrors.join(" | ")}`);
        }
      }

      // Interactive Aftertone 5-station progression at 390x844 (without scrolling!)
      if (vp.width === 390 && vp.height === 844) {
        await page.goto(`${origin}/experiments/aftertone.html`, { waitUntil: "networkidle" });
        await page.evaluate(() => localStorage.removeItem("aftertone-log-v1"));
        await page.reload({ waitUntil: "networkidle" });

        for (let i = 0; i < 5; i++) {
          await page.locator("#save").click();
          if (i < 4) await page.locator("#seek").click();
        }

        const scrollY = await page.evaluate(() => window.scrollY);
        const trayBtn = page.locator("[data-exp-tray-action]");
        const trayVisible = await trayBtn.isVisible();
        const trayBox = await trayBtn.boundingBox();

        if (scrollY !== 0 || !trayVisible || !trayBox || trayBox.y < 0 || trayBox.y + trayBox.height > 844) {
          failures.push(
            `[mobile-390x844 | ${theme} | aftertone-5th-save] final-state action cue not visible above fold: scrollY=${scrollY}, visible=${trayVisible}, box=${JSON.stringify(trayBox)}`
          );
        } else {
          await trayBtn.click();
          const notice = await page.locator("#notice").textContent();
          if (!notice?.includes("Return line connected")) {
            failures.push(`[mobile-390x844 | ${theme} | aftertone-5th-save] clicking sticky tray action did not connect return line (notice="${notice}")`);
          }
        }
      }

      await context.close();
    }
  }

  // 2. Full Keyboard-Only Acceptance Test (⌘K Pagefind search "BLF", theme switch, ambient toggle, Toolbox downloads)
  {
    const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await context.newPage();
    await page.route("https://www.youtube.com/**", (route) =>
      route.fulfill({ status: 200, contentType: "application/javascript", body: "/* offline stub */" })
    );

    const kbErrors = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") kbErrors.push(msg.text());
    });
    page.on("pageerror", (err) => kbErrors.push(err.message));

    await page.goto(`${origin}/`, { waitUntil: "networkidle" });

    // Open ⌘K with Control+k
    await page.keyboard.press("Control+k");
    await page.locator("#af-command-palette[open]").waitFor({ state: "visible", timeout: 3000 });

    // Search for "BLF" via Pagefind WASM
    await page.keyboard.type("BLF");
    await page.locator('#af-cmd-results a.af-cmd__item[href*="blf"]').first().waitFor({
      state: "visible",
      timeout: 5000
    });

    // Navigate to first Pagefind result using Enter and wait for ClientRouter swap to settle
    await page.keyboard.press("Enter");
    await page.waitForFunction(() => window.location.pathname !== "/" && !document.querySelector("#af-command-palette[open]"), {
      timeout: 5000
    });
    await page.waitForTimeout(250);
    const landedPath = new URL(page.url()).pathname;
    if (!landedPath.toLowerCase().includes("blf") && landedPath !== "/tools.html") {
      failures.push(`[keyboard] Expected BLF search Enter to navigate to BLF result; got ${landedPath}`);
    }

    // Switch theme via ⌘K command action (> Theme: Field Paper)
    await page.keyboard.press("Control+k");
    await page.locator("#af-command-palette[open]").waitFor({ state: "visible", timeout: 3000 });
    await page.keyboard.type("> Theme: Field Paper");
    await page.keyboard.press("Enter");
    const switchedTheme = await page.evaluate(() => document.documentElement.dataset.theme);
    if (switchedTheme !== "paper") {
      failures.push(`[keyboard] Expected ⌘K theme switch to set "paper", got "${switchedTheme}"`);
    }

    // Also verify legacy Easter-egg theme unlockable strictly via ⌘K (> Theme: Cyberpunk)
    await page.keyboard.press("Control+k");
    await page.locator("#af-command-palette[open]").waitFor({ state: "visible", timeout: 3000 });
    await page.keyboard.type("> Theme: Cyberpunk");
    await page.keyboard.press("Enter");
    const cyberTheme = await page.evaluate(() => document.documentElement.dataset.theme);
    if (cyberTheme !== "cyberpunk") {
      failures.push(`[keyboard] Expected ⌘K Easter-egg switch to set "cyberpunk", got "${cyberTheme}"`);
    }

    // Toggle ambient player via ⌘K (> Toggle Ambient Audio)
    await page.keyboard.press("Control+k");
    await page.locator("#af-command-palette[open]").waitFor({ state: "visible", timeout: 3000 });
    await page.keyboard.type("> Toggle Ambient Audio");
    await page.keyboard.press("Enter");
    const audioStatus = await page.locator("[data-ambient-status]").textContent();
    if (!audioStatus?.includes("TUNING")) {
      failures.push(`[keyboard] Expected Toggle Ambient Audio to initiate tuning, got "${audioStatus}"`);
    }

    // Jump to Toolbox and verify keyboard category jump + every download chip HTTP 200 integrity
    await page.goto(`${origin}/tools.html`, { waitUntil: "networkidle" });
    const jumpLink = page.locator('.af-tools-jump a[href="#audits"]');
    await jumpLink.focus();
    await page.keyboard.press("Enter");
    const hash = await page.evaluate(() => window.location.hash);
    if (hash !== "#audits") {
      failures.push(`[keyboard] Toolbox category jump expected #audits, got "${hash}"`);
    }

    const downloadHrefs = await page.evaluate(() =>
      [...document.querySelectorAll(".af-dl-chip[download]")].map((a) => a.getAttribute("href"))
    );
    if (downloadHrefs.length === 0) {
      failures.push("[keyboard] Found 0 .af-dl-chip[download] links on /tools.html");
    }
    for (const href of new Set(downloadHrefs)) {
      const dlRes = await fetch(`${origin}${href}`);
      const buf = await dlRes.arrayBuffer();
      if (dlRes.status !== 200 || buf.byteLength === 0) {
        failures.push(`[keyboard] Download link broken: ${href} -> HTTP ${dlRes.status} (${buf.byteLength} bytes)`);
      }
    }

    if (kbErrors.length > 0) {
      failures.push(`[keyboard] Console/page errors: ${kbErrors.join(" | ")}`);
    }

    await context.close();
  }
} finally {
  await browser.close();
  server.close();
}

console.log("Gate 4 Matrix Summary:", matrixStats);
if (failures.length > 0) {
  console.error("Gate 4 FAILURES:\n" + failures.map((f) => `- ${f}`).join("\n"));
  process.exit(1);
}

console.log(
  "Gate 4 PASS: 28/28 viewport×theme×route inspections, Aftertone 390x844 final-state above-the-fold cue, Satori 1200x630 OG PNGs, Pagefind ⌘K keyboard flow, and download integrity all passed with 0 errors."
);
