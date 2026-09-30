#!/bin/zsh
# scripts/stall-stress.sh ITER label [tests...] — run the given UI tests ITER times with a watchdog log stream.
cd "$(dirname "$0")/.."
S=${TMPDIR:-/tmp}/softnotes-stress; mkdir -p $S
ITER=$1; LABEL=$2; shift 2
SIM=${SIM_NAME:-"iPhone 17 Pro"}
xcodegen generate -q
ONLY=(); for t in $@; do ONLY+=("-only-testing:SoftNotesUITests/SoftNotesUITests/$t"); done
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
xcrun simctl spawn "$SIM" log stream --level debug --predicate 'subsystem == "com.owaistaha.softnotes"' > $S/stress_$LABEL.log 2>&1 &
LP=$!
# On the first 2 s in-progress stall of each app process, sample it for 3 s.
( n=0; tail -F $S/stress_$LABEL.log 2>/dev/null | while read -r line; do
    if [[ "$line" == *"stall in progress: 2"* ]]; then
      n=$((n+1)); AP=$(pgrep -f "Application/.*/SoftNotes.app/SoftNotes" | head -1)
      [[ -n "$AP" ]] && sample $AP 3 -mayDie -file $S/hang_${LABEL}_$n.txt >/dev/null 2>&1 && echo "sampled hang $n -> hang_${LABEL}_$n.txt"
    fi
  done ) &
WP=$!
xcodebuild test -project SoftNotes.xcodeproj -scheme SoftNotes -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath $TMPDIR/softnotes-uitests/dd -test-iterations $ITER $ONLY 2>&1 | tee $S/stress_$LABEL.xcb.log | grep -E "Test Case .*(passed|failed)|error:|TEST (SUCC|FAIL)"
kill $LP; pkill -P $WP; kill $WP 2>/dev/null
echo "stall lines:"; grep -c "stalled" $S/stress_$LABEL.log; grep -E "stalled|in progress" $S/stress_$LABEL.log | sed -E 's/.*(main thread)/\1/' | head -60
