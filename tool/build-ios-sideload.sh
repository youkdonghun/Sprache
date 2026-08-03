#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iPhoneOS sideload packages require macOS with Xcode." >&2
  exit 2
fi

for command_name in flutter xcodebuild pod codesign ditto shasum python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 2
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
client_dir="$repo_root/apps/client"
version="${SPRACHE_VERSION:-1.36.0}"
build_number="${SPRACHE_BUILD_NUMBER:-61}"
bundle_id="${SPRACHE_IOS_BUNDLE_ID:-com.youkdonghun.sprache}"
apple_client_id="${SPRACHE_GOOGLE_APPLE_CLIENT_ID:-1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com}"
apple_reversed_client_id="com.googleusercontent.apps.${apple_client_id%.apps.googleusercontent.com}"
artifact_dir="${SPRACHE_IOS_SIDELOAD_ARTIFACT_DIR:-$repo_root/artifacts/ios-sideload}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "SPRACHE_VERSION must use x.y.z: $version" >&2
  exit 2
fi
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "SPRACHE_BUILD_NUMBER must be a positive integer: $build_number" >&2
  exit 2
fi
if [[ "$bundle_id" != "com.youkdonghun.sprache" ]]; then
  echo "Unexpected iOS bundle identifier: $bundle_id" >&2
  exit 2
fi
if [[ ! "$apple_client_id" =~ ^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$ ]]; then
  echo "SPRACHE_GOOGLE_APPLE_CLIENT_ID is not a Google OAuth client ID." >&2
  exit 2
fi
if [[ "$artifact_dir" != /* ]]; then
  artifact_dir="$repo_root/$artifact_dir"
fi

temp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
work_dir="$(mktemp -d "$temp_parent/sprache-ios-sideload.XXXXXX")"
work_dir="$(cd "$work_dir" && pwd -P)"

cleanup() {
  if [[ -d "$work_dir" && "$(dirname "$work_dir")" = "$temp_parent" && \
        "$(basename "$work_dir")" == sprache-ios-sideload.* ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT

python3 - "$client_dir/pubspec.yaml" "$version" "$build_number" <<'PY'
import pathlib
import re
import sys

path, version, build_number = sys.argv[1:]
match = re.search(
    r'^version:\s*([^+\s]+)\+([0-9]+)\s*$',
    pathlib.Path(path).read_text(encoding='utf-8'),
    re.MULTILINE,
)
assert match, f'{path}: pubspec version is missing'
assert match.group(1) == version and match.group(2) == build_number, (
    f'{path}: expected {version}+{build_number}, found '
    f'{match.group(1)}+{match.group(2)}'
)
PY

mkdir -p "$artifact_dir"
cd "$client_dir"
flutter pub get
find ios -name Podfile -execdir pod install \;

flutter build ios --release --no-codesign \
  --build-name="$version" \
  --build-number="$build_number" \
  --dart-define=APP_ENV=production \
  --dart-define=ENABLE_MOCK_MODE=false \
  --dart-define=APP_VERSION="$version" \
  --dart-define=GOOGLE_APPLE_CLIENT_ID="$apple_client_id"

app_path="$client_dir/build/ios/iphoneos/Runner.app"
app_plist="$app_path/Info.plist"
test -d "$app_path"
test -f "$app_plist"
if [[ -d "$app_path/_CodeSignature" || -f "$app_path/embedded.mobileprovision" ]]; then
  echo "The sideload package must remain unsigned before local re-signing." >&2
  exit 2
fi
if codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
  echo "The sideload package unexpectedly contains a valid signature." >&2
  exit 2
fi

python3 - \
  "$app_plist" \
  "$bundle_id" \
  "$version" \
  "$build_number" \
  "$apple_client_id" \
  "$apple_reversed_client_id" <<'PY'
import pathlib
import plistlib
import sys

(
    app_plist_path,
    bundle_id,
    version,
    build_number,
    apple_client_id,
    reversed_client_id,
) = sys.argv[1:]

with pathlib.Path(app_plist_path).open('rb') as source:
    app = plistlib.load(source)

assert app.get('CFBundleIdentifier') == bundle_id
assert app.get('CFBundleShortVersionString') == version
assert str(app.get('CFBundleVersion')) == build_number
assert app.get('GIDClientID') == apple_client_id
assert app.get('MinimumOSVersion') == '13.0'
assert 'iPhoneOS' in app.get('CFBundleSupportedPlatforms', ())

schemes = [
    scheme
    for item in app.get('CFBundleURLTypes', ())
    if isinstance(item, dict)
    for scheme in item.get('CFBundleURLSchemes', ())
    if isinstance(scheme, str)
]
assert schemes.count('sprache') == 1
assert schemes.count(reversed_client_id) == 1
PY

payload_dir="$work_dir/Payload"
mkdir -p "$payload_dir"
ditto "$app_path" "$payload_dir/Sprache.app"

artifact_name="Sprache-iPhone-Sideload-$version-unsigned.ipa"
artifact_path="$artifact_dir/$artifact_name"
(
  cd "$work_dir"
  ditto -c -k --sequesterRsrc --keepParent Payload "$artifact_path"
)
(
  cd "$artifact_dir"
  shasum -a 256 "$artifact_name" > "$artifact_name.sha256"
)

python3 - \
  "$artifact_path" \
  "$artifact_dir/build-ios-sideload.json" \
  "$version" \
  "$build_number" \
  "$bundle_id" <<'PY'
import hashlib
import json
import pathlib
import sys

artifact_path, output_path, version, build_number, bundle_id = sys.argv[1:]
artifact = pathlib.Path(artifact_path)
result = {
    'format': 'sprache-ios-sideload-build-v1',
    'platform': 'ios',
    'deviceTarget': 'IPHONEOS_UNSIGNED_FOR_LOCAL_FREE_ACCOUNT_RESIGNING',
    'version': version,
    'buildNumber': int(build_number),
    'bundleIdentifier': bundle_id,
    'artifact': artifact.name,
    'bytes': artifact.stat().st_size,
    'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(),
    'appleDistributionSigningVerified': False,
    'requiresLocalResigning': True,
    'physicalDeviceRuntimeVerified': False,
    'expectedFreeAccountValidityDays': 7,
}
pathlib.Path(output_path).write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + '\n',
    encoding='utf-8',
)
PY

echo "Unsigned iPhone sideload IPA is ready: $artifact_path"
