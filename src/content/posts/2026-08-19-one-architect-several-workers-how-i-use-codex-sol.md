---
title: "One Architect, Several Workers: How I Use Codex Sol"
date: 2026-08-19T12:00:00-04:00
categories:
  - General
  - Automation
tags:
  - Codex
  - Artificial Intelligence
  - Automation
  - Local LLM
  - Software Development
description: "How I use Codex Sol at medium reasoning as the architect and integrator for bounded subagents, evidence-based trust, proportionate revalidation, and an optional local-model worker."
draft: false
---

## The Strongest Model Does Not Need To Do Every Job

For a while, the safest way to use a coding agent seemed obvious: choose the strongest model available, give it the whole problem, and let it work from beginning to end.

There is nothing inherently wrong with that. I still prefer one model for small changes, tightly coupled problems, and work where the cost of explaining a subtask would be greater than simply doing it.

The problem appears when the work gets wider.

One task may require repository discovery, documentation review, a focused implementation, test updates, a security check, and a final integration decision. Having one model perform every search, edit, and verification in sequence can be thorough. It can also spend its most capable reasoning on work that did not require it, while independent work waits in line behind it.

My current approach is different. I normally use Codex Sol at medium reasoning as the architect, task owner, and final integrator. Sol keeps the complete request, decides what can be separated safely, gives bounded assignments to specialized workers, reviews what comes back, and remains responsible for the result.<!--more-->

The workers are not a committee, and Sol is not there to count votes.

This is closer to a senior engineer dividing a job among people with different strengths while remaining responsible for the design, review, and release.

## Medium Reasoning Is The Default, Not A Statement Of Importance

OpenAI's current [GPT-5.6 model guidance](https://developers.openai.com/api/docs/guides/latest-model) describes Sol as the frontier model, Terra as the balanced worker, and Luna as the efficient high-volume option. It also recommends medium reasoning as a balanced starting point rather than assuming the maximum setting is always the correct one.

That matches what I have observed.

Medium gives Sol enough room to understand a repository, notice authority boundaries, decompose a larger task, and review evidence without making every ordinary action a maximum-effort exercise. More reasoning remains useful for unusually difficult architecture, security, recovery, or debugging work. It is simply not a tax that every file search needs to pay.

The important part is that Sol does not stop being responsible when it delegates something.

It owns the full request before the first worker is called. It owns the decision to delegate. It owns the review of the returned work, the integration check, and the final report. A subagent can complete an assignment; it cannot quietly redefine the assignment or grant itself more authority because it found an interesting adjacent problem.

## How The Work Gets Divided

The model names are less important than the shapes of work they receive, but our current routing generally looks like this:

- **Sol** keeps ambiguous architecture, cross-cutting integration, security decisions, credentials, destructive or privileged work, backup and recovery behavior, external publication, and final release decisions.
- **Terra** handles bounded implementation, debugging, integration, and code review where the design and authority boundary are already understood.
- **Luna** is useful for focused repository analysis, documentation and test synchronization, fixtures, mechanical refactors, and small reversible fixes.
- **Spark Explorer** performs read-only repository mapping and exact evidence collection.
- **Spark Worker** handles very small, reversible implementations with explicit file ownership and acceptance criteria.
- **A local model**, when included, works through a narrow adapter for read-only analysis or candidate generation. Its model and accelerator may change, but its authority does not.

This is not a rule that every task should produce a small swarm.

If I need to change one tightly coupled function and its test, Sol may do the entire thing. If I need three independent answers about an unfamiliar repository, three read-only explorers can collect them at the same time. If two agents would need to edit the same file, parallelism may create more integration work than it saves.

The first routing question is not “Which worker is available?”

It is “Can this piece of work be separated, owned, and checked?”

## A Subagent Receives A Contract, Not A Vague Request

The quality change did not come from adding more models. It came from getting much stricter about the handoff.

Every delegated assignment identifies:

1. the exact objective and expected deliverable;
2. the files the worker owns, or an explicit read-only scope;
3. the acceptance criteria and commands it must run;
4. the authority limits and things it should not do;
5. the fact that other work may exist in the same checkout and must be preserved; and
6. the evidence it must return.

A useful return is not “done.”

It includes the paths that changed, commands that ran, results from those commands, exact source locations supporting analysis, uncertainties, and any deviation from scope. If the worker finds overlapping edits or a larger architectural problem, reporting that condition is a successful result. Guessing around it is not.

This also keeps the handoff small enough to review. If Sol has to reconstruct an entire hidden investigation to decide whether the result is usable, the delegation did not buy very much.

## Trust Is Earned Per Assignment

The part that took the longest to become comfortable with was deciding how much of a worker's result to repeat.

If Sol blindly reruns every search, reimplements every patch, and repeats every test, the workflow may be safe, but it is not really multi-agent. It is one agent doing the work twice with an audience.

We ended up with three practical trust levels.

### Evidence-Trusted

