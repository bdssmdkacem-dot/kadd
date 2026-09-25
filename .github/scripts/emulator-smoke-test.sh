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

echo "Selecting the first launchable app exposed by the Flutter UI..."
python3 - <<'PY'
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

xml = subprocess.check_output(
    ["adb", "exec-out", "uiautomator", "dump", "/dev/tty"],
    text=True,
    stderr=subprocess.DEVNULL,
)
root = ET.fromstring(xml)
ignored = {
    "ابدأ باختيار التطبيقات",
    "متابعة إلى الإعدادات",
    "ابحث عن تطبيق...",
    "تطبيقًا متاحًا",
    "تحديث",
    "إشعار",
}
candidates = []
for node in root.iter("node"):
    text = (node.attrib.get("text") or "").strip()
    bounds = node.attrib.get("bounds") or ""
    if not text or text in ignored:
        continue
    m = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
    if not m:
        continue
    x1, y1, x2, y2 = map(int, m.groups())
    if y1 < 300 or y2 - y1 < 30:
        continue
    candidates.append((y1, x1, x2, y2, text))
candidates.sort()
if not candidates:
    print(xml)
    sys.exit("No selectable app candidate found in UIAutomator tree")
y1, x1, x2, y2, text = candidates[0]
x = (x1 + x2) // 2
y = (y1 + y2) // 2
print("Selecting app candidate: %r at (%d, %d)" % (text, x, y))
subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=True)
PY

sleep 2
wait_for_text "متابعة إلى الإعدادات" 5

echo "Continuing to the main app..."
python3 - <<'PY'
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
xml = subprocess.check_output(
    ["adb", "exec-out", "uiautomator", "dump", "/dev/tty"],
    text=True,
    stderr=subprocess.DEVNULL,
)
root = ET.fromstring(xml)
for node in root.iter("node"):
    if (node.attrib.get("text") or "").strip() == "متابعة إلى الإعدادات":
        bounds = node.attrib.get("bounds", "")
        m = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            subprocess.run(["adb", "shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2)], check=True)
            break
else:
    print(xml)
    sys.exit("Continue button not found")
PY

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
