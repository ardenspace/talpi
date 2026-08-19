# talpi

*talpi* (탈피) is Korean for "molting" — a crustacean grows soft inside a
hard shell, then sheds and rebuilds it. Talpi hardens your project's
boundaries with human-designed contracts and lets the interior grow fast
and free.

## Philosophy

Quality is measured by one question: **how hard is this decision to
change later?** Hard-to-change decisions — external boundaries, schemas,
public APIs, stack choices — are designed carefully with the human, up
front, and protected thickly with contract tests. Easy-to-change
decisions — everything internal — are explicitly delegated to the agent:
built fast, thin, with minimal verification, on the condition that they
stay refactorable. The verification budget is spent where it matters,
at the boundaries, instead of spread evenly across the whole codebase —
that's what keeps an MVP both fast to build and solid, and what keeps
maintenance cheap after it ships. The corollary: spec thickness is
proportional to boundary surface, not project size. A spec that starts
describing internals is itself a signal of over-engineering.

Full rationale and design record:
[`docs/specs/2026-08-05-talpi-design.md`](docs/specs/2026-08-05-talpi-design.md).

## The pipeline

```
1. SPEC    Act 1: product conversation (divergent, freeform)
           Act 2: design interview (convergent, 4 lenses)
           Spec review panel (3 fresh-session reviewers)
           → HUMAN APPROVAL (required)
2. PLAN    Phase decomposition + conventions.md draft
           → HUMAN APPROVAL (required — last mandatory human gate)
3. BUILD   Autonomous. Per phase: pin boundary contracts as tests first,
           then implement freely inside them. No per-step verification.
4. VERIFY  At each phase end: one fresh-session independent verifier.
           Fix what's fixable; escalate the rest. Reports are
           non-blocking — except violations of Decided (hard-to-change)
           decisions, which halt the run for the human.
5. DONE    All contract tests green + smoke run + whole-run review +
           human acceptance. On acceptance the run distills what it
           learned into .talpi/knowledge.md for the next run — gated
           so only knowledge that cannot lie survives.
```

`talpispec` turns a product idea into an approved spec: a freeform
product conversation first, then a four-lens design interview (scope,
boundary, reversibility, conventions), then a fresh-session review
panel. For an existing codebase, `talpirefactor` is the alternate
entry point: the same spec artifacts, produced by interviewing the
code itself — mined conventions, current behavior pinned as the
boundary contracts — for a behavior-preserving refactor run. `talpiplan` decomposes the approved spec into phases and drafts
`.talpi/conventions.md` — the last mandatory human gate before the build
runs unattended. `talpirun` is the autonomous core: at the start of each
phase it pins that phase's boundary contracts as failing tests, then
hands every step — contract-pinning included — to a fresh implementer
subagent, so the orchestrating session stays a thin dispatcher and never
implements inline; each step lands as its own commit, and disk state,
not conversation history, is what a step inherits. At each phase's end, one fresh-session verifier checks contract
adherence, smuggled irreversible decisions, and convention drift, then
fixes what it can and reports to chat. Escalation is two-tier: most
findings are non-blocking, but a finding that touches a Decided
(hard-to-change) entry on the reversibility ledger halts the run for a
human ruling before it continues. `talpiresume` reads `.talpi/` state off
disk and routes a fresh session back into the pipeline at exactly the
right point. There is no supervisor process watching the run — a live
session self-serves its own context, and a long silence in chat is the
signal that a session died; the human restarts with one command and the
session-start hook surfaces the run so talpiresume picks it up from the
right point.

## Skills

| Skill | What it does |
|---|---|
| `talpispec` | Turns a product idea into an approved `.talpi/spec.md` through a two-act conversation (freeform product talk, then a four-lens design interview) and a fresh-session review panel. |
| `talpirefactor` | Brownfield twin of talpispec: a short intent conversation, then a three-angle codebase recon (mined conventions, pinned/unpinned behavior, hotspots) that becomes a behavior-preserving refactor spec (`mode: refactor`) — same panel, same approval, same pipeline downstream. |
| `talpiplan` | Decomposes the approved spec into phases and drafts `.talpi/conventions.md` — the last mandatory human gate before the build runs autonomously. |
| `talpirun` | Executes the plan phase by phase: pins boundary contracts as tests first, dispatches fresh implementer subagents per step (one commit per step), verifies each phase with one fresh-session reviewer, and reports non-blocking. |
| `talpiresume` | Reads `.talpi/` state off disk and routes a fresh session back into the pipeline at the right point — after a compact, a crash, or a restart. |

## State

All cross-session state lives in `.talpi/` at the project root — spec,
plan, conventions, state, journal, handoff, and knowledge, all plain
Markdown, all meant to be committed to version control. The design
assumption behind this is
that any session can die at any moment, so the files on disk — not the
conversation — are the single source of truth for where a run stands.
Full field-by-field format: [`docs/state-format.md`](docs/state-format.md).

Two files survive across runs: `journal.md` and `knowledge.md`.
The journal is append-only as a mechanical guarantee — the journal
script refuses to append when a committed line was edited or removed,
because journal lines are the provenance store under the knowledge
checks. `knowledge.md` is the distilled memory of past runs, written
at completion behind a script gate that admits only knowledge that
cannot lie: human decisions as verbatim quotes (string-checked against
their source), facts as replayable commands (re-run at write time,
dropped on failure), and everything interpretive only as open
questions. Only the implementation lane of the next run reads it —
verifiers, run reviewers, and spec panels stay blind, so an inherited
blind spot cannot recruit the lane meant to catch it.

## Install

```
/plugin marketplace add ardenspace/talpi
/plugin install talpi@talpi
```

Run these inside Claude Code. Restart Claude Code to load the plugin.
Then, in your project, invoke the `talpispec` skill to start the
pipeline (`talpirefactor` when the project is an existing codebase to
restructure).

## Status

v1 ships the 0→1 MVP pipeline described above — spec, plan, build,
verify, done — as a Claude Code plugin, plus `talpirefactor` as the
brownfield entry point for behavior-preserving refactor runs.
Feature-addition workflows on shipped projects are v2, and the plan is
to design and build them *with* talpi itself, dogfooding the same
pipeline shipped here.

## License

MIT — see [`LICENSE`](LICENSE).
