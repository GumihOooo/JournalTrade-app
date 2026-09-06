# GumiBook PRD v1.1
## Personal Trading Journal & Analytics

**Product:** GumiBook  
**Version:** 1.1  
**Status:** Final  
**Platform:** Android & iOS  
**Type:** Personal Trading Journal & Analytics  
**Target Users:** ±5 users  
**Markets:** Forex, Futures, Gold (XAU/USD)

---

## 1. Product Overview

GumiBook is a premium personal trading journal for recording, reviewing, and analyzing trading activity.

Core capabilities:
- Manual trade entry
- MT5 screenshot → automatic trade data extraction
- Trading journal and psychology tracking
- Performance analytics
- Market intelligence
- Trading calculators
- Privacy-first screenshot handling

GumiBook is intended for personal use and portfolio presentation. No social feed, followers, sharing, or community features.

**Core principle:** Track → Analyze → Learn → Improve

---

## 2. User Journey

### First Launch
```text
Splash
  ↓
Onboarding 1
  ↓
Onboarding 2
  ↓
Login / Sign Up
  ↓
Dashboard
```

Returning users: `Splash → Login`  
Users with a valid session: `Splash → Dashboard`

Onboarding state is stored locally.

---

## 3. Main Navigation

Five destinations:

1. **Dashboard** — analytics and performance overview
2. **Journal** — trade history
3. **Add Trade** — primary action
4. **Market** — market data and intelligence
5. **Settings** — profile, preferences, calculator, privacy, account

### Liquid Glass Navigation

The bottom navigation uses a Liquid Glass-inspired floating pill:
- Frosted/translucent glass
- Background blur
- Subtle reflection
- Silver border
- Soft shadow
- Smooth spring animation

Resting height: ~48dp. Scrolled height: ~36dp.

When scrolling down, the pill becomes compact. When scrolling up, it expands.

The Add Trade button is larger, slightly elevated, and has a subtle glow.

Implement using performant Flutter-native techniques rather than web-only CSS APIs.

---

## 4. Design System

### Visual Direction
- Dark only
- Premium
- Minimal
- Professional
- Monochrome / Silver
- No unnecessary colors or visual clutter
- Prioritize readability

### Colors
- Background: `#0A0A0A`
- Primary text: `#F5F5F5`
- Secondary text: white at ~60% opacity
- Glass surface: subtle translucent white/black
- Border: subtle white opacity
- Accent: Silver
- Profit: Green
- Loss: Red
- Warning: Amber

Use semantic green/red only for trading outcomes and warnings.

### Typography
Use a modern system font or Inter. Use a monospace font for prices and trading numbers where appropriate.

### Components
Cards and panels use premium frosted-glass styling with subtle borders, blur, depth, and restrained shadows.

---

## 5. Splash Screen

- GumiBook logo centered
- Dark background
- Subtle silver animation
- Auth/session initialization
- Smooth transition to the correct next screen

Do not force an unnecessarily long splash duration.

---

## 6. Onboarding

### Onboarding 1
Headline: **Track. Analyze. Improve.**

Explain GumiBook as a trading journal focused on speed, analytics, and learning.

### Onboarding 2
Highlight:
- MT5 screenshot extraction
- Psychology journal
- Performance analytics
- Screenshot privacy

CTA: **Get Started** → Login / Sign Up

---

## 7. Authentication

Backend: **Appwrite Authentication**

V1:
- Email/password sign up
- Email/password login
- Logout
- Persistent session

Social login is not required for MVP.

Use secure session handling and never store credentials in plaintext.

---

## 8. Dashboard

Display:
- Balance
- Total P/L
- Win Rate
- Average RR
- Total Trades
- Equity Curve
- Drawdown
- Instrument performance
- Strategy performance
- Session performance
- Emotion performance
- Trading heatmap

If there are no trades, show an informative empty state with an Add Trade CTA.

**Balance card behavior:** Balance is derived from the user's Starting Balance (see Settings → Profile, Section 14). Starting Balance is optional.
- If set: Balance card shows current balance, and Equity Curve starts from that value.
- If not set: Balance card is hidden. Equity Curve still renders using cumulative P/L only, starting from 0.

### Calculations
- Win Rate = winning trades / total trades × 100
- Average RR = mean RR of applicable trades
- Equity = starting balance + cumulative P/L (or cumulative P/L alone if no starting balance is set)
- Drawdown = decline from previous equity peak

---

## 9. Add Trade

Add Trade provides two input paths:

```text
Add Trade
├── Manual Entry
└── Import MT5 Screenshot
```

### 9.1 Manual Entry

