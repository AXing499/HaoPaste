#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/haopaste-shot-check.XXXXXX")"
cleanup() {
    rm -rf "$OUTPUT"
}
trap cleanup EXIT

HAOPASTE_SKIP_BUILD=1 \
HAOPASTE_SCREENSHOT_OUTPUT="$OUTPUT" \
    Scripts/generate-screenshots.sh >/dev/null

failed=0
for generated in "$OUTPUT"/screenshot-*.png; do
    name="$(basename "$generated")"
    # TextEditor caret blinking makes OCR captures non-deterministic.
    if [[ "$name" == screenshot-ocr* ]]; then
        continue
    fi
    baseline="Docs/$name"
    if [[ ! -f "$baseline" ]]; then
        echo "MISSING baseline: Docs/$name" >&2
        failed=1
        continue
    fi
    if ! cmp -s "$baseline" "$generated"; then
        echo "CHANGED: Docs/$name" >&2
        failed=1
    fi
done

if [[ "$failed" -ne 0 ]]; then
    echo "Screenshot baselines differ. Review the UI and run make screenshots." >&2
    exit 1
fi

echo "Screenshots match baselines."
