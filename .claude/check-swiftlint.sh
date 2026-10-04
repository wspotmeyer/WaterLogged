#!/bin/bash
# Runs SwiftLint on the file just edited by Claude.
# Called as a PostToolUse hook — receives JSON on stdin with tool_input.

set -euo pipefail

SWIFTLINT=/opt/homebrew/bin/swiftlint
[ -x "$SWIFTLINT" ] || exit 0

# Extract the file path from the hook payload
FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

# Only run on Swift files
case "$FILE" in
  *.swift) ;;
  *) exit 0 ;;
esac

# Skip files outside the linted area (Libraries, Tests, etc. are excluded by config)
case "$FILE" in
  */Libraries/*) exit 0 ;;
  */WaterLoggedTests/*) exit 0 ;;
esac

# Skip if file no longer exists
[ -f "$FILE" ] || exit 0

# Run SwiftLint scoped to the single file (positional path).
OUTPUT=$("$SWIFTLINT" lint --quiet --reporter json "$FILE" 2>/dev/null || echo '[]')

# Build a human-readable summary with jq; emit nothing if no violations.
MSG=$(printf '%s' "$OUTPUT" | jq -r --arg name "$(basename "$FILE")" '
  if length == 0 then empty
  else
    "SwiftLint violations in \($name):\n" +
    (map("- L\(.line) \(.severity): \(.reason) (\(.rule_id))") | join("\n"))
  end
')

if [ -n "$MSG" ]; then
  jq -nc --arg msg "$MSG" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $msg
    }
  }'
fi
