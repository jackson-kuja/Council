# CoachBoard

**Brief:** Simon (Better Creating)
**Developer:** Jackson Kuja
**Platform:** iOS, native SwiftUI

---

## Problem and Approach

I started with an observation about coaching that I couldn't let go of: the best conversations follow a shape. They don't begin with answers. They begin with context — who you are, what you care about, what you're trying to work through. Then they narrow. Not more information, but better questions. And they resolve into something you can actually do next. That shape is what I built CoachBoard around. Every decision in the app — the interface, the architecture, the way sessions connect to each other — exists to protect that shape and make it feel effortless.

The first and most consequential decision was making voice the primary interface. Coaching is a timing art. It lives in the pause before a hard question, in the shift in tone when a coach finds the thread. Text compresses all of that into something transactional — prompt in, response out. I didn't want that. I wanted the interaction to have presence, the way a real conversation does, where you're not reading and typing but actually talking and listening. So I built the entire app around real-time voice using ElevenLabs Conversational AI. It's full-duplex — true simultaneous speech, not turn-based. The coach can interject. The user can interrupt. Conversations flow the way real ones do. The orb at the center of the session screen responds to the coach's voice across seven frequency bands, and the haptics follow — the phone vibrates gently in rhythm with the words. It's subtle, but it anchors the experience in something physical. You're not scrolling through a chat log. You're holding a conversation.

---

## Personal Context and Continuity

The first thing CoachBoard asks isn't which coach you want. It's who you are. Values, goals, what you're focused on right now. This personal context is injected into the preamble of every session — before the coach says a word, it already knows what the user cares about, what they're building, and where they're stuck. This changes the quality of the first interaction dramatically. Without it, every session starts cold, and the coach spends its opening exchanges just learning the basics. With it, the first conversation already feels like the fifth. The coach asks better questions sooner because it already knows what matters. And because the context is always editable, the coaching adapts as the user's life shifts — new project, new challenge, new phase — without starting over.

Session continuity was non-negotiable. A coaching relationship that resets every time you open the app isn't a relationship, it's a service call. Every session in CoachBoard is transcribed and stored. When the user returns for a new session, prior conversations are injected as coaching history through dynamic context variables. The coach doesn't just remember what was discussed — it identifies patterns across sessions. Recurring hesitations. Decisions that keep getting deferred. Progress the user might not see from inside it. This is architecturally possible because of a decision I made about how agents work: when a user starts their first session with any coach, CoachBoard creates a dedicated instance of that agent — cloned from the template, stored against their account, carrying their history and their customizations. It's not a shared model being prompted differently each time. It's their coach. The design intent is that the tenth session with Marcus feels fundamentally different from the first, and the user can feel it.

---

## Multiple Perspectives and Presence

Coaching has an inherent limitation that I kept thinking about: a single perspective, no matter how skilled, carries blind spots. A productivity coach optimizes for output. A mindset coach asks whether the output even matters. Both are valuable. The real insight lives in the tension between them. CoachBoard lets users bring up to three coaches into a single live session, each with their own voice, personality, and methodology. The primary coach speaks in its default voice, and additional coaches tag their contributions with named markers that the voice engine routes to the corresponding voice model. The effect is a conversation between specialists — about the user's specific problem, in real time, with the user in the room. I think this is one of the most meaningful things in the app. It models something that almost never happens in traditional coaching: two expert perspectives, in dialogue with each other, about you.

I also spent a lot of time thinking about what happens when the user leaves the app. A coaching session shouldn't end because you got a text message. When a session is active, it persists — the Dynamic Island shows the coach names, elapsed time, and mute controls, styled with the gradient colors from the coach's orb. The lock screen shows the same. The user can switch apps, check messages, look something up, and come back without losing the thread. Background reconnection handles dropped connections automatically. The principle is straightforward: a coaching session is something the user is *in*, not something the app is displaying. Leaving doesn't end it, the same way walking to the kitchen during a phone call doesn't hang up. Live Activities and the Dynamic Island are native iOS APIs that I could only access by building natively in SwiftUI — and these details are what make the experience feel like it belongs on the device rather than running inside a web view.

---

## Coaches That See Your Work

This is the part I'm most excited about. I built CoachBoard on the Model Context Protocol — an open standard for connecting AI agents to external tools. The first integration is Notion. When a user connects their workspace through OAuth, their coaches gain the ability to search pages, read content, and reference real projects, notes, and plans. The effect is striking: ask your coach what you should focus on this quarter and instead of offering a generic prioritization framework, it pulls up your actual planning document, reads your priorities, and coaches you on those. The guidance is grounded in reality, not inference.

