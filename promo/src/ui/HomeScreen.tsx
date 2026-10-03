import React from "react";
import { Glyph } from "../icons";
import { C, FONT, SHADOW } from "../theme";
import { IconSpec, NoteRow, RoundButton, StackedIcon } from "./Primitives";

export type ChipSpec = {
  key: string;
  icon: IconSpec;
  x: number;
  y: number;
  scale: number;
  opacity: number;
  phase: number;
};

export type RowSpec = {
  key: string;
  title: string;
  time: string;
  icon: IconSpec;
  tag?: string;
  tagPop: number;
  slot: number; // fractional list index → y
  enter: number; // 0..1
};

export type HomeProps = {
  frame: number;
  chrome: number;
  open: number;
  bounce: number;
  count: { from: number; to: number; roll: number };
  toggle: number; // 0 = off (open) … 1 = on (closed)
  chips: ChipSpec[];
  rows: RowSpec[];
  cardSlot?: React.ReactNode;
  hideSearchButton?: boolean;
};

export const FOLDER = { x: 79, y: 239, w: 235, h: 174 };
export const ROW_TOP = 470;
export const ROW_PITCH = 64;
/** Where the newest note's chip lives. */
export const CENTER_SLOT = { x: 205, y: 209 };

const FolderFront: React.FC = () => (
  <svg
    width={FOLDER.w}
    height={FOLDER.h}
    viewBox={`0 0 ${FOLDER.w} ${FOLDER.h}`}
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      overflow: "visible",
      filter:
        "drop-shadow(0 2px 3px rgba(0,0,0,0.05)) drop-shadow(0 20px 22px rgba(0,0,0,0.075))",
    }}
  >
    <defs>
      <linearGradient id="ff" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="#FEFEFE" />
        <stop offset="0.36" stopColor="#FCFCFC" />
        <stop offset="0.385" stopColor="#F9F9F9" />
        <stop offset="1" stopColor="#F5F5F6" />
      </linearGradient>
    </defs>
    <path
      d="M24 0 H88 C103 0 108 26 123 26 H211 Q235 26 235 50 V150 Q235 174 211 174 H24 Q0 174 0 150 V24 Q0 0 24 0 Z"
      fill="url(#ff)"
    />
  </svg>
);

const Mix = (a: string, b: string, t: number) =>
  `color-mix(in srgb, ${a} ${Math.round(t * 100)}%, ${b})`;

const CountBubble: React.FC<{ from: number; to: number; roll: number }> = ({
  from,
  to,
  roll,
}) => (
  <div
    style={{
      position: "absolute",
      left: 96 - FOLDER.x,
      top: 353 - FOLDER.y,
      width: 46,
      height: 46,
      borderRadius: 23,
      background: "#fff",
      border: "1px solid rgba(0,0,0,0.06)",
      boxShadow: "0 3px 8px rgba(0,0,0,0.05)",
      overflow: "hidden",
      fontFamily: FONT,
      fontSize: 20,
      color: C.ink,
      boxSizing: "border-box",
    }}
  >
    {[from, to].map((n, i) => (
      <div
        key={i}
        style={{
          position: "absolute",
          left: 0,
          width: 44,
          height: 44,
          lineHeight: "44px",
          textAlign: "center",
          translate: `0 ${(i - roll) * 44}px`,
          filter: `blur(${Math.abs(i - roll) * 0 + (roll > 0 && roll < 1 ? 1.2 : 0)}px)`,
        }}
      >
        {n}
      </div>
    ))}
  </div>
);

const Toggle: React.FC<{ on: number }> = ({ on }) => (
  <div
    style={{
      position: "absolute",
      left: 184 - FOLDER.x,
      top: 354 - FOLDER.y,
      width: 113,
      height: 44,
      borderRadius: 22,
      background: Mix(C.lavTint, C.track, on),
      boxShadow: `inset 0 0 0 2px rgba(220,220,224,${0.5 * on + 0.15})`,
      fontFamily: FONT,
    }}
  >
    <div
      style={{
        position: "absolute",
        left: 52 + (16 - 52) * on,
        top: 0,
        height: 44,
        lineHeight: "44px",
        fontSize: 19,
        fontWeight: 600,
        letterSpacing: -0.3,
        color: Mix(C.lavInk, C.ink2, on),
      }}
    >
      Notes
    </div>
    <div
      style={{
        position: "absolute",
        left: 2 + 69 * on,
        top: 2,
        width: 40,
        height: 40,
        borderRadius: 20,
        background: "#fff",
        boxShadow: "0 2px 5px rgba(0,0,0,0.12)",
      }}
    />
  </div>
);

const TabBar: React.FC = () => (
  <>
    <div
      style={{
        position: "absolute",
        left: 31,
        top: 743,
        width: 331,
        height: 73,
        borderRadius: 36.5,
        background: C.track,
        boxShadow:
          "inset 0 3px 6px rgba(0,0,0,0.07), inset 0 -2px 3px rgba(255,255,255,0.55)",
      }}
    />
    <div
      style={{
        position: "absolute",
        left: 38.5,
        top: 754,
        width: 101,
        height: 55,
        borderRadius: 27.5,
        background: "#fff",
        boxShadow: SHADOW.row,
      }}
    />
    <div
      style={{
        position: "absolute",
        left: 38.5,
        top: 754,
        width: 101,
        height: 55,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 3,
        fontFamily: FONT,
      }}
    >
      <StackedIcon size={26} icon={{ tone: "lavender", glyph: "home" }} glow={false} />
      <div style={{ fontSize: 13, fontWeight: 600, color: C.ink }}>Home</div>
    </div>
    <div
      style={{
        position: "absolute",
        left: 253.5,
        top: 754,
        width: 101,
        height: 55,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 3,
        fontFamily: FONT,
      }}
    >
      <StackedIcon size={26} icon={{ tone: "grey", glyph: "heart" }} glow={false} />
      <div style={{ fontSize: 13, fontWeight: 500, color: C.ink2 }}>Saved</div>
    </div>
  </>
);

