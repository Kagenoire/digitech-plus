# Digitech+

Aplikasi Android companion untuk mahasiswa **Universitas Teknologi Digital**, dibuat karena e-learning resmi kampus tidak memiliki sistem notifikasi.

> Dibuat oleh mahasiswa Universitas Teknologi Digital sebagai solusi pribadi.
> Bukan produk resmi kampus.

---

## Fitur

- **Notifikasi tugas baru** saat dosen mengupload assignment
- **Pengingat deadline** H-24 jam dan H-3 jam sebelum batas waktu
- **Notifikasi presensi dibuka** secara real-time (delay maks 15 menit)
- **Notifikasi tugas terlewat** jika deadline sudah lewat
- **Background sync** otomatis setiap 15 menit via WorkManager
- **Auto-refresh** saat app dibuka kembali dari background
- Login via WebView (mendukung captcha e-learning kampus)

---

## Install APK

1. Download file APK dari [Releases](../../releases)
2. Aktifkan **Install dari sumber tidak dikenal** di pengaturan HP
3. Install dan buka app
4. Login menggunakan akun e-learning kampus seperti biasa
5. Izinkan notifikasi dan battery optimization saat diminta

---

## Build dari Source

**Requirement:**
- Flutter SDK 3.12+
- Android SDK (min API 21)
- Java 17

```bash
git clone https://github.com/Kagenoire/digitech-plus.git
cd digitech-plus
flutter pub get
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Cara Kerja

App ini bekerja dengan cara **scraping** halaman e-learning kampus menggunakan cookie sesi (`ci_session`) yang diambil setelah login via WebView. Tidak ada API resmi yang digunakan.

Konsekuensinya: jika kampus mengubah tampilan atau struktur halaman e-learning, beberapa fitur bisa berhenti bekerja sampai parser diperbarui.

---

## Stack

| Komponen | Library |
|---|---|
| HTTP & scraping | `http`, `html` |
| Login WebView | `webview_flutter` |
| Notifikasi lokal | `flutter_local_notifications` |
| Background sync | `workmanager` |
| Penyimpanan sesi | `flutter_secure_storage` |
| State sync | `shared_preferences` |

---

## Lisensi

MIT License dengan klausul attribution.

Siapapun boleh menggunakan, memodifikasi, dan mendistribusikan app ini dengan syarat mencantumkan kredit kepada pembuat asli. Mahasiswa cukup mencantumkan **"Mahasiswa"**; institusi atau pihak kampus wajib mencantumkan **"Mahasiswa Universitas Teknologi Digital"**. Tidak boleh diklaim sebagai karya pihak kampus atau institusi manapun.

Lihat file [LICENSE](LICENSE) untuk detail lengkap.
