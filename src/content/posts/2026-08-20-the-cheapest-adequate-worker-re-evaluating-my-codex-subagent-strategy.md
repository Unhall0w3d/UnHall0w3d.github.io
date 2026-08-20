---
title: "The Cheapest Adequate Worker: Re-Evaluating My Codex Subagent Strategy"
date: 2026-08-20T12:00:00-04:00
categories:
  - General
  - Automation
tags:
  - Codex
  - Artificial Intelligence
  - Automation
  - Software Development
  - Subagents
description: "Why I re-tested a Codex multi-agent strategy one day after publishing it, what Luna, Terra, Spark, and Sol found in two real repositories, and the cost-aware routing policy that replaced my first version."
draft: false
---

## A Confident Article Is Still A Snapshot

Yesterday I published
[One Architect, Several Workers: How I Use Codex Sol](/2026/08/19/one-architect-several-workers-how-i-use-codex-sol.html).
It described a workflow I was comfortable enough with to turn into a reusable
`AGENTS.md`: Sol owned architecture and integration, Spark mapped repositories,
Luna handled efficient bounded work, and Terra handled ordinary implementation
and debugging.

I still agree with its central premise. Delegation should be bounded. Trust
belongs to evidence from one assignment, not to a model's name. Sensitive and
high-consequence decisions stay with the primary agent. A worker does not gain
authority merely because it can edit a file.

The routing table changed anyway.<!--more-->

That is not an embarrassment hidden behind a silent edit. It is the useful part
of the story.

A process document is a model of how work should move. The day after publishing
ours, we acquired better evidence about cost, allowance behavior, and what the
workers could actually do in our repositories. Keeping the old table because I
had described it confidently would have converted documentation into ego
preservation.

## What Triggered The Re-Evaluation

Spark has a separate visible weekly allowance in Codex. We had treated that
allowance cautiously, raising its delegation threshold as it declined. In
practice, a concentrated period of repository mapping consumed the pool about a
day after reset while the main weekly pool still had substantial capacity.

That produced two questions.

First: should a separate specialized allowance be conserved, or used for the
work it is good at until it is gone?

Second: after Spark is unavailable, what is the least expensive worker that can
reliably take over each shape of work?

The answer to the first question became straightforward. An unused specialized
pool has no residual value at reset. Spark remains our preferred read-only
mapper while it is available. When its allowance is exhausted, mapping moves to
the next adequate worker instead of stopping.

The second question required more than intuition.

## Separating Assumptions From Evidence

We began with several assumptions:

- Luna should be cheaper than Terra, and Terra cheaper than Sol.
- Lower reasoning should cost less than higher reasoning within one family.
- Terra would probably remain the safest routine implementation worker.
- Luna would probably remain best for searches, documentation, fixtures, and
  mechanical changes.
- A stronger model reviewing every cheaper worker would improve safety.

Some were directionally right. Some were incomplete. The last one can be
actively wasteful.

We also established what we could not measure. The primary Codex agent cannot
directly see the exact subscription quota charged to each subagent turn. I can
provide `/status` screenshots or before-and-after usage observations, but the
agent cannot manufacture a precise subscription conversion table from API
prices.

So we kept three evidence classes separate:

1. **Official documentation** for intended model roles and current API rates.
2. **User reports and independent comparisons** for hypotheses worth testing,
   not facts to inherit blindly.
3. **Our own bake-off** for repository-specific quality and scope discipline.

## What The Documentation Says

