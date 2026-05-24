# SMV — Know Your Edge

> AI-powered facial analysis app built on real PSL (looksmaxxing) standards. Scan your face, get an honest score, track your progress, compete on leaderboards.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI** | SwiftUI 5, iOS 17+ |
| **Data** | SwiftData (local persistence) |
| **Vision** | Apple Vision framework (76-point facial landmarks) |
| **Subscriptions** | StoreKit 2 |
| **Architecture** | MVVM, feature-based modules |

## Architecture

```
SMV/
├── App/                    # Entry point, theme, router, tab bar
├── Features/
│   ├── Scan/              # Camera + photo upload + face analysis
│   ├── Results/           # Score display, radar chart, share card
│   ├── Feed/              # Social feed, post creation
│   ├── Leaderboard/       # Rankings with podium + filters
│   ├── Community/         # Forums, guides, trending
│   ├── Profile/           # User profile, edit, progress tracking
│   ├── Settings/          # Preferences, paywall, legal
│   ├── Onboarding/        # 3-page welcome flow
│   └── Notifications/     # Activity feed
├── Components/            # Reusable UI (GlassmorphicCard, GradientButton, etc.)
├── Models/                # SwiftData models (ScanResult, Post, UserProfile, etc.)
├── Services/              # FaceAnalysisService, AuthService, SubscriptionManager
└── Extensions/            # Score formatting, clamping utilities
```

## Scoring Engine

Uses real PSL community standards from looksmax.org:

- **10 biometric metrics**: FWHR, canthal tilt, gonial angle, facial thirds, IPD ratio, eye aspect ratio, nose width, lip ratio, philtrum ratio, bilateral symmetry
- **Weighted scoring**: Eye area (25%) + jaw (22%) dominate — "Eyes are the prize" / "Jaw is law"
- **Bell curve distribution**: Most users score 4–6. Elite (8+) is genuinely rare.
- **Failo detection**: Severely below-ideal features cap the maximum possible score
- **No artificial floor**: Honest ratings, period.

### PSL Tiers

| Score | Tier | Rarity |
|-------|------|--------|
| 9.0+ | Giga Chad | 1 in 8M |
| 7.5–9.0 | Chad | 1 in 150K |
| 7.0–7.5 | Chadlite | 1 in 4.5K |
| 6.0–7.0 | HTN | 1 in 92 |
| 4.5–6.0 | Average | 1 in 2 |
| 3.0–4.5 | Below Average | 1 in 7 |
| <3.0 | Subhuman | 1 in 2K |

## Getting Started

1. Clone the repo:
   ```bash
   git clone git@github.com:YOUR_ORG/smv-app.git
   cd smv-app
   ```

2. Open in Xcode:
   ```bash
   open SMV.xcodeproj
   ```

3. Select an iOS 17+ simulator or device

4. Build and run (⌘R)

> **Note**: Camera features require a physical device. Photo upload works in simulator.

## Roadmap

- [x] Face scanning (camera + photo upload)
- [x] PSL-accurate scoring engine
- [x] Results with radar chart + share card
- [x] Social feed
- [x] Leaderboard with podium
- [x] Community forums
- [x] Profile + scan history
- [x] Progress tracking with charts
- [x] Settings + paywall
- [x] Onboarding flow
- [ ] Firebase backend (Auth + Firestore + Storage)
- [ ] Real-time leaderboards
- [ ] Push notifications
- [ ] In-app messaging
- [ ] Video scan mode
- [ ] Before/after comparison tool

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Test on simulator + device
4. Open a PR with screenshots

## License

Proprietary — all rights reserved.
