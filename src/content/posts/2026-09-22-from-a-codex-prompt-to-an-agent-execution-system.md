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

The latest revision is bigger than replacing GPT-5.6 Sol and Luna with GPT-6 Sol and Luna. We audited the instructions, introduced three scoped worker roles, and moved several checks into schemas and a verifier. Since publication, we have also compacted the global and Soul policies and clarified exactly which rules belong in each. The configuration now chooses GPT-6 Sol Medium as the personal default, while the policy continues to describe Astra Medium as its ordinary orchestration baseline. Those are different kinds of settings.<!--more-->

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

## Review the Reusable Configuration

The downloadable package now contains the compacted generic `AGENTS.md`, the three unchanged model-neutral role examples, a minimal `config.example.toml` showing the current Sol Medium primary selection, and a README. It illustrates the policy, role, and model-selection layers. The Soul-specific schemas, check registry, and verifier described above are not included in this generic package; they depend on that repository's risk and review rules. The example config deliberately omits the Soul project's broader sandbox setting.

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
