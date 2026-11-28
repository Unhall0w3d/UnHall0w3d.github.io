---
trigger: always_on
description: Content schema, 5-Pillar taxonomy, canonical tag vocabulary, .html permalink preservation, private repository linking, and build validation rules for NOC Thoughts.
---

# NOC Thoughts — Taxonomy, Permalink & Validation Guardrails

Follow these rules whenever adding or editing posts (`src/content/posts/`), tools (`src/config/tools.ts`), experiments (`src/experiments/`), RSS feeds, or routing.

## 1. Permalinks & Inbound URL Preservation

- **`.html` Canonical URLs**: All public routes emit `.html` files (`/posts.html`, `/tools.html`, `/experiments.html`, `/about.html`, `/YYYY/MM/DD/slug.html`). Canonical `<link rel="canonical">` tags and `sitemap-0.xml` entries must use `.html` (except `/`).
- **Date-Derived Post Permalinks**: `postUrl()` in `src/lib/posts.ts` computes `/YYYY/MM/DD/slug.html` from frontmatter `pubDate` formatted in `America/New_York` (not the filename prefix). Never alter existing `pubDate` timestamps or offsets on published posts, or inbound URLs will shift and fail `docs/rebuild/legacy-sitemap.xml` validation.
- **Static Redirects for Retired Slugs**: Never delete an inbound article, tool, experiment, `/categories/*`, or `/tags/*` URL. Any retired category or tag slug must remain mapped in `RETIRED_CATEGORY_REDIRECTS` / `RETIRED_TAG_REDIRECTS` in `src/config/taxonomy.ts` so Astro emits a static `<meta http-equiv="refresh">` + `<link rel="canonical">` redirect page without redirect chains.

## 2. Content Schema & Taxonomy (`src/content.config.ts` & `src/config/taxonomy.ts`)

- **Astro 7 Zod Import**: Import `z` from `"astro/zod"` (not `"astro:content"`).
- **Required Post Frontmatter**:
  - `title`: non-empty string
  - `description`: clean 1-sentence summary (`10..240` chars; never raw Markdown headings)
  - `pubDate`: ISO timestamp (`updatedDate` optional)
  - `pillar`: strict 5-value enum:
    1. `unified-communications` (Unified Communications)
    2. `automation-tooling` (Automation & Tooling)
    3. `local-ai-agents` (Local AI & Agents)
    4. `systems-infrastructure` (Systems & Infrastructure)
    5. `field-log-craft` (Field Log & Craft)
  - `tags`: array of lowercase canonical slugs matching `/^[a-z0-9-]+$/` (max `6`), preferring the established ~31-tag lexicon in `src/config/taxonomy.ts` (`CANONICAL_TAG_LABELS`).
  - `hasTool`: `true` when paired with an entry in `src/config/tools.ts`.
  - `validation` (optional): `{ posture: "read-only" | "preview-first" | "observe-default" | "lab-verified" | "reference", testedOn: string, limits?: string }`.
- **Zero Pillar/Tag Collisions**: A label or slug must never appear as both `pillar` and an entry in `tags` on the same post, nor duplicate `<category>` elements in `/feed.xml` or `/rss.xml`.

## 3. Private Repository & Download Integrity Rules

- **Private Repositories**: Private repositories (such as `AletheiaUC` and `Soul/` / `soul-slash`) must **never** link outbound to `https://github.com/Unhall0w3d/<private-repo>` in `RepositoryRelay.astro` or Markdown prose. Render `STATUS // PRIVATE` and link internally to the architecture write-up or canonical tag archive (`READ ARCHITECTURE →`).
- **Build & Validation Gate**: Before committing or deploying changes, run `npm run validate` (executes Python download release parity tests, site validator unit tests, `astro check`, `astro build` with Satori OG PNGs, `pagefind --site dist`, `build-sitemap.mjs`, and `validate-site.mjs`) alongside `node scripts/verify-gate2.mjs`.