Fields:
- Instrument
- Direction: Buy / Sell
- Entry Price
- Exit Price
- Stop Loss
- Take Profit
- Lot Size
- P/L
- Risk/Reward
- Open Date/Time
- Close Date/Time
- Strategy
- Session
- Confluence
- Emotion
- Mistake
- Lesson Learned
- Notes

Required:
- Instrument
- Direction
- Entry
- Exit
- Lot Size
- P/L
- Open Time
- Close Time

Validation:
- Entry must differ from Exit
- Lot size > 0
- Numeric values must be valid
- Missing SL may show a configurable warning instead of blocking submission

---

## 10. MT5 Screenshot Extraction

This is a hero feature.

The intended screenshot is an **MT5 History / Trade History screenshot containing one trade**, not a chart.

### Flow
```text
Add Trade
  ↓
Import MT5 Screenshot
  ↓
Gallery / Camera
  ↓
Crop
  ↓
On-device OCR
  ↓
Review Form
  ↓
Edit / Confirm
  ↓
Save Trade
  ↓
Discard Temporary Image
```

### Crop
The user crops the relevant table area, preferably around one trade. Cropping reduces noise and improves OCR accuracy.

V1 focuses on **one trade per extraction**. Bulk screenshot import is out of scope.

### OCR
Preferred technology: **Google ML Kit Text Recognition**, processed on-device.

Extract only visible values:

| MT5 Field | GumiBook Field |
|---|---|
| Symbol | Instrument |
| Type | Direction |
| Volume | Lot Size |
| Open Time | Open Time |
| Close Time | Close Time |
| Open Price | Entry Price |
| Close Price | Exit Price |
| S/L | Stop Loss |
| T/P | Take Profit |
| Profit | P/L |
| Commission | Commission |
| Swap | Swap |

### Extraction Rules
1. Extract only what is visibly present.
2. Never guess missing values.
3. Never infer direction from profit.
4. Never calculate SL/TP from other values during extraction.
5. OCR results must be reviewed before saving.
6. Unreadable fields remain blank and are editable.

### Errors
- No text: ask user to select a clear MT5 History screenshot.
- Partial extraction: highlight missing fields for manual completion.
- Blurry image: ask for a clearer screenshot.
- Chart/wrong screenshot: explain that MT5 Trade History is required.
- OCR failure: provide Manual Entry fallback.

---

## 11. Screenshot Privacy — Critical

Screenshots are **ephemeral**.

The screenshot must:
- Never be saved to Appwrite Storage
- Never be stored in the database
- Never become an attachment
- Never appear in Trade Detail after processing
- Never be retained as a screenshot gallery

With on-device OCR, the image does not need to leave the device.

After extraction/review, release the temporary image/resources as soon as practical.

Only the user-confirmed **structured trade data** is persisted.

---

## 12. Journal

### List
- Search by instrument, strategy, or notes
- Filter by date, instrument, direction, strategy, session, emotion, mistake, win/loss
- Sort by newest, oldest, P/L, or RR

Each trade card shows:
- Instrument + direction
- Entry → Exit
- P/L
- Date
- Emotion
- Mistake indicator when applicable

### Trade Detail
Sections:
- Execution
- Psychology
- Reflection

Actions:
- Edit
- Delete

No screenshot is displayed because screenshots are never stored.

### Edit
Uses the same trade form with existing values. User can save changes or delete the trade.

---

## 13. Market

Market page may include:

### Watchlist
- Instrument
- Current price
- Change

### Economic Calendar
- Event
- Time
- Currency
- Impact
- Forecast
- Previous
- Actual

### News
Financial market headlines.

### Sentiment
Retail/market sentiment when a reliable provider is available.

### Fear & Greed
Relevant market sentiment index when a suitable data source is available.

### AI Market Summary
A concise summary of major market drivers using available market/news context.

The AI summary must not be presented as financial advice.

---

## 14. Settings

### Profile
- Display name
- Email
- Bio
- Trading since
- Starting Balance (optional; editable at any time)

### Appearance
Dark theme only.

### Notifications
- Daily journal reminder
- Weekly performance summary
- Economic calendar alerts

### Privacy & Data
- Export JSON
- Export CSV
- Delete all data
- Screenshot privacy information
- Optional biometric app lock

### Trading Tools
- Trading Calculator

### Account
- Change password
- Logout
- Delete account

---

## 15. Trading Calculator

Accessible from **Settings → Trading Calculator** and optionally from Add Trade.

Calculator is standalone. Results are not saved.

