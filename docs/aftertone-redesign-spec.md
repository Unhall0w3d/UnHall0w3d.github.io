NOC Thoughts — Unified Design & Engineering Specification ("Aftertone Telemetry")
YAML
document_type: design-and-engineering-spec
project: nocthoughts.com
target_harness: Antigravity (Planning Mode -> Phased Implementation)
target_model: Gemini Carbon
stack: Astro (Static Output) + GitHub Pages
status: ready-for-phase-0-discovery
1. Architectural Constitution & Non-Negotiables
Gemini Carbon must enforce these invariants across every phase. Do not silently waive any rule; if a repository constraint conflicts with a rule below, stop and surface the conflict before modifying files.

100% Static GitHub Pages Output: No SSR adapters, server endpoints, or external SaaS dependencies (no Algolia, no external font CDNs at runtime, no third-party analytics). All search indices, syntax highlighting, and OpenGraph cards must compile at build time into dist/.

Zero Broken Inbound URLs: The live site preserves .html permalinks (e.g., /posts.html, /tools.html, /experiments.html, /2026/11/23/...html). Inspect astro.config.* (build.format, trailingSlash, and existing permalink rules) during Phase 0 and preserve every existing article, tool, and experiment URL. Any retired /categories/* or /tags/* slug must emit a static redirect page (<meta http-equiv="refresh"> + canonical link) to its mapped Pillar or Tag.

Zero Category/Tag Label Collisions: A label must never appear as both a pillar (category) and a tag on the same entry. Enforce this at build time in the content schema and RSS generator.

Zero Flash of Unstyled Theme (FOUC): Theme state (data-theme) must initialize synchronously via an inline <script is:inline> in <head> before first paint, falling back to aftertone (default dark) or respecting explicit user preference in localStorage.

Single Layout Shell Across All Routes: Every public route (/, /posts, /tools, /experiments, /about, articles, archives) must share one BaseLayout.astro header, navigation, theme state, command palette, and footer. Eliminate current per-page navigation drift.

Astro ClientRouter Lifecycle Discipline: Because persistent audio relies on <ClientRouter/> and transition:persist, every client script (theme toggle, oscilloscope canvas, TOC scroll-spy, copy buttons, archive filter chips, interactive experiments) must initialize on astro:page-load, clean up listeners/animation loops on astro:before-swap, and re-sync data-theme on astro:after-swap.

Zero Dead or Broken UI Affordances:

Replace the broken Chippy · Artwork unavailable hero fallback with a verified local SVG/WebP asset bundled in the repo.

Private repositories (e.g., AletheiaUC) must never render an outbound OPEN REPOSITORY ↗ link; instead render STATUS // PRIVATE with an internal link to the architecture write-up (READ ARCHITECTURE →).

Accessibility & Motion Discipline:

All color pairs must meet WCAG 2.1 AA contrast (≥ 4.5:1 body text, ≥ 3:1 UI controls/large text) across all active themes.

Respect prefers-reduced-motion: reduce by freezing the hero oscilloscope to a crisp static waveform and disabling non-essential view transitions.

Full keyboard navigation across header, ⌘K palette, archive filters, and tool download links.

2. Visual Design System & Token Specification
Unify the current 6 competing palettes into 3 flagship themes (aftertone, paper, polar) exposed in the UI, with optional legacy Easter-egg themes (cyberpunk, moss-brass) unlockable strictly via the ⌘K command palette.

2.1 Semantic CSS Custom Properties (src/styles/tokens.css)
CSS
:root,
[data-theme="aftertone"] {
  /* Surfaces */
  --bg-canvas: #0E1013;
  --bg-surface: #15181D;
  --bg-surface-elevated: #1C2028;
  --bg-code: #0B0D10;

  /* Borders & Hairlines */
  --border-subtle: rgba(255, 255, 255, 0.08);
  --border-strong: rgba(255, 255, 255, 0.16);

  /* Typography */
  --text-primary: #ECEEF2;
  --text-secondary: #9CA3AF;
  --text-muted: #6B7280;

  /* Semantic Signal Accents */
  --accent-signal: #E5A448;        /* Phosphor amber: active controls, CTAs, preview/caution */
  --accent-signal-soft: rgba(229, 164, 72, 0.14);
  --accent-verified: #38C6B8;      /* Signal teal: read-only, verified, sonar/AI telemetry */
  --accent-verified-soft: rgba(56, 198, 184, 0.14);
  --accent-danger: #E05D5D;        /* Destructive / error / incident */

  /* Geometry & Layout */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-pill: 999px;
  --measure-prose: 66ch;
  --container-max: 1280px;
}

