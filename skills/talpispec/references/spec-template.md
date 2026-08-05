status: draft
# Spec: <project>

## Product Picture
<!-- Who this is for, what they do today without it; the core experience —
     the moment that must feel right; the smoke scenario — the one
     end-to-end path that proves it works. -->

## Requirements
<!-- Enumerated, each independently verifiable. -->

## Out of Scope (v1)
<!-- Explicit non-goals for this phase, to prevent scope creep. -->

## Simplicity Zones
<!-- Areas the human explicitly licenses the agent to keep deliberately
     simple, plain, or hardcoded — the anti-over-engineering permit. -->

## Boundary Contracts
<!-- One `### B<n>: <name>` subsection per external touchpoint or hardened
     internal module contract. Each written testably: request/response
     shapes, schema, file format, or CLI behavior — concrete enough that
     a failing test could be written from it alone. -->

### B1: <name>
<!-- What crosses this line, in testable form. -->

## Reversibility Ledger

### Decided (hard to change)
<!-- Decisions that would be costly to reverse — stack, schema, auth
     model, data ownership, deployment shape — discussed and decided
     with the human. -->

### Delegated (agent's discretion)
<!-- Easy-to-change areas explicitly named and handed to the agent; they
     stay out of the rest of the spec. -->
