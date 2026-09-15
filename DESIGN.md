# GumiBook — Design Specification

**Document:** `DESIGN.md`  
**Product:** GumiBook  
**Version:** 1.0  
**Source:** GumiBook PRD v1.1  
**Platforms:** Android & iOS  
**Design direction:** Dark-first, premium, minimal, professional, monochrome/silver

---

## 1. Purpose

Dokumen ini menjadi sumber acuan UI/UX GumiBook agar seluruh screen, component, state, animasi, dan interaction pattern konsisten selama implementasi Flutter.

GumiBook bukan aplikasi trading yang menampilkan banyak warna dan elemen dekoratif. Fokus desain adalah:

- data trading cepat dibaca;
- input trade cepat dan tidak melelahkan;
- hierarchy visual jelas;
- tampilan premium tanpa mengurangi usability;
- semantic color hanya dipakai ketika memang membawa arti;
- screenshot MT5 diperlakukan sebagai data sementara, bukan konten galeri.

Prinsip produk:

> **Track → Analyze → Learn → Improve**

---

## 2. Design Principles

### 2.1 Clarity before decoration

Setiap screen harus memprioritaskan informasi utama dan tindakan utama. Glass effect, blur, shadow, glow, dan animasi hanya digunakan untuk memperkuat hierarchy, bukan sebagai dekorasi berlebihan.

### 2.2 Dark-first

GumiBook menggunakan dark theme sebagai tampilan utama. Background harus cukup gelap agar chart, angka performa, dan surface terlihat jelas tanpa menghasilkan kontras yang melelahkan.

### 2.3 Monochrome as default

Warna utama UI menggunakan spektrum hitam, graphite, abu-abu, putih, dan silver. Warna lain hanya untuk semantic meaning.

### 2.4 Trading color is semantic

- Profit → green
- Loss → red
- Warning → amber
- Neutral / primary UI → silver

Jangan menggunakan green/red untuk dekorasi yang tidak berkaitan dengan performa atau status.

### 2.5 Progressive disclosure

Screen tidak harus menampilkan semua informasi sekaligus. Data detail dan form advanced dapat dikelompokkan menjadi section agar proses input tetap ringan.

### 2.6 Privacy is visible in UX

Pada flow OCR, user harus memahami bahwa screenshot hanya diproses sementara dan tidak disimpan. Pesan privacy harus singkat, jelas, dan ditempatkan sebelum atau saat proses import.

### 2.7 Verification before persistence

Hasil OCR tidak pernah langsung menjadi record trade. UX harus selalu memiliki tahap:

`Extract → Review → Edit → Confirm → Save`

---

## 3. Visual Language

### 3.1 Color roles

Gunakan color token berdasarkan role, bukan berdasarkan nama warna mentah.

| Token | Fungsi |
|---|---|
| `bg.primary` | Background utama aplikasi |
| `bg.secondary` | Background section / nested surface |
| `surface.base` | Card / panel utama |
| `surface.glass` | Frosted translucent surface |
| `surface.elevated` | Modal, sheet, floating component |
| `border.subtle` | Border tipis |
| `border.focus` | Focus / selected state |
| `text.primary` | Informasi paling penting |
| `text.secondary` | Supporting information |
| `text.muted` | Placeholder / metadata |
| `accent.silver` | Primary accent |
| `semantic.profit` | Profit / positive trading result |
| `semantic.loss` | Loss / negative trading result |
| `semantic.warning` | Warning dan caution state |
| `semantic.info` | Informasi netral bila dibutuhkan |

Nilai warna final sebaiknya ditetapkan sebagai Flutter `ColorScheme` agar seluruh component memakai satu source of truth.

### 3.2 Surface style

Glass surface menggunakan karakter berikut:

- translucent background;
- background blur;
- subtle border;
- soft reflection;
- low-contrast shadow;
- depth yang ringan;
- radius konsisten.

Jangan menggunakan glass pada seluruh komponen. Gunakan terutama pada:

- bottom navigation;
- primary floating controls;
- summary cards tertentu;
- modal/sheet yang membutuhkan separation visual.

Implementasi glass dibagi dua:

