#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Apple preview builds require macOS with Xcode." >&2
  exit 2
fi

for command_name in flutter xcrun xcodebuild codesign ditto shasum python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 2
  fi
done

if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  echo "Required command is missing: /usr/libexec/PlistBuddy" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
client_dir="$repo_root/apps/client"
version="${SPRACHE_VERSION:-1.34.0}"
build_number="${SPRACHE_BUILD_NUMBER:-58}"
artifact_dir="${SPRACHE_APPLE_ARTIFACT_DIR:-$repo_root/artifacts/apple-preview}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "SPRACHE_VERSION must use x.y.z: $version" >&2
  exit 2
fi
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "SPRACHE_BUILD_NUMBER must be a positive integer: $build_number" >&2
  exit 2
fi
if [[ "$artifact_dir" != /* ]]; then
  artifact_dir="$repo_root/$artifact_dir"
fi
if [[ "${CI:-}" != "true" && "${CI:-}" != "1" && \
      "${SPRACHE_ALLOW_ISOLATED_APPLE_RUNTIME:-}" != "1" ]]; then
  cat >&2 <<'EOF'
The runtime proof launches the production bundle identifier and may write to its
macOS sandbox container. Run this script in an ephemeral CI account, or use a
clean dedicated macOS user and set SPRACHE_ALLOW_ISOLATED_APPLE_RUNTIME=1.
EOF
  exit 2
fi

mkdir -p "$artifact_dir"
temp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
work_dir="$(mktemp -d "$temp_parent/sprache-apple-preview.XXXXXX")"
work_dir="$(cd "$work_dir" && pwd -P)"
ios_device_id=""
ios_device_created="false"
macos_app_pid=""

cleanup() {
  if [[ -n "$ios_device_id" ]]; then
    xcrun simctl shutdown "$ios_device_id" >/dev/null 2>&1 || true
    if [[ "$ios_device_created" = "true" ]]; then
      xcrun simctl delete "$ios_device_id" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$macos_app_pid" ]]; then
    kill "$macos_app_pid" >/dev/null 2>&1 || true
    wait "$macos_app_pid" >/dev/null 2>&1 || true
  fi
  if [[ -d "$work_dir" && "$(dirname "$work_dir")" = "$temp_parent" && \
        "$(basename "$work_dir")" == sprache-apple-preview.* ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT

read_plist() {
  local plist_path="$1"
  local plist_key="$2"
  /usr/libexec/PlistBuddy -c "Print :$plist_key" "$plist_path"
}

publish_runtime_evidence() {
  local evidence_path="$1"
  local platform="$2"
  local probe="$3"
  local output_json_name="$4"
  local output_frame_name="$5"
  python3 - \
    "$evidence_path" \
    "$platform" \
    "$version" \
    "$build_number" \
    "$probe" \
    "$artifact_dir/$output_json_name" \
    "$artifact_dir/$output_frame_name" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

(
    path,
    platform,
    version,
    build_number,
    probe,
    output_json_path,
    output_frame_path,
) = sys.argv[1:]
path = pathlib.Path(path)
output_json_path = pathlib.Path(output_json_path)
output_frame_path = pathlib.Path(output_frame_path)
value = json.loads(path.read_text())
assert value['format'] == 'sprache-runtime-evidence-v1'
assert value['platform'] == platform
assert value['mode'] == 'MOCK'
assert value['version'] == version
assert value['buildNumber'] == int(build_number)
assert value['launched'] is True
assert value['firstFrameRendered'] is True
assert value['probe'] == probe
assert 0 <= value['firstFrameMillis'] <= 60000
assert re.fullmatch(r'[0-9a-f]{64}', value['frameSha256'])
frame_name = value['frameFile']
assert pathlib.Path(frame_name).name == frame_name
frame_bytes = (path.parent / frame_name).read_bytes()
assert frame_bytes.startswith(b'\x89PNG\r\n\x1a\n')
assert hashlib.sha256(frame_bytes).hexdigest() == value['frameSha256']
output_frame_path.write_bytes(frame_bytes)
value['frameFile'] = output_frame_path.name
output_json_path.write_text(
    json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n'
)
PY
}

common_defines=(
  "--dart-define=APP_ENV=ci"
  "--dart-define=ENABLE_MOCK_MODE=true"
  "--dart-define=APP_VERSION=$version"
  "--dart-define=ENABLE_RELEASE_PROBE=true"
  "--dart-define=RELEASE_PROBE_MODE=MOCK"
  "--dart-define=RELEASE_BUILD_NUMBER=$build_number"
)

echo "Building Sprache Apple previews $version+$build_number"
cd "$client_dir"
flutter pub get

flutter build ios --simulator --debug \
  --build-name="$version" \
  --build-number="$build_number" \
  "${common_defines[@]}" \
  --dart-define=RELEASE_PROBE_KIND=simulator-runtime

ios_app="$client_dir/build/ios/iphonesimulator/Runner.app"
ios_plist="$ios_app/Info.plist"
test -d "$ios_app"
test "$(read_plist "$ios_plist" CFBundleIdentifier)" = "com.youkdonghun.sprache"
test "$(read_plist "$ios_plist" CFBundleName)" = "Sprache"
test "$(read_plist "$ios_plist" MinimumOSVersion)" = "13.0"
test "$(read_plist "$ios_plist" CFBundleShortVersionString)" = "$version"
test "$(read_plist "$ios_plist" CFBundleVersion)" = "$build_number"
test "$(read_plist "$ios_plist" 'CFBundleURLTypes:0:CFBundleURLSchemes:0')" = "sprache"
read_plist "$ios_plist" 'CFBundleDocumentTypes:0:LSItemContentTypes' |
  grep -q 'com.youkdonghun.sprache.json-lines'

read -r ios_device_type ios_runtime < <(python3 - <<'PY'
import json
import subprocess

device_types = json.loads(
    subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devicetypes', '-j'],
        text=True,
    )
)['devicetypes']
runtimes = json.loads(
    subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'runtimes', '-j'],
        text=True,
    )
)['runtimes']

available_ios_runtimes = [
    item for item in runtimes
    if item.get('isAvailable')
    and item.get('identifier', '').startswith(
        'com.apple.CoreSimulator.SimRuntime.iOS-'
    )
]
if not available_ios_runtimes:
    raise SystemExit('No compatible iPhone Simulator runtime was found')

def version_key(runtime):
    return tuple(int(part) for part in runtime['version'].split('.'))

runtime = max(available_ios_runtimes, key=version_key)
supported_ids = {
    item.get('identifier') if isinstance(item, dict) else item
    for item in runtime.get('supportedDeviceTypes', ())
}
supported_ids.discard(None)
compatible_iphones = [
    item for item in device_types
    if item['name'].startswith('iPhone')
    and (not supported_ids or item['identifier'] in supported_ids)
]
preferred_names = ('iPhone 16 Pro', 'iPhone 16', 'iPhone 15 Pro')
device_type = next(
    (
        item
        for name in preferred_names
        for item in compatible_iphones
        if item['name'] == name
    ),
    compatible_iphones[0] if compatible_iphones else None,
)
if device_type is None:
    raise SystemExit('No compatible iPhone Simulator device type was found')
print(device_type['identifier'], runtime['identifier'])
PY
)
ios_device_id="$(
  xcrun simctl create \
    "Sprache Preview $build_number" "$ios_device_type" "$ios_runtime"
)"
ios_device_created="true"

xcrun simctl boot "$ios_device_id" 2>/dev/null || true
xcrun simctl bootstatus "$ios_device_id" -b
xcrun simctl uninstall "$ios_device_id" com.youkdonghun.sprache 2>/dev/null || true
xcrun simctl install "$ios_device_id" "$ios_app"
xcrun simctl launch --terminate-running-process \
  "$ios_device_id" com.youkdonghun.sprache

ios_data_container="$(
  xcrun simctl get_app_container \
    "$ios_device_id" com.youkdonghun.sprache data
)"
ios_marker=""
for _ in $(seq 1 120); do
  ios_marker="$(
    find "$ios_data_container/Library/Application Support" \
      -type f -name 'sprache-runtime-evidence-v1.json' \
      -print -quit 2>/dev/null || true
  )"
  if [[ -n "$ios_marker" ]]; then break; fi
  sleep 0.5
done
test -n "$ios_marker"
publish_runtime_evidence \
  "$ios_marker" ios simulator-runtime \
  runtime-ios.json runtime-ios-first-frame.png
xcrun simctl io "$ios_device_id" screenshot \
  "$artifact_dir/runtime-ios-simulator-screenshot.png"

ios_artifact_name="Sprache-iOS-Simulator-$version-mock.zip"
ditto -c -k --sequesterRsrc --keepParent \
  "$ios_app" "$work_dir/$ios_artifact_name"
mv -f "$work_dir/$ios_artifact_name" "$artifact_dir/$ios_artifact_name"
(
  cd "$artifact_dir"
  shasum -a 256 "$ios_artifact_name" > "$ios_artifact_name.sha256"
)
xcrun simctl shutdown "$ios_device_id" >/dev/null 2>&1 || true
xcrun simctl delete "$ios_device_id" >/dev/null 2>&1 || true
ios_device_id=""
ios_device_created="false"

flutter build macos --release \
  --build-name="$version" \
  --build-number="$build_number" \
  "${common_defines[@]}" \
  --dart-define=RELEASE_PROBE_KIND=native-runtime

macos_app="$client_dir/build/macos/Build/Products/Release/Sprache.app"
macos_plist="$macos_app/Contents/Info.plist"
ci_entitlements="$work_dir/sprache-macos-ci.entitlements"
test -d "$macos_app"
test -x "$macos_app/Contents/MacOS/Sprache"
test -f "$macos_plist"
cp "$client_dir/macos/Runner/Release.entitlements" "$ci_entitlements"
/usr/libexec/PlistBuddy -c 'Delete :keychain-access-groups' \
  "$ci_entitlements" 2>/dev/null || true
codesign --force --deep --sign - "$macos_app"
codesign --force --sign - --entitlements "$ci_entitlements" "$macos_app"
codesign --verify --deep --strict --verbose=2 "$macos_app"
test "$(read_plist "$macos_plist" CFBundleIdentifier)" = "com.youkdonghun.sprache"
test "$(read_plist "$macos_plist" CFBundleName)" = "Sprache"
test "$(read_plist "$macos_plist" LSMinimumSystemVersion)" = "12.0"
test "$(read_plist "$macos_plist" CFBundleShortVersionString)" = "$version"
test "$(read_plist "$macos_plist" CFBundleVersion)" = "$build_number"
test "$(read_plist "$macos_plist" 'CFBundleURLTypes:0:CFBundleURLSchemes:0')" = "sprache"
read_plist "$macos_plist" 'CFBundleDocumentTypes:0:LSItemContentTypes' |
  grep -q 'com.youkdonghun.sprache.json-lines'

macos_launch_log="$work_dir/macos-runtime.log"
macos_launch_start="$work_dir/macos-launch-start"
touch "$macos_launch_start"
"$macos_app/Contents/MacOS/Sprache" >"$macos_launch_log" 2>&1 &
macos_app_pid=$!
macos_marker=""
for _ in $(seq 1 120); do
  if ! kill -0 "$macos_app_pid" 2>/dev/null; then
    cat "$macos_launch_log" >&2 || true
    exit 1
  fi
  macos_marker="$(
    find \
      "$HOME/Library/Containers/com.youkdonghun.sprache/Data/Library/Application Support" \
      "$HOME/Library/Application Support" \
      -type f -name 'sprache-runtime-evidence-v1.json' \
      -newer "$macos_launch_start" -print -quit 2>/dev/null || true
  )"
  if [[ -n "$macos_marker" ]]; then break; fi
  sleep 0.5
done
test -n "$macos_app_pid"
kill -0 "$macos_app_pid"
test -n "$macos_marker"
publish_runtime_evidence \
  "$macos_marker" macos native-runtime \
  runtime-macos.json runtime-macos-first-frame.png

macos_artifact_name="Sprache-macOS-$version-mock.zip"
ditto -c -k --sequesterRsrc --keepParent \
  "$macos_app" "$work_dir/$macos_artifact_name"
mv -f "$work_dir/$macos_artifact_name" "$artifact_dir/$macos_artifact_name"
(
  cd "$artifact_dir"
  shasum -a 256 "$macos_artifact_name" > "$macos_artifact_name.sha256"
)

echo "Apple preview artifacts are ready in $artifact_dir"
