---
title: "Running Local LLMs on a Ryzen 5800X, Navi 21, and a GTX 1070"
date: 2026-11-16T12:00:00-05:00
description: "My local LLM workstation, model placement and quantization, measured memory and throughput, thermal tuning, and llama.cpp runtime updates."
categories:
  - General
  - Linux
  - Automation
tags:
  - Local LLM
  - llama.cpp
  - GPU
  - AMD
  - NVIDIA
  - OpenClaw
  - OpenCode
draft: false
---

The GTX 1070 in my workstation still has a job. In my usual setup it handles context compaction with a 2B model, leaving the AMD card free for most foreground work. For a couple of the larger models, I split layers across both cards. Embeddings stay on the CPU.

Once the models loaded, I wanted to know what it cost to keep them useful. I measured how long a request took, how much memory it left for the desktop and how hot the Radeon got when I kept it busy.<!--more-->

*Updated November 26, 2026 after checking the running services and retiring the Maya pilot.*

## What Is in the Workstation?

- **CPU and RAM.** Ryzen 7 5800X with eight cores, 16 threads and 64GB of RAM. The DIMMs occupy slots 1B and 2B, running dual-channel at DDR4-3800 with Infinity Fabric at 1,900 MHz.
- **AMD GPU.** Navi 21 (RDNA 2) with 16GB of VRAM, recorded in my configuration as an RX 6900 XT. The shared PCI identifier leaves the exact board SKU to be confirmed.
- **NVIDIA GPU.** GeForce GTX 1070 with 8GB of VRAM and driver 580.196.07.
- **Serving.** The November 16 baseline used llama-swap v272 (`802f1c43`). The November 18 router ran v273-1 and routed requests to llama.cpp, using Vulkan for AMD and CUDA architecture 61 for the GTX 1070.

## What’s running on November 26?

OpenClaw and OpenCode both point to llama-swap on port 18080. When I checked, the router reported `v272-idle-restore1`, a local build based on `802f1c43`. Its catalog listed 22 profiles. In the normal routing configuration, Qwen3.5 2B handles compaction on the GTX 1070, EmbeddingGemma runs on the CPU, and the router can load a foreground model alongside them. The gaming configuration pairs the Capri Gemma E4B profile on the GTX with the CPU embedder.

Most foreground profiles use the Radeon through Vulkan. The 27B Qwen splits layers across both GPUs. The 35B Qwen and heavy coder also keep experts in system RAM. Both Flint context profiles use the Radeon and CPU experts. The catalog includes separate stock and Heretic Gemma 12B profiles, both on AMD. The common llama.cpp package is still pinned to `a06044b`, with separate builds for Command R7B, Phi and the CPU embedder. Bonsai 2.5 27B has its own AMD ROCm runtime at `41c86f7`.

Only EmbeddingGemma showed up as ready. Qwen 2B was on the preload list but had no running process. A separate Qwen3.5 9B test process had 32 layers assigned to CUDA and was using 7,572 MiB on the GTX. The router’s own 9B profile calls for the Radeon. I checked the process arguments and GPU allocation and left the test running without sending a request.

## November 16 Serving Roster

I measured 15 active profiles on November 16, plus Ministral as a candidate. By November 17, Ministral was my tool-free Technical Writer and the router had 15 on-demand profiles alongside the two resident helpers. On November 18, two context profiles for Flint brought the count to 17 on-demand profiles across 16 distinct foreground models. The helpers stayed in their own persistent group.

After the November 16 upgrade, the original 15 active profiles used the `a06044b` source pin. Twelve GPU profiles share the common package. Command R7B has its parser repair, Phi has its scheduler repair, and EmbeddingGemma uses the CPU package. Qwen 35B also uses a 192 MiB expert cache with CPU share set to zero, in addition to the attention K/V cache listed below.

| Model | Weight quant | Weights (GiB) | Placement | GGUF blocks | Configured / native context | K / V cache | Batch / microbatch |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmbeddingGemma 300M QAT | Q8_0 | 0.31 | CPU (resident) | 24 | 2,048 / 2,048 | Unverified / Unverified | 2,048 / 2,048 |
| Qwen3.5 2B | Q5_K_M | 1.34 | NVIDIA (resident) | 24 | 65,536 / 262,144 | q8_0 / q8_0 | 512 / 512 |
| Gemma 4 E4B | Q4_0 | 4.80 | NVIDIA | 42 | 131,072 / 131,072 | f16 / f16 | 512 / 512 |
| Gemma 4 12B Heretic i1 | Q4_K_M | 6.87 | AMD | 48 | 65,536 / 262,144 | q8_0 / q8_0 | 512 / 512 |
| GPT-OSS 20B | MXFP4 | 11.28 | AMD | 24 | 32,768 / 131,072 | q8_0 / q8_0 | 1,024 / 1,024 |
| Qwen3.5 9B | Q5_K_M | 6.27 | AMD | 33 | 65,536 / 262,144 | q8_0 / q8_0 | 512 / 512 |
| Aya Expanse 8B | Q5_K_M | 5.40 | AMD | 32 | 8,192 / 8,192 | q8_0 / q8_0 | 1,024 / 1,024 |
| Command R7B 12-2024 | Q5_K_M | 5.41 | AMD | 32 | 8,192 / 8,192 | q8_0 / q8_0 | 1,024 / 1,024 |
| Falcon H1 7B Instruct | Q5_K_M | 5.02 | AMD | 44 | 24,576 / 262,144 | q8_0 / q8_0 | 1,024 / 1,024 |
| Granite 4.2 8B | Q5_K_M | 5.82 | AMD | 40 | 24,576 / 131,072 | q8_0 / q8_0 | 1,024 / 1,024 |
| Hermes 4 14B | Q4_K_M | 8.38 | AMD | 40 | 24,576 / 40,960 | q8_0 / q8_0 | 1,024 / 1,024 |
| OLMo 3 7B Instruct | Q5_K_M | 4.85 | AMD | 32 | 24,576 / 65,536 | q8_0 / q8_0 | 1,024 / 1,024 |
| Phi-4 Reasoning Plus 14B | Q4_K_M | 8.43 | AMD | 40 | 16,384 / 32,768 | q8_0 / q8_0 | 1,024 / 1,024 |
| Qwen3.6 35B-A3B | UD-Q6_K | 27.30 | AMD + NVIDIA + 17 CPU expert blocks | 40 | 32,768 / 262,144 | q8_0 / q8_0 | 1,024 / 1,024 |
| Qwen3.8 27B | UD-IQ4_XS | 13.27 | AMD + NVIDIA | 65 | 32,768 / 262,144 | q8_0 / q8_0 | 1,024 / 512 |
| Ministral 3 14B Instruct 2512 (candidate) | Q4_K_M | 7.67 | AMD | 40 | 24,576 / 262,144 | q8_0 / q8_0 | 512 / 512 |

