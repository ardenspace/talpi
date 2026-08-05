# Talpi — Design Document

**Date:** 2026-08-05
**Status:** Draft — pending author review
**Name:** *talpi* (탈피, Korean for "molting") — a crustacean grows soft inside a
hard shell, then sheds and rebuilds it. Talpi hardens the shell (external
boundaries) with contracts and lets the interior grow — and be refactored —
freely.

## 1. Why talpi exists

Talpi is a complete, self-contained development pipeline for Claude Code —
one plugin that takes a project from idea to shipped MVP and beyond. It is
the synthesis of lessons from two predecessor plugins built by the author:

- **loopspace** (autonomous spec-driven loop): verification was applied
  uniformly to every task — verifier panels, multi-lens reviews per task.
  Result: heavy token cost and over-engineered code. Lesson: *do not
  intervene much while code is being written.*
- **pslog-workflow** (human-approval workflow): light and fast, but with no
  testing discipline at all — nothing protected the code from regressions.
  Lesson: *some things must be verified.* (Its dashboard visibility was
  loved; chat-based reporting replaces it here.)
- **Both**: the real time sink in every project came *after* the MVP —
  maintenance and refactoring. And both handled context exhaustion poorly
  (manual `/clear`, ad-hoc handoffs).

## 2. Core philosophy

> **Quality is measured by one question: how hard is this decision to change
> later?**

- **Hard-to-change decisions** (external boundaries, schemas, public APIs,
  stack choices) are designed carefully with the human, up front, and
  protected thickly with contract tests.
- **Easy-to-change decisions** (internal implementation) are explicitly
  delegated to the agent: built fast, thin, with minimal verification.
  They only need to remain *refactorable*.
- **The verification budget is spent at the boundaries**, not spread
  uniformly. This is what keeps the MVP both fast and solid, and what makes
  post-MVP maintenance cheap.
- **Spec thickness is proportional to boundary surface.** The spec stays
  silent about internals; a spec that starts specifying internals is itself
  a signal of over-engineering.

## 3. Pipeline overview

```
1. SPEC    Act 1: product conversation (divergent, freeform)
           Act 2: design interview (convergent, 4 lenses)
           Spec review panel (3 fresh-session reviewers)
           → HUMAN APPROVAL (required)
2. PLAN    Phase decomposition + CONVENTIONS.md draft
           → HUMAN APPROVAL (required — last mandatory human gate)
3. BUILD   Autonomous. Per phase: pin boundary contracts as tests first,
           then implement freely inside them. No per-task verification.
4. VERIFY  At each phase end: one fresh-session independent verifier.
           Fix what's fixable; escalate the rest. Reports are
           non-blocking — except violations of Decided (hard-to-change)
           decisions, which halt the run for the human.
5. DONE    All contract tests green + smoke run + human acceptance.
```

### 3.1 Spec stage — two acts

**Act 1 — Product conversation (divergent).** Starts from "what do you want
to build?" and stays in the user's world: what should the *product's users*
experience, which moment is the core of it. No lens interrogation — a
natural conversation (the agent follows the thread, one question at a
time). The *process* is at the agent's discretion; the *output* is fixed.
Act 1 is done only when these slots are filled:

- Who is this for, and what do they do today without it?
- The core experience — the moment that must feel right.
- The smoke scenario — the one end-to-end path that will define "it works."

When the slots are filled the agent proposes moving to Act 2; the human
agrees or keeps talking.

**Act 2 — Design interview (convergent).** Four lenses, asked one question
at a time, skipping anything already answered. Questions reference Act 1
concretely ("that core flow — does it need to work offline?").

1. **Scope** — the minimal MVP line; explicit v1 exclusions; and
   **simplicity zones**: areas the human explicitly licenses the agent to
   keep simple (the anti-over-engineering permit).
2. **Boundary ★** — enumerate every external touchpoint: HTTP APIs, DB
   schemas, file formats, CLI surfaces, third-party services. Select the
   few internal module contracts worth hardening. Security is asked *here,
   per boundary* ("what crosses this line? any secrets/PII?") — never as an
   abstract questionnaire.
3. **Reversibility ★** — which decisions in this project are hard to change
   later (stack, schema, auth model, data ownership, deployment shape)?
   Hard ones get discussed and decided now, with the human. Easy ones are
   *explicitly delegated* to the agent and stay out of the spec.
