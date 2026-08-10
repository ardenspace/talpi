---
name: talpiplan
description: Use when a talpi spec is approved (.talpi/spec.md, status approved) and the project has no approved plan yet. Decomposes into phases and drafts conventions. This is the last mandatory human gate before the autonomous build.
---

# talpiplan

Turn an approved `.talpi/spec.md` into an approved `.talpi/plan.md` plus a
first draft of `.talpi/conventions.md`. This is the last mandatory human
gate — once the human approves the plan, the build runs autonomously
until a phase report or a halt brings the human back in.

## Guard

Before starting, check `.talpi/spec.md`. If it does not exist, or its
first line is not `status: approved`, do not start planning — report
that no approved spec exists yet and route to the talpispec skill
(or talpirefactor, for restructuring an existing codebase) instead.

If `.talpi/plan.md` exists and its first line is `status: approved`, do
not start a new planning conversation — report that a plan already
exists and route to the talpirun skill instead. If `.talpi/plan.md`
exists with `status: draft`, resume phase decomposition or the
conventions draft from where it left off rather than starting over.

## Phase Decomposition

Read `.talpi/spec.md` in full, especially its Requirements and Boundary
Contracts sections. Break the work into phases, where each phase is a
meaningful product increment — it ends with something a user (or,
pre-launch, the human standing in for one) could actually touch and
try. Phases are not technical layers: "backend," "frontend," and
"database" are not phases. "A user can sign up and log in" is a phase.
A phase may still be small — the bar is *touchable*, not *big*.

For each phase, decide which boundary contracts from spec.md's
`### B<n>: <name>` subsections it pins — the contracts that phase's
implementation must satisfy, and that talpirun will write as tests
before any other code in that phase. List them on the phase's
`Contracts:` line (e.g. `Contracts: B1, B3`).

Self-check before moving on: every `B<n>` id listed in spec.md's
Boundary Contracts section must appear in exactly one phase's
`Contracts:` line across the whole plan — not zero (an unpinned
contract will never get a test) and not two or more (ambiguous
ownership, and a contract pinned twice as tests is pinned once too
often). Re-scan spec.md's Boundary Contracts against the draft plan and
fix any mismatch before presenting the plan to the human.

Second self-check — early-pull: for each phase, ask what its pinned
contracts' tests will actually exercise. A contract that quantifies
over the whole surface ("*every* command fails on corrupted storage")
forces the pinning phase to build at least stubs — sometimes working
minimal versions — of commands whose "implement X" step lives in a
later phase. That is allowed, but the plan must say so: note the
early pull in the pinning phase's step description, and write the
later phase's step as "finish/verify X against its contract" rather
than "implement X", so a step that finds the work already landed is a
conformance check, not a surprise no-op.

## Conventions Draft

Write `.talpi/conventions.md` from `references/conventions-template.md`.
Seed it from the spec's `## Conventions` section — the recorded answers
to the design-theme, shared-utility policy, naming/layout rules, and
user-visible failure behavior questions asked during the spec
interview. That section is the primary source, and survives on its own
even in a fresh session with only the spec file on disk. If this
session also carries the live conversation that produced those answers,
use it to enrich the draft with detail the recorded answers didn't
capture. Ask the human only for genuine gaps — anything the spec's
Conventions section leaves unanswered.

Present the conventions draft to the human together with the plan —
never separately. Approving the plan without knowing the conventions it
implies (or vice versa) is one decision artificially split into two.

## Approval

Write `.talpi/plan.md` from `references/plan-template.md`: `status:
draft` as the first line, then one `## Phase <n>: <name>` section per
phase, each with a one-sentence goal line, a `Contracts:` line, and
`- [ ]` step checkboxes for its work — one step per fresh implementer
subagent that talpirun will dispatch, committed one commit per step.

Present the plan and the conventions draft together and ask the human
to approve them. Iterate on either or both until they do — do not
proceed on silence or an ambiguous response.

On approval:

1. Change the first line of `.talpi/plan.md` from `status: draft` to
   `status: approved`.
2. Rewrite `.talpi/state.md` in full, all four keys: `run_status:
   building`, `current_phase: 1`, `phases_total: <n>` (n = the number of
   phases in the approved plan), `updated: <ISO date>`.
3. Append an event to `.talpi/journal.md` recording that the plan was
   approved and how many phases it has (`- [<ISO date>] plan approved,
   <n> phases` — journal lines are always `- [<ISO date>] <event>`,
   append-only).
4. Tell the human the run is now autonomous: there are no more
   mandatory approval gates until a phase report arrives, or the run
   halts on an escalation. Hand off to the talpirun skill.
