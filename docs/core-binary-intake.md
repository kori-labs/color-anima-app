# Core Binary Intake

This public repository is a sanitized app and release-intake surface. It does
not contain production compute source or a source fallback target.

The package can expose a `ColorAnimaKernel` SwiftPM binary target only when a
maintainer supplies one of these inputs:

- `COLOR_ANIMA_KERNEL_PATH` for a local artifact under ignored `.local-core/`
- `COLOR_ANIMA_KERNEL_URL` and `COLOR_ANIMA_KERNEL_CHECKSUM` for an approved
  remote SwiftPM artifact

Without those inputs, the package builds the public app with the kernel bridge
in unavailable mode.

## Encrypted Release Intake

The supported maintainer flow is:

1. A maintainer release process builds an audited C-ABI-only
   `ColorAnimaKernel.xcframework.zip`.
2. The zip is encrypted. Only `ColorAnimaKernel.xcframework.zip.enc` and
   checksum sidecars are attached to the public app release.
3. `CoreBinary.env` is updated with version, tag, asset name, and checksums. It
   contains no secret material.
4. Maintainer CI or local maintainers run:

   ```sh
   ./scripts/fetch-core-binary.sh
   ```

The script requires `COLOR_ANIMA_KERNEL_DECRYPTION_KEY` or the same value in
macOS Keychain service `color-anima-kernel-release-key`.

5. The fetch script verifies the encrypted checksum, decrypts into
   `.local-core/`, verifies the plaintext checksum, and leaves:

   ```text
   .local-core/ColorAnimaKernel.xcframework
   ```

6. Intake verification activates the binary target through the local path:

   ```sh
   COLOR_ANIMA_KERNEL_PATH=".local-core/ColorAnimaKernel.xcframework" \
     ./scripts/verify-core-binary-intake.sh
   ```

Public forks and external pull requests do not receive the decryption key.

## Expected Artifact

The decrypted artifact must be:

- an XCFramework accepted by SwiftPM `.binaryTarget(path:)` under `.local-core/`
- C-ABI-only for public-intake use
- audited before publication
- published only as an encrypted `.zip.enc` plus checksum sidecars

## Required Audit Before Future Release Use

Before a future release depends on a newly mirrored encrypted asset, audit the
final plaintext zip, not only the intermediate build folder:

- archive file names
- exported interfaces
- symbol names
- reflection strings
- debug information
- bundled sidecar files
- release title and release notes

Do not ship or promote a future release from this repository until that audit
passes.

## Local Verification

Public app:

```sh
swift package describe
swift build
swift test
```

With a local maintainer artifact:

```sh
COLOR_ANIMA_KERNEL_PATH=".local-core/ColorAnimaKernel.xcframework" \
  ./scripts/verify-core-binary-intake.sh
```

With an approved remote binary:

```sh
COLOR_ANIMA_KERNEL_URL="https://example.com/ColorAnimaKernel.xcframework.zip" \
COLOR_ANIMA_KERNEL_CHECKSUM="<sha256>" \
  ./scripts/verify-core-binary-intake.sh
```

The verifier rejects source fallback directories and hard-coded local binary
paths in the package manifest.
