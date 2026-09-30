#!/usr/bin/env python3
"""Track the FAB / Next disc through a simulator recording (see VIDEO=1 in ui-shots.sh).

    scripts/video-disc-track.py build/shots/ui/motion.mov [--all]

Resamples to 60 fps, then for every frame measures the dark disc in the bottom
third: pixel count, centre (pt) and core darkness (23 ≈ solid ink, higher =
more transparent). Prints only frames where something changed (or all with
--all), with timestamps — so a glide shows as a run of frames with a moving
centre, a dissolve as darkness drifting, and a pop as one jump.
"""
import subprocess, sys

W, H = 402, 874                       # phone points; video is downscaled 3x


def frames(path):
    cmd = ["ffmpeg", "-loglevel", "error", "-i", path, "-vf", f"fps=60,scale={W}:{H}",
           "-f", "rawvideo", "-pix_fmt", "gray", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = W * H
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            return
        yield buf


def measure(g):
    xs = ys = n = 0
    vals = []
    for y in range(int(H * 0.66), H - 10):
        row = g[y * W:(y + 1) * W]
        for x in range(int(W * 0.30), int(W * 0.70)):
            v = row[x]
            if v < 150:
                xs += x; ys += y; n += 1; vals.append(v)
    if n < 40:
        return None
    dark = sorted(vals)[:max(1, n // 4)]
    return n, round(xs / n), round(ys / n), sum(dark) // len(dark)


def main():
    path = sys.argv[1]
    show_all = "--all" in sys.argv
    prev = "init"
    for i, g in enumerate(frames(path)):
        m = measure(g)
        key = None if m is None else (m[0] // 300, m[2], m[3] // 6)
        if show_all or key != prev:
            desc = "no dark disc" if m is None else f"n={m[0]:5d} centre=({m[1]},{m[2]}) core={m[3]}"
            print(f"t={i / 60:6.2f}s  {desc}")
            prev = key


if __name__ == "__main__":
    main()
