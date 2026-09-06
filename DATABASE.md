# GumiBook — Database Specification

**Document:** `DATABASE.md`  
**Product:** GumiBook  
**Version:** 1.0  
**Backend:** Appwrite  
**Database:** Appwrite Database

---

## 1. Scope

Dokumen ini mendefinisikan model data GumiBook berdasarkan kebutuhan PRD.

Database hanya menyimpan structured application data.

Screenshot MT5:

- tidak disimpan ke database;
- tidak disimpan ke Appwrite Storage;
- tidak menjadi attachment;
- tidak menjadi bagian dari Trade Detail;
- tidak menjadi bagian export.

---

## 2. Database Principles

1. Setiap record milik user harus terisolasi.
2. Tidak ada public database access.
3. Trade menyimpan data terstruktur, bukan screenshot.
4. Optional field tetap nullable/omittable bila OCR atau user tidak mengisinya.
5. Field yang dapat dihitung boleh disimpan jika membantu UX, tetapi sumber input harus tetap jelas.
6. Query Journal harus didukung index yang relevan.
7. Database design tidak perlu multi-tenant complexity di luar per-user permission karena target user sekitar ±5.

---

## 3. Appwrite Resources

Recommended logical IDs:

```text
database: gumibook

collections:
- trades
- user_settings
- watchlist
```

`Users` tidak dibuat sebagai collection auth utama karena account dikelola oleh Appwrite Authentication.

Profile metadata tambahan dapat disimpan di `user_settings`.

---

## 4. Collection: `trades`

Satu document = satu trade.

### 4.1 Attributes

| Field | Type | Required | Notes |
|---|---|---:|---|
| `userId` | string | yes | Appwrite authenticated user ID |
| `instrument` | string | yes | Example: `XAUUSD`, `EURUSD` |
| `direction` | string | yes | `buy` / `sell` |
| `accountType` | string | no | `real` / `funded`; default `real` |
| `entryPrice` | double | yes | Entry price |
| `exitPrice` | double | yes | Exit price |
| `stopLoss` | double | no | Warning jika kosong, bukan blocking |
| `takeProfit` | double | no | Optional |
| `lotSize` | double | yes | Must be > 0 |
| `profitLoss` | double | yes | Signed P/L value |
| `riskReward` | double | no | Optional/calculated |
| `openTime` | datetime | yes | Trade open time |
| `closeTime` | datetime | yes | Trade close time |
| `strategy` | string | no | Strategy name/tag |
| `session` | string | no | Trading session |
| `confluence` | string[] | no | Multi-value tags recommended |
| `emotion` | string | no | Psychology field |
| `mistakeTags` | string[] | no | Multiple mistake tags |
| `lessonLearned` | string | no | Reflection |
| `notes` | string | no | Free-form notes |
| `inputMethod` | string | yes | `manual` / `ocr` |
| `createdAt` | datetime | yes* | Can use Appwrite system metadata instead |
| `updatedAt` | datetime | yes* | Can use Appwrite system metadata instead |

`createdAt` dan `updatedAt` boleh menggunakan Appwrite `$createdAt` dan `$updatedAt` sebagai source of truth. Jika menggunakan metadata bawaan, jangan duplikasi tanpa alasan.

### 4.2 Validation Rules

Application validation:

```text
instrument != empty
direction in [buy, sell]
entryPrice != exitPrice
lotSize > 0
profitLoss is valid number
openTime is valid datetime
closeTime is valid datetime
```

Recommended additional rule:

```text
closeTime >= openTime
```

Rule ini merupakan validation implementasi yang logis; bila ada use case trading tertentu yang membutuhkan pengecualian, dokumentasikan sebelum mengubahnya.

### 4.3 Field length recommendations

| Field | Suggested maximum |
|---|---:|
| `instrument` | 32 |
| `direction` | 8 |
| `strategy` | 100 |
| `session` | 32 |
| `emotion` | 64 |
| `confluence[]` item | 64 |
| `mistakeTags[]` item | 64 |
| `lessonLearned` | 4,000 |
| `notes` | 8,000 |
| `accountType` | 16 |
| `inputMethod` | 16 |

Sesuaikan dengan limit Appwrite version yang digunakan saat setup.

---

## 5. Trade Permissions

Setiap trade wajib menggunakan document-level user permission.

Konseptual:

```text
read   → user:<ownerId>
update → user:<ownerId>
delete → user:<ownerId>
```

Create dilakukan oleh authenticated user melalui permission collection yang sesuai atau server rule yang aman.

Tidak ada:

- public read;
- public write;
- role `any` read/update/delete.

`userId` tetap disimpan sebagai field query/filter dan defense-in-depth, tetapi permission Appwrite tetap menjadi boundary access utama.

---

## 6. Trade Indexes

Index final harus disesuaikan dengan query Appwrite yang benar-benar digunakan. Untuk kebutuhan PRD, index berikut direkomendasikan.

### 6.1 Core indexes

1. `user_open_time`
   - `userId`
   - `openTime`

