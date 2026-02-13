# Council — Technical Documentation

**Brief:** Simon (Better Creating)
**Developer:** Jackson Kuja
**Platform:** iOS (native SwiftUI)

---

## Architecture Overview

Council is a native iOS app built in SwiftUI using MVVM architecture. The client is intentionally thin — all AI agent logic, API key management, and third-party orchestration happens server-side through Firebase Cloud Functions and a Model Context Protocol (MCP) proxy on Cloud Run.

```
iOS Client (SwiftUI / MVVM)
  ├── Firebase Auth (Apple Sign In)
  ├── Firestore (coaches, sessions, profiles, connected services)
  ├── ElevenLabs Swift SDK (real-time voice)
  ├── RevenueCat Purchases SDK (subscriptions + entitlements)
  └── ActivityKit (Live Activities / Dynamic Island)

Firebase Cloud Functions (TypeScript, 11 functions)
  ├── Agent lifecycle (create, update, delete ElevenLabs agents)
  ├── Multi-voice session configuration
  ├── MCP server registration per agent
  └── Notion OAuth token exchange

MCP Proxy (Node.js on Cloud Run)
  └── Notion workspace tools via HTTP transport + session pooling
```

**Key architectural decisions:**
- Per-user agent cloning is lazy — agents are created on first session start, not at sign-up, keeping onboarding instant
- All API keys (ElevenLabs, OpenAI, Anthropic, Google) stay server-side in Cloud Functions; nothing sensitive reaches the device
- Firestore security rules enforce strict per-user data isolation
- Coach sharing uses both a custom URL scheme and Universal Links with Firebase-hosted web previews

---

## RevenueCat Integration

### SDK

- **SDK:** RevenueCat Purchases iOS SDK v5.0+ (via Swift Package Manager)
- **Configuration:** `Purchases.configure(withAPIKey:)` called in `CouncilApp.swift` at launch
- **Platform:** App Store (`appl_` API key prefix)
- **Not using RevenueCat Test Store** — products are configured through App Store Connect

### Dashboard Configuration

**Products:**

| Product | Store Identifier | Type | Duration |
|---------|-----------------|------|----------|
| Council Premium Monthly | `council_premium_monthly` | Subscription | P1M |
| Council Premium Yearly | `council_premium_yearly` | Subscription | P1Y |

**Entitlement:** `premium`
- Both monthly and yearly products grant the `premium` entitlement

**Offering:** Default
- Current/active offering containing both monthly and yearly packages

### Monetization Implementation

**Free tier includes:**
- All 6 built-in coaches (Productivity, Mindset, Career, Wellness, Creativity, Executive)
- Capped monthly sessions
- Efficient AI models

**Premium tier unlocks (all gated behind `premium` entitlement):**

| Feature | Paywall Trigger | Where Checked |
|---------|----------------|---------------|
| Multi-coach sessions (up to 3) | `.multiCoach` | SessionViewModel |
| Notion/MCP integrations | `.notion` | ProfileView |
| Custom coach creation + sharing | `.customCoach` | CreateCoachView |
| Unlimited sessions | `.sessionLimit` | SessionViewModel |
| Session continuity across conversations | `.continuity` | SessionViewModel |
| Flagship AI models (Claude, GPT-4o, Gemini Pro) | `.flagshipModel` | SessionViewModel |

Each trigger presents a contextual paywall with a unique headline and value proposition tailored to the moment the user hits the gate. The paywall is not a generic screen — it explains exactly what the user was trying to do and why upgrading enables it.

### Purchase Flow

1. User hits a premium feature gate → contextual `PaywallView` presented as a sheet
2. `PaywallView` fetches offerings via `Purchases.shared.offerings()`
3. User selects monthly or yearly package (annual pre-selected as "Best value")
4. Purchase executed via `Purchases.shared.purchase(package:)`
5. On success, `isPremium` updates immediately via `PurchasesDelegate`
6. Paywall dismisses, feature unlocks
7. Restore purchases available via `Purchases.shared.restorePurchases()`

### User Identity Sync

- On Firebase Auth sign-in: `Purchases.shared.logIn(firebaseUID)` syncs the RevenueCat customer ID to the Firebase user
- On sign-out: `Purchases.shared.logOut()` clears the RevenueCat session
- `PurchasesDelegate` listens for real-time entitlement changes and updates `isPremium` reactively

---

## Key User Flows

### Onboarding → Monetization

1. **Launch** → Apple Sign In (one tap)
2. **Personal Context** → User enters values, goals, current focus (stored in Firestore, injected into every coach's system prompt)
3. **Coach Selection** → Pick from 6 built-in coaches
4. **First Session** → Voice conversation with full personal context (feels like the fifth session, not the first)
5. **Premium Trigger** → User attempts multi-coach, Notion, custom coach, or exceeds session cap
6. **Paywall** → Contextual upgrade screen with RevenueCat offerings
7. **Purchase** → Sandbox or production transaction via App Store
8. **Unlock** → Feature immediately available, entitlement persisted

### Voice Session

1. Session start → Cloud Function clones/retrieves user's personal ElevenLabs agent
2. ElevenLabs Conversational AI establishes full-duplex WebSocket
3. Real-time voice with 7-band frequency analysis driving orb animation + haptics
4. Transcript builds live, stored in Firestore on session end
5. Prior transcripts injected as coaching history in subsequent sessions
6. Live Activity persists session in Dynamic Island and lock screen via ActivityKit

### Coach Creation + Sharing

1. 5-step guided flow: name → system prompt → voice (50+ options) → AI model (12 options) → orb colors
2. Coach saved to Firestore under user's account
3. Share generates a deep link carrying full coach configuration
4. Recipients open link → coach added to their library instantly
5. Firebase-hosted web preview for discovery before app install

---

## Third-Party Services

| Service | Purpose | Auth |
|---------|---------|------|
| Firebase Auth | Apple Sign In | OAuth |
| Cloud Firestore | All persistent data | Firebase SDK + security rules |
| Firebase Cloud Functions | Server-side agent orchestration | Service account |
| ElevenLabs Conversational AI | Real-time voice synthesis + conversation | API key (server-side only) |
| RevenueCat | Subscription management + entitlements | SDK API key |
| Notion API | Workspace search + page reading via MCP | OAuth (user-authorized) |
| Cloud Run | MCP proxy server for Notion tools | Bearer token |

---

## Codebase

- **42 Swift files** organized in MVVM (Models, ViewModels, Views, Services, Theme)
- **11 Cloud Functions** in TypeScript (agent CRUD, multi-voice config, MCP registration, OAuth exchange)
- **1 MCP proxy** on Cloud Run (Node.js, Notion tools, HTTP transport, session pooling)
