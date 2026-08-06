# Changelog

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

## 0.1.0 — 2026-08-05
- Initial release: the 0→1 MVP pipeline.
- talpispec: two-act spec conversation (product talk, then scope /
  boundary / reversibility / conventions lenses) + 3-reviewer panel.
- talpiplan: phase decomposition + conventions draft; last mandatory
  human gate.
- talpirun: contracts-first autonomous build, one fresh verifier per
  phase, non-blocking phase reports, smoke run + human acceptance.
- talpiresume: disk-state routing; session-start hook.
