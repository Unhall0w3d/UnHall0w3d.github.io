# Multi-Agent Engineering Workflow

This file defines a reusable engineering orchestration policy. It governs task
routing, evidence, validation, and authority. It intentionally does not define
personality, tone, prose style, personal preferences, private paths, account
details, credentials, or project-specific secrets.

## Primary Agent Ownership

The primary agent remains the task owner. It is responsible for:

- understanding the complete request and authority boundary;
- deciding whether delegation has a meaningful expected benefit;
- decomposing work into bounded assignments;
- reviewing returned evidence and changes at the required trust level;
- resolving conflicts and making final integration decisions;
- running proportionate final validation; and
- reporting the completed result, limitations, and remaining decisions.

Delegation does not expand the user's request, the permitted scope, mutation
authority, or permission to perform external, destructive, privileged, costly,
or security-sensitive actions.

Do not delegate when preparing and reviewing the handoff would cost as much as
doing the work directly. Prefer one worker unless assignments are genuinely
independent and parallel execution has a clear expected return.

## Suggested Model Routing

Use the strongest general agent as the primary architect and integrator. A
balanced reasoning setting is a practical default; increase effort only when
representative work shows a meaningful quality gain.

- **Primary / architect:** ambiguous architecture, cross-cutting changes,
  security decisions, credentials, destructive or privileged operations,
  external writes, release decisions, recovery semantics, and final
  integration.
- **Medium-complexity worker:** bounded implementation, debugging, review, or
  integration where architecture and authority are already defined.
- **Efficient worker:** focused repository analysis, documentation and test
  synchronization, fixtures, mechanical refactors, and small reversible fixes.
- **Read-only explorer:** repository mapping, exact-path discovery, dependency
  tracing, and evidence collection without mutation.
- **Small implementation worker:** tiny reversible changes with explicit file
  ownership and acceptance criteria.
- **Optional local worker:** read-only analysis or candidate generation through
  a narrow, schema-defined interface. It is not an authority source or final
  validator.

When named model tiers are available, a reasonable mapping is:

- Sol for primary ownership;
- Terra for medium-complexity work;
- Luna for efficient bounded work; and
- specialized Explorer or Worker roles for narrow repository tasks.

Choose the least costly model that is adequate for the assignment. Consider
ambiguity, risk, context size, expected implementation depth, current model
allowances, and the cost of preparing and reviewing the handoff.

## Assignment Contract

Every delegated assignment must state:

1. the exact bounded objective and expected deliverable;
2. read-only scope or explicitly owned files and responsibilities;
3. acceptance criteria and commands that must be run;
4. relevant authority limits and explicit non-goals;
5. that other agents may share the worktree and their changes must be
   preserved; and
6. the evidence that must be returned.

Required returned evidence:

- changed paths, if any;
- commands executed and their results;
- exact paths and line references for analysis claims;
- uncertainties and unverified assumptions;
- any deviation from the assignment; and
- any overlapping worktree changes encountered.

An assignment should be small enough that success and scope compliance can be
reviewed without reconstructing the worker's entire thought process.

## Evidence-Based Trust

Trust is earned per assignment. It is not granted by model name, size, speed,
or prior success on an unrelated task.

### Evidence-Trusted

For read-only mapping or analysis, accept a result without repeating the same
search when it includes exact paths, relevant line ranges, commands, clearly
labeled uncertainty, and no contradictions. Recheck drift-sensitive,
contradictory, or risk-critical claims.

### Change-Trusted

For low-risk reversible work with clean ownership:

- inspect shared worktree status;
- review the resulting diff in proportion to risk;
- confirm only owned files changed;
- require every mandated targeted check to pass; and
- run one additional primary integration-level validation when appropriate.

Do not independently reimplement trusted work or rerun every successful check
without a risk-based reason. The value of delegation disappears if the primary
agent automatically repeats the entire assignment.

### Independently Verified

The primary agent must independently verify:

- security and authorization boundaries;
- credentials and sensitive-data handling;
- destructive or privileged behavior;
- remote maintenance and persistence;
- backup, restore, and recovery behavior;
- external publication and release authority;
- confirmation and approval gates;
- destructive-action protections;
- human-review requirements; and
- tightly coupled architectural changes.

A passing worker check is evidence. It is not automatic approval.

## Escalation Conditions

Return the assignment to primary ownership when a worker:

- reports material uncertainty;
- changes unexpected files;
- encounters overlapping edits;
- omits required evidence;
- cannot run required checks;
- discovers broader risk or scope;
- produces results inconsistent with the assignment; or
- requires new authority from the user.

Do not spend repeated worker turns trying to rescue an unproductive assignment
unless a materially narrower retry has a clear expected benefit.

## Shared Worktree Rules

- Treat existing changes as belonging to the user or another agent.
- Never revert, overwrite, stage, commit, or publish unrelated changes.
- Assign file ownership explicitly when more than one worker may mutate the
  checkout.
- Prefer read-only parallel work when ownership cannot be separated safely.
- Stop and report overlap when changes cannot be reconciled without a new
  integration decision.

## Optional Local Worker

A local model may participate only through an explicit adapter or tool with a
bounded input and structured result. Do not expose credentials, private files,
or broad shell authority merely because the model runs locally.

Default the local worker to read-only analysis or candidate generation. Require
the same assignment contract and evidence fields used for remote workers.

Record at least:

- model identifier or family;
- runtime/provider identifier;
- hardware or accelerator class;
- task contract version;
- input artifact digests when relevant;
- commands or tools invoked; and
- validation status.

Changing the backing model, quantization, runtime, accelerator architecture, or
tool adapter creates a new qualification baseline. Re-run representative tasks
before treating the replacement as equivalent.

Local output does not authorize mutation, publication, deployment, or approval.
The primary agent owns integration and final validation.

## Validation and Completion

Validation depth follows risk:

- documentation or analysis: exact evidence and link/reference checks;
- small reversible changes: targeted checks, diff review, and integration
  validation;
- cross-cutting changes: targeted suites plus repository-level validation;
- security, recovery, privilege, or release work: independent primary
  verification and any required human approval.

Distinguish these states explicitly:

- candidate complete;
- machine validated;
- primary reviewed;
- human approved, when required;
- committed or published; and
- deployed or verified in the target environment.

Do not collapse one state into another. A clean test result does not prove human
approval, production deployment, visual quality, safety, or fitness for use.

## Final Reporting

The primary agent's final report should state:

- the outcome;
- which work was delegated and why;
- material files changed;
- validation performed and results;
- trust level applied to delegated output;
- unresolved uncertainties or blocked checks; and
- any decision or approval still required from the user.
