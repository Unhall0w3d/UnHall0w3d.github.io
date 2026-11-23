---
title: "Evaluating 15 AI Skills Against My Existing Codex Setup"
date: 2026-11-23T12:00:00-05:00
description: "Testing 15 AI skills against an existing Codex setup, tracing their upstream sources, and deciding which review, design, and operator handoff rules to keep."
categories:
  - General
  - Automation
tags:
  - Codex
  - Artificial Intelligence
  - Automation
  - Software Development
---

At 14:06, both nodes reported healthy on retry. At 14:07, the operator approved Gate 4. At 14:10, the ticket still showed Stage 4 in progress. Given those records, my usual Codex workflow told the operator to update the ticket, then run `route inspect`. With Roost’s runbook guidance, the agent asked the operator to settle the discrepancy and held the Stage 5 command.

Both answers read the health check correctly. The difference was what the operator could copy and run while the ticket was still open. That simulated handoff accounts for one of the changes I made after testing 15 AI skills on November 21 and 22, 2026.

I started with ten entries from Alyn’s weekly list and five repositories I’d collected separately. I wanted to know which ones improved work I already do in Codex. I installed the five-skill REA package, added individual checks to existing workflows, and kept several of my current defaults. The starting configuration matters to those decisions. [Alyn’s weekly list](https://alyn.dev/top-10-ai-skills-this-week)

## What the Baseline Included

An ordinary Sol session here runs under my `AGENTS.md`, which covers implementation, delegation, and verification. For the design and prompt-intake comparisons, ordinary Sol meant the model working under those instructions. For a review task, the baseline could include a named local skill. The following are custom adaptations, so someone running a fresh Codex setup would need to account for that difference when comparing results.

| Existing local skill | Upstream source | What it did in these trials |
|---|---|---|
| `completion-evidence-review` | Superpowers’ *Verification Before Completion*. A later reference adapts Trail of Bits’ *Post-Patch Validation*. | Checks which completion claims the evidence supports. Used in the Bearpaws and Cloudflare trials. This is where the Roost handoff rule now lives. |
| `change-impact-review` | Trail of Bits’ *Differential Review* | Traces a change through its callers and checks for regressions. This was the single reviewer in the RSS comparison. |
| `browser-acceptance` | Anthropic’s *Webapp Testing* | Exercises the rendered workflow. We added a mobile check here after the Impeccable trial. |
| `complex-debugging` | Superpowers’ *Systematic Debugging*, with a separate reference adapted from Trail of Bits’ *Variant Analysis* | Handles recurring failures, including the browser-restore scenario in the Superpowers routing test. |
| `controlled-evaluation` | Anthropic’s *Skill Creator* and the evaluation skill from *Agent Skills for Context Engineering* | Defines the comparison, acceptance criteria, and evidence to retain. |

The local planning skill also descends from Superpowers’ *Writing Plans*. It predates these trials. We tested how the suite routed incoming work, so planning quality wasn’t part of its score. [Superpowers](https://github.com/obra/superpowers) · [Trail of Bits skills](https://github.com/trailofbits/skills) · [Anthropic skills](https://github.com/anthropics/skills) · [Agent Skills for Context Engineering](https://github.com/muratcankoylan/Agent-Skills-for-Context-Engineering)

Where we ran a paired comparison, both workflows received the same task. We used disposable fixtures or copies of blog components and scored the behavior the brief called for. Four short tests at the end shared one baseline session, while each guided response came from a fresh session. Counts below are per task or per response as indicated. There were too few independent runs to rank models or estimate a general productivity gain.

## Three Changes to the Existing Workflow

**Roost.** We scored six first replies across three operator handoffs. The existing workflow passed two of three cases. The guided workflow passed all three. In the opening example, the baseline even put the steps in the right order. It still supplied the executable command before the records agreed. I added one instruction to `completion-evidence-review`: reconcile the working record and tracker before handing over the next executable command. A successful retry and an existing approval remain valid. Neither needs to be repeated to fix the ticket. [Roost](https://github.com/Beakpoint-Insights/roost)

I also kept Roost’s short retrospective format. Applying it to the repair-café test exposed a runner that could exit successfully after a valid form submission failed. We checked the corrected runner against both versions of the page. It exited 1 on the broken build and 0 on the delivered build at both viewport widths. Those two practices covered what I wanted from Roost, so I skipped the suite installation.

**ECC Agent Harness Construction.** We asked for a read-only build-status tool. Both responses distinguished a pending job from an unknown ID, bounded retries, and excluded private filenames from errors. The guided response also identified a race at submission. If a submitter receives the ID before the status registry can resolve it, an immediate lookup reports a missing job that was just accepted.

I added the rule to my global `AGENTS.md`. Return the run ID once the status lookup can resolve it. The acceptance check is the first lookup with the ID exactly as returned, whether the job is queued or has already finished. This was a tool-design exercise. Applying the rule to a particular queue still requires a runtime check. [Agent Harness Construction](https://github.com/affaan-m/ECC/tree/4adeee6732a12d1540f49a4d50a38ce8c97f9a53/skills/agent-harness-construction)

**Impeccable.** Both reviewers found both planted defects on the Observatory page. On Aftertone, the guided reviewer also caught the state after the fifth save. Browser replay placed the newly available action at y=1103 in an 844-pixel-high viewport. A browser test can scroll to the button and click it. A person holding the phone first needs some indication that another action is available.

I added that distinction to `browser-acceptance`. Exercise the final action at the narrowest supported viewport and inspect what the user can see **before scrolling**. We also tested creation with one repair-café ticket page per workflow. The ordinary build failed on valid input. The guided build created, persisted, and downloaded the ticket, but its mobile handoff needed a correction. The corrected build passed at 390 and 1440 pixels. Volunteer usability remains untested. I kept the targeted check and left the broader design guidance optional. [Impeccable](https://github.com/pbakaus/impeccable)

## Review Findings and Completion Claims

**Bearpaws** prompted a test of the reviewer I already had. In the first case, an invoice export dropped leading zeros despite a passing mocked test. The reviewer held completion open. In the control case, the requested invoice change worked and an older shipping defect remained. The reviewer reported that defect separately and accepted the invoice change. [Bearpaws](https://github.com/thepragmaticbear/bearpaws)

The harder case used two bay labels, `North Annex 12 East` and `North Annex 12 West`. The payload contained both values correctly. Only the independent reviewer checked the receiving terminal, which displayed the first 12 characters of each. The implementing agent received the review and then handled additional tasks. We gave it no instruction to record the finding. It still reported the unresolved display issue in the final handoff. I kept the existing completion review. We never ran a Bearpaws arm, so these cases establish what the local skill handled.

**Matt Pocock’s Code Review** got a direct comparison on a disposable copy of this blog’s RSS handler. We planted three issues. The feed returned 19 posts against a limit of 20. A label present in both categories and tags appeared twice. A named constant violated the repository’s casing convention. Our single change-impact reviewer found all three. Pocock’s specification reviewer found both behavior defects, and its standards reviewer caught the naming violation. All three reviewers used GPT-6.2 Sol at medium effort. On this change the extra reviewer bought separate reports with the same findings. I kept the single reviewer as the default. [Code Review](https://github.com/mattpocock/skills/tree/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills/engineering/code-review)

**Cloudflare Security Audit.** The upstream validator accepted a well-formed unresolved finding that misquoted the source value. In the follow-up, eight records passed schema validation. Five contained seeded errors. Fresh reviewers using either our completion guidance or Cloudflare’s written verification guidance caught all five and accepted the other three on each of two passes. I kept our existing verification step. This covered the reporting stage for unresolved findings. The rest of Cloudflare’s audit workflow remains outside this comparison. [Cloudflare Security Audit](https://github.com/cloudflare/security-audit-skill)

## Two Blind Design Reviews on the Blog

We gave ordinary Sol, Design Taste Frontend, and Hallmark the same Experiments index brief. All three first-pass layouts and the existing page passed the desktop and phone checks for content, artwork, overflow, and keyboard links. I chose A before seeing the mapping. Design Taste put the description on the left and the image on the right. Reading left to right, I got the explanation before the artwork. [Design Taste Frontend](https://github.com/Leonxlnx/taste-skill) · [Hallmark](https://github.com/Nutlope/hallmark/tree/04977e15f3dfd6ee4b74c887dac3eb52665d6c92)

The Tools index had a different job. It contained ten tools and 56 links. We checked keyboard navigation, a jump to a category, navigation to a guide, and a ZIP download whose contents matched the local file. I leaned toward C and asked to see all three layouts in Aftertone before deciding. C’s sections were easier to scan, and the contrasting table backgrounds made the downloads stand out. It read like a tools download page. C was ordinary Sol.

Design Taste and ordinary Sol each received one first choice across two briefs. Hallmark passed the functional checks on both. Viewing Tools in a second theme gave me a better basis for that choice, but it was still the same brief. I kept design guidance available for comparisons.

## Prompt Intake, Ideation, and Skill Selection

| Candidate | Test and result | Decision |
|---|---|---|
| Prompter | Sixteen blog requests per workflow, repeated in a different order. Ordinary intake met the criteria on 32/32 replies. Guided intake scored 31/32 and requested seven unnecessary confirmations. Four downstream source edits matched exactly. | Keep ordinary intake. Model capability might affect the value of prompt coaching, but we tested no other model tier. |
| Solo Venturing | After a two-case pilot, each workflow answered four new founder scenarios twice. Both scored 8/8 on each measure: making a decision, generating distinct options, and proposing a feasible test. The briefs explicitly asked for alternatives. | Skip installation. Keep the question about the smallest experiment that would change the decision. |
| Ponytail | Return the first five public downloads from a potentially unbounded input. Both implementations reused the existing visibility helper with Python’s `islice`. The code matched byte for byte and passed the same three stream checks. | Keep the existing implementation policy, which already favors a suitable helper and the standard library. |
| Using Superpowers | Both workflows went straight to the source for a heading edit and selected evidence-led debugging plus browser replay for a recurring export failure. | Keep local routing and the existing Superpowers adaptations. The additional catalog check produced the same first actions. |
| Anthropic Academy Guide | The catalog fetch returned HTTP 403. Ordinary Sol named a course and qualified its availability. The guided reply linked the official Claude Code learning hub. Both supplied a team exercise and handled an unrelated sorting task without recommending a course. | Use the official hub as a fallback in training material. The 403 leaves the specific course unverified. Matching courses against a working catalog still needs a test. |

One Solo Venturing scenario helps explain the ideation result. In a synthetic case about pottery kilns, seven of eight potters who missed a firing already knew which kiln had time available. The mismatch involved clay, glaze, or firing temperature. Adding map filters would only help if they captured the conditions under which an operator could accept the work. Asking what evidence would change that decision was the part I wanted to reuse. [Solo Venturing](https://github.com/michael-ilic/solo-venturing) · [Prompter](https://github.com/Terryc21/prompter) · [Ponytail](https://github.com/DietrichGebert/ponytail) · [Academy Guide](https://github.com/anthropics/skills/tree/e4bb5d960d87126ff3b3a8af1a104b7db67560ba/skills/academy-guide)

## What I Installed and What Remains Open

I already had a reverse-engineering skill through the local modding toolkit. The five upstream **Reverse Engineer Anything** skills were missing from my Codex skills directory. We installed all five, then used a trial-local copy of REA CLI 6.10.1 to inspect a synthetic NuGet package offline. The reported package ID, version, file list, and SHA-256 matched an independent standard-library read. I kept REA for targeted package inspection. That result covers one CLI provider. The MCP connection remains unverified. [Reverse Engineer Anything](https://github.com/morluto/rea/tree/6ce7f932bdfa0a09e227361ecb3bef02853c684e/.agents/skills)

For the **Product Demo Agent Toolkit**, we used a temporary provider to supply a line of local Kokoro narration. The toolkit located “receipt” at 0.65 seconds and “select the model” at 1.40 seconds. That establishes word lookup for the supplied audio. The open test is to record the browser, render the clip, and check whether the visible actions land on those cues. I’m holding the toolkit decision until there’s a clip to review. [Product Demo Agent Toolkit](https://github.com/chapter-dev-pty-ltd/product-demo-agent-toolkit)
