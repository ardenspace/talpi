---
name: talpirun
description: Use when a talpi plan is approved and the build should start or continue. Autonomous per phase - pin boundary contracts as tests first, implement freely inside them, one fresh verifier per phase, non-blocking reports to the human, one whole-run fresh-eyes review before final acceptance.
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

Before starting, run the plugin's status script and follow its `next:`
line. The where-is-this-run decision table lives in the script, not in
prose, so re-entry is a tool call rather than a journal-reading
exercise:

    sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-status.sh"

Route on the `next:` line it prints:

- **route to talpispec / talpirefactor / talpiplan** — no approved
  plan yet; do not build, hand off to that skill.
- **halted** — do not build; hand off to the talpiresume skill so the
  human can rule on the halt first (the script surfaces the
  `reason:`). One exception: arriving *from* talpiresume with the
  human's ruling already in hand. Then `halted` on disk is expected —
  execute the ruling (the ratify/reject path under Phase report, which
  sets `run_status` back to `building`) instead of bouncing back to
  talpiresume.
- **phase loop — work phase `<n>`** — enter the Phase loop below at
  that phase; a `step:` line names the phase's first unchecked step.
  `current_phase` equal to `phases_total` is normal — it means the
  last phase is the one being built.
- **completion** — the phase loop is over; enter Completion at step 1.
  A `note:` line may narrow the run review's diff range to
  `<hash>..HEAD` — earlier commits were already reviewed, and the
  smoke run and review are idempotent, so the redo is cheap.
- **awaiting acceptance** — completion already ran and is waiting on
  the human; remind them the final report is pending their acceptance
  and wait. Do not rebuild or re-send the report.
