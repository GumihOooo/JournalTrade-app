# GumiBook — Implementation Guide

**Document:** `IMPLEMENTATION.md`  
**Product:** GumiBook  
**Version:** 1.0  
**Purpose:** Panduan implementasi MVP dari setup project sampai testing

---

## 1. Implementation Strategy

Implementasi dilakukan bertahap sesuai prioritas PRD:

1. **P0 — Core Journal**
2. **P1 — MT5 OCR Hero Feature**
3. **P1 — Analytics**
4. **P2 — Supporting Features**

Jangan memulai market/news, notification, biometric, atau full calculator suite sebelum core CRUD dan permission stabil.

---

## 2. Development Environment

Development flow yang ditetapkan:

```text
HP
 ↓ SSH
VPS
 ↓
Flutter + editor/agent
 ↓
Build APK
 ↓
Download APK
 ↓
Install di HP
 ↓
Physical testing
```

HP digunakan terutama sebagai physical test device.

### Minimum environment

- Flutter stable compatible with target Android/iOS;
- Dart bundled with Flutter;
- Android SDK / build tools;
- Java/JDK version compatible with Flutter toolchain;
- Appwrite project accessible over HTTPS;
- Git;
- optional iOS build environment on macOS when iOS build starts.

Catatan: VPS non-macOS dapat digunakan untuk Android development/build. Native iOS build tetap memerlukan toolchain Apple/macOS pada tahap distribusi iOS.

---

## 3. Create Flutter Project

Example:

```bash
flutter create gumibook
cd gumibook
flutter doctor
```

Set application ID/package name sebelum integrasi platform production.

Recommended flavors/environment separation jika dibutuhkan:

- development;
- production.

MVP tidak wajib membuat banyak flavor bila deployment hanya satu environment.

---

## 4. Core Dependencies

Dependencies yang berasal dari keputusan PRD:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ...
  go_router: ...
  appwrite: ...
  google_mlkit_text_recognition: ...
```

Dependencies tambahan yang lazim dibutuhkan untuk flow PRD:

```yaml
  image_picker: ...
  image_cropper: ...
  shared_preferences: ...
```

Charting library belum dikunci dalam PRD. Pilih satu library Flutter yang:

- mendukung line chart;
- area/bar chart bila diperlukan;
- mobile performance baik;
- styling dapat mengikuti monochrome design;
- maintenance memadai.

Jangan menambah dependency hanya karena tersedia; setiap package baru meningkatkan maintenance surface.

---

## 5. App Bootstrap

Urutan bootstrap:

```text
WidgetsFlutterBinding.ensureInitialized()
 → load environment config
 → initialize Appwrite Client
  → initialize local preferences (non-sensitive)
 → runApp(ProviderScope(...))
```

Appwrite configuration yang dibutuhkan:

- endpoint;
- project ID;
- database ID;
- collection IDs.

Semua konfigurasi dipusatkan dalam config class.

---

## 6. Appwrite Client Setup

Logical example:

```dart
final client = Client()
  ..setEndpoint(appwriteEndpoint)
  ..setProject(appwriteProjectId);
