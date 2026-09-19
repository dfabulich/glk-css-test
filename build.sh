#!/bin/bash
# Build Glk CSS Basic Test (bare Inform 6 / Glulx, no library) as a .gblorb.
#
# Tool locations (override any of these):
#   INFORM6       path to inform6
#   CBLORB        path to inblorb/cBlorb (packages .ulx into .gblorb)
#   INFORM_APP    macOS: Inform.app bundle (used to derive INFORM6 / CBLORB)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/csstest.inf"
OUT="$SCRIPT_DIR/csstest.gblorb"
IMG_LIGHT="$SCRIPT_DIR/img_light.png"
IMG_DARK="$SCRIPT_DIR/img_dark.png"

uname_s="$(uname -s 2>/dev/null || echo unknown)"
case "$uname_s" in
	Darwin)
		INFORM_APP="${INFORM_APP:-/Applications/Inform.app}"
		: "${INFORM6:=$INFORM_APP/Contents/MacOS/inform6}"
		: "${CBLORB:=$INFORM_APP/Contents/MacOS/cBlorb}"
		;;
	*)
		: "${INFORM6:=$(command -v inform6 2>/dev/null || echo inform6)}"
		: "${CBLORB:=$(command -v inblorb 2>/dev/null || command -v cBlorb 2>/dev/null || echo inblorb)}"
		;;
esac

if [ ! -e "$INFORM6" ] && ! command -v "$INFORM6" >/dev/null 2>&1; then
	echo "Missing inform6: $INFORM6" >&2
	echo "On macOS set INFORM_APP or INFORM6." >&2
	exit 1
fi

if [ ! -e "$CBLORB" ] && ! command -v "$CBLORB" >/dev/null 2>&1; then
	echo "Missing inblorb/cBlorb: $CBLORB" >&2
	echo "On macOS set INFORM_APP or CBLORB." >&2
	exit 1
fi

if [ ! -f "$SRC" ]; then
	echo "Missing source: $SRC" >&2
	exit 1
fi
if [ ! -f "$IMG_LIGHT" ] || [ ! -f "$IMG_DARK" ]; then
	echo "Missing test images: $IMG_LIGHT / $IMG_DARK" >&2
	exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/csstest.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
ULX="$WORKDIR/csstest.ulx"
BLURB="$WORKDIR/csstest.blurb"

echo "==> inform6 (Glulx, UTF-8 source)"
echo "    INFORM6=$INFORM6"
# -Cu: source text is UTF-8 (needed for em dashes etc. in print strings).
# Without it, Inform treats each UTF-8 byte as Latin-1 (— becomes â??).
# Compile from $WORKDIR so intermediates (ulx, gameinfo.dbg) never land in the repo.
(
	cd "$WORKDIR"
	"$INFORM6" -GCu "$SRC" "$ULX"
)

echo "==> cBlorb (wrap ulx + pictures -> $OUT)"
echo "    CBLORB=$CBLORB"
{
	printf 'storyfile leafname "csstest.gblorb"\n'
	printf 'storyfile "%s" include\n' "$ULX"
	# Picture numbers match glk_image_draw resource IDs in csstest.inf.
	printf 'picture 1 "%s"\n' "$IMG_LIGHT"
	printf 'picture 2 "%s"\n' "$IMG_DARK"
} >"$BLURB"
"$CBLORB" "$BLURB" "$OUT"

# Drop leftovers from older builds.
rm -f "$SCRIPT_DIR/csstest.ulx" "$SCRIPT_DIR/gameinfo.dbg"

echo
echo "Built: $OUT"
ls -lh "$OUT"
