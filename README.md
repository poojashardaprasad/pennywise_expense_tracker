# Pennywise — Monefy-inspired Flutter expense tracker

A fresh Flutter project source bundle. It is an original Monefy-inspired implementation, not a copy of Monefy branding or proprietary assets.

## Included
- Dark green dashboard with balance, monthly income/expenses and category donut chart
- Add/edit income and expense transactions
- Category selection and date picker
- Transaction history; swipe left to delete; tap to edit
- Monthly insights and category spending bars
- Offline SQLite persistence (data stays on the device)
- No account, login, logout, cloud sync or internet requirement

## Create the Android project and build the APK (Windows PowerShell)
1. Install Flutter and Android Studio / Android SDK.
2. Extract this folder.
3. Open PowerShell in this folder and run:

```powershell
flutter create . --platforms=android
flutter pub get
flutter run
```

To create an installable release APK:

```powershell
flutter build apk --release
```

APK output:
`build\app\outputs\flutter-apk\app-release.apk`

## Notes
- Currency is set to Indian Rupees (₹).
- SQLite database name: `monefy_local.db`.
- The APK must be built with Flutter on your computer; this source bundle does not contain a precompiled APK.
