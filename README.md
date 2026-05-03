# Color Anima

Native macOS app and release-intake surface for Color Anima.

## Overview

This repository contains the public macOS app surface, the app-side workspace,
the app-side engine client, the binary kernel bridge, distribution scripts,
issue templates, and encrypted binary intake metadata. Production compute is
delivered through maintainer-controlled release intake; private implementation
source is not committed here.

The tracked `CoreBinary.env` file contains version, tag, asset name, and
checksum metadata only. The encrypted asset is mirrored through GitHub Releases
and requires a maintainer-held decryption key before it can be staged under
ignored `.local-core/`.

## Build

Public app build:

```sh
swift package resolve
swift build
swift test
swift run ColorAnima
```

Maintainer intake verification after a mirrored encrypted binary is available:

```sh
./scripts/fetch-core-binary.sh
COLOR_ANIMA_KERNEL_PATH=".local-core/ColorAnimaKernel.xcframework" \
  ./scripts/verify-core-binary-intake.sh
```

The intake path activates the `ColorAnimaKernel` SwiftPM binary target only
through environment variables. App workspace code calls the public
`ColorAnimaAppEngine` client, which delegates to `ColorAnimaKernelBridge`; no
source fallback is allowed in this repository.

## Issues

Use GitHub Issues for bug reports, feature requests, and workflow feedback.
Do not attach unreleased project files, credentials, customer material, or other
sensitive material to public issues.

## Contributing

External pull requests are not accepted at this time. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for commercial-licensing inquiries.

## License

PolyForm Noncommercial 1.0.0. See [`LICENSE`](LICENSE).
