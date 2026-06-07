#!/usr/bin/env bash
# Feature-isolation boundary check (run in CI).
#
# Rule: a feature may import another feature's PUBLIC barrel or its domain/,
# but never reach into another feature's data/ or presentation/ internals.
# Composition roots are exempt (they exist to wire features together):
#   lib/app/**, lib/core/di/**, lib/core/navigation/**,
#   lib/features/dashboard/** (shell), lib/features/settings/** (orchestrator).
set -euo pipefail
cd "$(dirname "$0")/.."

violations=0
while IFS= read -r -d '' file; do
  case "$file" in
    lib/app/*|lib/core/di/*|lib/core/navigation/*|\
    lib/features/dashboard/*|lib/features/settings/*) continue ;;
  esac
  # the importing file's own top-level feature (…/features/<name>/…)
  self=$(printf '%s' "$file" | sed -nE 's#^lib/features/([^/]+)/.*#\1#p')
  # forbidden: importing another feature's data/ or presentation/
  while IFS= read -r line; do
    other=$(printf '%s' "$line" | sed -nE "s#.*package:noscroll/features/([^/]+)/.*/(data|presentation)/.*#\1#p")
    [ -z "$other" ] && continue
    [ "$other" = "$self" ] && continue
    echo "BOUNDARY VIOLATION: $file"
    echo "    -> $line"
    violations=$((violations+1))
  done < <(grep -nE "package:noscroll/features/[^/]+/(.*/)?(data|presentation)/" "$file" || true)
done < <(find lib/features -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' -print0)

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "✗ $violations feature-boundary violation(s) found."
  exit 1
fi
echo "✓ No feature-boundary violations."
