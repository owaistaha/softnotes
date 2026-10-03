import React from "react";
import { AbsoluteFill, staticFile, useCurrentFrame } from "remotion";
import { Audio } from "@remotion/media";
import { Cam, WIDE, camAt, lerpCam } from "./camera";
import { NOTES } from "./data";
import { clamp01, ease, inOut, lerp, sp, SPRINGS } from "./anim";
import { FlowScreen } from "./Flow";
import { C, FONT, rgba } from "./theme";
import { EDIT_AT, NOTE_TEXT, SHOT3_QUERY, T, TIME_SCALE, typedCount } from "./timeline";
import { ChipSpec, HomeScreen, RowSpec } from "./ui/HomeScreen";
import { StackedIcon } from "./ui/Primitives";
import {
  AllNotesScreen,
  DetailOverlay,
  DetailState,
  SearchOverlay,
  TONE_DOTS,
} from "./ui/Screens";
import { Backdrop, Caption, PhoneWorld, TopFade } from "./ui/Stage";
import { Tone } from "./theme";

const LOGO_ICON = { tone: "lavender" as Tone, glyph: "note" };

/* ---------------- brand ---------------- */

const Wordmark: React.FC<{ size: number }> = ({ size }) => (
  <span
    style={{
      fontFamily: FONT,
      fontSize: size,
      fontWeight: 800,
      letterSpacing: -size * 0.035,
      color: C.ink,
      whiteSpace: "nowrap",
    }}
  >
    Soft<span style={{ color: C.lavInk }}>Notes</span>
  </span>
);

const Intro: React.FC<{ f: number }> = ({ f }) => {
  const logo = sp(f, T.logo, SPRINGS.bouncy);
  const word = sp(f, T.word, SPRINGS.pop);
  const wordA = ease(f, T.word, T.word + 5);
  const out = ease(f, T.introOut, 30);
  if (f > 31) return null;
  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        opacity: 1 - out,
        scale: String(1 + out * 1.6),
        filter: out > 0.02 ? `blur(${out * 22}px)` : undefined,
      }}
    >
      <div style={{ position: "absolute", top: 640, display: "flex", flexDirection: "column", alignItems: "center", gap: 70 }}>
        <div style={{ position: "relative" }}>
          {[0, 1].map((i) => {
            const r = ease(f, T.logo + i * 3, T.logo + 14 + i * 3);
            return (
              <div
                key={i}
                style={{
                  position: "absolute",
                  left: 150 - 150 * (1 + r * 1.2),
                  top: 150 - 150 * (1 + r * 1.2),
                  width: 300 * (1 + r * 1.2),
                  height: 300 * (1 + r * 1.2),
                  borderRadius: 120 * (1 + r),
                  border: `4px solid ${rgba("#9E81F6", 0.35)}`,
                  opacity: (1 - r) * (f >= T.logo + i * 3 ? 1 : 0),
                }}
              />
            );
          })}
          <div style={{ scale: String(logo), rotate: `${(1 - Math.min(logo, 1)) * -14}deg`, opacity: clamp01(logo * 3) }}>
            <StackedIcon size={300} icon={LOGO_ICON} glyphScale={0.46} />
          </div>
        </div>
        <div
          style={{
            scale: String(0.6 + 0.4 * word),
            opacity: wordA,
            filter: wordA < 1 ? `blur(${(1 - wordA) * 14}px)` : undefined,
            translate: `0 ${(1 - word) * 40}px`,
          }}
        >
          <Wordmark size={168} />
        </div>
      </div>
    </AbsoluteFill>
  );
};

/* ---------------- shared "finished" Home ---------------- */

const restChips = (f: number, start: number): ChipSpec[] => [
  { key: "B", icon: { tone: "pink", glyph: "basket", circle: true }, x: 127, y: 208, scale: sp(f, start + 2, SPRINGS.pop), opacity: 1, phase: 3 },
  { key: "N", icon: NOTES[0].icon, x: 205, y: 209, scale: sp(f, start, SPRINGS.pop), opacity: 1, phase: 0 },
  { key: "A", icon: { tone: "lavender", glyph: "plane", circle: true }, x: 259, y: 177, scale: sp(f, start + 4, SPRINGS.pop), opacity: 1, phase: 0 },
];

const restRows: RowSpec[] = [0, 1, 2].map((i) => ({
  key: NOTES[i].key,
  title: NOTES[i].title,
  time: NOTES[i].time,
  icon: NOTES[i].icon,
  tag: NOTES[i].tag,
  tagPop: 1,
  slot: i,
  enter: 1,
}));

