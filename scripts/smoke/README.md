# macOS App Smoke Checks

Small launch checks for the packaged public shell. They are called by
`scripts/smoke-test-macos-app.sh`.

| Script | What it checks |
| --- | --- |
| `verify-window-present.sh` | Process is alive, the app has a visible window, and the window has nonzero size |
| `verify-keyboard-smoke.sh` | The app stays alive after basic keyboard events |
| `verify-accessibility-tree.sh` | The app exposes a non-empty accessibility tree via System Events |

Checks that require System Events degrade to `[SKIP]` when accessibility
permissions are unavailable.
