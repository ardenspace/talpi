# .talpi/ State Format

All cross-session state lives in `.talpi/` at the target project root. This directory serves as the canonical store for project state, designed with one core assumption: any session can terminate at any moment. The files described here are the single source of truth for the state of a talpi run. All files are Markdown, human-readable, and should be committed to version control so their evolution is tracked.

Skills and agents must never invent new state files or namespaces outside of `.talpi/`. Every reference to `.talpi/*` from a skill must be to a file defined in this document.

## State scripts

Four plugin scripts mechanize reading and writing this state, so rule-following is a tool call rather than prose interpretation. They are the canonical parser and writers; skills invoke them via `${CLAUDE_PLUGIN_ROOT}/scripts/`:

- **`talpi-status.sh [root]`** — read-only. Reads `.talpi/`, applies the conflict rule (journal wins over `state.md`) and the guard/resume decision table, and prints the run's position plus exactly one `next:` action line. On a multi-run journal, the scan is fenced at the last run-start marker (`run started over done run` / `refactor run started over done run`): events before it belong to an archived run and never route the current one. Disagreements between `state.md` and the journal surface as `warning:` lines, and so does journal tampering (a committed journal line edited or removed). **The decision table lives in this script alone** — skill prose routes on the script's output and must not duplicate the table.
- **`talpi-journal.sh "<event>" [root]`** — appends one line to `.talpi/journal.md` in the canonical `- [<ISO date>] <event>` form. The only sanctioned way to write the journal. Before appending it verifies the committed (HEAD) journal is a byte-prefix of the working copy and refuses to append onto a tampered journal — append-only is a mechanical guarantee, not a convention.
- **`talpi-state.sh <run_status> <current_phase> <phases_total> [root]`** — rewrites `.talpi/state.md` in full, validating the `run_status` vocabulary and numeric phases, stamping `updated`. The only sanctioned way to write the snapshot.
- **`talpi-knowledge.sh check|replay [root]`** — the trust gate over `.talpi/knowledge.md`. `check` is read-only: validates the file's structure and entry grammar, resolves every Decision quote content-addressed against `spec.md`, `archive/*/spec.md`, and `journal.md`, enforces question form in Open questions, and flags Facts whose `scope` files changed since their `as of` hash as `stale — demote to question`. `replay` runs every Fact's command from the project root and reports pass/fail per entry — the write-time gate; recon may also replay before trusting an inherited fact.

`root` defaults to `$CLAUDE_PROJECT_DIR`, then the working directory. The decision table's behavior is pinned by `scripts/test/status.test.sh`; the knowledge gate and the append-only guard by `scripts/test/knowledge.test.sh`.

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
- [2026-08-05T11:15:00Z] spec approved
- [2026-08-05T14:00:00Z] plan approved, 4 phases
- [2026-08-05T14:06:00Z] phase 1 started (base: 3f2c9a1)
- [2026-08-05T14:32:00Z] phase 1 verified
- [2026-08-05T16:45:00Z] run halted: verifier found auth model changed from spec
```

The journal is per-project, not per-run: a new run over a `done` project archives `spec.md` and `plan.md` but appends to the same journal. The boundary between runs is a run-start marker — `run started over done run` (talpispec) or `refactor run started over done run` (talpirefactor), journaled when the archive move lands. `talpi-status.sh` fences its scan at the last such marker, so an archived run's `run done` / `run halted:` / completion-tail events cannot route the current run.

On conflicting entries (same timestamp or event), the latest line wins, and only that version is authoritative.

Append-only is a mechanical guarantee, not a convention: before appending, `talpi-journal.sh` verifies that the committed (HEAD) version of journal.md is a byte-prefix of the working copy, and refuses to append onto a tampered journal. `talpi-status.sh` surfaces the same condition as a `warning:` line. This matters beyond hygiene — journal.md is a provenance store: `knowledge.md`'s verbatim Decision quotes resolve against journal lines, so line immutability is the load-bearing wall under every content-addressed check.

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

## .talpi/knowledge.md

The distilled memory of past runs. Together with `journal.md`, one of only two files that survive across runs: a new run over a done project archives `spec.md` and `plan.md` into `.talpi/archive/<ISO date>/`, but `knowledge.md` (like `journal.md`) stays in place and keeps accumulating. Written by the `talpirun` skill at completion — on acceptance, before the `run done` journal line — and read only by the implementation lane of the next run (see the read rule below).

The governing rule: **inherit only knowledge that cannot lie.** Knowledge splits into three types with different contamination profiles — records of human choice (cannot be wrong), machine-verifiable facts (replaying them exposes any falsehood), and model interpretations (no verification anchor, so plausible-but-wrong inherits as truth). The first two persist, each in a form a script can verify; the third survives only as a question, never a statement — labels like "unverified" do not defuse anchoring, so statement form is banned outright.

The first line is `# Knowledge`, followed by exactly these three sections, in this order. Entries start with a `- <field>:` line; continuation fields are indented two spaces.

