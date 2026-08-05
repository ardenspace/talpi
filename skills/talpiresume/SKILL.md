---
name: talpiresume
description: Use when a session starts in a project with an unfinished talpi run (.talpi/ exists), after a context handoff, or when the user asks where the run stands. Reads disk state and re-enters the pipeline at the right point.
---

# talpiresume

A fresh session has no conversation history to rely on. talpiresume reads
`.talpi/` off disk and routes to wherever the run actually is — the
counterpart to talpirun's persistence discipline: if talpirun's job is to
make sure disk state is always enough to resume from, talpiresume's job is
to do that resuming.

## Conflict rule

`journal.md` is append-only; where entries conflict, the latest line wins.
`state.md` is a convenience snapshot — if it contradicts the journal, trust
the journal and rewrite `state.md`.

Apply this before routing: read `.talpi/state.md`, then check the tail of
`.talpi/journal.md` for anything more recent that `state.md` doesn't
reflect (a phase advance, a halt, a resume-after-ratify or
resume-after-reject). If they disagree, the journal wins — rewrite
`state.md` to match it, then route off the corrected value.

## Routing

Read `.talpi/state.md`'s `run_status` and route:

- **`speccing`** — hand off to the talpispec skill.
- **`planning`** — hand off to the talpiplan skill.
- **`building`** — hand off to the talpirun skill, re-entering at
  `current_phase`. Before handing off, read `.talpi/handoff.md`,
  `.talpi/conventions.md`, and the tail of `.talpi/journal.md` so the
  resumed run has the same context a continuous session would have had —
  what's done, the concrete next step, and any gotchas recorded for it.
- **`done`** — do not re-enter the pipeline. Summarize the run for the
  human from `.talpi/state.md`, `.talpi/plan.md`, and the journal: what
  was built, how many phases, and the outcome of final acceptance.
- **`halted`** — do not resume automatically. Find the `run halted:
  <reason>` line in `.talpi/journal.md` (the most recent one, per the
  conflict rule), present that reason to the human together with the
  relevant context from `.talpi/handoff.md`, and ask them how to proceed —
  ratify, reject, or otherwise resolve — before anything continues. This
  mirrors talpirun's halt/resume flow: only after the human rules does
  `run_status` move back to `building`, and that transition belongs to
  talpirun, not to talpiresume.

If `.talpi/` does not exist at all, there is no run to resume — report
that and suggest starting with talpispec instead.

## Status questions

If the human is only asking where the run stands ("where are we?",
"what's the status?") rather than asking to continue, answer from disk —
`state.md`, the journal tail, and `handoff.md` if relevant — and stop
there. A status question never re-enters the pipeline or hands off to
another skill on its own; it answers, then waits.
