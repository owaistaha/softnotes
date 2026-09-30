#!/bin/zsh
# Run the UI tests and export every XCTAttachment (screenshots) to build/shots/ui/.
#   scripts/ui-shots.sh                          # all tests
#   scripts/ui-shots.sh testFabMorphOpenAndClose # one test (method name)
# Env: SIM_NAME (default "iPhone 17 Pro"). DerivedData + the .xcresult live in
# $TMPDIR, NOT in the repo (an in-repo DerivedData breaks XcodeGen — see CLAUDE.md).
set -eo pipefail
cd "$(dirname "$0")/.."

SIM_NAME=${SIM_NAME:-"iPhone 17 Pro"}
WORK=${TMPDIR:-/tmp}/softnotes-uitests
OUT=build/shots/ui
RESULT=$WORK/result.xcresult
ONLY=${1:+-only-testing:SoftNotesUITests/SoftNotesUITests/$1}

rm -rf "$RESULT" "$OUT"; mkdir -p "$WORK" "$OUT"
xcodegen generate -q

set +e
xcodebuild test -project SoftNotes.xcodeproj -scheme SoftNotes \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$WORK/dd" -resultBundlePath "$RESULT" $ONLY 2>&1 \
  | grep -E "error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)|\*\* "
STATUS=${pipestatus[1]}
set -e

# Export attachments, then give them readable names from manifest.json.
RAW=$WORK/raw; rm -rf "$RAW"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$RAW" >/dev/null
python3 - "$RAW" "$OUT" <<'PY'
import json, shutil, sys, os
raw, out = sys.argv[1:3]
n = 0
for test in json.load(open(os.path.join(raw, "manifest.json"))):
    for a in test.get("attachments", []):
        src = os.path.join(raw, a["exportedFileName"])
        name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
        base = name.split("_0_")[0]            # strip Xcode's uuid suffix
        shutil.copy(src, os.path.join(out, base + ".png")); n += 1
print(f"exported {n} screenshots -> {out}")
PY
exit $STATUS
