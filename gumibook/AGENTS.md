# /Skills usage rules

Selalu terapkan otomatis tanpa diminta:
- caveman (level full)
- ponytail (level full)
- stop-slop

Gunakan otomatis sesuai konteks:
- flutter-setup-declarative-routing — saat kerja routing/go_router
- flutter-implement-json-serialization — saat bikin model/mapper
- flutter-fix-layout-issues — saat ada bug layout/overflow
- flutter-add-widget-test / flutter-add-integration-test — saat nulis test
- flutter-add-widget-preview — saat preview widget UI baru
- flutter-build-responsive-layout — saat kerja layout adaptif
- dart-add-unit-test — saat nulis unit test logic/parser
- dart-run-static-analysis — sebelum menandai task selesai
- dart-fix-runtime-errors — saat debug error runtime
- ui-ux-pro-max — saat kerja desain/styling komponen
- stop-slop — saat menulis teks panjang (deskripsi, dokumentasi, bukan kode)
- to-tickets — saat memecah task besar jadi tiket kecil
- implement — saat eksekusi fitur dari tiket/spec
- tdd — saat mengerjakan logic murni (parser, kalkulasi)
- code-review — sebelum commit perubahan besar
- diagnosing-bugs — saat menelusuri bug yang tidak jelas akar masalahnya
- wizard — saat butuh langkah manual (provisioning, credential, dll)
- git-guardrails-claude-code — selalu aktif saat operasi git
- setup-pre-commit — saat setup awal repo (sudah dipakai di P0-01)
- qa — saat menyusun/menjalankan checklist QA

JANGAN gunakan:
- flutter-apply-architecture-best-practices — konflik Riverpod
- flutter-use-http-package — tidak relevan, project pakai Appwrite SDK
- flutter-setup-localization — tidak ada requirement i18n

# Guard rules (permanen — hasil insiden 3183222/8591cde)

1. Sebelum klaim task selesai, WAJIB jalankan grep/git log/ls (atau command
   verifikasi lain) dan tunjukkan output MENTAH di tool-call — bukan
   diringkas, bukan dinarasikan.
2. Kalau ada sinyal kontradiktif (file tidak berubah di git status, command
   gagal, grep tidak menemukan nilai baru), STOP dan laporkan — jangan
   lanjut mengklaim sukses.
3. Setelah edit file, verifikasi isi file (grep/read) SEBELUM commit dan
   SEBELUM klaim selesai.
4. Tidak ada keputusan repo-hygiene (.gitignore, struktur, config) di luar
   perintah eksplisit user.
