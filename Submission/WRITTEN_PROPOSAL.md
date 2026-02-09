# Council

**Brief:** Simon (Better Creating)
**Developer:** Jackson Kuja
**Platform:** iOS, native SwiftUI

---

## Problem and Approach

Coaching is one of the highest returns on investment you can make with your time. The right question at the right moment changes the trajectory of a project, a decision, a career. But most people never access it — they don't know where to start, don't have the time to vet someone, and can't justify the cost for something they've never experienced.

AI should make this obvious. But most AI tools still feel like chatbots in a text box — prompt in, response out. They compress the best part of coaching, the rhythm, the pacing, the pause before a question that actually makes you think, into something transactional. And they start cold every time. No context. No memory. No relationship.

I built Council to solve both problems at once. A beautiful, minimal app where the first thing it asks isn't which coach you want — it's who you are. Your values. What you're building. What you're stuck on. Then you pick a coach, and the very first conversation already feels like the fifth. Because the coach already knows what matters to you before it says a word.

The core decision was making voice the primary interface. Coaching lives in conversation — the shift in tone, the follow-up question, the moment a coach finds the thread you didn't know you were pulling. Council uses ElevenLabs Conversational AI for full-duplex real-time voice. The coach can interject. You can interrupt. It flows the way a real conversation does. The orb at the center of the screen responds across seven frequency bands, and the haptics follow — the phone vibrates gently in rhythm with the words. You're not reading a chat log. You're holding a conversation.

---

## Personal Context and Continuity

Every session in Council is transcribed and stored. When you return, prior conversations are injected as coaching history through dynamic context variables. The coach doesn't just remember what was discussed — it identifies patterns across sessions. Recurring hesitations. Decisions that keep getting deferred. Progress you might not see from inside it.

This works because of a decision I made about agent architecture: when you start your first session with any coach, Council creates a dedicated instance of that agent — cloned from the template, stored against your account, carrying your history and your customizations. It's not a shared model being prompted differently each time. It's your coach. The tenth session with Marcus feels fundamentally different from the first, and you can feel it.

---

## Multiple Perspectives

Coaching has an inherent limitation: a single perspective carries blind spots. A productivity coach optimizes for output. A mindset coach asks whether the output even matters. Council lets you bring up to three coaches into a single live session, each with their own voice, personality, and methodology. The effect is a conversation between specialists — about your specific problem, in real time, with you in the room. This is one of the most meaningful things in the app. It models something that almost never happens in traditional coaching: two expert perspectives, in dialogue, about you.

When a session is active, it persists through the Dynamic Island and lock screen. Switch apps, check messages, come back — the session is right where you left it. A coaching session is something you're in, not something the app is displaying.

---

## Coaches That See Your Work

I built Council on the Model Context Protocol — an open standard for connecting AI agents to external tools. The first integration is Notion. When you connect your workspace through OAuth, your coaches gain the ability to search pages, read content, and reference real projects. Ask your coach what to focus on this quarter and instead of a generic prioritization framework, it pulls up your actual planning document, reads your priorities, and coaches you on those. The guidance is grounded in what's actually there, not what you remembered to mention.

The architecture matters more than the first integration. MCP is a transport layer — adding Todoist, Google Calendar, or Reminders follows the same pattern. What I'm building toward is coaches that don't stop at advice. They help you follow through.

---

## The Library and Community

Council ships with six specialist coaches — Productivity, Mindset, Career, Wellness, Creativity, and Executive — each with a distinct voice, personality, and methodology. But users create their own through a guided five-step process: name, system prompt, voice from a library of over fifty, AI model (twelve options across Claude, GPT, and Gemini), and visual identity through orb colors. A coach can be built in under a minute. Sharing is a single tap — a deep link carries the full coach configuration, and anyone who opens it gets it added to their library. There's also a web preview hosted on Firebase for discovery before the user even opens the app.

The long-term shape is a community library where the most useful coaches surface naturally. Every coach someone creates and shares makes the platform deeper for everyone.

---

## Monetization

RevenueCat powers the subscription layer. The free tier includes all six built-in coaches with capped monthly sessions and efficient AI models. I was deliberate about making the free experience complete — you should be able to have a real coaching conversation, feel the personal context working, and walk away having made a decision. That's the conversion engine. Not frustration, but the desire for more depth.

Premium unlocks unlimited sessions, multi-coach conversations, Notion and future tool integrations, custom coach creation and sharing, flagship AI models (Claude, GPT-4o, Gemini Pro), and full session history with continuity. The upgrade triggers are specific and intentional: "I want my coach to remember this next time" is session continuity. "I want both of them in the same conversation" is multi-coach. "I want my coach to see my Notion" is tool access. Each maps to a moment where the user already felt the value.

Voice AI costs more per session than text. I see that as alignment — the cost reflects the quality, and the subscription model delivers it sustainably. A month of unlimited AI coaching costs less than fifteen minutes with a human coach. Looking further ahead, community-created coaches shared via deep link are a natural path toward creator-led monetization. Revenue sharing on popular coaches is a direct extension of the architecture that already exists.

---

## Technical Architecture

The iOS app is 42 Swift files organized in MVVM — Firebase Auth for Apple Sign In, Firestore for persistence across coaches, sessions, user profiles, and connected services, the ElevenLabs Swift SDK for real-time voice, ActivityKit for Live Activities and Dynamic Island, and the RevenueCat Purchases SDK for subscription management and entitlement checks. Behind the app, eleven Firebase Cloud Functions written in TypeScript handle the agent lifecycle — creating, updating, and deleting ElevenLabs agents, configuring multi-voice sessions, managing MCP server registration, and exchanging Notion OAuth tokens. All API keys stay server-side; nothing sensitive touches the device. The MCP server runs as a Node.js container on Cloud Run, exposing Notion workspace tools over HTTP transport with session pooling and Bearer token authentication.

Key architectural decisions: per-user agent cloning is lazy (created on first session, not sign-up), keeping onboarding instant. Firestore security rules enforce strict per-user data isolation. Coach sharing works through both a custom URL scheme and Universal Links with web-hosted previews.

---

## Roadmap

**Near term (weeks):**
- In-app task management with push notifications — coaches create follow-up actions that live on your device
- Todoist and Google Calendar MCP integrations using the same architecture as Notion
- AI-generated session summaries
- Home screen widgets for instant session launch

**Further out:**
- Community coach marketplace with ratings and discovery
- Android client (the architecture is backend-heavy by design — the iOS app is a client, not the product)
- Team coaching with shared contexts for co-founders and small teams
- Coaching analytics — patterns, themes, and progress visible over time

---

## About Me

Jackson Kuja — iOS developer building at the intersection of AI and personal productivity. I built Council because I've seen what coaching does for the people who access it, and I believe AI has reached the point where that experience can be genuinely recreated — with voice, with memory, with tools that see your actual work. The gap between a chatbot and a coach isn't a model upgrade. It's architecture, interface design, and a hundred small decisions about what a conversation should feel like. That's what I spent this month building.

**GitHub:** [github.com/jacksonkuja](https://github.com/jacksonkuja)
**Contact:** jacksonkuja@gmail.com
