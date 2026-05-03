#!/usr/bin/env bash
# verify-accessibility-tree.sh — confirm the app exposes a basic accessibility tree
# Usage: ./verify-accessibility-tree.sh "$APP_NAME" "$APP_PID"
# Exit 0 = pass, Exit 1 = fail

set -euo pipefail

APP_NAME="${1:-Color Anima}"
APP_PID="${2:?APP_PID required}"

PASS=0
FAIL=0
MAX_ATTEMPTS=10
RETRY_DELAY=0.5

pass() { echo "[PASS] $*"; ((PASS++)) || true; }
fail() { echo "[FAIL] $*"; ((FAIL++)) || true; }
skip() { echo "[SKIP] $*"; }

is_accessibility_error() {
    echo "$1" | grep -qi "not allowed\|not authorized\|1002\|access for assistive\|keystrokes"
}

# Check 1: process is alive (hard check, no accessibility needed)
if kill -0 "$APP_PID" 2>/dev/null; then
    pass "Process $APP_PID is running"
else
    fail "Process $APP_PID is not running"
    exit 1
fi

# Check 2: query a lightweight accessibility surface via System Events.
# `entire contents of window 1` is too brittle for CI: it can race window
# creation and produces large outputs. Count common AX element kinds instead.
AX_EXIT=0
AX_RESULT=""
AX_COUNTS=""

for (( attempt=1; attempt<=MAX_ATTEMPTS; attempt++ )); do
    AX_EXIT=0
    AX_RESULT=$(osascript -e "
tell application \"System Events\"
    tell (first process whose unix id is $APP_PID)
        tell first window
            set groupCount to count of groups
            set buttonCount to count of buttons
            set scrollAreaCount to count of scroll areas
            set staticTextCount to count of static texts
            set checkBoxCount to count of checkboxes
            return (groupCount as text) & \",\" & (buttonCount as text) & \",\" & (scrollAreaCount as text) & \",\" & (staticTextCount as text) & \",\" & (checkBoxCount as text)
        end tell
    end tell
end tell
" 2>&1) || AX_EXIT=$?

    if is_accessibility_error "$AX_RESULT"; then
        skip "Accessibility not available — grant permission in System Preferences > Privacy & Security > Accessibility"
        skip "Cannot verify accessibility tree without permission; skipping accessibility checks"
        echo ""
        echo "Results: $PASS passed, $FAIL failed"
        exit 0
    fi

    if (( AX_EXIT == 0 )) && [[ "$AX_RESULT" =~ ^[0-9]+,[0-9]+,[0-9]+,[0-9]+,[0-9]+$ ]]; then
        AX_COUNTS="$AX_RESULT"
        break
    fi

    sleep "$RETRY_DELAY"
done

if [[ -z "$AX_COUNTS" ]]; then
    fail "Could not query accessibility surface after ${MAX_ATTEMPTS} attempts (last result: $AX_RESULT)"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

IFS=',' read -r GROUP_COUNT BUTTON_COUNT SCROLL_AREA_COUNT STATIC_TEXT_COUNT CHECKBOX_COUNT <<< "$AX_COUNTS"
ELEMENT_COUNT=$(( GROUP_COUNT + BUTTON_COUNT + SCROLL_AREA_COUNT + STATIC_TEXT_COUNT + CHECKBOX_COUNT ))

if (( ELEMENT_COUNT > 0 )); then
    pass "Accessibility tree is non-empty (groups=$GROUP_COUNT, buttons=$BUTTON_COUNT, scrollAreas=$SCROLL_AREA_COUNT, staticTexts=$STATIC_TEXT_COUNT, checkboxes=$CHECKBOX_COUNT)"
else
    fail "Accessibility tree is empty (groups=$GROUP_COUNT, buttons=$BUTTON_COUNT, scrollAreas=$SCROLL_AREA_COUNT, staticTexts=$STATIC_TEXT_COUNT, checkboxes=$CHECKBOX_COUNT)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
