---
title: "Soul/ Has More Than One Brain Now"
date: 2026-07-19T08:00:00-04:00
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
description: "Soul/ can now move between local models, GPU architectures, and purpose-built Cores without leaving its identity, memory, or boundaries behind."
image: "/assets/images/soul-slash-conversation-social.png"
imageAlt: "Soul Slash interface illustrating a fictional, approval-gated conversation."
imageWidth: 1200
imageHeight: 630
draft: false
---

## Apparently One Brain Was Not Complicated Enough

The last time I wrote about [Soul/](/2026/07/17/soul-slash-is-taking-shape.html), it had recently become a much more convincing conversational system. It could maintain continuity, research with provenance, assess its own environment, propose new skills, and distinguish between looking at itself and asking permission to change itself.

It also had one primary local model running on one primary GPU.

That arrangement lasted almost an entire day.

Soul/ can now move between different local language models, inference servers, GPU manufacturers, and generations of hardware without becoming a different assistant every time the machinery underneath it changes. It can release the larger AMD GPU when I need it, preserve conversation on an older NVIDIA card, and divide the machine between conversation and specialist work when it is generating music.

Around that architecture, Music Studio has grown from an experiment into a bounded production system, Visual Studio has arrived, private memory has been separated from the public repository, and Soul/ has become considerably better at explaining what is occupying the machine and why.

The dashboard reflects some of this. The more interesting part is what had to happen underneath it.<!--more-->

<span class="image fit"><a href="/assets/images/soul-slash-core-dashboard-avatar.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-core-dashboard-avatar.png" alt="Soul Slash Chat dashboard in Music Core showing the new Soul avatar, Qwen conversation runtime, and AMD music engine status" loading="lazy" /></a></span>

*Soul/ in Music Core. Qwen keeps the conversation present on NVIDIA while the dashboard reports the AMD music lane separately. The new avatar has also replaced the original glyph as Soul/'s presence inside the Chat pane. Select any screenshot to open the full-resolution image.*

## The Model Is Still Not The Assistant

One of the ideas behind Soul/ from the beginning has been that the language model is not the assistant.

The model is an important part of it. It gives Soul/ language, interpretation, judgment, and the ability to carry a conversation that does not feel like issuing commands to a particularly ornate shell script. It is also replaceable.

Soul/'s identity, conversation history, project context, memory rules, truth safeguards, tool contracts, approval boundaries, and records of what actually happened live outside the model. Those pieces belong to Soul/ itself.

That distinction has become much less theoretical.

The previous primary model was Ministral 3 14B running through `llama.cpp` and Vulkan on the AMD RX 6900 XT. It had earned that position through testing against Soul/'s actual requirements: conversation, continuity, structured output, tool selection, execution honesty, and the peculiar young-machine-mind voice I want Soul/ to have.

The new primary model is Gemma 4 12B Instruct Q4_K_M, running through Ollama and Vulkan on the same AMD card. Soul/ also retains Qwen3 8B through `llama.cpp` and CUDA on an NVIDIA GTX 1070.

That means there are now meaningful differences on nearly every layer:

- Different model families.
- Different inference servers.
- Different provider protocols.
- Different GPU manufacturers.
- Different graphics and compute APIs.
- Different generations of hardware separated by roughly half a decade.

Soul/ still has to be Soul/ across all of them.

## A Core Is More Than A Model Selector

The mechanism organizing this is something I have been calling **Cores**.

A Core is not simply a friendly name for a model. It describes an operating posture for the whole machine: which model provides conversation, which GPU owns that work, which specialist resources are available, and what the Operator is trying to preserve for something else.

Soul/ currently has three:

- **Daily Core** runs Gemma on the AMD RX 6900 XT. It is the normal conversational home, while the NVIDIA card remains available for bounded specialist work.
- **AMD-Free Core** moves conversation to Qwen on the NVIDIA GTX 1070 and leaves the AMD card alone. This is useful when I need the larger GPU for work outside Soul/.
- **Music Core** also keeps Qwen conversation on NVIDIA, but makes the AMD card available to ACE-Step for foreground music generation.

The distinction matters because “switch to another model” and “rearrange ownership of the machine's compute resources” are not the same operation.

Changing Cores requires a preview of the exact transition, a check for active work and resource leases, and confirmation bound to what was inspected. Soul/ will not interrupt a generation, evict a model that is still working, or decide on its own that a fallback would probably be fine.

There is also no need to restart a model merely to change the label on the door. AMD-Free Core and Music Core both use Qwen for conversation. If Qwen is already active and demonstrably idle, Soul/ can change the recorded operating intent without needlessly unloading and reloading it.

That may sound like a small optimization. It is also the difference between designing around what the system is actually doing and writing a sequence of service restarts until the interface appears correct.

