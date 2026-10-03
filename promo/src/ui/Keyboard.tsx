import React from "react";
import { Glyph } from "../icons";
import { FONT } from "../theme";

export const KB_TOP = 528; // phone-space y of the keyboard's top edge when fully up
export const KB_H = 324;

const ROWS = ["qwertyuiop", "asdfghjkl", "zxcvbnm"];
const KEY_H = 42;
const PITCH = 38.5;

type KeyBox = { ch: string; x: number; y: number; w: number };

const letterBoxes: KeyBox[] = [];
ROWS.forEach((row, r) => {
  const x0 = r === 0 ? 6.8 : r === 1 ? 25.6 : 64.5;
  const y = [49.5, 102.5, 155][r];
  [...row].forEach((ch, i) =>
    letterBoxes.push({ ch, x: x0 + i * PITCH, y, w: 32 }),
  );
});

const keyStyle: React.CSSProperties = {
  position: "absolute",
  height: KEY_H,
  borderRadius: 8,
  background: "#fff",
  boxShadow: "0 1px 0 rgba(0,0,0,0.28)",
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  fontFamily: FONT,
  color: "#000",
};

/** iOS-style software keyboard. `pressed` highlights one key with a preview bubble. */
export const Keyboard: React.FC<{
  action: "done" | "search";
  caps?: boolean;
  pressed?: string | null;
  press?: number;
  suggestions?: string[];
}> = ({ action, caps, pressed, press = 0, suggestions }) => {
  const sugg = suggestions ?? [];
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: 393,
        height: KB_H,
        background: "#DCDDE3",
        borderTopLeftRadius: 28,
        borderTopRightRadius: 28,
        overflow: "visible",
      }}
    >
      {[0, 1, 2].map((i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: 0,
            left: i * 131,
            width: 131,
            height: 40,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontFamily: FONT,
            fontSize: 16,
            color: "#222",
            borderRight: i < 2 && sugg.length ? "1px solid rgba(0,0,0,0.12)" : undefined,
            boxSizing: "border-box",
            marginTop: 8,
          }}
        >
          {sugg[i] ?? ""}
        </div>
      ))}
      {letterBoxes.map((k) => {
        const on = pressed === k.ch && press > 0;
        return (
          <React.Fragment key={k.ch}>
            <div
              style={{
                ...keyStyle,
                left: k.x,
                top: k.y,
                width: k.w,
                fontSize: 22,
                background: on ? "#C6C8CF" : "#fff",
              }}
            >
              {caps ? k.ch.toUpperCase() : k.ch}
            </div>
            {on ? (
              <div
                style={{
                  position: "absolute",
                  left: k.x - 7,
                  top: k.y - 56,
                  width: k.w + 14,
                  height: 60,
                  borderRadius: 11,
                  background: "#fff",
                  boxShadow: "0 4px 12px rgba(0,0,0,0.22)",
                  display: "flex",
                  alignItems: "flex-start",
                  justifyContent: "center",
                  paddingTop: 7,
                  fontSize: 32,
                  fontFamily: FONT,
                  color: "#000",
                  opacity: Math.min(1, press * 1.6),
                }}
              >
                {caps ? k.ch.toUpperCase() : k.ch}
              </div>
            ) : null}
          </React.Fragment>
        );
      })}
      <div style={{ ...keyStyle, left: 6.8, top: 155, width: 43.6, background: "#fff" }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill={caps ? "#000" : "none"} stroke="#000" strokeWidth="1.8" strokeLinejoin="round">
          <path d="M12 3l9 10h-5.5v7h-7v-7H3z" />
        </svg>
      </div>
      <div style={{ ...keyStyle, left: 342, top: 155, width: 44.6, background: "#fff" }}>
        <svg width="26" height="20" viewBox="0 0 26 20" fill="none" stroke="#000" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
          <path d="M8 1h15a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8L1 10z" />
          <path d="M12 6.5l7 7M19 6.5l-7 7" />
        </svg>
      </div>
      <div style={{ ...keyStyle, left: 6.8, top: 208, width: 90, fontSize: 17 }}>123</div>
      <div style={{ ...keyStyle, left: 103, top: 208, width: 187 }} />
      <div
        style={{
          ...keyStyle,
          left: 296,
          top: 208,
          width: 90.6,
          background: "#0A7AFF",
          boxShadow: "0 1px 0 rgba(0,0,0,0.2)",
        }}
      >
        <Glyph name={action === "search" ? "search" : "check"} size={24} color="#fff" stroke={2.2} />
      </div>
      <div style={{ position: "absolute", left: 28, top: 267 }}>
        <svg width="28" height="28" viewBox="0 0 28 28" fill="none" stroke="#000" strokeWidth="1.7" strokeLinecap="round">
          <circle cx="14" cy="14" r="11.5" />
          <circle cx="10.3" cy="11.5" r="1" fill="#000" />
          <circle cx="17.7" cy="11.5" r="1" fill="#000" />
          <path d="M8.5 16.5a6 6 0 0 0 11 0z" />
        </svg>
      </div>
      <div style={{ position: "absolute", left: 340, top: 266 }}>
        <svg width="24" height="30" viewBox="0 0 24 30" fill="none" stroke="#000" strokeWidth="1.7" strokeLinecap="round">
          <rect x="8" y="1.5" width="8" height="15" rx="4" />
          <path d="M3.5 13a8.5 8.5 0 0 0 17 0M12 21.5V27M8 27h8" />
        </svg>
      </div>
    </div>
  );
};
