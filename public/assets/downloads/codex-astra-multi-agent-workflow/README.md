# Astra workflow template — 2026-09-22

This package follows the current policy: GPT-6 Astra owns the task; GPT-6 Sol
handles difficult bounded work; GPT-6 Luna handles routine and bounded work at
an appropriate reasoning level. Terra is an optional legacy route, not a
required dependency. Spark is used only when callable.

The August articles and downloads are historical experiment records. Their
GPT-5.6 pricing and results are not GPT-6 performance or quota measurements.

## Files and setup

- `AGENTS.md`: adapt to your repository's authority and verification rules.
- `roles/mapper.toml`: read-only mapping.
- `roles/implementer.toml`: workspace-write bounded implementation.
- `roles/reviewer.toml`: read-only review.

The role files intentionally omit model and reasoning pins. Select the model
and effort through the active Codex surface or supported assignment overrides.
Inherited settings must be checked: a mapper role does not automatically mean
Luna. These are examples copied from reviewed repository roles, not proof that
your runtime has discovered or activated them. Check your runtime's supported
role-loading mechanism before installing them.

No sample grants credentials, network access, privilege, deployment, or release
authority. Verify effective sandbox and approval behavior; role text and a
configured sandbox value do not establish the effective boundary. Do not copy a
whole personal config.toml or a danger-full-access repository setting.

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