### `## Decisions`

Verbatim quotes of human decisions — records of choice, not truth claims. No model paraphrase: the check is string equality against the original, so distortion dies mechanically.

```
- quote: <text copied byte-for-byte from spec.md's Reversibility Ledger or a journal line>
  rationale: <the decision's rationale, also copied byte-for-byte>
  source: <where it was copied from, e.g. "journal.md" or "spec.md Ledger">
  date: <YYYY-MM-DD>
```

`rationale` is optional (a journal line may not record one), but when present it is verbatim-checked like the quote. Provenance is **content-addressed**: `quote` (and `rationale`) must appear verbatim in `.talpi/spec.md`, `.talpi/archive/*/spec.md`, or `.talpi/journal.md`. The `source` field is a human-facing hint only — the check never trusts it — so entries survive a later run archiving spec.md into a dated directory unknowable at distillation time. Prefer journal lines as quote targets: journal.md is the one file that never moves.

Entries are dated because human decisions go stale. Reopening or retiring a Decision is a human act, never the model's.

### `## Verified facts`

Replayable commands only — a dressed-up interpretation has no command to replay, so it cannot enter this section.

```
- fact: <short name>
  command: <POSIX shell command, run from the project root>
  expect: <text the command's output must contain>
  as of: <commit hash at which the fact was last verified>
  scope: <space-separated paths the fact depends on (no spaces within a path)>
```

A fact replays by running `command` from the project root; it passes iff the command exits 0 and its output contains the `expect` text. `scope` is descriptive only — which files or surfaces the command exercises. Semantic claims ("guarantees X", "pins Y") are banned from Fact prose; what a fact *means* is an interpretation and belongs in Open questions. The check flags any fact whose `scope` files changed since its `as of` hash: `stale — demote to question`.

### `## Open questions`

The only afterlife for interpretations, and for negative knowledge ("tried Z, failed"). Question form is mechanically enforced — the text must end with `?`. Provenance pointers (a commit hash, a journal line) are allowed, but the entry is homework for the next run, never a belief it inherits.

```
- question: <text ending with ?>
  source: <optional provenance pointer — commit hash, journal line>
```

### Write rule

At completion, on acceptance and before the `run done` journal line, the orchestrator distills the run's learnings into the three sections, then runs the gate — `talpi-knowledge.sh check` and `talpi-knowledge.sh replay`. Entries that fail are dropped or demoted to Open questions, and the gate re-runs until clean. Trust comes from the gate, not the distiller — the same trust architecture as implementers plus contract tests.

### Read rule (lane isolation)

Only the implementation lane ever reads knowledge.md: talpispec / talpirefactor recon, and implementers via the approved spec. Verifiers, run reviewers, and spec review panels never see it — not the file path, not its contents inlined into a dispatch prompt — so inherited blind spots stay decorrelated from the verification lane. Two guards against laundering knowledge into the verification lane:

- knowledge.md is never merged into `conventions.md` (the verifier reads conventions.md); conventions.md only carries what *this run* mined or observed.
- When recon feeds a knowledge-derived item into the spec, it marks the origin, and the human approves the spec — knowledge gains execution authority only through that human gate.

---

## Running State Lifecycle

A typical talpi run progresses:

1. **speccing** — `talpispec` writes spec.md, spec.md is reviewed
2. **planning** — `talpiplan` writes plan.md from the approved spec, plan.md is reviewed
3. **building** — `talpirun` executes phases, updating state.md and journal.md at phase boundaries
4. **done** — all phases complete; on acceptance the run distills `knowledge.md` (gated by `talpi-knowledge.sh`), then concludes with run_status: done
5. **halted** — if a phase-end verifier finding alters a Reversibility Ledger **Decided** entry, the run transitions to halted for a human ruling, with a journal explanation (context, time, or resource limits never halt a run — those are self-served via auto-compact and the session-start hook)

At any transition, handoff.md is written to ensure the next session can resume without conversation history.
