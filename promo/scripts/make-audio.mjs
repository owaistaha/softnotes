// Synthesises every sound effect and mixes them onto the timeline defined in
// src/timeline.ts (sub-frame accurate) → public/mix.wav.   node scripts/make-audio.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { SFX, FPS, DURATION, TIME_SCALE } from "../src/timeline.ts";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SR = 48000;
const TOTAL = Math.ceil(((DURATION * TIME_SCALE) / FPS) * SR);

let seed = 20261003;
const rnd = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296) * 2 - 1;

const make = (dur, fn) => {
  const n = Math.floor(dur * SR);
  const a = new Float32Array(n);
  for (let i = 0; i < n; i++) a[i] = fn(i / SR);
  return a;
};

// RBJ biquad
const filt = (arr, type, f0, Q = 0.707) => {
  const w = (2 * Math.PI * f0) / SR;
  const cos = Math.cos(w);
  const al = Math.sin(w) / (2 * Q);
  let b0, b1, b2;
  if (type === "lp") { b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = b0; }
  else if (type === "hp") { b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = b0; }
  else { b0 = al; b1 = 0; b2 = -al; }
  const a0 = 1 + al, a1 = -2 * cos, a2 = 1 - al;
  const out = new Float32Array(arr.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < arr.length; i++) {
    const x = arr[i];
    const y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
    out[i] = y; x2 = x1; x1 = x; y2 = y1; y1 = y;
  }
  return out;
};
const add = (a, b, gain = 1, off = 0) => {
  for (let i = 0; i < b.length && i + off < a.length; i++) a[i + off] += b[i] * gain;
  return a;
};
const normalise = (a, peak = 0.9) => {
  let m = 0;
  for (const v of a) m = Math.max(m, Math.abs(v));
  const g = m > 0 ? peak / m : 1;
  return a.map((v) => v * g);
};

const att = (t, a = 0.0012) => Math.min(1, t / a);

const popGen = ({ base, sweep, tau, decay, dur }) =>
  normalise(
    make(dur, (t) => {
      const ph = 2 * Math.PI * (base * t + sweep * tau * (1 - Math.exp(-t / tau)));
      return (
        (Math.sin(ph) * Math.exp(-t * decay) + 0.28 * Math.sin(2 * ph) * Math.exp(-t * decay * 2.2)) * att(t) +
        0.12 * rnd() * Math.exp(-t * 1800)
      );
    }),
  );

const tickGen = (F, dur = 0.045) =>
  normalise(
    filt(
      filt(
        make(dur, (t) => 0.55 * rnd() * Math.exp(-t * 1000) + 0.7 * Math.sin(2 * Math.PI * F * t) * Math.exp(-t * 650)),
        "hp",
        500,
      ),
      "lp",
      8000,
    ),
  );

const noiseEnv = (dur, env) => make(dur, (t) => rnd() * env(t));

const bell = (freq, decay, dur, delay = 0) =>
  make(dur, (t) => {
    const u = t - delay;
    if (u < 0) return 0;
    return (
      (Math.sin(2 * Math.PI * freq * u) + 0.3 * Math.sin(2 * Math.PI * freq * 2.01 * u) * Math.exp(-u * 4)) *
      Math.exp(-u * decay) *
      att(u, 0.003)
    );
  });

