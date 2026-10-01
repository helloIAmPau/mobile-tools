#!/usr/bin/env bash
set -euo pipefail
cd /source
: "${MOBILE_WORKSPACE:?Set MOBILE_WORKSPACE to the app workspace path relative to /source}"
test -f "$MOBILE_WORKSPACE/app.json"

# A directory mount follows atomic manifest replacements by npm and editors.
# Keep container-installed node_modules isolated from the host installation.
ln -sf /project/package.json package.json
ln -sf /project/package-lock.json package-lock.json

mkdir -p "$HOME" "$ANDROID_AVD_HOME" "$GRADLE_USER_HOME"
rm -f /state/mobile-ready
emulator_pid=''
metro_pid=''
build_pid=''

cleanup() {
  trap - EXIT INT TERM
  rm -f /state/mobile-ready
  for child in "$build_pid" "$metro_pid" "$emulator_pid"; do
    if [ -n "$child" ]; then kill -- "-$child" 2>/dev/null || true; fi
  done
  adb -s "$ANDROID_SERIAL" emu kill >/dev/null 2>&1 || true
  wait || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM

dependencies() {
  node --input-type=module <<'JS'
import { createHash } from 'node:crypto';
import { globSync, readFileSync } from 'node:fs';

const root = JSON.parse(readFileSync('package.json', 'utf8'));
const patterns = Array.isArray(root.workspaces) === true ? root.workspaces : root.workspaces.packages;
const manifests = globSync(patterns.map(function(pattern) {
  return `${ pattern }/package.json`;
}));
const files = [ ...new Set([ 'package.json', 'package-lock.json', ...manifests ]) ].sort();
for (const file of files) {
  console.log(`${ createHash('sha256').update(readFileSync(file)).digest('hex') }  ${ file }`);
}
JS
}

configuration() {
  sha256sum "$MOBILE_WORKSPACE/app.json"
}

start_metro() {
  setsid npm run develop --workspace="$MOBILE_WORKSPACE" -- --localhost &
  metro_pid=$!
}

if [ ! -f "$ANDROID_AVD_HOME/mobile-tools.ini" ]; then
  echo no | avdmanager create avd --name mobile-tools --device pixel_6 \
    --package 'system-images;android-36;google_apis;x86_64'
fi

adb start-server
setsid emulator -avd mobile-tools -port 5554 -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu swiftshader_indirect &
emulator_pid=$!

for attempt in {1..180}; do
  kill -0 "$emulator_pid"
  if [ "$(adb -s "$ANDROID_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
    break
  fi
  if [ "$attempt" = 180 ]; then
    echo 'Android emulator did not boot within three minutes' >&2
    exit 1
  fi
  sleep 1
done
adb -s "$ANDROID_SERIAL" reverse tcp:8081 tcp:8081

installed=''
if [ -f /source/.dependencies.sha256 ]; then
  installed=$(cat /source/.dependencies.sha256)
fi
previous=''
while true; do
  kill -0 "$emulator_pid"
  current_dependencies=$(dependencies)
  current_configuration=$(configuration)
  current="$current_dependencies$current_configuration"

  if [ "$current" != "$previous" ]; then
    rm -f /state/mobile-ready
    # Stop Metro before replacing its dependencies, but retain it for config-only builds.
    if [ "$current_dependencies" != "$installed" ]; then
      if [ -n "$metro_pid" ]; then
        kill -- "-$metro_pid" 2>/dev/null || true
        wait "$metro_pid" || true
        metro_pid=''
      fi
      npm ci
      installed=$current_dependencies
      dependencies > /source/.dependencies.sha256
    fi
    if [ -z "$metro_pid" ]; then start_metro; fi

    echo 'Building and installing the Android development app…'
    CI=1 setsid npm run android --workspace="$MOBILE_WORKSPACE" &
    build_pid=$!
    if wait "$build_pid"; then
      app_id=$(node -p "require(require('node:path').resolve(process.env.MOBILE_WORKSPACE, 'app.json')).expo.android.package")
      scheme=$(node -p "require(require('node:path').resolve(process.env.MOBILE_WORKSPACE, 'app.json')).expo.scheme")
      adb -s "$ANDROID_SERIAL" shell am force-stop "$app_id"
      adb -s "$ANDROID_SERIAL" shell am start -W -a android.intent.action.VIEW \
        -d "'${scheme}://expo-development-client/?url=http%3A%2F%2Flocalhost%3A8081&disableOnboarding=1&disableFab=1&disableAutoLaunch=1'" "$app_id"
      touch /state/mobile-ready
      echo 'Mobile ready: app installed; Metro watches source, tooling watches app.json and dependency manifests.'
    else
      echo 'Android build failed; edit configuration or dependencies to retry.' >&2
    fi
    build_pid=''
    previous=$current
  fi

  if [ -n "$metro_pid" ]; then kill -0 "$metro_pid"; fi
  sleep 2
done