<span class="image left"><a href="/assets/images/soul-slash-core-runtime-selector.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-core-runtime-selector.png" alt="Soul Slash model runtime panel showing the active NVIDIA Qwen fallback and available AMD Gemma profile" loading="lazy" /></a></span>

*The runtime panel makes the split explicit: Qwen is active as reserve chat on NVIDIA while Gemma remains available as the AMD Daily Core. Loading and switching remain manual operations.*

<div class="post-clear"></div>

## Keeping The Soul During A Brain Transplant

Moving conversation between models is easy if the only acceptance test is receiving text from both of them.

Keeping the same quality, continuity, personality, structured behavior, and respect for authority is harder.

Gemma was not promoted because it answered one prompt correctly or because a model card had an encouraging collection of benchmark numbers. It was evaluated through Soul/'s real context builder, identity policy, truth guard, temporary state, tool definitions, and output schemas.

The evaluation included persona conversations, twenty-turn continuity tests, exact object and array responses, tool selection without execution, visual inspection, long-form proposals, and the kind of dense reference synthesis Music Studio now needs. Soul/ had to retain project details, understand what belonged to the current conversation, respect the limits of its authority, and remain recognizable while doing it.

It also exposed real differences between providers.

Ollama and `llama.cpp` do not report health, loaded models, activity, or capabilities in the same way. They do not accept every generation control through the same interface, either. Soul/ now accounts for those dialects without relaxing the validation above them. A malformed response does not become acceptable merely because a new model produced it with confidence.

Gemma ultimately produced the strongest balance of continuity, structured behavior, tool use, long-form synthesis, and Soul/'s intended voice. Ministral was retired from the supported production inventory, although its service and weights were left intact rather than being quietly erased as part of the promotion.

Qwen has a different role. It is smaller, runs on the older GTX 1070, and gives Soul/ a capable conversational path when the AMD card needs to do something else. The experience will not be mathematically identical across the two models, but the assistant's identity and operating rules no longer depend on one set of weights remaining loaded forever.

This is closer to what I meant when I said the model is not the assistant.

## Soul/ Started Making Music

The first large beneficiary of the Core architecture is Music Studio.

Music generation began as a feasibility question involving ACE-Step, an aging Pascal GPU, carefully selected CUDA packages, and the familiar optimism of “this should probably work.” The pilot eventually produced complete audio, but the path was held together by a compatibility overlay and a great deal of attention to what the word *success* actually meant.

At one point the backend could finish, create a file, and report success after numerical failure had already turned the latent data into nonsense. Soul/ now inspects the generated plan before allowing synthesis to continue. A file existing is useful evidence that a file exists. It is not proof that music happened.

The production path has since moved to a pinned native ACE-Step Vulkan implementation on the AMD GPU. Music generation is a bounded foreground operation: the model is loaded for the approved work, produces one candidate, and releases the resource afterward. There is no permanent music service waiting in the background and no unattended queue slowly composing an album while I sleep.

Before synthesis, Soul/ checks the language model's audio-code plan for severe collapse. If it has degraded into repetition, the same approved operation may retry with a deterministic new seed. Three collapsed plans stop at human review rather than broadening the request or continuing until something happens to work.

A successful candidate produces a 48 kHz stereo FLAC master, an MP3 listening copy, hashes, duration and codec information, and lineage back to the exact project and request that created it. The intermediate WAV is removed after publication. Failed work is quarantined instead of being promoted into the project as a strangely large mystery file.

Generation also survives moving around the dashboard now. Leaving Music Studio no longer kills the browser connection and takes the job with it. Soul/ owns the bounded job, the dashboard can reattach to its progress, and cancellation still reaches the underlying process group.

This is deliberately not a general background worker system. The operation still has a beginning, a specific scope, an accountable owner, and an end.

<span class="image fit"><a href="/assets/images/soul-slash-music-studio-afterimage-current.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-music-studio-afterimage-current.png" alt="Soul Slash Music Studio showing the Afterimage Current creative brief, project archive, and reference controls" loading="lazy" /></a></span>

*Music Studio's creative brief for Afterimage Current. The project binds intent, duration, musical structure, seed, rights status, references, and eventual candidates into one private record.*

## Revision Without Pretending To Have Ears

Music Studio can now help with revision, reference analysis, and the preparation of an original target.

The wording there is intentional.

Soul/ should not claim that it listened to a piece of music when the conversational model received only text. Operator observations, deterministic machine analysis, and model-generated interpretation are kept separate. Soul/ can reason over the evidence it actually has, explain a proposed revision, and prepare a new candidate without quietly upgrading “I was told this section feels crowded” into “I heard the crowded section myself.”

