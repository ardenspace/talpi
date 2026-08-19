# Knowledge Distillation (v0.5.0) — Implementation Plan

Written: 2026-08-19, from a design conversation (three rounds of external-agent
review, holes patched each round). Status: **approved design, implementation
pending**.

## Problem

Every talpi run ends by discarding what it learned: `conventions.md`,
`handoff.md`, and the spec's Reversibility Ledger are all run-scoped. The next
run's recon re-mines the same codebase from scratch — a large repeated cost.

The naive fix (write down what was learned and hand it forward) is exactly what
the ornith-loopspace experiments showed to be dangerous: inherited knowledge
containing a wrong interpretation carries the blind spot into every later
session, regardless of model or tier. The dilemma: don't inherit → waste;
inherit → contamination.

## Resolution principle

**Inherit only knowledge that cannot lie.** Knowledge splits into three types
with different contamination profiles:

1. **Human decisions** — records of choice, not truth claims. Cannot be wrong.
2. **Machine-verifiable facts** — replaying them exposes any falsehood.
3. **Model interpretations** — no verification anchor; plausible-but-wrong
   inherits as truth. *This* is the contamination channel.

Types 1–2 persist. Type 3 may only survive as a **question** ("check whether
X…"), never a statement — questions are homework, not beliefs, and labels like
"unverified" do not defuse anchoring, so statement form is banned outright.

## Design (final, after three review rounds)

New file: **`.talpi/knowledge.md`** — the only file that survives across runs
besides `journal.md`. Three sections mirroring the three types:

- `## Decisions` — **verbatim quotes only** (both the decision line and its
  rationale), copied from the spec's Ledger or a journal line, with a source
  pointer. No model paraphrase: the check is string-equality against the
  original, so distortion dies mechanically. Prefer journal lines as targets —
  `journal.md` is the one file that never moves across runs.
- `## Verified facts` — **replayable commands only**: a command + expected
  outcome + `as of <hash>` + a scope note (which files/surfaces, descriptive
  scope only — semantic claims like "guarantees/pins X" are banned from the
  prose and belong in Questions). A dressed-up interpretation has no command to
  replay, so it cannot enter this section.
- `## Open questions` — the only afterlife for interpretations and for
  **negative knowledge** ("tried Z, failed") — provenance pointers allowed
  (commit hash, journal line), but phrased as questions, never as facts with a
  "medium trust" grade (a trust ladder's middle rung still anchors).

Write rule (talpirun Completion, on acceptance, before `run done`): the
orchestrator distills; the **replay gate** (script, not model) then re-runs
every Fact's command and string-checks every Decision quote — entries that fail
are dropped or demoted to Questions. Trust comes from the gate, not the
distiller — same trust architecture as implementers + contract tests.

Read rule (lane isolation): only the implementation lane (talpispec /
talpirefactor recon, implementers via the spec) ever reads knowledge.md.
Verifiers, run reviewers, and spec panels never see it — inherited blind spots
stay decorrelated from the verification lane. Two guards against laundering:

- knowledge.md is never merged into `conventions.md` (the verifier reads
  conventions.md); conventions.md only carries what *this run* mined/observed.
- When recon feeds a knowledge-derived item into the spec, it marks the origin,
  and the human approves the spec — knowledge gains execution authority only
  through that human gate.

Known residual risks (accepted): distiller *selection* quality (errors are
omissions/noise, not false beliefs); scope-note overclaim (bounded — but note
verifiers are spec-anchored, so a spec blind spot blinds the verification lane
too; the human spec gate is the real backstop); question framing as weak
anchoring; file growth (curation); human decisions going stale (dated entries,
human-only reopening).

## Mechanization touchpoints

- **`scripts/talpi-knowledge.sh`** (new):
  - `check [root]` — read-only. Validates structure; provenance is
    **content-addressed**: each Decision's verbatim quote must exist in
    `spec.md`, `archive/*/spec.md`, or `journal.md` (path is a hint, not an
    address — survives talpirefactor's archive move, whose `<ISO date>` dir
    name is unknowable at distillation time). Flags Facts whose `scope` files
    changed since their `as of` hash: `stale — demote to question`.
  - `replay [root]` — runs every Fact's command; reports pass/fail per entry.
    The write-time gate; recon may also replay before trusting.
- **`scripts/talpi-journal.sh`** — append-only becomes a mechanical guarantee:
  before appending, verify the committed (HEAD) journal is a byte-prefix of the
  working copy; refuse to append onto a tampered journal. journal.md is now a
  provenance store — line immutability is the load-bearing wall under every
  verbatim check.
- **`scripts/talpi-status.sh`** — surface journal tampering as a `warning:`.

## Steps

- [ ] 1. `docs/state-format.md`: define `.talpi/knowledge.md` (sections, entry
  grammar, write/read/isolation rules, archive interaction) + journal
  append-only guarantee note + script contract updates.
- [ ] 2. `scripts/talpi-knowledge.sh` (`check` / `replay`) + append-only guard
  in `talpi-journal.sh` + tamper warning in `talpi-status.sh`.
- [ ] 3. `scripts/test/knowledge.test.sh`: entry-grammar fixtures; content-
  addressed provenance incl. archive path; replay gate (passing + failing
  command fixtures); staleness demotion flag; journal tamper refusal (git
  fixture); isolation greps (verifier/reviewer prompts and their dispatch
  instructions never reference knowledge.md; conventions-laundering rule
  present in skills).
- [ ] 4. `skills/talpirun/SKILL.md`: distillation step in Completion's
  acceptance branch (distill → gate → drop/demote → journal `knowledge
  distilled`); explicit prohibition on passing knowledge.md into any
  verifier/reviewer dispatch.
- [ ] 5. `skills/talpirefactor/SKILL.md` + `skills/talpispec/SKILL.md`: recon
  reads knowledge.md when present — Decisions as constraints, gate-passing
  Facts as re-mining skips, Questions as homework; origin-marking rule for
  knowledge-derived spec items; conventions.md stays this-run-only.
- [ ] 6. CHANGELOG 0.5.0, version bump, full suite green, fixture smoke of the
  whole loop (distill → archive move → next-run check still passes).
