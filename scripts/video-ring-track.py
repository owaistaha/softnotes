#!/usr/bin/env python3
"""Track the icon-picker selection ring through a simulator recording.

    scripts/video-ring-track.py build/shots/ui/motion.mov [start_s] [end_s]

Per frame (resampled to 60 fps) finds ring pixels inside the picker grid —
dark *and* coloured (sum of RGB < 470, channel spread > 40), so it keeps
following the ring while its colour interpolates between two tones — and
prints the centroid + pixel count whenever it changes. A glide = a run of
intermediate centroids over several frames; a teleport = one jump.
"""
import subprocess, sys

W, H = 402, 874
X0, X1, Y0, Y1 = 20, 382, 360, 570         # picker grid rows 1-2 (pt)


def is_ring(r, g, b):
    return r + g + b < 470 and max(r, g, b) - min(r, g, b) > 40


def main():
    path = sys.argv[1]
    start = float(sys.argv[2]) if len(sys.argv) > 2 else 0
    end = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
    cmd = ["ffmpeg", "-loglevel", "error"]
    if start: cmd += ["-ss", str(start)]
    if end < 1e9: cmd += ["-t", str(end - start)]
    cmd += ["-i", path, "-vf", f"fps=60,scale={W}:{H}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size, i, prev = W * H * 3, 0, None
    while True:
        b = p.stdout.read(size)
        if len(b) < size:
            break
        n = sx = sy = 0
        for y in range(Y0, Y1):
            base = y * W * 3
            for x in range(X0, X1):
                k = base + x * 3
                if is_ring(b[k], b[k + 1], b[k + 2]):
                    n += 1; sx += x; sy += y
        key = None if n < 25 else (round(sx / n / 4), round(sy / n / 4), n // 40)
        if key != prev:
            print(f"t={start + i / 60:7.3f}s  " + ("no ring" if key is None else f"centre=({sx / n:5.1f},{sy / n:5.1f}) n={n}"))
            prev = key
        i += 1


if __name__ == "__main__":
    main()
