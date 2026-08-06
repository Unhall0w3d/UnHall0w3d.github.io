---
title: "Five Cores, One Soul/"
date: 2026-08-06T08:00:00-04:00
categories:
  - General
  - Automation
  - Linux
tags:
  - Soul Slash
  - Artificial Intelligence
  - Local LLM
  - GPU
  - Automation
  - Linux
description: "Soul/ now operates through five distinct Cores, moving conversation, creative work, development reasoning, or complete resource release across local hardware without becoming five different assistants."
image: "/assets/images/five-cores-one-soul-social.jpg"
imageAlt: "Soul Slash Chat with the five-Core selector showing Soul, Soul-Lite, Creative, Free, and Dev Core."
imageWidth: 1200
imageHeight: 630
draft: false
---

## Three Was Apparently The Minimum

When I wrote that [Soul/ had more than one brain](/2026/07/19/soul-slash-has-more-than-one-brain-now.html), it had three operating arrangements.

Soul/ could run its primary conversational model on the AMD GPU, move conversation to an older NVIDIA card when I needed the AMD hardware back, or keep Chat on NVIDIA while the AMD card generated music.

That was enough to prove the larger point: the model is not the assistant.

Soul/'s identity, conversation history, memory rules, capabilities, evidence, and authority boundaries exist outside the model currently producing language. Gemma and Qwen do not need to sound mathematically identical, but changing the machinery underneath a conversation should not create a stranger with access to Soul/'s name.

The original three Cores have since become five.

The additional two are not merely more models. One deliberately removes every conversational and development model from memory. The other gives Soul/ access to a much larger local reasoning model for bounded development work without pretending that reasoning is the same thing as permission—or that a model capable of producing code should automatically receive a repository and a shell.

Soul/ now has more ways to arrange the machine beneath it.

It still has one identity above them.<!--more-->

<span class="image fit"><a href="/assets/images/five-cores-selector.jpg" target="_blank" rel="noopener"><img src="/assets/images/five-cores-selector.jpg" alt="Soul Slash Chat with the five-Core selector showing Soul, Soul-Lite, Creative, Free, and Dev Core and their local runtime arrangements" loading="lazy" width="1700" height="980" /></a></span>

*The five Cores are operating arrangements, not five personalities. Soul-Lite is active here: Qwen carries Chat on NVIDIA while AMD remains released to the Operator. Select any screenshot to open the full-resolution image.*

## A Core Is An Operating Posture

The word **Core** can sound like a decorative name for a model selector. It is closer to a declared operating posture for the machine.

A Core defines which model carries the conversation, which hardware owns that model, whether the AMD lane is reserved for specialist work, and what kind of work the Operator is preparing to do. It also defines what must be stopped, preserved, restored, or refused during a transition.

The current arrangement looks like this:

| Core | Conversation | AMD lane | Intended posture |
| --- | --- | --- | --- |
| **Soul Core** | Gemma on AMD | Occupied by Chat | Primary conversation and multimodal work |
| **Soul-Lite Core** | Qwen on NVIDIA | Free for the Operator | Keep Soul/ present while releasing AMD |
| **Creative Core** | Qwen on NVIDIA | Creative models on demand | Music and visual generation |
| **Free Core** | Unloaded | Free | Release all conversational and development models |
| **Dev Core** | Qwen on NVIDIA | GPT-OSS 20B on AMD | Bounded local development reasoning |

Some of the internal names remain `daily`, `amd-free`, and `music`. Those names predate the current interface and remain stable so existing private state does not break every time I become dissatisfied with a label.

This is one of the less glamorous parts of building something meant to retain continuity: even the names you outgrow may become part of the machine's history.

## The Core Where Soul/ Lives

**Soul Core** is the primary conversational home.

Gemma 4 12B Instruct runs through Ollama and Vulkan on AMD. It provides the strongest current balance of Soul/'s intended voice, long-context continuity, structured responses, tool selection, and visual understanding.

This is also the Core used when Soul/ needs to inspect an explicitly provided image or one previewed screen capture. The multimodal path belongs with the larger AMD model; it does not silently ask the smaller NVIDIA model to improvise a visual answer it was not selected to provide.

