/**
 * Updates community coach orb colors in Firestore to ensure
 * every coach has a visually distinct color pair.
 *
 * Usage:
 *   npx ts-node --compiler-options '{"module":"commonjs","target":"es2018","esModuleInterop":true}' scripts/updateCommunityColors.ts
 */

import * as admin from "firebase-admin";
admin.initializeApp();
const db = admin.firestore();

// Built-in hues already taken (avoid these bands):
// Marcus: indigo-violet  (#4F46E5 → #7C3AED)
// Sage:   emerald-green  (#059669 → #34D399)
// James:  red-orange     (#DC2626 → #F97316)
// Aria:   cyan           (#0891B2 → #06B6D4)
// Nova:   fuchsia-pink   (#D946EF → #F472B6)
// Victoria: dark slate   (#1E293B → #475569)

// 18 distinct color pairs, spaced across the full spectrum,
// avoiding built-in hue bands.

const colorUpdates: Record<string, [string, string]> = {
  // Productivity
  "deep-work-diana":  ["0284C7", "7DD3FC"],  // Sky blue
  "systems-sol":      ["B45309", "FCD34D"],  // Amber / gold
  "sprint-kai":       ["BE123C", "FDA4AF"],  // Coral / salmon
  "digital-min-lea":  ["6D28D9", "C084FC"],  // Soft violet

  // Mindset
  "stoic-zeno":       ["4B5563", "CBD5E1"],  // Cool graphite
  "gratitude-joy":    ["DB2777", "FBCFE8"],  // Rose / blush
  "resilience-rook":  ["047857", "6EE7B7"],  // Sea green / mint
  "breathwork-luna":  ["1D4ED8", "93C5FD"],  // Royal blue

  // Career
  "interview-max":    ["1E40AF", "60A5FA"],  // Sapphire
  "freelance-mia":    ["A21CAF", "E9D5FF"],  // Orchid / lilac
  "networking-ray":   ["92400E", "D6A85C"],  // Warm brown / sienna

  // Health
  "sleep-nyx":        ["312E81", "818CF8"],  // Cobalt / indigo
  "movement-atlas":   ["B91C1C", "FCA5A5"],  // Crimson / light red
  "nutrition-olive":  ["4D7C0F", "BEF264"],  // Lime / chartreuse
  "stress-river":     ["0F766E", "99F6E4"],  // Teal / aquamarine

  // Creativity
  "writing-ink":      ["57534E", "D6D3D1"],  // Warm stone / taupe
  "design-pixel":     ["CA8A04", "FDE68A"],  // Marigold / yellow
  "music-tempo":      ["BE185D", "F9A8D4"],  // Hot pink / magenta
};

async function updateColors() {
  for (const [id, colors] of Object.entries(colorUpdates)) {
    await db.collection("coaches").doc(id).update({ orbColors: colors });
    console.log(`Updated ${id}: [${colors[0]}, ${colors[1]}]`);
  }
  console.log("\nDone! All 18 community coaches updated with distinct colors.");
}

updateColors().catch(console.error);
