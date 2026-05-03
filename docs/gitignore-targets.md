# Gitignore Targets

The public repository keeps ignore rules narrow. The goal is to prevent local
build output, credentials, and packaged release artifacts from entering the
public history while keeping the sanitized shell source and public documentation
visible.

## Currently Ignored

macOS and editor noise:

- `.DS_Store`
- `*.xcuserstate`
- `*.xcworkspace/xcuserdata/`
- `*.xcodeproj/xcuserdata/`

Swift and Xcode build output:

- `.build/`
- `.swiftpm/`
- `DerivedData/`

Local credentials and machine-only configuration:

- `.env`
- `.env.local`
- `.local-core/`

Core release metadata:

- `CoreBinary.env` is intentionally tracked after the maintainer release process
  writes it. It contains version, tag, asset name, and checksums only.
- `CoreBinary.env.example` is a placeholder template.

Packaged artifacts:

- `*.xcframework`
- `*.xcframework.zip`
- `*.dSYM/`
- `*.dmg`
- `*.pkg`
- `dist/`
- `reports/`

## Not Ignored By Default

These should remain visible unless a later decision changes the public repo
shape:

- `README.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `LICENSE`
- `.github/ISSUE_TEMPLATE/**`
- `Package.swift`
- sanitized `Sources/**`
- `docs/**`

## Review Rule

Do not broaden `.gitignore` to hide uncertain files. If a file is not safe for
public history, remove it from the public repo or document why it is generated
locally.
