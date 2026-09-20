#!/bin/bash
# Build Glk CSS Basic Test (bare Inform 6 / Glulx, no library) as a .gblorb.
#
# Tool locations (override any of these):
#   INFORM6       path to inform6
#   CBLORB        path to inblorb/cBlorb (packages .ulx into .gblorb)
#   INFORM_APP    macOS: Inform.app bundle (used to derive INFORM6 / CBLORB)
#
# Release is fixed at 1. Serial is YYMMDD from the build date (override with
# SERIAL=yymmdd). An iFiction record is embedded in the blorb.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/csstest.inf"
OUT="$SCRIPT_DIR/csstest.gblorb"
IMG_LIGHT="$SCRIPT_DIR/img_light.png"
IMG_DARK="$SCRIPT_DIR/img_dark.png"

RELEASE=1
SERIAL="${SERIAL:-$(date +%y%m%d)}"
RELEASE_DATE="$(date +%Y-%m-%d)"
# Stable IFID for this project (must match Embedded_IFID in csstest.inf).
IFID="4F0B01F7-AB3E-433A-801E-4D1A092B0929"
TITLE="Glk CSS Basic Test"
AUTHOR="Dan Fabulich"

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

if ! [[ "$SERIAL" =~ ^[0-9]{6}$ ]]; then
	echo "SERIAL must be six digits (YYMMDD), got: $SERIAL" >&2
	exit 1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/csstest.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
ULX="$WORKDIR/csstest.ulx"
BLURB="$WORKDIR/csstest.blurb"
VERSION_INF="$WORKDIR/version.inf"
IFICATION="$WORKDIR/Metadata.iFiction"

# Inform header Release/Serial plus printable constants for the banner.
{
	printf 'Release %s;\n' "$RELEASE"
	printf 'Serial "%s";\n' "$SERIAL"
	printf 'Constant GAME_RELEASE = %s;\n' "$RELEASE"
	printf 'Constant GAME_SERIAL "%s";\n' "$SERIAL"
} >"$VERSION_INF"

# Treaty of Babel iFiction (see Babel-Treaty.md examples).
cat >"$IFICATION" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<ifindex version="1.0" xmlns="http://babel.ifarchive.org/protocol/iFiction/">
	<story>
		<identification>
			<ifid>${IFID}</ifid>
			<format>glulx</format>
		</identification>
		<bibliographic>
			<title>${TITLE}</title>
			<author>${AUTHOR}</author>
			<language>en</language>
			<headline>A visual test for the Glk CSS Basic extension</headline>
			<firstpublished>${RELEASE_DATE}</firstpublished>
			<genre>Testing</genre>
			<description>Exercises the CSS Basic property/value set from the
			Glk CSS extension proposal.</description>
		</bibliographic>
		<glulx>
			<release>${RELEASE}</release>
			<serial>${SERIAL}</serial>
		</glulx>
		<releases>
			<attached>
				<release>
					<version>${RELEASE}</version>
					<releasedate>${RELEASE_DATE}</releasedate>
					<compiler>Inform 6</compiler>
				</release>
			</attached>
		</releases>
		<colophon>
			<generator>glk-css-test/build.sh</generator>
			<originated>${RELEASE_DATE}</originated>
		</colophon>
	</story>
</ifindex>
EOF

echo "==> inform6 (Glulx, UTF-8 source)"
echo "    INFORM6=$INFORM6"
echo "    Release $RELEASE / Serial $SERIAL"
# -Cu: source text is UTF-8 (needed for em dashes etc. in print strings).
# ++WORKDIR so Include "version.inf" finds the generated file.
# Compile into $WORKDIR so intermediates never land in the repo.
(
	cd "$WORKDIR"
	"$INFORM6" -GCu "++$WORKDIR" "$SRC" "$ULX"
)

echo "==> cBlorb (wrap ulx + pictures + iFiction -> $OUT)"
echo "    CBLORB=$CBLORB"
{
	printf 'storyfile leafname "csstest.gblorb"\n'
	printf 'storyfile "%s" include\n' "$ULX"
	printf 'ifiction "%s" include\n' "$IFICATION"
	# Picture numbers match glk_image_draw resource IDs in csstest.inf.
	printf 'picture 1 "%s"\n' "$IMG_LIGHT"
	printf 'picture 2 "%s"\n' "$IMG_DARK"
} >"$BLURB"
"$CBLORB" "$BLURB" "$OUT"

# Drop leftovers from older builds.
rm -f "$SCRIPT_DIR/csstest.ulx" "$SCRIPT_DIR/gameinfo.dbg"

echo
echo "Built: $OUT"
echo "IFID: $IFID"
ls -lh "$OUT"
