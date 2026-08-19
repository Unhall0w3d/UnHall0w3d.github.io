# Reusable Codex Multi-Agent Workflow

This directory contains a generic orchestration policy for a Codex workflow in
which a primary agent owns architecture and integration while bounded workers
handle suitable subtasks.

## Files

- `AGENTS.md` defines task routing, assignment contracts, evidence-based trust,
  revalidation, shared-worktree rules, and an optional local-worker lane.
- `local-worker-result.schema.json` defines a small result envelope that a local
  model adapter can return to the primary agent.

## Use

1. Copy `AGENTS.md` to the root of the repository where the policy should
   apply.
2. Select the primary model and reasoning effort through the Codex interface or
   supported configuration for your environment. Sol at medium reasoning is a
   practical starting point for this workflow.
3. Replace generic validation language with the repository's real commands,
   safety boundaries, ownership rules, and release process.
4. Start with read-only delegation and small reversible changes. Increase trust
   only after workers repeatedly return complete evidence and remain in scope.
5. If using a local model, expose it through a narrow adapter and validate its
   structured result against `local-worker-result.schema.json`.

The example deliberately excludes personality, prose style, private paths,
credentials, account information, individual preferences, and project-specific
authority.

Model and feature availability can change. Confirm current names and supported
configuration in the official OpenAI documentation before adopting the example.