Soul Core is the most capable general conversational posture, but it occupies the machine's largest GPU. That is not always where I want those resources.

## Soul-Lite Is Not Lesser Soul

**Soul-Lite Core** moves Chat to Qwen3 8B through `llama.cpp` and CUDA on NVIDIA.

The smaller name describes the runtime footprint, not a reduced set of identity rules. Soul/ retains the same conversations, shared context, skill contracts, memory boundaries, and approval system. The underlying model may phrase something differently or have less room for a demanding synthesis, but it does not inherit a different personality or a looser definition of truth.

The AMD GPU is then free for me to use outside Soul/.

That distinction matters on a workstation. A local assistant that treats every available accelerator as permanent personal property is less a familiar and more a very articulate resource leak.

Soul-Lite lets Soul/ remain available without requiring the machine to remain arranged around its largest conversational model.

## Creative Core Is An Agreement About Intent

**Creative Core** also keeps Qwen on NVIDIA.

The difference is intent.

In Creative Core, the AMD lane is available to bounded specialist runtimes such as ACE-Step for music, FLUX for still imagery, and the reviewed motion models used by Visual Studio. Those models are loaded for one approved foreground operation and released afterward. They do not remain resident while waiting for inspiration.

Because Soul-Lite and Creative Core share the same Qwen conversation profile, moving between them should not require stopping and restarting the model merely to rename what the AMD card is being saved for.

That turned out to be an important implementation detail.

An early transition path treated every Core change like a full runtime replacement. The repaired path first verifies that Qwen is already active and certainly idle. It then previews an exact intent-only transition, binds confirmation to that preview, and updates the private Core record without issuing unnecessary model-service commands.

Same conversational runtime. Different declared use of the machine.

The distinction prevents churn while preserving something more important than efficiency: Soul/ still knows whether AMD is free for me or reserved for a creative action. A shared model profile does not make the operating postures interchangeable.

<span class="image fit"><a href="/assets/images/five-cores-creative-gate.jpg" target="_blank" rel="noopener"><img src="/assets/images/five-cores-creative-gate.jpg" alt="Soul Slash Creative Core activation preview showing the current and target Cores, Qwen model, NVIDIA accelerator, zero active work, and exact approval phrase" loading="lazy" width="1100" height="900" /></a></span>

*Opening a Core preview changes nothing. Before Creative Core can be activated, Soul/ shows the current and target arrangements, verifies that no work is active, discloses the runtime involved, and requires an exact approval action.*

## Free Core Is A Deliberate Absence

**Free Core** may be my favorite addition because it does less.

It unloads both conversational and development models. The authenticated dashboard becomes inert and visibly blurred except for Core selection. There is no quiet fallback, no smaller model loaded to keep up appearances, and no attempt to act conversational while the system has no conversational runtime.

If Soul/ has no brain loaded, the interface says so.

Free Core returns both GPUs and the associated memory to the Operator. It is useful when the workstation needs to become something else for a while, but it also tests an architectural principle: Soul/ must be able to stop without treating absence as failure.

A system that can only preserve its identity by running continuously does not really own its continuity. It is depending on uptime.

Soul/'s conversations and records remain where they belong. Selecting another Core restores a reviewed runtime arrangement and allows the dashboard to resume. Nothing tries to infer which model I probably meant or load one because an inactive screen felt inconvenient.

<span class="image fit"><a href="/assets/images/five-cores-free-gate.jpg" target="_blank" rel="noopener"><img src="/assets/images/five-cores-free-gate.jpg" alt="Soul Slash Free Core activation preview showing no target model, released accelerator resources, zero active work, and an exact approval phrase" loading="lazy" width="1100" height="900" /></a></span>

*Free Core is previewed as exactly what it is: no target model and released accelerator resources. The dashboard does not describe a hidden fallback or pretend that an unloaded assistant remains conversationally available.*

## Dev Core Borrows A Different Kind Of Mind

**Dev Core** is the largest departure from the original three.

Qwen continues carrying Chat on NVIDIA while GPT-OSS 20B remains resident on AMD for local development reasoning. This gives Soul/ a specialist model suited to structured analysis, critique, proposal drafting, and candidate implementation material without replacing the conversational model that maintains the exchange around it.