2. `user_close_time`
   - `userId`
   - `closeTime`

3. `user_instrument`
   - `userId`
   - `instrument`

4. `user_strategy`
   - `userId`
   - `strategy`

5. `user_direction`
   - `userId`
   - `direction`

6. `user_session`
   - `userId`
   - `session`

7. `user_emotion`
   - `userId`
   - `emotion`

8. `user_profit_loss`
   - `userId`
   - `profitLoss`

9. `user_risk_reward`
   - `userId`
   - `riskReward`

### 6.2 Full-text/search considerations

PRD membutuhkan search berdasarkan:

- Instrument;
- Strategy;
- Notes.

Gunakan Appwrite search/index capability yang tersedia pada deployment untuk text search. Jika Notes full-text search belum dibutuhkan pada awal MVP, fallback dapat berupa filter instrument/strategy terlebih dahulu lalu menambahkan full-text index setelah flow CRUD stabil.

Jangan memuat seluruh database lintas user ke client hanya untuk melakukan search lokal.

---

## 7. Collection: `user_settings`

Satu document per user.

Document ID strategy (P0-13.09, audit K-2 hardening):

```text
documentId = ID.unique()  (random, auto-generated)
userId     = field di dalam dokumen (lookup key, indexed unique)
```

`documentId = userId` (predictable) tidak dipakai lagi: siapa pun authenticated user bisa pre-create dokumen dengan documentId milik korban sebelum korban signup (doc-squatting — poisoning default settings atau DoS permanen karena `ensureDefault` menelan 409 dan `updateProfile` menabrak 403). Dengan documentId random, squatting tidak mungkin; lookup lewat `Query.equal('userId', ...)` dan client memverifikasi ownership (`doc.userId == currentUser.id`) serta menolak kondisi ambigu (0 atau >1 dokumen) dengan fallback ke default.

Index yang dibutuhkan: `user_id` (unique) pada attribute `userId`.

### 7.1 Attributes

| Field | Type | Required | Notes |
|---|---|---:|---|
| `userId` | string | yes | Owner user ID |
| `displayName` | string | no | Profile display name |
| `bio` | string | no | Short profile bio |
| `tradingSince` | datetime/date | no | Profile metadata |
| `theme` | string | yes | MVP default `dark` |
| `dailyJournalReminder` | boolean | yes | P2 notification setting |
| `weeklyPerformanceSummary` | boolean | yes | P2 |
| `economicCalendarAlerts` | boolean | yes | P2 |
| `biometricLockEnabled` | boolean | yes | P2 |
| `startingBalance` | double | no | Optional. Base value for Balance card and Equity Curve origin |
| `balanceCurrency` | string | no | Optional. Default set by user during setup, e.g. `USD` |
| `balanceSetAt` | datetime | no | Optional. Last time `startingBalance` was set/edited |
| `preferences` | string/json | no | Only if needed; prefer typed fields for critical settings |

Email tetap berasal dari Appwrite account, bukan diduplikasi sebagai primary auth source.

### 7.2 Permissions

```text
read   → user:<ownerId>
update → user:<ownerId>
delete → user:<ownerId>
```

Create hanya oleh authenticated owner.

---

## 8. Collection: `watchlist`

Recommended model: satu document per `(userId, instrument)`.

### 8.1 Attributes

| Field | Type | Required | Notes |
|---|---|---:|---|
| `userId` | string | yes | Owner |
| `instrument` | string | yes | Selected instrument |
| `sortOrder` | integer | no | Custom order |
| `createdAt` | datetime | yes* | Or Appwrite `$createdAt` |

### 8.2 Constraints

Application harus mencegah duplicate instrument untuk user yang sama.

Recommended composite uniqueness strategy jika Appwrite deployment mendukung unique index yang sesuai:

```text
(userId, instrument)
```

Jika tidak, lakukan pre-check dan handle conflict pada repository.

### 8.3 Permissions

Same owner-only permission model.

---

## 9. Data Not Stored

Jangan membuat field/collection berikut untuk MVP:

- screenshot path;
- screenshot URL;
- screenshot file ID;
- image attachment;
- OCR image history;
- raw broker screenshot archive;
- public profile;
- social follow/like/comment;
- broker account token;
- MT5 credentials.

Raw OCR text tidak wajib disimpan. Default: jangan simpan kecuali ada kebutuhan debugging yang eksplisit dan aman.

---

## 10. Trade JSON Model Example

Contoh logical document:

```json
{
  "userId": "USER_ID",
  "instrument": "XAUUSD",
  "direction": "buy",
  "accountType": "real",
  "entryPrice": 2401.25,
  "exitPrice": 2412.80,
  "stopLoss": 2395.00,
  "takeProfit": 2415.00,
  "lotSize": 0.10,
  "profitLoss": 115.50,
  "riskReward": 1.84,
  "openTime": "2026-08-29T09:15:00+07:00",
  "closeTime": "2026-08-29T10:40:00+07:00",
  "strategy": "London Breakout",
  "session": "London",
  "confluence": ["HTF bias", "liquidity sweep"],
  "emotion": "calm",
  "mistakeTags": [],
  "lessonLearned": "Waited for confirmation before entry.",
  "notes": "Clean setup.",
  "inputMethod": "manual"
}
```