- **`GlassCard` (komponen umum)** — backdrop blur sederhana untuk card, panel, dan surface konten. Implementasi: `lib/core/design/widgets/glass_card.dart`.
- **Liquid glass navigasi** — efek refractive glass khusus navigasi (`LGAppBar`, `LGBottomBar`) menggunakan package `flutter_liquid_glass_plus` (quality: `LGQuality.standard`; premium hanya bila terbukti perlu dan performa aman). Warna dan radius tetap mengikuti token `gumi_colors.dart` dan `gumi_spacing_radius.dart`. Liquid glass tidak dipakai untuk card/komponen konten umum.

### 3.3 Spacing system

Gunakan grid 4dp dengan spacing utama:

- 4dp — micro spacing;
- 8dp — compact spacing;
- 12dp — internal component spacing;
- 16dp — standard content spacing;
- 20–24dp — section spacing;
- 32dp — major separation.

### 3.4 Radius

Gunakan radius konsisten:

- small control: 8–10dp;
- input/button: 12–14dp;
- card: 16dp;
- glass panel / bottom nav: 20–28dp atau pill penuh sesuai konteks.

### 3.5 Typography

Gunakan hierarchy sederhana:

| Style | Kegunaan |
|---|---|
| Display | Angka balance / total P&L utama |
| H1 | Judul screen |
| H2 | Judul section |
| Title | Card / list title |
| Body | Konten normal |
| Label | Tombol, field label, filter |
| Caption | Metadata, time, helper text |

Angka finansial harus menggunakan font feature/tabular figure jika font yang dipilih mendukung agar digit stabil saat berubah.

---

## 4. Navigation Design

Bottom navigation memiliki 5 destination:

`Dashboard | Journal | + Add Trade | Market | Settings`

### 4.1 Liquid Glass-inspired behavior

Bottom navigation adalah floating pill dengan:

- frosted/translucent glass;
- blur;
- subtle reflection;
- silver border;
- soft shadow;
- spring animation.

Implementasi memakai `LGBottomBar` dari package `flutter_liquid_glass_plus` (`LGQuality.standard`), dengan warna dan radius dari token `gumi_colors.dart` / `gumi_spacing_radius.dart`.

### 4.2 Scroll behavior

Saat user scroll ke bawah:

- tinggi visual bertransisi dari sekitar 48dp ke sekitar 36dp;
- label dapat dipadatkan jika diperlukan;
- navigasi tetap tappable dan tidak kehilangan accessibility target.

Saat user scroll ke atas:

- kembali ke expanded state sekitar 48dp.

Animasi harus smooth dan tidak menghambat scroll.

### 4.3 Add Trade action

Add Trade adalah primary action:

- lebih besar daripada item navigation lain;
- sedikit floating;
- subtle glow;
- press animation;
- selalu mudah ditemukan.

---

## 5. Screen Specifications

## 5.1 Splash

Tujuan:

- menampilkan identitas GumiBook;
- memeriksa onboarding status;
- memeriksa auth/session;
- mengarahkan user ke tujuan berikutnya.

Visual:

- dark background (`bg.primary` #0A0B0E);
- wordmark "GumiBook": "Gumi" putih (`text.primary`), "book" abu-abu (`text.secondary`);
- subtle silver animation (fade-in, ringan);
- transition singkat.

Native splash (cold start) dibuat via `flutter_native_splash` dengan warna dan wordmark yang sama; in-app splash widget hanya bridge singkat ke route pertama.

Jangan menahan splash menggunakan artificial delay jika initialization sudah selesai.

---

## 5.2 Onboarding

### Page 1

Headline:

> **Track. Analyze. Improve.**

Isi menjelaskan bahwa GumiBook adalah personal trading journal untuk pencatatan dan analisis.

### Page 2

Menjelaskan empat nilai utama:

- MT5 screenshot extraction;
- psychology journal;
- performance analytics;
- privacy-first image handling.

Primary CTA:

> **Get Started**

---

## 5.3 Authentication

Screen minimal:

- Login;
- Sign Up.

Field:

- email;
- password.

UX requirements:

- password visibility toggle;
- clear validation;
- loading state;
- error state dari Appwrite ditampilkan dalam bahasa yang mudah dipahami;
- tombol tidak dapat dikirim berulang saat request aktif.

---

## 5.4 Dashboard

Dashboard berfungsi sebagai performance overview.

### Overview cards

Tampilkan:

- Balance (hanya bila Starting Balance sudah diisi di Settings → Profile; disembunyikan bila belum);
- Total P/L;
- Win Rate;
- Average RR;
- Total Trades.

Hierarchy yang disarankan:

1. Balance / Total P&L sebagai informasi dominan;
2. Win Rate, RR, Total Trades sebagai supporting metrics;
3. chart analytics di bawah summary.

### Charts

- Equity Curve;
- Drawdown;
- Performance Breakdown;
- Instrument Performance;
- Strategy Performance;
- Session Performance;
- Emotion Performance;
- Trading Heatmap.

Chart harus:

- tidak penuh grid line;
- label ringkas;
- dapat dibaca pada mobile;
- menggunakan semantic color hanya bila relevan;
- memiliki empty/loading/error state.

### Empty state

Copy:

> Start your trading journal by adding your first trade.

CTA:

> **Add Trade**

---

## 5.5 Journal

Tujuan: melihat dan menemukan seluruh trade yang tersimpan.

### Header actions

- Search;
- Filter;
- Sort.

### Search fields

- Instrument;
- Strategy;
- Notes.

### Filter

- Date;
- Instrument;
- Direction;
- Strategy;
- Session;
- Emotion;
- Mistake;
- Win/Loss.

### Sort

- Newest;
- Oldest;
- P/L;
- RR.

### Trade list item

Minimal menampilkan:

- instrument;
- direction;
- close/open date;
- P/L;
- RR bila tersedia;
- strategy atau session sebagai metadata opsional.

List item harus mudah discan secara vertikal dan tidak terlalu padat.

---

## 5.6 Add Trade — Method Selector

User memilih salah satu:

1. Manual Entry
2. Import MT5 Screenshot

Gunakan dua card/action yang jelas. Import screenshot dapat diberikan penjelasan singkat bahwa gambar tidak disimpan setelah extraction.

---

## 5.7 Manual Trade Form

Kelompokkan field menjadi section.

### A. Execution

- Instrument *
- Direction *
- Entry Price *
- Exit Price *
- Stop Loss
- Take Profit
- Lot Size *
- P/L *
- Risk/Reward
- Open Date/Time *
- Close Date/Time *

### B. Trading Context

- Strategy
- Session
- Confluence

### C. Psychology

- Emotion
- Mistake

### D. Reflection

- Lesson Learned
- Notes

UX rules:

- required field ditandai jelas;
- numeric keyboard untuk angka;
- date/time picker native-friendly;
- validation inline;
- missing SL = warning, bukan otomatis blocking;
- sticky/fixed Save action boleh digunakan jika form panjang;
- jangan reset form saat validation error.

---

## 5.8 Screenshot Import

Flow:

`Gallery/Camera → Crop → OCR → Review → Confirm → Save → Discard Temporary Image`

### Import entry state

Tampilkan:

- Gallery;
- Camera;
- privacy note;
- format yang didukung: MT5 History / Trade History;
- warning bahwa chart screenshot bukan input yang didukung.

---

## 5.9 Crop Screen

Tujuan:

> Memilih area yang berisi satu trade.

UX:

- crop handle jelas;
- preview tidak terlalu kecil;
- instruction singkat;
- CTA: `Continue`;
- secondary action: `Retake` / `Choose Another`.

MVP hanya 1 trade per extraction.

---

## 5.10 OCR Processing

Processing state harus singkat dan informatif.

Tampilkan:

- progress indicator non-deterministic jika progress riil tidak tersedia;
- teks seperti `Reading trade data…`;
- jangan menyatakan AI sedang menebak atau menganalisis sesuatu yang tidak terlihat.

Tidak perlu menampilkan raw OCR text kepada user kecuali nanti diperlukan untuk debugging internal.

---

## 5.11 OCR Review Form

Hasil extraction selalu masuk ke review form.

Field yang terdeteksi:

- Instrument;
- Direction;
- Lot Size;
- Open Time;
- Close Time;
- Entry;
- Exit;
- Stop Loss;
- Take Profit;
- P/L;
- Commission;
- Swap.

UX requirements:

- field kosong tetap terlihat;
- field yang tidak terbaca dapat diberi status `Needs review`;
- user bebas mengedit seluruh hasil;
- data baru disimpan setelah user menekan Confirm/Save;
- setelah keluar dari flow atau selesai save, temporary image harus dilepas.

---

## 5.12 OCR Error States

### No text

> Could not detect trade data.

### Partial data

Tampilkan field yang berhasil dibaca dan tandai field yang masih perlu diisi.

### Blurry image

> Image is too blurry. Please select a clearer screenshot.

### Chart screenshot

> This doesn't appear to be an MT5 Trade History screenshot.

### OCR failure

Primary recovery:

- Retry;
- Choose another screenshot.

Secondary recovery:

- Manual Entry.

---

## 5.13 Trade Detail

### Execution

- Instrument;
- Direction;
- Entry;
- Exit;
- SL;
- TP;
- Lot;
- P/L;
- RR;
- Time.

### Psychology

- Strategy;
- Session;
- Confluence;
- Emotion;
- Mistake.

### Reflection

- Lesson Learned;
- Notes.

Actions:

- Edit;
- Delete.

Screenshot tidak pernah ditampilkan karena tidak disimpan.

---

## 5.14 Market

Section (P2-05 FINAL, provider terkunci):

- Watchlist prices — Sugra API (sugra.ai) via `gumibook-ai-gateway`
  task `marketPrice`. Free tier 50 req/hari (reset UTC midnight);
  ~13 req per refresh;
- Economic Calendar (hari-ini, timezone user) — LSE via
  `gumibook-ai-gateway` task `marketCalendar`;
- News (business feed) — Sugra `/api/v1/news/latest` via task
  `marketNews`;
- Market mood — GDELT tone chart via Sugra, datang di dalam response
  `marketNews` (satu chip `MOOD: POSITIVE/NEGATIVE/NEUTRAL` per
  section). TIDAK ADA task Gemini terpisah; GDELT throttle = badge
  no-data, bukan error;
- Fear & Greed — feargreedchart.com (public, langsung dari app,
  redirect /api → /api/);
- Chart utama — TradingView Widget embed resmi (WebView). Simbol
  VERIFIKASI via TradingView symbol search 2026-09-13:
  NQ/NAS100=`CME_MINI:NQ1!`, ES/SP500=`CME_MINI:ES1!`,
  YM/DJ30=`CBOT_MINI:YM1!`, XAUUSD=`SAXO:XAUUSD`,
  EURUSD/GBPUSD/USDJPY=`SAXO:*`, BTCUSD=`COINBASE:BTCUSD`,
  DXY=`TVC:DXY`, US10Y=`TVC:US10Y`, USOIL=`NYMEX:CL1!`
  (CBOT:YM1! dan TVC:USOIL TIDAK VALID);
- AI Market Summary — epic P2-06.

Provider tiap sub-fitur terkunci — tidak ada lagi "provider belum
ditentukan". OpenWeb Ninja diganti total (free tier 100 req/BULAN
terlalu ketat untuk watchlist harian).