- **reopen phase loop** — acceptance was declined and the reopened fix
  work is in progress; continue the phase loop rather than waiting (if
  plan.md has no Acceptance-fixes phase yet, appending it is the first
  move — see Completion's rejection path).
- **run done** — the run is genuinely finished; report that.

Any `warning:` line means `.talpi/state.md` disagrees with the journal
— the journal wins. Rewrite state.md to the corrected values (the
state script below) before continuing.

## Phase loop

For the phase identified by `current_phase` in `.talpi/state.md`, work
through that `## Phase <n>: <name>` section of `.talpi/plan.md`:

1. **Thin orchestrator.** The talpirun session never implements inline.
   It manages state, dispatches one fresh implementer subagent per step
   in the phase, and reports — nothing more. Each subagent starts with
   no conversation history; it receives `.talpi/conventions.md`, the
   phase's contracts (the `B<n>` shapes from spec.md that the phase's
   `Contracts:` line names), and its own step description from
   plan.md, and nothing else — all three inlined in the dispatch
   prompt, not passed as paths for the subagent to go read. Build
   every dispatch from `references/implementer-prompt.md`: it carries
   those three slots plus the standing rules each implementer must
   receive — the question rule and the contract-dispute license below
   travel in the template, never from the orchestrator's memory, so no
   implementer is dispatched without them. Inlining
   is safe because the orchestrator is conventions.md's only writer
   during a run and the contracts froze at spec approval, so the
   inlined copies cannot be stale — and it spares each subagent the
   discovery tool calls. This keeps the orchestrator's own context
   lean for long runs, and forces disk state — not conversation memory
   — to be the real continuity mechanism on every single step.
   Environment facts the run must respect — port assignments, services
   that must not be killed, machine quirks from CLAUDE.md or the human
   — are written into conventions.md once, when the run's first
   dispatch is prepared, never repeated ad hoc in each dispatch prompt:
   conventions.md is already inlined into every dispatch, so recording
   them there is what makes the repetition unnecessary.
   Journal `phase <n> started (base: <hash>)` when the phase's first
   step is dispatched, where `<hash>` is the commit HEAD points at just
   before that step — the phase's diff range starts there. (Every
   journal entry, here and below, is appended through the plugin's
   journal script — `sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-journal.sh"
   "<event>"` — which stamps the canonical `- [<ISO date>] <event>`
   form; journal.md is never rewritten or hand-formatted. Likewise,
   every state.md rewrite goes through the state script —
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-state.sh" <run_status>
   <current_phase> <phases_total>` — which validates the vocabulary,
   writes all four keys, and stamps `updated`.)
2. **Pin contracts.** The first step of every phase writes that phase's
   `Contracts:` list as failing tests, before any other implementation
   step runs. Journal `phase <n> contracts pinned` once those tests
   exist and fail for the right reason — missing implementation, not a
   broken test. If the phase's `Contracts:` line is empty (a phase may
   legitimately pin nothing when its boundaries were pinned by earlier
   phases), there is no pinning step: journal `phase <n> contracts:
   none` instead when the phase's first step is dispatched, and let
   that first step be whatever the plan says it is — usually plain
   behavior tests.
3. **Implement freely.** The phase's remaining steps run the same way,
   one fresh subagent per step, but with no per-step verification
   ceremony and no reviewer panels mid-phase. Internal implementation
   decisions belong to the implementer. Each subagent returns its
   result — including the files it created or significantly reshaped —
   plus any questions it has for the human. The orchestrator
   registers any new shared utility a subagent reports in
   `.talpi/conventions.md`, so the next subagent inherits it. It also
   appends one line per step to a `Prior work this phase` block in
   conventions.md — `step <k>: <path> — <purpose>` — reset at each
   phase start, so every later fresh subagent in the phase sees what
   already exists and reuses it instead of recreating it; this is
   unconditional, not just for utilities the implementer thought to
   flag as shared. Questions are relayed to the human under this rule:

   > Ask the human only what a *user of the product* would notice, or
   > what touches a boundary contract or the Reversibility Ledger's
   > Decided list. Everything else is yours — the ledger's Delegated
   > list is your license.

   One event outranks that rule: a **contract dispute**. If a pinned
   contract itself looks wrong — it contradicts the spec's intent,
   another contract, or what implementing revealed — the implementer
   says so and stops; it never contorts internals until the test
   passes. The canonical report form lives in
   `references/implementer-prompt.md` (`CONTRACT DISPUTE: <contract
   id> — <one sentence>`), so every implementer knows the license and
   the orchestrator can dispatch on the first line of the reply. "The
   implementation violates the contract" is the
   implementer's to fix; "the contract is wrong" is only ever the
   human's. The orchestrator journals `phase <n> contract dispute:
   <summary>` and halts through the blocking-escalation path under
   Phase report, immediately, not at the phase boundary — a pinned
   contract froze at spec approval, so amending or upholding it is the
   same grade of event as a Decided-list change.

4. **One step, one commit.** When a step's subagent returns and its
   work is accepted — acceptance is mechanical, not a review: run the
   cheapest check the project offers, preferring typecheck or build;
   fall back to the test command only when it is the only mechanical
   check the project has. The point is that no step lands a commit
   that breaks compilation or leaves the suite unrunnable — a
   tripwire, not a verification ceremony. Never re-run a full test
   suite the implementer already ran and reported: correctness is
   phase-end verification's job, and the phase's contract tests get
   their green check at the phase boundary, not on every step. If the
   step touched code but no such check
   can run, journal `phase <n> step <k>: no mechanical check:
   <reason>` and proceed — the orchestrator marks that step's checkbox
   `- [x]` in `.talpi/plan.md` and commits the step's work — the code,
   the plan.md tick, any conventions.md update it triggered, and any
   journal line the step produced (`started`, `contracts pinned`, `no
   mechanical check`) — as a single commit: `talpi: phase <n> step
   <k>: <short description>`. That message form is talpi's default,
   not load-bearing: if the repo enforces its own commit-message
   convention, record that convention in conventions.md when the run's
   first dispatch is prepared (next to the environment facts) and
   follow it instead. What never bends is the atomicity — the step's
   code and its plan.md tick land in the same commit, because that
   commit, not its message, is the step's ground truth.
   If a crash leaves these out of step,
   recovery is mechanical: a step whose commit landed is done whatever
   the journal says (commits are ground truth for steps; the journal
   for phase events; state.md is a snapshot rewritten from the
   journal).
   This holds for the contract-pinning step too (its tests are
   committed failing — they fail for the right reason). Never batch
   steps into one commit, and never leave a finished step uncommitted:
   plan.md's checkboxes plus `git log` are how a fresh session
   reconstructs mid-phase progress.
5. **Contracts green.** Once every step in the phase is done and the
   phase's pinned contract tests are green, move to phase-end
   verification.

## Phase-end verification

Dispatch exactly one fresh-context verifier — no conversation history —
using `references/verifier-prompt.md`, filling in the phase number, the
project name, and the diff range covering this phase's work:
`<base>..HEAD`, where `<base>` is the hash recorded in the phase's
`phase <n> started (base: <hash>)` journal line. The diff excludes
`.talpi/` bookkeeping — plan.md ticks and journal lines are commit
freight, not review material — so the range is read as
`git diff <base>..HEAD -- . ':(exclude).talpi'`; the verifier still
reads the `.talpi/` files themselves as context.

**Lane isolation.** If `.talpi/knowledge.md` exists (a previous run
distilled it), it never enters a verifier or run-reviewer dispatch —
not the path, not its contents inlined into the prompt. And knowledge.md
material is never merged into `.talpi/conventions.md`: the verifier
reads conventions.md, which carries only what *this run* mined or
observed. The verification lane stays blind to inherited knowledge so
an inherited blind spot cannot recruit the very lane meant to catch it.

The verifier returns one line per finding, `[FIX]` or `[ESCALATE]`, or
returns exactly `CLEAN`. Fix every `[FIX]` finding before moving on —
send it back to a fresh implementer subagent, the same as any other
step; the thin-orchestrator rule holds here too, so the talpirun session
never fixes a finding inline itself, no matter how trivial it looks —
then re-run the phase's contract tests and commit the fix the same way
(`talpi: phase <n> fix: <short summary>`). Carry every `[ESCALATE]` finding
forward into the phase report; do not resolve it yourself.

Journal `phase <n> verified` once the verifier has run and any `[FIX]`
findings are resolved.

## Phase report

Before filling the report: if this phase built or reshaped a surface
the spec's simplicity zones leave to eye verification, append concrete
check items for it to `.talpi/manual-check.md` — derived from the smoke
scenario and the phase's work, specific enough to walk without reading
the code (what to open, what to do, what should be seen). The report's
Manual-check line points at the file; the final acceptance walks it. A
project with no eye-verified zones never creates the file.

Fill `references/phase-report-template.md` for the phase and deliver it
to the human through the session's available channel. Journal
`phase <n> reported`, update `.talpi/state.md` (`current_phase` advanced
to the next phase, `updated` timestamp refreshed), and continue
immediately to the next phase's loop — never wait for a reply. A human
reply, if one comes, steers the next phase; silence is not a blocker.

**Delivering the report must not end the turn.** "Continue immediately"
governs the session's turn, not merely its intent, and the channel
decides whether that is automatic. Where the channel is a tool — a chat
integration, a notifier — sending the report is a tool call, and work
continues after it on its own. Where the channel is the session's own
transcript, the report *is* the session's user-facing text, and final
text is how a session ends its turn: written last, it hands control back
to the human and the run stalls there until they type something. That
stall is invisible to the session, which believes it reported and
continued. So the report text is never the turn's final act: emit it,
then keep going in the same turn — the journal line, the state rewrite,
and the next phase's first dispatch all follow it without pausing. The
only turns talpirun may end are the stops this skill names: a blocking
escalation's halt, and the final report awaiting acceptance. A phase
boundary is not one of them, and neither is a channel that happens to
make stopping the path of least resistance.

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
is actually moving again. A contract dispute (Phase loop step 3) halts
through this same path with the ruling vocabulary aimed at the contract
instead of code: ratify amends the contract test and spec to the
disputed reading, reject upholds the pinned contract and the
implementer conforms to it. Every stop-report — halted or not — includes
the one-line resume command, so the human, or the next session, knows
exactly how to continue. The resume command is simply: start a fresh
Claude Code session in the project directory. The plugin's
session-start hook detects `.talpi/` on disk and injects guidance
pointing the fresh session at the talpiresume skill — there is nothing
else to type or remember. (The hook injects an instruction, it cannot
force a skill invocation — the session follows the guidance.)

All other escalations are non-blocking: list them in the phase report
and keep going.

## Persistence discipline

Rewrite `.talpi/handoff.md` at every phase boundary, and again whenever
context runs low mid-phase — not just at the edges. handoff.md records
state and context — the *what* and *where*, never the *how*: do not
restate pipeline procedure in it, because skills change between
versions and a copied procedure goes stale; the how always lives in
the current skill text. State on disk is
the only truth talpirun relies on: `handoff.md` plus `state.md` plus
`conventions.md` — with plan.md's step checkboxes and the one-commit-
per-step log recording exactly which steps have landed — must be enough
for a fresh session with no conversation history to pick up exactly
where this one left off. The human is never
summoned for context reasons alone — context exhaustion is a disk-write
problem, not a human problem.

## Completion

After the last phase's contract tests are green and its phase-end
verification is clean or resolved:

1. Run the **smoke run** — actually launch the product and walk the
   smoke scenario from `.talpi/spec.md`'s Product Picture, for real,
   not as a test file. (On a refactor run — spec.md's second line is
   `mode: refactor` — the smoke scenario is the spec's behavior walk:
   the same end-to-end paths, behaving identically to what the spec
   recorded before the run.) If the smoke run breaks, that is not a
   completion blocker to escalate — it reopens the phase loop: treat
   the break as a step, dispatch a fresh implementer subagent to fix
   it, and re-run the smoke scenario before attempting completion
   again.
   One reuse license exists, and it is mechanical — the diff decides,
   never the session's judgment. When a final-phase step's acceptance
   already included launching the product for real and walking the
   full smoke scenario, journal `smoke walked (at: <hash>)` at that
   moment, `<hash>` being HEAD when the walk finished — the line is
   written when it happens, never retroactively. At completion, that
   walk may stand in for step 1 iff
   `git diff --name-only <hash>..HEAD -- . ':(exclude).talpi'` prints
   only documentation paths (every path matches `*.md`). Then journal
   `smoke reused from phase <n> (doc-only diff since <hash>)` and move
   on. Anything else — one non-doc path, no `smoke walked` line from
   the final phase, a diff command that errors — means walk it fresh.
2. Run the **run review** — dispatch exactly one fresh-context
   reviewer, no conversation history, using
   `references/run-reviewer-prompt.md`. Phase verifiers each saw only
   their own phase's contracts; this is the one look at what sits
   *between* them — contract interactions, the spec swept end to end,
   and leftovers no phase owned. The diff range is
   `<run base>..HEAD`, where `<run base>` is the hash in the journal's
   `phase 1 started (base: <hash>)` line; on a repeat completion
   (reopened by rejection or a review fix), narrow it to
   `<last reviewed hash>..HEAD` from the most recent
   `run review (through <hash>)` journal line — earlier commits were
   already reviewed. The same `:(exclude).talpi` pathspec applies as
   in phase-end verification — bookkeeping churn is not review
   material. Findings route by tag:
   - `[FIX]` (objective bug or spec violation): same machinery as a
     smoke-run break — one fresh implementer subagent per finding,
     re-run the test suite, commit as
     `talpi: run review fix: <short summary>`. Never fixed inline.
   - `[NOTE]` (judgment call, cleanup): do not fix — carry every one
     verbatim into the final report for the human to rule on at
     acceptance.
   - `[ESCALATE]`: treat like a phase-end escalation — blocking (the
     halt path) iff it alters a Reversibility Ledger Decided entry,
     otherwise a question in the final report.
   Journal `run review (through <hash>): <n> findings (<f> fixed,
   <k> noted)` — `<hash>` is the HEAD the reviewer saw — or
   `run review (through <hash>): clean`.
3. Send the final report asking the human for acceptance, with the
   run review's `[NOTE]` findings listed for their ruling. If
   `.talpi/manual-check.md` exists, hand it over here: the eye-verified
   zones' verification story is the human walking that checklist, so
   acceptance is asked *with* it, not before it. Human
   acceptance is the final gate — completion is not done until they
   say so.
4. Journal `final report sent, awaiting acceptance`. Leave
   `.talpi/state.md`'s `run_status` at `building` — the run is not
   `done` yet — and rewrite `.talpi/handoff.md` so a fresh session
   landing here knows the build is finished and is waiting on the
   human's acceptance, not mid-phase work. This bookkeeping lands in
   the same turn as step 3's report — the turn-ending rule under Phase
   report holds here too, and only step 5's wait may end the turn. A
   final report that ends the turn before this runs leaves the journal
   and handoff.md describing a run still mid-phase.
5. Wait for the human's response, same as any other stop-report: the
   run does not send further reports on its own from here.

**On acceptance:** distill the run's knowledge before closing the run:

1. Write (or extend) `.talpi/knowledge.md` — entry grammar and section
   order are defined with the rest of the state format. Only knowledge
   that cannot lie survives: human decisions as **verbatim quotes**,
   copied byte-for-byte from the spec's Reversibility Ledger or a
   journal line (prefer journal lines — journal.md never moves across
   runs); machine-verifiable facts as **replayable commands** with the
   expected output, the current commit hash, and the files they depend
   on; everything interpretive — including negative knowledge like
   "tried Z, failed" — as **Open questions**, phrased as questions,
   never statements.
2. Run the gate — a script, not judgment:

       sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-knowledge.sh" check
       sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-knowledge.sh" replay

   Drop every entry either command reports as failing, or demote it to
   an Open question, and re-run until both are clean. Trust comes from
   the gate, not the distillation — the same architecture as
   implementers plus contract tests. Know what each check means, by
   design: Decision quotes resolve content-addressed — the text must
   appear verbatim in spec.md, an archived spec, or journal.md, so an
   entry surviving a later run's archive move is intended, not a gap
   (the `source:` field is a hint the check never trusts). Open
   questions get only the question-form check because nothing
   downstream ever trusts them; executable trust comes from `replay`
   alone.
3. Journal `knowledge distilled`.
4. Rewrite `.talpi/state.md` in full, all four keys: `run_status:
   done`, `current_phase` and `phases_total` unchanged, `updated: <ISO
   date>`. Journal `run done`.

**On rejection:** this is not an escalation — it reopens the phase
loop as a new phase, so the fix work gets the same machinery as any
other phase. Journal `acceptance declined: <summary>` first, so the
journal tail reflects what happened. Then append a synthetic phase to
`.talpi/plan.md` — `## Phase <n+1>: Acceptance fixes`, one `- [ ]`
step per piece of the human's feedback, and a `Contracts:` line naming
the contracts the feedback touches (usually none — those boundaries
were already pinned) — bump `phases_total` in `.talpi/state.md` to
match, set `current_phase` to the new phase, and run it through the
normal phase loop: fresh implementer subagents, one step one commit,
phase-end verification. Its steps get plan.md checkboxes, its start
journals a base hash, and a fresh session resumes it like any other
phase. When it lands, repeat Completion (smoke run through asking for
acceptance again) from step 1.

Nothing about completion is heavyweight: the boundaries were already
guarded by contracts through every phase, and internals were built to
stay cheap to change if acceptance surfaces something.
