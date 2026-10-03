import React from "react";
import { Glyph } from "../icons";
import { C, FONT, SHADOW, TONES, Tone, rgba } from "../theme";

export type IconSpec = { tone: Tone; glyph: string; circle?: boolean };

/** The app's two-tile glass icon: solid back tile + frosted front tile + outline glyph. */
export const StackedIcon: React.FC<{
  size: number;
  icon: IconSpec;
  glow?: boolean;
  glyphScale?: number;
  style?: React.CSSProperties;
}> = ({ size, icon, glow = true, glyphScale = 0.4, style }) => {
  const t = TONES[icon.tone];
  const back = size * 0.8;
  const front = size * 0.82;
  const off = size * 0.18;
  const r = (s: number) => (icon.circle ? s / 2 : s * 0.3);
  return (
    <div style={{ position: "relative", width: size, height: size, ...style }}>
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: back,
          height: back,
          borderRadius: r(back),
          background: `linear-gradient(145deg, ${t.base}, ${rgba(t.base, 0.86)})`,
          boxShadow: glow
            ? `0 ${size * 0.2}px ${size * 0.38}px ${rgba(t.base, 0.38)}`
            : undefined,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: off,
          top: off,
          width: front,
          height: front,
          borderRadius: r(front),
          background: `linear-gradient(135deg, ${rgba(t.light, 0.8)}, ${rgba(t.light, 0.5)})`,
          backdropFilter: `blur(${size * 0.16}px)`,
          border: "1px solid rgba(255,255,255,0.6)",
          boxShadow: `inset 0 1px 1px rgba(255,255,255,0.5)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Glyph name={icon.glyph} size={size * glyphScale} color="#fff" stroke={2.1} />
      </div>
    </div>
  );
};

export const RoundButton: React.FC<{
  size?: number;
  glyph: string;
  flat?: boolean;
  glyphColor?: string;
  fill?: string;
  glyphFill?: string;
  style?: React.CSSProperties;
}> = ({
  size = 46,
  glyph,
  flat,
  glyphColor = C.ink,
  fill,
  glyphFill,
  style,
}) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size / 2,
      background: fill ?? (flat ? C.track : "#fff"),
      boxShadow: flat ? "inset 0 1px 2px rgba(0,0,0,0.05)" : SHADOW.raised,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      ...style,
    }}
  >
    <Glyph
      name={glyph}
      size={size * 0.42}
      color={glyphColor}
      stroke={2.1}
      fill={glyphFill}
    />
  </div>
);

/** Splits `text` so the matched query is bold lavender (the app's search emphasis). */
export const Emph: React.FC<{ text: string; query: string }> = ({
  text,
  query,
}) => {
  const q = query.trim().toLowerCase();
  const i = q ? text.toLowerCase().indexOf(q) : -1;
  if (i < 0) return <>{text}</>;
  return (
    <>
      {text.slice(0, i)}
      <b style={{ color: C.lavInk, fontWeight: 700 }}>
        {text.slice(i, i + q.length)}
      </b>
      {text.slice(i + q.length)}
    </>
  );
};

export const TagPill: React.FC<{ label: string; pop?: number }> = ({
  label,
  pop = 1,
}) => (
  <span
    style={{
      display: "inline-block",
      marginLeft: 6,
      padding: "1px 7px",
      borderRadius: 9,
      background: C.paperTag,
      color: C.ink2,
      fontSize: 12,
      fontWeight: 600,
      lineHeight: "17px",
      verticalAlign: 1,
      scale: String(Math.max(0, pop)),
      opacity: Math.min(1, pop * 1.5),
      transformOrigin: "left center",
    }}
  >
    #{label}
  </span>
);

export const NoteRow: React.FC<{
  title: React.ReactNode;
  time: string;
  icon: IconSpec;
  tag?: string;
  tagPop?: number;
  style?: React.CSSProperties;
}> = ({ title, time, icon, tag, tagPop = 1, style }) => (
  <div
    style={{
      position: "absolute",
      left: 16,
      width: 361,
      height: 58,
      borderRadius: 20,
      background: "#fff",
      boxShadow: SHADOW.row,
      fontFamily: FONT,
      ...style,
    }}
  >
    <StackedIcon
      size={40}
      icon={icon}
      style={{ position: "absolute", left: 10, top: 10 }}
    />
    <div style={{ position: "absolute", left: 61, top: 9, right: 40 }}>
      <div
        style={{
          fontSize: 16,
          fontWeight: 500,
          color: C.ink,
          lineHeight: "21px",
          letterSpacing: -0.2,
          whiteSpace: "nowrap",
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontSize: 13,
          color: C.ink2,
          lineHeight: "18px",
          whiteSpace: "nowrap",
        }}
      >
        {time}
        {tag ? <TagPill label={tag} pop={tagPop} /> : null}
      </div>
    </div>
    <div style={{ position: "absolute", right: 14, top: 18 }}>
      <Glyph name="chevron" size={22} color={C.ink3} stroke={2} />
    </div>
  </div>
);

export const StatusBar: React.FC<{ opacity?: number }> = ({ opacity = 1 }) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      width: 393,
      height: 54,
      opacity,
      fontFamily: FONT,
    }}
  >
    <div
      style={{
        position: "absolute",
        left: 44,
        top: 18,
        fontSize: 17,
        fontWeight: 600,
        color: C.ink,
        letterSpacing: -0.3,
      }}
    >
      9:41
    </div>
    <svg
      width="76"
      height="14"
      viewBox="0 0 76 14"
      style={{ position: "absolute", right: 28, top: 22 }}
    >
      <g fill={C.ink}>
        <rect x="0" y="9" width="3" height="5" rx="1" />
        <rect x="5" y="6" width="3" height="8" rx="1" />
        <rect x="10" y="3" width="3" height="11" rx="1" />
        <rect x="15" y="0" width="3" height="14" rx="1" />
      </g>
      <path
        d="M30 4.5a9 9 0 0 1 12 0M32.5 7.6a5.4 5.4 0 0 1 7 0"
        stroke={C.ink}
        strokeWidth="2"
        fill="none"
        strokeLinecap="round"
      />
      <circle cx="36" cy="11" r="1.6" fill={C.ink} />
      <rect
        x="50"
        y="1"
        width="23"
        height="12"
        rx="3.6"
        fill="none"
        stroke={C.ink}
        strokeOpacity="0.4"
      />
      <rect x="52" y="3" width="19" height="8" rx="2.2" fill="#46c75a" />
    </svg>
  </div>
);

/** A finger touch dot, drawn in phone coordinates. */
export const Touch: React.FC<{
  x: number;
  y: number;
  opacity: number;
  press: number; // 0..1
}> = ({ x, y, opacity, press }) => (
  <div
    style={{
      position: "absolute",
      left: x - 22,
      top: y - 22,
      width: 44,
      height: 44,
      borderRadius: 22,
      opacity,
      scale: String(1 - 0.18 * press),
      background: "rgba(40,36,60,0.16)",
      border: "1.5px solid rgba(255,255,255,0.85)",
      boxShadow: "0 3px 10px rgba(30,20,60,0.18)",
      pointerEvents: "none",
    }}
  />
);
