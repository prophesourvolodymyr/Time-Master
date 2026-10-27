import type { AppClipId } from "@/content/app-clips";

export type TalosBeat = {
  clip: AppClipId;
  title: string;
  line: string;
  side: "left" | "right";
};

export const talosBeats: readonly TalosBeat[] = [
  {
    clip: "ai-coach",
    title: "Plans your week.",
    line: "Ask like you'd text a friend. Get a plan back, minus the lecture.",
    side: "left",
  },
  {
    clip: "ai-long",
    title: "One sentence. Whole workout.",
    line: "It picks moves from your own library, builds the workout, then waits for your OK.",
    side: "right",
  },
  {
    clip: "database",
    title: "Grows your library.",
    line: "New exercises and folders, created the moment you ask for them.",
    side: "left",
  },
  {
    clip: "streaks",
    title: "Knows your numbers.",
    line: "It reads your streaks, totals and recent sessions, so the advice is about you.",
    side: "right",
  },
  {
    clip: "agent-settings",
    title: "Bring your own brain.",
    line: "Plug in OpenAI, Anthropic, Gemini, Groq or a local Ollama. Then write its personality.",
    side: "left",
  },
];

export type IconColor = { hex: string; label: string };

export const iconColors: readonly IconColor[] = [
  { hex: "#FFFFFF", label: "White" },
  { hex: "#FF3B30", label: "Red" },
  { hex: "#FF9500", label: "Orange" },
  { hex: "#FFCC00", label: "Yellow" },
  { hex: "#34C759", label: "Green" },
  { hex: "#007AFF", label: "Blue" },
  { hex: "#AF52DE", label: "Purple" },
  { hex: "#FF2D55", label: "Pink" },
];

export const personalities = ["Strict", "Hype", "Calm"] as const;

export type Personality = (typeof personalities)[number];

export const agentDemo = {
  username: "talos.ironmind",
  hoverColors: ["#FF2D55", "#AF52DE"],
  color: "#007AFF",
  personality: "Strict" as Personality,
  knowledgeFile: "goals.md",
} as const;
