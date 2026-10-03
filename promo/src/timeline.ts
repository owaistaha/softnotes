// SINGLE SOURCE OF TRUTH for timing.
// All frame numbers below are LOGICAL frames (the animation clock, 30 per
// second of design time). The video plays them TIME_SCALE× slower: the render
// is 30 fps, so 300 logical frames × 2 = 600 rendered frames = 20.0 s.
// Plain TS with no imports: scripts/mix-audio.ts reads the same file, so every
// sound effect lands on the exact frame (sub-frame precision) of its animation.

export const FPS = 30;
export const DURATION = 300; // logical frames
export const TIME_SCALE = 2; // 2 → 20 s video
export const TOTAL_FRAMES = DURATION * TIME_SCALE;
export const W = 1080;
export const H = 1920;

export const NOTE_TEXT = "Plan the launch party";
export const EDIT_INSERT = "big ";
export const EDIT_AT = 9; // caret index in "Plan the |launch party"
export const QUERY = "launch";
export const SHOT3_QUERY = "cherries";

export const T = {
  // 0.0–1.0s  brand intro
  logo: 1,
  word: 8,
  introOut: 19,
  phoneIn: 15,
  // 1.0–2.5s  create
  fabTap: 33,
  composeIn: 34,
  kbUp: 40,
  typeStart: 46,
  typeStep: 1.05,
  nextTap: 70,
  // 2.5–4.0s  organise (settle → lift → fold → file)
  settle: 71,
  lift: 79,
  foldStart: 84,
  foldEnd: 92,
  rise: 92,
  drop: 97,
  land: 102,
  countRoll: 100,
  toggleOn: 104,
  zoomOut: 105,
  chromeIn: 107,
  rowIn: 112,
  tags: [114, 117, 120],
  // 4.0–5.5s  search
  searchTap: 122,
  searchExpand: 123,
  searchKb: 126,
  searchType: 138,
  searchStep: 1.8,
  searchZoom: 150,
  // 5.5–7.0s  edit / manage
  rowTap: 163,
  detailIn: 164,
  navPops: [168, 170, 172],
  caretIn: 172,
  caretMoveStart: 176,
  caretMoveEnd: 181,
  editType: 182,
  editStep: 2,
  heart: 191,
  tagCycle: 196,
  iconTap: 200,
  tonePick: 204,
  // 7.0–8.5s  montage (4 shots)
  montage: [210, 221, 232, 243],
  shot3Type: 233,
  shot3Step: 1,
  // 8.5–10.0s final
  final: 255,
} as const;

export const typedCount = (
  f: number,
  start: number,
  step: number,
  total: number,
) => Math.min(total, Math.max(0, Math.floor((f - start) / step) + 1));

export type Sfx =
  | "pop"
  | "popHi"
  | "popLo"
  | "click"
  | "tick1"
  | "tick2"
  | "tick3"
  | "whoosh"
  | "whooshSm"
  | "thump"
  | "thock"
  | "swish"
  | "ding"
  | "sparkle";

export type SfxEvent = { f: number; s: Sfx; v: number; pan?: number };

const ticks = (
  start: number,
  step: number,
  n: number,
  v = 0.5,
): SfxEvent[] =>
  Array.from({ length: n }, (_, i) => ({
    f: start + i * step,
    s: (["tick1", "tick2", "tick3"] as const)[(i * 7 + 1) % 3],
    v: v * (0.85 + 0.15 * ((i * 5) % 3) / 2),
    pan: ((i % 5) - 2) * 0.04,
  }));

