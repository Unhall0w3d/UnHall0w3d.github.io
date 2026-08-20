# Cost-Aware Multi-Agent Engineering Workflow

This file defines reusable routing, evidence, validation, and authority rules.
It intentionally excludes personality, private paths, credentials, account
details, publication preferences, and repository-specific secrets.

## Primary ownership

The primary agent remains responsible for the full request, authority boundary,
decomposition, returned evidence, integration decision, proportionate final
validation, and final report. Delegation never expands user authority, task
scope, mutation permission, or permission for external, destructive,
privileged, costly, or security-sensitive actions.

Do not delegate when preparing and reviewing the handoff would cost as much as
doing the work directly. Prefer one worker unless tasks are genuinely
independent and parallel execution has a clear expected return.

## Cost-aware routing

Use the least costly worker that is adequate for the assignment. Published API
rates may provide relative context but do not establish subscription usage.
Measure representative work in the actual repositories whenever possible.

- **Primary architect/integrator:** ambiguous architecture, security,
  credentials, destructive or privileged behavior, persistence, remote
  maintenance, backup/recovery, external publication, release, and final
  integration.
- **Specialized explorer:** read-only repository mapping and exact evidence
  collection while its separate allowance is available.
- **Efficient low-reasoning worker:** fallback mapping, exact searches,
  deterministic check execution, documentation/test synchronization, fixtures,
  and mechanical changes.
- **Efficient high-reasoning worker:** default bounded implementation,
  substantive cross-file review, deterministic reproducers, and low-risk
  reversible work after architecture and authority are settled.
- **Balanced integration worker:** escalation when the efficient worker reports
  material uncertainty or encounters integration ambiguity or tightly coupled
  behavior.
- **Optional local worker:** tool-less analysis or candidate generation through
  a narrow schema-defined adapter; never an authority source.

When current Codex model tiers are available, one qualified mapping is:

```text
Spark Explorer while its separate mapping allowance is available
  -> Luna Low for mapping, checks, documentation, and mechanical work
  -> Luna High for bounded implementation and substantive review
  -> Terra Medium for unresolved integration ambiguity
  -> primary Sol for architecture, sensitive authority, and final integration
```

Do not automatically send every successful efficient-worker result through a
complete balanced or frontier-model re-review. That duplicates work and can
erase the cost advantage. Escalate because evidence, risk, uncertainty, failed
acceptance criteria, or coupling requires it.

Keep one model and reasoning level for a bounded assignment where practical.
Prefer a compact purpose-built handoff over full inherited conversation history.
Reuse a related worker when that is safer and cheaper than starting fresh.

## Assignment contract

Every delegated assignment must state the bounded objective and deliverable,
read-only scope or exact ownership, acceptance criteria and commands, authority
limits and non-goals, shared-worktree preservation rule, and required evidence.

Returned evidence includes changed paths, commands and results, exact source
references, uncertainty, scope deviations, and overlapping worktree changes.

## Evidence-based trust

Trust is earned per assignment, not granted by model name.

### Evidence-trusted

Accept a read-only map without repeating the same search when it contains exact
paths, line ranges, commands, labeled uncertainty, and no contradictions.
Recheck drift-sensitive, contradictory, and risk-critical claims.

### Change-trusted

For low-risk reversible work with clean ownership, inspect worktree status and
the scoped diff, confirm only owned files changed, require every mandated check,
and run one primary integration validation when appropriate. Do not reimplement
trusted work or automatically rerun every successful check.

### Independently verified

Primary ownership and independent validation remain mandatory for security,
credentials, destructive or privileged behavior, persistence, remote
maintenance, backup/recovery, external publication, release authority,
confirmation gates, human review, and tightly coupled architecture.

## Escalation and shared worktrees

Return work to primary ownership or the next qualified tier when a worker
reports material uncertainty, changes unexpected files, encounters overlap,
omits evidence, cannot run required checks, discovers broader risk, violates
scope, or produces a result inconsistent with the assignment.

Treat existing changes as belonging to the user or another agent. Never revert,
overwrite, stage, commit, or publish unrelated changes. Assign file ownership
explicitly and stop when overlap requires a new integration decision.

## Optional local worker

A local model participates only through a bounded adapter and structured result.
Do not expose credentials, private files, broad shell authority, or repository
access merely because inference is local. Changing model, quantization, runtime,
accelerator, or adapter creates a new qualification baseline.

## Completion states

Keep candidate complete, machine validated, primary reviewed, human approved,
committed/published, and deployed/verified states distinct. A passing worker
check is evidence, not automatic approval.
