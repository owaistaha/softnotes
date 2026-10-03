import { ease, lerp } from "./anim";

export type Cam = { s: number; fx: number; fy: number; cy: number };

/** `fx, fy` = phone point (pt) that sits at screen (540, cy); `s` = px per pt. */
const W_: Cam = { s: 2.0, fx: 196.5, fy: 426, cy: 1042 };
export const WIDE = W_;

type K = { f: number } & Cam;
const k = (f: number, c: Partial<Cam> = {}): K => ({ f, ...W_, ...c });

// Keyframes: each segment eases (expo-out) from the previous key to this one.
// Equal consecutive keys are holds.
const KEYS: K[] = [
  k(0, { s: 1.25 }),
  k(15, { s: 1.25 }),
  k(34), // zoom into the app
  k(58),
  k(68, { s: 2.5, fy: 330 }), // quick zoom toward the note
  k(71, { s: 2.5, fy: 330 }),
  k(80, { s: 2.6, fy: 405 }), // settle, lift, fold
  k(90, { s: 2.6, fy: 405 }),
  k(96, { s: 2.9, fy: 250 }), // onto the folder
  k(104, { s: 2.9, fy: 250 }),
  k(121), // zoom out to reveal the list
  k(150),
  k(158, { s: 2.7, fy: 215 }), // search result zoom
  k(163, { s: 2.7, fy: 215 }),
  k(174, { s: 2.3, fy: 330 }), // edit
  k(209, { s: 2.3, fy: 330 }),
];

export const camAt = (f: number): Cam => {
  if (f <= KEYS[0].f) return KEYS[0];
  for (let i = 0; i < KEYS.length - 1; i++) {
    const a = KEYS[i];
    const b = KEYS[i + 1];
    if (f >= a.f && f < b.f) {
      const t = ease(f, a.f, b.f);
      return {
        s: Math.exp(lerp(Math.log(a.s), Math.log(b.s), t)),
        fx: lerp(a.fx, b.fx, t),
        fy: lerp(a.fy, b.fy, t),
        cy: lerp(a.cy, b.cy, t),
      };
    }
  }
  return KEYS[KEYS.length - 1];
};

export const lerpCam = (a: Cam, b: Cam, t: number): Cam => ({
  s: Math.exp(lerp(Math.log(a.s), Math.log(b.s), t)),
  fx: lerp(a.fx, b.fx, t),
  fy: lerp(a.fy, b.fy, t),
  cy: lerp(a.cy, b.cy, t),
});