A read-only explorer can be evidence-trusted when it stays in scope and returns exact paths, relevant line locations, commands, and clearly labeled uncertainty. Sol can consume that map without performing the same search again.

Drift-sensitive, contradictory, or risk-critical claims still get checked. Trusting a repository map is not the same as outsourcing a security decision.

### Change-Trusted

A bounded implementation can be change-trusted when the worker modifies only its assigned files, returns a clean diff, and passes the required targeted checks.

Sol still inspects the shared worktree, reviews the diff in proportion to risk, and runs an integration-level validation where appropriate. It does not automatically redo the implementation or rerun every successful unit check.

This is where most of the time savings appear. The worker proves that its slice is internally coherent. Sol proves that the slice still belongs in the larger system.

### Independently Verified

Some work stays with Sol even when a worker helps prepare it.

Security boundaries, credentials, destructive or privileged behavior, remote maintenance, persistence, backup and recovery, external publication, release authority, confirmation gates, and tightly coupled architecture receive independent primary verification.

A subagent result may be excellent evidence. It is not permission to publish, deploy, delete, reboot, restore, or declare a human review complete.

## When A Worker Loses The Handoff

Trust is deliberately temporary.

An assignment returns to Sol when the worker changes unexpected files, reports material uncertainty, encounters overlapping edits, misses required evidence, cannot run a required check, discovers broader risk, or produces something inconsistent with the original contract.

This is not punishment for the worker. It is the point where the problem has changed shape.

We also try not to spend several worker turns rescuing a bad delegation. Sometimes the right answer is a smaller retry with clearer ownership. Sometimes Sol should take the work back. Delegation is useful only while the handoff remains cheaper and clearer than direct ownership.

## The Local Model Is Replaceable. Its Qualification Is Not.

A local LLM can fit into the same structure, but “local” does not automatically mean trusted.

The useful way to include one is through a narrow tool or adapter with a defined request and a structured result. By default, I would give it read-only analysis or candidate-generation work: summarize a bounded artifact, classify findings, propose a test, or prepare a candidate patch for review.

The result should identify the backing model, runtime, accelerator class, contract version, commands or tools used, evidence, uncertainty, and scope deviations. It should not receive broad shell authority, private files, or credentials merely because inference happens on hardware I own.

Interchangeable models and GPU architectures are useful operationally. They are not proof of interchangeable behavior.

Changing the model, quantization, serving runtime, accelerator architecture, or adapter establishes a new qualification baseline. I would rerun representative assignments before granting the replacement the same trust earned by the previous combination.

The interface can remain stable while the engine behind it changes. The evidence still has to show that the new engine can drive it correctly.

## One Model Versus One Architect And Several Workers

I do not think the multi-agent version is universally better.

One capable model has real advantages. It carries one context, does not need a handoff, and can reason across tightly coupled changes without merging several partial views. For a small or ambiguous task, that simplicity is hard to beat.

The orchestrated approach becomes more useful when the work contains distinct lanes that can be verified independently. Repository mapping can happen while another worker checks documentation. A focused implementation can proceed after architecture is fixed. Test synchronization can be assigned without handing over release authority. Sol can spend more of its time on decisions that require the whole picture.

The improvement is not that several models produce a more democratic truth. Three weakly scoped agents can be wrong faster and in parallel.

The improvement comes from decomposition, ownership, evidence, and a primary agent that knows when not to delegate.

Our strongest conclusion is therefore modest: a Sol-led group can reduce wall-clock time and preserve primary-model attention on wider engineering work when the tasks divide cleanly and the evidence contract is strong. It can be worse than one model when assignments overlap, validation is vague, or the primary agent repeats everything anyway.

That is an observed working method, not a benchmark claiming that one arrangement wins every repository.

## The Reusable Part

Most of this workflow belongs in `AGENTS.md`. The primary model and reasoning setting can be selected through the supported Codex interface or configuration, while the repository file defines routing, assignment contracts, evidence, revalidation, and authority.

I prepared a generic version of that policy without my personal tone, private paths, project names, credentials, publication habits, or other individual preferences. I also included a small JSON Schema for an optional local worker's result envelope.

- <a href="/assets/downloads/codex-multi-agent-workflow/AGENTS.md" download>Download the generic AGENTS.md</a>
- <a href="/assets/downloads/codex-multi-agent-workflow/local-worker-result.schema.json" download>Download the local-worker result schema</a>
- <a href="/assets/downloads/codex-multi-agent-workflow/README.md" download>Download the setup notes</a>

The file is a starting policy, not a universal authority document. A real repository still needs its actual test commands, sensitive-data boundaries, ownership rules, deployment process, and human approval points.

## What Changed My Mind

I did not become comfortable with subagents because the models became persuasive enough to sound trustworthy.

I became comfortable when we stopped treating trust as a personality trait.

A worker receives one bounded job. It returns inspectable evidence. The amount Sol repeats depends on the risk and the quality of that return. High-consequence work receives independent verification. The final decision stays with the agent that still holds the whole problem, and with me where human approval is required.

That is the difference between using several models and having an engineering workflow.
