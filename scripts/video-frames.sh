#!/bin/zsh
# Tile frames from a simulator recording using the SAME time base as the
# trackers (fps=60 resample, frame n = t*60) — `-ss` seeks land off on these
# variable-frame-rate recordings.
#   scripts/video-frames.sh <video> <start_s> <end_s> <out.png> [step_frames=2] [crop=w:h:x:y] [cols=6]
set -e
zmodload zsh/mathfunc; V=$1; A=$(( int(rint($2*60)) )); B=$(( int(rint($3*60)) )); OUT=$4
STEP=${5:-2}; CROP=${6:-1206:2622:0:0}; COLS=${7:-6}
N=$(( (B-A)/STEP + 1 )); ROWS=$(( (N+COLS-1)/COLS ))
ffmpeg -loglevel error -y -i "$V" -vf "fps=60,select='between(n\,$A\,$B)*not(mod(n-$A\,$STEP))',crop=$CROP,scale=300:-1,tile=${COLS}x${ROWS}" -frames:v 1 -update 1 "$OUT"
echo "$OUT: frames $A..$B step $STEP ($N frames, $(( STEP*1000/60 )) ms apart)"
