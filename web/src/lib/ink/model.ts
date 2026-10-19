export type PaperId = "plain" | "xuan" | "coarse" | "silk";

export type LayerRecord = {
  name: string;
  visible: boolean;
  png: string;
};

export type WorkRecord = {
  id: string;
  title: string;
  width: number;
  height: number;
  paper: PaperId;
  updatedAt: number;
  thumb: string;
  layers: LayerRecord[];
};

export type Draft = {
  id: string;
  title: string;
  width: number;
  height: number;
  paper: PaperId;
  layers?: LayerRecord[];
  underlay?: string;
};

export type BrushSpec = {
  id: string;
  name: string;
  hint: string;
  spacing: number;
  hard: number;
  baseFlow: number;
  kind: "solid" | "dry" | "speed";
};

export const PAPERS: { id: PaperId; name: string; hint: string }[] = [
  { id: "plain", name: "Bare", hint: "No tooth" },
  { id: "xuan", name: "Xuan", hint: "Soft fiber" },
  { id: "coarse", name: "Cold press", hint: "Hungry paper" },
  { id: "silk", name: "Raw silk", hint: "Warm ground" },
];

export const PRESETS: {
  id: string;
  name: string;
  ratio: string;
  w: number;
  h: number;
  blurb: string;
}[] = [
  { id: "scroll", name: "Hanging scroll", ratio: "9:16", w: 540, h: 960, blurb: "A single column of quiet." },
  { id: "leaf", name: "Album leaf", ratio: "3:4", w: 630, h: 840, blurb: "The size of a page you can hold." },
  { id: "seal", name: "Seal square", ratio: "1:1", w: 800, h: 800, blurb: "A moon, a bowl, a mark." },
  { id: "hand", name: "Handscroll", ratio: "16:9", w: 960, h: 540, blurb: "Read it sideways, or refuse to." },
  { id: "screen", name: "Screen panel", ratio: "4:3", w: 880, h: 660, blurb: "Wide enough for a room." },
  { id: "letter", name: "Letter sheet", ratio: "A4", w: 620, h: 877, blurb: "Leave room for a sentence." },
  { id: "card", name: "Postcard", ratio: "3:2", w: 900, h: 600, blurb: "Something you could actually send." },
];

export const BRUSHES: BrushSpec[] = [
  { id: "wolf", name: "Wolf hair", hint: "A decisive edge.", spacing: 0.16, hard: 0.62, baseFlow: 0.92, kind: "solid" },
  { id: "goat", name: "Goat wash", hint: "Wide, thirsty, and slow.", spacing: 0.2, hard: 0.02, baseFlow: 0.38, kind: "solid" },
  { id: "pine", name: "Dry pine", hint: "The paper shows through.", spacing: 0.32, hard: 0.45, baseFlow: 0.85, kind: "dry" },
  { id: "reed", name: "Reed pen", hint: "Thins when you hurry.", spacing: 0.1, hard: 0.78, baseFlow: 1, kind: "speed" },
  { id: "soot", name: "Soot stump", hint: "Charcoal, not a line.", spacing: 0.14, hard: 0.08, baseFlow: 0.55, kind: "solid" },
];

export const SWATCH_GROUPS: { name: string; colors: string[] }[] = [
  { name: "Ink", colors: ["#14110e", "#3a342c", "#6e6558", "#a39886", "#d9d0c0", "#f4ecdf"] },
  { name: "Minerals", colors: ["#8d1f22", "#c44536", "#d4783a", "#e2b657", "#2f6f62", "#1d4e79", "#6b4c7a", "#f0e2c8"] },
  { name: "Blossom", colors: ["#f0c4cb", "#d45d7e", "#8e3148", "#efd7a2", "#6f9a62", "#2f5344", "#d5e3ea", "#2e3d48"] },
];

export const PROMPTS: {
  id: string;
  title: string;
  text: string;
  preset: string;
  paper: PaperId;
}[] = [
  { id: "pine", title: "Three strokes of pine", text: "A trunk, a reach, and the sky you refuse to fill. Stop at three.", preset: "scroll", paper: "xuan" },
  { id: "river", title: "The unpainted river", text: "The blank sheet is the water. Only the banks deserve ink.", preset: "hand", paper: "plain" },
  { id: "lantern", title: "One lantern", text: "Night everywhere else. The lantern is the only mineral color you may use.", preset: "leaf", paper: "coarse" },
  { id: "seal", title: "A seal, not a signature", text: "A square, slightly wrong on purpose. Cinnabar, then stop.", preset: "seal", paper: "silk" },
  { id: "window", title: "Borrowed scenery", text: "Draw the window first. What sits beyond it can be three marks.", preset: "screen", paper: "xuan" },
  { id: "letter", title: "The letter you will not send", text: "A fold, one sentence, and the ring where the tea sat.", preset: "letter", paper: "plain" },
  { id: "bowl", title: "Bowl with a crack", text: "Mend the crack in cinnabar. The repair is the subject.", preset: "seal", paper: "coarse" },
  { id: "rain", title: "Rain that missed the mountain", text: "A horizontal wash, one dark ridge. No raindrops. They always lie.", preset: "hand", paper: "xuan" },
];

export function presetById(id: string) {
  return PRESETS.find((p) => p.id === id) ?? PRESETS[0];
}
