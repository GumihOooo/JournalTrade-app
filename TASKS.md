# GumiBook — Development Task Breakdown

**Document:** `TASKS.md`  
**Product:** GumiBook  
**Version:** 1.0  
**Goal:** Executable backlog untuk implementasi PRD v1.1

---

## 1. Task Conventions

Priority:

- **P0** — Core MVP, harus selesai lebih dahulu.
- **P1** — Hero OCR + analytics.
- **P2** — Supporting features.

Status:

- `[ ]` Todo
- `[-]` In progress
- `[x]` Done

Setiap task dianggap selesai hanya jika acceptance criteria terkait juga terpenuhi.

---

# EPIC P0-01 — Project Foundation

- [ ] P0-01.01 Create Flutter project `gumibook`
- [ ] P0-01.02 Configure Android application ID
- [ ] P0-01.03 Prepare iOS bundle identifier placeholder/config
- [ ] P0-01.04 Add Riverpod
- [ ] P0-01.05 Add `go_router`
- [ ] P0-01.06 Add Appwrite Flutter SDK
- [ ] P0-01.07 Create environment/config layer
- [ ] P0-01.08 Create base folder structure
- [ ] P0-01.09 Add linting/formatting rules
- [ ] P0-01.10 Create base error/failure model + AppwriteException-to-failure mapper
- [x] P0-01.11 Verify `flutter analyze` clean
- [x] P0-01.12 Verify debug APK builds on VPS
- [x] P0-01.13 Install first APK on physical Android device

### Acceptance

- project builds;
- no secret key hardcoded;
- environment config centralized;
- Riverpod and router bootstrap working.

---

# EPIC P0-02 — Design System

- [x] P0-02.01 Implement dark theme
- [x] P0-02.02 Define semantic color tokens
- [x] P0-02.03 Define typography tokens
- [x] P0-02.04 Define spacing/radius tokens
- [x] P0-02.05 Implement `GlassCard`
- [x] P0-02.06 Implement primary/secondary/destructive buttons
- [x] P0-02.07 Implement shared text fields
- [x] P0-02.08 Implement numeric field
- [x] P0-02.09 Implement select/tag components
- [x] P0-02.10 Implement loading state component
- [x] P0-02.11 Implement empty state component
- [x] P0-02.12 Implement error state component
- [x] P0-02.13 Implement confirmation dialog
- [x] P0-02.14 Implement profit/loss semantic text component

### Acceptance

- all core screens can reuse same tokens/components;
- monochrome/silver is default;
- profit/loss color is semantic only.

---

# EPIC P0-03 — Appwrite Setup

- [x] P0-03.01 Create Appwrite project
- [x] P0-03.02 Configure HTTPS endpoint
- [x] P0-03.03 Configure mobile platform(s)
- [x] P0-03.04 Create `gumibook` database
- [x] P0-03.05 Create `trades` collection
- [x] P0-03.06 Create `user_settings` collection
- [x] P0-03.07 Create `watchlist` collection
- [x] P0-03.08 Add `trades` attributes from `DATABASE.md`
- [x] P0-03.09 Add `user_settings` attributes
- [x] P0-03.10 Add `watchlist` attributes
- [x] P0-03.11 Create required indexes (9 index user_* di trades via appwrite.json + CLI push; schema full: 22 attribute trades, 13 attribute user_settings)
- [x] P0-03.12 Configure collection/document permission strategy
- [x] P0-03.13 Test User A cannot access User B records

### Acceptance

- no public database access;
- owner-only trade access verified;
- collections match database documentation.

---

# EPIC P0-04 — App Bootstrap & Routing

- [x] P0-04.01 Implement app bootstrap
- [x] P0-04.02 Initialize Appwrite client once
- [x] P0-04.03 Create account/database providers
- [x] P0-04.04 Implement onboarding local flag
- [x] P0-04.05 Implement auth state provider
- [x] P0-04.06 Build splash route
- [x] P0-04.07 Implement redirect logic
- [x] P0-04.08 Build app shell route (GumiScaffold; LGAppBar via flutter_liquid_glass_plus)
- [x] P0-04.09 Add 5-destination bottom navigation (LGBottomBar via flutter_liquid_glass_plus, LGQuality.standard)
- [x] P0-04.10 Add prominent Add Trade action
- [-] P0-04.11 Implement compact/expanded navigation behavior (scroll-driven collapse; blocked on LGBottomBar lacking scroll API — revisit at P0-09 Journal or swap nav implementation)

### Acceptance

- first launch → onboarding;
- onboarding done + no session → login;
- active session → dashboard;
- no redirect loop.

---

# EPIC P0-05 — Splash & Onboarding

