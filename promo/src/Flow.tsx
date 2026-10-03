import React from "react";
import { Easing } from "remotion";
import { clamp01, ease, easeIn, inOut, lerp, pulse, sp, SPRINGS } from "./anim";
import { NEW_ICON, NOTES } from "./data";
import {
  EDIT_AT,
  EDIT_INSERT,
  NOTE_TEXT,
  QUERY,
  T,
  typedCount,
} from "./timeline";
import {
  CENTER_SLOT,
  ChipSpec,
  FabDisc,
  HomeScreen,
  RowSpec,
} from "./ui/HomeScreen";
import { CARD_H, CARD_W, FoldingCard, caretPos } from "./ui/NoteCard";
import { StatusBar, StackedIcon, Touch } from "./ui/Primitives";
import {
  ComposeOverlay,
  ComposeState,
  DETAIL,
  DetailOverlay,
  DetailState,
  PALETTE,
  SEARCH_ROW_TOP,
  SearchOverlay,
  paletteDot,
} from "./ui/Screens";

/* ================================================================== */
/* Home                                                                */
/* ================================================================== */

const open = (f: number) => ease(f, 91, 94) * (1 - ease(f, 104, 108));

const chipsAt = (f: number): ChipSpec[] => {
  const p = ease(f, 90, 96);
  return [
    { key: "A", icon: { tone: "lavender", glyph: "plane", circle: true }, x: lerp(127, 259, p), y: lerp(208, 177, p), scale: 1, opacity: 1, phase: 0 },
    { key: "B", icon: { tone: "pink", glyph: "basket", circle: true }, x: lerp(205, 127, p), y: lerp(209, 208, p), scale: 1, opacity: 1, phase: 3 },
    { key: "C", icon: { tone: "orange", glyph: "book" }, x: 259, y: lerp(177, 150, p), scale: 1 - 0.4 * p, opacity: 1 - p, phase: 6 },
    { key: "N", icon: NEW_ICON, x: CENTER_SLOT.x, y: CENTER_SLOT.y, scale: 1, opacity: f >= T.land ? 1 : 0, phase: 0 },
  ];
};

const rowsAt = (f: number): RowSpec[] => {
  const shift = f < T.rowIn ? 0 : clamp01(sp(f, T.rowIn, { damping: 24, stiffness: 420, mass: 0.6 }));
  const enter = ease(f, T.rowIn, T.rowIn + 9);
  const tg = (i: number) => (f < T.tags[i] ? 0 : sp(f, T.tags[i], SPRINGS.pop));
  const [n, c, l] = [NOTES[0], NOTES[1], NOTES[2]];
  return [
    { key: n.key, title: n.title, time: n.time, icon: n.icon, tag: n.tag, tagPop: tg(0), slot: 0, enter },
    { key: c.key, title: c.title, time: c.time, icon: c.icon, tag: c.tag, tagPop: tg(1), slot: shift, enter: 1 },
    { key: l.key, title: l.title, time: l.time, icon: l.icon, tag: l.tag, tagPop: tg(2), slot: 1 + shift, enter: 1 },
  ];
};

const bounceAt = (f: number) =>
  0.035 * Math.sin(Math.PI * clamp01((f - T.land) / 10));

const homeChrome = (f: number) => (f < 91 ? 1 : ease(f, T.chromeIn, T.chromeIn + 9));

/* ================================================================== */
/* Compose                                                             */
/* ================================================================== */

