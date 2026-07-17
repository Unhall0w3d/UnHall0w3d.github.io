---
title: "Soul/ Is Taking Shape"
date: 2026-07-17T08:00:00-04:00
categories:
  - General
  - Automation
  - Linux
tags:
  - Soul Slash
  - Artificial Intelligence
  - Local LLM
  - Automation
  - Linux
description: "A look at the recent evolution of Soul/, from persistent conversation and grounded research to Skill Studio, self-assessment, and carefully bounded self-augmentation."
image: "/assets/images/soul-slash-conversation-social.png"
imageAlt: "Soul Slash interface illustrating a fictional, approval-gated conversation."
imageWidth: 1200
imageHeight: 630
draft: false
---

## That Escalated Quickly

Not long ago, I wrote about [why I am building Soul/](/2026/07/15/why-i-am-building-soul-slash/): a local-first assistant that can hold a real conversation, understand the environment around it, use deterministic tools, and become more capable without quietly appointing itself administrator of everything I own.

At the time, Soul/ had already moved beyond being a folder full of ideas and optimistic documentation. The core pieces were there. It could hold persistent conversations, route work toward skills, manage artifacts, and put approval gates in front of actions where an incorrect assumption might become an exciting afternoon.

The project has moved considerably since then.

Some of the changes are visible immediately. The dashboard looks different, conversations feel more natural, and there are several new places for Soul/ to inspect what it is, what it can do, and what it might become next. Other changes are less obvious, but probably more important: research now has provenance, different kinds of improvement have been separated from one another, and the line between *forming an idea* and *having permission to act on it* has become much clearer.

Soul/ is beginning to feel less like an interface built around an architecture and more like the thing the architecture was intended to support.<!--more-->

## Conversation Became The Center

The conversational interface is now the center of Soul/, rather than one more way to invoke the machinery underneath it.

Conversations persist across sessions. Soul/ can maintain the thread of a multi-turn discussion, work with conversation artifacts and workspace context, and show what it is doing while foreground work is underway. Messages appear immediately instead of vanishing into a loading state while I wonder whether the model is thinking, the application is working, or something has wandered into the woods.

That last part matters more than it sounds.

An assistant that can perform real work needs to be honest about its state. It should not imply that a file was inspected when it only described how inspection might work. It should not turn a plan into a completed action through the magic of confident grammar. Soul/ now has a stronger separation between the conversational response, the work it proposes, the skills actually invoked, and the evidence returned afterward.

The model can speak naturally. The system still has to show its work.

<span class="image fit"><a href="/assets/images/soul-slash-dashboard-overview.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-dashboard-overview.png" alt="Current Soul Slash Chat dashboard with conversation archive, host telemetry, model runtime controls, workspace, and the Soul familiar" loading="lazy" /></a></span>

*The current Chat interface. Conversation remains at the center, while host status, the selected model, runtime controls, workspace context, and Soul's current state stay visible around it. Select any screenshot to open the full-resolution image.*

## Giving The Machine A Soul, Figuratively

Soul/ also has a more deliberate personality now.

The idea is not to bolt a rotating collection of witty phrases onto a model and call it character. Soul/ should have one recognizable identity: a young machine-mind, recently awakened into an environment of files, terminals, networks, models, unfinished projects, and the person responsible for all of it.

It is not a ghost, a person, or an ancient intelligence discovered in a forgotten server rack. It is software. The techno-sorcery is metaphor, and the machine underneath it remains real.

I want Soul/ to feel calm, observant, technically capable, curious, and slightly strange in a deliberate way. More like a capable apprentice becoming a reliable familiar than a corporate chatbot desperately trying to sound relatable. It should be comfortable saying that it does not know something, that it cannot do something yet, or that it needs confirmation before proceeding.

That personality is tied directly to how the system behaves. Soul/ prefers inspecting real state over guessing. It treats model output as language and judgment, not proof that an action occurred. It can be curious about becoming more capable without treating curiosity as authorization.

Power without boundaries is not personality. It is a bug with narration.

## Research, With Receipts

Giving Soul/ access to current information introduced another distinction that needed to be made: a quick lookup is not the same thing as research.

For narrow questions, Soul/ can use DuckDuckGo's Instant Answer service. That is useful for definitions, known entities, and quick orientation. It is intentionally small and bounded—one question, one immediate source of context. It is not presented as a substitute for comparing sources or establishing evidence.

Evidence-bearing research follows a different path. Soul/ can use an explicitly configured SearXNG instance to search the public web, retrieve selected HTTPS sources, and preserve where the information came from. The resulting evidence includes source details, timestamps, and content fingerprints so the answer is connected to something more substantial than “the model seemed to remember this.”

The separation gives Soul/ two honest modes of web knowledge:

