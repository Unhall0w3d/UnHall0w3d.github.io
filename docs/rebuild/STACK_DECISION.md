# Rebuild stack decision

## Decision

Build the next NOC Thoughts site with Astro 7 as a statically generated site and deploy the compiled output to GitHub Pages through GitHub Actions.

Astro is pinned in `package.json`; upgrades will be reviewed rather than inherited implicitly.

## Why Astro

- Static HTML is the default output, which matches GitHub Pages and keeps the public site resilient.
- Content collections can validate post metadata before deployment.
- Components give us complete ownership of page structure without requiring React or another browser framework.
- CSS and JavaScript remain ordinary project assets under our control.
- New design assets can use Astro's image pipeline while legacy screenshots remain at their stable URLs.
- GitHub Pages is an officially documented deployment target.

## Alternatives considered

### Eleventy

Eleventy is the strongest fallback. It is smaller and highly flexible, and its Liquid support would ease parts of the migration. It offers less built-in content validation and image/component infrastructure, so more of the foundation would need to be assembled and maintained locally.

### Jekyll 4

Modern Jekyll would minimize content conversion. It would also retain more of the Ruby/Jekyll-specific publishing model that this rebuild is intended to reconsider. It remains a viable fallback if the Astro migration reveals an unexpected content-compatibility problem.

## Constraints

- Preserve every published URL unless a redirect is explicitly created and tested.
- Do not copy theme markup or styles from Minimal Mistakes.
- Keep legacy posts and screenshots intact during initial migration.
- Keep content usable without client-side JavaScript.
- Isolate analytics, advertising, consent, and verification from visual components.