### State per section (tetap wajib)

- provider available;
- no data;
- unavailable;
- loading;
- error.

Satu section gagal TIDAK boleh block section lain — teruji di widget
test (`test/watchlist/market_screen_test.dart`).

### Fitur tambahan (P2-05, implemented)

- **Market Session Clock — ICT Kill Zones** (bukan sesi umum): chip
  Asia / London / NY AM / NY PM, zona aktif di-highlight (teal), badge
  `OVERLAP` saat 2+ zona aktif (by definition ICT windows tidak saling
  tumpang tindih — flag tetap tersedia). Windows Eastern Time:
  Asia 20:00-00:00, London 02:00-05:00, NY AM 08:30-11:00,
  NY PM 13:30-16:00, Senin-Jumat. DST-aware via package `timezone`
  (America/New_York — EST UTC-5 / EDT UTC-4 otomatis mengikuti
  kalender DST AS), ticker 30s, tanpa API.
- **Loading Shimmer** — skeleton mengikuti bentuk card/row asli
  (`GumiShimmer`), bukan spinner polos.
- **Price flash animation** — harga berkedip teal saat berubah
  (`PriceFlashText`), nilai null tetap `N/A` (tidak pernah fabrikasi).
- **Change chip** — +x.xx% hijau/-x.xx% merah di samping harga.
- **Empty state didesain** — icon + copy ramah per section, bukan teks
  polos.
- **Pull-to-refresh** — `RefreshIndicator` + `HapticFeedback.mediumImpact`.

### Default watchlist (P2-05 revisi, urutan prioritas user)

NQ → XAUUSD (Gold) → YM → ES → EURUSD → GBPUSD → USDJPY → BTCUSD →
DXY → US10Y → USOIL. Tersedia sebagai seed satu-tap di empty state
watchlist. Alias broker (NAS100/DJ30/SP500/US30) tetap dikenali di
mapping simbol untuk watchlist lama yang sudah ter-seed.

