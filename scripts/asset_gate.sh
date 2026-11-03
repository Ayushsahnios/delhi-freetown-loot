#!/usr/bin/env bash
# Asset license + size gate (issue 295).
# 1. Every binary asset under assets/ must live in a folder that also
#    holds a license statement (LICENSE*, OFL* or COPYING*).
# 2. Size budget: assets/ total <= 48 MB, any single file <= 12 MB.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

# --- 1. license file next to every committed asset ----------------------
while IFS= read -r -d '' f; do
	dir=$(dirname "$f")
	if ! find "$dir" -maxdepth 1 -type f \
		\( -iname 'LICENSE*' -o -iname 'OFL*' -o -iname 'COPYING*' \) \
		-print -quit | grep -q .; then
		echo "asset-gate FAIL: no license file next to $f"
		fail=1
	fi
done < <(find assets -type f \( -iname '*.glb' -o -iname '*.gltf' \
	-o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
	-o -iname '*.ttf' -o -iname '*.otf' -o -iname '*.wav' \
	-o -iname '*.ogg' -o -iname '*.mp3' \) -print0)

# --- 2. size budget ------------------------------------------------------
total_kb=$(du -sk assets | cut -f1)
if [ "$total_kb" -gt 49152 ]; then
	echo "asset-gate FAIL: assets/ is ${total_kb}KB — over the 48MB budget"
	fail=1
fi
while IFS= read -r -d '' f; do
	kb=$(du -k "$f" | cut -f1)
	if [ "$kb" -gt 12288 ]; then
		echo "asset-gate FAIL: $f is ${kb}KB — over the 12MB per-file budget"
		fail=1
	fi
done < <(find assets -type f -print0)

if [ "$fail" -ne 0 ]; then
	echo "asset-gate: verdict=FAIL"
	exit 1
fi
echo "asset-gate: verdict=PASS (licenses present, ${total_kb}KB within budget)"