4. **Conventions** — design tokens/theme, shared-utility policy ("this kind
   of logic gets extracted globally"), naming/layout rules, user-visible
   failure behavior. Seeds `.talpi/conventions.md`.

★ = talpi's signature lenses.

**Spec review panel.** Three fresh-session reviewers read the draft spec
before human approval:

- **Adversarial** — contradictory requirements, undefined edge cases,
  security holes, *and over-specification* (anything specified more
  elaborately than its requirement justifies → blocking).
- **Boundary completeness** — predicts external touchpoints that will
  surface mid-build but aren't in the spec; checks every contract is
  written in a testable form.
- **Reversibility audit** — finds hard-to-change decisions hiding in the
  spec that were never discussed with the human.

Findings are `[BLOCKING]` or `[NOTE]`; only blocking findings return to the
interview. Then the human approves the spec.

### 3.2 Spec artifact

The spec contains, at minimum:

- Product picture (Act 1 output: who / core experience / smoke scenario)
- Requirements + v1 exclusions + simplicity zones
- **Boundary contracts** — each external touchpoint and selected module
  contract, written testably (request/response shapes, schema, file format,
  CLI behavior)
- **Reversibility ledger** — hard-to-change decisions *decided*; easy-to-
  change areas *delegated* (listed by name so delegation is explicit)

### 3.3 Plan stage

Phase decomposition (phases are meaningful product increments, not task
lists), plus the first draft of `.talpi/conventions.md`. Human approves both.
This is the **last mandatory human gate** — everything after runs
autonomously until final acceptance.

### 3.4 Build stage

- **Contracts first.** At the start of each phase, the agent pins that
  phase's boundary contracts as tests — then implements freely inside them.
- **Task-unit subagents.** The build session is a thin orchestrator — it
  manages state, dispatches, and reports; it never implements inline.
  Each task (contract pinning is the first task of every phase) goes to a
  fresh implementer subagent that reads `.talpi/conventions.md`, the
  phase's contracts, and its task description — no conversation history.
  This keeps the orchestrator's context lean for long runs, and forces
  disk state to be the real continuity mechanism on every single task.
  A subagent's questions come back as results; the orchestrator relays
  them to the human under the routing rule below.
- **No per-task verification.** No reviewer panels, no per-task test
  ceremony. The contract tests are the safety net.
- **Internal decisions are the agent's.** Only *product-external* questions
  (anything a user of the product would notice; anything touching a
  boundary or the reversibility ledger) go to the human — via chat,
  non-blocking where possible.
- **CONVENTIONS.md is a living document.** New shared utilities get
  registered in it; each phase's implementer reads it first and reuses.
  It doubles as cross-session continuity: a fresh session inherits the
  conventions by reading one file.

### 3.5 Phase-end verification

One **fresh-session independent verifier** per phase (empirically, a clean
session reviews far better than the implementer reviewing itself). Its
lenses mirror the philosophy:

1. **Contract adherence** — implementation matches the boundary contracts;
   the contract tests genuinely guard the boundaries (not hollowed out).
2. **Smuggled irreversible decisions** — schema changes, new external
   dependencies, API shape changes that never went through the human →
   escalate to the human in the phase report.
3. **Conventions & duplication** — violations of `.talpi/conventions.md`,
   copy-pasted logic that should use the shared layer, hardcoded values
   the theme should own. *No taste-based style comments* — every finding
   must cite the conventions doc or a contract. Internals otherwise pass
   if refactorability is intact.

**Escalations are two-tier.** A finding that alters an entry on the
Reversibility Ledger's **Decided** list is blocking: the run halts
(`run_status: halted`, reason journaled) and the report asks the human to
rule. If the human ratifies the change, the ledger and spec are updated and
the run continues; if they reject it, the agent reverts the decision first,
a fresh-session verifier re-checks the revert, and only then does the run
continue. All other escalations are non-blocking.

The agent fixes what it can, then sends a **phase report** (chat): what
shipped, verifier findings, anything escalated. Unless halted, the run
continues to the next phase; the human interjects only if they want to.

### 3.6 Completion

- All boundary contract tests green (mechanical).
- **Smoke run** — the agent actually launches the product and walks the
  spec's smoke scenario ("does it really run", not a test file).
- **Human acceptance** — the human tries it; their OK is the final gate.

No heavyweight final verification panel — the boundaries are already
guarded by contracts, and internals were designed to be cheap to change.

## 4. Session & state infrastructure

- **State lives on disk, in Markdown, and is the single source of truth.**
  Design assumption: *any session can die at any moment.* State directory:
  `.talpi/` in the target project (spec, plan, state, journal, handoff).
- **Context is self-served; only restarts involve the human.** A live
  session never runs out of road: the harness auto-compacts, and a
  session-start hook re-routes a compacted or fresh session back into the
  pipeline — context exhaustion never summons the human. Every *semantic*
  stop (phase report, halt, completion) is reported to chat and includes
  the one-line resume command. If a session dies outright (crash, closed
  terminal, reboot), nothing is lost — state is always on disk; the human
  restarts with one command and the hook resumes from the right point.
  There is no supervisor process; a long silence in chat is itself the
  signal that the session died.
- **Visibility is the chat itself** (terminal or Telegram). No dashboard —
  phase reports and on-demand status questions cover it. State files are
  written human-readable so a dashboard *could* be layered on later, but
  none is planned.

## 5. Scope

- **v1: the 0→1 MVP pipeline** described above, as a Claude Code plugin
  (skills + state conventions).
- **Full-lifecycle is the goal**: feature-addition and refactoring
  workflows (mini-spec: "does this touch a boundary? if yes, discuss;
  if no, go fast") come after v1 — built *with* talpi v1 on talpi itself
  (dogfooding).
- **Non-goals for v1**: dashboard, multi-harness portability, multi-user
  features, supervisor process (manual one-command restart instead),
  feature/refactor workflows (v2, dogfooded).

## 6. Language

All code, documentation, skill prose, and artifacts are written in
**English** — talpi is for developers everywhere. (Conversations with the
human follow the human's language, as always.)
