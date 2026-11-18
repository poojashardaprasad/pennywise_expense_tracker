$ErrorActionPreference = "Stop"
Write-Host "Checking Flutter..." -ForegroundColor Cyan
flutter --version
if (!(Test-Path ".\android")) {
  flutter create . --platforms=android
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "APK build failed" }
Write-Host "`nAPK created at: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
