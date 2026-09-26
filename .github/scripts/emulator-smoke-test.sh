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
    adb get-state || true
    adb shell getprop sys.boot_completed || true
    adb logcat -d -t 300 || true
    exit 1
  fi
  sleep 2
done

adb shell settings put secure show_ime_with_hard_keyboard 0 || true

echo "Installing Kadd APK..."
for attempt in 1 2 3; do
  if adb install -r "$APK"; then
    echo "APK installed successfully on attempt $attempt."
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "APK installation failed after 3 attempts."
    adb get-state || true
    adb shell getprop sys.boot_completed || true
    adb logcat -d -t 500 || true
    exit 1
  fi
  echo "APK installation attempt $attempt failed; restarting ADB connection and retrying..."
  adb reconnect || true
  sleep 3
  adb wait-for-device
  sleep 3
done
echo "Resetting app data for a true first-run test..."
adb shell pm clear "$PACKAGE"
echo "Granting Usage Access through AppOps for the emulator test..."
adb shell appops set "$PACKAGE" GET_USAGE_STATS allow

echo "Launching Kadd..."
adb shell monkey -p "$PACKAGE" 1 >/dev/null

dump_ui() {
  adb shell uiautomator dump /sdcard/window.xml >/dev/null 2>&1 || true
  adb shell cat /sdcard/window.xml 2>/dev/null || true
}

wait_for_text() {
  local expected="$1"
  local timeout="${2:-30}"
  for i in $(seq 1 "$timeout"); do
    XML="$(dump_ui)"
    if printf '%s' "$XML" | grep -Fq "$expected"; then
      echo "FOUND: $expected"
      return 0
    fi
    sleep 1
  done
  echo "FAILED TO FIND: $expected"
  dump_ui
  adb logcat -d -t 250
  return 1
}

wait_for_text "ابدأ باختيار التطبيقات" 35
wait_for_text "متابعة إلى الإعدادات" 10
wait_for_text "تطبيقًا متاحًا" 20

echo "Selecting the first launchable app through the deterministic smoke-test hook..."
python3 - <<'PY'
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

def dump():
    subprocess.run(
        ["adb", "shell", "uiautomator", "dump", "/sdcard/window.xml"],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return subprocess.check_output(
        ["adb", "shell", "cat", "/sdcard/window.xml"],
        text=True, stderr=subprocess.DEVNULL,
    )

for attempt in range(1, 11):
    root = ET.fromstring(dump())
    target = None
    for node in root.iter("node"):
        if node.attrib.get("content-desc") == "اختبار اختيار أول تطبيق":
            target = node
            break
    if target is not None:
        bounds = target.attrib.get("bounds", "")
        if target.attrib.get("enabled") == "true":
            if bounds != "[0,0][0,0]":
                match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
                if not match:
                    raise RuntimeError(f"Unexpected bounds: {bounds}")
                left, top, right, bottom = map(int, match.groups())
                x = (left + right) // 2
                y = (top + bottom) // 2
            else:
                # Flutter can expose a semantic node before UIAutomator receives
                # its final bounds. The hook has a fixed 52px row immediately
                # below the intro card, so use its stable center as fallback.
                x, y = 540, 430
            print(f"Tapping smoke-test selection hook at ({x}, {y}), bounds={bounds}")
            subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
            subprocess.run(["sleep", "1"], check=True)
            root = ET.fromstring(dump())
            for node in root.iter("node"):
                if node.attrib.get("content-desc") == "متابعة إلى الإعدادات" and node.attrib.get("enabled") == "true":
                    print("App selection confirmed.")
                    sys.exit(0)
    print(f"Smoke-test selection hook not ready; retry {attempt}/10")
    subprocess.run(["sleep", "1"], check=True)

print(dump())
sys.exit("Could not select an app through the smoke-test hook")
PY
echo "Continuing to the main app..."
# The Continue button is a Flutter-rendered control and has no useful native
# bounds in UIAutomator. On the 1080x1920 emulator it occupies the bottom
# action area; tap its center directly.
adb shell input tap 540 1840
sleep 4
XML="$(dump_ui)"
if printf '%s' "$XML" | grep -Fq "ابدأ باختيار التطبيقات"; then
  echo "FAIL: first-run picker is still visible after Continue"
  dump_ui
  exit 1
fi
if printf '%s' "$XML" | grep -Fq "الرئيسية"; then
  echo "PASS: Kadd reached the main navigation after first-run setup."
else
  echo "FAIL: main navigation was not detected."
  dump_ui
  adb logcat -d -t 400
  exit 1
fi
echo "Kadd emulator smoke test passed."