[data-theme="paper"] {
  /* Archival Warm Daylight Mode */
  --bg-canvas: #F5F3EE;
  --bg-surface: #EBE7DF;
  --bg-surface-elevated: #FFFFFF;
  --bg-code: #17191C;              /* High-contrast dark terminal inset */

  --border-subtle: rgba(23, 25, 28, 0.11);
  --border-strong: rgba(23, 25, 28, 0.22);

  --text-primary: #17191C;
  --text-secondary: #4B525C;
  --text-muted: #6C737E;

  --accent-signal: #B95E1B;        /* Terracotta amber (AA on #F5F3EE) */
  --accent-signal-soft: rgba(185, 94, 27, 0.12);
  --accent-verified: #0F766E;      /* Deep signal teal (AA on #F5F3EE) */
  --accent-verified-soft: rgba(15, 118, 110, 0.12);
  --accent-danger: #B91C1C;
}

[data-theme="polar"] {
  /* High-Contrast Late-Night NOC Mode */
  --bg-canvas: #080C14;
  --bg-surface: #0F1624;
  --bg-surface-elevated: #162033;
  --bg-code: #05080E;

  --border-subtle: rgba(148, 184, 232, 0.12);
  --border-strong: rgba(148, 184, 232, 0.24);

  --text-primary: #F1F5F9;
  --text-secondary: #94A3B8;
  --text-muted: #64748B;

  --accent-signal: #60A5FA;
  --accent-signal-soft: rgba(96, 165, 250, 0.15);
  --accent-verified: #34D399;
  --accent-verified-soft: rgba(52, 211, 153, 0.15);
  --accent-danger: #F87171;
}
2.2 Typography Stack (Self-Hosted via @fontsource)
Display / Headings (--font-display): Space Grotesk (weights 500, 600, 700), tight tracking -0.025em.

Long-Form Prose (--font-sans): Inter (weights 400, 500, 600), 1.0625rem (17px) desktop / 1rem (16px) mobile, line-height 1.7.

Telemetry / Metadata / Code (--font-mono): JetBrains Mono (weights 400, 500), used strictly for operational coordinates (6.830 MHz, SYRACUSE, NY), status badges, commit SHAs, SHA-256 hashes, timestamps, and code blocks.

2.3 Visual Discipline Rules
Use 1px solid var(--border-subtle) architectural grid dividers instead of heavy drop shadows or glowing neon borders.

Reserve --accent-signal and --accent-verified for semantic meaning only (active state, safety posture, primary CTA). Never flood cards or headings with decorative gradients.

