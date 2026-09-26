#!/usr/bin/env bash
set -euo pipefail

APK="build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE="com.comptaflow.kadd"

test -f "$APK"
adb wait-for-device

echo "Waiting for Android framework and package manager..."
for i in $(seq 1 60); do
  if adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' | grep -qx "1" &&
     adb shell cmd package list packages >/dev/null 2>&1; then
    echo "Android package manager is ready."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Android package manager did not become ready."
    adb logcat -d -t 300 || true
    exit 1
  fi
  sleep 2
done

echo "Installing debug APK once to prepare Usage Access..."
adb install -r "$APK"
adb shell pm clear "$PACKAGE" >/dev/null
adb shell appops set "$PACKAGE" GET_USAGE_STATS allow
echo "Usage Access granted before Flutter integration test."

echo "Running the real Flutter integration test..."
flutter test integration_test/app_picker_smoke_test.dart -d emulator-5554

echo "Kadd Flutter integration smoke test passed."
