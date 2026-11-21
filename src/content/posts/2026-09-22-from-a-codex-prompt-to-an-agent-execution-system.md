---
title: "From a Clever Codex Prompt to an Agent Execution System"
date: 2026-09-22T12:00:00-04:00
description: "How our Codex policy became shorter, split general and Soul-specific rules, and connected scoped roles to evidence checks while keeping model selection explicit."
categories:
  - General
  - Automation
tags:
  - Codex
  - Artificial Intelligence
  - Subagents
  - Software Development
draft: false
---

Our first multi-agent configuration was mostly an `AGENTS.md` that told a strong primary model when to delegate, which worker to choose, and how to review the result. It was useful. It was also asking the model to remember a growing list of authority rules, handoff details, test expectations, and exceptions.

The September revision was bigger than replacing GPT-5.6 Sol and Luna with GPT-6 Sol and Luna. We audited the instructions, introduced three scoped worker roles, and moved several checks into schemas and a verifier. Since publication, we have also compacted the global and Soul policies and clarified exactly which rules belong in each. At the time, I had configured GPT-6 Sol Medium as my personal default, while the written policy still described Astra Medium as the ordinary orchestration baseline.<!--more-->

## Current Configuration (November 15, 2026)

The September setup used three model-neutral roles. That made the roles easy to reuse, but the primary had to pick the model and effort whenever the inherited defaults were a poor fit. I now use GPT-6.1 Sol as the primary, with reasoning effort left at the client's default. The five worker roles below pin a model and effort for jobs I can describe up front.

| Role | Model and effort | Work I assign |
| --- | --- | --- |
| `luna_focused` | GPT-6 Luna Low | Exact mapping, routine checks, and small reversible edits. |
| `luna_coding` | GPT-6 Luna High | Low-complexity coding, small fixes, and focused tests when the design and checks are already clear. |
| `sol_implementation` | GPT-6.1 Sol Medium | Complex implementation and debugging. |
| `sol_review` | GPT-6.1 Sol Medium | Read-only review for correctness, regressions, and gaps in validation. |
| `terra_visual` | GPT-6.1 Terra Low | Visual reasoning, computer use, and bounded UI coding where rendered behavior matters. |