OpenAI's current
[model catalog](https://developers.openai.com/api/docs/models) describes Sol as
the frontier model for complex professional work, Terra as the balance between
intelligence and cost, and Luna as the cost-sensitive high-volume model.

At the time of this post, the standard API token rates are:

| Model | Input / 1M | Cached input / 1M | Output / 1M | Relative rate |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Luna | $0.20 | $0.02 | $1.20 | 1x |
| GPT-5.6 Terra | $2.00 | $0.20 | $12.00 | 10x |
| GPT-5.6 Sol | $5.00 | $0.50 | $30.00 | 25x |

The ratios are unusually clean. At equal input, cache, and output volume,
Terra is ten times Luna and Sol is twenty-five times Luna.

Those are API rates, **not Codex subscription multipliers**. The subscription
service may account for work differently. I use the table as relative context,
not as a claim that one Codex prompt removes exactly ten times another from a
weekly bar.

It still changes the burden of proof. Luna does not need to equal Terra token
for token. It can use materially more reasoning, or occasionally require a
narrow retry, and still remain attractive if subscription accounting resembles
the API direction at all.

## What Other Users Reported

Recent community reports pointed in several directions.

One independent
[cost/performance comparison](https://www.reddit.com/r/codex/comments/1ut3bnp/the_codex_pareto_frontier_luna_high_terra_max_sol/)
placed Luna High on its measured efficiency frontier before Terra Max and Sol
Max. Other users described Luna as effective when assignments were narrow and
explicit, and Terra as a strong everyday worker. A
[model-choice discussion](https://www.reddit.com/r/codex/comments/1v3mw6i/model_choice_guide/)
argued for scoped work and Terra rather than automatically choosing the most
expensive reasoning path.

There were also warnings. GitHub issues reported
[model or effort inheritance that did not match the requested child](https://github.com/openai/codex/issues/32510),
[reasoning changes causing cache misses](https://github.com/openai/codex/issues/35416),
and
[large-context Luna responses stopping without a useful result](https://github.com/openai/codex/issues/37879).

None of those reports became our policy by themselves. Reddit experience is
anecdotal. A GitHub issue can document a real reproduction without proving that
every version and environment behaves the same way. They told us what to watch:
actual child metadata, context size, model changes inside a session, retries,
and whether a cheaper worker required expensive repair.

## Why We Tested Two Real Repositories

Synthetic coding questions would have been easier to score and less useful.

We chose two repositories that exercise different kinds of reasoning:

- **Project Wraith**, an Unreal Engine space-simulation project with accepted
  design decisions, generation manifests, fixed automation scenarios, C++
  runtime implementation, and tests.
- **Soul/**, a local-first assistant whose behavior crosses Chat, Voice,
  capability routing, deterministic services, dashboard surfaces, retained
  evidence, and explicit authority contracts.

The assignments were read-only. We would not adopt patches from the bake-off.
Each worker received the same bounded objective, exact scope, evidence
requirements, non-goals, shared-worktree warning, and instruction to identify
one consequential mismatch or missing proof.

We compared Luna Low, Luna High, and Terra Medium. Spark was already exhausted,
and Sol remained the architect and evaluator rather than competing in the job
it was assigning.

The purpose was not to ask which model sounded most intelligent. We looked for:

- exact source paths and line ranges;
- separation of accepted design from hypothesis;
- distinction between documentation, tests, and live implementation;
- one consequential finding instead of an unbounded review;
- a deterministic way to prove or falsify the finding;
- clear uncertainty;
- scope discipline; and
- how much work Sol would have to repeat or repair.

## What Project Wraith Revealed

The Wraith assignment traced an accepted assisted-inertial flight and automated
landing decision into its automation scenario and Unreal implementation.

**Luna Low** found the broad verification gap: policy tests existed, but the
actual pawn landing, abort, touchdown, landing-gear, and takeoff lifecycle did
not have equivalent deterministic coverage.

**Luna High** found a concrete contradiction. The accepted design prohibited
teleporting the craft or erasing canonical momentum, while touchdown used a
physics teleport and zeroed velocity. More importantly, the existing transition
metric sampled after the snap, so the evidence could still report zero error.

**Terra Medium** found a different concrete issue. Takeoff released the grounded
state and applied upward velocity without revalidating the accepted collision,
local-frame, control, and clearance requirements. Fail-closed terrain handling
occurred only after grounded state had already been released.

All three results were useful. Luna Low mapped the missing proof class. Luna
High and Terra Medium performed the deeper cross-artifact reasoning expected of
a substantive review.

## What Soul Revealed

The Soul assignment traced a question such as “How does fleet observability
look?” through Chat and Voice intent matching, runtime execution, application
facade, summary service, Incident Narrator, Dashboard exposure, and the A3
verifier.

**Luna Low** found that the A3 “Chat and Voice” check proved pattern matching,
not a complete turn through runtime execution, evidence collection, and voice
delivery.

**Luna High** and **Terra Medium** independently found a deeper contract
violation. Incident Narrator was documented as consuming retained evidence
without refreshing sources, but its application wiring invoked the live fleet
summary. Composing a narrative could therefore perform new SSH/Prometheus
queries, block on reachability, or mix current telemetry into retained evidence.

Luna High went one step further. It constructed a deterministic injected
service that counted calls without touching the network. Narrative composition
called the live summary once; retained-only composition required zero.

That was the most useful result in the comparison. The cheaper worker did not
merely equal the more expensive finding. It produced the strongest falsifiable
proof.

No bake-off candidate was adopted. The exercise qualified routing; it did not
silently turn findings into implementation authority.

## The Cost Trap In Automatic Review

The original workflow correctly said that Sol should not redo every successful
worker assignment. The pricing comparison makes that more concrete.

At equal token volume:

- Luna work plus a complete Terra review costs eleven Luna-rate units;
- Terra doing the work directly costs ten;
- Luna work plus a complete Sol review costs twenty-six Luna-rate units; and
- Sol doing the work directly costs twenty-five.

This does not mean cheaper work should go unreviewed. It means review should be
proportionate.

An evidence-trusted read-only result gets checked for contradictions, drift, and
risk—not rediscovered from zero. A change-trusted implementation gets a scoped
diff review and integration check—not automatic reimplementation by Sol. Work
involving security, credentials, destructive or privileged behavior,
persistence, remote maintenance, backup and recovery, publication, release
authority, or tightly coupled architecture remains independently verified.

The expensive model is an escalation path and authority owner, not a ceremonial
second copy of every worker.

## The Routing We Adopted

Our current ladder is:

```text
Spark Explorer while its separate mapping allowance is available
  -> Luna Low for mapping, deterministic checks, and mechanical work
  -> Luna High for bounded implementation and substantive review
  -> Terra Medium for unresolved integration ambiguity
  -> primary Sol for architecture, sensitive authority, and final integration
```

In practical terms:

- **Spark Explorer** maps repositories until its separate pool is exhausted.
- **Luna Low** becomes the mapping fallback and handles exact searches,
  deterministic check execution, documentation synchronization, fixtures, and
  mechanical edits.
- **Luna High** is the default bounded implementation and substantive-review
  worker once architecture and authority are settled.
- **Terra Medium** is used when Luna reports material uncertainty or the work
  contains integration ambiguity and tight coupling.
- **Sol** owns ambiguous architecture, security, credentials, privileged or
  destructive operations, persistence, remote maintenance, recovery, release,
  and final integration.

We keep one model and reasoning level for a bounded worker session where
practical, avoid passing the entire parent conversation when a compact handoff
will do, and reuse an existing related worker instead of repeatedly creating
fresh context.

This is not a permanent leaderboard. A model update, orchestration change,
runtime change, or materially different repository should trigger another
representative qualification.

## Updated Reusable Files

The replacement package keeps the original authority and evidence principles,
but updates model routing, pool behavior, escalation, and structured worker
results. It is generic: no private paths, credentials, personal preferences, or
project-specific authority are included.

<details class="code-preview" data-code-preview="/assets/downloads/codex-cost-aware-multi-agent-workflow/AGENTS.md">
  <summary>
    <span>Preview the updated generic AGENTS.md</span>
    <small>MARKDOWN // COST-AWARE ROUTING POLICY</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the updated multi-agent workflow policy.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-cost-aware-multi-agent-workflow/delegated-worker-result.schema.json">
  <summary>
    <span>Preview the delegated-worker result schema</span>
    <small>JSON SCHEMA // EVIDENCE ENVELOPE</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the delegated-worker result schema.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-cost-aware-multi-agent-workflow/README.md">
  <summary>
    <span>Preview the updated setup notes</span>
    <small>MARKDOWN // IMPLEMENTATION NOTES</small>
  </summary>
  <pre aria-live="polite"><code>Open this panel to load the updated setup notes.</code></pre>
</details>

- <a href="/assets/downloads/codex-cost-aware-multi-agent-workflow/AGENTS.md" download>Download the updated generic AGENTS.md</a>
- <a href="/assets/downloads/codex-cost-aware-multi-agent-workflow/delegated-worker-result.schema.json" download>Download the delegated-worker result schema</a>
- <a href="/assets/downloads/codex-cost-aware-multi-agent-workflow/README.md" download>Download the updated setup notes</a>

Start with the policy, then replace its generic validation and authority
language with the real commands, ownership rules, privacy boundaries, and human
gates of the repository where it will operate.

## Updating A Process Is Part Of The Process

The original article was not wrong about architecture. It was incomplete about
economics and worker placement.

We responded the same way I want the agents to respond when evidence changes a
task: preserve the earlier record, state what became uncertain, run a bounded
test, distinguish observation from inference, and update the current contract.

The strongest model still does not need to do every job.

Now the most expensive worker does not automatically get every implementation
or every review either.