Modes:
1. Lot Size
2. Position Size
3. Risk
4. Risk %
5. Pip Value
6. Margin
7. Profit
8. Drawdown
9. Compound
10. Risk/Reward

Design:
- Minimal
- Fast input
- Numeric keypad
- Animated results
- Copy result action

Allow custom pip-value override where necessary.

---

## 16. Backend & Technical Stack

### Final Stack
- **Framework:** Flutter
- **Language:** Dart
- **State Management:** Riverpod
- **Navigation:** go_router
- **Backend:** Appwrite
- **Authentication:** Appwrite Authentication
- **Database:** Appwrite Database
- **OCR:** Google ML Kit Text Recognition, on-device
- **Charts:** Suitable Flutter chart library

Architecture should be modular, secure, maintainable, and simple. Avoid unnecessary overengineering.

---

## 17. Appwrite Data Model

### Trades
Fields:
- id
- userId
- instrument
- direction
- entryPrice
- exitPrice
- stopLoss
- takeProfit
- lotSize
- profitLoss
- riskReward
- openTime
- closeTime
- strategy
- session
- confluence
- emotion
- mistakeTags
- lessonLearned
- notes
- inputMethod
- createdAt
- updatedAt

### User Settings
Fields:
- userId
- preferences
- notification settings
- profile metadata
- startingBalance (optional)
- balanceCurrency (optional)
- balanceSetAt (optional)

### Watchlist
Fields:
- userId
- instrument
- addedAt

---

## 18. Appwrite Permissions

Every user's data must be private.

Users can only:
- Read their own trades
- Create their own trades
- Update their own trades
- Delete their own trades

No public access to private journal data.

Do not use Supabase RLS or Firebase Auth. Appwrite permissions are the source of truth.

---

## 19. Security & Privacy

Requirements:
- HTTPS for network communication
- Appwrite authentication
- Per-user database permissions
- Secure session handling
- No screenshot persistence
- No screenshot storage bucket
- Validate all user inputs
- Never expose server/API secrets inside the mobile application

Secrets that must remain private must be handled server-side where applicable.

---

## 20. Data Export & Deletion

Users can export structured trade data as JSON or CSV.

Deleting all data permanently removes the user's stored journal/settings data after confirmation.

Deleting the account must also remove associated user data according to the application's Appwrite deletion flow.

Screenshots cannot be exported because they are never stored.

---

## 21. MVP Priorities

### P0 — Core
- Flutter setup
- Appwrite setup
- Authentication
- Splash
- Onboarding
- Navigation
- Dashboard
- Manual Add Trade
- Journal
- Trade Detail
- Edit/Delete
- Settings

### P1 — Hero Feature
- MT5 screenshot picker
- Crop
- On-device OCR
- Field mapping
- Review/edit
- Ephemeral image disposal

### P1 — Analytics
- Equity curve
- Win rate
- P/L
- RR
- Drawdown
- Instrument/strategy/session analysis
- Heatmap

### P2 — Supporting
- Market
- Economic calendar
- News
- Sentiment
- AI market summary
- Calculator suite
- Data export
- Notifications
- Biometric lock

---

## 22. Out of Scope for V1

- Social feed
- Followers
- Likes
- Public profiles
- Trade sharing
- Community
- Copy trading
- Broker auto-sync
- Multi-account MT5 integration
- Bulk screenshot import
- Screenshot storage/gallery

---

## 23. Acceptance Criteria

### Authentication
User can register, log in, maintain a secure session, and log out.

### Manual Trade
User can create, view, edit, and delete trades.

### Screenshot Import
User can:
```text
Select MT5 screenshot
→ Crop
→ OCR
→ Review
→ Edit
→ Save
```

### Privacy
After processing, the screenshot is not persisted anywhere by GumiBook.

### Analytics
Dashboard statistics update from stored trades.

### Security
A user cannot access another user's journal data.

### UI
The application consistently follows the dark, premium, monochrome/silver, frosted-glass visual direction with smooth Liquid Glass-inspired navigation.

---

## 24. Development & Testing

Development and builds are performed on a VPS to reduce workload on the mobile device.

Workflow:
```text
HP
 ↓ SSH
VPS
 ↓
Flutter + AI coding tools
 ↓
Build APK
 ↓
Transfer APK to HP
 ↓
Install
 ↓
Physical device testing
```

The phone is primarily used as the physical test device rather than the development machine.

---

## 25. Final Product Direction

GumiBook is not merely a CRUD trading journal.

Its product identity is:

> **A premium trading journal that makes trade logging fast, converts MT5 History into structured data without storing screenshots, and turns trading data into actionable performance and psychology insights.**

**Final stack: Flutter + Appwrite.**