Reference material follows a similar rule. Soul/ can retain lawful source information, derived evidence, provenance, and content fingerprints. It can combine several reviewed references into a weighted description of roles and musical properties, then synthesize an original target from those observations.

It rejects instructions framed around cloning, imitation, or producing a soundalike. The point is to understand why a reference works and use that understanding to describe something new—not to place a thin semantic curtain over copying it.

Reviewed candidates can also be trimmed at their source edges without overwriting the original. More involved editing, arrangement, internal splicing, fades, and amplification remain outside the current editor. Calling a precise trim “full audio production” would be the software equivalent of calling scissors a recording studio.

<span class="image fit"><a href="/assets/images/soul-slash-music-candidate-visual-companion.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-music-candidate-visual-companion.png" alt="Soul Slash Music Studio candidate showing audio playback, vocal evidence, and a reviewed static visual companion" loading="lazy" /></a></span>

*A generated music candidate remains surrounded by evidence and review controls. Its visual companion is bound to the exact audio candidate rather than becoming a vaguely related file elsewhere on disk.*

## Then It Started Making Pictures

Visual Studio arrived alongside the music work.

It uses a pinned local FLUX.2 Klein 4B Q4 model through `stable-diffusion.cpp` and Vulkan on the AMD GPU. Like Music Studio, it has private projects, versioned briefs, immutable candidates, exact approvals, review records, and deliberate resource ownership.

The initial text-to-image qualification produced a 1024×576 image in roughly ten seconds on the RX 6900 XT. Image-guided editing took considerably longer—about eight and a half minutes—but demonstrated that a source composition could be retained while making a directed change.

<span class="image fit"><a href="/assets/images/soul-slash-visual-studio-first-light.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-visual-studio-first-light.png" alt="Soul Slash Visual Studio showing the First Light Calibration brief and bounded local generation controls" loading="lazy" /></a></span>

*Visual Studio begins with a versioned brief and an exact local-generation preview. The motion lane is visible, but correctly marked as unavailable while qualification remains incomplete.*

Visual candidates can be reviewed and bound to music candidates as companions. The current production video path is intentionally conservative: a reviewed still, controlled framing, matte treatment, fades, and the exact approved audio.

Soul/ briefly explored procedural motion effects. They looked like procedural effects, because that is what they were. They have been removed from the presented generation path rather than being dressed up as something the image model created.

Generated motion remains visible as a future capability, but unavailable until there is a real, qualified model behind it.

Soul/ can now assemble the selected audio, visual, thumbnail, description, and metadata into a deterministic local YouTube package. It cannot upload or publish the package. The last step remains exactly where I want it: outside the assistant, attached to a human decision.