```

Buat provider untuk:

- `Client`;
- `Account`;
- `Databases`.

Jangan membuat ulang `Client` di setiap repository/screen.

---

## 7. Environment Configuration

Recommended:

```text
lib/core/config/app_config.dart
```

Data yang boleh ada di mobile config:

- Appwrite public endpoint;
- project identifier;
- database/collection identifiers;
- non-secret feature flags.

Data yang tidak boleh ada:

- Appwrite server API key;
- private market provider secret;
- service account credential;
- MT5 user credential.

Jika P2 membutuhkan secret API, akses provider melalui backend/server function.

---

## 8. Theme Implementation

Buat central theme:

```text
core/theme/
├─ app_colors.dart
├─ app_typography.dart
├─ app_spacing.dart
├─ app_radius.dart
├─ app_theme.dart
└─ app_motion.dart
```

Rule:

- tidak hardcode style berulang di screen;
- semantic colors didefinisikan satu kali;
- dark theme sebagai default;
- chart colors mengambil theme tokens.

---

## 9. Routing Implementation

Implement `GoRouter` dengan auth/onboarding redirect.

Pseudo flow:

```dart
redirect: (context, state) {
  if (booting) return '/splash';
  if (!onboardingDone) return '/onboarding';
  if (!authenticated) return '/auth/login';
  return null;
}
```

Pastikan tidak terjadi redirect loop.

Main shell berisi bottom navigation:

- Dashboard;
- Journal;
- Add Trade;
- Market;
- Settings.

---

## 10. Authentication Implementation

### Sign Up

1. validate email/password;
2. create Appwrite account;
3. create session atau arahkan login sesuai flow final;
4. create default `user_settings` document bila diperlukan;
5. navigate dashboard.

### Login

1. validate input;
2. create email/password session;
3. fetch account;
4. update auth provider;
5. navigate dashboard.

### Logout

1. delete current session;
2. clear user-specific cached state;
3. navigate login.

### Change password

Gunakan Appwrite account API yang sesuai deployment/version.

### Session persistence

Saat app start:

1. query current Appwrite account/session;
2. jika valid → authenticated;
3. jika invalid → login.

Jangan menyimpan password sendiri.

---

## 11. Data Models

Domain model `Trade` harus memiliki field sesuai database spec.

Recommended separation:

```text
Trade          = persisted valid record
TradeDraft     = mutable/partial form or OCR result
TradeFormState = UI state + validation messages
```

Keuntungan:

- OCR boleh menghasilkan nullable fields;
- persisted Trade tetap mengikuti requirement;
- UI validation tidak mencemari domain model.

---

## 12. Repository Implementation

Create repository interface lalu Appwrite implementation.

Example:

```text
TradeRepository
└─ AppwriteTradeRepository
```

Tanggung jawab repository:

- serialize/deserialize;
- set document permission;
- create/update/delete/get/list;
- query filter/sort;
- map Appwrite exception ke application failure.

Jangan membuat widget menyusun query Appwrite langsung.

---

## 13. Manual Add Trade

Implementation order:

1. build form UI;
2. create `TradeDraft` state;
3. implement validation;
4. implement Save loading state;
5. call repository;
6. invalidate Journal provider;
7. invalidate Dashboard analytics provider;
8. show success;
9. navigate detail/journal sesuai UX final.

Validation minimum:

```text
instrument required
direction required
entry required
exit required
entry != exit
lotSize > 0
profitLoss required
openTime required
closeTime required
```

Missing SL:

- show warning;
- allow save.

---

## 14. Journal Implementation

Start with list newest-first.

Then add:

- search instrument;
- search strategy;
- notes search;
- filters;
- sorting;
- pagination if necessary.

Filter state harus terpisah dari loaded data state.

Recommended model:

```dart
class TradeQuery {
  final String? search;
  final DateTimeRange? dateRange;
  final String? instrument;
  final TradeDirection? direction;
  final String? strategy;
  final String? session;
  final String? emotion;
  final String? mistake;
  final TradeOutcome? outcome;
  final TradeSort sort;
}
```

---

## 15. Trade Detail / Edit / Delete

### Detail

Fetch berdasarkan `tradeId` dan current user access.

### Edit

- preload draft;
- validate;
- update document;
- refresh detail, journal, analytics.

### Delete

- confirmation dialog;
- repository delete;
- invalidate providers;
- pop back to journal.

UI tidak menampilkan screenshot field karena memang tidak ada.

---

## 16. OCR Feature Implementation

P1 hero feature harus dimulai setelah manual trade CRUD stabil.

### Step 1 — Image acquisition

Gunakan:

- gallery;
- camera.

Image tetap lokal.

### Step 2 — Crop

User harus memilih area satu trade.

Crop result diperlakukan sebagai temporary file.

### Step 3 — OCR

Gunakan Google ML Kit Text Recognition on-device.

Output: visible text / text blocks.

### Step 4 — MT5 parser

Parser hanya mengambil nilai yang terlihat.

Tidak boleh:

- menebak SL/TP;
- menentukan direction berdasarkan profit;
- membuat harga;
- menghitung field untuk menutup data yang tidak terbaca pada tahap extraction.

### Step 5 — Review

Convert parser output ke `TradeDraft`.

Semua field editable.

Field tidak terbaca:

- `null`;
- UI tandai `Needs review`.

### Step 6 — Save

Baru setelah user confirm:

- run validation;
- persist structured trade;
- `inputMethod = ocr`.

### Step 7 — Dispose image

Dalam success/cancel/error path:

- close image references;
- delete temporary cropped file jika package menghasilkan file sementara yang menjadi tanggung jawab aplikasi;
- jangan mengupload file.

Gunakan `try/finally` atau lifecycle cleanup yang setara agar file tidak tertinggal akibat early return.

---

## 17. OCR Parser Implementation

Pisahkan parser ke file/class yang dapat dites:

```text
features/trade/screenshot_import/domain/mt5_trade_parser.dart
```

Input:

```text
recognized text
```

Output:

```text
TradeDraft + extraction metadata
```

Recommended metadata:

```dart
class ExtractedField<T> {
  final T? value;
  final bool detected;
  final String? rawText;
}
```

`rawText` hanya untuk in-memory review/debug; default jangan persist.

Unit test menggunakan berbagai sample text MT5 yang sudah dianonimkan.

---

## 18. OCR Error Handling

Map condition ke user-facing state:

| Condition | UI |
|---|---|
| No text | `Could not detect trade data.` |
| Partial text | Open review with missing fields marked |
| Blurry image | `Image is too blurry. Please select a clearer screenshot.` |
| Looks like chart | `This doesn't appear to be an MT5 Trade History screenshot.` |
| OCR engine error | Retry / Manual Entry |

Deteksi chart jangan dibuat agresif jika accuracy belum cukup. Lebih baik gagal sebagai low-confidence extraction daripada memblokir valid screenshot.

---

## 19. Dashboard Analytics Implementation

Implement pure functions terlebih dahulu.

Recommended:

```text
analytics/
├─ total_pl.dart
├─ win_rate.dart
├─ average_rr.dart
├─ equity_curve.dart
├─ drawdown.dart
├─ breakdown.dart
└─ heatmap.dart
```

