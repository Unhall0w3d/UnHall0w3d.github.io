---
trigger: always_on
description: Aftertone Telemetry visual design system, semantic CSS tokens, self-hosted typography, accessibility, and Astro ClientRouter lifecycle invariants for NOC Thoughts.
---

# NOC Thoughts — Design System & Engineering Rules ("Aftertone Telemetry")

Enforce these invariants across every UI, layout, stylesheet, and interactive experiment update in this repository. Never silently waive a rule; surface conflicts before modifying files.

## 1. Architectural & Runtime Invariants

- **100% Static GitHub Pages Output**: Keep `output: "static"` and `build.format: "file"` in `astro.config.mjs`. Never introduce SSR adapters, server endpoints, external font CDNs, third-party analytics, or external SaaS search dependencies. All Pagefind WASM indices (`dist/pagefind/`), Expressive Code syntax blocks, and Satori OpenGraph PNGs (`src/pages/og/[...slug].png.ts`) compile at build time into `dist/`.
- **Zero Flash of Unstyled Theme (FOUC)**: `data-theme` must initialize synchronously before first paint via `/assets/site-theme.js` in `<head>`, defaulting to `aftertone` (dark) or honoring `localStorage["noc-thoughts.theme"]`.
- **Single Layout Shell**: Every Astro page must use `src/layouts/BaseLayout.astro` (or `src/layouts/ExperimentLayout.astro` for standalone instruments in `src/experiments/*.html`), sharing `SiteHeader.astro`, `SiteFooter.astro`, `CommandPalette.astro`, and persistent `AmbientPlayer.astro`.
- **Astro `<ClientRouter />` Lifecycle Discipline**: Because `AmbientPlayer.astro` persists across navigations via `transition:persist="ambient-player"`, every client script must:
  1. Initialize on `astro:page-load` (with idempotent binding guards so listeners never double-attach).
  2. Tear down `requestAnimationFrame` loops, `IntersectionObserver` / `MutationObserver` instances, and window listeners on `astro:before-swap`.
  3. Re-synchronize `document.documentElement.dataset.theme` on `astro:after-swap`.
- **`/tools.html` Hardened CSP**: `src/pages/tools.astro` sets `downloadPage`, emitting a strict Content-Security-Policy (`script-src 'self' 'wasm-unsafe-eval' https://www.youtube.com`) verified by `scripts/validate-site.mjs`. Never add inline executable `<script>` blocks to `/tools.html`; use external local scripts (`/assets/*.js` or bundled `/_astro/*.js`).
- **Intrinsic Image Dimensions & Local Assets**: Every `<img>` element must specify explicit numeric `width` and `height` attributes (`scripts/validate-site.mjs` fails the build otherwise) and resolve to a verified local repo asset with `naturalWidth > 0`.

## 2. Semantic CSS Custom Properties (`src/styles/tokens.css`)

Expose 3 flagship themes in the header cycle (`aftertone` → `paper` → `polar`), with legacy Easter-egg themes (`cyberpunk`, `moss-brass`) unlockable strictly via `⌘K`:

- **Surfaces**: `--bg-canvas`, `--bg-surface`, `--bg-surface-elevated`, `--bg-code`
- **Borders & Hairlines**: `--border-subtle`, `--border-strong`
- **Typography Colors**: `--text-primary`, `--text-secondary`, `--text-muted`
- **Semantic Signal Accents**:
  - `--accent-signal`, `--accent-signal-soft`, `--accent-signal-ink`, `--text-on-signal` (active controls, primary CTAs, preview/caution posture)
  - `--accent-verified`, `--accent-verified-soft`, `--accent-verified-ink` (read-only, verified, observe-default posture, live telemetry)
  - `--accent-danger`, `--accent-danger-soft`, `--accent-danger-ink` (destructive / incident / error)
- **Geometry & Measure**: `--radius-sm` (`4px`), `--radius-md` (`8px`), `--radius-pill` (`999px`), `--measure-prose` (`66ch`), `--container-max` (`1280px`)

## 3. Self-Hosted Typography & Visual Discipline

- **Fonts (Self-Hosted via `@fontsource` only)**:
  - `--font-display`: `Space Grotesk` (500, 600, 700), tight tracking `-0.025em`.
  - `--font-sans`: `Inter` (400, 500, 600), `1.0625rem` (`17px`) desktop / `1rem` (`16px`) mobile, line-height `1.7`.
  - `--font-mono`: `JetBrains Mono` (400, 500) strictly for operational coordinates (`6.830 MHz`, `SYRACUSE, NY`), status/safety badges, commit SHAs, SHA-256 digests, timestamps, and code blocks.
- **Visual Discipline**:
  - Use `1px solid var(--border-subtle)` architectural grid dividers instead of heavy drop shadows, neon glows, or decorative card/heading gradients.
  - Reserve `--accent-signal` and `--accent-verified` for semantic meaning only.
  - Keep micro-telemetry (`11px–12px` mono, `--text-muted`) compact so primary titles and prose dominate the hierarchy.

## 4. Accessibility & Responsive Discipline

- **WCAG 2.1 AA Contrast**: Maintain `>= 4.5:1` contrast on all body, secondary, muted micro-telemetry, badge, and button text pairs across `aftertone`, `paper`, `polar`, `cyberpunk`, and `moss-brass` (verify via `node scripts/verify-gate2.mjs`).
- **Reduced Motion**: Respect `prefers-reduced-motion: reduce` by freezing animated canvases (`SignalScope.astro`) to static waveforms, pausing equalizer animations, and disabling non-essential view transition motion.
- **Zero Overflow & Mobile Action Visibility**: Maintain `document.documentElement.scrollWidth <= window.innerWidth` at both `1440×900` and `390×844`. Interactive experiments must surface newly unlocked progression actions inside `ExperimentLayout.astro`'s sticky bottom tray (`.af-exp-tray`) without requiring blind scrolling.