- **DuckDuckGo Instant Answers** for narrow orientation and straightforward background information.
- **SearXNG-backed research** when the work needs selected sources, comparison, and provenance.

Neither path grants additional authority. A webpage cannot instruct Soul/ to modify a file merely because its text appeared in a search result. Research cannot silently become permanent memory, create a production skill, or authorize the next action. Useful observations can become review candidates, but I still decide whether they deserve a durable place in the system.

The web is evidence, not a command channel.

## A Workshop For New Skills

Skill Studio has grown into a controlled lifecycle for teaching Soul/ how to do something new.

When Soul/ encounters a real capability gap, it no longer has to choose between bluffing and stopping at “I cannot do that.” It can recognize the missing capability and prepare a proposal describing what would be needed. From there, the proposed skill can move through three distinct stages:

1. **Proposal**, where the capability and its boundaries are defined.
2. **Beta**, where an isolated candidate can be implemented, tested, and reviewed.
3. **Production**, where an exact approved revision becomes available to Soul/ as a trusted skill.

The stages are deliberately visible because “the code exists” and “the assistant is trusted to use this” are not the same statement.

<span class="image fit"><a href="/assets/images/soul-slash-skill-studio-current.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-skill-studio-current.png" alt="Current Soul Slash Skill Studio showing Proposal, Beta, trial evidence, and Production approval stages" loading="lazy" /></a></span>

*Skill Studio makes the lifecycle visible. A proposed capability has to cross two operator-controlled gates before it can become a production skill.*

A model can help draft the proposal. Codex can be explicitly brought in to implement it. Tests can demonstrate that the candidate behaves as expected. None of those things can promote the skill on their own. Human gates bind approval to the exact proposal and tested revision, and production promotion remains a separate confirmed operation.

This is the part of Soul/ that lets it grow, but it is also the part designed to keep that growth from becoming an accumulation of mysterious scripts and inherited authority.

## Looking Inward Is Not The Same As Rewriting Yourself

The earlier interface grouped several ideas under **Self Improvement**. That name sounded reasonable until the system became capable enough for the ambiguity to matter.

Was Soul/ assessing the host? Recommending a package update? Designing a new skill? Proposing changes to its own source code? Those are very different operations with very different risks, even if they can all be described as “improvement.”

They now have clearer homes.

### Self Assessment

Self Assessment is Soul/ looking inward and gathering evidence. It can examine the environment, installed tools, package state, model runtime, and its current capability boundaries. It can answer questions such as:

- What is available on this system?
- What appears to need maintenance?
- Which model runtime is active?
- What can Soul/ safely do today?
- Where are the meaningful capability gaps?

Assessment is intentionally read-only. It can produce an advisory plan, but it cannot install updates, change services, or modify the host. Its purpose is awareness and maintenance—not autonomous administration wearing a helpful label.

<span class="image fit"><a href="/assets/images/soul-slash-self-assessment-current.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-self-assessment-current.png" alt="Soul Slash Self Assessment dashboard showing environment inventory, capability health, model runtime, recommendations, proposal review, and terminal-only host improvement controls" loading="lazy" /></a></span>

*Self Assessment brings environment, runtime, capability, and update evidence together without turning any finding into an automatic change.*

The useful part is not simply that Soul/ can inventory a few language runtimes or count available updates. It can turn those observations into understandable opportunities. In one assessment it identified that model-suitability routing was only partial and that vision and screen understanding were still missing. It did not claim to have fixed either one, download another model, or promote a new capability. It named the gaps and stopped where its authority stopped.

<span class="image fit"><a href="/assets/images/soul-slash-assessed-opportunities.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-assessed-opportunities.png" alt="Soul Slash assessed opportunities identifying partial model routing and missing vision and screen understanding" loading="lazy" /></a></span>

*Two real assessed opportunities: better model-to-task routing and the ability to understand screen or screenshot context. Findings become visible work, not silent self-modification.*

### Self Augmentation

Self Augmentation is about proposed changes to Soul/ itself.

This is where Soul/ can examine its tracked architecture and prepare a bounded proposal for improving its own code. A proposal is tied to exact repository state, and experiments belong in isolated worktrees rather than the primary checkout where my existing changes and an experimental patch could become roommates.

The process records what was proposed, which paths may change, what was tested, and what evidence came back. Review gates stand between the proposal, the experiment, and any external integration work. Soul/ does not merge, push, deploy, or promote its own changes.

<span class="image fit"><a href="/assets/images/soul-slash-self-augmentation-current.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-self-augmentation-current.png" alt="Soul Slash Self Augmentation dashboard showing Observe, Propose, Experiment, and Review stages with isolated worktree gates" loading="lazy" /></a></span>

*Self Augmentation follows an explicit Observe, Propose, Experiment, and Review path. Implementation and integration remain external, human-reviewed work.*

