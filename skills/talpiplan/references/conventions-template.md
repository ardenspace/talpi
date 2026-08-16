# Conventions

## Baseline (applies unless overridden)
<!-- Domain-neutral floor, proposed at the spec interview's Conventions
     lens. Keep what the human accepted; drop what they struck. The
     phase-end verifier cites these lines like any other rule.
     Simplicity zones named in the spec override this baseline where
     they apply — licensed hardcoding is not a finding. -->
- Repeated literals (colors, spacing, paths, magic numbers) live in one
  named home — design tokens or a constants module — never inlined in
  two places.
- Logic appearing a second time is extracted into the shared layer and
  registered under Shared Utilities below.
- User-visible failure wording follows one tone, defined in one place.
- A file growing past ~300 lines triggers a split review: look for
  separable concerns (components, pure helpers, shader/template
  sources). Staying single-file is a legitimate outcome — record why
  in one line under Layout & Naming; a recorded exception is not a
  finding. This is a review trigger, not a hard limit.

## Design Tokens
<!-- Colors, typography, spacing, and other visual constants used
     across the project. If the project has no visual surface, say so
     explicitly rather than leaving this blank. -->

## Shared Utilities
<!-- Functions, components, or modules available for reuse. Implementers
     register new utilities here as they create them during the build,
     so this section grows over the life of the run. -->

## Layout & Naming
<!-- File organization, naming conventions, and module structure
     implementers should follow. -->

## Failure Behavior
<!-- How errors are handled, logged, and reported; what the product's
     user sees when something goes wrong; what counts as a fatal vs.
     recoverable failure. -->