const RestHome: React.FC<{ f: number; start: number; bounce?: number }> = ({ f, start, bounce = 0 }) => (
  <HomeScreen
    frame={f}
    chrome={1}
    open={0}
    bounce={bounce}
    count={{ from: 8, to: 9, roll: 1 }}
    toggle={1}
    chips={restChips(f, start)}
    rows={restRows}
  />
);

/* ---------------- montage ---------------- */

type ShotCam = { from: Pick<Cam, "s" | "fy">; to: Pick<Cam, "s" | "fy"> };
const SHOTS: ShotCam[] = [
  { from: { s: 2.5, fy: 270 }, to: { s: 2.8, fy: 270 } },
  { from: { s: 2.1, fy: 330 }, to: { s: 2.3, fy: 330 } },
  { from: { s: 2.5, fy: 190 }, to: { s: 2.8, fy: 190 } },
  { from: { s: 2.25, fy: 300 }, to: { s: 2.55, fy: 300 } },
];
const SHOT_END = [221, 232, 243, T.final];
const LABELS = ["Notes", "Organize", "Search", "Edit"];

const shotIndex = (f: number) => (f < T.montage[1] ? 0 : f < T.montage[2] ? 1 : f < T.montage[3] ? 2 : 3);

const shotCam = (f: number): Cam => {
  const i = shotIndex(f);
  const a = T.montage[i];
  const len = SHOT_END[i] - a;
  const t = ease(f, a, a + len, inOut);
  const c = SHOTS[i];
  return { s: Math.exp(lerp(Math.log(c.from.s), Math.log(c.to.s), t)), fx: 196.5, fy: lerp(c.from.fy, c.to.fy, t), cy: 1042 };
};

const shot4State = (f: number): DetailState => {
  const l = f - T.montage[3];
  const tones: Tone[] = ["orange", "green", "pink", "lavender"];
  const idx = Math.max(0, Math.floor(l / 3)) % 4;
  const tone = tones[idx];
  const popAt = T.montage[3] + 3 * Math.floor(Math.max(0, l) / 3);
  const heartP = f < 246 ? 1 : sp(f, 246, { damping: 8, stiffness: 300, mass: 0.5 });
  const text = NOTE_TEXT.slice(0, EDIT_AT) + "big " + NOTE_TEXT.slice(EDIT_AT);
  return {
    bg: 1,
    open: 1,
    rowIcon: { x: 0, y: 0 },
    text,
    caret: { from: text.length, to: text.length, t: 0, on: Math.floor(f / 7) % 2 === 0 ? 1 : 0.1 },
    navPops: [1, 1, 1],
    titleOpacity: 1,
    heart: f >= 246 ? 1 : 0,
    heartScale: f < 246 ? 1 : 1.4 - 0.4 * heartP,
    burst: f >= 246 && f < 257 ? (f - 246) / 11 : -1,
    tag: "work",
    tagPop: 1,
    tone,
    iconPop: 1.3 - 0.3 * sp(f, popAt, SPRINGS.snappy),
    palette: 1,
    paletteSel: TONE_DOTS.indexOf(tone),
  };
};

const MontageScreen: React.FC<{ f: number }> = ({ f }) => {
  const i = shotIndex(f);
  const start = T.montage[i];
  if (i === 0)
    return <RestHome f={f} start={start} bounce={0.035 * Math.sin(Math.PI * clamp01((f - start) / 10))} />;
  if (i === 1)
    return <AllNotesScreen f={f - start} tagPops={[0, 1, 2, 3, 4].map((k) => (f - start < 6 ? 0 : sp(f - start, 6 + k * 1.5, SPRINGS.pop)))} />;
  if (i === 2) {
    const n = typedCount(f, T.shot3Type, T.shot3Step, SHOT3_QUERY.length);
    return (
      <SearchOverlay
        f={f}
        expand={1}
        kb={1}
        query={SHOT3_QUERY.slice(0, n)}
        fullQuery={SHOT3_QUERY}
        typeStart={T.shot3Type}
        typeStep={T.shot3Step}
        rowsStart={-100}
        pressed={n > 0 ? SHOT3_QUERY[n - 1] : null}
        press={n > 0 ? Math.max(0, 1 - (f - (T.shot3Type + (n - 1) * T.shot3Step)) / 2) : 0}
        caretOn={n < SHOT3_QUERY.length ? 1 : Math.floor(f / 6) % 2 === 0 ? 1 : 0}
      />
    );
  }
  return <DetailOverlay s={shot4State(f)} icon={NOTES[0].icon} />;
};