const composeAt = (f: number): ComposeState => {
  const n = typedCount(f, T.typeStart, T.typeStep, NOTE_TEXT.length);
  const lastT = T.typeStart + (n - 1) * T.typeStep;
  return {
    bg: ease(f, 34, 39) * (1 - ease(f, 91, 95)),
    enter: ease(f, T.composeIn, T.composeIn + 12),
    k: ease(f, T.kbUp, T.kbUp + 10),
    kbDrop: ease(f, T.settle, T.settle + 7),
    titleOpacity: ease(f, 35, 42) * (1 - ease(f, 73, 78)),
    navOpacity: ease(f, 35, 40) * (1 - ease(f, 40, 46)),
    text: NOTE_TEXT.slice(0, n),
    caretOn: f < T.typeStart ? (Math.floor((f - 44) / 6) % 2 === 0 ? 1 : 0.15) : 1,
    pressed: n > 0 ? NOTE_TEXT[n - 1].toLowerCase() : null,
    press: n > 0 ? pulse(f, lastT, 3) : 0,
    showCard: f < T.nextTap,
    icon: NEW_ICON,
  };
};

/* ================================================================== */
/* Flying card (settle → lift → fold → rise → drop behind the folder)  */
/* ================================================================== */

const foldEase = Easing.bezier(0.3, 0.2, 0.5, 0.95);
const FOLD_Y = 414; // icon height on the fold line

const flightAt = (f: number) => {
  const s = ease(f, T.settle, T.settle + 8);
  const r = ease(f, T.rise, T.rise + 5);
  const d = ease(f, T.drop, T.land, inOut);
  const cyA = lerp(283, 426, s);
  const cy = f < T.rise ? cyA : f < T.drop ? lerp(426, 84, r) : lerp(84, 264, d);
  const sc = lerp(1.12, 1.025, s) * lerp(1, 0.86, d);
  const rot = lerp(-1.5, 0, s);
  const angle = ease(f, T.foldStart, T.foldEnd, foldEase) * 180;
  // ----- the travelling icon
  const rad = (rot * Math.PI) / 180;
  const ox = -86 * sc;
  const oy = -99 * sc;
  const header = {
    x: 196.5 + ox * Math.cos(rad) - oy * Math.sin(rad),
    y: cyA + ox * Math.sin(rad) + oy * Math.cos(rad),
  };
  const liftP = f < T.lift ? 0 : sp(f, T.lift, { damping: 13, stiffness: 320, mass: 0.55 });
  const liftTarget = { x: 196.5, y: 426 - (CARD_H / 2) * 1.025 - 30 };
  let ix = lerp(header.x, liftTarget.x, liftP);
  let iy = lerp(header.y, liftTarget.y, liftP);
  let isz = lerp(32 * sc, 64, clamp01(liftP) + 0 * liftP);
  if (f >= T.foldStart) iy = lerp(iy, FOLD_Y, ease(f, T.foldStart, T.foldEnd, foldEase));
  if (f >= T.rise) iy = FOLD_Y + (f < T.drop ? lerp(426, 84, r) - 426 : 84 - 426);
  if (f >= T.drop) {
    const bob = Math.sin(T.land / 11) * 2.4;
    const end = { x: CENTER_SLOT.x, y: CENTER_SLOT.y - 14 * open(T.land) + bob };
    ix = lerp(196.5, end.x, d);
    iy = lerp(FOLD_Y + 84 - 426, end.y, d);
    isz = lerp(64, 48, d);
  }
  return {
    visible: f >= T.nextTap && f < T.land + 1,
    cy,
    sc,
    rot,
    angle,
    opacity: 1 - ease(f, T.land - 1.5, T.land + 0.5),
    blur: d * 6,
    icon: { x: ix, y: iy, size: isz, visible: f >= T.nextTap && f < T.land },
  };
};

/* ================================================================== */
/* Search                                                              */
/* ================================================================== */

const searchAt = (f: number) => {
  const n = typedCount(f, T.searchType, T.searchStep, QUERY.length);
  const lastT = T.searchType + (n - 1) * T.searchStep;
  return {
    expand: ease(f, T.searchExpand, T.searchExpand + 9),
    kb: ease(f, T.searchKb, T.searchKb + 10),
    query: QUERY.slice(0, n),
    pressed: n > 0 ? QUERY[n - 1] : null,
    press: n > 0 ? pulse(f, lastT, 3) : 0,
    caretOn: f < T.searchExpand + 6 ? 0 : 1,
  };
};

