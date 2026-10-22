#!/usr/bin/env bash
# Installs the release APK on a running emulator, launches it, and checks that
# the first screen appears (the app logs "SEMESTA boot: ui shown") and that no
# start-up step reported a problem. Prints the relevant log either way.
set -u
APK="${1:-app-release.apk}"

adb install -r "$APK" || { echo "install failed"; exit 1; }
adb logcat -c
adb shell monkey -p com.semesta.semesta -c android.intent.category.LAUNCHER 1

shown=0
for _ in $(seq 1 45); do
  sleep 2
  if adb logcat -d | grep -q "SEMESTA boot: ui shown"; then shown=1; break; fi
done
sleep 25 # let the background start-up steps run

echo "=== start-up log ==="
adb logcat -d | grep -E "SEMESTA boot|AndroidRuntime|FATAL EXCEPTION|flutter" | tail -150
echo "=== crash buffer ==="
adb logcat -d -b crash | tail -60

if [ "$shown" != 1 ]; then echo "FAIL: the first screen never appeared"; exit 1; fi
if adb logcat -d | grep -q "SEMESTA boot: PROBLEM"; then echo "FAIL: a start-up step reported a problem"; exit 1; fi
if ! adb logcat -d | grep -q "SEMESTA boot: ready"; then echo "FAIL: start-up never finished"; exit 1; fi
echo "smoke ok"
