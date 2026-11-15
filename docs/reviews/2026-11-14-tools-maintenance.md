# Tools directory and maintenance review

Date: 2026-11-14. Scope: site resources, local script structure, published guides,
and packaging. This is a prioritized maintenance assessment, not a new runtime
qualification of the UC tools. No operational script was changed during this review.
External repository implementations were not inspected; findings about those tools
are based on the site's published articles.

## Directory implemented

Eight published resources are grouped by task at `/tools.html`: two CUCM phone
updaters, three read-only SQL guides, SmartZone backup retrieval, the analog
stuck-call guard, and the Codex workflow reference. The directory resolves each
entry against published content at build time; a missing or draft guide fails
the build. Requirements and verification limits appear beside each resource.
The UC DRS candidate remains excluded pending the operator's testing and publication.

The homepage introduces the toolbox before recent posts, then social/music and
repositories. The music player is a native details disclosure, closed on load.
Opening it does not initialize YouTube or autoplay. Closing it pauses playback
and cancels pending autoplay; late playback callbacks are also guarded.

## Proposed maintenance order

| Priority | Resource | Evidence and proposed work | Acceptance boundary |
| --- | --- | --- | --- |
| 1 | Download packaging | The Python source and README are duplicated under `scripts/` and `public/assets/downloads/`; the DRS candidate also has a ZIP and checksums. Establish a small release manifest and a repeatable copy/hash check from canonical source. | Download bytes and previews match the tested source; ZIP membership and versions agree; unpublished resources do not enter the directory. |
| 1 | Codex configuration packages | Three generations remain under `codex-multi-agent-workflow`, `codex-cost-aware-multi-agent-workflow`, and `codex-astra-multi-agent-workflow`. The latest package still describes a September model catalog and differing policy/config primaries. Create one reviewed current package, with older examples explicitly dated and superseded. | Validate role/config syntax and current callable models; sanitize private configuration; preserve old article links and their historical context. This review does not qualify new model routing. |
| 2 | CUCM auto-answer | `AXL_VERSION = "15.0"` is fixed, whereas the BLF tool negotiates a schema. The README records live `ALREADY_OK` checks but no live write with this revision. Review schema negotiation and consistent connection/error UX, then qualify one approved write. | Preserve shared-DN checks, exact target identity, durable write intent, and read-back. Do not infer live write qualification from already-correct results. |
| 2 | CUCM BLF updater and auto-answer shared conventions | Both validate targets, create sessions and journals, and perform preflight/write/read-back. BLF uses Zeep/toolkit handling; auto-answer uses direct SOAP and only requests. Standardize help, exit/status documentation, journal terminology, and connection behavior before deciding whether a shared module is worthwhile. | Keep the line-update and full-BLF-collection preservation algorithms separate. Preserve standalone usability and avoid adding Zeep to auto-answer solely for code reuse. Any journal schema change needs a compatibility/version plan. |
| 2 | CUCM SQL guides | Three useful audit procedures are embedded in articles. Offer a curated read-only `.sql` pack with a query index, explicit replacement values, sample outputs, and the existing interpretation limits. | Queries agree with the articles; no mutation statements; placeholders and configured-versus-live behavior are clear. Do not build a broad execution framework just to distribute queries. |
| 3 | UC DRS v1.6 candidate | The 1,298-line script combines profile/CSV handling, credentials, SSH/DRS orchestration, and local Windows SFTP provisioning. Existing validation records 89 core and 53 local-setup simulated checks, with native Windows/Cisco qualification pending. Complete operator testing first; then consider separating internal responsibilities without changing the entry point. | Keep existing checks, privilege boundaries, credential isolation, cleanup, and interrupted-write semantics. Local simulation is not proof of SFTP authentication, a completed backup, or a restore. |
| 3 | Legacy UC Toolbelt / phone WebGUI collectors | The 2020 Toolbelt article describes a move from model-dependent HTML parsing to XML endpoints and combines discovery with log collection. Inventory the current external repository before promoting these utilities alongside newer tools. | Assess supported phone/firmware endpoints, authentication, timeouts, bounded downloads, safe paths, and subprocess usage. Choose a maintained successor rather than retaining multiple overlapping collectors. These are review targets, not confirmed current defects. |
| 3 | RUCKUS SmartZone retriever | The published guide describes Windows DPAPI credential export, scheduled runs, API-style web endpoints, and per-run/latest JSON status. Review the current external source for host identity, partial-download handling, completion semantics, and task-account setup. | Align operator conventions with DRS where useful, but do not merge HTTPS backup retrieval with SSH backup configuration. Credential migration needs its own plan; the mechanisms differ. |
| 3 | Analog stuck-call guard v1.0.6 | The Tcl policy and deployment notes live in public downloads. It intentionally targets one validated FXO loop-start state contract. Add a canonical source/test location if the originating project does not already provide one. | Preserve observe-only default, exact CallID/port correlation, cooldown and recovery checks. Use captured/synthetic CLI fixtures. Do not generalize FXO behavior to FXS. |

## Recommended first maintenance slice

1. Establish a source-to-download manifest and parity check for the existing
   Python artifacts; add the DRS package only when its release is ready.
2. Reconcile and label the public Codex configuration generations.
3. Align CUCM tool documentation and connection conventions, then separately
   propose any schema-negotiation or shared-code changes with preservation tests.

The directory is a curated entry point, not a certification badge or a replacement
for each tool's README. Keep requirements and evidence current when artifacts change.

## Validation of this redesign

- `npm run validate`: passed; 207 HTML files, 74 published posts, 57 legacy
  URLs, local links/assets, and a sitemap with 141 indexable canonical URLs.
- `node scripts/test-music-player.mjs`: three checks passed for opening without
  autoplay, closing before the YouTube API is ready, and late playback callbacks.
- Browser: directory/category navigation, desktop and 390px mobile layouts,
  keyboard player expansion, real YouTube playback, and pause/Chippy reset on
  collapse were exercised. No console warnings/errors were captured in those checks.
- A BLF Python download through the directory matched canonical source bytes.
  Both published Python scripts and their READMEs also matched their source copies.
- `git diff --check`: passed. No operational scripts or advertising integrations
  changed. No publication performed; the preview server was stopped after testing.

External codebases still need their own inspection before any proposed refactor.
