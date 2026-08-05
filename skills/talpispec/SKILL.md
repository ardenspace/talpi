---
name: talpispec
description: Use when starting a new talpi project, when the user has a product idea that needs to become a spec, or when .talpi/ has no approved spec yet. First step of the talpi pipeline — a two-act conversation, not a questionnaire.
---

# talpispec

Turn a product idea into an approved `.talpi/spec.md` through a two-act
conversation: a freeform product conversation, then a structured design
interview, then a fresh-context review panel, then human approval. The
spec stays thick at boundaries and silent about internals — spec
thickness is proportional to boundary surface, not project size.

## Guard

Before starting, check `.talpi/spec.md`. If it exists and its first line
is `status: approved`, do not start a new conversation. Report that a
spec already exists and route to talpiplan (if no plan yet) or talpirun
(if a plan is already approved) instead. If `.talpi/spec.md` exists with
`status: draft`, resume Act 2 or the panel from where the draft left off
rather than starting over.

## Act 1 — Product Conversation

Start from "what do you want to build?" and stay entirely in the user's
world. Ask about what the *product's users* will experience, not about
implementation. One question at a time — a natural conversation, not a
form. Never ask a technical question here (no stack, no schema, no API
shape); that belongs to Act 2.

The process is at your discretion — follow the thread, ask what makes
sense next. The output is fixed: Act 1 is done only when you can fill
these three slots from what the human has told you:

1. Who this is for, and what they do today without it.
2. The core experience — the moment that must feel right.
3. The smoke scenario — the one end-to-end path that will define "it
   works."

When all three slots are filled, do not silently move on. Propose moving
to Act 2 explicitly, and wait for the human to agree. If they keep
talking, keep listening — the slots are a floor, not a stopwatch.

## Act 2 — Design Interview

Work through `references/interview-lenses.md` in order: Scope, Boundary,
Reversibility, Conventions. Within each lens, ask one question at a time.
Skip any question the human has already answered — in Act 1, earlier in
Act 2, or anywhere else in the conversation. Reference Act 1 concretely
when you ask ("that core flow — does it need to work offline?"); do not
ask in the abstract.

Boundary and Reversibility are talpi's signature lenses — do not rush
them. Spend the most words there. Security questions belong inside the
Boundary lens, per touchpoint ("what crosses this line? any secrets or
personal data?") — never as a separate, abstract security questionnaire.

Keep the spec's thickness proportional to its boundary surface: the more
external touchpoints and hardened module contracts a project has, the
more the spec should say about them. The spec stays silent about
internals — if you find yourself specifying *how* something is
implemented rather than *what* crosses a boundary or what would be hard
to reverse, that's a sign to stop and delegate it instead (Reversibility
lens, "Delegated" list).

## Panel Review

Once Act 2 is complete, write the draft to `.talpi/spec.md` (see
Approval below for the exact procedure) and dispatch the three reviewers
in `references/panel-reviewers.md`: the adversarial reviewer, the
boundary-completeness reviewer, and the reversibility auditor. Each
reviewer runs in a fresh context — no conversation history, only the
spec file path. This matters: a reviewer that shares your context will
share your blind spots.

Collect findings from all three. Each finding is `[BLOCKING]` or
`[NOTE]`:

- `[BLOCKING]` findings go back into the interview. Re-open the relevant
  lens with the human, resolve the finding, update the spec, and re-run
  the panel before proceeding to Approval.
- `[NOTE]` findings do not gate approval. List them for the human when
  you present the spec for approval, so they can act on any of them if
  they choose.

Do not proceed to Approval while any `[BLOCKING]` finding is
unresolved.

## Approval

Write `.talpi/spec.md` following `references/spec-template.md` exactly —
same section names, same order, `status: draft` as the first line. Fill
in every section from the Act 1 and Act 2 conversation; do not leave
template hint comments in the final file. This includes the Conventions
lens's answers, recorded verbatim in the spec's `## Conventions`
section — so a session death after approval loses nothing.

The first time this draft is written, also initialize `.talpi/state.md`
if it does not already exist, with all four keys `docs/state-format.md`
defines — partial writes are invalid:

```
run_status: speccing
current_phase: 0
phases_total: 0
updated: <ISO date>
```

Present the spec to the human (including any open `[NOTE]` findings) and
ask them to approve it. Do not proceed on silence or an ambiguous
response — wait for an explicit approval.

On approval:

1. Change the first line of `.talpi/spec.md` from `status: draft` to
   `status: approved`.
2. Rewrite `.talpi/state.md` in full, all four keys: `run_status:
   planning`, `current_phase: 0`, `phases_total: 0`, `updated: <ISO
   date>`.
3. Append an event to `.talpi/journal.md` recording that the spec was
   approved.
4. Hand off to the talpiplan skill.