export const HomeScreen: React.FC<HomeProps> = ({
  frame,
  chrome,
  open,
  bounce,
  count,
  toggle,
  chips,
  rows,
  cardSlot,
  hideSearchButton,
}) => {
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: C.canvas,
        fontFamily: FONT,
        overflow: "hidden",
      }}
    >
      {/* ---------- header, Recent, tab bar ---------- */}
      <div style={{ position: "absolute", inset: 0, opacity: chrome, zIndex: 1 }}>
        <div
          style={{
            position: "absolute",
            left: 20,
            top: 67,
            fontSize: 13,
            color: C.ink2,
            letterSpacing: -0.1,
          }}
        >
          Saturday, 3 October
        </div>
        <div
          style={{
            position: "absolute",
            left: 20,
            top: 84,
            fontSize: 36,
            fontWeight: 700,
            color: C.ink,
            letterSpacing: -1.2,
            lineHeight: "44px",
          }}
        >
          Notes
        </div>
        {!hideSearchButton && (
          <RoundButton
            glyph="search"
            style={{ position: "absolute", left: 328, top: 76 }}
          />
        )}
        <div
          style={{
            position: "absolute",
            left: 20,
            top: 438,
            fontSize: 15,
            fontWeight: 600,
            color: C.ink,
          }}
        >
          Recent
        </div>
        <div
          style={{
            position: "absolute",
            right: 20,
            top: 439,
            fontSize: 14,
            color: C.ink2,
          }}
        >
          See all
        </div>
        {rows.map((r) => (
          <NoteRow
            key={r.key}
            title={r.title}
            time={r.time}
            icon={r.icon}
            tag={r.tag}
            tagPop={r.tagPop}
            style={{
              top: ROW_TOP + r.slot * ROW_PITCH,
              opacity: r.enter,
              translate: `0 ${(1 - r.enter) * -16}px`,
              filter: r.enter < 1 ? `blur(${(1 - r.enter) * 8}px)` : undefined,
            }}
          />
        ))}
        <TabBar />
      </div>

      {/* ---------- folder (always visible) ---------- */}
      <div
        style={{
          position: "absolute",
          left: 86,
          top: 225,
          width: 221,
          height: 178,
          borderRadius: 24,
          background: "#F8F8F9",
          boxShadow: "0 10px 24px rgba(0,0,0,0.05)",
          zIndex: 1,
          scale: String(1 + bounce * 0.5),
          transformOrigin: "50% 100%",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 9,
            top: 9,
            right: 9,
            height: 60,
            borderRadius: 16,
            border: "1px solid rgba(0,0,0,0.045)",
          }}
        />
      </div>
      {chips.map((c) => (
        <div
          key={c.key}
          style={{
            position: "absolute",
            left: c.x - 24,
            top:
              c.y -
              24 -
              14 * open +
              Math.sin((frame + c.phase) / 11) * 2.4,
            width: 48,
            height: 48,
            opacity: c.opacity,
            scale: String(c.scale * (1 + bounce * 0.5)),
            zIndex: 2,
          }}
        >
          <StackedIcon size={48} icon={c.icon} />
        </div>
      ))}
      <div style={{ position: "absolute", inset: 0, zIndex: 3 }}>{cardSlot}</div>
      <div
        style={{
          position: "absolute",
          left: FOLDER.x,
          top: FOLDER.y,
          width: FOLDER.w,
          height: FOLDER.h,
          zIndex: 4,
          scale: String(1 + bounce),
          transformOrigin: "50% 100%",
        }}
      >
        <FolderFront />
        <CountBubble from={count.from} to={count.to} roll={count.roll} />
        <Toggle on={toggle} />
      </div>
    </div>
  );
};

export const FabDisc: React.FC<{
  morph: number; // 0 = plus, 1 = arrow
  arc: number; // 0..1 amber arc
  enabled: number; // opacity of the disc content
  press: number;
}> = ({ morph, arc, enabled, press }) => {
  const R = 40.5;
  const circ = 2 * Math.PI * R;
  return (
    <div
      style={{
        position: "absolute",
        left: -45,
        top: -45,
        width: 90,
        height: 90,
        scale: String(1 - 0.1 * press),
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 9,
          top: 9,
          width: 72,
          height: 72,
          borderRadius: 36,
          background: "#F4F4F5",
          boxShadow: "0 4px 14px rgba(0,0,0,0.10), inset 0 1px 0 rgba(255,255,255,0.9)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 14,
          top: 14,
          width: 62,
          height: 62,
          borderRadius: 31,
          background: C.ink,
          opacity: 0.35 + 0.65 * enabled,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <div style={{ position: "absolute", opacity: 1 - morph, rotate: `${morph * 90}deg` }}>
          <Glyph name="plus" size={26} color="#fff" stroke={2.4} />
        </div>
        <div style={{ position: "absolute", opacity: morph, rotate: `${(1 - morph) * -90}deg` }}>
          <Glyph name="arrow" size={26} color="#fff" stroke={2.4} />
        </div>
      </div>
      {arc > 0 && (
        <svg
          width="90"
          height="90"
          viewBox="0 0 90 90"
          style={{ position: "absolute", left: 0, top: 0, rotate: "-90deg" }}
        >
          <circle
            cx="45"
            cy="45"
            r={R}
            fill="none"
            stroke={C.amber}
            strokeWidth="3.5"
            strokeLinecap="round"
            strokeDasharray={`${circ * arc} ${circ}`}
          />
        </svg>
      )}
    </div>
  );
};
