import React from "react";
import { measureText } from "@remotion/layout-utils";
import { C, FONT, SHADOW } from "../theme";
import { IconSpec, StackedIcon } from "./Primitives";

export const CARD_W = 236;
export const CARD_H = 258;
const TEXT_X = 18;
const TEXT_W = 200;
const TEXT_TOP = 63;
const LINE_H = 30;
const FONT_SIZE = 24;

const cache = new Map<string, number>();
const width = (text: string) => {
  const hit = cache.get(text);
  if (hit !== undefined) return hit;
  const w = measureText({
    text: text.replace(/ /g, " "),
    fontFamily: FONT,
    fontSize: FONT_SIZE,
    fontWeight: "600",
    letterSpacing: "-0.3px",
  }).width;
  cache.set(text, w);
  return w;
};

/** Greedy word wrap that keeps trailing spaces, so lines concatenate back to `text`. */
export const wrapText = (text: string): string[] => {
  const tokens = text.match(/\S+\s*|\s+/g) ?? [];
  const lines: string[] = [];
  let cur = "";
  for (const tok of tokens) {
    if (cur && width((cur + tok).trimEnd()) > TEXT_W) {
      lines.push(cur);
      cur = tok;
    } else {
      cur += tok;
    }
  }
  lines.push(cur);
  return lines;
};

/** Position (card-local) of the caret at character index `idx` of `text`. */
export const caretPos = (text: string, idx: number) => {
  const lines = wrapText(text);
  let consumed = 0;
  for (let i = 0; i < lines.length; i++) {
    const len = lines[i].length;
    if (idx <= consumed + len || i === lines.length - 1) {
      const col = Math.max(0, Math.min(len, idx - consumed));
      return {
        x: TEXT_X + width(lines[i].slice(0, col)),
        y: TEXT_TOP + i * LINE_H + 2,
      };
    }
    consumed += len;
  }
  return { x: TEXT_X, y: TEXT_TOP };
};

export type CardProps = {
  text: string;
  icon: IconSpec;
  hideIcon?: boolean;
  tag?: string;
  tagPop?: number;
  heading?: string;
  time?: string;
  noShadow?: boolean;
  /** caret slides from char index `from` to `to` (t 0..1); `on` is its opacity */
  caret?: { from: number; to: number; t: number; on: number };
  iconScale?: number;
};

export const NoteCard: React.FC<CardProps> = ({
  text,
  icon,
  hideIcon,
  tag = "daily",
  tagPop = 1,
  heading = "Morning note",
  time = "3 Oct · 9:41",
  noShadow,
  caret,
  iconScale = 1,
}) => {
  const lines = text ? wrapText(text) : [];
  const c = caret
    ? (() => {
        const a = caretPos(text, caret.from);
        const b = caretPos(text, caret.to);
        return {
          x: a.x + (b.x - a.x) * caret.t,
          y: a.y + (b.y - a.y) * caret.t,
        };
      })()
    : null;
  return (
    <div
      style={{
        position: "relative",
        width: CARD_W,
        height: CARD_H,
        borderRadius: 22,
        background: C.paper,
        boxShadow: noShadow ? undefined : SHADOW.card,
        fontFamily: FONT,
        overflow: "hidden",
      }}
    >
      {!hideIcon && (
        <StackedIcon
          size={32}
          icon={icon}
          style={{
            position: "absolute",
            left: 16,
            top: 14,
            scale: String(iconScale),
          }}
        />
      )}
      <div
        style={{
          position: "absolute",
          left: 56,
          top: 15,
          fontSize: 13,
          fontWeight: 600,
          color: C.ink,
          letterSpacing: -0.1,
        }}
      >
        {heading}
      </div>
      <div
        style={{
          position: "absolute",
          left: 56,
          top: 33,
          fontSize: 11,
          color: C.ink2,
        }}
      >
        {time}
      </div>
      <div
        style={{
          position: "absolute",
          left: 16,
          right: 16,
          top: 58,
          borderTop: "1.5px dashed rgba(0,0,0,0.08)",
        }}
      />
      {[118, 148, 178, 208].map((y, i) => (
        <div
          key={y}
          style={{
            position: "absolute",
            left: 16,
            top: y,
            width: i === 3 ? 92 : 204,
            height: 1,
            background: "rgba(0,0,0,0.06)",
          }}
        />
      ))}
      {text === "" && (
        <div
          style={{
            position: "absolute",
            left: TEXT_X,
            top: TEXT_TOP,
            lineHeight: `${LINE_H}px`,
            fontSize: FONT_SIZE,
            fontWeight: 600,
            letterSpacing: -0.3,
            color: C.ink3,
            whiteSpace: "nowrap",
          }}
        >
          Tap to write...
        </div>
      )}
      {lines.map((l, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            left: TEXT_X,
            top: TEXT_TOP + i * LINE_H,
            lineHeight: `${LINE_H}px`,
            fontSize: FONT_SIZE,
            fontWeight: 600,
            letterSpacing: -0.3,
            color: C.ink,
            whiteSpace: "pre",
          }}
        >
          {l}
        </div>
      ))}
      {c && caret && caret.on > 0 && (
        <div
          style={{
            position: "absolute",
            left: c.x + 1,
            top: c.y,
            width: 2.5,
            height: 26,
            borderRadius: 2,
            background: C.amber,
            opacity: caret.on,
          }}
        />
      )}
      <div
        style={{
          position: "absolute",
          left: 16,
          top: 218,
          height: 24,
          padding: "0 11px",
          borderRadius: 12,
          background: C.paperTag,
          color: C.ink2,
          fontSize: 12,
          fontWeight: 600,
          display: "flex",
          alignItems: "center",
          scale: String(tagPop),
          transformOrigin: "left center",
        }}
      >
        #{tag}
      </div>
    </div>
  );
};

const DROP =
  "drop-shadow(0 2px 3px rgba(0,0,0,0.06)) drop-shadow(0 14px 18px rgba(0,0,0,0.10))";

/**
 * The save's fold: the card drawn twice, clipped to halves. The top half
 * turns about the centre line (toward the viewer) and tucks behind the
 * bottom half past 90°.
 */
export const FoldingCard: React.FC<{ angle: number } & CardProps> = ({
  angle,
  ...card
}) => {
  if (angle <= 0.01) return <NoteCard {...card} />;
  const half = CARD_H / 2;
  const shade = angle < 90 ? 0.22 * Math.sin((angle * Math.PI) / 180) : 0.22;
  return (
    <div
      style={{
        position: "relative",
        width: CARD_W,
        height: CARD_H,
        perspective: 640,
        perspectiveOrigin: `50% ${half}px`,
      }}
    >
      <div style={{ position: "absolute", inset: 0, zIndex: 2, filter: DROP }}>
        <div style={{ clipPath: `inset(${half - 0.5}px 0 0 0)` }}>
          <NoteCard {...card} noShadow />
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          inset: 0,
          zIndex: angle < 90 ? 3 : 1,
          transformOrigin: `50% ${half}px`,
          transform: `rotateX(${-angle}deg)`,
        }}
      >
        <div style={{ clipPath: `inset(0 0 ${half}px 0)`, position: "relative" }}>
          <NoteCard {...card} noShadow />
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: `rgba(0,0,0,${shade})`,
            }}
          />
        </div>
      </div>
    </div>
  );
};
