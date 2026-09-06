# GumiBook — Application Architecture

**Document:** `ARCHITECTURE.md`  
**Product:** GumiBook  
**Version:** 1.0  
**Architecture target:** Flutter mobile application + Appwrite backend

---

## 1. Architectural Goals

Arsitektur GumiBook dirancang untuk memenuhi kebutuhan berikut:

1. Menjaga codebase Flutter mudah dikembangkan dan diuji.
2. Memisahkan UI, business logic, dan data access.
3. Membatasi ketergantungan langsung terhadap Appwrite pada layer UI.
4. Menjaga screenshot MT5 tetap ephemeral.
5. Menjalankan OCR on-device.
6. Menjamin data antar-user terisolasi melalui Appwrite permissions.
7. Mendukung analytics yang dihitung dari structured trade data.
8. Tidak membuat offline-sync architecture kompleks pada MVP.
9. Menyediakan extension point untuk market/news provider tanpa mengunci provider terlalu awal.

---

## 2. Final Technology Stack

| Area | Decision |
|---|---|
| UI framework | Flutter |
| Language | Dart |
| Routing | `go_router` |
| State management | Riverpod |
| Backend | Appwrite |
| Authentication | Appwrite Authentication |
| Database | Appwrite Database |
| OCR | Google ML Kit Text Recognition, on-device |
| Charts | Flutter charting library selected during implementation |
| Native splash | `flutter_native_splash` |
| Glass navigation | `flutter_liquid_glass_plus` (`LGAppBar`, `LGBottomBar`, `LGQuality.standard`) |
| Glass card umum | custom `GlassCard` (backdrop blur, token gumi) |
| Target platform | Android + iOS |
| Development | VPS |
| Android testing | Physical device via APK |

---

## 3. High-Level Architecture

```text
┌───────────────────────────────────────────────┐
│                Flutter Application            │
│                                               │
│  Presentation                                │
│  ├─ Screens / Widgets                        │
│  ├─ go_router                                │
│  └─ Riverpod UI state                        │
│                                               │
│  Application                                 │
│  ├─ Use cases / services                     │
│  ├─ validation                               │
│  ├─ analytics                                │
│  └─ OCR extraction orchestration             │
│                                               │
│  Domain                                      │
│  ├─ Trade                                    │
│  ├─ UserProfile                              │
│  ├─ WatchlistItem                            │
│  └─ value objects / enums                    │
│                                               │
│  Data                                        │
│  ├─ Repositories                             │
│  ├─ Appwrite data source                     │
│  ├─ ML Kit OCR data source                   │
│  └─ local preferences                        │
└───────────────────────────────────────────────┘
          │                 │
          │                 └─────────────┐
          ▼                               ▼
┌─────────────────────┐       ┌──────────────────────┐
│      Appwrite       │       │   Device Services    │
│ Auth + Database     │       │ Camera/Gallery       │
│ Per-user permission │       │ Crop + ML Kit OCR    │
└─────────────────────┘       └──────────────────────┘
```

Market/news integration berada di luar core MVP dan harus diakses melalui adapter/provider interface.

---

## 4. Layer Responsibilities

## 4.1 Presentation Layer

Tanggung jawab:

- screen rendering;
- user interaction;
- form state;
- loading/error/empty state;
- navigation;
- memanggil application controller/use case melalui Riverpod.

Tidak boleh:

- memanggil Appwrite Database langsung dari widget;
- menjalankan analytics calculation kompleks di widget;
- menyimpan screenshot ke backend;
- menaruh secret key di source code.

---

## 4.2 Application Layer

Tanggung jawab:

- menjalankan use case;
- orchestration antar repository/service;
- validation;
- transform OCR result ke draft trade;
- analytics calculation;
- lifecycle temporary image;
- memastikan user confirmation sebelum persistence.

Contoh use case:

- `SignIn`
- `SignUp`
- `SignOut`
- `CreateTrade`
- `UpdateTrade`
- `DeleteTrade`
- `GetJournal`
- `GetTradeDetail`
- `ImportTradeFromScreenshot`
- `ExtractTradeDraftFromImage`
- `CalculateDashboardAnalytics`
- `ExportJournal`
- `DeleteAllUserData`

---

## 4.3 Domain Layer

Berisi model dan aturan bisnis yang tidak bergantung pada Flutter UI atau Appwrite.

Entitas utama:

- `Trade`
- `TradeDraft`
- `UserSettings`
- `WatchlistItem`
- `DashboardAnalytics`