There is already a concrete example of that path: [Afterimage Current](https://www.youtube.com/watch?v=863-KXJRfyA), a three-minute instrumental published through the Soul Slash Synthesis channel. The music, composition, and static visual were produced through Soul/, then assembled into the local video draft without a revision pass.

That last detail is worth preserving. It is not being presented as a painstakingly edited final production or the best result the system could eventually produce. It is a useful record of what came out of one bounded request, one accepted candidate, and one reviewed still before anyone began sanding down the machine marks.

<span class="image fit"><a href="/assets/images/soul-slash-visual-studio-candidates.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-visual-studio-candidates.png" alt="Soul Slash Visual Studio comparing an original text draft with an image-guided revision and human review controls" loading="lazy" /></a></span>

*The original image and guided revision remain separate candidates. Each keeps its timing, origin, rating, disposition, and next available actions instead of allowing an edit to quietly replace its source.*

## Private Memory Became Actually Private

The repository for Soul/ is public. The memory it develops while working with me should not be.

Earlier versions mixed neutral tracked seeds and policy material with the location used for durable shared memory. That was survivable while the stored information was mostly structural. It was not a boundary I wanted to test by eventually committing something personal and discovering the problem through GitHub's excellent email notification system.

Soul/ now has an ignored private memory path. Fresh installations receive neutral public seed data. Existing installations use an explicit copy, verification, and cutover process with restrictive permissions. The original data is not silently moved or deleted, and the public Git history has not been rewritten to make the design appear more prescient than it was.

Soul/ also gained a read-only Storage & Retention assessment. It can inventory private projects, model installations, pilot runs, exports, logs, memory, and temporary artifacts using metadata without reading their contents.

The first real assessment classified roughly 25 GB of local state. About 15 GB belonged to the retired Python and CUDA music runtime, making it the most obvious cleanup candidate. Soul/ identified it and stopped there.

An inventory is not permission to delete things. Even when some of those things are impressively large.

## The Dashboard Is Finally Telling The Truth About The Machine

The visible interface has changed to accommodate all of this, but the useful improvement is not simply that more cards exist.

Soul/'s branding has also become more coherent. The original sigil is still the compact mark for the application—the shape that belongs in the header, favicon, and places where a full character would become visual noise. Earlier dashboard versions also used that small glyph to represent Soul/'s presence inside the Chat pane.

That worked as a status indicator. It did not do much to establish that the conversation belonged to a particular entity.

The Chat pane now uses a full avatar for **Core Presence**. At rest, Soul/ appears masked and quiet. During active foreground work, the unmasked portrait can take its place. The transition is driven by the existing request lifecycle, not by a second model attempting to infer an emotional state from the conversation.

The distinction gives the visual identity two useful scales. The sigil represents the system. The avatar represents the presence inside it.

The surrounding dashboard has followed the same direction. Graphite and deep indigo provide the machinery, ice-blue light carries active state and evidence, and aged bronze marks boundaries and deliberate action. The earlier techno-sorcery idea is still there, but it now feels less like decoration applied to a control panel and more like one visual language shared by Chat, Self Improvement, Music Studio, and Visual Studio.

System Status can now distinguish between the selected Core, the conversational model, the music engine, the provider serving each one, the accelerator involved, the state of the service, and whether the model is actually resident.

Those distinctions prevent several convenient lies. A running service does not necessarily mean its model is loaded. An active NVIDIA conversation does not mean music generation is using NVIDIA. A configured fallback does not mean it is healthy. A process having existed recently does not mean it still owns the GPU.

The navigation has also been reorganized around intent. Skill Studio, Self Assessment, and Self Augmentation now live under Self Improvement. Music Studio and Visual Studio live under Creative Studios. Review Center holds the decisions that still belong to me.

<div class="post-image-grid">
  <a href="/assets/images/soul-slash-self-improvement-navigation.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-self-improvement-navigation.png" alt="Soul Slash Self Improvement navigation containing Skill Studio, Self Assessment, and Self Augmentation" loading="lazy" /></a>
  <a href="/assets/images/soul-slash-creative-studios-navigation.png" target="_blank" rel="noopener"><img src="/assets/images/soul-slash-creative-studios-navigation.png" alt="Soul Slash Creative Studios navigation containing Music Studio and Visual Studio" loading="lazy" /></a>
</div>

*The revised navigation groups related work without flattening their boundaries. Assessment, augmentation, capability development, music, and visual creation still retain separate contracts underneath.*

There is still no emotional inference system deciding that Soul/ feels mysterious on Tuesdays.

Probably a future feature.

## In The Works

The immediate work is less about adding another large tab and more about extending what the new architecture can safely support.

- **Longer music generation.** A technically valid 210-second pilot has been produced, although human listening review and any production decision remain separate. A gated ten-minute qualification is being prepared to test whether ACE-Step can maintain musical structure across a much longer generation without collapsing into repetition, silence, or an accidental seven-minute outro.
- **Better fit-to-task routing.** Cores currently change only through explicit Operator action. Soul/ can understand which resources and models are available, but it does not autonomously decide to rearrange them. Future work can improve recommendations without turning a recommendation into permission.
- **Vision and bounded screen understanding.** Gemma advertises visual capability and Visual Studio can generate images, but general conversational image attachments and user-invoked screenshot understanding still need explicit artifact, retention, and provider contracts.
- **Voice.** Whisper already exists as a bounded transcription component inside Music Studio. Turning that into deliberate speech input—and eventually adding local spoken responses—requires a separate privacy and lifecycle design. There will still be no always-listening microphone quietly waiting to become helpful.
- **Backup and recovery.** Private memory, projects, references, model state, and creative artifacts now have clearer boundaries. The next step is an Operator-controlled backup system that preserves what matters without treating a public Git repository as off-site storage for a machine familiar's private life.

## More Than A Better Chat Box

Soul/ can now change its conversational model, provider, GPU manufacturer, GPU generation, and operating purpose while keeping the same identity and authority boundaries around the exchange.

That is the part I find most interesting.

The work is not about building a shrine to whichever local model currently wins a benchmark. Models will change. Hardware will change. Better inference servers will appear, current ones will improve, and something I carefully installed this week will eventually become the 15 GB directory a storage assessment politely suggests I review.

Soul/ needs to survive those changes without leaving its memory, personality, skills, evidence, or restraint trapped inside one model runtime.

Music Studio and Visual Studio are useful in their own right, but they also demonstrate what becomes possible once conversation is only one resource in a larger local system. Soul/ can remain present on one GPU while another performs specialist work, keep an exact record of which machine produced what, and stop at the point where generated material becomes a human decision.

There is considerably more machinery now.

Somehow, Soul/ feels more coherent because of it.

The repository is available here:

[github.com/Unhall0w3d/soul-slash](https://github.com/Unhall0w3d/soul-slash)
