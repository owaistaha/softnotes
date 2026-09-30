#!/bin/zsh
# Run the UI tests and export every XCTAttachment (screenshots) to build/shots/ui/.
#   scripts/ui-shots.sh                          # all tests
#   scripts/ui-shots.sh testFabMorphOpenAndClose # one test (method name)
#   scripts/ui-shots.sh SoftNotesTests/FoldingCardTests  # unit tests (id with a /)
# Env: SIM_NAME (default "iPhone 17 Pro"). DerivedData + the .xcresult live in
# $TMPDIR, NOT in the repo (an in-repo DerivedData breaks XcodeGen — see CLAUDE.md).
set -eo pipefail
cd "$(dirname "$0")/.."

SIM_NAME=${SIM_NAME:-"iPhone 17 Pro"}
WORK=${TMPDIR:-/tmp}/softnotes-uitests
OUT=build/shots/ui
RESULT=$WORK/result.xcresult
# A bare method name runs that UI test; anything with a "/" is passed through
# (e.g. SoftNotesTests/FoldingCardTests for the unit tests).
if [[ "$1" == */* ]]; then ONLY="-only-testing:$1"; else ONLY=${1:+-only-testing:SoftNotesUITests/SoftNotesUITests/$1}; fi

rm -rf "$RESULT" "$OUT"; mkdir -p "$WORK" "$OUT"

# Show the *software* keyboard (the write step's layout depends on it): turn off
# the Mac-keyboard passthrough globally and for this device. Needs a sim reboot
# to take effect if Simulator.app already connected a hardware keyboard.
UDID=$(xcrun simctl list devices available | grep -m1 "    $SIM_NAME (" | grep -oE '[0-9A-F-]{36}')
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
/usr/libexec/PlistBuddy -c "Delete :DevicePreferences:$UDID:ConnectHardwareKeyboard" \
  ~/Library/Preferences/com.apple.iphonesimulator.plist >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :DevicePreferences:$UDID:ConnectHardwareKeyboard bool false" \
  ~/Library/Preferences/com.apple.iphonesimulator.plist >/dev/null 2>&1 || true
xcodegen generate -q

# VIDEO=1: also record the simulator screen (60 fps) to build/shots/ui/motion.mov.
# Boots the sim first; the recording brackets the whole xcodebuild run.
REC_PID=""
if [[ -n "$VIDEO" ]]; then
  xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
  xcrun simctl bootstatus "$SIM_NAME" -b >/dev/null 2>&1
  xcrun simctl io "$SIM_NAME" recordVideo --codec h264 --force "$OUT/motion.mov" 2>/dev/null &
  REC_PID=$!
  sleep 1
fi

# run <result.xcresult> [-only-testing:…]: one xcodebuild test pass; the
# full log goes to $WORK/last.log, the summary lines to the terminal.
run() {
  local res=$1; shift
  rm -rf "$res"
  xcodebuild test -project SoftNotes.xcodeproj -scheme SoftNotes \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -derivedDataPath "$WORK/dd" -resultBundlePath "$res" "$@" 2>&1 \
    | tee -a "$WORK/last.log" \
    | grep -E "error:|Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)|\*\* "
  return ${pipestatus[1]}
}

set +e
: > "$WORK/last.log"
RESULTS=("$RESULT")
run "$RESULT" $ONLY
STATUS=$?
# Re-run each failed test ONCE (simulator UI queries flake — see CLAUDE.md)
# and say so. The run passes only if every retried test passes.
if [[ $STATUS -ne 0 ]]; then
  FAILED=($(grep -oE "Test Case '-\[[A-Za-z]+\.[A-Za-z]+ [A-Za-z0-9_]+\]' failed" "$WORK/last.log" \
    | sed -E "s/.*-\[([A-Za-z]+)\.([A-Za-z]+) ([A-Za-z0-9_]+)\].*/\1\/\2\/\3/" | sort -u))
  if (( ${#FAILED} )); then
    STATUS=0
    for t in $FAILED; do
      echo "RETRY: $t failed — re-running it once"
      R2="$WORK/retry_${t:t}.xcresult"
      RESULTS+=("$R2")
      if run "$R2" "-only-testing:$t"; then
        echo "RETRY: $t passed on the second run (flaky)"
      else
        echo "RETRY: $t failed again"
        STATUS=1
      fi
    done
  fi
fi
set -e
if [[ -n "$REC_PID" ]]; then kill -INT $REC_PID 2>/dev/null; wait $REC_PID 2>/dev/null; fi

# Export attachments (first run + any retries), then give them readable
# names from manifest.json.
RAW=$WORK/raw; rm -rf "$RAW"
for res in $RESULTS; do
  [[ -d "$res" ]] || continue
  mkdir -p "$RAW/${res:t:r}"
  xcrun xcresulttool export attachments --path "$res" --output-path "$RAW/${res:t:r}" >/dev/null
done
python3 - "$RAW" "$OUT" <<'PY'
import json, shutil, sys, os
raw, out = sys.argv[1:3]
n = 0
for sub in sorted(os.listdir(raw)):
    d = os.path.join(raw, sub)
    manifest = os.path.join(d, "manifest.json")
    if not os.path.exists(manifest):
        continue
    for test in json.load(open(manifest)):
        for a in test.get("attachments", []):
            src = os.path.join(d, a["exportedFileName"])
            name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            base = name.split("_0_")[0]            # strip Xcode's uuid suffix
            shutil.copy(src, os.path.join(out, base + ".png")); n += 1
print(f"exported {n} screenshots -> {out}")
PY
exit $STATUS
