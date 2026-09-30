#!/usr/bin/env python3
"""Measure the FAB / Next disc in exported UI-test screenshots.

    scripts/fab-morph-stats.py build/shots/ui [prefix ...]

For each PNG (optionally filtered by file-name prefix) prints the dark disc's
size, centre (px/3 ≈ pt on a 3x phone) and "core darkness" (0–255 gray of the
darkest quarter of its pixels; a solid ink disc ≈ 23, lower is more opaque).
Use it to tell a solid glide from a cross-dissolve or a pop.
"""
import glob, os, subprocess, sys

W, H = 1206, 2622          # iPhone 17 Pro screenshot size


def gray(path):
    return subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "gray", "-"],
        capture_output=True).stdout


def disc(path):
    g = gray(path)
    xs, ys, vals = [], [], []
    for y in range(int(H * 0.66), H - 40):
        row = g[y * W:(y + 1) * W]
        for x in range(int(W * 0.30), int(W * 0.70)):
            if row[x] < 150:
                xs.append(x); ys.append(y); vals.append(row[x])
    if not xs:
        return None
    n = len(xs)
    dark = sorted(vals)[:max(1, n // 4)]
    return n, round(sum(xs) / n / 3), round(sum(ys) / n / 3), sum(dark) // len(dark)


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "build/shots/ui"
    prefixes = sys.argv[2:]
    for path in sorted(glob.glob(os.path.join(folder, "*.png"))):
        name = os.path.basename(path)[:-4]
        if prefixes and not any(name.startswith(p) for p in prefixes):
            continue
        r = disc(path)
        print(f"{name:34s}", f"px={r[0]:6d}  centre=({r[1]},{r[2]})  core={r[3]}" if r else "no dark disc")


if __name__ == "__main__":
    main()