The architecture here matters more than the first integration. MCP is a transport layer. Adding a new tool — Todoist, Google Calendar, a custom internal service — follows the same pattern: register a server, attach it to the agent, and the coach gains a new capability. The design accommodates the second integration and the tenth without rearchitecting. What I'm building toward is in-app task management where coaches create action items with due dates and send push notifications to the user's device. The coach suggests a next step, creates the task, and reminds you tomorrow. Calendar-aware coaching that checks what your week looks like before suggesting you take on something new. The throughline is coaches that don't stop at advice — they help you follow through.

---

## The Library and Community

CoachBoard ships with six specialist coaches — Productivity, Mindset, Career, Wellness, Creativity, and Executive — each with a distinct voice, personality, and structured methodology. But I designed the app to outgrow them. Users create their own coaches through a guided five-step process: name, system prompt, voice selection from a library of over fifty, AI model (twelve options across Claude, GPT, and Gemini), and visual identity through orb colors. A coach can be built in under a minute. Sharing is a single tap — a deep link carries the coach, and anyone who opens it gets it added to their library, ready for a session. There's also a web preview hosted on Firebase that provides a landing page before the user even opens the app.

The long-term shape of this is a community library where the most useful coaches surface naturally. I want the library to reflect the way people actually think about self-improvement — specific, varied, deeply personal — rather than a fixed set of categories defined in advance. Every coach someone creates and shares makes the platform deeper for everyone.

---

## Monetization

RevenueCat powers the subscription layer. The free tier includes all six built-in coaches, capped monthly sessions, and efficient AI models. I was deliberate about making the free experience complete — a user should be able to have a real coaching conversation, feel the personal context working, and walk away having made a decision. That's the conversion engine. Not frustration, but the desire for more depth.

Premium unlocks unlimited sessions, multi-coach conversations, Notion and future tool integrations, custom coach creation and sharing, flagship AI models, and full session history with continuity across conversations. The upgrade triggers are specific and intentional: "I want my coach to remember this next time" is session continuity. "I want both of them in the same conversation" is multi-coach. "I want my coach to see my Notion" is tool access. Each maps to a moment where the user already felt the value and wants more of it.

Voice AI is more expensive per session than text. I see that as alignment, not a problem — the cost structure reflects the quality of the experience, and the subscription model lets me deliver it sustainably. A month of unlimited AI coaching costs less than fifteen minutes with a human coach, and the human coach doesn't read your Notion before the call. Looking further ahead, custom coaches shared via deep link are a natural path toward creator-led monetization. The audience for this app builds systems — some of them will build coaches. Revenue sharing on community-created coaches is a direct extension of the architecture that already exists.

---

## Technical Architecture

The iOS app is 42 Swift files organized in MVVM — Firebase Auth for Apple Sign In, Firestore for persistence across coaches, sessions, user profiles, and connected services, the ElevenLabs Swift SDK for real-time voice, ActivityKit for Live Activities, and the RevenueCat SDK for subscription management. Behind the app, eleven Firebase Cloud Functions written in TypeScript handle the agent lifecycle — creating, updating, and deleting ElevenLabs agents, configuring multi-voice sessions, managing MCP server registration, and exchanging Notion OAuth tokens. All API keys stay server-side; nothing sensitive touches the device. The MCP server itself runs as a Node.js container on Cloud Run, exposing Notion workspace tools over HTTP transport with session pooling and Bearer token authentication.

A few decisions worth noting: per-user agent cloning is lazy, meaning the dedicated agent instance is created on first session rather than on sign-up, which keeps onboarding instant and avoids provisioning infrastructure for users who are still browsing. Firestore security rules enforce strict per-user data isolation — users read and write only their own data, and public coaches are read-only to non-creators. Coach sharing works through both a custom URL scheme and web-hosted previews, supporting discovery both inside and outside the app.

---

## Roadmap

In the near term — weeks, not months — I'm adding in-app task management with push notifications so coaches can create actionable follow-ups that live on the device, Todoist and Google Calendar MCP integrations using the same architecture as Notion, AI-generated session summaries, and home screen widgets for launching a session without opening the app. Further out, I'm building toward a community coach marketplace with ratings and discovery, an Android client (the architecture is backend-heavy by design, so the iOS app is a client, not the product), team coaching with shared contexts for co-founders and small teams, and coaching analytics that make patterns, recurring themes, and progress visible over time.

---

## About Me

Jackson Kuja — iOS developer building at the intersection of AI and personal productivity. Experienced with SwiftUI, Firebase, conversational AI, and the Model Context Protocol.

**Portfolio:** [Add links]
**GitHub:** [Add link]
**Contact:** [Add email]
