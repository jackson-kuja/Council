# Council

Voice-first AI coaching for iOS. Personal context, real-time conversation, multiple perspectives.

Built for the [RevenueCat Shipyard 2026](https://www.revenuecat.com/shipyard/) competition — Simon / Better Creating brief.

---

**[Written Proposal](Submission/WRITTEN_PROPOSAL.md)** · **[Technical Documentation](Submission/TECHNICAL_DOCUMENTATION.md)**

---

## What It Does

Council is an AI coaching app where the first conversation already feels like the fifth. You tell it who you are — values, goals, what you're working through — and every coach reads that before a word is spoken.

- **Real-time voice** — Full-duplex via ElevenLabs with a responsive orb and haptic feedback
- **Continuity** — Sessions are transcribed and carried forward. Your coach remembers.
- **Multi-coach sessions** — Up to three coaches in a single live conversation, each with their own voice and perspective
- **Tool integration** — Connect Notion via MCP so coaches can reference your actual work
- **Coach creation + sharing** — Build a custom coach in under a minute, share with a deep link

## Architecture

Native SwiftUI (iOS 17+), MVVM, intentionally thin client. All AI logic runs server-side.

- **Backend:** Firebase Auth, Firestore, 11 Cloud Functions (TypeScript)
- **Voice:** ElevenLabs Conversational AI SDK
- **Subscriptions:** RevenueCat Purchases SDK (App Store)
- **MCP Proxy:** Node.js on Cloud Run for Notion workspace tools
- **Live Activities:** ActivityKit for Dynamic Island + lock screen

## Monetization

RevenueCat-powered subscriptions (monthly + annual). Free tier gives you real coaching conversations with all six built-in coaches. Premium unlocks unlimited sessions, multi-coach, Notion integration, custom coach creation, flagship AI models, and session continuity.

Seven contextual paywall triggers — each one arrives at the moment you want more, not before.

## Links

- [Written Proposal](Submission/WRITTEN_PROPOSAL.md)
- [Technical Documentation](Submission/TECHNICAL_DOCUMENTATION.md)