### Di-skip (keputusan scope P2-05)

- Sparkline mini-chart di watchlist;
- Currency Strength meter;
- Riwayat AI Market Bias.

AI Market Summary harus memiliki disclaimer yang menyatakan bahwa konten bukan financial advice.

---

## 5.15 Settings

Section:

### Profile

- Display name;
- Email;
- Bio;
- Trading since;
- Starting Balance (optional, editable anytime).

### Appearance

- Dark theme.

### Notifications

- Daily journal reminder;
- Weekly performance summary;
- Economic calendar alerts.

### Privacy & Data

- Data export;
- Delete all data;
- Screenshot privacy information;
- App lock / biometric.

### Trading Tools

- Trading Calculator.

### Account

- Change password;
- Logout;
- Delete account.

Destructive action menggunakan confirmation dialog yang menjelaskan dampaknya.

---

## 5.16 Trading Calculator

Lokasi utama:

`Settings → Trading Calculator`

Akses cepat dari Add Trade dapat diberikan bila tidak mengganggu flow.

Calculator yang disiapkan:

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

UI:

- minimal;
- numeric keypad;
- input dan output jelas;
- hasil mudah di-copy;
- hasil tidak disimpan ke database.

---

## 6. Component Inventory

Komponen reusable minimum:

- `GumiScaffold`
- `GumiAppBar`
- `GlassCard`
- `GlassBottomNav`
- `PrimaryButton`
- `SecondaryButton`
- `DestructiveButton`
- `GumiTextField`
- `NumericField`
- `DateTimeField`
- `SelectField`
- `TagSelector`
- `MetricCard`
- `ProfitLossText`
- `TradeListTile`
- `FilterChip`
- `EmptyState`
- `LoadingState`
- `ErrorState`
- `ConfirmationDialog`
- `PrivacyNotice`
- `ChartContainer`
- `SectionHeader`

Komponen harus menerima token/theme, bukan hardcoded style per screen.

---

## 7. Interaction & Motion

Gunakan animasi untuk:

- navigation compact/expand;
- tab or destination change;
- press feedback;
- sheet/modal transition;
- metric appearance;
- chart reveal secukupnya;
- success feedback setelah trade tersimpan.

Hindari:

- animasi panjang;
- animasi yang menghalangi input;
- parallax berat;
- blur dinamis berlebihan;
- glow besar pada banyak elemen.

Target: motion terasa premium tetapi tetap cepat.

---

## 8. Accessibility

Minimum requirements:

- touch target sekitar 44–48dp;
- text contrast memadai;
- informasi profit/loss tidak hanya dibedakan berdasarkan warna;
- semantic labels untuk icon button;
- support text scaling tanpa memotong data penting;
- error field memiliki pesan teks;
- destructive action memiliki confirmation yang jelas.

---

## 9. Responsive Rules

MVP mobile-first.

Gunakan layout yang aman untuk:

- Android compact phone;
- Android large phone;
- iPhone compact;
- iPhone regular/large.

Guideline:

- konten utama menggunakan horizontal padding 16–20dp;
- card dapat menjadi full-width pada mobile;
- chart height adaptif;
- hindari fixed width yang hanya cocok pada satu device;
- gunakan safe area untuk bottom navigation dan modal.

Tablet layout dapat dioptimalkan setelah mobile MVP stabil.

---

## 10. Copy Style

Copy GumiBook harus:

- singkat;
- professional;
- jelas;
- tidak hiperbolik;
- tidak memberikan financial advice;
- menjelaskan error dan recovery action.

Gunakan istilah trading secara konsisten:

- Entry
- Exit
- Stop Loss
- Take Profit
- Lot Size
- P/L
- Risk/Reward
- Strategy
- Session
- Emotion
- Mistake

---

## 11. Design Acceptance Checklist

Sebuah screen dianggap selesai bila:

- hierarchy informasi jelas;
- dark theme konsisten;
- monochrome/silver tetap dominan;
- semantic colors digunakan sesuai fungsi;
- loading, empty, error, success state tersedia;
- typography dan spacing memakai token;
- action utama mudah ditemukan;
- tidak ada screenshot trading yang muncul di UI setelah extraction selesai;
- destructive action menggunakan confirmation;
- form dapat digunakan tanpa layout overflow pada device kecil;
- screen mendukung keyboard dan safe area dengan benar;
- accessibility label tersedia pada icon-only controls.
