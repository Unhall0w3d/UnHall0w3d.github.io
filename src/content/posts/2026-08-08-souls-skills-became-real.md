---
title: "Soul/'s Skills Became Real"
date: 2026-08-08T12:00:00-04:00
categories:
  - General
  - Automation
  - Linux
tags:
  - Soul Slash
  - Artificial Intelligence
  - Local LLM
  - Skills
  - Automation
  - Linux
description: "Soul/ now has an inspectable production skill registry, a human-readable invocation guide, and a gated path for turning one missing capability into tested, reviewable behavior."
image: "/assets/images/soul-skills-became-real-skill-studio.jpg"
imageAlt: "Soul Slash Skill Studio showing the controlled proposal, Beta build, trial, and production approval workflow."
imageWidth: 1270
imageHeight: 714
draft: false
---

## The Skills Were Always The Point

When I first wrote about [Skill Studio](/2026/07/17/soul-slash-is-taking-shape.html), it was an architectural promise.

Soul/ would be able to recognize a missing capability, describe the capability as a proposal, isolate a candidate implementation, test it, and place every meaningful transition behind human review. A Beta skill would not quietly become a production skill because a model felt confident. A passing test would be evidence, not permission.

The interface existed. The stages existed. The boundary was clear.

What did not yet exist was a substantial body of capabilities that had actually traveled through the larger system and become part of how Soul/ works.

That has changed.

Soul/ now has a deterministic registry containing 38 skill records, a conversational inventory that can explain what is in that registry, an Invocation Guide that describes how those smaller capabilities become useful workflows, and a Skill Studio path that can use the local [Dev Core](/2026/08/06/five-cores-one-soul.html) to prepare a bounded candidate without allowing the development model to quietly rewrite Soul/ around itself.

The number is not the important part.

The important part is that a “skill” is no longer shorthand for a Ruby file I happen to know exists somewhere in the repository. It has an identity, a contract, a current state, an evidence trail, and a defined relationship to the rest of the system.

Soul/'s skills became real when they became inspectable—and when their limits became as concrete as their abilities.<!--more-->

<span class="image fit"><a href="/assets/images/soul-skills-became-real-skill-studio.jpg" target="_blank" rel="noopener"><img src="/assets/images/soul-skills-became-real-skill-studio.jpg" alt="Soul Slash Skill Studio showing the need and proposal, scope approval, Beta build, trial and evidence, and production approval stages" loading="lazy" width="1270" height="714" /></a></span>

*Skill Studio makes the entire path visible. A missing capability passes through an exact scope approval, a separate Beta build, trial evidence, and approval of the tested revision. Nothing is implemented, registered, or promoted merely because the workflow exists. Select any screenshot to open the full-resolution image.*

## A Registry, Not A Bag Of Scripts

It is easy to make an assistant appear capable by placing a language model in front of a collection of scripts.

The model sees a request, guesses which script sounds relevant, invents some arguments, and hopes the result resembles what the person meant. This can be impressive during a demonstration. It is also how a conversational misunderstanding becomes a system operation.

Soul/'s production registry is intended to prevent that ambiguity.

A registered capability has a stable identifier such as `files.inspect`, `network.diagnose`, or `repository.inspect`. Its implementation does not receive a vague paragraph and the freedom to interpret it creatively. It receives bounded inputs through a deterministic application path and returns a defined result or an explicit failure.

The language model can help understand the request.

It does not get to redefine the operation.

Registration and availability are also deliberately separate ideas. Skill Studio currently reports 38 production skills as available, but the underlying registry projection still treats availability as something a record must explicitly establish. It does not turn the mere presence of a row in a YAML file into a claim that the capability is ready for ordinary use.

That distinction is the sort of detail that makes a feature list less exciting and a system more trustworthy.

<span class="image fit"><a href="/assets/images/soul-skills-became-real-production-registry.jpg" target="_blank" rel="noopener"><img src="/assets/images/soul-skills-became-real-production-registry.jpg" alt="Soul Slash Skill Studio inventory showing two proposals, no implemented Beta packages, and 38 available production skills" loading="lazy" width="1270" height="714" /></a></span>

*The current inventory separates two proposals awaiting review, an empty Operator-invoked Beta lane, and 38 available production skills. The center remains a candidate channel until one exact proposal or Beta is deliberately selected.*

## The First Five Had To Be Boring

The first completed foundational cohort consists of five capabilities:

