import type { IconSpec } from "./ui/Primitives";

export const NEW_ICON: IconSpec = { tone: "blue", glyph: "star" };

export type NoteData = {
  key: string;
  title: string;
  time: string;
  icon: IconSpec;
  tag: string;
};

export const NOTES: NoteData[] = [
  { key: "new", title: "Plan the launch party", time: "Just now", icon: NEW_ICON, tag: "daily" },
  { key: "cher", title: "Buy fresh cherries", time: "2h ago", icon: { tone: "pink", glyph: "basket", circle: true }, tag: "errands" },
  { key: "launch", title: "Launch day checklist", time: "Yesterday", icon: { tone: "lavender", glyph: "plane", circle: true }, tag: "work" },
  { key: "book", title: "Book club picks", time: "Sep 28", icon: { tone: "orange", glyph: "book" }, tag: "ideas" },
  { key: "leaf", title: "Water the monstera", time: "Sep 26", icon: { tone: "green", glyph: "leaf" }, tag: "daily" },
];

export const matches = (title: string, q: string) => {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  const t = title.toLowerCase();
  return words.every((w) => t.includes(w));
};
