import { loadFont } from "@remotion/google-fonts/Inter";

// Inter is only the fallback: on macOS `-apple-system` resolves to SF Pro,
// which is exactly what the real SoftNotes app uses.
const { fontFamily: inter } = loadFont("normal", {
  weights: ["400", "500", "600", "700", "800"],
  subsets: ["latin"],
});

export const FONT = `-apple-system, BlinkMacSystemFont, "SF Pro Display", ${inter}, system-ui, sans-serif`;

// Tokens copied from DesignSystem/Theme.swift — keep in sync with the app.
export const C = {
  canvas: "#F0F0F0",
  surface: "#FFFFFF",
  track: "#E7E6E8",
  ink: "#17161A",
  ink2: "#8E8C93",
  ink3: "#C2C0C6",
  lavTint: "#E2DAFF",
  lavInk: "#7B6FE0",
  amber: "#F5B74A",
  paper: "#FFFDFA",
  paperTag: "#F5EFE5",
  heart: "#F77696",
} as const;

export const TONES = {
  lavender: { base: "#9E81F6", light: "#CBC6F7" },
  pink: { base: "#F77696", light: "#F8C2D2" },
  blue: { base: "#5A9AF6", light: "#B3D2FC" },
  orange: { base: "#FB9A4B", light: "#FFD6B0" },
  green: { base: "#63C36C", light: "#BDEBD0" },
  yellow: { base: "#FFBF55", light: "#FFE7A8" },
  indigo: { base: "#837AF1", light: "#C4C5FB" },
  grey: { base: "#C9C8CE", light: "#E6E5EA" },
} as const;
export type Tone = keyof typeof TONES;

export const rgba = (hex: string, a: number) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
};

export const SHADOW = {
  raised:
    "0 1px 2px rgba(0,0,0,0.04), 0 6px 14px rgba(0,0,0,0.06), 0 18px 32px rgba(0,0,0,0.05)",
  row: "0 1px 2px rgba(0,0,0,0.03), 0 5px 12px rgba(0,0,0,0.045)",
  card: "0 2px 4px rgba(0,0,0,0.05), 0 12px 24px rgba(0,0,0,0.08), 0 28px 48px rgba(0,0,0,0.07)",
};

export const PHONE_W = 393;
export const PHONE_H = 852;
