# .talpi/ State Format

All cross-session state lives in `.talpi/` at the target project root. This directory serves as the canonical store for project state, designed with one core assumption: any session can terminate at any moment. The files described here are the single source of truth for the state of a talpi run. All files are Markdown, human-readable, and should be committed to version control so their evolution is tracked.

Skills and agents must never invent new state files or namespaces outside of `.talpi/`. Every reference to `.talpi/*` from a skill must be to a file defined in this document.

## State scripts

Three plugin scripts mechanize reading and writing this state, so rule-following is a tool call rather than prose interpretation. They are the canonical parser and writers; skills invoke them via `${CLAUDE_PLUGIN_ROOT}/scripts/`:

- **`talpi-status.sh [root]`** — read-only. Reads `.talpi/`, applies the conflict rule (journal wins over `state.md`) and the guard/resume decision table, and prints the run's position plus exactly one `next:` action line. Disagreements between `state.md` and the journal surface as `warning:` lines. **The decision table lives in this script alone** — skill prose routes on the script's output and must not duplicate the table.
- **`talpi-journal.sh "<event>" [root]`** — appends one line to `.talpi/journal.md` in the canonical `- [<ISO date>] <event>` form. The only sanctioned way to write the journal.
- **`talpi-state.sh <run_status> <current_phase> <phases_total> [root]`** — rewrites `.talpi/state.md` in full, validating the `run_status` vocabulary and numeric phases, stamping `updated`. The only sanctioned way to write the snapshot.

`root` defaults to `$CLAUDE_PROJECT_DIR`, then the working directory. The decision table's behavior is pinned by `scripts/test/status.test.sh`.

---

## .talpi/spec.md

Produced by the `talpispec` skill. This file captures the product specification for the current run.

The first line is a status marker, exactly as written: `status: draft` or `status: approved`. This allows quick status lookup without parsing Markdown.

Sections follow this structure:

- `# Spec: <project>` — the document title
- `## Product Picture` — describes the target user, their core experience with the feature, and a smoke-test scenario that proves the feature works
- `## Requirements` — enumerated requirements, each independently verifiable
- `## Out of Scope (v1)` — explicit non-goals for this phase to prevent scope creep
- `## Simplicity Zones` — areas where the design deliberately trades capability for maintainability or understandability
- `## Boundary Contracts` — one `### B<n>: <name>` subsection per contract, each written testably so acceptance is unambiguous
- `## Reversibility Ledger` — split into two subsections:
  - `### Decided (hard to change)` — technical or architectural decisions that will be costly to reverse
  - `### Delegated (agent's discretion)` — choices explicitly delegated to the implementing agent to make
- `## Conventions` — raw answers from the Conventions interview lens (design tokens/theme, shared-utility policy, naming/layout rules, user-visible failure behavior); the seed `talpiplan` reads when drafting `.talpi/conventions.md`

---

## .talpi/plan.md

Produced by the `talpiplan` skill. This file breaks the specification down into executable phases.

The first line is a status marker: `status: draft` or `status: approved`.

Sections:

- `# Plan: <project>` — the document title
- One `## Phase <n>: <name>` section per phase, each containing:
  - A goal line (one sentence summarizing what that phase achieves)
  - A `Contracts:` line listing which boundary contracts from spec.md this phase pins (e.g., `Contracts: B1, B3`)
  - Step checkboxes in Markdown format (`- [ ] <step description>`) — one step per implementer-subagent dispatch. `talpirun` ticks each to `- [x]` in the same commit that lands the step's work, so the checkboxes are the canonical mid-phase progress record.

The plan is the source of truth for phase numbering and sequencing.

---

## .talpi/conventions.md

Drafted by the `talpiplan` skill and maintained by the `talpirun` skill as a living document. This file captures shared patterns and utilities that implementers should know about before writing code.

Sections:

- `# Conventions` — the document title
- `## Baseline (applies unless overridden)` — domain-neutral form rules proposed at the spec interview's Conventions lens (no repeated inline literals, extract shared logic on second occurrence, one failure-wording tone); whatever the human accepted survives here and is citable by the verifier
- `## Design Tokens` — colors, typography, spacing, and other visual constants used across the project
- `## Shared Utilities` — functions, components, or modules that are available for reuse; implementers register new utilities here as they create them
- `## Layout & Naming` — file organization, naming conventions, and module structure
- `## Failure Behavior` — how errors should be handled, logged, and reported; what constitutes a fatal vs. recoverable failure

---

## .talpi/state.md

A machine-readable-ish snapshot file, overwritten (not appended) at each run state transition. This file is meant to be quickly parseable by both scripts and humans.

Exactly these keys appear, one per line:

- `run_status: speccing | planning | building | done | halted` — the current phase of the run
  - `speccing` — the spec is being written or refined
  - `planning` — the spec is approved; the plan is being written or refined
  - `building` — the plan is approved; implementation is underway
  - `done` — all phases complete; the run has concluded successfully
  - `halted` — the run stopped for a human ruling: a phase-end verifier
    found something that alters an entry on the spec's Reversibility
    Ledger **Decided** list. The reason lives in journal.md's
    `run halted: <reason>` line, not here.
- `current_phase: <n>` — the current phase number (0 before any build phase starts; rests one past `phases_total` once the last phase has reported and the run is in completion; an acceptance rejection appends an Acceptance-fixes phase to plan.md and bumps `phases_total` to match, putting the counters back in normal building range)
- `phases_total: <n>` — total number of phases in the plan
- `updated: <ISO date>` — timestamp of the last update to this file

Example:
```
run_status: building
current_phase: 2
phases_total: 4
updated: 2026-08-05T14:32:00Z
```

---

## .talpi/journal.md

An append-only event log. Never rewritten or compacted; entries stack chronologically.

Format: `- [<ISO date>] <event>` — one event per line.

When a run halts, a journal line is written to explain why: `run halted: <reason>`. This line always accompanies a state.md transition to `run_status: halted`.

The `phase <n> started (base: <hash>)` event records the commit the phase's diff range starts from; the phase-end verifier reviews `<hash>..HEAD`.

Example events (illustrative, not exhaustive):
```markdown
- [2026-08-05T10:00:00Z] run started: speccing
- [2026-08-05T11:15:00Z] spec approved
- [2026-08-05T11:30:00Z] run started: planning
- [2026-08-05T14:00:00Z] plan approved, 4 phases
- [2026-08-05T14:05:00Z] run started: building
- [2026-08-05T14:06:00Z] phase 1 started (base: 3f2c9a1)
- [2026-08-05T14:32:00Z] phase 1 verified
- [2026-08-05T16:45:00Z] run halted: verifier found auth model changed from spec
```

On conflicting entries (same timestamp or event), the latest line wins, and only that version is authoritative.

---

## .talpi/handoff.md

Overwritten at every phase boundary and whenever context becomes constrained. This file is the "resume point" for a fresh session.

A session reading `handoff.md` + `state.md` + `conventions.md` (without any prior conversation history) must have enough information to pick up the work where it was left off and continue productively.

Sections:

- `## Done so far` — summary of completed work, phase by phase or by category
- `## Next step` — concrete, unambiguous next action (e.g., "Implement the user-auth module per Phase 2, step 3")
- `## Gotchas` — known pitfalls, dependency issues, edge cases, or open questions that may trip up the next session

Example:
```markdown
## Done so far

Phase 1 (Setup) is complete. Database schema is defined and migrations run. Frontend scaffolding set up.

## Next step

Implement the user-auth controller in Phase 2. Start with the login endpoint as described in plan.md Phase 2, step 2.

## Gotchas

- The database migrations assume PostgreSQL 13+; SQLite is not supported.
- The frontend build step has a 5-minute cold-start time on first run; expect delays.
- Context limit is tightening; next session may need to split Phase 2 into sub-phases.
```

---

## .talpi/manual-check.md

The human's eye-verification checklist, for projects whose spec names simplicity zones that leave a surface to eye verification. A project with no eye-verified zones never creates this file.

Created and appended by `talpirun` at each phase report whose phase built or reshaped an eye-verified surface: concrete check items derived from the smoke scenario and the phase's work, specific enough to walk without reading the code — what to open, what to do, what should be seen. The phase report's `Manual check:` line records how many items the phase added.

At completion, the final report hands the file to the human: walking it is the verification story for the eye-verified zones, so acceptance is asked *with* it, not before it. The file is for the human's eyes and hands — no agent walks or checks off its items.

Example:

```markdown
## Phase 2: bubble scene

- Open `/` in a real browser (not headless). Bubbles drift over the
  backdrop; motion is smooth, no stutter.
- Hover a work bubble: it pauses and enlarges, and the work's objet
  fades in on its surface.
- Click a work bubble: it pops with a particle burst, then the work
  page opens.
```

---

## Running State Lifecycle

A typical talpi run progresses:

1. **speccing** — `talpispec` writes spec.md, spec.md is reviewed
2. **planning** — `talpiplan` writes plan.md from the approved spec, plan.md is reviewed
3. **building** — `talpirun` executes phases, updating state.md and journal.md at phase boundaries
4. **done** — all phases complete; run concludes with run_status: done
5. **halted** — if a phase-end verifier finding alters a Reversibility Ledger **Decided** entry, the run transitions to halted for a human ruling, with a journal explanation (context, time, or resource limits never halt a run — those are self-served via auto-compact and the session-start hook)

At any transition, handoff.md is written to ensure the next session can resume without conversation history.