Ini hanya contoh bentuk data, bukan seed data wajib.

---

## 11. OCR Draft vs Persisted Trade

OCR menghasilkan `TradeDraft`, bukan langsung Trade document.

Example draft:

```json
{
  "instrument": "XAUUSD",
  "direction": "buy",
  "accountType": null,
  "entryPrice": 2401.25,
  "exitPrice": 2412.80,
  "stopLoss": null,
  "takeProfit": null,
  "lotSize": 0.10,
  "profitLoss": 115.50,
  "openTime": "...",
  "closeTime": "...",
  "inputMethod": "ocr"
}
```

Field yang tidak terlihat dibiarkan `null`.

Persistence baru dilakukan setelah:

```text
OCR → Review → User Edit/Confirm → Validate → Create Document
```

---

## 12. Journal Query Patterns

### Newest

```text
where userId = currentUser
order closeTime DESC
```

### Oldest

```text
where userId = currentUser
order closeTime ASC
```

### Filter instrument

```text
where userId = currentUser
and instrument = selectedInstrument
```

### Filter direction

```text
where userId = currentUser
and direction = selectedDirection
```

### Filter date range

```text
where userId = currentUser
and closeTime >= start
and closeTime <= end
```

### Sort by P/L

```text
where userId = currentUser
order profitLoss DESC/ASC
```

### Sort by RR

```text
where userId = currentUser
order riskReward DESC/ASC
```

Pagination harus ditambahkan saat jumlah trade cukup besar.

---

## 13. Analytics Data Requirements

Analytics dihitung dari trade fields berikut:

### Total P/L

`sum(profitLoss)`

### Win Rate

```text
wins = count(profitLoss > 0)
winRate = wins / totalTrades * 100
```

### Average RR

Mean dari `riskReward` yang tersedia.

### Equity Curve

Cumulative P/L berdasarkan chronological close time.

Jika `user_settings.startingBalance` tersedia, curve dimulai dari nilai tersebut (`startingBalance + cumulativeP/L`). Jika tidak diset, curve dimulai dari 0 (`cumulativeP/L` saja). `startingBalance` bersifat mutable — perubahan nilai langsung memengaruhi seluruh curve karena MVP tidak menyimpan balance adjustment log.

### Drawdown

Dihitung dari peak-to-trough cumulative equity.

### Instrument Breakdown

Group by `instrument`.

### Strategy Breakdown

Group by `strategy`.

### Session Breakdown

Group by `session`.

### Emotion Breakdown

Group by `emotion`.

### Heatmap

Group trade result/count berdasarkan tanggal/hari/periode yang dipilih.

---

## 14. Delete Operations

### Delete Trade

Menghapus satu trade document milik user.

### Delete All Data

Minimal menghapus:

- all `trades` for current user;
- `watchlist` for current user;
- `user_settings` sesuai keputusan product.

Jika profile/settings ingin dipertahankan pada `Delete All Journal Data`, bedakan action tersebut secara eksplisit dari `Delete All Data`.

### Delete Account

Flow:

1. confirmation;
2. delete user-owned documents;
3. delete account sesuai mekanisme Appwrite;
4. clear local state/session.

Pastikan tidak ada orphaned records.

---

## 15. Export Schema

### JSON

Array of structured trade objects.

### CSV recommended columns

```text
instrument,direction,accountType,entryPrice,exitPrice,stopLoss,takeProfit,
lotSize,profitLoss,riskReward,openTime,closeTime,
strategy,session,confluence,emotion,mistakeTags,lessonLearned,notes,
inputMethod,createdAt,updatedAt
```

Array values seperti `confluence` dan `mistakeTags` dapat digabung menggunakan separator yang terdokumentasi.

---

## 16. Migration Strategy

MVP tidak membutuhkan migration framework kompleks, tetapi setiap perubahan schema harus dicatat.

Recommended:

```text
/docs/database-migrations/
  001_initial_schema.md
  002_add_account_type.md
  ...
```

Untuk perubahan breaking:

- tambahkan attribute baru dulu;
- deploy app yang memahami old/new state;
- migrate data bila dibutuhkan;
- baru hapus attribute lama setelah aman.

---

## 17. Database Acceptance Checklist

- `trades` collection tersedia;
- `user_settings` collection tersedia;
- `watchlist` collection tersedia;
- semua field required sesuai spec;
- trade owner permission diterapkan saat create;
- User A tidak dapat read/update/delete trade User B;
- public read tidak aktif;
- Journal dapat query newest/oldest/filter/sort;
- OCR tidak membuat image record;
- delete trade menghapus document;
- delete all data hanya mempengaruhi owner;
- export hanya menghasilkan structured data;
- index yang dibutuhkan query aktif sudah dibuat;
- schema tidak menyimpan secret API keys atau MT5 credentials.
