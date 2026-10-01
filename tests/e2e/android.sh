#!/usr/bin/env bash
set -euo pipefail
# The packaged lifecycle must reject incomplete consumer configuration before booting.
if env -u MOBILE_WORKSPACE mobile-develop > /tmp/missing-workspace.log 2>&1; then
  echo 'mobile-develop accepted a missing MOBILE_WORKSPACE' >&2
  exit 1
fi
if [[ "$(cat /tmp/missing-workspace.log)" != *'Set MOBILE_WORKSPACE'* ]]; then
  cat /tmp/missing-workspace.log >&2
  exit 1
fi

mkdir -p "$HOME" "$ANDROID_AVD_HOME" /tmp/native-test/classes /tmp/native-test/dex
cd /tmp/native-test
emulator_pid=''
cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [ "$status" != 0 ]; then tail -n 60 /tmp/emulator.log || true; fi
  if [ -n "$emulator_pid" ]; then kill "$emulator_pid" 2>/dev/null || true; fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

node --version
npm --version
java -version
maestro --version
android_jar="$ANDROID_HOME/platforms/android-36/android.jar"
build_tools="$ANDROID_HOME/build-tools/36.0.0"
javac -source 8 -target 8 -classpath "$android_jar" -d classes /tests/e2e/MainActivity.java
"$build_tools/d8" --lib "$android_jar" --output dex classes/io/helloiampau/mobiletools/smoke/MainActivity.class
"$build_tools/aapt" package -f -M /tests/e2e/AndroidManifest.xml -I "$android_jar" -F unsigned.apk
jar uf unsigned.apk -C dex classes.dex
"$build_tools/zipalign" -f 4 unsigned.apk aligned.apk
# This disposable fixture key never signs a distributed application.
keytool -genkeypair -keystore debug.keystore -storepass android -keypass android \
  -alias androiddebugkey -dname 'CN=Mobile Tools E2E' -keyalg RSA -validity 1
"$build_tools/apksigner" sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android --out test.apk aligned.apk

echo no | avdmanager create avd --name tooling-e2e --device pixel_6 \
  --package 'system-images;android-36;google_apis;x86_64'
adb start-server
emulator -avd tooling-e2e -port 5554 -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu swiftshader_indirect > /tmp/emulator.log 2>&1 &
emulator_pid=$!
for attempt in {1..180}; do
  kill -0 "$emulator_pid"
  if [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then break; fi
  if [ "$attempt" = 180 ]; then echo 'Emulator boot timed out' >&2; exit 1; fi
  sleep 1
done
adb install test.apk
maestro test /tests/e2e/android.yaml
