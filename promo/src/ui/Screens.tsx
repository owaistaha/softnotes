import React from "react";
import { Glyph } from "../icons";
import { NOTES, NoteData, matches } from "../data";
import { C, FONT, SHADOW, TONES, Tone } from "../theme";
import { clamp01, ease, inOut, lerp, sp, SPRINGS } from "../anim";
import { Keyboard, KB_H, KB_TOP } from "./Keyboard";
import { NoteCard, CardProps, CARD_H, CARD_W } from "./NoteCard";
import { Emph, IconSpec, NoteRow, RoundButton } from "./Primitives";

/* ------------------------------------------------------------------ */
/* Compose (write a chit)                                              */
/* ------------------------------------------------------------------ */

export type ComposeState = {
  bg: number; // canvas opacity
  enter: number; // card slides in
  k: number; // keyboard-up layout progress (0..1)
  kbDrop: number; // keyboard leaves at save
  titleOpacity: number;
  navOpacity: number;
  text: string;
  caretOn: number;
  pressed: string | null;
  press: number;
  showCard: boolean;
  icon: IconSpec;
};

export const CARD_POSE = (k: number) => ({
  cy: lerp(440, 283, k),
  scale: lerp(1, 1.12, k),
  rot: lerp(-3, -1.5, k),
});

export const ComposeOverlay: React.FC<{ s: ComposeState }> = ({ s }) => {
  const pose = CARD_POSE(s.k);
  const kbY = KB_TOP + (1 - s.k) * (KB_H + 12) + s.kbDrop * (KB_H + 12);
  return (
    <div style={{ position: "absolute", inset: 0, fontFamily: FONT }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: C.canvas,
          opacity: s.bg,
        }}
      />
      {/* nav */}
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: 393,
          height: 130,
          opacity: s.navOpacity * s.bg,
          translate: `0 ${-s.k * 24}px`,
        }}
      >
        <RoundButton glyph="back" style={{ position: "absolute", left: 20, top: 54 }} />
        <RoundButton glyph="close" flat style={{ position: "absolute", left: 327, top: 54 }} />
        <div
          style={{
            position: "absolute",
            left: 0,
            width: 393,
            top: 58,
            textAlign: "center",
            fontSize: 15,
            fontWeight: 600,
            color: C.ink,
          }}
        >
          New note
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            width: 393,
            top: 77,
            textAlign: "center",
            fontSize: 12,
            color: C.ink2,
          }}
        >
          Step 2 of 2
        </div>
      </div>
      {/* title */}
      <div
        style={{
          position: "absolute",
          left: 0,
          width: 393,
          top: lerp(138, 46, s.k),
          textAlign: "center",
          fontSize: 28,
          fontWeight: 700,
          letterSpacing: -0.5,
          lineHeight: "31px",
          color: C.ink,
          opacity: s.titleOpacity,
          filter: s.enter < 1 ? `blur(${(1 - s.enter) * 6}px)` : undefined,
        }}
      >
        What’s on your
        <br />
        mind today?
      </div>
      {/* card */}
      {s.showCard && (
        <div
          style={{
            position: "absolute",
            left: 196.5 - CARD_W / 2,
            top: pose.cy - CARD_H / 2,
            width: CARD_W,
            height: CARD_H,
            translate: `${(1 - s.enter) * 330}px 0`,
            rotate: `${pose.rot}deg`,
            scale: String(pose.scale),
            opacity: Math.min(1, s.enter * 3),
            filter: s.enter < 1 ? `blur(${(1 - s.enter) * 12}px)` : undefined,
          }}
        >
          <NoteCard
            text={s.text}
            icon={s.icon}
            caret={{ from: s.text.length, to: s.text.length, t: 0, on: s.caretOn }}
          />
        </div>
      )}
      {/* keyboard */}
      <div style={{ position: "absolute", left: 0, top: kbY, width: 393, height: KB_H }}>
        <Keyboard
          action="done"
          caps={s.text.length === 0}
          pressed={s.pressed}
          press={s.press}
          suggestions={s.text.length === 0 ? ["I", "The", "I’m"] : []}
        />
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Search                                                              */
/* ------------------------------------------------------------------ */

