---
name: talpirefactor
description: Use when pointing talpi at an existing codebase - the user wants a refactor run, .talpi/ has no approved spec, and the ask is restructuring code that already works. Brownfield twin of talpispec - a short intent conversation with the human, then a codebase recon that mines conventions and pins current behavior as contracts.
---

# talpirefactor

Turn "this code needs restructuring" into an approved `.talpi/spec.md`
that the unchanged downstream pipeline executes: talpiplan decomposes
it, talpirun builds it, the run review checks it — no new commands.
Where talpispec interviews a human about a product that doesn't exist
yet, talpirefactor has two interviewees: a short intent conversation
with the human, then a recon of the codebase itself — the code is the
second, and more talkative, interviewee.

The governing rule: **a refactor run preserves behavior.** The spec's
boundary contracts pin what the code observably does today; the run
restructures freely inside them. This is talpi's core mechanism —
harden the boundary, molt the interior — pointed at code that already
exists. If the human wants behavior changes too, carve them out
explicitly: those are a normal talpi run (or a later phase), never
smuggled into this one.

## Guard

Same as talpispec's guard: if `.talpi/spec.md` exists with `status:
approved`, do not start over — route to talpiplan (no approved plan) or
talpirun (plan approved). A `status: draft` spec resumes from where the
draft left off. Two brownfield additions:

- If the project has no meaningful existing code, this is the wrong
  skill — route to talpispec.
- If `.talpi/` holds a **done run** (`run_status: done`), this refactor
  is a new run over the same project. Confirm that with the human,
  then move the old `spec.md` and `plan.md` into
  `.talpi/archive/<ISO date>/` before writing anything new.
  `journal.md` stays in place and keeps appending — one history, many
  runs — and so does `.talpi/knowledge.md`, the distilled memory the
  previous run left (Act 2 below reads it). When the archive move
  lands, journal `refactor run started over done run` through the
  journal script
  (`sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-journal.sh" "..."`) — the
  status script fences its journal scan on that exact event, so the
  archived run's `run done` line stops routing the new run — and
  rewrite the snapshot:
  `sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-state.sh" speccing 0 0`.

## Act 1 — Intent Conversation

With the human, one question at a time, short — the codebase will
answer most questions better than they can. Three slots to fill:

1. **The itch** — what about this code hurts today, and why now? Pain
   is scope: a refactor without a felt itch is gold-plating.
2. **The target shape** — what does "better" look like, structurally?
   A direction, not a design ("module X should not know about Y",
   "this logic should live in one place") — the recon tests it against
   reality before the spec commits to it.
3. **The must-not-change seed** — public surfaces, on-disk formats,
   user-visible behavior the human already knows are untouchable. A
   seed only; the recon completes the list.

Also ask directly: is any behavior *change* riding along with this
refactor? If yes, move it to Out of Scope with a pointer to a future
run, and say so out loud — mixed runs lose the preservation guarantee
that makes autonomous refactoring safe.

When the slots are filled, propose moving to the recon and wait for
the human to agree.

## Act 2 — Codebase Recon

Dispatch three fresh-context recon subagents — no conversation
history — using `references/recon-prompt.md`, one per angle:

- **conventions** — mine the patterns the code actually follows, and
  where it contradicts itself.
- **boundaries** — inventory external touchpoints and internal seams,
  and for each observable behavior: pinned by an existing test, or
  unpinned?
- **hotspots** — map where the human's target shape requires change,
  and the minimal-change route to it.

Fresh contexts matter here for the same reason as everywhere in talpi:
a reader who shares the orchestrator's conversation inherits the
human's framing of the code, and the point of recon is to hear what
the code says even where it disagrees with the human.