Keep micro-telemetry (FIELD NOTES // 6.830 MHz, short SHAs) compact (11px–12px mono, muted color) so primary titles and body text dominate the hierarchy.

3. Information Architecture & Taxonomy Overhaul
3.1 Unified Navigation Bar (SiteHeader.astro)
Sticky top bar (height: 60px, backdrop blur, 1px bottom border) rendered identically on every route:

Left: Brand lockup (NOC THOUGHTS + compact live status indicator dot).

Center: 4 primary links — Field Notes (/posts), Toolbox (/tools), Lab (/experiments), Operator (/about).

Right: Search trigger button (Search ⌘K / Ctrl+K) + single Theme cycle button (Aftertone → Field Paper → Polar Night).

(Categories and Tags remain accessible via dedicated index routes and filter controls inside Field Notes and ⌘K, removing them from top-level header clutter.)

3.2 Category Consolidation (18 Categories → 5 Operational Pillars)
Replace the current 18 categories with a strict 5-value enum (pillar) in frontmatter:

Canonical Pillar Slug	Display Title	Absorbs Legacy Categories
unified-communications	Unified Communications	Cisco, Unified Communications, Cisco Unified Contact Center, IOS/XE
automation-tooling	Automation & Tooling	Automation, Python, PowerShell, SQL
local-ai-agents	Local AI & Agents	Modern AI/LLM/Codex/Soul posts currently filed in General
systems-infrastructure	Systems & Infrastructure	Linux, Arch, Debian, VMWare, Cisco UCS, RUCKUS, Microsoft Windows
field-log-craft	Field Log & Craft	Gaming, Web Development, remaining non-AI General posts
3.3 Tag Normalization (~105 Tags → ~32 Canonical Slugs)
Create a deterministic migration script (e.g., scripts/normalize-taxonomy.mjs) that normalizes frontmatter across all ~76 posts using an explicit alias map:

CUCM consolidation: Cisco Unified Communications Manager, CUCM, Callmanager → cucm

Unity Connection: Cisco Unity Connection, Unity Connection → unity-connection

Contact Center: Cisco Unified Contact Center Express, Cisco Unified Contact Center, UCCX → uccx

PowerShell / Scripting: Powershell, PowerShell → powershell; Paramiko, Python → python

BLF / Dial Plan: blf, BLF Speed Dial, Speed Dial, auto-answer, Directory Number, Calling Search Space, Route Pattern → dial-plan or phone-config

AI / Local Compute: Artificial Intelligence, Local LLM, llama.cpp, GPU, AMD, NVIDIA → local-llm, llama-cpp, gpu-tuning; Codex, Subagents, Skills, MCP, OpenClaw, OpenCode → codex, agent-workflows; Soul Slash, Music Production → soul-slash

Virtualization / Hardware: VMWare, VMware ESXi, vCenter, vCSA, Proxmox → virtualization; Cisco UCS, Cisco UCS-C → cisco-ucs

Prune single-use orphan tags: Drop or roll up one-off tags unless they represent a strategic recurring topic (e.g., astro, nixos, smartzone, unreal-engine, aletheia-uc).

3.4 Content Collection Schema (src/content.config.ts)
TypeScript
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

export const PILLARS = [
  'unified-communications',
  'automation-tooling',
  'local-ai-agents',
  'systems-infrastructure',
  'field-log-craft',
] as const;

const posts = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/posts' }),
  schema: z.object({
    title: z.string().min(1),
    description: z.string().min(10).max(240), // Required; backfill 2019–2023 posts
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    pillar: z.enum(PILLARS),
    tags: z.array(z.string().regex(/^[a-z0-9-]+$/)).max(6).default([]),
    legacyCategories: z.array(z.string()).optional(), // For static redirect generation only
    hasTool: z.boolean().default(false),
    draft: z.boolean().default(false),
    validation: z.object({
      posture: z.enum(['read-only', 'preview-first', 'observe-default', 'lab-verified', 'reference']),
      testedOn: z.string(),
      limits: z.string().optional(),
    }).optional(),
  }).refine(
    (data) => !data.tags.includes(data.pillar),
    { message: 'Tag must not duplicate pillar slug.' }
  ),
});

export const collections = { posts };
4. Page & Component Specifications
4.1 Homepage (/) — "The Signal Console"
Structured as a calm, high-density bento sequence with clear visual rhythm:

Asymmetric Hero (2-column desktop, stacked mobile):