Atau satu service jika code masih kecil.

### Required calculations

- total trades;
- total P/L;
- win rate;
- average RR;
- equity curve;
- drawdown;
- breakdown instrument;
- strategy;
- session;
- emotion;
- heatmap.

Equity curve function menerima `startingBalance` nullable sebagai parameter: gunakan sebagai origin bila tersedia, fallback ke 0 bila null. Jangan hardcode asumsi balance selalu ada.

Analytics sebaiknya pure dan unit-testable.

---

## 20. Settings Implementation

P0:

- profile basic;
- starting balance (optional field, nullable; drives Dashboard Balance card and Equity Curve origin);
- dark appearance;
- account;
- logout;
- change password.

P2:

- notifications;
- data export;
- delete all data;
- biometric lock;
- calculator full suite.

Screenshot privacy info dapat muncul lebih awal karena terkait hero feature.

---

## 21. Calculator Implementation

Calculator standalone.

Rule:

- tidak menulis ke database;
- input ephemeral;
- hasil mudah disalin;
- shared numeric component;
- formula dipisahkan dari UI dan ditest.

Implement satu calculator per module/function agar formula tidak bercampur dengan widget.

---

## 22. Data Export

### JSON

Serialize current user's Trade model.

### CSV

- stable header;
- escape comma/newline/quote dengan benar;
- datetime gunakan format ISO 8601;
- arrays gunakan separator terdokumentasi.

Jangan memasukkan:

- password;
- auth session;
- screenshot;
- secret config.

---

## 23. Delete All Data

Flow:

```text
Settings
 → confirmation
 → optional second confirmation
 → list current user's documents
 → delete trades
 → delete watchlist
 → handle user_settings per product decision
 → refresh state
```

Jangan menggunakan broad server operation yang berisiko menghapus user lain.

---

## 24. Market Feature P2

Implement setelah core stabil.

Sequence:

1. pilih data provider;
2. evaluasi auth/rate limit/license;
3. tentukan apakah secret key diperlukan;
4. jika secret → backend function/proxy;
5. implement repository adapter;
6. watchlist;
7. calendar;
8. news;
9. sentiment;
10. AI summary terakhir.

AI summary hanya berdasarkan data/news yang tersedia dan harus diberi disclaimer bukan financial advice.

---

## 25. Notifications P2

Requirements:

- Daily journal reminder;
- Weekly performance summary;
- Economic calendar alerts.

Tentukan mekanisme berdasarkan kebutuhan:

- local notification untuk reminder yang tidak membutuhkan server;
- server/push hanya bila membutuhkan event eksternal.

Jangan membangun push infrastructure sebelum requirement provider calendar jelas.

---

## 26. Biometric Lock P2

Biometric lock adalah app-level privacy layer, bukan pengganti Appwrite auth.

Flow:

```text
App resumes
 → if biometric enabled
 → biometric prompt
 → unlock local UI
```

Jangan menyimpan password user untuk biometric unlock.

---

## 27. Error & Logging Implementation

Buat error mapper:

```text
AppwriteException → AuthFailure / DatabaseFailure / NetworkFailure
ML Kit exception  → OcrFailure
Validation        → ValidationFailure
```

Development logging boleh mencatat:

- operation;
- duration;
- generic error code.

Jangan log:

- password;
- session token;
- API secret;
- screenshot bytes;
- full private notes tanpa alasan.

---

## 28. Testing Plan

### Phase P0 tests

- auth repository;
- auth redirect;
- manual trade validation;
- create/list/detail/update/delete;
- owner permissions;
- empty journal/dashboard.

### Phase P1 OCR tests

- parser exact fields;
- missing fields remain null;
- screenshot cleanup;
- review required before save;
- no image upload request.

### Phase P1 analytics tests

- zero trades;
- all wins;
- all losses;
- mixed trades;
- nullable RR;
- drawdown sequence;
- group breakdown.

### P2 tests

- export correctness;
- calculator formulas;
- notification preference;
- biometric enable/disable;
- market provider failure state.

---

## 29. Definition of Done per Feature

Feature selesai jika:

- UI sesuai `DESIGN.md`;
- model/database sesuai `DATABASE.md`;
- permission benar;
- loading/error/empty state ada;
- validation ada;
- happy path berjalan di physical Android device;
- unit/widget test critical behavior ada;
- tidak menambahkan data persistence yang melanggar privacy;
- tidak menaruh secret key di mobile code;
- documentation/task checklist diperbarui.

---

## 30. Release Order

Recommended release milestone:

### Milestone A — Core Journal

- onboarding;
- auth;
- navigation;
- manual trade CRUD;
- journal;
- trade detail;
- settings basic.

### Milestone B — OCR

- image picker;
- crop;
- ML Kit;
- parser;
- review;
- cleanup.

### Milestone C — Analytics

- summary;
- charts;
- heatmap;
- breakdown.

### Milestone D — Supporting Features

- market;
- calculator suite;
- export;
- notifications;
- biometric.

---

## 31. Implementation Guardrails

Do not implement in V1:

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