Enum/value object yang direkomendasikan:

- `TradeDirection`
- `TradeInputMethod`
- `TradingSession`
- `TradeOutcome`
- `OcrFieldStatus`

Domain validation minimum:

- instrument tidak kosong;
- direction valid;
- entry != exit;
- lotSize > 0;
- required numeric values dapat diparse;
- openTime dan closeTime valid;
- missing SL menghasilkan warning, bukan hard error.

---

## 4.4 Data Layer

Tanggung jawab:

- Appwrite SDK access;
- database mapping;
- local persistence;
- OCR engine adapter;
- provider adapter untuk market data bila fitur P2 dimulai.

Repository contract contoh:

```dart
abstract interface class TradeRepository {
  Future<Trade> create(TradeDraft draft);
  Future<Trade> update(String id, TradeDraft draft);
  Future<void> delete(String id);
  Future<Trade?> getById(String id);
  Future<List<Trade>> list(TradeQuery query);
}
```

UI menggunakan repository melalui Riverpod provider, bukan menginstansiasi SDK secara langsung.

---

## 5. Feature Modules

Struktur feature utama:

```text
features/
├─ onboarding/
├─ auth/
├─ dashboard/
├─ journal/
├─ trade/
│  ├─ manual_entry/
│  ├─ screenshot_import/
│  ├─ trade_detail/
│  └─ trade_edit/
├─ market/
├─ calculator/
└─ settings/
```

Shared code:

```text
core/
├─ appwrite/
├─ routing/
├─ theme/
├─ errors/
├─ validation/
├─ storage/
├─ utils/
└─ widgets/
```

---

## 6. Recommended Flutter Project Structure

```text
lib/
├─ main.dart
├─ app/
│  ├─ app.dart
│  ├─ bootstrap.dart
│  └─ router.dart
├─ core/
│  ├─ config/
│  ├─ appwrite/
│  ├─ theme/
│  ├─ storage/
│  ├─ errors/
│  ├─ validation/
│  └─ widgets/
├─ domain/
│  ├─ trade/
│  ├─ user/
│  └─ watchlist/
├─ data/
│  ├─ models/
│  ├─ datasources/
│  └─ repositories/
└─ features/
   ├─ onboarding/
   ├─ auth/
   ├─ dashboard/
   ├─ journal/
   ├─ trade/
   ├─ market/
   ├─ calculator/
   └─ settings/
```

Untuk MVP, struktur ini dapat disederhanakan bila jumlah file belum besar, tetapi dependency direction tetap dipertahankan.

---

## 7. Riverpod State Architecture

Gunakan Riverpod untuk:

- auth session state;
- current user;
- journal query/filter state;
- trade form state;
- OCR flow state;
- dashboard analytics state;
- settings/preferences state;
- watchlist state.

Kategori provider:

### Infrastructure providers

- Appwrite `Client`;
- `Account`;
- `Databases`;
- local preferences (`shared_preferences`, non-sensitive data only);
- OCR service.

### Repository providers

- `authRepositoryProvider`;
- `tradeRepositoryProvider`;
- `settingsRepositoryProvider`;
- `watchlistRepositoryProvider`.

### Feature controllers

- `authControllerProvider`;
- `journalControllerProvider`;
- `tradeFormControllerProvider`;
- `ocrImportControllerProvider`;
- `dashboardControllerProvider`.

Rule:

> Widget membaca state dan mengirim intent. Controller/use case menjalankan proses.

---

## 8. Routing Architecture

Gunakan `go_router`.

Recommended route tree:

```text
/
├─ /splash
├─ /onboarding
├─ /auth/login
├─ /auth/signup
└─ /app
   ├─ /dashboard
   ├─ /journal
   │  └─ /trade/:tradeId
   ├─ /add-trade
   │  ├─ /manual
   │  └─ /screenshot
   │     ├─ /crop
   │     └─ /review
   ├─ /market
   └─ /settings
      ├─ /calculator
      ├─ /privacy
      └─ /account
```

Redirect logic:

```text
Splash
 ├─ onboarding not completed → Onboarding
 ├─ onboarding completed + no session → Login
 └─ valid session → Dashboard
```

Onboarding state boleh disimpan lokal karena bukan data sensitif.

---

## 9. Authentication Architecture

Backend: Appwrite Authentication.

MVP flow:

- Sign Up email/password;
- Login email/password;
- Logout;
- session persistence;
- change password;
- delete account.

Auth state source of truth adalah Appwrite session/account state.