const SOUNDS = {
  pop: popGen({ base: 240, sweep: 520, tau: 0.018, decay: 24, dur: 0.22 }),
  popHi: popGen({ base: 430, sweep: 900, tau: 0.014, decay: 30, dur: 0.18 }),
  popLo: popGen({ base: 150, sweep: 380, tau: 0.022, decay: 18, dur: 0.32 }),
  click: normalise(
    filt(
      make(0.06, (t) =>
        0.55 * Math.sin(2 * Math.PI * 3200 * t) * Math.exp(-t * 900) +
        0.5 * rnd() * Math.exp(-t * 1400) +
        0.35 * Math.sin(2 * Math.PI * 1100 * t) * Math.exp(-t * 300),
      ),
      "hp",
      450,
    ),
  ),
  tick1: tickGen(1700),
  tick2: tickGen(2100),
  tick3: tickGen(1450),
  thock: normalise(
    add(
      make(0.2, (t) => Math.sin(2 * Math.PI * (88 * t + 170 * 0.025 * (1 - Math.exp(-t / 0.025)))) * Math.exp(-t * 26) * att(t, 0.002)),
      filt(make(0.05, (t) => rnd() * Math.exp(-t * 200)), "lp", 1800),
      0.3,
    ),
  ),
  thump: normalise(
    make(0.38, (t) => Math.sin(2 * Math.PI * (48 * t + 120 * 0.03 * (1 - Math.exp(-t / 0.03)))) * Math.exp(-t * 13) * att(t, 0.002)),
    0.95,
  ),
  swish: normalise(
    filt(filt(noiseEnv(0.3, (t) => Math.pow(Math.sin((Math.PI * t) / 0.3), 2) * 0.9), "bp", 3600, 0.6), "hp", 1200),
  ),
  whooshSm: (() => {
    const d = 0.4;
    const env = (t) => Math.pow(Math.sin((Math.PI * Math.min(1, t / d))), 1.8);
    const lo = filt(noiseEnv(d, (t) => env(t) * (1 - t / d)), "bp", 900, 0.55);
    const hi = filt(noiseEnv(d, (t) => env(t) * (t / d)), "bp", 3200, 0.55);
    return normalise(add(lo, hi));
  })(),
  whoosh: (() => {
    const d = 0.75;
    const env = (t) => (t < 0.28 ? Math.pow(t / 0.28, 1.6) : Math.exp(-(t - 0.28) * 5.5));
    const lo = filt(noiseEnv(d, (t) => env(t) * Math.max(0, 1 - t / 0.5)), "bp", 700, 0.5);
    const mid = filt(noiseEnv(d, (t) => env(t) * 0.8), "bp", 1800, 0.45);
    const hi = filt(noiseEnv(d, (t) => env(t) * Math.min(1, t / 0.4)), "bp", 4600, 0.5);
    return normalise(add(add(lo, mid), hi));
  })(),
  ding: normalise(add(bell(1568, 6, 1.1), bell(2093, 7, 1.1, 0.085), 0.8)),
  sparkle: normalise(
    [2093, 2637, 3136, 4186].reduce((acc, f, i) => add(acc, bell(f, 9, 0.9, i * 0.045), 1 - i * 0.12), new Float32Array(Math.floor(0.9 * SR))),
  ),
};

// per-sound base level
const BASE = {
  pop: 0.8, popHi: 0.7, popLo: 0.85, click: 0.55, tick1: 0.5, tick2: 0.5, tick3: 0.5,
  thock: 0.7, thump: 0.9, swish: 0.55, whooshSm: 0.5, whoosh: 0.6, ding: 0.45, sparkle: 0.4,
};

const L = new Float32Array(TOTAL);
const R = new Float32Array(TOTAL);
for (const ev of SFX) {
  const src = SOUNDS[ev.s];
  const off = Math.round(((ev.f * TIME_SCALE) / FPS) * SR);
  const g = (BASE[ev.s] ?? 0.6) * ev.v;
  const pan = (ev.pan ?? 0) * 0.5 + 0.5;
  const gl = Math.cos((pan * Math.PI) / 2) * Math.SQRT2 * 0.707;
  const gr = Math.sin((pan * Math.PI) / 2) * Math.SQRT2 * 0.707;
  add(L, src, g * gl, off);
  add(R, src, g * gr, off);
}

// soft limiter + peak normalise to -2 dBFS, 20 ms fade at the very end
let peak = 0;
for (let i = 0; i < TOTAL; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const scale = peak > 0 ? 0.8 / peak : 1;
const pcm = Buffer.alloc(TOTAL * 4);
for (let i = 0; i < TOTAL; i++) {
  const fade = Math.min(1, (TOTAL - i) / (0.02 * SR));
  const l = Math.tanh(L[i] * scale * 1.15) * fade;
  const r = Math.tanh(R[i] * scale * 1.15) * fade;
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, l)) * 32767), i * 4);
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, r)) * 32767), i * 4 + 2);
}
const head = Buffer.alloc(44);
head.write("RIFF", 0); head.writeUInt32LE(36 + pcm.length, 4); head.write("WAVE", 8);
head.write("fmt ", 12); head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(2, 22);
head.writeUInt32LE(SR, 24); head.writeUInt32LE(SR * 4, 28); head.writeUInt16LE(4, 32); head.writeUInt16LE(16, 34);
head.write("data", 36); head.writeUInt32LE(pcm.length, 40);
const out = path.join(root, "public", "mix.wav");
fs.writeFileSync(out, Buffer.concat([head, pcm]));
console.log(`wrote ${out}: ${SFX.length} events, ${(TOTAL / SR).toFixed(2)} s, pre-limit peak ${peak.toFixed(2)}`);
