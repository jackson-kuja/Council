export type TurnEagerness = "patient" | "normal" | "eager";

type SuggestedAudioTag = {
  tag: string;
  description?: string;
};

const STYLE_TAGS: Record<string, SuggestedAudioTag[]> = {
  natural: [],
  warm: [
    { tag: "warm", description: "Use when offering support" },
    { tag: "empathetic", description: "Use when discussing emotions" },
  ],
  calm: [
    { tag: "calm", description: "Use for grounding moments" },
    { tag: "steady", description: "Use when clarifying next steps" },
  ],
  confident: [
    { tag: "confident", description: "Use when giving direction" },
    { tag: "direct", description: "Use for high-stakes decisions" },
  ],
  playful: [
    { tag: "playful", description: "Use for creative exploration" },
    { tag: "light", description: "Use to keep energy positive" },
  ],
  energetic: [
    { tag: "energetic", description: "Use when motivating action" },
    { tag: "upbeat", description: "Use to keep momentum high" },
  ],
};

export function clampSpeechSpeed(value: unknown, fallback = 1.0): number {
  let parsed = fallback;
  if (typeof value === "number") parsed = value;
  if (typeof value === "string") {
    const n = Number(value);
    if (!Number.isNaN(n)) parsed = n;
  }
  return Math.max(0.7, Math.min(1.2, parsed));
}

export function turnEagernessFromPace(value: unknown, fallback: TurnEagerness = "normal"): TurnEagerness {
  if (value === "thoughtful") return "patient";
  if (value === "snappy") return "eager";
  if (value === "balanced") return "normal";
  return fallback;
}

export function audioTagsFromStyle(value: unknown): SuggestedAudioTag[] {
  if (typeof value !== "string") return [];
  return STYLE_TAGS[value] ?? [];
}
