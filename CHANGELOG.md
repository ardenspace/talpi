# Changelog

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