I kept Luna Low for quick mapping and added a separate High role for small changes with clear acceptance checks. That gives the coding worker more reasoning effort while keeping the handoff narrow. Any comparison of the two still needs to count the primary's corrections and review through accepted completion. [OpenAI's model guidance](https://learn.chatgpt.com/docs/models)

OpenAI describes Terra as a model for visual reasoning and precise computer use. I apply that to bounded UI changes when I can give it a specific rendered state to inspect and verify. That's my routing choice. I still send complex code and cross-module debugging to Sol. [GPT-6.1 Terra model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-terra)

A role's pinned model and reasoning effort take precedence over spawn-time overrides. Choose a role whose pins fit the job, and check which model and effort actually ran where the client exposes them. Current Codex inherits the effective sandbox and approval mode from the parent session, including when an older role file contains its own sandbox key. A role can instruct a reviewer to avoid edits. For enforced read-only access, use a verified read-only parent. [Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents)

The primary still decides whether the handoff is worth doing. I give a worker a concrete objective, owned paths or read-only scope, acceptance checks, and the evidence to return. During long work I prefer a completion event or a bounded wait and inspect the result once it arrives. The aim is to spend fewer turns asking whether anything changed. I have no measured token savings or accepted-change cost for this setup.

The November qualification used Codex CLI 0.166.0. Fresh-session execution records confirmed all five saved roles used the configured model and effort and inherited the parent permissions. Luna High completed a small Python fix that passed six tests. Terra inspected a clipped mobile screenshot and changed the CSS; independent browser checks at mobile and desktop widths confirmed the layout fit and the button still worked. That establishes these fixtures. It does not establish a general performance ranking or lower subscription usage.

### Inspect the November Package

Review the policy and the roles before merging them into your setup. The config example sets the primary model. Start a fresh session after making changes and verify role discovery, model availability, and effective permissions in your client.

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/AGENTS.md">
  <summary><span>Review AGENTS.md</span><small>MARKDOWN // AUTHORITY AND ROUTING</small></summary>
  <pre aria-live="polite"><code>Open to load AGENTS.md.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/config.example.toml">
  <summary><span>Review the primary model config</span><small>TOML // PRIMARY MODEL</small></summary>
  <pre aria-live="polite"><code>Open to load config.example.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/agents/luna_focused.toml">
  <summary><span>Review luna_focused.toml</span><small>TOML // LUNA LOW</small></summary>
  <pre aria-live="polite"><code>Open to load luna_focused.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/agents/luna_coding.toml">
  <summary><span>Review luna_coding.toml</span><small>TOML // LUNA HIGH</small></summary>
  <pre aria-live="polite"><code>Open to load luna_coding.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/agents/sol_implementation.toml">
  <summary><span>Review sol_implementation.toml</span><small>TOML // SOL MEDIUM</small></summary>
  <pre aria-live="polite"><code>Open to load sol_implementation.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/agents/sol_review.toml">
  <summary><span>Review sol_review.toml</span><small>TOML // SOL MEDIUM</small></summary>
  <pre aria-live="polite"><code>Open to load sol_review.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/agents/terra_visual.toml">
  <summary><span>Review terra_visual.toml</span><small>TOML // TERRA LOW</small></summary>
  <pre aria-live="polite"><code>Open to load terra_visual.toml.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-routing-2026-11-15/README.txt">
  <summary><span>Review the setup notes</span><small>TEXT // INSTALLATION AND CHECKS</small></summary>
  <pre aria-live="polite"><code>Open to load README.txt.</code></pre>
</details>

- [Download the November configuration ZIP](/assets/downloads/codex-routing-2026-11-15/codex-routing-2026-11-15.zip)
- [Download AGENTS.md](/assets/downloads/codex-routing-2026-11-15/AGENTS.md)
- [Download config.example.toml](/assets/downloads/codex-routing-2026-11-15/config.example.toml)
- [Download luna_focused.toml](/assets/downloads/codex-routing-2026-11-15/agents/luna_focused.toml)
- [Download luna_coding.toml](/assets/downloads/codex-routing-2026-11-15/agents/luna_coding.toml)
- [Download sol_implementation.toml](/assets/downloads/codex-routing-2026-11-15/agents/sol_implementation.toml)
- [Download sol_review.toml](/assets/downloads/codex-routing-2026-11-15/agents/sol_review.toml)
- [Download terra_visual.toml](/assets/downloads/codex-routing-2026-11-15/agents/terra_visual.toml)
- [Download README.txt](/assets/downloads/codex-routing-2026-11-15/README.txt)
- [Changelog](/assets/downloads/codex-routing-2026-11-15/CHANGELOG.txt)
- [SHA-256 checksums](/assets/downloads/codex-routing-2026-11-15/SHA256SUMS.txt)

The [Codex workflow entry on Tools](/tools.html#codex-workflows) lists the tested CLI version, configuration package, and checksums.

## The September Configuration

<figure>
  <img src="/assets/images/codex-agent-execution-flow.svg" alt="Human authorization flows to the primary agent, which assigns work to read-only mapper and reviewer roles and a workspace-write implementer. Evidence goes through deterministic checks before the primary integrates it and a human reviews promotion." width="1200" height="870" loading="lazy" />
  <figcaption>The intended flow. The narrower Soul project default still needs runtime qualification.</figcaption>
</figure>

## Why the Prompt Kept Growing

[One Architect, Several Workers](/2026/08/19/one-architect-several-workers-how-i-use-codex-sol.html) described a Sol-led team. [The Cheapest Adequate Worker](/2026/08/20/the-cheapest-adequate-worker-re-evaluating-my-codex-subagent-strategy.html) revised the worker routing after repository experiments. By September, Astra had become the primary owner, with Sol available for difficult bounded work and Luna for less costly assignments.

Each iteration added a sensible rule: keep security and release decisions with the primary, give workers exact file ownership, check returned evidence, avoid duplicating successful tests, ask for a real permission boundary only when one is reached. Individually these helped. Together they produced overlapping statements across global guidance, repository policy, skill briefs, and handoff prompts. Some requirements were measurable, while others—such as “choose the least costly adequate worker”—were judgments written as though a validator could prove them.

The latest edit made that distinction easier to read. The global policy we reviewed before compaction was about **280 lines**; the current file is **139**. Soul's repository policy changed from **141 lines to 70** in its working tree. Line count is a rough measure of reading surface, not token savings or a quality score. The important change is where the rules now live: global guidance handles authority, delegation, validation, waiting, and implementation economy; Soul's file handles its skill lifecycle, review gate, memory and cloud boundaries, and project-specific evidence.

A read-only policy audit found two practical ambiguities. One document expected a new test for every implementation while another called for tests only when they protected distinct behavior. The global policy allowed some bounded development jobs to finish after a turn, while a Soul skill had a stricter lifecycle rule. We resolved the first with one testing rule: run deterministic checks for every implementation; add a test for distinct behavior or a credible uncovered failure mode; require deterministic coverage for safety-sensitive behavior. We separated ordinary bounded Codex jobs from Soul skill lifecycles for the second.

The audit also made the authority order explicit: platform limits, current user authorization, non-waivable repository safeguards, approved brief, repository defaults, role configuration, assignment details, then judgment guidance. A brief can authorize a specific service change without erasing a destructive-action confirmation gate. The compacted policy adds a useful clarification: an explicit request for an exact action counts as authorization for that action. The agent should finish the approved work rather than ask again after each ordinary slice; a new permission boundary or human gate still applies.

Soul now defines an approved brief as checked-in and human-authored or explicitly accepted by the current user. It points to its separate cloud policy and canonical review gate rather than repeating every rule in `AGENTS.md`. Its lifecycle still forbids silently leaving a skill process running after a response. This is policy organization, not a claim that shorter prose enforces itself.

## Roles Describe Jobs; the Parent Selects Models

We added project-scoped `mapper`, `implementer`, and `reviewer` TOMLs. The mapper and reviewer declare read-only sandboxes; the implementer declares workspace-write. Their instructions specify what evidence to return and when to hand a decision back to the primary. None pins a model or reasoning effort. **The recent compaction did not change these three role files.**

That distinction matters. “Mapper” is a job and permission boundary, not a synonym for Luna Low. A simple map might use Luna; a difficult review may warrant Sol. When a role omits model settings, Codex can inherit them, so the primary must verify the effective selection or supply a supported override. [OpenAI's subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents) describes project-scoped TOMLs, model inheritance, and the effect of live parent permission overrides.

The role files reduce repeated handoff prose, but they do not replace the assignment. The primary still supplies the objective, owned paths, acceptance commands, authority limits, shared-worktree warning, and expected evidence. Nor does a read-only line in a TOML prove the effective runtime boundary: the parent turn's live permissions can matter. We kept the primary responsible for verifying the sandbox actually in force.

## The Two `config.toml` Files Matter

The personal `~/.codex/config.toml` now selects `gpt-6-sol` at `medium` reasoning. It does not set a default subagent model. Soul's project `.codex/config.toml` still requests `danger-full-access` and live web search. The project-scoped mapper, implementer, and reviewer TOMLs supply role-specific sandbox declarations but no model pin.

The written policy says **Astra Medium is the ordinary orchestrator baseline**. That is a routing preference, not proof that every task runs on Astra: the current personal configuration selects Sol Medium unless a supported setting or runtime choice overrides it. The acting primary, whether Astra or Sol, retains architecture, authority, integration, and the final report. When a worker role lacks a model setting, it can inherit the parent's model and effort; a cheap mapping assignment will not become Luna Low merely because it uses the mapper role. The parent has to choose that model explicitly. The [Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents) describes model inheritance and live permission overrides.

This difference between **configured preference** and **observed runtime identity** is why the policy says to check callable models and effective permissions before claiming a particular worker ran. We have inspected the files; this article does not assert that a fresh Soul session has proven every role's effective sandbox.

## Putting Evidence Into Files and Checks

In Soul, the policy audit became an **agent execution control-plane candidate**. Alongside the roles, it added a structured assignment schema, a lifecycle receipt schema, a required-check registry keyed to changed paths, a review-artifact validator, and an advisory persistence classifier. A Ruby verifier exercises those pieces with valid and invalid examples. The candidate review packet reports passing syntax, schema, role, path-safety, assignment, lifecycle, review, and persistence checks.

Here is the division of work:

| Layer | What it contributes |
| --- | --- |
| Human authorization and repository policy | The scope and safeguards the agent may operate within. |
| Primary agent | Architecture, bounded assignments, integration, and consequential decisions. |
| Role TOML | A worker's job and configured sandbox. |
| Assignment schema | Required handoff fields, including scope, checks, and evidence. |
| Lifecycle receipt | One explicit terminal state and continuation evidence where applicable. |
| Required-check registry and review validator | Deterministic checks of required evidence and review structure. |
| Persistence classifier | Signals to investigate when a change may create lasting background behavior. |
| Human review | The decision to promote a candidate where the workflow requires it. |

The validators check shape and required fields. They cannot tell whether a finding is true or whether a design is good. The persistence classifier is advisory because text searches can both miss dynamic behavior and flag harmless examples. Those judgments still need an owner. What we gain is that the model no longer has to remember every required field or notice every missing review heading unaided.

There is an important unfinished boundary. Soul's project default **remains** `danger-full-access` in the configuration reviewed for this update. The audit found legitimate exceptional paths involving system configuration, services, hardware, and network access, but no ordinary repository-editing need for an unrestricted default. The proposed direction is workspace-write by default, read-only mapping and review, and explicit escalation for exceptional operations. That change awaits a fresh-session qualification of the actual permission behavior. The TOMLs and passing verifier alone do not establish it.

## Long Jobs Without a Wake–Check Loop

<figure>
  <img src="/assets/images/codex-bounded-wait-flow.svg" alt="Comparison of a repeated sleep, check, and resume loop with a bounded wait that has a job receipt and one result inspection." width="1200" height="440" loading="lazy" />
  <figcaption>The waiting rule aims to reduce redundant agent turns; we have not measured a token saving.</figcaption>
</figure>

Another concern came from reports of Codex repeatedly sleeping, waking, and checking whether a task had finished. Each extra agent turn can require the model to resume context and inspect state again. We did not capture a token trace that quantifies the cost in our setup, but the pattern is a poor fit for a long-running job with no new result.

The compacted policy still prefers a supported completion event or one long bounded wait. If an authorized development job must outlast the turn, it needs a durable job identity, a timeout, an expected result location, and recovery semantics. Where a supported completion notification exists, it should wake the exact task once for the retained result. Otherwise the agent should report the running job and stop, then inspect its result once when the conversation resumes. The policy specifically avoids repeated “still running” turns and rereading unchanged logs. It treats `codex queue` as an optional, feature-detected development mechanism tied to the exact task and a retained receipt, with a safe fallback when unavailable. Raw command output is not injected as a new instruction.

This is a workflow rule, not a newly installed background service or proof of lower token usage. A bounded development job also does not authorize a persistent Soul feature. The project skill lifecycle and review gate still apply.

## The September Model Change

The September 22 local Codex catalog exposed `gpt-6-astra`, `gpt-6-sol`, and `gpt-6-luna`. It advertised GPT-6 Sol as the upgrade for GPT-5.6 Sol **and** Terra, and GPT-6 Luna as the upgrade for GPT-5.6 Luna. It did not give us an exact removal date for the old models. The public [OpenAI model catalog](https://developers.openai.com/api/docs/models) is a separate source and does not establish our Codex subscription accounting.

The policy maps new delegated assignments to Sol for difficult bounded work and Luna Low or High for suitable mapping, implementation, or review. **Spark remains the preferred option for suitable read-only mapping when it is callable and has allowance; Luna Low is the fallback.** Spark Worker can take a small reversible assignment under the same availability condition. Terra is optional while available and justified; a task can go directly to Sol when its complexity warrants Sol. The acting primary remains responsible for the result. The roles remain model-neutral, so a model generation change does not require editing each job definition.

This is a configuration baseline, not a new bake-off. The older Luna and Terra findings in the August post remain useful evidence about **that** experiment. We have not shown that GPT-6 produces the same quality at the same effort, that it reduces correction work, or that it consumes a known fraction of the subscription allowance.

## What Improved, and What We Still Need to Measure

We can point to concrete changes now: the global and Soul policies are substantially shorter; approval continuity and Soul's brief boundary are more explicit; three scoped roles exist; the assignment and lifecycle contracts have schemas; required checks, review structure, and persistence signals have deterministic tooling; the verifier passed; and new assignments have explicit GPT-6 model routing. Those are configuration and component results.

The hoped-for operational gains are fewer incomplete handoffs, fewer skipped checks, less duplicated review, fewer unnecessary wake/check turns, and easier model replacement. To test them, we need representative tasks that record actual model and effort, elapsed time through accepted completion, failures, primary corrections, extra review work, and available usage observations. Comparing a frontier-only run with an orchestrated one would help show when delegation pays for its handoff and integration cost. We should not substitute API list prices for Codex subscription usage.

The system is still a candidate at several boundaries. The Soul default sandbox has not been changed by this work; effective role isolation needs runtime qualification; and the review validator proves completeness of an artifact, not correctness of its claims. The compacted instructions improve clarity but do not establish that Codex has loaded every role or reduced token use. Keeping those boundaries visible is part of making the system trustworthy.

## Review the September Configuration Files

The September package contains the compacted generic `AGENTS.md`, the three unchanged model-neutral role examples, a minimal `config.example.toml` showing the then-current Sol Medium primary selection, and a README. It illustrates the policy, role, and model-selection layers. The Soul-specific schemas, check registry, and verifier described above are not included in this generic package; they depend on that repository's risk and review rules. The example config deliberately omits the Soul project's broader sandbox setting.

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/AGENTS.md">
  <summary><span>Review the generic AGENTS.md</span><small>MARKDOWN // AUTHORITY AND ROUTING</small></summary>
  <pre aria-live="polite"><code>Open to load the policy.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/roles/mapper.toml">
  <summary><span>Review the mapper role</span><small>TOML // READ ONLY</small></summary>
  <pre aria-live="polite"><code>Open to load the mapper role.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/roles/implementer.toml">
  <summary><span>Review the implementer role</span><small>TOML // WORKSPACE WRITE</small></summary>
  <pre aria-live="polite"><code>Open to load the implementer role.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/roles/reviewer.toml">
  <summary><span>Review the reviewer role</span><small>TOML // READ ONLY</small></summary>
  <pre aria-live="polite"><code>Open to load the reviewer role.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/README.md">
  <summary><span>Review the setup notes</span><small>MARKDOWN // LIMITS AND QUALIFICATION</small></summary>
  <pre aria-live="polite"><code>Open to load the README.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/codex-astra-multi-agent-workflow/config.example.toml">
  <summary><span>Review the minimal model configuration</span><small>TOML // PRIMARY MODEL EXAMPLE</small></summary>
  <pre aria-live="polite"><code>Open to load the example config.</code></pre>
</details>

- [Download AGENTS.md](/assets/downloads/codex-astra-multi-agent-workflow/AGENTS.md)
- [Download README](/assets/downloads/codex-astra-multi-agent-workflow/README.md)
- [Download config.example.toml](/assets/downloads/codex-astra-multi-agent-workflow/config.example.toml)
- [Download mapper.toml](/assets/downloads/codex-astra-multi-agent-workflow/roles/mapper.toml)
- [Download implementer.toml](/assets/downloads/codex-astra-multi-agent-workflow/roles/implementer.toml)
- [Download reviewer.toml](/assets/downloads/codex-astra-multi-agent-workflow/roles/reviewer.toml)

What started as instructions to a capable model is becoming a system with role boundaries, evidence contracts, deterministic checks, and human review. The practical test is whether it helps the next task reach a correct, accepted result with less wasted work while keeping authority clear.
