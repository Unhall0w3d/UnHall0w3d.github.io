# NOC Thoughts

NOC Thoughts is a static Astro site deployed to GitHub Pages at [nocthoughts.com](https://nocthoughts.com). The visual system, layouts, archive, taxonomy, SEO, and deployment pipeline are owned by this repository and do not depend on Jekyll or Minimal Mistakes.

## Local development

Requirements: Node.js 24 and npm.

```sh
npm install
npm run dev
```

Astro will print the local preview address. Use `npm run validate` before committing; it builds the complete site and verifies all local links, assets, legacy URLs, and the expected post count.

## Add a post

Create a Markdown file in `src/content/posts` using this filename convention:

```text
YYYY-MM-DD-short-descriptive-slug.md
```

Start it with:

```yaml
---
title: "Post title"
date: 2026-07-13T08:00:00-05:00
categories:
  - Primary category
tags:
  - Specific technology
---
```

Place screenshots and other static media in `public/assets/images`, then reference them from Markdown as `/assets/images/filename.png`. The generated post URL retains the historical NOC Thoughts format: `/YYYY/MM/DD/short-descriptive-slug.html`.

## Important locations

- `src/config/site.ts` — site identity, verification, social, analytics, and advertising identifiers
- `src/content/posts` — the complete post archive
- `src/content/pages` — About, privacy, and retained page copy
- `src/layouts` — the owned page and post templates
- `src/styles/global.css` — the owned design system
- `public` — screenshots, icons, domain, robots, AdSense, and verification files
- `scripts/validate-site.mjs` — migration and link-integrity validation
- `.github/workflows/deploy.yml` — GitHub Pages build and deployment

## Deployment safety

Pull requests run the complete build. The deployment job runs only after changes reach `master`; work pushed to feature branches cannot replace the live site.
