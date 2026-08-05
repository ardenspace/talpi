---
name: talpirun
description: Use when a talpi plan is approved and the build should start or continue. Autonomous per phase - pin boundary contracts as tests first, implement freely inside them, one fresh verifier per phase, non-blocking reports to the human.
---

# talpirun

Execute an approved `.talpi/plan.md` phase by phase: pin each phase's
boundary contracts as failing tests, dispatch fresh implementer subagents
to make them pass, verify with one fresh-context reviewer, report to the
human, and continue on — without waiting for a reply. This is the
autonomous core of talpi. Once the plan was approved, there are no more
mandatory human gates until a phase report, an escalation, or final
acceptance brings the human back in.

## Guard

Before starting, check `.talpi/plan.md`. If it does not exist, or its
first line is not `status: approved`, do not start building — report
that no approved plan exists yet and route to the talpiplan skill
instead.

If `.talpi/state.md` reads `run_status: halted`, do not build — hand
off to the talpiresume skill so the human can rule on the halt first.

Read `.talpi/state.md` for `current_phase` and `phases_total` and work
the plan one phase at a time starting there. If `current_phase` is
already past `phases_total`, the run should already be `done`; check
`.talpi/journal.md` for what happened instead of re-running a phase.
If the journal's tail is `run done`, the run is genuinely finished —
report that. If instead the tail is `final report sent, awaiting
acceptance` with no later `run done` line, completion already ran and
is waiting on the human — remind them the final report is pending
their acceptance and wait; do not rebuild or re-send the report.

## Phase loop

For the phase identified by `current_phase` in `.talpi/state.md`, work
through that `## Phase <n>: <name>` section of `.talpi/plan.md`:

1. **Thin orchestrator.** The talpirun session never implements inline.
   It manages state, dispatches one fresh implementer subagent per task
   in the phase, and reports — nothing more. Each subagent starts with
   no conversation history; it receives `.talpi/conventions.md`, the
   phase's contracts (the `B<n>` shapes from spec.md that the phase's
   `Contracts:` line names), and its own task description from
   plan.md, and nothing else. This keeps the orchestrator's own context
   lean for long runs, and forces disk state — not conversation memory
   — to be the real continuity mechanism on every single task.
   Journal `phase <n> started` when the phase's first task is
   dispatched.
2. **Pin contracts.** The first task of every phase writes that phase's
   `Contracts:` list as failing tests, before any other implementation
   task runs. Journal `phase <n> contracts pinned` once those tests
   exist and fail for the right reason — missing implementation, not a
   broken test.
3. **Implement freely.** The phase's remaining tasks run the same way,
   one fresh subagent per task, but with no per-task verification
   ceremony and no reviewer panels mid-phase. Internal implementation
   decisions belong to the implementer. Each subagent returns its
   result plus any questions it has for the human. The orchestrator
   registers any new shared utility a subagent reports in
   `.talpi/conventions.md`, so the next subagent inherits it, and
   relays questions to the human under this rule:

   > Ask the human only what a *user of the product* would notice, or
   > what touches a boundary contract or the Reversibility Ledger's
   > Decided list. Everything else is yours — the ledger's Delegated
   > list is your license.

4. **Contracts green.** Once every task in the phase is done and the
   phase's pinned contract tests are green, move to phase-end
   verification.

## Phase-end verification

Dispatch exactly one fresh-context verifier — no conversation history —
using `references/verifier-prompt.md`, filling in the phase number, the
project name, and the diff range covering this phase's work.

The verifier returns one line per finding, `[FIX]` or `[ESCALATE]`, or
returns exactly `CLEAN`. Fix every `[FIX]` finding before moving on —
send it back to a fresh implementer subagent, the same as any other
task; the thin-orchestrator rule holds here too, so the talpirun session
never fixes a finding inline itself, no matter how trivial it looks —
then re-run the phase's contract tests. Carry every `[ESCALATE]` finding
forward into the phase report; do not resolve it yourself.

