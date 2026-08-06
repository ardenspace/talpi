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

## Conflict Rule

`journal.md` is append-only; where entries conflict, the latest line wins.
`state.md` is a convenience snapshot — if it contradicts the journal, trust
the journal and rewrite `state.md`.

Apply this before routing: read `.talpi/state.md`, then check the tail of
`.talpi/journal.md` for anything more recent that `state.md` doesn't
reflect (a phase advance, a halt, a resume-after-ratify or
resume-after-reject). If they disagree, the journal wins — rewrite
`state.md` to match it, then route off the corrected value.

## Fallback: no readable state.md

If `.talpi/` exists but `state.md` is missing, or its `run_status` line
can't be read, do not guess blindly — check the journal first, then
rewrite `state.md` in full (all four keys) before routing:

- Check the tail of `.talpi/journal.md` for the most recent relevant
  entry first. If it is `run done`, infer `done`. If it is `run
  halted: <reason>` with no later entry noting the run resumed, infer
  `halted`. Either way, reconstruct `current_phase` and `phases_total`
  from plan.md and the journal per the Conflict Rule above, then route
  accordingly. Otherwise, fall through to inferring from
  spec.md/plan.md below.
- No `.talpi/spec.md`, or it exists with `status: draft` — infer
  `speccing`.
- `.talpi/spec.md` has `status: approved` but there is no
  `.talpi/plan.md` with `status: approved` — infer `planning`.
- `.talpi/plan.md` has `status: approved` — infer `building`, and
  reconstruct `current_phase` and `phases_total` from the journal per
  the Conflict Rule above (the plan's phase count and the journal's most
  recent phase-advance or halt line).

## Routing

Read `.talpi/state.md`'s `run_status` and route:

- **`speccing`** — hand off to the talpispec skill.
- **`planning`** — hand off to the talpiplan skill.
- **`building`** — hand off to the talpirun skill, re-entering at
  `current_phase`. Before handing off, read `.talpi/handoff.md`,
  `.talpi/conventions.md`, and the tail of `.talpi/journal.md` so the
  resumed run has the same context a continuous session would have had —
  what's done, the concrete next step, and any gotchas recorded for it.
  Mid-phase position comes from `.talpi/plan.md` itself: the current
  phase's first unchecked `- [ ]` step is the next dispatch (talpirun
  ticks a checkbox in the same commit that lands its step). If the
  working tree has uncommitted changes, that first unchecked step was
  in flight when the session died — hand the diff to that step's fresh
  implementer subagent as context rather than discarding it.
- **`done`** — do not re-enter the pipeline. Summarize the run for the
  human from `.talpi/state.md`, `.talpi/plan.md`, and the journal (the
  `run done` line marks the human's final acceptance): what was built,
  how many phases, and the outcome of final acceptance.
- **`halted`** — do not resume automatically. Find the `run halted:
  <reason>` line in `.talpi/journal.md` (the most recent one, per the
  conflict rule), present that reason to the human together with the
  relevant context from `.talpi/handoff.md`, and ask them how to proceed —
  ratify, reject, or otherwise resolve — before anything continues. Once
  the human rules, hand off to the talpirun skill: executing the decision
  (ledger/spec update on ratify, or revert plus a fresh verifier re-check
  on reject), setting `run_status` back to `building`, and journaling the
  resume are talpirun's job, not talpiresume's.

If `.talpi/` does not exist at all, there is no run to resume — report
that and suggest starting with talpispec instead.

## Status Questions

If the human is only asking where the run stands ("where are we?",
"what's the status?") rather than asking to continue, answer from disk —
`state.md`, the journal tail, and `handoff.md` if relevant — and stop
there. A status question never re-enters the pipeline or hands off to
another skill on its own; it answers, then waits.
