# NOC Thoughts

NOC Thoughts is Kenneth Perry's technical field journal: hard-won fixes, useful scripts, and notes from the stranger corners of network operations, unified communications, automation, and Linux.

The site is built with [Astro](https://astro.build/) and published through GitHub Pages at [nocthoughts.com](https://nocthoughts.com).

## Local development

The project requires Node.js 24 and npm.

```sh
npm install
npm run dev
```

Astro will print the local preview address. Before committing a change, run:

```sh
npm run validate
```

This builds the complete site and checks its links, assets, established URLs, and post archive.

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

Place screenshots and other static media in `public/assets/images`, then reference them from Markdown as `/assets/images/filename.png`.

Posts use the established NOC Thoughts URL format:

```text
/YYYY/MM/DD/short-descriptive-slug.html
```

## Repository map

- `src/config/site.ts` — site identity, verification, social, analytics, and advertising identifiers
- `src/content/posts` — published articles
- `src/content/pages` — About, privacy, and other standalone page copy
- `src/layouts` — shared page and post templates
- `src/styles/global.css` — the site's visual system
- `public` — screenshots, icons, robots, AdSense, domain, and verification files
- `scripts/validate-site.mjs` — archive and link-integrity checks
- `.github/workflows/deploy.yml` — GitHub Pages build and deployment

## Deployment

Pull requests run the complete validation and build process. The live site is deployed only after changes are merged into `master`.
