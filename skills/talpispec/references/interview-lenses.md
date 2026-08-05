# Act 2 Interview Lenses

Work through these four lenses in order: Scope, Boundary, Reversibility,
Conventions. One at a time, skip answered, follow the thread.

## Scope Lens
- What is the minimal MVP — the smallest version you would actually use?
- What is explicitly out of scope for v1?
- Which areas are simplicity zones — places you license the agent to keep
  deliberately simple, plain, or hardcoded? (This is the anti-over-
  engineering permit; record them in the spec.)

## Boundary Lens (talpi signature)
- Let's enumerate every external touchpoint: HTTP APIs? Database schemas?
  File formats read or written? CLI surfaces? Third-party services?
- For each touchpoint: what crosses this line? Any secrets, credentials,
  or personal data? (Security lives here, per boundary — never as an
  abstract questionnaire.)
- Which few internal module contracts are worth hardening — seams where
  two parts of the system will evolve independently?
- For each boundary: what exact shape is the contract? (Request/response,
  schema, format — testable form.)

## Reversibility Lens (talpi signature)
- Which decisions in this project will be hard to change later? (Stack,
  schema, auth model, data ownership, deployment shape.)
- For each hard one: decide it now, together. For everything else: name
  it and delegate it — "internal X is the agent's call" goes in the
  ledger so delegation is explicit, and it stays out of the spec.

## Conventions Lens
- Is there a design theme — tokens, colors, spacing — that everything
  should draw from?
- What kinds of logic should always be extracted into shared utilities?
- Any layout or naming rules the codebase should follow?
- When something fails, what should the product's user see?
