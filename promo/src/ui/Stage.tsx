import React from "react";
import { AbsoluteFill } from "remotion";
import { Cam } from "../camera";
import { C, FONT, PHONE_H, PHONE_W, rgba } from "../theme";
import { ease, expoOut, sp, SPRINGS } from "../anim";

/** Soft pastel backdrop with slowly drifting colour glows. */
export const Backdrop: React.FC<{ frame: number }> = ({ frame }) => {
  const d = (n: number, sp_: number, amp: number) => Math.sin(frame / sp_ + n) * amp;
  const blob = (
    color: string,
    x: number,
    y: number,
    size: number,
    n: number,
  ): React.ReactNode => (
    <div
      style={{
        position: "absolute",
        left: x + d(n, 40, 40) - size / 2,
        top: y + d(n + 2, 46, 50) - size / 2,
        width: size,
        height: size,
        borderRadius: size / 2,
        background: `radial-gradient(circle, ${rgba(color, 0.55)} 0%, ${rgba(color, 0)} 68%)`,
      }}
    />
  );
  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #F7F6FC 0%, #EEEEF4 100%)",
        overflow: "hidden",
      }}
    >
      {blob("#9E81F6", 900, 240, 1100, 0)}
      {blob("#F77696", 120, 1180, 1000, 2)}
      {blob("#5A9AF6", 880, 1700, 1100, 4)}
      {blob("#FFBF55", 160, 120, 700, 6)}
    </AbsoluteFill>
  );
};

/**
 * The phone, placed by a camera: phone point (fx, fy) lands on screen (540, cy)
 * at scale s. Everything inside is in phone points (393 × 852).
 */
export const PhoneWorld: React.FC<{
  cam: Cam;
  opacity?: number;
  blur?: number;
  children: React.ReactNode;
}> = ({ cam, opacity = 1, blur = 0, children }) => (
  <div
    style={{
      position: "absolute",
      left: 0,
      top: 0,
      width: PHONE_W,
      height: PHONE_H,
      transformOrigin: "0 0",
      translate: `${540 - cam.s * cam.fx}px ${cam.cy - cam.s * cam.fy}px`,
      scale: String(cam.s),
      opacity,
      filter: blur > 0.05 ? `blur(${blur}px)` : undefined,
    }}
  >
    {/* soft ground shadow + bezel */}
    <div
      style={{
        position: "absolute",
        left: -9,
        top: -9,
        width: PHONE_W + 18,
        height: PHONE_H + 18,
        borderRadius: 66,
        background: "#16151A",
        boxShadow:
          "0 40px 80px rgba(60,40,120,0.20), 0 12px 24px rgba(0,0,0,0.12), inset 0 0 0 1.5px rgba(255,255,255,0.12)",
      }}
    />
    <div
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: 57,
        overflow: "hidden",
        background: C.canvas,
        fontFamily: FONT,
      }}
    >
      {children}
    </div>
    {/* dynamic island */}
    <div
      style={{
        position: "absolute",
        left: PHONE_W / 2 - 59,
        top: 11,
        width: 118,
        height: 34,
        borderRadius: 17,
        background: "#000",
        zIndex: 50,
      }}
    />
  </div>
);

/** Big pop-in caption, screen space. Words spring up one after another. */
export const Caption: React.FC<{
  frame: number;
  words: string[];
  start: number;
  end: number;
  accent?: number;
  size?: number;
  top?: number;
}> = ({ frame, words, start, end, accent = -1, size = 92, top = 64 }) => {
  if (frame < start || frame > end) return null;
  const out = ease(frame, end - 5, end);
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top,
        width: 1080,
        display: "flex",
        justifyContent: "center",
        gap: size * 0.26,
        fontFamily: FONT,
        fontSize: size,
        fontWeight: 800,
        letterSpacing: -size * 0.034,
        color: C.ink,
        opacity: 1 - out,
        translate: `0 ${-out * 24}px`,
        whiteSpace: "nowrap",
      }}
    >
      {words.map((w, i) => {
        const p = sp(frame, start + i * 2, SPRINGS.pop);
        const a = ease(frame, start + i * 2, start + i * 2 + 5);
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              translate: `0 ${(1 - p) * 46}px`,
              opacity: a,
              filter: a < 1 ? `blur(${(1 - a) * 12}px)` : undefined,
              scale: String(0.9 + 0.1 * Math.min(p, 1.15)),
              color: i === accent ? C.lavInk : C.ink,
            }}
          >
            {w}
          </span>
        );
      })}
    </div>
  );
};

/** Fades phone content into the backdrop under the captions when zoomed in. */
export const TopFade: React.FC<{ s: number }> = ({ s }) => {
  const o = Math.min(1, Math.max(0, (s - 2.15) / 0.35));
  if (o <= 0) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: 1080,
        height: 360,
        opacity: o,
        background:
          "linear-gradient(180deg, rgba(247,246,252,1) 0%, rgba(247,246,252,0.96) 45%, rgba(247,246,252,0) 100%)",
      }}
    />
  );
};

export { expoOut };