/* ================================================================== */
/* Detail                                                              */
/* ================================================================== */

const detailAt = (f: number): DetailState => {
  const n = typedCount(f, T.editType, T.editStep, EDIT_INSERT.length);
  const text =
    NOTE_TEXT.slice(0, EDIT_AT) + EDIT_INSERT.slice(0, n) + NOTE_TEXT.slice(EDIT_AT);
  let caret: DetailState["caret"];
  if (f >= T.caretIn) {
    if (f < T.caretMoveEnd) {
      caret = {
        from: NOTE_TEXT.length,
        to: EDIT_AT,
        t: ease(f, T.caretMoveStart, T.caretMoveEnd, inOut),
        on: 1,
      };
    } else {
      const typing = f < T.editType + EDIT_INSERT.length * T.editStep + 3;
      caret = {
        from: EDIT_AT + n,
        to: EDIT_AT + n,
        t: 0,
        on: typing ? 1 : Math.floor((f - 190) / 7) % 2 === 0 ? 1 : 0.1,
      };
    }
  }
  const tagSwap = f >= T.tagCycle + 3;
  const tagPop =
    f < T.tagCycle
      ? 1
      : f < T.tagCycle + 3
        ? lerp(1, 0.7, (f - T.tagCycle) / 3)
        : 0.7 + 0.3 * sp(f, T.tagCycle + 3, SPRINGS.pop);
  const heartP = f < T.heart ? 1 : sp(f, T.heart, { damping: 8, stiffness: 300, mass: 0.5 });
  const toneOn = f >= T.tonePick + 1;
  return {
    bg: ease(f, T.detailIn, T.detailIn + 6),
    open: ease(f, T.detailIn, T.detailIn + 12),
    rowIcon: { x: 46, y: SEARCH_ROW_TOP + 29 },
    text,
    caret,
    navPops: [
      sp(f, T.navPops[0], SPRINGS.pop),
      sp(f, T.navPops[1], SPRINGS.pop),
      sp(f, T.navPops[2], SPRINGS.pop),
    ],
    titleOpacity: ease(f, 166, 172),
    heart: f >= T.heart ? 1 : 0,
    heartScale: f < T.heart ? 1 : 1.4 - 0.4 * heartP,
    burst: f >= T.heart && f < T.heart + 11 ? (f - T.heart) / 11 : -1,
    tag: tagSwap ? "work" : "daily",
    tagPop,
    tone: toneOn ? "orange" : "blue",
    iconPop: toneOn ? 1.3 - 0.3 * sp(f, T.tonePick + 1, SPRINGS.snappy) : 1,
    palette: sp(f, T.iconTap + 1, SPRINGS.pop) * (1 - ease(f, T.tonePick + 4, T.tonePick + 8)),
    paletteSel: f >= T.tonePick ? 2 : 0,
  };
};

const detailCardToWorld = (text: string, idx: number) => {
  const c = caretPos(text, idx);
  return {
    x: DETAIL.cx + (c.x - CARD_W / 2) * DETAIL.sc,
    y: DETAIL.cy + (c.y + 13 - CARD_H / 2) * DETAIL.sc,
  };
};

/* ================================================================== */
/* Finger                                                              */
/* ================================================================== */

