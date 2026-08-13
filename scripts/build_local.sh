#!/usr/bin/env bash
# Mirrors .github/workflows/build-apk.yml, for building locally without
# waiting on GitHub Actions. Run from the repo root.
set -euo pipefail

echo "==> Removing any stale local android/ folder"
# Critical: flutter create does NOT overwrite files that already exist. If a
# leftover android/ folder from a previous run is lying around (even though
# .gitignore excludes it from git), flutter create silently skips
# AndroidManifest.xml, and patch_manifest.py's permission/component
# injections never make it into the build — this is exactly what caused
# installed apps to not show up despite the code being correct.
rm -rf android

echo "==> Generating android/ platform folder"
flutter create --platforms=android --org com.comptaflow .

echo "==> Copying native Kotlin sources"
mkdir -p android/app/src/main/kotlin/com/comptaflow/kadd
cp android_additions/kotlin/*.kt android/app/src/main/kotlin/com/comptaflow/kadd/

echo "==> Patching AndroidManifest.xml"
python3 scripts/patch_manifest.py

echo "==> flutter pub get"
flutter pub get

echo "==> Generating launcher icons"
flutter pub run flutter_launcher_icons

echo "==> Building debug APK (use --release for a release build)"
if [[ "${1:-}" == "--release" ]]; then
  flutter build apk --release
  echo "APK at build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build apk --debug
  echo "APK at build/app/outputs/flutter-apk/app-debug.apk"
fi