export const SFX: SfxEvent[] = [
  // brand intro
  { f: T.logo, s: "popLo", v: 0.9 },
  { f: T.logo + 3, s: "popHi", v: 0.35 },
  { f: T.word, s: "pop", v: 0.7 },
  { f: 17, s: "whoosh", v: 0.7 },
  // create
  { f: T.fabTap, s: "click", v: 0.9 },
  { f: T.composeIn + 0.5, s: "pop", v: 0.8 },
  { f: T.composeIn + 1, s: "whooshSm", v: 0.5 },
  { f: T.kbUp + 1, s: "thock", v: 0.6 },
  ...ticks(T.typeStart, T.typeStep, NOTE_TEXT.length, 0.5),
  { f: 61, s: "whooshSm", v: 0.4 },
  { f: T.nextTap, s: "click", v: 0.9 },
  { f: T.nextTap + 1, s: "pop", v: 0.7 },
  { f: T.settle, s: "whooshSm", v: 0.55 },
  // organise
  { f: T.lift + 0.5, s: "popHi", v: 0.6 },
  { f: T.foldStart, s: "swish", v: 0.8 },
  { f: T.foldEnd - 0.5, s: "click", v: 0.55 },
  { f: T.rise, s: "whoosh", v: 0.65 },
  { f: T.drop, s: "whooshSm", v: 0.5 },
  { f: T.land - 1, s: "thump", v: 0.85 },
  { f: T.land, s: "pop", v: 0.9 },
  { f: T.countRoll + 1, s: "tick2", v: 0.55 },
  { f: T.toggleOn, s: "click", v: 0.6 },
  { f: T.toggleOn + 1, s: "ding", v: 0.45 },
  { f: T.zoomOut, s: "whoosh", v: 0.6 },
  { f: T.rowIn, s: "pop", v: 0.7 },
  { f: T.tags[0], s: "popHi", v: 0.5 },
  { f: T.tags[1], s: "pop", v: 0.5 },
  { f: T.tags[2], s: "popHi", v: 0.55 },
  // search
  { f: T.searchTap, s: "click", v: 0.9 },
  { f: T.searchExpand, s: "pop", v: 0.7 },
  { f: T.searchExpand, s: "whooshSm", v: 0.4 },
  { f: T.searchKb + 1, s: "thock", v: 0.6 },
  ...ticks(T.searchType, T.searchStep, QUERY.length, 0.5),
  { f: 149, s: "click", v: 0.85 },
  { f: 149.5, s: "popHi", v: 0.75 },
  { f: T.searchZoom, s: "whoosh", v: 0.5 },
  // edit / manage
  { f: T.rowTap, s: "click", v: 0.9 },
  { f: T.detailIn, s: "pop", v: 0.8 },
  { f: T.detailIn, s: "whoosh", v: 0.5 },
  { f: T.navPops[0], s: "popHi", v: 0.4 },
  { f: T.navPops[1], s: "popHi", v: 0.45 },
  { f: T.navPops[2], s: "popHi", v: 0.5 },
  { f: 174, s: "click", v: 0.6 },
  ...ticks(T.editType, T.editStep, EDIT_INSERT.length, 0.55),
  { f: T.heart, s: "pop", v: 1 },
  { f: T.heart + 1, s: "sparkle", v: 0.3 },
  { f: T.tagCycle, s: "click", v: 0.8 },
  { f: T.tagCycle + 0.5, s: "pop", v: 0.6 },
  { f: T.iconTap, s: "click", v: 0.7 },
  { f: T.iconTap + 1, s: "pop", v: 0.7 },
  { f: T.tonePick, s: "click", v: 0.7 },
  { f: T.tonePick + 0.5, s: "popHi", v: 0.7 },
  // montage
  ...T.montage.flatMap((f, i): SfxEvent[] => [
    { f, s: "whoosh", v: 0.7 },
    { f: f + 0.5, s: "pop", v: 0.8 },
    { f: f + 3, s: i % 2 ? "popHi" : "popLo", v: 0.4 },
  ]),
  ...ticks(T.shot3Type, T.shot3Step, SHOT3_QUERY.length, 0.4),
  { f: 248, s: "pop", v: 0.7 },
  // final
  { f: T.final, s: "whoosh", v: 1 },
  { f: 262, s: "pop", v: 0.9 },
  { f: 268, s: "popHi", v: 0.55 },
  { f: 273, s: "popHi", v: 0.6 },
  { f: 277, s: "ding", v: 0.55 },
  { f: 280, s: "sparkle", v: 0.45 },
];