type WP = { f: number; x: number; y: number; o: number };
const PATH: WP[] = [
  { f: 27, x: 262, y: 840, o: 0 },
  { f: 29, x: 236, y: 800, o: 1 },
  { f: 33, x: 196.5, y: 746, o: 1 },
  { f: 37, x: 196.5, y: 746, o: 0 },
  { f: 62, x: 250, y: 560, o: 0 },
  { f: 65, x: 232, y: 520, o: 1 },
  { f: 70, x: 196.5, y: 475, o: 1 },
  { f: 74, x: 196.5, y: 475, o: 0 },
  { f: 116, x: 300, y: 240, o: 0 },
  { f: 118, x: 322, y: 170, o: 1 },
  { f: 122, x: 351, y: 99, o: 1 },
  { f: 127, x: 351, y: 99, o: 0 },
  { f: 156, x: 262, y: 330, o: 0 },
  { f: 158, x: 232, y: 270, o: 1 },
  { f: 163, x: 150, y: 191, o: 1 },
  { f: 167, x: 150, y: 191, o: 0 },
  { f: 187, x: 230, y: 380, o: 0 },
  { f: 189, x: 240, y: 300, o: 1 },
  { f: 191, x: 292, y: 72, o: 1 },
  { f: 196, x: 106, y: 452, o: 1 },
  { f: 200, x: 95, y: 219, o: 1 },
  { f: 204, x: paletteDot(2).x, y: paletteDot(2).y, o: 1 },
  { f: 208, x: paletteDot(2).x, y: paletteDot(2).y, o: 0 },
];
const TAPS = [33, 70, 122, 163, 191, 196, 200, 204];

const fingerAt = (f: number) => {
  // caret drag (text edit) overrides the waypoint path
  if (f >= 172 && f <= 186) {
    const idxFrom = NOTE_TEXT.length;
    const t = ease(f, T.caretMoveStart, T.caretMoveEnd, inOut);
    const a = detailCardToWorld(NOTE_TEXT, idxFrom);
    const b = detailCardToWorld(NOTE_TEXT, EDIT_AT);
    return {
      x: lerp(a.x, b.x, t) + 4,
      y: lerp(a.y, b.y, t) + 30,
      o: ease(f, 172, 174) * (1 - ease(f, 183, 186)),
      press: f >= 174 && f < 182 ? 1 : pulse(f, 182, 3),
    };
  }
  if (f <= PATH[0].f || f >= PATH[PATH.length - 1].f) return { x: 0, y: 0, o: 0, press: 0 };
  for (let i = 0; i < PATH.length - 1; i++) {
    const a = PATH[i];
    const b = PATH[i + 1];
    if (f >= a.f && f < b.f) {
      const t = ease(f, a.f, b.f, Easing.bezier(0.4, 0, 0.2, 1));
      const press = Math.max(0, ...TAPS.map((tf) => pulse(f, tf, 5)));
      return { x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t), o: lerp(a.o, b.o, t), press };
    }
  }
  return { x: 0, y: 0, o: 0, press: 0 };
};

/* ================================================================== */
/* FAB / Next                                                          */
/* ================================================================== */

const fabAt = (f: number) => {
  if (f < T.settle) {
    const k = ease(f, T.kbUp, T.kbUp + 10);
    return {
      y: lerp(746, 475, k),
      opacity: 1,
      morph: ease(f, T.composeIn, T.composeIn + 8),
      arc: ease(f, T.composeIn, T.composeIn + 10) * 0.667,
      enabled: 1 - ease(f, T.composeIn, T.composeIn + 6) + ease(f, T.typeStart, T.typeStart + 2),
      press: Math.max(pulse(f, T.fabTap, 6), pulse(f, T.nextTap, 6)),
      blur: 0,
    };
  }
  if (f < T.chromeIn) {
    const t = ease(f, T.settle, T.settle + 4, easeIn);
    return { y: 475 + t * 190, opacity: 1 - t, morph: 1, arc: 1, enabled: 1, press: 0, blur: t * 6 };
  }
  return {
    y: 746,
    opacity: ease(f, T.chromeIn, T.chromeIn + 8) * (1 - ease(f, T.searchExpand, T.searchExpand + 6)),
    morph: 0,
    arc: 0,
    enabled: 1,
    press: 0,
    blur: 0,
  };
};

/* ================================================================== */
/* The whole phone content for frames 0 … 209                          */
/* ================================================================== */

