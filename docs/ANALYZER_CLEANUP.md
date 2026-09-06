# Analyzer cleanup

This file tracks the Flutter analyzer modernization pass for Kadd.

## Required cleanup
- Replace deprecated `Color.withOpacity` with `Color.withValues(alpha: ...)`.
- Replace deprecated `Switch.activeColor` with `activeThumbColor` where appropriate.
- Replace deprecated anchored adaptive banner API with the current orientation-aware API.
- Remove unnecessary imports and direct package references.
- Guard `BuildContext` use after async gaps with mounted checks.
- Add `const` constructors where they are safe and improve readability/performance.

## CI policy
`flutter analyze` remains a hard gate. We do not use `continue-on-error` to hide analyzer failures.
