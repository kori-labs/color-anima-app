# Public App Boundary

This repository intentionally exposes only:

- the public macOS app surface
- the app-side workspace target
- the app-side engine client
- the binary kernel bridge
- release and packaging scripts
- encrypted binary intake metadata
- public issue, security, and licensing material

It must not contain:

- production compute source
- source fallback targets for maintainer binaries
- private planning or audit artifacts
- plaintext binary artifacts
- customer, project, or credential material

Maintainer-only compute intake is documented in `docs/core-binary-intake.md`.
