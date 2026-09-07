#!/bin/bash
# Enforces the parts of docs/ui-standard.md a reader cannot be trusted to
# remember. Each rule exists because the thing it forbids actually happened.
#
#   ./scripts/check-ui-standard.sh
#
# Exits non-zero on the first violation, naming the rule and the fix.
set -uo pipefail

cd "$(dirname "$0")/.."

KIT="Sources/MacPlecoKit"
DESIGN="$KIT/Design"
PAGES=("$KIT/Features" "$KIT/App")

fail=0

# Comments are allowed to name the things the rules forbid — this file's own
# rationale, and the design system's, both quote the old API by name.
code_only() {
	grep -vE ':[[:space:]]*(//|///|\*)' || true
}

report() {
	echo "!! $1" >&2
	echo "   $2" >&2
	shift 2
	printf '   %s\n' "$@" >&2
	echo >&2
	fail=1
}

# 1. Type is chosen by role, never assembled at a call site. Before the ramp
#    existed the app used 27 point sizes; after it existed, 108 call sites went
#    on composing their own out of `Typo.Step`.
hits="$(grep -rn '\.font(\.system(size:' "${PAGES[@]}" | code_only || true)"
[ -n "$hits" ] && report \
	"A page is composing its own font size." \
	"Use a Typo role, or .glyph(_:) for an SF Symbol." "$hits"

hits="$(grep -rn 'Typo\.Step' "${PAGES[@]}" | code_only || true)"
[ -n "$hits" ] && report \
	"A page is reaching into the raw type steps." \
	"Typo.Step is internal to Design/. Add a role there instead." "$hits"

# 2. Radii come in a scale, so that nesting stays concentric.
hits="$(grep -rnE 'cornerRadius: [0-9]' "$KIT" --include='*.swift' | grep -v "^$DESIGN/" | code_only || true)"
[ -n "$hits" ] && report \
	"A corner radius literal outside the design system." \
	"Use a Radius token: panel 22, card 16, row 12, chip 8, control 4." "$hits"

# 3. Spacing is a scale, not a base value plus a nudge.
hits="$(grep -rnE 'Space\.[a-z]+ [+-] ' "$KIT" | code_only || true)"
[ -n "$hits" ] && report \
	"Arithmetic on a spacing token." \
	"Pick the token that is already the value you want." "$hits"

# 4. Height belongs to the container, not the call site. This is the rule that
#    kept the search field 7pt taller than the popup beside it.
hits="$(grep -rnE '\.frame\((height|minHeight): [0-9]' "${PAGES[@]}" | code_only || true)"
[ -n "$hits" ] && report \
	"A page is setting its own height." \
	"Heights come from Control (24/28/36/44) or Layout." "$hits"

# 5. The destructive button is never the loudest thing on the screen — the
#    README's first promise, which the code broke for three releases.
hits="$(grep -rn 'PrimaryButtonStyle\|GhostButtonStyle' "$KIT" --include='*.swift' | code_only || true)"
[ -n "$hits" ] && report \
	"The old button styles are back." \
	"Use ActionButtonStyle(_:height:); intent decides the colour." "$hits"

hits="$(grep -rnE 'ActionButtonStyle\([^)]*tint:' "$KIT" --include='*.swift' | code_only || true)"
[ -n "$hits" ] && report \
	"A call site is choosing a button colour." \
	"Declare an ActionIntent. Colour is derived, never passed." "$hits"

# A filled danger button may exist only where .confirm is unlocked, and
# .confirm is unlocked only by confirmationSurface().
confirms="$(grep -rln 'ActionButtonStyle(\.confirm' "$KIT" --include='*.swift' || true)"
for file in $confirms; do
	if ! grep -q 'confirmationSurface()' "$file"; then
		report \
			"$file uses .confirm without a confirmation surface." \
			"Only a sheet or alert marked .confirmationSurface() may fill a destructive action." \
			"(it would render as an ordinary outlined destructive button)"
	fi
done

if [ "$fail" -eq 0 ]; then
	echo "UI standard: all checks pass"
fi
exit "$fail"