- [x] P0-05.01 Build splash screen (splash Lottie + wordmark done; app launcher icon masih default Flutter)
- [x] P0-05.01a Generate native splash via flutter_native_splash (solid color #0A0B0E, minimalist)
- [x] P0-05.02 Add subtle silver animation (Lottie splash.json monochrome silver, half-speed)
- [x] P0-05.03 Build onboarding page 1
- [x] P0-05.04 Use headline `Track. Analyze. Improve.`
- [x] P0-05.05 Build onboarding page 2
- [x] P0-05.06 Explain MT5 extraction
- [x] P0-05.07 Explain psychology journal
- [x] P0-05.08 Explain analytics
- [x] P0-05.09 Explain screenshot privacy
- [x] P0-05.10 Implement `Get Started`
- [x] P0-05.11 Persist onboarding completion locally

---

# EPIC P0-06 — Authentication

- [x] P0-06.01 Implement AuthRepository interface
- [x] P0-06.02 Implement AppwriteAuthRepository
- [x] P0-06.03 Build login screen
- [x] P0-06.04 Build sign-up screen
- [x] P0-06.05 Add email validation
- [x] P0-06.06 Add password validation
- [x] P0-06.07 Add password visibility toggle
- [x] P0-06.08 Implement login loading/error states
- [x] P0-06.09 Implement signup loading/error states
- [x] P0-06.10 Implement session restore
- [x] P0-06.11 Implement logout
- [x] P0-06.12 Create default user settings if required (UserSettingsRepository.ensureDefault on signup, docId=userId, owner-only perms)
- [x] P0-06.13 Test invalid credentials (auth_flow_test: snackbar "Invalid email or password.", stay on auth)
- [-] P0-06.14 Test persisted session after app restart (unit covered by fake-account boot probe; device test pending QA-01.04)

### Acceptance

- signup works;
- login works;
- logout works;
- session persistence works;
- password is never stored manually.

---

# EPIC P0-07 — Trade Domain & Repository

- [x] P0-07.01 Create `Trade` entity
- [x] P0-07.02 Create `TradeDraft`
- [x] P0-07.03 Create direction/input-method/trading-session/outcome enums
- [x] P0-07.04 Implement trade validation (incl. `closeTime >= openTime`)
- [x] P0-07.05 Implement Appwrite trade mapper
- [x] P0-07.06 Implement `TradeRepository.create`
- [x] P0-07.07 Implement `TradeRepository.update`
- [x] P0-07.08 Implement `TradeRepository.delete`
- [x] P0-07.09 Implement `TradeRepository.getById`
- [x] P0-07.10 Implement `TradeRepository.list`
- [x] P0-07.11 Add owner permission on create
- [x] P0-07.12 Add repository unit tests

---

# EPIC P0-08 — Manual Add Trade

- [x] P0-08.01 Build Add Trade method selector
- [x] P0-08.02 Build Execution form section (shared `SectionHeader`)
- [x] P0-08.03 Build Trading Context section
- [x] P0-08.04 Build Psychology section
- [x] P0-08.05 Build Reflection section
- [x] P0-08.06 Implement required field validation
- [x] P0-08.07 Implement numeric validation
- [x] P0-08.08 Enforce entry != exit
- [x] P0-08.09 Enforce lot size > 0
- [x] P0-08.10 Add missing SL warning
- [x] P0-08.11 Implement open/close datetime picker (shared `DateTimeField`)
- [x] P0-08.12 Implement save controller
- [x] P0-08.13 Disable duplicate submit while saving
- [x] P0-08.14 Set `inputMethod = manual`
- [x] P0-08.15 Refresh journal after save
- [x] P0-08.16 Refresh dashboard after save
- [x] P0-08.17 Test manual create flow on physical device (audit Batch 1: form currency suffix, negative P/L input, Mistake-in-Psychology layout now follow DESIGN.md; device pass pending)

### Acceptance

- required minimum fields can create trade;
- invalid input does not persist;
- missing SL warns but can save;
- saved trade appears in Journal.

---

# EPIC P0-09 — Journal

- [x] P0-09.01 Build Journal screen
- [x] P0-09.02 Implement newest-first list
- [x] P0-09.03 Implement trade list tile
- [x] P0-09.04 Implement Journal empty state
- [x] P0-09.05 Add search UI
- [x] P0-09.06 Search instrument
- [x] P0-09.07 Search strategy
- [x] P0-09.08 Search notes
- [x] P0-09.09 Add date filter (shared `FilterChip`)
- [x] P0-09.10 Add instrument filter
- [x] P0-09.11 Add direction filter
- [x] P0-09.12 Add strategy filter
- [x] P0-09.13 Add session filter
- [x] P0-09.14 Add emotion filter
- [x] P0-09.15 Add mistake filter
- [x] P0-09.16 Add win/loss filter
- [x] P0-09.17 Add sort Newest
- [x] P0-09.18 Add sort Oldest
- [x] P0-09.19 Add sort P/L
- [x] P0-09.20 Add sort RR
- [x] P0-09.21 Add pagination if dataset threshold requires it (audit Batch 1 rework: full-dataset load via `listAll()` page walk — dashboard stats and filters see every trade; lazy windowed paging deferred until a real journal passes a few thousand trades)

---

# EPIC P0-10 — Trade Detail / Edit / Delete

- [x] P0-10.01 Build Trade Detail Execution section
- [x] P0-10.02 Build Psychology section
- [x] P0-10.03 Build Reflection section
- [x] P0-10.04 Add Edit action
- [x] P0-10.05 Build Edit Trade form
- [x] P0-10.06 Implement update repository call
- [x] P0-10.07 Refresh detail/journal/dashboard after update
- [x] P0-10.08 Add Delete action
- [x] P0-10.09 Add delete confirmation
- [x] P0-10.10 Delete document
- [x] P0-10.11 Return to Journal after delete
- [x] P0-10.12 Verify no screenshot section exists

---

# EPIC P0-11 — Dashboard Base

- [x] P0-11.01 Build Dashboard screen shell
- [x] P0-11.02 Build Balance metric card via shared `MetricCard` (hidden if Starting Balance not set)
- [x] P0-11.03 Build Total P/L card
- [x] P0-11.04 Build Win Rate card placeholder/calculation
- [x] P0-11.05 Build Average RR card placeholder/calculation
- [x] P0-11.06 Build Total Trades card
- [x] P0-11.07 Build dashboard empty state
- [x] P0-11.08 Add `Add Trade` CTA from empty state

---

# EPIC P0-12 — Settings Base

- [x] P0-12.01 Build Settings screen
- [x] P0-12.02 Build Profile section
- [x] P0-12.03 Display account email
- [x] P0-12.04 Edit display name
- [x] P0-12.05 Edit bio
- [x] P0-12.06 Edit trading since
- [x] P0-12.06a Add optional Starting Balance field (nullable, editable anytime; audit Batch 1: empty field on Save = explicit clear, 0/negative rejected, `clearStartingBalance` write)
- [x] P0-12.06b Add optional currency picker for `balanceCurrency` (default USD; audit Batch 1: journal/detail/form P/L currency now reads it — no hardcoded USD)
- [x] P0-12.06c Update `balanceSetAt` when Starting Balance is set or edited (audit Batch 1: stamped only on real balance changes; Trading Since clearable, epoch sentinel mapped to null on read)
- [x] P0-12.07 Build Appearance section
- [x] P0-12.08 Keep dark theme default
- [x] P0-12.09 Build Account section
- [x] P0-12.10 Implement change password (audit Batch 1: inline validation inside the dialog, controllers disposed)
- [x] P0-12.11 Implement logout action
- [x] P0-12.12 Add delete account entry point placeholder/flow

---

# EPIC P0-13 — Core Security Verification

- [x] P0-13.01 Verify HTTPS Appwrite endpoint (audit Batch 1: INTERNET permission added to main Android manifest — release builds could not reach Appwrite before)
- [x] P0-13.02 Verify no server API key in app
- [x] P0-13.03 Verify User A cannot list User B trades
- [x] P0-13.04 Verify User A cannot read User B trade by ID
- [x] P0-13.05 Verify User A cannot update User B trade
- [x] P0-13.06 Verify User A cannot delete User B trade
- [x] P0-13.07 Review logs for sensitive data leakage (audit Batch 1: `allowBackup=false` + data extraction rules keep Appwrite session cookies on device)
- [x] P0-13.08 Verify destructive actions confirm first
- [x] P0-13.09 User settings doc-squatting hardening (audit K-2, Opsi B client-side: documentId = `ID.unique()` random, lookup via `Query.equal('userId')` + unique index `user_id`, ownership verification dengan fallback default untuk kondisi ambigu; ditambah 7 unit test squat-guard. Server-side Function tetap hardening jangka panjang)

---

# EPIC P1-01 — Screenshot Acquisition

- [x] P1-01.01 Add image picker dependency
- [x] P1-01.02 Add camera permission/config
- [x] P1-01.03 Add gallery permission/config if required by platform
- [x] P1-01.04 Build screenshot import entry screen
- [x] P1-01.05 Add Gallery action
- [x] P1-01.06 Add Camera action
- [x] P1-01.07 Add privacy notice
- [x] P1-01.08 Explain supported MT5 History screenshot
- [x] P1-01.09 Explain chart screenshot is unsupported

---

# EPIC P1-02 — Crop

- [x] P1-02.01 Add crop dependency
- [x] P1-02.02 Build crop flow
- [x] P1-02.03 Add instruction `select area containing one trade`
- [x] P1-02.04 Limit MVP flow to one trade per extraction
- [x] P1-02.05 Handle cancel safely
- [x] P1-02.06 Track temporary cropped file lifecycle

---

# EPIC P1-03 — AI-gateway OCR (revised from on-device ML Kit)

- [x] P1-03.01 Add Google ML Kit text recognition (now fallback engine)
- [x] P1-03.02 Implement `OcrEngine` abstraction
- [x] P1-03.03 Implement ML Kit engine (fallback when gateway/Gemini fails)
- [x] P1-03.04 Process cropped image via `gumibook-ai-gateway` Appwrite Function → Gemini 3 Flash (vision), image sent transiently, never stored anywhere
- [x] P1-03.05 Return structured Trade JSON from Gemini (strict OCR prompt: extract only visible values, no inference)
- [x] P1-03.06 Build OCR processing state
- [x] P1-03.07 Handle no-text failure
- [x] P1-03.08 Handle OCR engine failure (gateway error falls back to ML Kit)
- [x] P1-03.09 Verify image only leaves device transiently to AI gateway; no permanent storage on device, GumiBook server, or Gemini

---

# EPIC P1-04 — MT5 Parser

- [x] P1-04.01 Create parser test fixtures
- [x] P1-04.02 Parse Symbol → Instrument
- [x] P1-04.03 Parse Type → Direction
- [x] P1-04.04 Parse Volume → Lot Size
- [x] P1-04.05 Parse Open Time
- [x] P1-04.06 Parse Close Time
- [x] P1-04.07 Parse Open Price → Entry
- [x] P1-04.08 Parse Close Price → Exit
- [x] P1-04.09 Parse S/L
- [x] P1-04.10 Parse T/P
- [x] P1-04.11 Parse Profit → P/L
- [x] P1-04.12 Parse Commission
- [x] P1-04.13 Parse Swap
- [x] P1-04.14 Leave missing values null
- [x] P1-04.15 Test parser does not infer missing values
- [x] P1-04.16 Test parser does not infer direction from profit

---

# EPIC P1-05 — OCR Review

- [x] P1-05.01 Build extracted data review screen (shared AddTradeScreen via `initialDraft`, title "Review Extracted Trade")
- [x] P1-05.02 Pre-fill detected fields
- [x] P1-05.03 Mark missing fields `Needs review` (extraction screen warn line + empty required fields; per-field badge deferred until design QA)
- [x] P1-05.04 Allow editing every extracted field
- [x] P1-05.05 Do not auto-save
- [x] P1-05.06 Validate before confirm
- [x] P1-05.07 Save `inputMethod = ocr`
- [x] P1-05.08 Refresh journal/dashboard after save
- [x] P1-05.09 Provide Manual Entry fallback

---

# EPIC P1-06 — Screenshot Privacy & Cleanup

- [x] P1-06.01 Confirm no Appwrite Storage integration for screenshot
- [x] P1-06.02 Confirm no screenshot URL/path in database
- [x] P1-06.03 Delete/release temp file after successful save
- [x] P1-06.04 Delete/release temp file after cancel
- [x] P1-06.05 Delete/release temp file after OCR error
- [x] P1-06.06 Verify Trade Detail never renders screenshot
- [x] P1-06.07 Verify export excludes screenshot
- [x] P1-06.08 Add privacy information in Settings

### Acceptance

- screenshot exists only as temporary local processing input;
- no persistent screenshot survives feature flow under normal lifecycle.

---

# EPIC P1-07 — OCR Error UX

- [x] P1-07.01 Implement `Could not detect trade data.` (exact DESIGN.md §5.12 copy; `OcrOutcome` classification in `ocr_review_screen.dart`)
- [x] P1-07.02 Implement partial extraction state (Detected-fields summary line + missing-fields warning; per-field `Needs review` badge stays deferred to design QA)
- [x] P1-07.03 Implement blurry image message (gradient-energy sharpness heuristic in `MlKitOcrEngine._looksBlurry`; exact §5.12 copy)
- [x] P1-07.04 Implement non-MT5/chart warning (text-present-but-no-row-signature, conservative per IMPLEMENTATION.md §18)
- [x] P1-07.05 Implement Retry (re-runs engine over the same crop; temp file now released on dispose/handoff — P1-06 lifecycle intact)
- [x] P1-07.06 Implement Choose Another Screenshot (primary on blurry state as Choose a Clearer Screenshot)
- [x] P1-07.07 Implement Manual Entry recovery (always offered on every error state)

---

# EPIC P1-08 — Analytics Engine

- [x] P1-08.01 Implement total P/L
- [x] P1-08.02 Implement total trades
- [x] P1-08.03 Implement win rate
- [x] P1-08.04 Implement average RR
- [x] P1-08.05 Implement equity curve
- [x] P1-08.05a Handle nullable `startingBalance` (fallback to 0 origin)
- [x] P1-08.06 Implement drawdown (deepest peak decline; starting balance anchors origin peak)
- [x] P1-08.07 Implement instrument breakdown
- [x] P1-08.08 Implement strategy breakdown (null keys excluded, P/L-desc sort)
- [x] P1-08.09 Implement session breakdown
- [x] P1-08.10 Implement emotion breakdown
- [x] P1-08.11 Implement trading heatmap data transform (ISO weekday × close hour buckets)
- [x] P1-08.12 Add unit tests for all analytics functions (24 tests, test/dashboard/analytics_test.dart, TDD)
- [x] P1-08.13 Handle zero-trade dataset (zeros/empty, never NaN, never throws)
- [x] P1-08.14 Handle nullable RR (mean over RR-carrying trades only; null when none)

---

# EPIC P1-09 — Dashboard Charts

- [x] P1-09.01 Select charting library (fl_chart ^1.2.0 for line/area charts; breakdown + heatmap pure widgets — no extra deps)
- [x] P1-09.02 Implement Equity Curve (shared `ChartContainer`)
- [x] P1-09.03 Implement Drawdown chart (running peak decline area, loss color)
- [x] P1-09.04 Implement performance breakdown (shared PerformanceBreakdown bars, signed P/L text for a11y)
- [x] P1-09.05 Implement instrument performance
- [x] P1-09.06 Implement strategy performance
- [x] P1-09.07 Implement session performance
- [x] P1-09.08 Implement emotion performance
- [x] P1-09.09 Implement trading heatmap (7×24 grid, fixed 12px cells fit 360dp, per-cell Semantics labels)
- [x] P1-09.10 Add chart empty states (empty breakdowns hidden; screen-level empty state covers zero trades; charts render empty datasets without crash)
- [-] P1-09.11 Test chart performance on physical device (widget tests pass; device QA pending with QA-01.12)

---

# EPIC P2-01 — Trading Calculator

- [x] P2-01.01 Build calculator hub (`CalculatorHubScreen`, GlassCard list, route `/settings/calculator` menggantikan stub P0-12)
- [x] P2-01.02 Lot Size calculator (`calculator_formulas.dart` `lotSize`, TDD)
- [x] P2-01.03 Position Size calculator (`positionSize`, TDD)
- [x] P2-01.04 Risk calculator (`riskMoney`, TDD)
- [x] P2-01.05 Risk % calculator (`riskPercent`, TDD)
- [x] P2-01.06 Pip Value calculator with custom pip-value override (`pipValue`; lot-size calculator menerima pip value per lot manual sebagai override)
- [x] P2-01.07 Margin calculator (`margin`, TDD)
- [x] P2-01.08 Profit calculator (`profit`, direction-aware Buy/Sell, TDD)
- [x] P2-01.09 Drawdown calculator (`drawdown` + `drawdownPercent`, floored at 0, TDD)
- [x] P2-01.10 Compound calculator (`compound`, TDD)
- [x] P2-01.11 Risk/Reward calculator (`riskReward`, TDD)
- [x] P2-01.12 Add copy result action (Clipboard per result row, snackbar konfirmasi; widget test mock `Clipboard.setData`)
- [x] P2-01.13 Add formula unit tests (27 test formula TDD + 4 widget test, `test/calculator/`)
- [x] P2-01.14 Verify calculator writes nothing to database (grep: `lib/features/calculator/` tanpa import appwrite/repository/DB — formula pure, state ephemeral di widget)

---

# EPIC P2-02 — Data Export

- [x] P2-02.01 Implement JSON exporter
- [x] P2-02.02 Implement CSV exporter
- [x] P2-02.03 Escape CSV values correctly
- [x] P2-02.04 Use ISO 8601 datetime
- [x] P2-02.05 Export only current user data
- [x] P2-02.06 Verify no screenshot included
- [x] P2-02.07 Add share/save action

---

# EPIC P2-03 — Delete Data / Delete Account

- [x] P2-03.01 Build Delete All Data confirmation
- [x] P2-03.02 Delete current user's trades
- [x] P2-03.03 Delete current user's watchlist
- [x] P2-03.04 Handle settings according to final product decision (Delete All Data keeps settings; Delete Account removes them first — final decision 2026-09-12)
- [x] P2-03.05 Build Delete Account confirmation
- [x] P2-03.06 Delete owned records before account removal
- [x] P2-03.07 Delete Appwrite account
- [x] P2-03.08 Clear local state
- [x] P2-03.09 Verify no orphan user records

---

# EPIC P2-04 — Watchlist

- [x] P2-04.01 Implement WatchlistRepository
- [x] P2-04.02 Add instrument
- [x] P2-04.03 Remove instrument
- [x] P2-04.04 Prevent duplicate instrument per user
- [x] P2-04.05 Add sort order if needed
- [x] P2-04.06 Render watchlist market state

---

# EPIC P2-05 — Market Provider

- [x] P2-05.01 Research/select market data provider (FINAL REVISI 2026-09-15: **Sugra API (sugra.ai)** untuk quotes+business news+GDELT market mood; LSE untuk economic calendar; feargreedchart.com untuk Fear & Greed; TradingView Widget untuk chart. OpenWeb Ninja DIGANTI — free tier 100 req/BULAN terlalu ketat; Sugra free 50 req/hari)
- [x] P2-05.02 Review licensing and rate limits (free tier rate limits: retry 1x dengan backoff 1s di gateway; Fear&Greed public no-auth)
- [x] P2-05.03 Determine secret-key requirements (SUGRA_API_KEY + LSE_API_KEY sebagai secret Appwrite Console — tidak pernah di kode/git; GEMINI_API_KEY untuk task ocr)
- [x] P2-05.04 Create backend proxy/function if secret is required (konsolidasi: semua market task DI `gumibook-ai-gateway` — `marketPrice`, `marketNews`, `marketCalendar` — function terpisah DIHAPUS untuk hemat slot free tier; hanya 1 function aktif)
- [x] P2-05.05 Implement MarketDataRepository adapter (`lib/features/market/market_data_repository.dart`, `MarketTransport` abstraction, 27 test TDD)
- [x] P2-05.06 Implement price/change data (price + changePercent + change chip, `PriceFlashText` animation)
- [x] P2-05.07 Implement Economic Calendar (today-only filter UTC, `filterTodayEvents`)
- [x] P2-05.08 Implement News (business feed via Sugra `/api/v1/news/latest`)
- [x] P2-05.09 Implement Sentiment if provider supports it (FINAL REVISI: GDELT tone chart dari Sugra datang DI DALAM response `marketNews` — TIDAK ADA task `sentiment` Gemini terpisah; satu chip MOOD per section; GDELT throttle = no-data badge)
- [x] P2-05.10 Implement Fear & Greed if data exists (feargreedchart.com `?action=all`, score + CNN-standard rating tiers)
- [x] P2-05.11 Add loading/no-data/error states (5 state per section, section independence teruji di widget test)
- [x] P2-05.12 (BARU) Market Session Clock — indikator sesi Sydney/Tokyo/London/NewYork + OVERLAP badge, murni kalkulasi UTC offset (`market_session_clock.dart`, 7 test)
- [x] P2-05.13 (BARU) Loading Shimmer — skeleton mengikuti bentuk card (`gumi_shimmer.dart`), bukan spinner polos
- [x] P2-05.14 (BARU) Price flash animation — angka flash hijau saat berubah (`price_flash_text.dart`)
- [x] P2-05.15 (BARU) Empty state didesain (icon + copy ramah per section)
- [x] P2-05.16 (BARU) Pull-to-refresh + haptic feedback (RefreshIndicator + HapticFeedback.mediumImpact)
- [x] P2-05.17 (BARU) TradingView Widget chart utama (embed resmi via webview_flutter, bukan render manual; format simbol FX:/OANDA:/BITSTAMP:/NASDAQ:/SP:/TVC:)
- [x] P2-05.18 (BARU) Provision secret keys di Appwrite Console: SUGRA_API_KEY + LSE_API_KEY ter-set via CLI (env-sugra, env-lse), OPENWEB_NINJA_API_KEY dihapus; function redeployed (deployment 6aa8f9e61ae42ab036c8, status ready) — marketCalendar e2e OK 89 events; marketPrice e2e tertahan Sugra 429 daily limit (discovery pakai ~50 req hari ini), reset UTC midnight
- [x] P2-05.19 (BARU) Konsolidasi backend: task market dipindah ke `gumibook-ai-gateway` (slot 2 dihemat), handler fix `{handler: fn}`, error contract 500 missing-key / 429 rate-limit / 502 provider-down; smoke test raw verified
- [x] P2-05.20 (BARU) Default watchlist prioritas user (NQ, XAUUSD, YM, ES, EURUSD, GBPUSD, USDJPY, BTCUSD, DXY, US10Y, USOIL) + tombol seed satu-tap; TradingView symbols VERIFIKASI live via symbol search 2026-09-13 (CBOT:YM1! & TVC:USOIL INVALID, diganti CBOT_MINI:YM1! & NYMEX:CL1!); alias broker NAS100/DJ30/SP500/US30 tetap dikenali
- [x] P2-05.21 (BARU) ICT Kill Zones session clock (Asia 20:00-00:00, London 02:00-05:00, NY AM 08:30-11:00, NY PM 13:30-16:00 ET) — DST-aware via package `timezone` (America/New_York), weekdays only, ticker 30s, OVERLAP badge; 7 test termasuk bukti pergeseran EST/EDT
- [x] P2-05.22 (BARU) Economic calendar filter hari-ini pakai TIMEZONE USER (local day), bukan UTC
- [x] P2-05.23 (BARU) Fear & Greed dilabel "General market mood" (sentimen US market, bukan per-pair)
- [x] P2-05.24 (BARU) Switch provider ke Sugra: backend `main.js` marketPrice pakai futures roots (NQ/ES/YM/GC/6E/6B/6J/CL) + quotes (^USDOLLAR/^TNX) + crypto (bitcoin), USDJPY di-invert (6J = JPY/USD); marketNews = `/api/v1/news/latest` + GDELT tone; hapus semua referensi OpenWeb Ninja
- [x] P2-05.25 (BARU) Discovery Sugra raw: `api.sugra.ai` NXDOMAIN (base = `sugra.ai/api/{v1,v2}`); `EUR-USD` di v2 quotes = crypto coin (bukan pair); `GBP-USD`/`USD-JPY` not found → forex pakai futures root; openapi.json 1626 endpoint diekstrak lokal
- [x] P2-05.26 (BARU) Dart layer refactor untuk Sugra: `fetchNews` return `NewsBundle` (news + shared GDELT sentiment), hapus `getSentiment`/`sentimentProvider`/`instrumentToYahooSymbol`; `parseGdeltTone` bucket tonechart; `_NewsMoodBadge` satu chip per section; watchlist key NQ/YM/ES; 279 test pass, analyze 0 issues
- [ ] P2-05.27 (BARU, BLOCKED) Verifikasi e2e `marketPrice` + `marketNews`+GDELT dengan data live: tertahan Sugra free-tier 429 (quota 50/hari habis saat discovery). Jalankan ulang setelah reset UTC midnight: `marketPrice` untuk NQ/XAUUSD/EURUSD, `marketNews` minimal 3 berita + field sentiment. `marketCalendar` sudah OK (89 events hari ini, 2026-09-15)
- [x] P2-05.28 (BARU) DXY benar: `DX-Y.NYB` TIDAK bisa diverifikasi di Sugra (`/api/v1/search` = 404; quota 429 saat probe ticker). Skenario B dieksekusi: angka DXY di-skip dari watchlist price card (`_noPriceCardInstruments`), `^USDOLLAR` (Dow Jones FXCM, skala ~12k) dihapus dari QUOTE_MAP; chart TradingView `TVC:DXY` jadi satu-satunya representasi DXY. Re-cek `DX-Y.NYB` setelah quota reset — kalau ada, tinggal tambah baris QUOTE_MAP + hapus filter
- [x] P2-05.29 (BARU) Paralelisasi quote: `fetchQuote` per-simbol + `Promise.all`, loop sekuensial 11 simbol dihapus (sebelumnya bisa >15s timeout Appwrite). Failure per-simbol tetap isolate jadi error row
- [x] P2-05.30 (BARU) Cache 10 menit di `gateway_cache` collection (Appwrite Database, BUKAN in-memory — function ephemeral/cold-start). TTL 10 menit; key sort-independen; payload all-error (429) TIDAK di-cache; `cacheRead`/`cacheWrite` never-throw. Scope function +`databases.read/write`. node:test 3 test (hit/expired/key-order), 3 pass

---

# EPIC P2-06 — AI Market Summary

- [ ] P2-06.01 Define summary input contract
- [ ] P2-06.02 Ensure summary only uses available market/news data
- [ ] P2-06.03 Add backend execution if secret model/API key is required
- [ ] P2-06.04 Add `not financial advice` disclaimer
- [ ] P2-06.05 Handle no-data state
- [ ] P2-06.06 Add timeout/error state

---

# EPIC P2-07 — Notifications

- [ ] P2-07.01 Add Daily Journal Reminder preference
- [ ] P2-07.02 Implement daily local reminder
- [ ] P2-07.03 Add Weekly Performance Summary preference
- [ ] P2-07.04 Implement weekly summary notification mechanism
- [ ] P2-07.05 Add Economic Calendar Alert preference
- [ ] P2-07.06 Implement calendar alert only after provider supports reliable events
- [ ] P2-07.07 Handle notification permissions

---

# EPIC P2-08 — Biometric Lock

- [ ] P2-08.01 Add biometric capability detection
- [ ] P2-08.02 Add enable/disable setting
- [ ] P2-08.03 Prompt on app resume when enabled
- [ ] P2-08.04 Handle device without biometric support
- [ ] P2-08.05 Ensure biometric does not store account password

---

# EPIC QA-01 — Cross-feature Testing

- [ ] QA-01.01 Test clean install
- [ ] QA-01.02 Test onboarding completion
- [ ] QA-01.03 Test signup/login/logout
- [ ] QA-01.04 Test session after app restart
- [ ] QA-01.05 Test manual trade CRUD (audit Batch 1 note: negative manual P/L input now possible on Android decimal keyboard)
- [ ] QA-01.06 Test Journal filters and sorting
- [ ] QA-01.07 Test OCR full path
- [ ] QA-01.08 Test OCR partial data
- [ ] QA-01.09 Test OCR invalid screenshot
- [ ] QA-01.10 Test screenshot cleanup
- [ ] QA-01.11 Test Dashboard with 0 trades
- [ ] QA-01.12 Test Dashboard with mixed trades
- [ ] QA-01.13 Test destructive actions
- [ ] QA-01.14 Test owner permissions using two accounts
- [ ] QA-01.15 Test small-screen layout
- [ ] QA-01.16 Test keyboard overlap
- [ ] QA-01.17 Test app background/resume
- [x] QA-01.18 Run `flutter analyze` (audit Batch 1: 0 issues)
- [x] QA-01.19 Run unit/widget tests (audit Batch 1: 94/94 pass; `noNetworkOverrides` helper isolates the auth boot probe in widget tests)
- [ ] QA-01.20 Build release APK (with release signing config)
- [ ] QA-01.21 Accessibility audit per `DESIGN.md` §8: contrast, semantic labels for icon buttons, text scaling, profit/loss not color-only, error text messages, 44–48dp touch targets, destructive confirmation

---

# EPIC DOC-01 — Documentation & Release Hygiene

- [ ] DOC-01.01 Keep `DESIGN.md` updated
- [ ] DOC-01.02 Keep `ARCHITECTURE.md` updated
- [ ] DOC-01.03 Keep `DATABASE.md` updated
- [ ] DOC-01.04 Keep `IMPLEMENTATION.md` updated
- [ ] DOC-01.05 Update `TASKS.md` status after each milestone
- [ ] DOC-01.06 Document environment variables
- [ ] DOC-01.07 Document Appwrite collection IDs outside source hardcoding
- [ ] DOC-01.08 Document database schema changes
- [ ] DOC-01.09 Add basic README setup steps

---

## Recommended Execution Order

```text
P0-01 Foundation
   ↓
P0-02 Design System
   ↓
P0-03 Appwrite Setup
   ↓
P0-04 Routing/Bootstrap
   ↓
P0-05 Onboarding
   ↓
P0-06 Authentication
   ↓
P0-07 Trade Repository
   ↓
P0-08 Manual Add Trade
   ↓
P0-09 Journal
   ↓
P0-10 Detail/Edit/Delete
   ↓
P0-11 Dashboard Base
   ↓
P0-12 Settings Base
   ↓
P0-13 Security Verification
   ↓
P1-01..07 OCR
   ↓
P1-08..09 Analytics
   ↓
P2 Supporting Features
```

---

## MVP Exit Criteria

GumiBook core MVP dianggap siap bila:

- [ ] user dapat signup/login/logout;
- [ ] session persistence berjalan;
- [ ] user dapat membuat manual trade;
- [ ] Journal menampilkan trade;
- [ ] user dapat membuka detail;
- [ ] user dapat edit/delete trade;
- [ ] dashboard menghitung data dari trades;
- [ ] User A tidak dapat mengakses User B data;
- [ ] screenshot OCR flow bekerja satu trade per extraction;
- [ ] OCR tidak menebak missing data;
- [ ] OCR selalu masuk review sebelum save;
- [ ] screenshot tidak disimpan persistently;
- [ ] UI dark premium konsisten;
- [ ] release APK dapat diuji di physical Android device.

---

## Out-of-Scope Guardrail

Jangan membuat task implementasi V1 untuk:

- social feed;
- followers;
- likes;
- public profiles;
- trade sharing;
- community;
- copy trading;
- broker auto-sync;
- multi-account MT5 integration;
- bulk screenshot import;
- screenshot gallery/storage.