Journal `phase <n> verified` once the verifier has run and any `[FIX]`
findings are resolved.

## Phase report

Fill `references/phase-report-template.md` for the phase and deliver it
to the human through the session's available channel. Journal
`phase <n> reported`, update `.talpi/state.md` (`current_phase` advanced
to the next phase, `updated` timestamp refreshed), and continue
immediately to the next phase's loop — never wait for a reply. A human
reply, if one comes, steers the next phase; silence is not a blocker.

**Exception — blocking escalation.** If a finding from phase-end
verification alters an entry on the Reversibility Ledger's *Decided*
list, this phase does not get a normal, continue-on report. Instead:

1. Set `.talpi/state.md`'s `run_status: halted`.
2. Journal `run halted: <reason>`, with the reason naming the Decided
   entry the finding affects.
3. Send the phase report anyway, with the escalation framed as a
   question the human must rule on: ratify the change, or reject it.

On ratify: update the Reversibility Ledger and spec.md to reflect the
new decision, then resume — set `.talpi/state.md`'s `run_status` back to
`building` and journal that the run resumed after ratifying the
decision. On reject: revert the decision in the code, dispatch a
fresh-session verifier to re-check the revert, and only then resume the
same way — `run_status` back to `building` in `.talpi/state.md`, and a
journal entry noting the run resumed after reverting the decision. In
both cases, `state.md` must never be left reading `halted` once the run
is actually moving again. Every stop-report — halted or not — includes
the one-line resume command, so the human, or the next session, knows
exactly how to continue. The resume command is simply: start a fresh
Claude Code session in the project directory. The plugin's
session-start hook detects `.talpi/` on disk and routes automatically
to the talpiresume skill — there is nothing else to type or remember.

All other escalations are non-blocking: list them in the phase report
and keep going.

## Persistence discipline

Rewrite `.talpi/handoff.md` at every phase boundary, and again whenever
context runs low mid-phase — not just at the edges. State on disk is
the only truth talpirun relies on: `handoff.md` plus `state.md` plus
`conventions.md` must be enough for a fresh session with no conversation
history to pick up exactly where this one left off. The human is never
summoned for context reasons alone — context exhaustion is a disk-write
problem, not a human problem.

## Completion

After the last phase's contract tests are green and its phase-end
verification is clean or resolved:

1. Run the **smoke run** — actually launch the product and walk the
   smoke scenario from `.talpi/spec.md`'s Product Picture, for real,
   not as a test file. If the smoke run breaks, that is not a
   completion blocker to escalate — it reopens the phase loop: treat
   the break as a task, dispatch a fresh implementer subagent to fix
   it, and re-run the smoke scenario before attempting completion
   again.
2. Send the final report asking the human for acceptance. Human
   acceptance is the final gate — completion is not done until they
   say so.
3. Journal `final report sent, awaiting acceptance`. Leave
   `.talpi/state.md`'s `run_status` at `building` — the run is not
   `done` yet — and rewrite `.talpi/handoff.md` so a fresh session
   landing here knows the build is finished and is waiting on the
   human's acceptance, not mid-phase work.
4. Wait for the human's response, same as any other stop-report: the
   run does not send further reports on its own from here.

**On acceptance:** rewrite `.talpi/state.md` in full, all four keys:
`run_status: done`, `current_phase` and `phases_total` unchanged,
`updated: <ISO date>`. Journal `run done`.

**On rejection:** treat it like a broken smoke run — this is not an
escalation, it reopens the phase loop. Turn the human's feedback into
one or more tasks, dispatch fresh implementer subagents the same as
any other task, re-run the affected contract tests, then repeat
Completion (smoke run through asking for acceptance again) from step 1.

Nothing about completion is heavyweight: the boundaries were already
guarded by contracts through every phase, and internals were built to
stay cheap to change if acceptance surfaces something.
