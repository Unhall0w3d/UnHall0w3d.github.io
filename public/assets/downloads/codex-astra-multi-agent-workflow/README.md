# Codex multi-agent workflow template — 2026-09-22 update

This generic package reflects the compacted policy. Its ordinary orchestration
preference is Astra Medium, while the reviewed personal `config.toml` currently
selects GPT-6 Sol Medium as the primary model. The effective primary owns
architecture, authority, integration, and the final report. New delegated work
may use GPT-6 Sol for difficult bounded tasks, GPT-6 Luna for suitable routine
or bounded work, and Spark for mapping or small reversible work when callable;
Luna Low is the mapping fallback. Terra is optional, not a required tier.

The August articles and downloads are historical experiment records. Their
GPT-5.6 pricing and results are not GPT-6 performance or quota measurements.

## Files and setup

- `AGENTS.md`: adapt to your repository's authority and verification rules.
- `config.example.toml`: optional primary-model example; no subagent model pin.
- `roles/mapper.toml`: read-only mapping.
- `roles/implementer.toml`: workspace-write bounded implementation.
- `roles/reviewer.toml`: read-only review.

The project-scoped role files were unchanged in this review and intentionally omit model and reasoning pins. Select the model
and effort through the active Codex surface or supported assignment overrides.
Inherited settings must be checked: a mapper role does not automatically mean
Luna. These are examples copied from reviewed repository roles, not proof that
your runtime has discovered or activated them. Check your runtime's supported
role-loading mechanism before installing them.

The reviewed Soul project still sets `sandbox_mode = "danger-full-access"` in
its project configuration. The role TOMLs declare narrower sandboxes, but live
parent overrides can affect effective permissions. A workspace-write project
default remains a separate, uncompleted qualification step.

No sample grants credentials, network access, privilege, deployment, or release
authority. Verify effective sandbox and approval behavior; role text and a
configured sandbox value do not establish the effective boundary. Do not copy a
whole personal config.toml or the Soul project's broader sandbox setting.

## Migration evidence and limits

The local Codex catalog checked September 22 advertises `gpt-6-sol` and
`gpt-6-luna`, with upgrades from GPT-5.6 Sol/Terra to GPT-6 Sol and from GPT-5.6
Luna to GPT-6 Luna. Exact removal dates are not established by that metadata.
Do not infer new model prices, subscription multipliers, or measured quality.

Verify availability and supported reasoning before dispatch. If Terra is absent,
route suitable work directly to Sol; do not invent `gpt-6-terra`. Qualify a
representative mapping task, implementation, and review before drawing new
cost/quality conclusions. Record actual model, effort, checks, corrections, and
accepted outcome. Security and release authority stay with the primary.
