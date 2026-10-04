#!/bin/bash
# Validates SwiftData @Model classes for CloudKit compatibility.
# Called as a PostToolUse hook — receives JSON on stdin with tool_input.

set -euo pipefail

# Extract the file path from the hook payload
FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

# Only check Swift files in a Models directory
case "$FILE" in
  */Models/*.swift) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist or is not a @Model file
[ -f "$FILE" ] || exit 0
grep -q '@Model' "$FILE" || exit 0

VIOLATIONS=""

# 1. @Attribute(.unique) is forbidden with CloudKit
if grep -q '@Attribute(\.unique)' "$FILE"; then
  VIOLATIONS+="- @Attribute(.unique) is not compatible with CloudKit. Remove it or use a different strategy.\n"
fi

# 2. Non-optional stored properties without default values.
#    Match "var name: Type" lines (no ?, no =, not a @Relationship line, not computed).
#    We read the file and only inspect lines inside @Model classes.
while IFS= read -r line; do
  # Skip blank, comments, relationships, lines with defaults, computed properties
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*//.* ]] && continue
  [[ "$line" =~ @Relationship ]] && continue
  [[ "$line" =~ = ]] && continue
  [[ "$line" =~ \{ ]] && continue

  # Match stored property declarations: "var foo: Bar" where Bar doesn't end with ?
  if [[ "$line" =~ ^[[:space:]]+var[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*[^?]+[^?][[:space:]]*$ ]]; then
    trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
    VIOLATIONS+="- Non-optional stored property without default value: ${trimmed}\n"
  fi
done < "$FILE"

# 3. Non-optional @Relationship properties.
while IFS= read -r lineno; do
  # Read the var declaration line(s) following the @Relationship attribute
  varline=$(awk "NR>$lineno && /var /{print; exit}" "$FILE")
  if [ -n "$varline" ] && ! echo "$varline" | grep -qE '\?'; then
    trimmed=$(echo "$varline" | sed 's/^[[:space:]]*//')
    VIOLATIONS+="- Non-optional @Relationship property: ${trimmed}\n"
  fi
done < <(grep -n '@Relationship' "$FILE" | cut -d: -f1)

if [ -n "$VIOLATIONS" ]; then
  MSG="CloudKit compatibility violations in $(basename "$FILE"):\n${VIOLATIONS}All @Model properties must either be optional or have default values. All relationships must be optional. @Attribute(.unique) is forbidden."
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$MSG"
fi