If `.talpi/knowledge.md` exists (like journal.md, it survives across
runs and the archive move), fold it into the recon — implementation-
lane eyes only, never a reviewer's. Use each section as its type
demands: **Decisions** are constraints the target shape must respect —
carry the still-binding ones into the Reversibility Ledger, and leave
reopening any of them to the human. **Verified facts** are re-mining
skips, but only after the gate — run
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/talpi-knowledge.sh" check` and
`replay` first; a passing fact spares the recon re-deriving it, while
a failing or stale one is at most a question, never carried as truth.
**Open questions** are recon homework — hand each to the matching
recon angle so this run answers what the last one could not.

Synthesize the three reports and present them to the human before
writing any spec: the mined conventions (including self-
contradictions — each one is either a refactor candidate or a
conscious "leave it"), the unpinned behaviors that will need
characterization tests, and the minimal-change route with anything
that makes the target shape more expensive than the human assumed.
Recon findings adjust scope *with the human* — shrinking or splitting
the run here is cheap; discovering mid-run is not.

## Spec

Write `.talpi/spec.md` following talpispec's
`../talpispec/references/spec-template.md` — same section names, same
order, `status: draft` as the first line — with one addition: **line 2
is `mode: refactor`**. Downstream prompts (verifier, run reviewer,
smoke run) key off that line; without it the run gets greenfield
semantics. Sections reinterpret for brownfield, structure unchanged:

- **Product Picture** — current state, the itch, the target shape, and
  the **behavior walk**: the end-to-end paths (from recon plus Act 1)
  that must behave identically after the run. The behavior walk is the
  refactor run's smoke scenario.
- **Requirements** — enumerated restructuring outcomes, each
  independently verifiable ("X no longer imports Y", "every screen
  reads tokens from theme", "duplication Z collapsed to one utility").
- **Out of Scope** — the carved-out behavior changes, plus everything
  the itch doesn't justify touching.
- **Simplicity Zones** — imperfections the human explicitly licenses
  to survive the refactor. Not everything ugly is in scope.
- **Boundary Contracts** — the preservation contracts. Existing tests
  that already pin behavior are named as standing contracts;
  observable behaviors the recon found unpinned get characterization
  contracts, written testably, to be pinned before restructuring
  begins (talpirun's pin-first phase discipline does this naturally).
- **Reversibility Ledger** — *Decided* = the must-not-change surfaces
  (public APIs, schemas, formats, user-visible behavior). *Delegated*
  = internals licensed to be reshaped freely.
- **Conventions** — the mined conventions, recorded verbatim. Source
  of truth is the codebase, not invention — and never copied from
  knowledge.md: talpiplan drafts `.talpi/conventions.md` from this
  section, the verifier cites conventions.md, and inherited knowledge
  must not launder into that lane. This-run mining only.

Every spec item derived from knowledge.md carries an origin mark —
`(from knowledge.md)` — so the human sees at approval exactly which
parts of the spec ride on inherited knowledge; knowledge gains
execution authority only through that human gate.

## Panel Review

Identical machinery to talpispec, reused directly: dispatch the three
reviewers in `../talpispec/references/panel-reviewers.md`, each in a
fresh context with only the spec file path. Same finding grammar
(`[BLOCKING]` / `[NOTE]`), same re-run scoping and two-re-run cap,
same human overrule recorded in the Ledger. The lenses land naturally
on brownfield material: boundary completeness becomes "which
observable behavior is still unpinned", and the adversarial reviewer's
favorite question becomes "what user-visible behavior could this
restructuring silently change?"

## Approval

Identical mechanics to talpispec's Approval section — write the draft
(with `mode: refactor` intact), initialize `.talpi/state.md` if absent
(`run_status: speccing`, zeros, date), present with open `[NOTE]`s,
and wait for explicit approval. On approval: flip to `status:
approved`, rewrite state.md via the state script (`planning 0 0`),
journal `spec approved (refactor)` via the journal script — both as
talpispec's Approval does — and hand off to talpiplan. From
there the pipeline is the standard one — talpirefactor's job ended
when the code's own rules became the spec.
