# Changelog

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