I use model names in the tables and keep the older routing IDs in the records so existing chats and memory still resolve. The weight column gives the size of the GGUF on disk. The context column pairs the configured window with the native limit from the GGUF header. Batch and microbatch govern how the runtime groups prompt work. The eight base profiles use eight generation threads and eight batch threads. The seven base GPU profiles enable Flash Attention and cap output at 8,192 tokens. The specialist ceilings are 4,096 tokens, with 8,192 for Phi. I don’t have KV cache or output ceiling values recorded for the embedder.

For the 35B, I use a 79:21 AMD/NVIDIA layer split and keep the expert tensors from 17 blocks in RAM. The 27B uses an 88:12 split. Those are layer splits. The footprint table shows what each card actually allocated. The GPU profiles specify `all` for the GPU-layer setting, and the embedder specifies zero. The table counts blocks from the GGUF headers. That includes one auxiliary multi-token prediction (MTP) block in each of the 9B and 27B artifacts, alongside 32 and 64 main transformer blocks, respectively.

The November 16 roster used the Heretic i1 Q4 build. Five additional GGUFs were inactive at the time, including the older 12B Gemma Q6 and Qwen 9B Q4 builds, Twin Turbo 27B, GLM-OCR and LFM2 Extract. The inventory also tracks two vision projectors separately from model weights.

## Updating the Runtime and Testing the MoE Cache

I built the replacement runtime from pinned commit `a06044b934db085e373286444e0c15b93635a20c`. Eight parser, grammar, template and server-component tests passed for each CPU and mixed-GPU build. The 13 upgraded GPU profiles passed native chat checks, with extra tool-call/follow-up checks for GPT-OSS and Qwen35B, plus a synthetic vision check for Gemma12B. The argument-parser test was built and left unrun because it includes external HTTP download assertions. Model startup exercised the configured argument sets.

The first upgrade attempt exposed two compatibility problems. Phi initially aborted during graph reservation after exhausting a scheduler hash table. The candidate CPU embedder produced vectors with cosine similarity 0.9998728 to the previous b9851 build and a 1.595% relative L2 difference. I kept b9851 serving embeddings until I could check what that difference did to retrieval.

For the MoE trial, Qwen3.6 35B-A3B kept its UD-Q6_K weights, 32K context, Q8 K/V, Flash Attention, 1024/1024 batch settings, eight threads, 79:21 GPU split and 17 host-expert blocks. I used the matching upstream tuner’s trace parsing, cache simulation and fitted cost model, with the existing temperature, memory and process checks around each test.

Seven conditions covered a cache-disabled control, then 192 and 384 MiB at CPU shares 0, 0.5 and 0.95. Each condition generated two 1,024-token continuations from the same synthetic prompt. I used temperature zero and a fixed seed for these comparisons, while the upstream tuner uses temperature 0.8. The first and second requests differ in expert-cache warmth. Prompt caching was disabled.

| Cache MiB | CPU share | First / second decode tok/s | Mean tok/s |
| --- | --- | --- | --- |
| 0 | 0 | 25.94 / 25.98 | 25.96 |
| 192 | 0 | 33.75 / 34.61 | 34.18 |
| 192 | 0.5 | 27.97 / 28.56 | 28.26 |
| 192 | 0.95 | 26.27 / 26.43 | 26.35 |
| 384 | 0 | 37.24 / 34.19 | 35.72 |
| 384 | 0.5 | 29.91 / 29.62 | 29.77 |
| 384 | 0.95 | 27.39 / 27.50 | 27.45 |

The fitted model matched its calibration measurements with a maximum relative error of 0.073%. It predicted about 34.19 tok/s at 192 MiB/share 0 and 35.68 tok/s at 384 MiB/share 0.

I took 192 MiB with CPU share 0 into the next test. It came within 5% of the fastest candidate on half the cache. This time I used different short and long prompts and added a synthetic tool exchange.

| Fixture | Cache MiB | Prompt tokens | Prefill tok/s | Decode tok/s | Wall seconds |
| --- | --- | --- | --- | --- | --- |
| short | 0 | 503 | 372.79 | 26.43 | 6.156 |
| long | 0 | 5371 | 518.71 | 25.78 | 15.286 |
| short | 192 | 503 | 397.13 | 34.37 | 4.962 |
| long | 192 | 5371 | 472.85 | 31.59 | 15.383 |

Generation improved about 30% on the short prompt and 23% on the long prompt. Short-request time fell about 19%, while the long request remained around 15.3 seconds because slower prefill offset faster generation. The tool proposal matched the requested schema and the follow-up consumed the supplied result. Generated hashes differed between cache and control, and the full text was discarded. These synthetic timings leave task-level evaluation open.

In confirmation, the 192 MiB cache raised AMD process-reported VRAM from about 12.652 to 12.840 GiB. NVIDIA process allocation at startup stayed about 5.174 GiB. AMD process-reported host GTT stayed about 10.658 GiB, while sampled RSS remained below 0.80 GiB. Host available RAM stayed above 33.1 GiB, and whole-device AMD free memory stayed above 1,637 MiB during candidate measurement. RSS and GTT have different scopes and can overlap. The highest sampled hotspot across the confirmation conditions was 62°C.

A missing copy of the split-memory approval record stopped the first confirmation launch before inference. After fixing the launcher, I repeated confirmation with that check in place. Calibration and completed confirmation used 20 inference requests in total. Afterward I checked that the test processes had exited and their ports were free.