export const FlowScreen: React.FC<{ f: number; noFinger?: boolean }> = ({ f, noFinger }) => {
  const compose = composeAt(f);
  const search = searchAt(f);
  const detail = detailAt(f);
  const flight = flightAt(f);
  const fab = fabAt(f);
  const finger = fingerAt(f);

  const recede = Math.max(
    ease(f, 34, 42) * (1 - ease(f, 91, 95)),
    f >= T.searchTap ? ease(f, T.searchExpand, T.searchExpand + 8) : 0,
  );
  const o = open(f);
  const statusOp = 1 - ease(f, 40, 46) * (1 - ease(f, 73, 80));

  const foldCard = (
    <FoldingCard
      angle={flight.angle}
      text={NOTE_TEXT}
      icon={NEW_ICON}
      hideIcon
    />
  );
  const cardStyle: React.CSSProperties = {
    position: "absolute",
    left: 196.5 - CARD_W / 2,
    top: flight.cy - CARD_H / 2,
    width: CARD_W,
    height: CARD_H,
    scale: String(flight.sc),
    rotate: `${flight.rot}deg`,
    opacity: flight.opacity,
    filter: flight.blur > 0.1 ? `blur(${flight.blur}px)` : undefined,
  };
  const cardInFolder = flight.visible && f >= T.drop - 1;

  return (
    <>
      <div
        style={{
          position: "absolute",
          inset: 0,
          scale: String(1 - 0.06 * recede),
          opacity: 1 - recede,
          filter: recede > 0.02 ? `blur(${recede * 14}px)` : undefined,
        }}
      >
        <HomeScreen
          frame={f}
          chrome={homeChrome(f)}
          open={o}
          bounce={bounceAt(f)}
          count={{ from: 8, to: 9, roll: ease(f, T.countRoll, T.countRoll + 5, inOut) }}
          toggle={1 - ease(f, 91, 93) + ease(f, T.toggleOn, T.toggleOn + 4)}
          chips={chipsAt(f)}
          rows={rowsAt(f)}
          cardSlot={
            cardInFolder ? <div style={cardStyle}>{foldCard}</div> : null
          }
        />
      </div>

      {f >= T.searchTap && (
        <SearchOverlay
          f={f}
          expand={search.expand}
          kb={search.kb}
          query={search.query}
          fullQuery={QUERY}
          typeStart={T.searchType}
          typeStep={T.searchStep}
          rowsStart={T.searchExpand + 3}
          pressed={search.pressed}
          press={search.press}
          caretOn={search.caretOn}
        />
      )}

      {f >= T.composeIn && f < 96 && <ComposeOverlay s={compose} />}

      {f >= T.detailIn && <DetailOverlay s={detail} icon={NOTES[0].icon} />}

      {flight.visible && !cardInFolder && <div style={cardStyle}>{foldCard}</div>}

      {flight.icon.visible && (
        <div
          style={{
            position: "absolute",
            left: flight.icon.x - flight.icon.size / 2,
            top: flight.icon.y - flight.icon.size / 2,
            zIndex: 30,
          }}
        >
          <StackedIcon size={flight.icon.size} icon={NEW_ICON} />
        </div>
      )}

      {fab.opacity > 0.01 && (
        <div
          style={{
            position: "absolute",
            left: 196.5,
            top: fab.y,
            opacity: fab.opacity,
            filter: fab.blur > 0.1 ? `blur(${fab.blur}px)` : undefined,
            zIndex: 40,
          }}
        >
          <FabDisc morph={fab.morph} arc={fab.arc} enabled={fab.enabled} press={fab.press} />
        </div>
      )}

      <div style={{ position: "absolute", inset: 0, zIndex: 45, pointerEvents: "none" }}>
        <Touch x={finger.x} y={finger.y} opacity={noFinger ? 0 : finger.o} press={finger.press} />
      </div>
      <StatusBar opacity={statusOp * (f >= T.detailIn ? 1 - detail.bg * 0 : 1)} />
    </>
  );
};

export { PALETTE };