Selected Dev Core is useful when several development requests are expected. GPT-OSS can remain resident across those bounded requests instead of paying the load cost repeatedly.

Soul/ can also borrow the Dev runtime for one scoped task without permanently entering Dev Core.

From Soul Core, Chat temporarily moves to the Soul-Lite arrangement, GPT-OSS performs one exact request, the development model is released, and Soul Core is restored. From Soul-Lite, Qwen can remain where it is while the temporary Dev work uses AMD. Creative Core blocks the request rather than preempting active generation, and Free Core remains deliberately unavailable.

The restoration is part of the operation, not a hopeful cleanup step.

Live testing covered Creative blocking, restoration to Soul-Lite and Soul Core, and reuse of one resident GPT-OSS runtime across multiple selected-Dev requests. Failures remain visible. There is no automatic retry queue continuing development work after everyone has stopped watching.

## A Developer Without Keys

Giving a larger model a development role created an obvious question: what is it actually allowed to touch?

Very little.

The Soul Dev Worker receives one exact, non-secret context packet selected by the calling system. A filename included in that packet is receipt metadata, not permission to open the file. GPT-OSS receives no repository reader, filesystem writer, shell, external network, Git access, test runner, approval mechanism, or merge authority.

It can return structured analysis, critique, or candidate unified-diff text.

The candidate is still text.

Its request is limited in size, hashed, previewed, confirmed, time-bounded, and validated against a closed output schema. Codex or the Operator must verify the claims against the real source, decide whether any proposed edit is worth reproducing, run the appropriate tests, and retain every decision about Git or deployment.

This may sound excessively restrictive for a model described as a development worker.

That restriction is the feature.

Reasoning quality and operational authority are different resources. GPT-OSS can contribute the former without receiving the latter. Soul/ can ask a specialist for a second opinion without handing it the building because it produced a convincing patch.

Skill Studio uses the same philosophy. An approved proposal can ask the local Dev lane for one bounded read-only Beta candidate, run deterministic checks inside a networkless sandbox, and stop at human review. Passing those checks does not promote the skill or erase either approval gate.

<span class="image fit"><a href="/assets/images/five-cores-dev-gate.jpg" target="_blank" rel="noopener"><img src="/assets/images/five-cores-dev-gate.jpg" alt="Soul Slash Dev Core activation preview showing the verified Qwen chat engine, NVIDIA accelerator, zero active work, and exact approval phrase" loading="lazy" width="1100" height="900" /></a></span>

*Dev Core uses the same explicit runtime gate. This preview concerns the Core arrangement only; it does not authorize GPT-OSS to inspect a repository, use tools, apply a candidate patch, or make any Git decision.*

## Switching Is Still An Operator Action

None of the five Cores can be selected by model text.

A transition begins with an explicit click. Soul/ previews the current and requested arrangements, checks active work and resource leases, records what will stop or start, and binds confirmation to that exact state. Execution revalidates those conditions so an old preview cannot authorize a different machine state later.

Creative actions can disclose a required Core transition as part of their exact action preview. The same click may authorize the disclosed transfer and the bounded generation together, but Soul/ must still explain the active Core, required Core, whether a transfer is included, and why.

There is no automatic failover. There is no idle timer quietly unloading a model. There is no background policy deciding that another Core would be more efficient now.

The machine may know how to rearrange itself.

It does not get to decide when it should.

## One Soul Above The Hardware

Five Cores now cover five meaningfully different states:

- Soul/ at full conversational and visual capability.
- Soul/ present with AMD returned to the Operator.
- Soul/ present while AMD performs bounded creative work.
- Soul/ deliberately stopped with both GPUs released.
- Soul/ present while a specialist development model reasons over one reviewed scope.

Those states cross model families, inference servers, GPU manufacturers, generations of hardware, and even the presence or absence of a loaded conversational model.

The thing I am trying to preserve is not identical prose from every configuration.

It is continuity of identity, evidence, memory, capability, and authority.

Soul/ should know what it knows, disclose what machinery produced an answer, retain the same boundaries when a specialist becomes available, and return the workstation to the state I actually selected.

Five Cores do not make five Souls.

They make one Soul/ that is becoming considerably better at understanding what kind of machine it is allowed to be right now.