/* ---------------- final ---------------- */

const FINAL_CAM: Cam = { s: 1.45, fx: 196.5, fy: 426, cy: 948 };

const Final: React.FC<{ f: number }> = ({ f }) => {
  const from = shotCam(T.final - 1);
  const t = ease(f, T.final, T.final + 24);
  const cam = lerpCam(from, FINAL_CAM, t);
  const bob = Math.sin(f / 14) * 4 * ease(f, 280, 295);
  const whip = 1 - ease(f, T.final, T.final + 6);
  const swapped = f >= T.final + 2;
  const logo = sp(f, 262, SPRINGS.bouncy);
  const l1 = sp(f, 268, SPRINGS.pop);
  const l2 = sp(f, 273, SPRINGS.pop);
  return (
    <>
      <PhoneWorld cam={{ ...cam, cy: cam.cy + bob }} blur={whip * 16}>
        {swapped ? (
          <RestHome f={f} start={T.final + 3} />
        ) : (
          <DetailOverlay s={shot4State(f)} icon={NOTES[0].icon} />
        )}
      </PhoneWorld>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 118,
          width: 1080,
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: 26,
          scale: String(Math.min(logo, 1.08)),
          opacity: clamp01(logo * 3),
        }}
      >
        <StackedIcon size={118} icon={LOGO_ICON} glyphScale={0.46} />
        <Wordmark size={112} />
      </div>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 1608,
          width: 1080,
          textAlign: "center",
          fontFamily: FONT,
          fontSize: 86,
          lineHeight: "100px",
          fontWeight: 800,
          letterSpacing: -3,
          color: C.ink,
        }}
      >
        {[
          { t: "Everything you need.", p: l1, c: C.ink },
          { t: "One simple place.", p: l2, c: C.lavInk },
        ].map((l, i) => (
          <div
            key={i}
            style={{
              color: l.c,
              translate: `0 ${(1 - l.p) * 44}px`,
              opacity: clamp01(l.p * 2.5),
              scale: String(0.94 + 0.06 * Math.min(l.p, 1.1)),
              filter: l.p < 0.9 ? `blur(${(1 - l.p) * 10}px)` : undefined,
            }}
          >
            {l.t}
          </div>
        ))}
      </div>
    </>
  );
};

/* ---------------- the video ---------------- */

export const Promo: React.FC = () => {
  // animation clock: logical frames (fractional), TIME_SCALE× slower than the render
  const f = useCurrentFrame() / TIME_SCALE;

  const inFlow = f < T.montage[0];
  const inMontage = f >= T.montage[0] && f < T.final;
  const phoneIn = ease(f, T.phoneIn, T.phoneIn + 12);

  const flowCam = camAt(f);
  const mCam = shotCam(f);
  const shotStart = T.montage[shotIndex(f)];
  const punch = 1 - ease(f, shotStart, shotStart + 7);
  const mCamPunched: Cam = { ...mCam, s: mCam.s * (1 + 0.14 * punch) };

  return (
    <AbsoluteFill style={{ backgroundColor: "#F2F1F8" }}>
      <Audio src={staticFile("mix.wav")} />
      <Backdrop frame={f} />

      {inFlow && (
        <>
          <PhoneWorld cam={flowCam} opacity={phoneIn} blur={(1 - phoneIn) * 10}>
            <FlowScreen f={f} />
          </PhoneWorld>
          <TopFade s={flowCam.s} />
          <Caption frame={f} words={["Write", "it", "down."]} start={30} end={75} accent={2} />
          <Caption frame={f} words={["Neatly", "organized."]} start={75} end={120} accent={1} />
          <Caption frame={f} words={["Find", "it", "instantly."]} start={120} end={165} accent={2} />
          <Caption frame={f} words={["Edit", "anything."]} start={165} end={210} accent={1} />
          <Intro f={f} />
        </>
      )}

      {inMontage && (
        <>
          <PhoneWorld cam={mCamPunched} blur={punch * 12}>
            <MontageScreen f={f} />
          </PhoneWorld>
          {LABELS.map((label, i) => (
            <Caption
              key={label}
              frame={f}
              words={[label]}
              start={T.montage[i]}
              end={SHOT_END[i]}
              size={128}
              top={70}
              accent={0}
            />
          ))}
        </>
      )}

      {f >= T.final && <Final f={f} />}
    </AbsoluteFill>
  );
};

export { WIDE };
