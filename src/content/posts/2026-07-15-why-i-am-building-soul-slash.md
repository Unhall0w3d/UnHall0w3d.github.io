---
title: "Why I Am Building Soul/"
date: 2026-07-15T08:00:00-04:00
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
description: "Why I started building Soul/, a local-first assistant designed around conversation, useful action, explicit approval, and human control."
image: "/assets/images/soul-slash-conversation-social.png"
imageAlt: "Soul Slash interface illustrating a fictional, approval-gated Downloads cleanup conversation."
imageWidth: 1200
imageHeight: 630
draft: false
---

## Does The World Really Need Another AI Assistant?

Probably not.

It already feels like every company with a website, an application, or a sufficiently ambitious toaster has added some form of AI assistant to it. Most of them will summarize something, answer a question, generate text, and occasionally assure you with tremendous confidence that a feature exists three menus away from where it actually does.

So naturally, I decided to build one too.

The project is called [Soul/](https://github.com/Unhall0w3d/soul-slash), pronounced “Soul Slash.” The name is a little strange, the repository is already larger than I originally intended, and explaining it as “my local AI assistant project” is technically accurate in the same way that describing a data center as “a room with some computers” is technically accurate.

It misses the part I actually care about.<!--more-->

I am not building Soul/ because I think the missing piece in my life is another chat box. I am building it because the assistants available today keep stopping just short of becoming the thing I want them to be.

They can talk, but they do not really know my environment. They can tell me how to do something, but usually cannot do it without handing the work back to me. When they *can* act, the process is often hidden behind a platform I do not control. Their memory is inconsistent, their integrations exist at the pleasure of a vendor, and whatever relationship I build with the system can disappear with the next product decision.

I wanted to see if I could build this differently.

## An Assistant That Belongs To Me

The simplest reason for Soul/ is ownership.

I want an assistant that lives alongside my Linux systems, my projects, and my workflows. I want to be able to inspect it, change it, move it to another machine, and understand why it did what it did. I do not want its continued existence to depend entirely on a subscription tier, a company roadmap, or an API remaining available forever.

That is where “local-first” enters the picture.

Local-first does not mean pretending a small model running on my computer is secretly better at everything than the largest cloud models. It is not. Some questions benefit from a larger model, current research, or more compute than I have sitting under my desk. Refusing to acknowledge that would be less a design philosophy and more an elaborate way to make the assistant worse.

Instead, Soul/ is being designed so the local system is home base. Conversation, context, private information, routine decisions, and local capabilities should remain local whenever possible. Cloud models can still be useful for research, critique, documentation, or difficult drafting, but they should be called deliberately, with a clear boundary around what they receive and what authority their answers have.

The cloud can help. It does not get the keys to the building.

## The Model Is Not The Assistant

One of the more important decisions in Soul/ is that the language model is not treated as the entire assistant.

The model is very good at language. It can understand a loosely worded request, carry a conversation, summarize information, and connect ideas. It can also improvise, misunderstand, forget an important detail, or invent a command with the calm delivery of someone who definitely tested it first.

That is acceptable when we are discussing ideas. It is less charming when files are being moved.

Soul/ separates conversation from exact action. The model helps understand what I am trying to accomplish. Deterministic skills handle work that needs repeatable output, access to actual system state, verification, or an audit trail.

I do not want to memorize a magic phrase that maps to a script. I want to be able to say what I am trying to do, have Soul/ identify the appropriate capability, show me the plan when necessary, perform the approved work, and then explain what happened like a normal conversation.

For example, “clean up my Downloads folder” sounds simple until an assistant has to decide what *clean up* means. Delete everything? Move old files? Ignore folders? What counts as old? What happens if it guesses wrong?

Soul/ should inspect first, present a bounded plan, ask for approval, move the exact approved files to Trash, verify the result, and leave a record. The conversational part makes the interaction natural. The deterministic part keeps “natural” from becoming “surprising.”

<span class="image fit"><img src="/assets/images/soul-slash-conversation-demo.svg" alt="Illustrative Soul Slash conversation showing a Downloads cleanup plan awaiting explicit approval" /></span>

*Illustrative demo using fictional data. The important part is not the cleanup itself—it is that Soul/ has inspected and planned the work without quietly deciding it has permission to act.*

## Useful, But Not Unsupervised

There is a popular version of the AI future where an agent quietly runs all the time, watches everything, makes decisions on your behalf, and occasionally presents the finished result as if a very efficient ghost has moved into the computer.

I can see the appeal.

I can also see the incident report.

Soul/ is deliberately being built around bounded work. A skill should start because I requested something, perform a specific task, report success or failure, and stop. It should not quietly install a service, create a scheduled task, start an endless watcher, or continue accumulating authority somewhere in the background because it seemed helpful at the time.

That constraint is not something I plan to remove once the project is “mature enough.” It is part of the reason the project exists.

I want useful automation without creating something I have to monitor like an untrusted administrator. Planning, approval, execution, and verification are separate steps because those separations matter. Destructive-looking file operations favor recoverable Trash workflows. Approval is scoped to the action being approved. Model output can recommend something, but it cannot authorize itself.

No green lights without gauges.

## Memory That Has To Earn Its Place

An assistant becomes much more useful when it remembers what you are working on, the tools you use, decisions you have already made, and how you prefer things to be done.

It also becomes much more unsettling if it stores everything indiscriminately and leaves you guessing what it knows.

Soul/ is intended to have continuity without turning memory into a mysterious pile of conversation debris. Working context, project information, preferences, and longer-term lessons are different kinds of memory and should not all be treated the same way.

Something mentioned once should not automatically become a permanent fact. A useful observation can be staged as a candidate, reviewed, corrected, approved, or forgotten. Durable memory should have provenance. I should be able to see where it came from and remove it when it is no longer true.

That may sound overly cautious for remembering that I use Linux or prefer a particular tool. The caution becomes much more reasonable when the same memory influences what an assistant does on the system.

Continuity is valuable. Invisible assumptions are not.

## Teaching It New Things Without Losing The Plot

The other large piece of Soul/ is the skill system.

My work crosses Linux administration, software projects, Cisco Unified Communications, documentation, troubleshooting, research, and whatever odd task has wandered into view that week. No assistant is going to arrive knowing the exact workflows I want for all of that.

It needs a way to grow.

What I do not want is for “growth” to mean collecting a haunted attic full of scripts, generated glue, overlapping tools, and capabilities nobody has reviewed since the afternoon they first worked.

Soul/ has a Skill Studio where a missing capability can become a proposal, move into an isolated beta implementation, be tested and reviewed, and only then be intentionally promoted into the production skill inventory. A model can help draft the idea. Codex can help implement it. Tests can prove that the code behaves as expected. None of those things, on their own, get to decide that the capability is trusted.

That remains a human decision.

In a way, Soul/ is both an assistant and a framework for teaching an assistant new things without handing the lesson plan to the assistant.

<span class="image fit"><img src="/assets/images/soul-slash-skill-studio-demo.svg" alt="Illustrative Soul Slash Skill Studio showing proposal, isolated beta, and production promotion stages" /></span>

*The Skill Studio lifecycle, shown with a fictional skill. A proposal can become a tested candidate, but tests and model output do not get to promote it into production.*

## Where It Is Today

Soul/ is still experimental, but it is no longer a README describing something I might build one day.

It has persistent multi-turn conversations through the terminal and a local dashboard. It can route requests toward deterministic skills, maintain conversation artifacts and workspace context, record execution history, and handle explicit approval flows. It has human-reviewed memory promotion, a Skill Studio with proposal, beta, and production stages, and a self-assessment surface for looking at its environment, models, and missing capabilities.

<span class="image fit"><img src="/assets/images/soul-slash-self-improvement-demo.svg" alt="Illustrative Soul Slash Self Improvement assessment identifying a capability gap without making system changes" /></span>

*Self Improvement is meant to identify and explain useful gaps, not silently rewrite the assistant. This fictional assessment ends with a recommendation and zero mutations.*

It can perform a small number of real, bounded actions today. That number is intentionally smaller than it could be.

The goal has not been to bolt on as many tools as possible and declare victory when the demo looks impressive. I have been building the layers underneath first: conversation, intent, skills, approvals, artifacts, memory, review, and the boundaries between them.

This is the slower route. It also means every new capability has somewhere sensible to live.

## Eventually, I Want To Talk To It

Voice is part of the longer-term plan, and not only because speaking to a computer satisfies a very specific science-fiction impulse I have apparently decided to indulge.

The interface should eventually disappear into the work. I should be able to ask a question or request an approved action without stopping what I am doing, opening another application, and operating a dashboard just to operate the assistant.

There are boundaries here too. Voice should require explicit activation. Speech processing should remain local where practical. There should not be a permanent cloud microphone stream, indefinite raw-audio retention, or hidden recording waiting for a convenient explanation later.

I want ambient availability, not ambient surveillance.

There is still a considerable amount of work between the current dashboard and that experience. Fortunately, “considerable amount of work” has never been especially effective at stopping me from starting a project.

## So, Why Even Do This?

Most of the individual parts already exist somewhere.

There are local models, speech recognition systems, automation frameworks, chat interfaces, plugin ecosystems, memory databases, and cloud APIs. Soul/ is not an attempt to claim I invented any of them.

The experiment is in assembling those pieces under a philosophy I have not found in one existing product: an assistant that can converse naturally, understand the environment around it, use real tools, retain useful continuity, and learn new capabilities—while remaining inspectable, recoverable, and governed by the person using it.

I want to find out whether an AI assistant can become genuinely useful without also becoming invasive, unpredictable, disposable, or entirely dependent on one vendor.

Maybe Soul/ eventually becomes the assistant I have been looking for. Maybe the project mostly teaches me exactly why building that assistant is difficult. Realistically, both of those things are probably going to happen at the same time.

Either way, it is worth finding out.

The repository is available here:

[github.com/Unhall0w3d/soul-slash](https://github.com/Unhall0w3d/soul-slash)

I will write more about the architecture, the skill lifecycle, local models, memory, and the many ways a supposedly simple conversational feature can become an entire subsystem as the project develops.

For now, that is the reason to build Soul/.
