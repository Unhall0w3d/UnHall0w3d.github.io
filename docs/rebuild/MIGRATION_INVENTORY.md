# Legacy migration inventory

> Migration status: completed on `codex/site-rebuild`. This remains the preservation checklist for review before merge.

Source of record during migration: `/home/bhones/Projects/blog/blogbackup`

The backup is a clean Git repository at commit `4738fe4fdc37427bc826c7b5061df6ba8f0b709d`.

## Content baseline

- 52 Markdown posts
- 103 files in `assets/images`
- 90 distinct post/about-page references to internal image assets
- Five posts using Jekyll `{% highlight %}` blocks
- No post-level scripts, iframes, video, audio, object, or embed elements
- All posts use the same seven front-matter keys: title, layout, classes, date, excerpt separator, categories, and tags

## Preserve exactly

- Published post titles, dates, body text, categories, and tags
- Existing `/YYYY/MM/DD/slug.html` URLs
- Screenshot filenames and case
- `/posts/`, `/categories/`, `/tags/`, `/about/`, `/privacypolicy.html`, `/404.html`
- `CNAME`, `ads.txt`, verification files, favicon family, and application icons
- Google AdSense publisher ID and GA4 measurement ID
- Google and Bing verification values
- Author identity and social destinations

## Transform deliberately

- Jekyll image expressions into portable root-relative image URLs
- Jekyll highlight blocks into fenced Markdown code blocks
- Minimal Mistakes image classes into semantic figures or compatibility classes
- `layout: single` and `classes: wide` into the new content schema
- Current SEO configuration into a generator-independent site configuration

## Regenerate rather than migrate

- Sitemap
- RSS feed
- Search index
- Canonical, Open Graph, Twitter card, and JSON-LD output
- Related-post lists and reading-time values
- Responsive image derivatives

## Do not carry forward

- `remote_theme` and Minimal Mistakes skin settings
- Copied Minimal Mistakes layouts/includes
- Theme JavaScript, Lunr assets, Font Awesome CDN dependency
- Stale hand-authored `sitemap.xml`
- Duplicate homepage sources
- Legacy Universal Analytics configuration
- Unused Jekyll plugins

## Required verification before cutover

- Old and new route sets match
- Every referenced local asset exists with exact case
- Every post builds and has a canonical URL
- Sitemap and feed include the 2026 post
- No Minimal Mistakes asset or include remains
- Production-only integrations do not load in local or preview builds
- Desktop and mobile visual review covers every page family
- Keyboard navigation, reduced motion, contrast, and print output are checked
