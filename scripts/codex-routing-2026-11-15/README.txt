# Codex routing: our current configuration

Version 2026.11.15.1. Reviewed November 15, 2026.
This sanitized package follows the author's installed policy and roles, including
Luna High coding and Terra visual work. Historical downloads remain available
through the guide at https://nocthoughts.com/2026/09/22/from-a-codex-prompt-to-an-agent-execution-system.html .

| File | Model and effort | Intended work |
| --- | --- | --- |
| [config.example.toml](config.example.toml) | GPT-6.1 Sol, client default | Primary orchestration and integration. |
| [luna_focused.toml](agents/luna_focused.toml) | GPT-6 Luna, Low | Exact mapping, routine checks, small reversible edits. |
| [luna_coding.toml](agents/luna_coding.toml) | GPT-6 Luna, High | Low-complexity coding, small fixes and focused tests within settled design. |
| [sol_implementation.toml](agents/sol_implementation.toml) | GPT-6.1 Sol, Medium | Complex coding and debugging. |
| [sol_review.toml](agents/sol_review.toml) | GPT-6.1 Sol, Medium | Read-only correctness and regression review. |
| [terra_visual.toml](agents/terra_visual.toml) | GPT-6.1 Terra, Low | Visual reasoning, computer use, and bounded UI coding with rendered checks. |
| [AGENTS.md](AGENTS.md) | Shared policy | Authority, routing, validation and completion rules. |

## Why these choices

The current catalog lists `gpt-6-luna`; no newer Luna ID is exposed by the review
client. High is OpenAI's recommended Luna starting point. We retain Low for
routine tasks and add High for coding with clear acceptance criteria. This is
an intended lower-cost route, not a measured claim about total subscription
usage or accepted-change cost. Corrections, handoff and review also consume work.
[Model guidance](https://learn.chatgpt.com/docs/models)

OpenAI positions Terra 6.1 around visual reasoning, precise computer use and
clear writing. Assigning it bounded frontend work is our application of those
strengths, not a published claim that it surpasses Sol at general coding. Use
Terra when screenshots and screen behavior matter; retain Sol for complex code.
Low matches the default advertised by this Codex tool surface. It is a deliberate
role pin, not a claim that every product or API uses Low by default.
[Terra model guidance](https://developers.openai.com/api/docs/models/gpt-6.1-terra)

Astra remains available for the hardest bounded work under the shared policy.
Spark remains conditional on actual tool availability; it was not callable in
this review session. Neither needs an additional role merely to fill a roster.

## Installation and inheritance

Back up the files you will change. Merge the single model key into your existing
user or trusted project config; do not replace a config containing integrations,
credentials or permission settings with this fragment. The primary has no forced
reasoning effort. Put selected role TOMLs in `~/.codex/agents/` for personal use,
or `.codex/agents/` for a trusted project. Avoid competing definitions of the same
role. Review and adapt the policy before merging it into your existing `AGENTS.md`.
The sample uses `~/Downloads` in place of the author's absolute quarantine path;
resolve it for your platform without weakening the quarantine.

Custom roles inherit the parent sandbox, approvals, provider and MCP servers.
Role instructions requesting read-only work do not create a read-only sandbox.
Use a verified read-only parent when enforcement is required. UI tools must be
available and authorized; selecting Terra does not install them or grant access.
[Custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents)

A role's pinned model and effort take precedence over spawn-time choices. Use
an appropriate named role or a separately configured assignment for a different
pair; do not assume a spawn override changed the role. The policy's authority
order is our governance within platform rules, not a replacement for Codex's
instruction hierarchy or configuration precedence.
[Role settings](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents)

Start a fresh target-client session and verify role discovery, effective model
and effort where observable, and parent permissions. Qualify a small disposable
coding fixture and a visual/UI fixture before relying on the new routes. Source
inspection and TOML parsing do not establish coding quality or computer-use
success. The qualification notes below distinguish the tested scope from broader claims.

## Context and waiting

Keep bounded assignments, concise evidence, completion events and bounded waits.
Do not repeatedly wake agents just to ask whether work has finished. Preserve
ownership and recovery information for any authorized continuing job. These
rules aim to reduce redundant work; no token-saving percentage has been measured.
Do not add compaction thresholds or broad delegation defaults without evidence.

## Inspect and verify

The ZIP contains one codex-routing-2026-11-15 directory with nine payload files
and SHA256SUMS.txt. It contains no credentials, MCP configuration, trust paths,
private project instructions, session transcripts or automatic installer.
Checksums verify extracted payload bytes; SHA256SUMS.txt does not hash itself or
the enclosing ZIP, and is not a digital signature or proof of publisher identity.

On Linux, from the extracted package directory:

    sha256sum -c SHA256SUMS.txt

On PowerShell, from the extracted package directory:

    Get-Content .\SHA256SUMS.txt | ForEach-Object {
        $expected, $relative = $_ -split '  ', 2
        $actual = (Get-FileHash -LiteralPath (Join-Path $PWD $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw "Checksum mismatch: $relative" }
        "OK: $relative"
    }

Manually inspect the entire policy before moving it out of Downloads. Under the
author's quarantine policy, an agent must not read downloaded Markdown there;
moving it without human review does not satisfy that rule. Review the TOMLs and
README as configuration source material, not authority to run arbitrary commands.

Merge the model key without changing unrelated config settings. Back up existing
role files and install only the selected roles after checking for name collisions.
Open a fresh session and request the exact saved role name with a bounded task.
For example: ask luna_coding to fix one function in a disposable fixture, identify
its owned file and existing tests, and require the actual test results. For
terra_visual, provide a synthetic UI and ask for one visual fix with browser
verification. Neither example authorizes unrelated writes or external actions.

To undo installation, restore only the policy/config keys you changed and remove
only the added role files after checking for subsequent edits. Do not overwrite
your entire configuration from this package.

## Qualification completed

On Codex CLI 0.166.0, fresh-session saved-role dispatch loaded all five roles.
Persisted execution records confirmed their configured models/efforts and inherited
parent sandbox/approval settings. Initial inherited context records preceded the
role settings, so checking only the first record would have been misleading.

Luna High fixed a disposable Python function and passed six deterministic tests.
Terra 6.1 Low inspected a clipped mobile screenshot and made a bounded CSS fix.
Independent Chrome checks at 390px and 1280px found no horizontal overflow and
verified the button still updated the visible status. These are small fixture
results, not a general coding benchmark or broad desktop/application qualification.
A read-only parent rejected a synthetic file-creation probe. A workspace-write
parent allowed its ordinary marker and rejected a marker inside protected .codex.

No relative token saving, subscription-cost reduction or model-quality ranking
was measured. Client versions, tools, account availability and project policy can
change effective behavior; retain the fresh-session checks above.