Session persistence ditangani oleh Appwrite SDK sesuai platform. Tidak ada custom password/session storage dan tidak menggunakan `flutter_secure_storage`. Local storage hanya menyimpan preferensi non-sensitif (onboarding flag, UI preferences) melalui `shared_preferences`.

---

## 10. Trade Lifecycle

### Create manual trade

```text
Form
 → local validation
 → TradeDraft
 → TradeRepository.create()
 → Appwrite document
 → invalidate journal/dashboard providers
 → success state
```

### Edit trade

```text
Trade Detail
 → Edit Form
 → validation
 → TradeRepository.update()
 → refresh detail + journal + analytics
```

### Delete trade

```text
Trade Detail
 → confirmation
 → TradeRepository.delete()
 → invalidate journal/dashboard
 → return Journal
```

---

## 11. Screenshot OCR Architecture

Ini adalah critical privacy flow.

```text
Gallery / Camera
      │
      ▼
Temporary device image reference
      │
      ▼
Crop
      │
      ▼
Temporary cropped image
      │
      ▼
ML Kit Text Recognition (on-device)
      │
      ▼
Raw visible text
      │
      ▼
Parser / Mapper
      │
      ▼
TradeDraft with nullable fields
      │
      ▼
Review UI
      │
   user edits
      │
      ▼
Confirm
      │
      ▼
Save structured data only
      │
      ▼
Release/delete temporary image reference
```

### Non-negotiable rules

- no Appwrite Storage upload;
- no image field in Trade document;
- no OCR cloud request in MVP;
- no inference for missing values;
- no automatic save after OCR;
- screenshot lifecycle berakhir setelah flow selesai/cancelled.

---

## 12. OCR Parsing Boundary

Pisahkan OCR engine dari trade parser.

```text
OcrEngine
  input: image
  output: visible text blocks

Mt5TradeParser
  input: visible text
  output: TradeDraft
```

Keuntungan:

- parser dapat unit-test tanpa device camera;
- OCR provider dapat diganti tanpa mengubah business logic;
- aturan `no guessing` lebih mudah diaudit.

Parser hanya memetakan nilai yang eksplisit terbaca, misalnya:

- Symbol → Instrument;
- Type → Direction;
- Volume → Lot Size;
- Open Time → Open Time;
- Close Time → Close Time;
- Open Price → Entry;
- Close Price → Exit;
- S/L → Stop Loss;
- T/P → Take Profit;
- Profit → P/L;
- Commission → Commission;
- Swap → Swap.

---

## 13. Analytics Architecture

Dashboard analytics berasal dari `Trade` records.

MVP disarankan menghitung analytics di application layer/client karena jumlah user sangat kecil dan data pribadi.

Metrics:

- balance-derived values jika `user_settings.startingBalance` tersedia (lihat `DATABASE.md` §7.1); disembunyikan di UI bila tidak diset;
- Total P/L;
- Win Rate;
- Average RR;
- Total Trades;
- Equity Curve;
- Drawdown;
- breakdown per instrument;
- breakdown per strategy;
- breakdown per session;
- breakdown per emotion;
- heatmap.

Jika volume data tumbuh jauh lebih besar, analytics dapat dipindahkan ke backend aggregation pada versi berikutnya.

---

## 14. Market Feature Architecture

Provider market data belum ditentukan di PRD.

Gunakan abstraction:

```dart
abstract interface class MarketDataRepository {
  Future<List<Quote>> getWatchlistQuotes(List<String> symbols);
  Future<List<EconomicEvent>> getCalendar(...);
  Future<List<MarketNews>> getNews(...);
  Future<MarketSentiment?> getSentiment(...);
}
```

Secret API key tidak boleh ditanam di mobile application.

Jika provider membutuhkan secret key:

```text
Flutter App
   ↓
Backend / Appwrite Function / secure server endpoint
   ↓
External provider
```

Market feature P2 tidak boleh menghambat core journal MVP.

---

## 15. Local Storage Strategy

Local persistence hanya untuk kebutuhan ringan:

- onboarding completed;
- UI preferences;
- cached non-sensitive preferences jika diperlukan;
- temporary state.

Tidak membangun:

- full offline database;
- bidirectional offline sync;
- conflict resolution system;
- local screenshot gallery.

---

## 16. Security Architecture

### 16.1 Data isolation

Setiap Appwrite Trade document menggunakan per-user permission.

User A hanya dapat:

- read own record;
- update own record;
- delete own record.

User tidak boleh mendapat list/read permission global.