- `files.inspect` can list one directory level, inspect one path, or read one bounded text file beneath a root I explicitly configured.

- `network.diagnose` can inspect local address and route evidence, resolve one target, send one fixed reachability probe, or test one TCP socket.

- `repository.inspect` can report bounded Git evidence from one configured local repository: branch, HEAD, status, recent history, and controlled diff information.

- `workspace.artifact.compose` can prepare one Markdown, text, or JSON artifact through a preview and an expiring approval token bound to that exact revision.

- `web.research` can perform bounded public-web research through the existing SearXNG or Brave path, preserve source provenance, and hand grounded material into a separate artifact or reflection workflow.

These are not glamorous capabilities.

That was intentional.

Reading a file, checking a route, inspecting a repository, composing an artifact, and gathering public evidence are the kind of primitives a useful local assistant will need constantly. They are also exactly the kind of seemingly harmless operations that tend to expand when their boundaries are left vague.

“Look at this file” becomes recursive indexing. “Check the network” becomes a scan. “Inspect the repository” becomes an accidental remote operation or a credential leaking through a diff. “Research this” becomes an unbounded crawler with access to internal addresses. “Write this down” becomes a general-purpose filesystem writer.

Soul/ does not receive those implied promotions.

`files.inspect` rejects paths outside approved roots, traversal, hidden paths, symlinks, secret-shaped files, binaries, oversized reads, writes, and recursive scans. `network.diagnose` rejects ranges, multiple targets, URLs, repeated monitoring, and mutation. `repository.inspect` cannot contact a remote or modify Git state, and it withholds credential-like diff content. `web.research` is restricted to bounded public HTTPS evidence and treats instructions found inside sources as untrusted material.

The capabilities are useful because their contracts are narrow enough to understand.

They are production skills because I reviewed and accepted those contracts—not because a model successfully demonstrated the happy path once.

## Knowing The Skill Is Not Knowing The Workflow

A registry answers, “What implementation units exist?”

That is not necessarily the question I am asking when I sit down in front of Soul/.

I am more likely to ask how to research a subject, create an artifact, inspect a repository, produce a song, or move a machine into a maintenance posture. One useful task may involve several skills, a deterministic handler, a particular Core, and more than one approval gate.

That is why Soul/ now has an Invocation Guide alongside the raw skill inventory.

The guide describes complete, supported workflows in human terms. Each entry can explain:

- what information I need to provide;
- which inputs are optional;
- whether a particular Core is required;
- what approval behavior I should expect;
- what the workflow will return; and
- where Soul/'s authority ends.

The dashboard loads that catalog only when I open it. I can filter it, select a workflow, and inspect the requirements without beginning the work. I can ask the same questions conversationally—“How can I invoke music production?” or “Show the Skill Studio inventory”—and receive a deterministic read-only answer.

Examples in the guide are inert.

That sounds like a small detail until an example contains wording that resembles an approval phrase. Documentation should explain how authority works. It should not accidentally exercise it.

The catalog is also checked against the production registry. If an invocation claims to depend on a production skill that Soul/ does not recognize, the workflow is shown as unavailable rather than being presented as a promise the runtime cannot keep.

<span class="image fit"><a href="/assets/images/soul-skills-became-real-invocation-guide.jpg" target="_blank" rel="noopener"><img src="/assets/images/soul-skills-became-real-invocation-guide.jpg" alt="Soul Slash Invocation Guide showing the supported workflow catalog and the required inputs, Core, approval, result, boundary, and inert example for System status" loading="lazy" width="1270" height="714" /></a></span>

*The Invocation Guide currently exposes 20 complete workflows. Selecting one explains its requirements, Core behavior, approval model, result, and authority boundary; inspecting the catalog performs no mutation.*

## Skill Studio Can Now Build A Candidate

The larger change is that Skill Studio is no longer limited to recording a proposal and waiting for me to implement it elsewhere.

The workflow begins the same way it always should: with a specific missing capability.

That gap can become a proposal containing the intended skill ID, scope, risks, expected behavior, and required tests. Soul/ should not propose a new skill merely because a question needs clarification, research, or an existing capability. A proposal is for behavior the system genuinely does not support.

Gate 1 approves one exact revision of that proposal.

It does not approve whatever code may later be associated with the same title. It does not run a skill, change the production registry, or authorize a development model to explore the repository freely.