Left (55%): Eyebrow telemetry (FIELD LOG // 6.830 MHz), bold H1 ("Where network operations meet local AI."), crisp 2-line subtitle, and two clean actions: primary button (Explore Field Toolbox) + secondary outline (Read Field Notes).

Right (45%): Interactive Oscilloscope Instrument Panel (<SignalScope/>) rendered via lightweight 2D Canvas (requestAnimationFrame throttled/paused when offscreen or under prefers-reduced-motion). Includes a sleek corner switch (Scope | Operator / Chippy) that swaps to a verified local asset—no broken artwork state.

Field Toolbox Strip (3-column bento): Quick-entry task cards (Phone Config, Read-Only UC Audits, Backups & Guardrails) with semantic safety pills (PREVIEW FIRST, READ-ONLY SQL, OBSERVE DEFAULT) and a direct All tools & downloads → link.

Signal Lab Showcase Band (New on Homepage): 3-card horizontal visual strip surfacing Local LLM Observatory, Kestrel Sound, and Aftertone with custom high-contrast SVG/CSS mini-instrument artwork and direct launch links.

Latest Transmissions Ledger: 1 featured lead card for the newest deep dive + 4 tight horizontal rows showing date, Pillar pill, title, 1-line summary, and read time.

Repository Relay (2-column compact grid): Cards for AletheiaUC, Soul/, Mind Enigma, Ruckus Backup Retriever, and Unreal Codex Playtesting displaying stack, branch, short SHA (or REDACTED), and sync date. Private repos link internally to their architecture article.

4.2 Persistent Ambient Audio Pill (AmbientPlayer.astro)
Relocate the 9-track Soul Slash Synthesis YouTube/audio player out of the homepage body into a collapsible bottom-right floating micro-player mounted inside BaseLayout.astro with transition:persist="ambient-player".

Collapsed state (default): Compact pill (36px tall) showing play icon, animated 4-bar equalizer (static when paused), current track title (Rooms Between Seconds), and expand chevron.

Expanded popover: Full 9-track selector, transport controls, volume slider, and external Source // YouTube ↗ link.

Mobile (< 640px): Docks cleanly above safe-area insets without overlapping sticky experiment controls or main content buttons.

4.3 Article Reading View (PostLayout.astro)
Desktop (≥ 1180px) 3-Column Grid: 180px left metadata rail | minmax(0, 66ch) centered prose well | 220px right sticky TOC rail.

Left Rail: Vertical hairline reading-progress bar, publication date, Pillar badge, read time, and Era Badge (2026 SPEC for 2026+ posts vs. ARCHIVE NOTE · 2020 for 2019–2023 posts).

Center Well: Article header, optional <ValidationScope/> spec box (auto-rendered when validation frontmatter exists), prose with astro-expressive-code blocks (dual theme aftertone / paper, terminal titles, one-click copy), and compact Adjacent Signals footer cards.

Right Rail: "On This Signal" scroll-spy Table of Contents highlighting active h2/h3 sections via IntersectionObserver.

Mobile (< 1180px): Collapses to a single column with a top horizontal reading-progress hairline and a collapsible <details> Table of Contents above the first paragraph.

4.4 Experiments Hub (/experiments) — "The Signal Lab"
Left-to-Right Editorial Showcase Cards: Full-width horizontal cards (desktop 45% text left / 55% visual right; stacked visual-below-text on mobile to preserve explanation-first reading order):

Left: EXP // 01 index, title, concise 2-sentence interaction brief, technical tags (Canvas 2D, Web Audio, Telemetry Replay), and Launch Instrument → CTA.

Right: Crisp custom visual preview frame matching each experiment's palette (GPU memory/token timeline for Local LLM Observatory; cyan-emerald sonar bathymetry rings for Kestrel Sound; warm phosphor shortwave tuning dial for Aftertone).

Shared Experiment Chrome (ExperimentLayout.astro):

Enforce a sticky mobile action/status tray (position: sticky; bottom: 0; padding-bottom: env(safe-area-inset-bottom)) inside interactive experiments so newly unlocked progression states (e.g., Aftertone post-5th-save action) are immediately visible at 390x844 without requiring blind scrolling.

4.5 Tools & Downloads (/tools) — Engineering Spec Cards
Retain the validated category jump-bar and scannable contrast surface while upgrading each tool entry to a structured Spec Card:

Card Header: Tool title + version mono badge (v1.6.2-r5) + semantic safety pill (READ-ONLY, PREVIEW + APPLY, OBSERVE DEFAULT).

Card Body: 2-column specification grid (Requirements | Scope & Validation).

Card Footer: Primary Read Guide → link, distinct high-contrast download chips (Script ↓, README ↓, Example CSV ↓, ZIP ↓), and an inline SHA-256 verification popover/copy button where checksums exist.

4.6 Signal Archive (/posts) & ⌘K Command Palette
Archive Facet Bar: Instant zero-reload client filtering by:

Pillar chips (All, plus the 5 Pillars)

Quick toggles (Includes Downloadable Tool, 2026+ Only)

Live count badge (Showing 18 of 76 signals)

URL query-param sync (?pillar=local-ai-agents&tools=1) so filtered views are shareable.

⌘K Command Palette (CommandPalette.astro): Powered by Pagefind static WASM index (dist/pagefind/). Supports:

Full-text search across articles, SQL/code snippets, tools, and experiments.

Direct command actions (> Theme: Aftertone, > Theme: Field Paper, > Theme: Polar Night, > Theme: Cyberpunk [Legacy], > Theme: Moss & Brass [Legacy], > Toggle Ambient Audio).

5. Static Build Pipeline & Tooling Additions
Add/configure the following in package.json, astro.config.mjs, and .github/workflows/:

Fonts: @fontsource/space-grotesk, @fontsource/inter, @fontsource/jetbrains-mono.

Code Highlighting: astro-expressive-code configured with dual themes mapped to [data-theme="paper"] vs. dark themes (aftertone, polar) via themeCssSelector.

Static Full-Text Search: pagefind invoked post-build:

JSON
"scripts": {
  "build": "astro check && astro build && npx pagefind --site dist"
}
Tag article/tool main regions with data-pagefind-body and exclude nav/footer/TOC with data-pagefind-ignore.

Build-Time OpenGraph Cards: Add satori + @resvg/resvg-js with a static endpoint src/pages/og/[...slug].png.ts generating 1200x630 Aftertone-styled social preview PNGs (brand header, Pillar tag, display title, read time) wired into <meta property="og:image"> in BaseLayout.astro.

6. Phased Execution Plan & Verification Gates
Execute sequentially. Do not start Phase N+1 until all acceptance checks for Phase N pass with verifiable output.

Phase 0 — Repository Discovery & Baseline Capture
Tasks:

Audit repo structure (astro.config.*, package.json, src/layouts/, src/pages/, src/content/, public/, .github/workflows/).

Snapshot all current built routes in dist/ to tmp/baseline-routes.txt so URL regressions can be diffed deterministically.

Confirm current Chippy/Operator image path (or missing reference) and existing Soul Slash Synthesis track list data source.

Gate 0: Produce a short reconciliation note listing actual repo paths, Astro version, permalink format, and any required adjustments to this spec before editing code.

Phase 1 — Unified Layout Shell & Taxonomy Migration
Tasks:

Consolidate all page headers/nav/footers into a single BaseLayout.astro with inline FOUC-free theme script.

Implement src/content.config.ts with the 5-pillar enum and no-collision refinement.

Run a deterministic taxonomy migration script mapping all existing posts to the 5 Pillars + ~32 canonical tags; backfill clean 1-sentence description fields for any 2019–2023 post missing one or pulling raw intro headings.

Generate static redirect pages for all retired /categories/* and /tags/* URLs.

Verify RSS feed generation emits zero duplicate category/tag labels.

Gate 1 (Evidence Required):

astro check && astro build exits 0.

Route diff confirms 100% of baseline article, tool, and experiment URLs remain present in dist/, and retired taxonomy URLs resolve to valid redirect HTML files.

Scripted check on generated rss.xml confirms zero duplicate <category> entries per <item> and exact item limit behavior.

Phase 2 — Design Tokens, Typography & Expressive Code
Tasks:

Implement src/styles/tokens.css (aftertone, paper, polar, plus legacy Easter-egg token blocks) and global reset/base typography using self-hosted @fontsource fonts.

Configure astro-expressive-code with dual dark/light theme selectors.

Build shared UI primitives: Badge.astro, SpecCard.astro, ValidationScope.astro.

Gate 2 (Evidence Required):

Clean build (0 errors, zero external font requests in browser network log).

Contrast audit confirms primary text, secondary text, badges, and buttons pass WCAG AA in both aftertone and paper modes.

Phase 3 — Flagship Page Implementations & Persistent Audio
Tasks:

Enable <ClientRouter/> in BaseLayout.astro and wire astro:page-load / astro:after-swap lifecycle hooks.

Implement AmbientPlayer.astro with transition:persist="ambient-player" using the 9 Soul Slash Synthesis tracks.

Rebuild / Homepage (Asymmetric Hero + 2D Canvas <SignalScope/> + fixed Operator/Chippy toggle, Field Toolbox strip, Signal Lab preview band, Latest Transmissions ledger, Repository Relay with proper AletheiaUC private handling).

Rebuild PostLayout.astro (3-column editorial grid, sticky progress rail, Era badge, scroll-spy TOC, <ValidationScope/>).

Rebuild /experiments (left-to-right showcase cards + custom visual previews) and add sticky mobile status/action chrome to ExperimentLayout.astro.

Upgrade /tools to Engineering Spec Cards (with SHA-256 copy popover) and /posts with URL-synced client facet filtering.

Gate 3 (Evidence Required):

Navigation from / → article → /tools → /experiments keeps AmbientPlayer mounted without DOM reset and preserves selected theme.

Zero Artwork unavailable fallbacks and zero dead outbound links on private repos.

Phase 4 — Pagefind ⌘K, Build-Time OG Cards & Browser Acceptance Matrix
Tasks:

Integrate pagefind into build script and wire CommandPalette.astro (⌘K / Ctrl+K) with search + theme/audio commands.

Implement build-time Satori OG card generation (/og/[...slug].png) and wire <meta property="og:image">.

Run automated Playwright browser acceptance across every flagship route.

Gate 4 (Browser Acceptance Matrix — Required Before Completion):
Test at 1440×900 (desktop) and 390×844 (mobile) in both aftertone and paper themes across /, /posts, /tools, /experiments, one 2026 article, one 2019–2023 archive article, and Aftertone interactive progression:

document.documentElement.scrollWidth <= window.innerWidth (zero horizontal overflow).

Above-the-fold inspection at 390×844 confirms primary headline/controls and Aftertone final-state action cue are visible without blind scrolling.

Zero console errors, zero failed network requests (status >= 400), zero broken images (naturalWidth === 0).

Keyboard-only test: open ⌘K, search for "BLF", navigate to result; switch theme; toggle ambient player; jump to a Toolbox category and verify download link integrity.

7. Ready-to-Paste Antigravity Starter Prompt
Paste this into Antigravity with Gemini Carbon selected (and attach the three mockup images if you want visual grounding):

Read docs/aftertone-redesign-spec.md and treat it as our authoritative design and engineering specification. Start in Planning Mode on Phase 0 only: inspect the repository structure, astro.config.*, package.json, existing layouts, content schemas, RSS generator, and current built routes. Do not modify any files yet. Return a concise Phase 0 Reconciliation Report mapping the spec to exact repository paths, flagging any URL/permalink or script constraints, and proposing the concrete Phase 1 Implementation Plan and Task List for my approval.

If you want to keep the visual rules active across future blog updates after the redesign ships, you can also copy Sections 1 and 2 into .agents/rules/design-system.md so Antigravity enforces the tokens and taxonomy guardrails automatically on every future session.
