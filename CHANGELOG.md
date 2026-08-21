# Changelog

## 0.6.1 — 2026-08-21
Prose-only fix for a stall that only ever showed on one channel: with a
chat integration attached, phase reports go out as a tool call and the
run continues by itself; in a plain terminal the report *is* the
session's final text, so the turn ended at every phase boundary and the
build sat there until the human typed "continue". The
plan-approved-then-autonomous promise was, in effect, conditional on
having a notifier configured.
- **A phase report may not end the turn** (talpirun, Phase report):
  "continue immediately" is now stated as a rule about the session's
  turn, not just its intent — emit the report, then journal, rewrite
  state, and dispatch the next phase's first step in the same turn.
  The only turns talpirun may end are the stops the skill names: a
  blocking escalation's halt, and the final report awaiting
  acceptance.
- **Completion bookkeeping shares the report's turn** (talpirun,
  Completion step 4): the same trap cost real state on the terminal
  channel — a final report that ended the turn left `final report
  sent, awaiting acceptance` unjournaled and handoff.md still
  describing mid-phase work.

## 0.6.0 — 2026-08-21
From the second nanpaseom dogfood retrospective — multi-run routing
becomes real, and the last hand-formatted state writes disappear.
- **Multi-run journal routing** (talpi-status.sh): the scan is now
  fenced at the last run-start marker (`run started over done run` /
  `refactor run started over done run`) — an archived run's `run
  done`, `run halted:`, and completion-tail events can no longer route
  the current run. Previously even talpirefactor's documented
  archive-over-done-run flow left status reporting "done — nothing to
  build". Pinned by four new status.test.sh fixtures.
- **New-run-over-done-run procedure in talpispec** (guard): the
  archive move (`spec.md`/`plan.md` → `.talpi/archive/<ISO date>/`,
  journal and knowledge stay), previously written down only for
  talpirefactor, now exists for greenfield re-runs too — human
  confirmation first, then the `run started over done run` journal
  marker the status fence keys on.
- **Every stage writes state through the scripts**: talpispec,
  talpiplan, and talpirefactor now journal and rewrite state.md via
  talpi-journal.sh / talpi-state.sh like talpirun always did — no more
  hand-formatted journal lines with drifting date formats.
- **Implementer dispatch template** (talpirun,
  `references/implementer-prompt.md`): the standing rules an
  implementer must receive — the question rule and the
  contract-dispute license with its canonical first-line form
  (`CONTRACT DISPUTE: <contract id> — <one sentence>`) — now travel in
  the template, so no implementer is dispatched without them and the
  orchestrator can route a dispute off the reply's first line.
- **Smoke-run reuse license, mechanical** (talpirun Completion): a
  final-phase real walk journaled as `smoke walked (at: <hash>)` may
  stand in for the completion smoke iff `git diff --name-only
  <hash>..HEAD -- . ':(exclude).talpi'` prints only `*.md` paths — the
  diff decides, never the session's judgment.
- **Commit-message convention yields to the repo's** (talpirun): the
  `talpi: phase <n> step <k>:` form is now an explicit default —
  a repo's own commit convention, recorded in conventions.md, wins.
  The non-negotiable part is named: code + plan.md tick in one commit.
- **Reviewer diffs exclude `.talpi/`** (verifier and run-reviewer
  prompts): plan ticks and journal lines are bookkeeping, not review
  material; the `.talpi/` files stay readable as context.
- **Panel `[NOTE]` folding license** (talpispec): self-evident
  one-line notes may fold straight into the spec (through the
  self-consistency pass); judgment calls are still listed, and the
  approval presentation discloses the folded count.
- **Knowledge-gate semantics stated where distillation happens**
  (talpirun): Decision quotes are content-addressed (archive
  tolerance is by design, `source:` is never trusted), Open questions
  get only the form check because nothing trusts them, executable
  trust comes from `replay` alone.

## 0.5.1 — 2026-08-20
Prose-only release from the nanpaseom dogfood run's retrospectives —
no new scripts, files, or state; per-run token cost goes down, not up.
- **Contract disputes are first-class** (talpirun): an implementer who
  believes a pinned contract is itself wrong says so and stops instead
  of contorting internals until the test passes — "implementation
  violates contract" is the implementer's to fix, "contract is wrong"
  is only ever the human's. The orchestrator journals `phase <n>
  contract dispute: <summary>` and halts through the existing
  blocking-escalation path (ratify amends the contract test and spec;
  reject upholds the contract). The phase verifier now also escalates
  when an implementation visibly contorted to satisfy a wrong
  contract.
- **Self-consistency pass before panel re-runs** (talpispec): after
  applying a round's resolutions, the orchestrator re-reads the spec
  for contradictions the edits themselves introduced, before
  dispatching any re-run — in the nanpaseom run, 3 of 10 BLOCKINGs
  were self-inflicted by round-1 spec edits, costing a full
  three-reviewer round.
- **Environment facts recorded once** (talpirun): port assignments,
  do-not-kill services, and other machine quirks go into
  conventions.md when the run's first dispatch is prepared, instead of
  being repeated ad hoc in every dispatch prompt — conventions.md is
  already inlined into each dispatch.

## 0.5.0 — 2026-08-19
- **Knowledge distillation: runs stop forgetting, without inheriting
  lies.** New file `.talpi/knowledge.md` — with journal.md, the only
  file that survives across runs (a new run's archive move leaves both
  in place). Written by talpirun at completion, on acceptance, before
  `run done`. The design rule: inherit only knowledge that cannot lie —
  - `## Decisions` — verbatim quotes of human decisions (plus their
    rationale), string-checked against the original; no paraphrase
    survives. Provenance is content-addressed (spec.md,
    archive/*/spec.md, journal.md), so entries survive a later run's
    archive move; the `source:` field is a hint, never trusted.
  - `## Verified facts` — replayable commands only (command + expected
    output + `as of <hash>` + descriptive scope). An interpretation has
    no command to replay, so it cannot enter this section.
  - `## Open questions` — the only afterlife for interpretations and
    negative knowledge; question form is mechanically enforced.
- New script `scripts/talpi-knowledge.sh` — the trust gate: `check`
  validates structure/grammar, resolves quotes content-addressed, and
  flags facts whose scope changed since their hash (`stale — demote to
  question`); `replay` re-runs every fact's command. talpirun runs both
  at distillation and drops or demotes what fails — trust comes from
  the gate, not the distiller.
- **journal.md append-only is now mechanical**: talpi-journal.sh
  refuses to append when the committed (HEAD) journal is not a
  byte-prefix of the working copy, and talpi-status.sh surfaces the
  same tampering as a `warning:` — journal lines are the provenance
  store under every verbatim check.
- **Lane isolation**: only the implementation lane (talpispec /
  talpirefactor recon, implementers via the spec) reads knowledge.md.
  Verifier and reviewer dispatches never receive it, knowledge is
  never merged into conventions.md, and recon marks knowledge-derived
  spec items `(from knowledge.md)` so inherited knowledge gains
  execution authority only through the human spec gate. Recon reads by
  type: Decisions as standing constraints, gate-passing facts as
  re-mining skips, questions as homework.
- All of it pinned by `scripts/test/knowledge.test.sh`: grammar and
  provenance fixtures (including the archive move), the replay gate,
  staleness demotion, journal tamper refusal on a git fixture, and
  isolation greps over prompts and skill prose.

## 0.4.1 — 2026-08-19
- **Session-start hook injects a position snapshot.** The hook now runs
  `talpi-status.sh` and includes its full output — run_status, phase
  counters, warnings, and the `next:` line — so a fresh session starts
  oriented even before any skill is invoked. Guardrails against the
  known failure modes: the snapshot is framed as orientation ("not an
  instruction to act on directly"), the talpiresume pointer stays (the
  skill restores handoff/conventions context and the halted path,
  which the snapshot does not carry), authority stays with the skill's
  own later script run, and if the status script is unavailable the
  hook falls back to the previous plain pointer. Behavior pinned in
  manifest.test.sh.

## 0.4.0 — 2026-08-19
- **The state machine moved from prose to scripts.** talpirun's Guard
  and talpiresume's conflict rule were a decision table encoded in
  skill prose ("if the journal tail is X, do Y") — every re-entry
  relied on a session parsing journal lines correctly, and the odds of
  a misread accumulate over long autonomous runs. Three scripts now
  mechanize it, turning rule-following from instruction adherence into
  tool calls:
  - `scripts/talpi-status.sh` — read-only; applies journal-over-state
    precedence and the full guard/resume decision table, prints the
    run's position and exactly one `next:` action (plus `warning:`
    lines when state.md contradicts the journal). The table lives
    only here — skills route on its output and no longer restate it,
    so there is no second copy to drift.
  - `scripts/talpi-journal.sh` — the only sanctioned journal writer;
    stamps the canonical `- [<ISO date>] <event>` line.
  - `scripts/talpi-state.sh` — the only sanctioned state.md writer;
    validates the run_status vocabulary, writes all four keys, stamps
    `updated`.
  The decision table's behavior is pinned by
  `scripts/test/status.test.sh` (fixture runs for every route: spec
  draft, planning, mid-phase, completion re-entry with narrowed diff,
  awaiting acceptance, declined, halt/resume, journal-wins conflicts).
  docs/state-format.md documents the script contract.

## 0.3.4 — 2026-08-16
- Three decisions from the practice-3d dogfood run
  (docs/plans/2026-08-16-dogfood-feedback-practice-3d.md):
  - **Size pressure inside delegated zones**: the conventions baseline
    gains a fourth rule — a file growing past ~300 lines triggers a
    split review; staying single-file is legitimate when recorded in
    one line under Layout & Naming. A review trigger, not a hard
    limit; the phase-end verifier covers it through the existing
    conventions check, no prompt change.
  - **Eye-verified zones get an explicit deliverable**: when a phase
    builds or reshapes a surface the spec leaves to eye verification,
    talpirun appends concrete check items to `.talpi/manual-check.md`
    before the phase report, and final acceptance is asked *with* the
    checklist — the human walking it is that zone's verification
    story. Ratifies behavior a live run invented on its own.
  - **Panel shape proportional to spec surface**: talpispec reads the
    panel's shape off the draft — a thin surface (few contracts, no
    schema/auth/data-ownership ledger material, no secrets/PII/
    multi-user) runs the three lenses as one fresh reviewer with a
    re-run cap of one. Discarding the thin classification — by a
    contradicting finding or by the human asking for the full panel
    at approval — re-enters the thick path at its start: one unscoped
    three-reviewer run (adjudicated findings preserved at collection
    against the ledger, never via the prompts), then scoped re-runs
    capped at two; discard happens at most once.

## 0.3.3 — 2026-08-16
- Per-step overhead cuts, from dogfooding a live run:
  - The step tripwire prefers typecheck or build, falls back to the
    test command only when nothing cheaper exists, and never re-runs
    a full suite the implementer already ran — correctness stays
    phase-end verification's job.
  - talpiplan gains a third self-check on step granularity: a step
    whose real work is a minute or two merges into a cohesive
    adjacent step; unrelated chores stay separate, since
    one-step-one-commit is also the recovery granularity.
  - talpirun's dispatch context (conventions, the phase's contracts,
    the step description) is explicitly inlined in the subagent
    prompt rather than passed as paths, sparing each fresh subagent
    its discovery tool calls.

## 0.3.2 — 2026-08-16
- Baseline precedence made explicit: simplicity zones named in the
  spec override the conventions baseline where they apply — licensed
  hardcoding is never a verifier finding.
- Test fix: skills.test.sh now resolves cross-skill
  `../<skill>/references/*.md` mentions (introduced by talpirefactor
  in 0.3.0) instead of flagging them as missing local files.

## 0.3.1 — 2026-08-16
- Conventions get a **baseline floor**: the Conventions lens now opens
  by proposing three domain-neutral form rules (repeated literals live
  in one named home; logic appearing twice is extracted and registered;
  one failure-wording tone), which the human can adjust or strike.
  Whatever survives lands in a new `## Baseline` section of
  `.talpi/conventions.md` — so the phase-end verifier always has
  concrete lines to cite against hardcoding and duplication, even when
  the human answers the lens thinly. Form rules only, never solutions;
  internals stay the agent's.

## 0.3.0 — 2026-08-10
- New skill **`talpirefactor`** — brownfield entry point for
  behavior-preserving refactor runs. A short intent conversation
  (itch, target shape, must-not-change seed), then a three-angle
  codebase recon by fresh subagents (mined conventions with
  contradictions, pinned/unpinned observable behavior, hotspot map
  with a minimal-change route), synthesized into the standard spec
  template with `mode: refactor` on line 2. Existing tests become
  standing contracts; unpinned behaviors get characterization
  contracts pinned first by talpirun's normal phase discipline. Panel
  review, approval, talpiplan, and talpirun are reused unchanged.
- Refactor-aware prompts: the phase verifier gains three brownfield
  checks (behavior preservation, mined-convention adherence, scope
  discipline) and the run reviewer walks the spec's behavior walk;
  talpirun's smoke run reads the behavior walk as the smoke scenario
  on `mode: refactor` runs.
- Routing: talpispec, talpiplan, and talpiresume know when to point at
  talpirefactor; a refactor run over a `done` run archives the old
  spec/plan to `.talpi/archive/<date>/` and keeps journal.md
  appending.

## 0.2.2 — 2026-08-10
- Completion gains a **run review** stage between the smoke run and
  the final report: one fresh-context reviewer over the whole run's
  diff, checking what per-phase verifiers structurally cannot see —
  contract interactions, an end-to-end spec sweep, and leftovers no
  phase owned (unused deps, dead files, convention drift). `[FIX]`
  findings reuse the smoke-break fix machinery; `[NOTE]` findings are
  carried into the final report for the human's acceptance ruling;
  `[ESCALATE]` follows the existing Decided-list halt rules. Repeat
  completions narrow the review to commits after the last reviewed
  hash, and the guard understands the new
  `run review (through <hash>)` journal tail.

## 0.2.1 — 2026-08-09
- Acceptance rejection now appends a synthetic `Acceptance fixes`
  phase to plan.md (steps get checkboxes, a journaled base hash, and
  phase-end verification) and bumps `phases_total`, instead of running
  fix steps outside the phase machinery.
- talpirun guard: arriving from talpiresume with a human ruling on a
  halt no longer bounces back to talpiresume — the ruling is executed
  directly.
- Phase loop: step acceptance now includes a mechanical tripwire
  (build/typecheck/test before each step commit — no review ceremony);
  every step's created files are carried to later subagents via a
  `Prior work this phase` block in conventions.md; journal lines a
  step produces ride in that step's commit, with commits as ground
  truth for step completion.
- Session-start hook announces `done` runs (routing talpiresume to a
  no-work-remains confirmation) instead of staying silent — a silent
  hook meant fresh sessions could restart the pipeline unaware.
- talpiresume documents that `current_phase` past `phases_total` is
  talpirun's normal completion convention, not a contradiction.
- Docs no longer claim the hook "routes automatically" — it injects
  guidance the session follows.
- talpiplan: early-pull self-check (surface-sweeping contracts pull
  later phases' stubs into the pinning phase; later steps say
  finish/verify, not implement). Verifier prompt: seam-bypass check
  (when contracts verify only through a test seam, read the real
  default path the seam bypasses).
- Reviewer panel re-runs after BLOCKING fixes are scoped and capped,
  with an overrule path; last-phase report branch and contracts-less
  phase journal event fixed.

## 0.2.0 — 2026-08-06
- Commit discipline: one commit per step (`talpi: phase <n> step <k>:
  ...`), ticking the step's plan.md checkbox in the same commit; phase
  start journals its base hash, giving the phase-end verifier a real
  `<base>..HEAD` diff range.
- Terminology: work units are now "steps" (was "tasks"), avoiding
  collision with the harness's Task/subagent naming; guarded by a new
  skills.test.sh vocabulary check.
- talpiresume: mid-phase position now reconstructed from plan.md
  checkboxes; uncommitted working-tree changes are handed to the
  in-flight step's implementer instead of discarded.
- talpirun guard: `current_phase == phases_total` is recognized as
  normal last-phase building (was mislabeled as "should be done"), and
  a died-before-completion resume now routes straight to Completion.
- Skills no longer reference repo-relative `docs/` paths (unresolvable
  inside a target project); the journal line format is stated inline
  where skills append events. Both guarded by new contract tests.
- Session-start hook: resolves the project root via
  `CLAUDE_PROJECT_DIR` (detects `.talpi/` when the session opens in a
  subdirectory) and stays quiet once a run is `done` instead of
  nagging every future session; behavior covered by contract tests.

## 0.1.0 — 2026-08-05
- Initial release: the 0→1 MVP pipeline.
- talpispec: two-act spec conversation (product talk, then scope /
  boundary / reversibility / conventions lenses) + 3-reviewer panel.
- talpiplan: phase decomposition + conventions draft; last mandatory
  human gate.
- talpirun: contracts-first autonomous build, one fresh verifier per
  phase, non-blocking phase reports, smoke run + human acceptance.
- talpiresume: disk-state routing; session-start hook.