After Gate 1, Skill Studio can prepare an isolated Beta workspace and a proposal-bound implementation handoff. If I explicitly choose **Build with Dev Core**, the reviewed local GPT-OSS model can draft one read-only Ruby candidate for that proposal.

The model does not receive Soul/'s entire operating environment and an encouraging note to be careful.

The candidate is checked for syntax and declared behavior inside a networkless, read-only `bubblewrap` sandbox. The development pass stops at human review. There is no automatic repair loop where a model repeatedly changes code until the tests finally stop objecting.

That last restriction matters more than it may appear.

An autonomous repair loop can optimize for passing the test it sees instead of preserving the capability I meant to build. Stopping after one candidate keeps the evidence legible. If the implementation is wrong, I can see how it is wrong before another revision obscures the path that produced it.

The Dev Core contributes reasoning.

It does not inherit authorship, approval, or promotion authority.

## Beta Means “Try This Exact Thing”

A Beta skill remains separate from production.

Skill Studio shows its description, risk classification, current test evidence, known weaknesses, and the promotion tests that remain. **Try this Beta** prepares one bounded foreground run with visible arguments and records diagnostic evidence from that attempt.

The sandbox remains in place for read-only candidates produced through Dev Core. A failure must terminate visibly. It cannot disappear into a background worker and return later with a success-shaped summary.

If the implementation changes, its digest and revision change with it.

Previous tests do not automatically transfer. Previous approval does not stretch far enough to cover code that did not exist when I gave it. The familiar name of a skill is not the approved object; the exact tested revision is.

Gate 2 checks the original scope approval, implementation completeness, current test evidence, and revision integrity. Even then, it only approves that candidate for later promotion.

Production promotion is a separate action.

It previews the exact change, copies the reviewed entrypoint, records hashes and rollback evidence, and atomically adds one new registry entry. It refuses to replace an existing production skill. Cleanup of the completed proposal and superseded Beta is another explicit decision after the production record exists.

There are more gates here than a small local script strictly needs.

That is because the artifact being built is not merely a script. It is a new thing Soul/ may be able to do when I ask.

## Tests Are Evidence, Not Authority

This principle now appears throughout Soul/, but Skill Studio makes it particularly visible:

**Model output, passing tests, and successful trials are evidence—not authorization.**

A capable model can produce bad code. A weak test can approve the wrong behavior. A successful trial can miss the path that matters. None of those observations should be discarded, but none of them can make the decision they are supposed to inform.

Human review does not make the software infallible either.

It establishes who is responsible for the transition.

Soul/ can explain the proposal, preserve the candidate, run bounded checks, record the evidence, and make the exact revision visible. The Operator decides whether that evidence is sufficient to move forward.

That is a very different relationship from asking a model to improve itself and discovering afterward what “improve” meant.

## Not Every Improvement Is A Skill

Building a real skill system also forced a clearer definition of what a skill is not.

If the new behavior can be expressed as one bounded capability—with explicit inputs, outputs, limits, failures, and authority—it belongs in Skill Studio.

If the change affects shared orchestration, memory architecture, provider infrastructure, Core behavior, or another system-wide contract, it belongs in Self Augmentation.

The distinction prevents Skill Studio from becoming a convenient route around architectural review.

A skill performs a bounded capability.

An augmentation changes the machinery that decides how capabilities, models, memory, and authority relate to one another.

Both can begin with an idea. They should not inherit the same path merely because a language model might write code for either one.

## Soul/ Can Explain What It Can Do

The most immediately useful result of all this may be the least visually dramatic.

Soul/ can now answer questions about its own capabilities from current deterministic state.

It can list proposals, Beta candidates, production records, and invocation workflows. It can explain which inputs a supported operation requires and which boundary remains in place. Those answers do not depend on the conversational model remembering a design document from somewhere in its context window.

They are read from the system that actually owns the capability.

That does not make Soul/ self-aware in the science-fiction sense.

It makes it less likely to confidently claim a tool it does not have, overlook a tool it does have, or confuse an example with permission to use one.

For a project built around continuity, this is an important kind of self-knowledge.

The models underneath Soul/ can change. [The active Core can change](/2026/08/06/five-cores-one-soul.html). A development model can help shape a candidate and then leave memory entirely. The registry, contracts, evidence, and human gates remain outside any one model's recollection.

The skills became real when they stopped being aspirations in a diagram and became durable parts of that continuity.

There are now enough of them to be useful.

More importantly, there is finally a path for the next one.