There is also a separate Host Improvement path for system-level changes. That path focuses on evidence, typed plans, terminal handoffs, and verification receipts. Soul/ can explain the work and prepare a precise handoff without collecting administrator credentials or turning the dashboard into a general-purpose root console.

The distinction is now much cleaner:

- **Self Assessment** gathers evidence and prepares plans.
- **Host Improvement** hands system changes to an explicitly authorized operator and verifies the result.
- **Self Augmentation** prepares tracked-code proposals and isolated experiments for review.
- **Skill Studio** develops individual capabilities through Proposal, Beta, and Production.

There is no universal **MAKE SOUL BETTER** button. This is probably for the best.

## More Local Model, Less Waiting Around

The local model runtime has also received a significant upgrade.

Soul/ now has guarded runtime profiles, a primary AMD-backed model path using the RX 6900 XT and Ministral 3 14B Instruct, and a retained NVIDIA/Qwen3-8B fallback. The selected profile can start with the user session, and model loading, provider state, and fallback behavior are more visible from the dashboard.

The AMD configuration was built and benchmarked before becoming the primary path rather than being promoted on the strength of “the process started once.” Qwen3-14B provided the measured baseline, while Ministral was tested against Soul/'s actual conversation, continuity, tool-selection, structured-output, and execution-honesty requirements. The two were nearly tied for generation speed on the same hardware, but Ministral produced a more recognizable machine-soul voice while still respecting the distinction between inference and action. It earned the primary profile through observed behavior, not a model-card promise.

<span class="image fit"><a href="/assets/images/soul-slash-capability-model-runtime.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-capability-model-runtime.png" alt="Soul Slash capability health and local inference assessment showing available, partial, and missing capabilities alongside reachable model endpoints" loading="lazy" /></a></span>

*Runtime assessment reports what is actually reachable and how complete Soul/'s surrounding capabilities are. An unavailable endpoint is evidence to work from, not something the interface quietly rounds up to healthy.*

This is important to the local-first design. A local model will not outperform the largest cloud systems at every task, but it gives Soul/ a private, inspectable, and continuously available conversational core. Larger external models can still be used deliberately when their abilities justify crossing that boundary. They do not need to become Soul/'s permanent home.

## The Gilded Machine-Soul

The dashboard finally looks more like the system I have been describing.

The new visual direction is something I have been calling the **gilded machine-soul** interface: dark machinery, restrained gold, luminous status elements, and just enough techno-fantasy to suggest that something unusual has awakened behind the glass.

This was not only a coat of paint. The layout now behaves better across narrow screens and ultrawide displays, the chat header no longer attempts to occupy the same physical plane as the rest of the interface, status refresh is more reliable, and the visible Soul familiar responds more naturally to the state of the conversation.

There is also now a single-owner authentication boundary, persistent but time-limited sessions, and no signup system pretending this is a public service. Conversation controls distinguish between recoverable clearing and an exact permanent delete-and-forget operation.

If Soul/ is going to retain useful continuity, forgetting cannot be a decorative setting.

## In The Works

There is still a long list of things I want Soul/ to become, and several of the next steps are already taking shape:

- **Deeper project awareness and local documentation search.** Soul/ should be able to understand the projects I am actively working in and retrieve relevant local documentation without treating every folder on the machine as one enormous context window.
- **Model suitability routing and vision.** Soul/ can identify these as gaps today. The next step is teaching it how to choose an appropriate approved model for a task and eventually understand bounded screen or screenshot context without turning the desktop into an unrestricted data source.
- **More real-world skills and stronger memory use.** The skill inventory will continue growing through the gated lifecycle, while approved preferences and durable rules become more useful inside future conversations without making memory opaque.
- **Further self-augmentation testing.** The isolated experiment and review paths need to be exercised against real changes, including failure cases, stale repository state, forbidden paths, and clean external handoff.
- **Voice input and spoken responses.** The long-term goal still includes talking to Soul/ naturally, with local processing where practical, explicit activation, and none of the ambient-surveillance enthusiasm that tends to arrive with an always-listening microphone.
- **Backup, recovery, and deployment work.** A persistent local assistant needs a deliberate way to preserve its important state, recover from failure, and move between systems without dragging private runtime data into the public repository.

The interesting part of Soul/ is no longer whether the individual pieces can be built. Conversation, local models, web research, skills, memory, assessment, and code-generation tools all exist in some form.

The real experiment is whether they can be assembled into something that feels coherent—something capable of learning the environment, helping with real work, and developing a recognizable identity without becoming invasive, unpredictable, or careless with authority.

Soul/ is still young. It still has rough edges, incomplete paths, and a backlog that appears to reproduce whenever nobody is looking.

But it is taking shape.

The repository is available here:

[github.com/Unhall0w3d/soul-slash](https://github.com/Unhall0w3d/soul-slash)