After reviewing those results, I activated 192 MiB with CPU share 0 for Qwen 35B. The router reload and resident-helper readiness checks passed without inference. Higher CPU shares slowed this setup, which uses pinned host experts through `--load-mode none`. The upstream documentation notes that CPU miss handling often helps less when pinned-memory uploads are already fast. The disposable cache-statistics tests used verbosity 4, including its diagnostic CUDA context overhead. I kept the extra logging confined to the test. [Pinned MoE documentation](https://github.com/ggml-org/llama.cpp/blob/a06044b934db085e373286444e0c15b93635a20c/docs/moe-cache.md), [matching tuner](https://github.com/ggml-org/llama.cpp/blob/a06044b934db085e373286444e0c15b93635a20c/scripts/moe-cache-tune.py).

## Repairing Phi's Scheduler Startup

Phi's startup failure came from a scheduler tensor table sized for graph nodes that also needed entries for leaf tensors. A CPU-only regression reproduced the exact abort. The isolated patch doubled that capacity and added an overflow assertion. All 33 allocator tests and eight existing component tests passed, followed by two small Vulkan ADD comparisons against the CPU reference.

The first native qualification used the generic test's temperature zero and a 2,048-token output cap. It reached that cap after starting successfully. Microsoft's Phi Reasoning Plus card specifies temperature 0.8, top-k 50 and top-p 0.95. For the two replies left in my three-request budget, I used those settings and the deployed 8,192-token ceiling. Changing both together left me unable to tell which made the difference. [Microsoft model card](https://huggingface.co/microsoft/Phi-4-reasoning-plus#usage).

With the repaired runtime, Phi started in 2.75 seconds. The arithmetic response completed in 6.76 seconds at 47.19 tok/s, and its follow-up completed in 11.73 seconds at 47.08 tok/s. Both response checks passed, with reasoning kept separate. Generation rates include reasoning tokens. The first prompt had 245 tokens. The follow-up had 269 total prompt tokens, including 243 cached tokens.

The native tests retained 16K context, Q8 K/V, Flash Attention, 1024/1024 and eight threads on AMD. Peak sampled hotspot was 64°C, AMD process-reported VRAM reached 10.174 GiB, and whole-device AMD free memory stayed above 4164 MiB. That was enough to check startup and the exchange of replies. Full-context behavior and answer quality still need a longer test.

I switched only Phi to the repaired package. During the handover, the first check couldn’t reliably identify the resident process. Two further checks confirmed its identity and health without another restart. I kept the previous package and the failed-run records.

## Checking Embedding Compatibility

The CPU embedding follow-up compared the working b9851 build with a06044b using the same 300M QAT Q8_0 artifact and frozen synthetic inputs. Fresh b9851 output matched its retained reference bit-for-bit, and tokenization matched across builds. I could reproduce the difference on the original short query. Source changes include FP16-to-FP32 accumulation in CPU Flash Attention, while thread and weight-buffer ablations did not remove the drift. Disabling Flash Attention recovered equality for that original query, but other probes still differed.

A corpus of 36 documents and 24 queries was tested as raw text and with the model's published prefixes, giving 48 query cases. The newer runtime retained the same top result in every case. Against old document vectors, its new query vectors changed three top-five result sets across those 48 cases. Maximum absolute cosine-score movement was about 0.0030 for that mixed path and 0.0032 when both queries and documents were new. That was enough movement to warrant checking the existing indexes before switching.

The initial diagnostic adapter omitted six requested overrides from the effective command. A corrected version verified those arguments and ran the six missing ablations, retaining the earlier evidence. In total the investigation produced 430 synthetic vectors in 20 embedding requests, plus two tokenizer requests. I then completed the migration with versioned indexes and cache identity, preserving the original b9851 runtime and index snapshots for rollback.

The completed migration covered 16 agent indexes and 532 chunks, with canonical content and indexed content preserved exactly. All 32 frozen-corpus probes returned the same top result and the same top-five result set. Two live local OpenClaw retrieval checks also passed.

The first live validator expected a session chunk, while the default search scope selects memory sources. Correcting the probes resolved that mismatch. Indexed sessions were preserved and the source policy stayed in place.

The embedder now selects the new CPU package directly. The CPU macro still points to the old fallback.

## What the Optimization Screening Changed

Before the full-roster collection and runtime upgrade, I tested 168 conditions across 575 screening requests. Screening peaked at 90 °C, while the final collection peaked at 88 °C across its own workloads.

Batch changes were the useful adjustments. MTP confidence thresholds from 0.25 to 0.9 and draft depth 1 supplied no useful request-latency improvement on the tested fixtures, so I kept the existing MTP settings. Separate MTP-off references in the screening showed decode benefits for those fixtures.

Eight CPU threads stayed in place for the embedder and the 35B expert offload. Twelve and 16 threads were slower in the measured comparisons. Loading and host-operation alternatives improved the best long-request time by less than 0.2%, so the current specialist policies stayed in place too.

The attention-cache trials also favored the existing settings. Q4 supplied no compelling speed benefit over the Q8 attention profiles. Gemma E4B kept F16 after Q8 and Q4 slowed decode and total request time.

For CPU embeddings, I compared isolated native and generic Netlib BLAS builds from the same b9851 source. Three native control conditions completed three requests each, with roughly one-second median long-input latency. The two generic Netlib BLAS conditions returned no responses before their 30-second request deadlines. That screening favored the native backend. Optimized OpenBLAS, AOCL and ZenDNN remain untested.

## Full-Roster Measurements Before the Runtime Update

The following tables cover the full roster on the earlier v0.8.0 GPU runtime and b9851 CPU runtime, with the MoE cache disabled. They show the batch settings I carried into the runtime upgrade.

After screening batch sizes, I applied the selected settings, including 1,024/1,024 for Phi. The screening required more than 3% improvement in long-request time beyond baseline drift, then favored smaller batches within 1% of the best result.

All 15 active profiles and the installed Ministral candidate completed the collection. That amounted to 141 measurement requests and 344 sustained-load requests. Each generative model ran three repetitions of a repetitive 120-record prompt, a varied 20-record prompt and a varied 220-record prompt. The same text produces different token counts across tokenizers.

I used native completion requests with temperature zero, seed 20261116 and 128 forced output tokens, ignoring EOS. Prompt caching was disabled and cached-token counts were verified as zero. Embeddings used the native embedding endpoint. The resident servers were measured directly, while the other test processes used their deployed arguments. The operating system page cache was uncontrolled.

The repetitive fixture favors MTP. For the MTP comparison, I used the paired runs from screening. Each model allocated its configured context, though the prompts used only part of it.

### The Original 120-Record Fixture

Prefill measures prompt processing, decode measures generation, and wall time covers the request. Values are median (minimum–maximum) across three repetitions. Readiness includes startup for newly loaded profiles and a health check for the resident Qwen 2B.

| Model | Prompt tokens | Prefill (tok/s) | Decode (tok/s) | Wall (s) | Readiness (s) |
| --- | --- | --- | --- | --- | --- |
| Qwen3.5 2B | 2,411 | 1979.3 (1900.8–1985.0) | 72.5 (72.4–72.6) | 2.969 (2.969–3.025) | 0.049 |
| Gemma 4 E4B | 2,411 | 779.7 (776.6–780.9) | 40.7 (40.6–40.8) | 6.218 (6.200–6.237) | 6.154 |
| Gemma 4 12B Heretic i1 | 2,411 | 1052.5 (1048.6–1057.2) | 46.4 (46.1–46.6) | 5.030 (5.010–5.055) | 4.029 |
| GPT-OSS 20B | 1,930 | 2864.7 (2742.2–2908.3) | 128.9 (126.9–129.6) | 1.658 (1.654–1.710) | 5.836 |
| Qwen3.5 9B | 2,411 | 1227.3 (1188.5–1236.4) | 118.6 (117.2–118.7) | 3.038 (3.022–3.115) | 3.628 |
| Aya Expanse 8B | 2,411 | 1334.7 (1297.1–1336.4) | 68.0 (67.4–68.7) | 3.676 (3.658–3.746) | 4.232 |
| Command R7B 12-2024 | 2,411 | 1327.0 (1300.6–1327.8) | 68.8 (67.7–68.9) | 3.665 (3.661–3.733) | 3.227 |
| Falcon H1 7B Instruct | 2,412 | 1300.0 (1282.3–1303.0) | 57.9 (56.1–58.0) | 4.047 (4.045–4.147) | 3.225 |
| Granite 4.2 8B | 2,051 | 1163.8 (1143.8–1165.2) | 62.7 (62.7–62.8) | 3.788 (3.788–3.819) | 3.224 |
| Hermes 4 14B | 2,291 | 928.4 (910.8–928.7) | 46.7 (46.4–46.7) | 5.191 (5.190–5.258) | 6.246 |
| OLMo 3 7B Instruct | 1,931 | 1371.9 (1322.4–1376.9) | 70.2 (70.0–70.5) | 3.214 (3.212–3.276) | 3.838 |
| Phi-4 Reasoning Plus 14B | 1,931 | 857.6 (845.5–862.3) | 45.9 (45.8–46.0) | 5.029 (5.007–5.046) | 4.833 |
| Qwen3.6 35B-A3B | 2,411 | 432.4 (409.2–446.8) | 22.4 (19.6–22.5) | 11.259 (11.032–12.363) | 18.882 |
| Qwen3.8 27B | 2,411 | 413.4 (394.8–413.4) | 32.6 (32.4–32.9) | 9.749 (9.690–10.004) | 9.663 |
| Ministral 3 14B Instruct 2512 (candidate) | 2,292 | 940.6 (938.2–945.1) | 45.4 (45.0–45.5) | 5.238 (5.228–5.264) | 4.232 |

### Short and Long Varied Prompts

Here’s what changed when I switched from repeated records to the varied 20- and 220-record prompts.

| Model | Fixture | Prompt tokens | Prefill (tok/s) | Decode (tok/s) | Wall (s) |
| --- | --- | --- | --- | --- | --- |
| Qwen3.5 2B | short | 503 | 2039.9 (2035.8–2042.8) | 73.8 (72.4–73.9) | 1.968 (1.965–2.002) |
| Qwen3.5 2B | long | 5,371 | 1873.6 (1867.5–1881.9) | 69.4 (69.1–69.7) | 4.699 (4.695–4.701) |
| Gemma 4 E4B | short | 504 | 844.3 (843.5–851.3) | 41.3 (41.3–41.4) | 3.672 (3.659–3.677) |
| Gemma 4 E4B | long | 5,373 | 711.0 (707.6–714.3) | 39.8 (39.6–39.8) | 10.754 (10.715–10.804) |
| Gemma 4 12B Heretic i1 | short | 504 | 1099.1 (1079.8–1105.8) | 47.0 (47.0–47.5) | 3.157 (3.141–3.162) |
| Gemma 4 12B Heretic i1 | long | 5,373 | 999.2 (997.4–1001.1) | 45.4 (45.2–45.4) | 8.179 (8.170–8.199) |
| GPT-OSS 20B | short | 397 | 2041.8 (2040.0–2144.3) | 131.9 (129.5–132.6) | 1.154 (1.149–1.177) |
| GPT-OSS 20B | long | 4,302 | 2750.0 (2749.7–2751.9) | 127.2 (125.9–127.8) | 2.571 (2.567–2.580) |
| Qwen3.5 9B | short | 503 | 1238.6 (1231.8–1243.9) | 89.2 (89.1–89.5) | 1.830 (1.825–1.834) |
| Qwen3.5 9B | long | 5,371 | 1188.5 (1186.2–1189.0) | 94.0 (93.9–94.2) | 5.873 (5.873–5.883) |
| Aya Expanse 8B | short | 501 | 1306.7 (1302.3–1335.9) | 69.9 (69.3–70.3) | 2.203 (2.183–2.216) |
| Aya Expanse 8B | long | 5,360 | 1229.8 (1229.3–1231.6) | 66.0 (66.0–66.2) | 6.281 (6.281–6.290) |
| Command R7B 12-2024 | short | 501 | 1329.9 (1303.2–1331.2) | 70.6 (68.2–70.7) | 2.183 (2.177–2.239) |
| Command R7B 12-2024 | long | 5,360 | 1232.7 (1222.7–1236.9) | 66.6 (66.4–66.8) | 6.266 (6.237–6.294) |
| Falcon H1 7B Instruct | short | 504 | 1292.9 (1262.8–1293.3) | 61.2 (61.0–61.4) | 2.467 (2.459–2.483) |
| Falcon H1 7B Instruct | long | 5,380 | 1241.1 (1233.1–1256.4) | 58.3 (58.2–58.3) | 6.516 (6.462–6.546) |
| Granite 4.2 8B | short | 421 | 1113.2 (1108.8–1135.1) | 64.8 (64.8–64.9) | 2.339 (2.330–2.340) |
| Granite 4.2 8B | long | 4,536 | 1082.5 (1082.4–1084.9) | 60.9 (60.9–61.0) | 6.277 (6.270–6.279) |
| Hermes 4 14B | short | 481 | 929.6 (913.4–930.9) | 48.2 (48.0–48.3) | 3.158 (3.150–3.165) |
| Hermes 4 14B | long | 5,149 | 846.4 (845.3–852.0) | 44.3 (43.4–44.7) | 8.962 (8.886–9.011) |
| OLMo 3 7B Instruct | short | 398 | 1292.1 (1257.6–1301.3) | 76.0 (75.8–76.1) | 1.982 (1.981–1.987) |
| OLMo 3 7B Instruct | long | 4,303 | 1254.9 (1251.7–1256.0) | 64.2 (63.9–64.3) | 5.417 (5.412–5.417) |
| Phi-4 Reasoning Plus 14B | short | 398 | 802.7 (800.0–804.0) | 47.2 (47.2–47.3) | 3.187 (3.184–3.191) |
| Phi-4 Reasoning Plus 14B | long | 4,303 | 810.7 (810.3–812.2) | 44.6 (44.6–44.6) | 8.157 (8.147–8.165) |
| Qwen3.6 35B-A3B | short | 503 | 350.0 (331.9–351.7) | 22.9 (22.6–22.9) | 7.052 (6.984–7.070) |
| Qwen3.6 35B-A3B | long | 5,371 | 442.3 (406.9–446.1) | 22.2 (20.8–22.3) | 18.266 (17.757–18.905) |
| Qwen3.8 27B | short | 503 | 389.6 (387.8–390.1) | 25.7 (25.6–26.0) | 6.242 (6.179–6.261) |
| Qwen3.8 27B | long | 5,371 | 403.9 (401.9–405.6) | 28.3 (28.1–28.5) | 17.825 (17.699–17.861) |
| Ministral 3 14B Instruct 2512 (candidate) | short | 482 | 950.2 (940.4–963.3) | 46.5 (46.4–46.5) | 3.240 (3.237–3.247) |
| Ministral 3 14B Instruct 2512 (candidate) | long | 5,164 | 877.3 (872.3–878.2) | 43.8 (43.1–44.2) | 8.788 (8.769–8.870) |

### CPU Embeddings

EmbeddingGemma completed three requests at each of two input lengths. Throughput here includes the entire embedding request.

| Fixture | Tokens | End-to-end tok/s | Wall (s) |
| --- | --- | --- | --- |
| short | 783 | 1706.6 (1398.3–1712.5) | 0.459 (0.457–0.560) |
| long | 1,947 | 1696.3 (1348.1–1710.5) | 1.148 (1.138–1.444) |

### Memory Across Measurement and Sustained Load

| Model | AMD model VRAM (GiB) | NVIDIA model VRAM (GiB) | AMD process GTT (GiB) | AMD board peak (GiB) | NVIDIA board peak (GiB) | Steady RSS (GiB) | VmHWM (GiB) | Host available drop (GiB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| EmbeddingGemma 300M QAT | — | — | — | 1.20 | 2.08 | 2.33 | 2.33 | 1.08 |
| Qwen3.5 2B | — | 2.07 | — | 1.20 | 2.09 | 1.05 | 1.81 | 1.30 |
| Gemma 4 E4B | — | 5.13 | — | 1.25 | 7.23 | 3.42 | 3.42 | 3.37 |
| Gemma 4 12B Heretic i1 | 8.83 | — | 0.08 | 10.03 | 2.09 | 0.57 | 0.58 | 0.61 |
| GPT-OSS 20B | 12.29 | 0.08 | 0.09 | 13.49 | 2.17 | 0.75 | 0.76 | 0.86 |
| Qwen3.5 9B | 7.42 | — | 0.84 | 8.97 | 2.09 | 0.49 | 0.51 | 1.34 |
| Aya Expanse 8B | 6.28 | — | 0.08 | 7.86 | 2.09 | 1.13 | 5.72 | 0.60 |
| Command R7B 12-2024 | 6.14 | — | 0.09 | 7.72 | 2.09 | 1.13 | 5.72 | 0.57 |
| Falcon H1 7B Instruct | 5.81 | — | 0.10 | 7.25 | 2.09 | 0.57 | 5.29 | 0.67 |
| Granite 4.2 8B | 7.89 | — | 0.11 | 9.29 | 2.09 | 0.55 | 6.08 | 0.46 |
| Hermes 4 14B | 10.38 | — | 0.13 | 12.18 | 2.09 | 0.60 | 8.66 | 0.73 |
| OLMo 3 7B Instruct | 7.54 | — | 0.12 | 9.79 | 2.09 | 0.55 | 5.11 | 0.19 |
| Phi-4 Reasoning Plus 14B | 10.21 | — | 0.11 | 11.82 | 2.09 | 0.55 | 8.69 | 0.29 |
| Qwen3.6 35B-A3B | 13.22 | 5.22 | 10.66 | 14.59 | 7.31 | 0.79 | 0.79 | 11.08 |
| Qwen3.8 27B | 12.81 | 3.01 | 0.10 | 14.22 | 5.10 | 0.78 | 0.79 | 1.45 |
| Ministral 3 14B Instruct 2512 (candidate) | 9.55 | — | 0.07 | 11.06 | 2.09 | 0.66 | 7.96 | 1.58 |

Model VRAM and AMD GTT are reported for the process. Board totals include the desktop and resident helpers. Steady RSS is the sampled median, while VmHWM is the process-lifetime high-water mark and can predate the test for resident servers. Sampling every 500 ms can miss brief peaks. Dashes mark unavailable or inapplicable values.

The 35B illustrates why RSS alone gives an incomplete picture. Its process reported about 0.79 GiB of peak RSS alongside 10.66 GiB of AMD GTT. GTT accounts for GPU-accessible host memory, and it can overlap with RSS. Adding them can overstate unique RAM use. The whole-host `MemAvailable` change also includes other activity and page-cache behavior.

During the five-minute Hermes run, process swap (VmSwap) stayed between 120.61 and 120.64 MiB even with more than 42.3 GiB of host memory available in every sample. Linux reports swapped private anonymous pages through this counter. The host uses compressed-RAM zram swap, and the inspected cgroup ancestors had unlimited memory caps with zero limit or OOM events. These observations are consistent with cold host pages being paged out. The exact pages and historical reclaim trigger were not captured. Every other profile recorded zero process swap, and the operating guards passed.

GPT-OSS was configured for AMD compute and reported exactly 84 MiB of NVIDIA process memory. Follow-up traced this to its verbosity-4 startup diagnostics, which query memory on every GPU and create a CUDA primary context. A disposable probe using the same backend library reproduced zero NVIDIA allocation before the memory query and 84 MiB afterward, loading zero model weights and making zero inference requests. Exit released the allocation. The logging-only reduction to verbosity 2 was then activated with a healthy resident-helper reload and zero inference requests. The subsequent new-runtime GPT-OSS startup qualification reported no NVIDIA process allocation at verbosity 2.

The current 35B keeps expert tensors from 17 blocks in RAM. That change followed an earlier load hitting the AMD free-memory guard at 16 blocks. The failed attempt remains recorded, with the exact triggering sample unavailable. The two split Qwen profiles use a 768 MiB AMD free-memory floor. The other profiles retain 1,536 MiB.

### Keeping the Models Busy

Each generative model then repeated the long fixture for at least two minutes. Hermes ran for 306.99 seconds, and the embedder ran for 60.25 seconds. Wall times are median (minimum–maximum) across sustained requests. AMD and CPU temperatures below cover sustained load. NVIDIA peaks cover the full condition.

| Model | Prompt tokens | Duration (s) | Requests | Wall (s) | AMD hotspot (°C) | NVIDIA peak (°C) | CPU peak (°C) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| EmbeddingGemma 300M QAT | 1,947 | 60.25 | 50 | 1.138 (1.117–1.262) | 40 | 25 | 76.6 |
| Qwen3.5 2B | 5,371 | 121.01 | 25 | 4.770 (4.715–4.816) | 40 | 70 | 69.9 |
| Gemma 4 E4B | 5,373 | 120.22 | 11 | 10.873 (10.814–10.894) | 42 | 74 | 69.8 |
| Gemma 4 12B Heretic i1 | 5,373 | 124.01 | 15 | 8.205 (8.178–8.231) | 87 | 45 | 60.4 |
| GPT-OSS 20B | 4,302 | 122.25 | 46 | 2.596 (2.585–2.615) | 83 | 31 | 59.6 |
| Qwen3.5 9B | 5,371 | 125.21 | 21 | 5.900 (5.870–5.951) | 88 | 28 | 59.4 |
| Aya Expanse 8B | 5,360 | 120.74 | 19 | 6.292 (6.265–6.325) | 87 | 27 | 63.4 |
| Command R7B 12-2024 | 5,360 | 126.09 | 20 | 6.246 (6.239–6.255) | 88 | 27 | 55.9 |
| Falcon H1 7B Instruct | 5,380 | 124.22 | 19 | 6.473 (6.465–6.537) | 87 | 27 | 55.9 |
| Granite 4.2 8B | 4,536 | 120.48 | 19 | 6.280 (6.264–6.326) | 88 | 27 | 55.1 |
| Hermes 4 14B | 5,149 | 306.99 | 34 | 9.002 (8.873–9.102) | 88 | 27 | 65.1 |
| OLMo 3 7B Instruct | 4,303 | 120.27 | 22 | 5.399 (5.381–5.459) | 88 | 27 | 66.2 |
| Phi-4 Reasoning Plus 14B | 4,303 | 123.37 | 15 | 8.153 (8.135–8.209) | 87 | 27 | 65.5 |
| Qwen3.6 35B-A3B | 5,371 | 133.12 | 7 | 18.910 (18.736–19.325) | 65 | 48 | 73.0 |
| Qwen3.8 27B | 5,371 | 123.19 | 7 | 17.536 (17.492–17.572) | 86 | 58 | 69.0 |
| Ministral 3 14B Instruct 2512 (candidate) | 5,164 | 125.86 | 14 | 8.948 (8.808–8.981) | 88 | 55 | 69.4 |

The collection used the saved 255 W cap, −50 mV offset, automatic core clocks and junction-based fan curve. Overall peaks reached 88 °C at the AMD hotspot, 74 °C on NVIDIA and 76.625 °C on the CPU. The completed conditions recorded no operating-guard failures or GPU/OOM kernel errors.

Starting conditions changed during collection. A two-minute cooldown expired before GPT-OSS launched. The continuation initially allowed five minutes for the same starting-temperature targets. From Command R7B onward, I removed that low-temperature starting gate and began at idle operating temperatures. The hard thermal, fan, memory and process-ownership guards stayed active. That difference matters when comparing temperatures and elapsed times.

I haven’t run these loads for hours. Final checks confirmed the test processes and listeners were released, resident identities were preserved and idle, and the saved settings were intact.

## What Did the Earlier Runs Look Like?

The earlier runs helped me choose the current settings. I’ve kept their original conditions here because several used different weights, placement or workloads. Some of the older records have no test date.

| Model and test date | Recorded condition | Result |
| --- | --- | --- |
| Qwen 2B, Nov. 9 | Resident CUDA, 64K, Q8 KV, 256/128 batch, about 34K prompt tokens | About 1,437 prefill and 65 decode tok/s. Prefill took about 24 seconds. |
| Gemma E4B, date unknown | CUDA, 128K, f16 KV, 512/512 batch | About 280 prefill and 39.6 decode tok/s. |
| Qwen 9B, Nov. 9 | Vulkan, 64K, Q8 KV, MTP depth 2, 512/256 batch | About 970 prefill and 105–114 decode tok/s across the short and long cases. |
| Qwen 9B, Nov. 9 | Vulkan alternatives | About 76 decode tok/s without MTP. The long-form depth-6 run returned about 18 tok/s with about 21% draft acceptance. |
| Qwen 35B, date unknown | Direct 79:21 split, CPU expert tensors from 16 blocks, 32K | 417 prefill and 26 decode tok/s. Loading took about 19 seconds. A separate routed run alongside the resident 2B reached 26.3 decode tok/s. |
| Qwen 27B, date unknown | Direct 88:12 split, Q8 KV, MTP, 32K | 393 prefill and 29 decode tok/s. A separate short routed run with the resident 2B reached 21.5 decode tok/s. The Vulkan condition with host KV reached 10.6. |
| GPT-OSS 20B, date unknown | Retained prefill comparison at batches 512 and 1,024 | 2,448 and 2,814 prefill tok/s, respectively. A separate routed observation recorded 141 decode tok/s. |
| Gemma 12B Heretic i1 Q4, Nov. 13 | Short smoke tests including text, tool and vision checks | About 47–48 decode tok/s. |
| EmbeddingGemma, Nov. 9 | CPU warm query, batch of four, and longer input | 7–13 ms for a warm query, about 34 ms for a batch of four, and about 600 ms for a 4,320-character input. The warm query produced a 768-dimensional vector. |

The older Gemma 12B Q6 sweep is a good example of why I keep the prompt length with the result. With a roughly 2,500-token prompt, Q8 KV, Flash Attention enabled and a 512/512 batch, it reached 923.7 prefill tok/s and 37.7 and 38.7 decode tok/s at 64 and 256 generated tokens, respectively. With f16 KV, prefill was 928.6 tok/s with Flash Attention on and 682.9 with it off. The Q6 long-prompt observations were 639.6 prefill tok/s at about 20,600 prompt tokens and 362.0 at about 61,900. The current Q4 model has its own smoke-test evidence.

I also record the MTP depth. On the 9B, the long-form depth-6 run was slower than I’d want to use. The depth-2 numbers apply to the recorded Vulkan condition. A general MTP uplift would require matched runs across prompt lengths and tasks, including draft acceptance and request latency.

## The Earlier Specialist Pilot

Before the common benchmark, I tested the eight specialist candidates individually on November 15. Each ran by itself on AMD with SHA-verified weights, Q8 attention K and V, Flash Attention, and a 256/256 batch and microbatch. Falcon also kept its recurrent state in native F32. The 40 measured cases cover feasibility and follow-up runs.

| Candidate | Weight quant | Context | Prefill (tok/s) | Decode (tok/s) | Wall time (s) | AMD total (GiB) | Process RSS (GiB) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Granite 4.2 8B | `Q5_K_M` | 24,576 | 439.6–732.9 | 64.5–65.1 | 0.543–0.866 | 9.18 | 6.08 |
| Command R7B (12-2024) | `Q5_K_M` | 8,192 | 824.5–1089.4 | 70.7–70.9 | 0.539–0.720 | 7.10 | 5.72 |
| Ministral 3 14B Instruct (2512) | `Q4_K_M` | 24,576 | 457.5–809.9 | 47.0 | 1.511–2.760 | 10.61 | 7.96 |
| Phi-4-reasoning-plus | `Q4_K_M` | 16,384 | 395.2–474.2 | 47.3–47.4 | 15.457–15.677 | 11.45 | 8.69 |
| Olmo 3 7B Instruct | `Q5_K_M` | 24,576 | 657.7–697.4 | 77.2–77.6 | 0.529–0.670 | 8.27 | 5.11 |
| Falcon H1 7B Instruct | `Q5_K_M` | 24,576 | 300.1–408.3 | 61.3 | 0.320–0.662 | 6.78 | 5.29 |
| Hermes 4 14B | `Q4_K_M` | 24,576 | 438.3–858.9 | 48.0–48.5 | 0.519–0.627 | 11.51 | 8.66 |
| Aya Expanse 8B | `Q5_K_M` | 8,192 | 461.6–830.9 | 69.3–70.8 | 0.520–0.557 | 7.40 | 5.72 |

The runtime follow-ups included native stop-token handling for Command R7B and Aya, an undefined-tools guard in Olmo’s chat template, and a publisher-template repair for Phi that separated reasoning from final output. Phi’s decode rate includes reasoning tokens, and its two native requests each took roughly 15½ seconds.

### What the Pilot Actually Measured

Each specialist had its own prompts and output lengths. Prefill rates use uncached tokens for each case, and prefix reuse varied. Short prompts make fixed overhead more visible, and early loads overlapped with download I/O. Those differences led to the common workload and cache policy used in the November 16 benchmark above.

The VRAM column reports whole-device usage, including the desktop. Two-second sampling can miss short peaks. Process RSS includes file-backed model mappings. Private anonymous RAM was unavailable, and system `MemAvailable` was recorded separately in the run data. Adding RSS to VRAM would give a misleading estimate of model-owned memory.

This pilot capped ordinary outputs at 1,024 tokens and Phi at 4,096, below their configured ceilings. Sustained generation near those ceilings still needs a longer test.

## Putting Seven Specialists Into Service

On November 15, I added seven roles to OpenClaw and OpenCode. I checked a direct reply from each role in each client and verified model attribution for all 14 paths.

| Model | Role | Read tools enabled |
| --- | --- | --- |
| Granite | Structured Data | Yes |
| Command R7B | Grounded Research | Yes |
| Phi | Reasoning Verifier | No |
| Olmo | Independent Evaluator | Yes |
| Falcon | Lightweight Assistant | No |
| Hermes | Conversation Specialist | Yes |
| Aya | Translator | No |

Aya uses a chat template that handles consecutive user turns and a plain-content parser in both clients.

Client smoke-check elapsed time includes startup and prompt overhead. The prefill and decode rates above come from the native pilot.

The original activation batch stopped at the 95 °C junction guard and released the foreground slot. After resuming the work, an OpenCode check returned from the expected local Hermes model in 11.408 seconds. The sampled hotspot peaked at 79 °C and the thermal and resource guards stayed clear. The role resolved after a catalog refresh. A November 16 native delegation pilot subsequently checked Granite extraction and follow-up, Qwen 27B code proposals, GPT-OSS independent review and cancellation of an active Phi request. Model selection, native receipts and return delivery to the parent were verified for those paths.

Command R7B’s earlier tools-unavailable refusal led to a parser repair for legacy response delimiters and streaming prefixes. After the repair, the Coordinator received both the Grounded Research answer and a corrected follow-up from the same child. I checked that Command produced both replies. I also updated its executable path and gave the Research role instructions for working from supplied sources.

The delegation checks also exposed problems with completed-job receipts and cancellation recovery. Those paths have since been repaired and checked. Standalone Grounded Research source handling, occasional missing child citations and specialist formatting remain open. Local OpenClaw patches will need requalification after an upstream package replacement.

<details>
<summary>Receipt and cancellation-recovery checks</summary>

Completed native receipts now survive the in-memory cache expiry. A lookup 632 seconds after termination returned the matching receipt beyond the 600-second expiry, with zero new inference.

Restart recovery had also revived cancelled Coordinator reconciliation. The cancellation repair now retires the cancelled session’s recovery and pending-delivery claims, while Coordinator guidance limits reconciliation to the listed unfinished jobs. Twenty deterministic controls passed, followed by a 240-second live campaign covering delegation, final delivery, cancellation during inference and two minutes of post-restart observation with event wakes enabled. No duplicate or revived work was observed in that window.

The earlier receipt repair preserved transcript and indexed-chunk hashes but changed two source-index metadata rows. The cancellation-recovery repair preserved every baseline transcript, chunk and source-index metadata row. Heartbeat cadence was restored and test resources were released.

The legacy paused Developer follow-up was subsequently retired through authenticated native cancellation. Its pause state cleared, no other tasks were cancelled, and all 237 baseline Developer transcript rows were preserved. The gateway reported zero active work. The earlier HTTP 403 remains part of the test history.

The cancellation notice was later settled as intentional non-delivery, retaining its cancellation and suppression markers. Its raw status is `failed`, with disposition `intentional_non_delivery` and reason `task_cancelled`. Twenty-five deterministic controls passed, followed by 126.45 seconds of observation with event wakes enabled and zero active work or revival. Only the intended registry record changed among 16 baseline records. All 2,340 baseline transcript rows, 659 memory chunks and 96 source-index metadata rows were preserved, with zero model generation requests.

</details>

## Adding Ministral as a Technical Writer

On November 17, I ran two AMD-only writing checks with 24 requests each. Both finished within the original hardware guards and released the model cleanly. In the second check, an experimental grammar removed the leading Markdown fences from all 15 structured replies. The harder problem was what went inside the JSON. Ministral took a missing installation record to mean installation had never been attempted. In another draft, it described a request due to be sent tomorrow as already sent.

I activated Ministral 3 14B Instruct 2512 Q4_K_M in llama-swap, OpenClaw and OpenCode as a tool-free `technical-writer`. I use it for general technical drafts and check the facts myself, especially where the source is silent or describes work still to come. The active recipe runs on AMD with a 24,576-token context, Q8_0 K/V, 512/512 batching and Flash Attention. I left the experimental grammar out of the deployed profile.

The first OpenClaw check returned HTTP 500 when two user turns arrived back to back. I repaired Ministral’s chat template and checked that it preserved role boundaries in 13 deterministic cases. OpenClaw and OpenCode then each returned a handoff from supplied material and an open-ended explanation without a source packet. All four replies came from the expected local model. In the OpenClaw handoff, I caught one more factual slip. It added a verification step nobody had assigned. After the checks, the foreground model unloaded, both resident helpers were idle, and WinBoat was still running.

## A Heavy-Coder Job Through OpenClaw

On November 17, I gave the Qwen3.5 9B Coordinator a read-only synthetic coding job in OpenClaw. It handed the job to Unsloth Qwen3-Coder-Next UD-Q4_K_M, then returned the corrected answer. I found one accepted dispatch, and the completion receipts matched at both ends. I reviewed the generated code without executing it. The whole exchange took about 309 seconds, including orchestration.

The launcher aims for a 2,048 MiB expert cache. On this run it picked 1,792 MiB to fit the available memory. The MTP 2B and CPU embedder stayed resident while WinBoat was running. Sampled minimum free memory was 2,091 MiB on AMD and 1,215 MiB on NVIDIA, with 40.89 GiB available on the host. The hotspot peaked at 84 °C and no guard tripped. Both helpers were idle when the job finished. I still haven’t tested that handoff through OpenCode.

## Flint 40B on the Radeon and system RAM

With Flint Preview 40B, I wanted to know whether streaming the experts would get a coding job back sooner. I tried the same UD-Q4_K_XL weights three ways. The Radeon ran the trunk, the Ryzen computed routed experts, and the GTX 1070 remained available to the resident 2B. At 16K context, the 4,290-token prompt and 128-token response took 21.53 seconds on stock llama.cpp, 21.98 seconds on the TokenWing control and 63.54 seconds with TokenWing’s 12 GiB streaming pool. Stock reached 295.7 prompt and 18.1 generation tok/s. Streaming reached 80.9 and 12.1. The streamed worker read about 91 GiB during that request and again on the immediate repeat. Streaming reduced startup time and host memory use, but stock finished this task sooner.

I kept two stock profiles, 16K and 32K. They share one weights file and use Flash Attention, Q8_0 K/V, 1,024/256 batching, eight threads and up to 8,192 output tokens within the selected window. The longer test asked Flint to build an interactive HTML/Canvas depth journal from records scattered through a synthetic ledger. Each run started cold with zero cached prompt tokens.

| Context tested | Actual input tokens | Prefill | Prompt tok/s | Generation tok/s | Cold start to result | Output |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 32K | 24,072 | 1m 28s | 272.3 | 17.92 | 6m 07s | Natural stop at 4,718 tokens |
| 64K | 60,886 | 4m 05s | 248.6 | 15.84 | 8m 39s | Hit the 4,096-token cap |
| 128K | 126,426 | 9m 56s | 212.1 | 12.79 | 15m 30s | Hit the 4,096-token cap |

At 32K the first visible output arrived at 1m 50s. The page still lacked its closing HTML tag at token 4,096. The completed desktop artifact passed the interaction checks, with mobile layout and high-DPI scaling issues left for review. The Radeon peaked at 64 °C hotspot, with at least 11.10 GiB of AMD VRAM free and 18.10 GiB of host memory available at sampled points. Both helpers kept their processes. I kept 32K for larger coding requests. The 128K run spent nearly ten minutes on prefill alone. The prompt lengths and output caps differed, so these are task turnaround measurements. Flint’s callable role covers text and coding. Tool execution still needs qualification.

## Two Coordinator handoffs

For a structured-data request, stock Qwen3.5 9B and Ornith 1.5 9B each delegated to Granite and returned all four fields with the requested values and types. Stock returned standalone JSON in 60.601 seconds. Ornith took 58.872 seconds and wrapped its JSON in a sentence and a Markdown fence. One exchange per model gives me little reason to trade a working default for that timing difference. I kept stock 9B as Coordinator and the 35B in Main.

Video uses a different path. The 9B handed a request to Rapid 14B Q5_K and released its idle GPU cache before the seven-minute expiry. Admission took 6.16 seconds. The worker took 162 seconds to produce the 624 × 352, 17-frame H.264 clip. The Radeon hotspot peaked at 87 °C, sampled whole-card VRAM use peaked at 13.79 GiB, and host available memory stayed at or above 25.39 GiB in the samples. Both resident helpers kept their original processes. The returned file matched the worker’s checksum in the requesting chat, and Observatory passed all 11 handoff checks. I still need to see the native 9B Workshop review run on a render.

## Could Maya run a larger MoE on this box?

Maya gave me a way to try GLM-5.3-Flash Maya-XS without fitting all its experts in VRAM. The idea was to keep the busiest experts on the Radeon, hold another set in pinned system RAM and fetch the rest from NVMe. I wanted to see whether that left enough speed for offline review while the GTX kept its usual 2B loaded.

My best AMD-only run on Maya v1.1.80 used 5.97 GiB of GPU cache and 23.99 GiB of pinned RAM with the 2B resident. Maya answered all six short checks correctly. Across five separate technical paragraph prompts, median decode was 2.9 tok/s and median time to first token was 7.8 seconds. I used one client, greedy sampling, reasoning off, a 4,096-token context, INT8 KV and a 48-token output cap. On the request closest to the median, the engine recorded 344 ms per generated token, including 306 ms in disk waits and about 93 disk reads per token. Unloading the 2B for the matched run brought decode to 2.8 tok/s.

Could the GTX hold another tier of experts? Single-expert checks passed in both directions. With the Radeon leading and real model weights on the GTX helper, the fixed-input check reached layer 43 and measured a relative L2 error of 0.000056 against a limit of 0.000010. Startup stopped there, before the mixed setup generated a token.

The AMD run fell short of my 5 tok/s floor for offline review on this workstation. I kept llama-swap for everyday use and retired Maya on November 25. After removing the pilot weights and builds, I got an `OK` back from the 2B through the router. Both helpers kept their ready timestamps across cleanup, and the Maya listener was closed. I archived the measurements before cleanup. I didn’t test long-context quality or run the same prompts against my larger llama.cpp models.

## The Earlier Power and Thermal Tests

Before the full-roster collection, I used a longer Hermes prompt to compare power and voltage settings. The earlier Hermes role checks used 55–78 prompt tokens, took about 0.6 seconds per request, and sampled temperature every two seconds. The thermal runs used Hermes 4 14B Q4_K_M on AMD only, with the 24,576-token context, Q8 attention K and V, Flash Attention and 256/256 batching. Each request processed 9,404 prompt tokens and generated 128 tokens, with prompt caching disabled, temperature zero and a fixed seed. Thermal sampling ran every 250 ms. The later roster collection used Hermes at 1,024/1,024 with its 220-record long fixture.

| Power cap / offset / core policy | Requests / active seconds | Peak junction | Mean load power | Mean prefill (tok/s) | Mean decode (tok/s) | Outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 281 W / -50 mV / 2,400 MHz ceiling | 3 / 48.1 s | 93 °C | 264.4 W | 722.7 | 42.27 | Short reference completed |
| 252 W / -50 mV / 2,400 MHz ceiling | 3 / 49.1 s | 88 °C | 243.7 W | 703.9 | 42.22 | Short comparison completed |
| 255 W / -75 mV / Auto | 3 / 48.9 s | 88 °C | 247.3 W | 709.9 | 41.76 | Short replay completed |
| 255 W / -75 mV / Auto | 10 / 164.3 s | 92 °C | 247.6 W | 704.0 | 41.40 | Stopped at tenth request on hash mismatch |
| 255 W / -50 mV / Auto | 35 / 575.0 s | 94 °C | 250.5 W | 700.9 | 42.29 | 35 matching outputs, including match to earlier reference |

The three-request 252 W pilot and 281 W reference both used a −50 mV offset, a 2,400 MHz core-clock ceiling and a 95 °C junction stop. The lower cap coincided with a 5 °C lower sampled peak, 2.6% lower mean prefill throughput and effectively unchanged decode throughput. That was enough to make the lower cap worth keeping for this workload. The 255 W short replay also changed the voltage offset and clock policy, so its temperature and throughput changes cannot be assigned to the power cap alone.

For the longer trials I set the junction stop to 100 °C and kept the other thermal and resource guards in place. At −75 mV, the tenth request produced a different output hash and the run stopped after 164 seconds. No thermal guard or kernel GPU fault was recorded. The temporary −50 mV control completed 35 identical-output requests over 575 seconds, with a 94 °C sampled peak. Its hash matched the earlier reference. That gave me a reason to keep −50 mV for this workload. The trials ran sequentially for different durations, and the retained hash alone cannot explain the earlier mismatch or establish repeatability across other workloads.

Whole-device AMD VRAM, including desktop usage, peaked at about 11.5–11.6 GiB across these runs. The minimum sampled system `MemAvailable` ranged from about 43.6 to 44.6 GiB. Process RSS and NVIDIA VRAM were unmeasured.

### Where I Landed on the AMD Settings

I saved a 255 W cap and a −50 mV offset with automatic core clocks. The fan controller follows GPU junction temperature and targets full PWM at 78 °C, polling every 500 ms with zero deadband and a five-second spin-down delay. A short pilot observed about 97% PWM at 78–79 °C, followed by full PWM about half a second later.

## What I Still Want to Measure

Next I’d like to measure cold-filesystem loading, more varied real tasks and operation near the configured context limit. For the specialists, I’d also like to run the same task with different weights and GPU placements. What I care about on this box is how soon I get a usable reply while the rest of the desktop keeps working.
