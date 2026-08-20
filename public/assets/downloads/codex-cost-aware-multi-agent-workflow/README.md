# Cost-Aware Codex Multi-Agent Workflow

This package updates the workflow published with “One Architect, Several
Workers.” It keeps primary ownership, bounded handoffs, evidence-based trust,
and independent verification while refining worker selection around measured
task fit and relative cost.

## Files

- `AGENTS.md` defines cost-aware routing, assignment contracts, trust,
  escalation, shared-worktree behavior, and authority boundaries.
- `delegated-worker-result.schema.json` defines a result envelope for native or
  local workers. It records requested and observed model identity, reasoning
  effort, task category, evidence, validation, uncertainty, and escalation.

## Suggested setup

1. Copy `AGENTS.md` into the repository or appropriate owner-level Codex policy
   location.
2. Replace generic validation, privacy, ownership, and release language with
   the repository's actual requirements.
3. Run read-only representative assignments and compare exact evidence,
   first-pass correctness, scope discipline, validation, repair, and wall time.
4. Treat API pricing as relative context only; do not infer Codex subscription
   multipliers without measured account evidence.
5. Use a specialized mapping pool while it exists, then fall back to the least
   costly adequate general worker.
6. Escalate because risk or evidence demands it, not as an automatic ritual.
7. Validate structured results against the included schema when supported.
8. Re-run qualification after changing model, reasoning policy, runtime,
   orchestration, context strategy, or materially different project type.

## Important boundaries

- A worker result is evidence, not authorization.
- Successful cheap work should not automatically receive a complete expensive
  re-review; use proportionate integration review.
- Security, credentials, destructive or privileged behavior, persistence,
  remote maintenance, backup/recovery, publication, release, and tightly
  coupled architecture remain primary-owned and independently verified.
- Record observed model identity when available because requested configuration
  and actual runtime behavior may differ.
- This package contains no credentials, private paths, personal preferences, or
  project-specific authority.

Model names, availability, pricing, and subscription behavior can change.
Confirm current official documentation and repeat representative tests before
adopting this routing unchanged.
