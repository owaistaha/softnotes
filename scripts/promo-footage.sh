#!/bin/zsh
# Record promo footage: one simulator screen recording per PromoFootageTests method.
#   scripts/promo-footage.sh                    # every clip
#   scripts/promo-footage.sh testPromoCompose   # one or more clips
# Output (default ../softnotes-promo/public/footage, override with PROMO_OUT):
#   <clip>.raw.mov   raw recording (changed frames only, includes launch)
#   <clip>.marks.json  { "mark": seconds-from-recording-start, ... } (± ~0.4 s)
# DerivedData lives in $TMPDIR, never in the repo (see CLAUDE.md).
set -eo pipefail
cd "$(dirname "$0")/.."

SIM_NAME=${SIM_NAME:-"iPhone 17 Pro"}
OUT=${PROMO_OUT:-../softnotes-promo/public/footage}
WORK=${TMPDIR:-/tmp}/softnotes-promo-footage
DEST="platform=iOS Simulator,name=$SIM_NAME"
mkdir -p "$OUT" "$WORK"

UDID=$(xcrun simctl list devices available | awk '/^-- /{sec=$0} index($0, "    '"$SIM_NAME"' (") {print; exit}' | grep -oE '[0-9A-F-]{36}')
[[ -n "$UDID" ]] || { echo "simulator '$SIM_NAME' not found"; exit 1; }

# Software keyboard on (the write step needs it), as in ui-shots.sh.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
/usr/libexec/PlistBuddy -c "Delete :DevicePreferences:$UDID:ConnectHardwareKeyboard" ~/Library/Preferences/com.apple.iphonesimulator.plist >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :DevicePreferences:$UDID:ConnectHardwareKeyboard bool false" ~/Library/Preferences/com.apple.iphonesimulator.plist >/dev/null 2>&1 || true
xcodegen generate -q

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1
# Clean, marketing-style status bar.
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

echo "building for testing…"
xcodebuild build-for-testing -project SoftNotes.xcodeproj -scheme SoftNotes -destination "$DEST" \
  -derivedDataPath "$WORK/dd" -quiet 2>&1 | grep -E "error:|BUILD|\*\* " || true

if (( $# )); then CLIPS=("$@"); else
  CLIPS=($(grep -oE "func testPromo[A-Za-z]+" SoftNotesUITests/PromoFootageTests.swift | sed 's/func //'))
fi

for clip in $CLIPS; do
  echo "── recording $clip"
  RAW="$OUT/$clip.raw.mov"; LOG="$WORK/$clip.log"
  rm -f "$RAW"
  START=$(python3 -c 'import time; print(f"{time.time():.3f}")')
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$RAW" 2>/dev/null &
  REC=$!
  sleep 1.5
  set +e
  xcodebuild test-without-building -project SoftNotes.xcodeproj -scheme SoftNotes -destination "$DEST" \
    -derivedDataPath "$WORK/dd" -only-testing:SoftNotesUITests/PromoFootageTests/$clip > "$LOG" 2>&1
  STATUS=$?
  set -e
  kill -INT $REC 2>/dev/null; wait $REC 2>/dev/null || true
  grep -E "Test Case .*(passed|failed)|error:" "$LOG" | head -5
  python3 - "$LOG" "$START" "$OUT/$clip.marks.json" <<'PY'
import json, re, sys
log, start, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
marks = {}
for line in open(log, errors="ignore"):
    m = re.search(r"PROMO_MARK (\S+) ([0-9.]+)", line)
    if m and m.group(1) not in marks:
        marks[m.group(1)] = round(float(m.group(2)) - start, 3)
json.dump(marks, open(out, "w"), indent=1)
print("marks:", marks)
PY
  [[ $STATUS -eq 0 ]] || echo "!! $clip FAILED (see $LOG)"
done
xcrun simctl status_bar "$UDID" clear
