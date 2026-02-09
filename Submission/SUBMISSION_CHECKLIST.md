# Council — RevenueCat Shipyard 2026 Submission

## Brief: Simon (Better Creating)

---

## Key Dates

| Milestone | Date |
|-----------|------|
| Brief Release & Registration Open | January 15, 2026 |
| **Submission Deadline** | **February 12, 2026 @ 11:59pm PST** |
| Judging Period | February 12-14, 2026 |
| Winners Announced | February 26, 2026 |

---

## CRITICAL: Must Complete Before Submission

### RevenueCat Integration (PASS/FAIL — will be disqualified without this)
- [ ] Add `RevenueCat/purchases-ios` to Package.swift
- [ ] Configure `Purchases.configure(withAPIKey:)` in CoachBoardApp.swift
- [ ] Create products in RevenueCat dashboard (monthly/yearly subscription)
- [ ] Create App Store Connect subscription products
- [ ] Build paywall view with subscription options
- [ ] Gate premium features behind entitlement checks:
  - [ ] Unlimited sessions (free tier: capped monthly)
  - [ ] Multi-coach sessions
  - [ ] Notion/MCP integrations
  - [ ] Custom coach creation and sharing
  - [ ] Flagship AI models (Claude, GPT-4o, Gemini Pro)
  - [ ] Full session history with continuity
- [ ] Test purchase flow end-to-end in sandbox
- [ ] Restore purchases support

### Onboarding Flow (High-impact UX — directly from Simon's brief)
- [ ] Build 2-3 screen onboarding after first sign-in
- [ ] Screen 1: Personal context (values, goals, current focus)
- [ ] Screen 2: Suggested first coach
- [ ] Screen 3: Start first session
- [ ] Store completion flag to skip on subsequent launches

---

## Submission Checklist

### 1. App Access (TestFlight Link)
- [ ] App uploaded to TestFlight
- [ ] TestFlight link is publicly accessible
- [ ] RevenueCat SDK integrated with subscription product
- [ ] Core features functional and demonstrable
- [ ] App is newly created (no prior App Store submission before Jan 15, 2026)

### 2. Demo Video (2-3 minutes, max 3 minutes)
- [ ] Video recorded showing app on actual device
- [ ] Uploaded to YouTube, Vimeo, Facebook Video, or Youku
- [ ] Set to public visibility
- [ ] Covers full flow: onboarding → context → coach → session → monetization
- [ ] No copyrighted music without permission
- [ ] See `VIDEO_SCRIPT.md` for script

### 3. Written Proposal (1-2 pages)
- [ ] Problem statement
- [ ] Solution overview
- [ ] Monetization strategy (with RevenueCat specifics)
- [ ] Post-hackathon roadmap
- [ ] Technical documentation section
- [ ] Developer bio with real links
- [ ] See `WRITTEN_PROPOSAL.md` for full draft

### 4. Devpost Submission
- [ ] Register at https://revenuecat-shipyard-2026.devpost.com/
- [ ] Select "Better Creating" brief
- [ ] Upload demo video
- [ ] Paste written proposal
- [ ] Add TestFlight link
- [ ] Submit before deadline

---

## Judging Criteria

| Criteria | Weight | Council's Position |
|----------|--------|--------------------|
| **Audience Fit** | 30% | Built for productivity-obsessed, design-loving system-builders. Personal context, coach creation, Notion integration — this is Simon's audience in app form. |
| **User Experience** | 25% | Voice-first with animated orb. Hero transitions. Haptic feedback. Dynamic Island persistence. iOS-native jiggle-mode library. Clean SwiftUI design system. |
| **Monetization Potential** | 20% | RevenueCat subscriptions. Free tier that converts through value, not frustration. Premium unlocks depth (unlimited sessions, multi-coach, tools, custom coaches). Creator monetization path via coach sharing. |
| **Innovation** | 15% | Multi-coach sessions with distinct voices. MCP-powered Notion integration. Per-user agent cloning. Live Activities. Full-duplex voice coaching with frequency-responsive orb. |
| **Technical Quality** | 10% | MVVM architecture. 11 Cloud Functions. Firebase + Firestore. ElevenLabs SDK. ActivityKit. RevenueCat SDK. MCP proxy on Cloud Run. Server-side API keys. |

---

## Stage One (Pass/Fail)

- [ ] Project meets the Better Creating brief requirements
- [ ] RevenueCat SDK integrated
- [ ] App runs on iOS via TestFlight

---

## Quick Reference

- **Devpost:** https://revenuecat-shipyard-2026.devpost.com/
- **Rules:** https://revenuecat-shipyard-2026.devpost.com/rules