### 16.1a User settings document (P0-13.09)

`user_settings` menggunakan documentId random (`ID.unique()`), bukan `userId` yang predictable — documentId predictable memungkinkan doc-squatting oleh authenticated user lain (pre-create doc dengan id korban → poisoning default atau DoS permanen). Lookup berjalan lewat `Query.equal('userId', userId)` pada attribute `user_id` (unique index), dengan verifikasi ownership eksplisit di client: ownership mismatch atau jumlah dokumen selain tepat satu dianggap suspect dan di-fallback ke default (data mencurigakan tidak pernah dirender). Server-side create hook (Appwrite Function) tetap menjadi hardening jangka panjang.

### 16.2 Network

- HTTPS;
- Appwrite endpoint menggunakan TLS;
- external market API secrets tidak ada di APK/source code.

### 16.3 Screenshot privacy

- local temporary only;
- no Appwrite Storage;
- no database field;
- no attachment;
- no post-save display;
- release/delete temporary file setelah selesai atau cancel.

### 16.4 Input validation

Validation diterapkan di client sebelum write dan constraint database digunakan ketika memungkinkan.

### 16.5 Destructive actions

- Delete Trade → confirmation;
- Delete All Data → confirmation;
- Delete Account → confirmation lebih kuat.

---

## 17. Error Handling

Gunakan typed failure/domain error bila memungkinkan.

Kategori:

- `AuthFailure`
- `ValidationFailure`
- `NetworkFailure`
- `DatabaseFailure`
- `OcrFailure`
- `ImageTooBlurryFailure`
- `UnsupportedScreenshotFailure`
- `PermissionFailure`

UI tidak menampilkan raw stack trace atau backend detail.

Logging development tidak boleh memuat password, auth token, atau screenshot image data.

---

## 18. Data Export Architecture

Format:

- JSON;
- CSV.

Flow:

```text
User request export
 → fetch current user's trades
 → serialize structured data
 → generate local export file
 → share/save via platform mechanism
```

Screenshot tidak menjadi bagian export.

---

## 19. Dependency Rules

Recommended dependency direction:

```text
Presentation → Application → Domain
                     ↓
                    Data
```

Rules:

- Domain tidak import Flutter UI/Appwrite.
- Repository interface dapat berada di domain/application.
- Appwrite implementation berada di data layer.
- Screen tidak mengetahui collection ID/database ID.
- Environment/configuration dipusatkan.

---

## 20. Configuration

Pisahkan config berikut dari source code hardcoded:

- Appwrite endpoint;
- Appwrite project ID;
- Appwrite database ID;
- collection IDs;
- external provider public configuration.

Secret backend keys tidak boleh dikompilasi ke mobile app.

Gunakan build-time environment configuration atau mechanism setara yang sesuai workflow Flutter.

---

## 21. Testing Architecture

### Unit tests

Prioritas:

- trade validation;
- RR/statistics calculation;
- drawdown calculation;
- OCR text parser;
- CSV/JSON export serialization.

### Repository tests

- mapping document ↔ domain model;
- filtering/sorting query builder;
- permission assignment.

### Widget tests

- auth form;
- manual trade form;
- OCR review form;
- empty state;
- destructive confirmation.

### Integration tests

Critical paths:

1. Sign Up → Login → Dashboard.
2. Add Manual Trade → Journal → Detail → Edit → Delete.
3. Screenshot → Crop → OCR → Review → Save.
4. User A tidak dapat mengakses User B data.

---

## 22. Performance Considerations

- chart calculation jangan dijalankan berulang di `build()`;
- gunakan provider memoization/cache sesuai kebutuhan;
- pagination journal jika jumlah trade mulai besar;
- image crop/OCR diproses tanpa menyimpan original secara persistent;
- navigation blur jangan berlebihan sampai menurunkan frame rate;
- liquid glass navigasi (flutter_liquid_glass_plus) dipakai `LGQuality.standard`, bukan premium, kecuali performa device sudah terbukti aman;
- hindari rebuild seluruh dashboard saat hanya satu widget berubah.

---

## 23. MVP Architecture Guardrails

Jangan menambahkan tanpa kebutuhan nyata:

- microservices;
- event bus kompleks;
- GraphQL layer;
- broker auto-sync;
- custom backend auth;
- offline-first sync engine;
- screenshot storage;
- bulk OCR;
- social/community architecture.

Tujuan arsitektur MVP adalah modular, testable, dan cukup sederhana untuk ±5 pengguna.
