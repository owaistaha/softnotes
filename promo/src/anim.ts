import { Easing, interpolate, spring } from "remotion";

export const FPS = 30;

export const expoOut = Easing.bezier(0.22, 1, 0.36, 1);
export const inOut = Easing.bezier(0.65, 0, 0.35, 1);
export const easeIn = Easing.bezier(0.5, 0, 0.9, 0.4);

/** 0 → 1 between frames a and b, clamped. */
export const ease = (
  f: number,
  a: number,
  b: number,
  easing: (t: number) => number = expoOut,
) =>
  interpolate(f, [a, b], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing,
  });

export const SPRINGS = {
  /** small UI state — tiny overshoot */
  snappy: { damping: 15, stiffness: 260, mass: 0.7 },
  /** things that pop in */
  pop: { damping: 11, stiffness: 230, mass: 0.6 },
  /** big bouncy logo / landing */
  bouncy: { damping: 9, stiffness: 160, mass: 0.8 },
  /** no overshoot */
  crisp: { damping: 30, stiffness: 260, mass: 0.8 },
};

/** Spring 0 → 1 (overshoots for the bouncy presets) starting at frame `start`. */
export const sp = (
  f: number,
  start: number,
  cfg: Partial<(typeof SPRINGS)["pop"]> = SPRINGS.pop,
) =>
  f < start
    ? 0
    : spring({ frame: f - start, fps: FPS, config: { ...SPRINGS.pop, ...cfg } });

export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

/** 1 at `at`, decaying to 0 over `len` frames — a button-press envelope. */
export const pulse = (f: number, at: number, len = 6) =>
  f < at ? 0 : Math.max(0, 1 - (f - at) / len);