export const SEARCH_ROW_TOP = 162;
export const SEARCH_PITCH = 64;

export const SearchOverlay: React.FC<{
  f: number;
  expand: number;
  kb: number;
  query: string;
  fullQuery: string;
  typeStart: number;
  typeStep: number;
  rowsStart: number;
  pressed: string | null;
  press: number;
  caretOn: number;
  rows?: NoteData[];
}> = ({
  f,
  expand,
  kb,
  query,
  fullQuery,
  typeStart,
  typeStep,
  rowsStart,
  pressed,
  press,
  caretOn,
  rows = NOTES,
}) => {
  // when does each row stop matching while the query is typed?
  const vis = rows.map((n) => {
    for (let i = 1; i <= fullQuery.length; i++) {
      if (!matches(n.title, fullQuery.slice(0, i))) {
        return 1 - clamp01(sp(f, typeStart + (i - 1) * typeStep, SPRINGS.crisp));
      }
    }
    return 1;
  });
  let y = SEARCH_ROW_TOP;
  const placed = rows.map((n, i) => {
    const top = y;
    y += SEARCH_PITCH * vis[i];
    return { n, top, v: vis[i] };
  });
  const fieldLeft = lerp(328, 20, expand);
  const fieldW = lerp(46, 298, expand);
  const fieldTop = lerp(76, 68, expand);
  const kbY = KB_TOP + (1 - kb) * (KB_H + 12);
  return (
    <div style={{ position: "absolute", inset: 0, fontFamily: FONT }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: C.canvas,
          opacity: clamp01(expand * 2),
        }}
      />
      {/* field (grows out of the Home search button) */}
      <div
        style={{
          position: "absolute",
          left: fieldLeft,
          top: fieldTop,
          width: fieldW,
          height: 46,
          borderRadius: 23,
          background: "#fff",
          boxShadow: SHADOW.raised,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 16,
            top: 12,
            opacity: ease(expand, 0.35, 0.85),
          }}
        >
          <Glyph name="search" size={22} color={C.ink} stroke={2} />
        </div>
        <div
          style={{
            position: "absolute",
            left: 51,
            top: 0,
            height: 46,
            lineHeight: "46px",
            fontSize: 17,
            whiteSpace: "pre",
            opacity: ease(expand, 0.45, 0.9),
            color: query ? C.ink : C.ink3,
            display: "flex",
            alignItems: "center",
          }}
        >
          {query ? query : "Search notes"}
          {(caretOn > 0) && (
            <span
              style={{
                display: "inline-block",
                width: 2,
                height: 21,
                borderRadius: 1,
                background: C.amber,
                marginLeft: query ? 1 : -108,
                opacity: caretOn,
              }}
            />
          )}
        </div>
      </div>
      <RoundButton
        glyph="close"
        flat
        style={{
          position: "absolute",
          left: 328,
          top: 68,
          opacity: ease(expand, 0.4, 0.9),
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 20,
          top: 131,
          fontSize: 15,
          fontWeight: 600,
          color: C.ink2,
          opacity: ease(expand, 0.5, 1),
        }}
      >
        {query ? "Results" : "Recent"}
      </div>
      {placed.map(({ n, top, v }, i) => {
        const enter = ease(f, rowsStart + i * 1.4, rowsStart + 9 + i * 1.4);
        return (
          <NoteRow
            key={n.key}
            title={<Emph text={n.title} query={query} />}
            time={n.time}
            icon={n.icon}
            style={{
              top,
              opacity: v * enter,
              scale: String(0.94 + 0.06 * v),
              translate: `0 ${(1 - enter) * 22}px`,
              filter: v < 1 || enter < 1 ? `blur(${(1 - v * enter) * 6}px)` : undefined,
            }}
          />
        );
      })}
      <div style={{ position: "absolute", left: 0, top: kbY, width: 393, height: KB_H }}>
        <Keyboard action="search" pressed={pressed} press={press} />
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* Note detail (open from a row)                                       */
/* ------------------------------------------------------------------ */

export const DETAIL = { cx: 196.5, cy: 335, sc: 1.18 };

export type DetailState = {
  bg: number;
  open: number; // card flight 0 (at the row) → 1 (resting)
  rowIcon: { x: number; y: number }; // where the card's icon starts (row icon centre)
  text: string;
  caret?: CardProps["caret"];
  navPops: [number, number, number];
  titleOpacity: number;
  heart: number; // 0..1 active
  heartScale: number;
  burst: number; // 0..1 while the heart bursts, -1 = off
  tag: string;
  tagPop: number;
  tone: Tone;
  iconPop: number;
  palette: number; // pop 0..1
  paletteSel: number; // index highlighted
};

export const TONE_DOTS: Tone[] = ["blue", "pink", "orange", "green", "lavender"];
export const PALETTE = { left: 61, top: 128, w: 190, h: 44 };
export const paletteDot = (i: number) => ({
  x: PALETTE.left + 23 + i * 36,
  y: PALETTE.top + PALETTE.h / 2,
});

export const cardPoseDetail = (open: number, rowIcon: { x: number; y: number }) => {
  const startScale = 0.3;
  const sc = lerp(startScale, DETAIL.sc, open);
  // header icon slot centre (card-local 32,30) must start on the row icon
  const sx = rowIcon.x + (CARD_W / 2 - 32) * startScale;
  const sy = rowIcon.y + (CARD_H / 2 - 30) * startScale;
  return {
    cx: lerp(sx, DETAIL.cx, open),
    cy: lerp(sy, DETAIL.cy, open),
    sc,
  };
};

const NavPop: React.FC<{ p: number; children: React.ReactNode; style: React.CSSProperties }> = ({ p, children, style }) => (
  <div style={{ position: "absolute", scale: String(p), opacity: clamp01(p * 2), ...style }}>{children}</div>
);

export const DetailOverlay: React.FC<{ s: DetailState; icon: IconSpec }> = ({ s, icon }) => {
  const pose = cardPoseDetail(s.open, s.rowIcon);
  const iconNow: IconSpec = { ...icon, tone: s.tone };
  return (
    <div style={{ position: "absolute", inset: 0, fontFamily: FONT }}>
      <div style={{ position: "absolute", inset: 0, background: C.canvas, opacity: s.bg }} />
      <div
        style={{
          position: "absolute",
          left: 0,
          width: 393,
          top: 58,
          textAlign: "center",
          fontSize: 15,
          fontWeight: 600,
          color: C.ink,
          opacity: s.titleOpacity,
        }}
      >
        Your note
      </div>
      <div
        style={{
          position: "absolute",
          left: 0,
          width: 393,
          top: 77,
          textAlign: "center",
          fontSize: 12,
          color: C.ink2,
          opacity: s.titleOpacity,
        }}
      >
        Tap the card to edit
      </div>
      <NavPop p={s.navPops[0]} style={{ left: 20, top: 47 }}>
        <RoundButton glyph="back" />
      </NavPop>
      <NavPop p={s.navPops[1]} style={{ left: 269, top: 47 }}>
        <div style={{ scale: String(s.heartScale), position: "relative" }}>
          <RoundButton
            glyph="heart"
            fill={s.heart > 0.5 ? C.heart : "#fff"}
            glyphColor={s.heart > 0.5 ? "#fff" : C.ink}
            glyphFill={s.heart > 0.5 ? "#fff" : "none"}
          />
          {s.burst >= 0 &&
            Array.from({ length: 8 }, (_, i) => {
              const a = (i / 8) * Math.PI * 2;
              const r = lerp(24, 44, s.burst);
              return (
                <div
                  key={i}
                  style={{
                    position: "absolute",
                    left: 23 + Math.cos(a) * r - 3,
                    top: 23 + Math.sin(a) * r - 3,
                    width: 6,
                    height: 6,
                    borderRadius: 3,
                    background: i % 2 ? C.heart : C.amber,
                    opacity: 1 - s.burst,
                    scale: String(1 - s.burst * 0.5),
                  }}
                />
              );
            })}
        </div>
      </NavPop>
      <NavPop p={s.navPops[2]} style={{ left: 327, top: 47 }}>
        <RoundButton glyph="trash" />
      </NavPop>

      {/* tone palette (icon tap) */}
      {s.palette > 0 && (
        <div
          style={{
            position: "absolute",
            left: PALETTE.left,
            top: PALETTE.top,
            width: PALETTE.w,
            height: PALETTE.h,
            borderRadius: 22,
            background: "#fff",
            boxShadow: SHADOW.raised,
            scale: String(s.palette),
            opacity: clamp01(s.palette * 1.6),
            transformOrigin: "30% 100%",
          }}
        >
          {TONE_DOTS.map((t, i) => (
            <div
              key={t}
              style={{
                position: "absolute",
                left: 23 + i * 36 - 13,
                top: 9,
                width: 26,
                height: 26,
                borderRadius: 13,
                background: TONES[t].base,
                boxShadow:
                  s.paletteSel === i
                    ? `0 0 0 3px #fff, 0 0 0 5px ${TONES[t].base}`
                    : undefined,
                scale: String(s.paletteSel === i ? 1.12 : 1),
              }}
            />
          ))}
        </div>
      )}

      <div
        style={{
          position: "absolute",
          left: pose.cx - CARD_W / 2,
          top: pose.cy - CARD_H / 2,
          width: CARD_W,
          height: CARD_H,
          scale: String(pose.sc),
          opacity: clamp01(s.open * 4),
        }}
      >
        <NoteCard
          text={s.text}
          icon={iconNow}
          iconScale={s.iconPop}
          tag={s.tag}
          tagPop={s.tagPop}
          caret={s.caret}
        />
      </div>
    </div>
  );
};

/* ------------------------------------------------------------------ */
/* All notes (montage shot 2): cards rearrange into an organised list  */
/* ------------------------------------------------------------------ */

const GROUPS: { label: string; y: number; rows: { n: NoteData; y: number }[] }[] = [
  { label: "Today", y: 168, rows: [{ n: NOTES[0], y: 194 }, { n: NOTES[1], y: 258 }] },
  { label: "Yesterday", y: 334, rows: [{ n: NOTES[2], y: 360 }] },
  { label: "This week", y: 436, rows: [{ n: NOTES[3], y: 462 }, { n: NOTES[4], y: 526 }] },
];

const SCATTER = [
  { x: 120, y: 330, r: 14 },
  { x: -150, y: 200, r: -11 },
  { x: 90, y: -210, r: 9 },
  { x: -110, y: -330, r: -13 },
  { x: 160, y: -120, r: 12 },
];

export const AllNotesScreen: React.FC<{ f: number; tagPops: number[] }> = ({ f, tagPops }) => {
  let idx = 0;
  return (
    <div style={{ position: "absolute", inset: 0, background: C.canvas, fontFamily: FONT }}>
      <RoundButton glyph="back" style={{ position: "absolute", left: 20, top: 54 }} />
      <div
        style={{
          position: "absolute",
          left: 20,
          top: 108,
          fontSize: 36,
          fontWeight: 700,
          letterSpacing: -1.2,
          color: C.ink,
        }}
      >
        All notes
      </div>
      {GROUPS.map((g) => (
        <React.Fragment key={g.label}>
          <div
            style={{
              position: "absolute",
              left: 20,
              top: g.y,
              fontSize: 14,
              fontWeight: 600,
              color: C.ink2,
              opacity: ease(f, 3, 9),
            }}
          >
            {g.label}
          </div>
          {g.rows.map(({ n, y }) => {
            const i = idx++;
            const p = sp(f, i * 1.2, { damping: 14, stiffness: 190, mass: 0.7 });
            const sc = SCATTER[i % SCATTER.length];
            return (
              <NoteRow
                key={n.key}
                title={n.title}
                time={n.time}
                icon={n.icon}
                tag={n.tag}
                tagPop={tagPops[i] ?? 0}
                style={{
                  top: y,
                  translate: `${(1 - p) * sc.x}px ${(1 - p) * sc.y}px`,
                  rotate: `${(1 - p) * sc.r}deg`,
                  opacity: clamp01(p * 3),
                }}
              />
            );
          })}
        </React.Fragment>
      ))}
    </div>
  );
};

export { inOut };
