#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Signed iPhone IPA builds require macOS with Xcode." >&2
  exit 2
fi

for command_name in \
  flutter xcodebuild xcode-project pod unzip codesign security shasum python3; do
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
version="${SPRACHE_VERSION:-1.34.1}"
build_number="${SPRACHE_BUILD_NUMBER:-59}"
bundle_id="${SPRACHE_IOS_BUNDLE_ID:-com.youkdonghun.sprache}"
apple_client_id="${SPRACHE_GOOGLE_APPLE_CLIENT_ID:-1054343487948-8ueu92l0ov3259rs8psun40c6iu4arel.apps.googleusercontent.com}"
apple_reversed_client_id="com.googleusercontent.apps.${apple_client_id%.apps.googleusercontent.com}"
artifact_dir="${SPRACHE_IOS_DEVICE_ARTIFACT_DIR:-$repo_root/artifacts/ios-device}"
export_options="${SPRACHE_EXPORT_OPTIONS_PLIST:-$HOME/export_options.plist}"

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
work_dir="$(mktemp -d "$temp_parent/sprache-ios-device.XXXXXX")"
work_dir="$(cd "$work_dir" && pwd -P)"

cleanup() {
  if [[ -d "$work_dir" && "$(dirname "$work_dir")" = "$temp_parent" && \
        "$(basename "$work_dir")" == sprache-ios-device.* ]]; then
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

xcode-project use-profiles --project "$client_dir/ios/Runner.xcodeproj"
if [[ ! -f "$export_options" ]]; then
  echo "Code signing did not create export options: $export_options" >&2
  exit 2
fi

flutter build ipa --release \
  --build-name="$version" \
  --build-number="$build_number" \
  --export-options-plist="$export_options" \
  --dart-define=APP_ENV=production \
  --dart-define=ENABLE_MOCK_MODE=false \
  --dart-define=APP_VERSION="$version" \
  --dart-define=GOOGLE_APPLE_CLIENT_ID="$apple_client_id"

shopt -s nullglob
ipa_candidates=("$client_dir"/build/ios/ipa/*.ipa)
shopt -u nullglob
if [[ "${#ipa_candidates[@]}" -ne 1 ]]; then
  echo "Expected exactly one signed IPA, found ${#ipa_candidates[@]}." >&2
  exit 2
fi

ipa_path="${ipa_candidates[0]}"
unpack_dir="$work_dir/unpacked"
mkdir -p "$unpack_dir"
unzip -q "$ipa_path" -d "$unpack_dir"

shopt -s nullglob
app_candidates=("$unpack_dir"/Payload/*.app)
shopt -u nullglob
if [[ "${#app_candidates[@]}" -ne 1 ]]; then
  echo "Expected exactly one app bundle in the IPA." >&2
  exit 2
fi

app_path="${app_candidates[0]}"
app_plist="$app_path/Info.plist"
profile_path="$app_path/embedded.mobileprovision"
profile_plist="$work_dir/profile.plist"
test -f "$app_plist"
test -f "$profile_path"

codesign --verify --deep --strict --verbose=2 "$app_path"
codesign_output="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
if ! grep -Eq '^Authority=(Apple Distribution|iPhone Distribution)' \
  <<<"$codesign_output"; then
  echo "The IPA is not signed with an Apple distribution certificate." >&2
  exit 2
fi
if ! grep -Eq '^TeamIdentifier=[A-Z0-9]{10}$' <<<"$codesign_output"; then
  echo "The signed app is missing an Apple TeamIdentifier." >&2
  exit 2
fi

security cms -D -i "$profile_path" > "$profile_plist"
python3 - \
  "$app_plist" \
  "$profile_plist" \
  "$bundle_id" \
  "$version" \
  "$build_number" \
  "$apple_client_id" \
  "$apple_reversed_client_id" <<'PY'
import datetime
import pathlib
import plistlib
import sys

(
    app_plist_path,
    profile_plist_path,
    bundle_id,
    version,
    build_number,
    apple_client_id,
    reversed_client_id,
) = sys.argv[1:]

with pathlib.Path(app_plist_path).open('rb') as source:
    app = plistlib.load(source)
with pathlib.Path(profile_plist_path).open('rb') as source:
    profile = plistlib.load(source)

assert app.get('CFBundleIdentifier') == bundle_id
assert app.get('CFBundleShortVersionString') == version
assert str(app.get('CFBundleVersion')) == build_number
assert app.get('GIDClientID') == apple_client_id
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

expiration = profile.get('ExpirationDate')
assert isinstance(expiration, datetime.datetime)
if expiration.tzinfo is None:
    expiration = expiration.replace(tzinfo=datetime.timezone.utc)
assert expiration > datetime.datetime.now(datetime.timezone.utc)

team_ids = profile.get('TeamIdentifier')
assert isinstance(team_ids, list) and len(team_ids) == 1
team_id = team_ids[0]
entitlements = profile.get('Entitlements', {})
assert entitlements.get('application-identifier') == f'{team_id}.{bundle_id}'
assert entitlements.get('com.apple.developer.team-identifier') == team_id
assert entitlements.get('get-task-allow') is False
provisioned_devices = profile.get('ProvisionedDevices')
assert isinstance(provisioned_devices, list) and provisioned_devices
assert profile.get('ProvisionsAllDevices') is not True
PY

artifact_name="Sprache-iPhone-Direct-Install-$version.ipa"
artifact_path="$artifact_dir/$artifact_name"
cp -f "$ipa_path" "$artifact_path"
(
  cd "$artifact_dir"
  shasum -a 256 "$artifact_name" > "$artifact_name.sha256"
)

python3 - \
  "$artifact_path" \
  "$artifact_dir/build-ios-device.json" \
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
    'format': 'sprache-ios-device-build-v1',
    'platform': 'ios',
    'deviceTarget': 'IPHONE_REGISTERED_DEVICE_AD_HOC_DIRECT_INSTALL',
    'version': version,
    'buildNumber': int(build_number),
    'bundleIdentifier': bundle_id,
    'artifact': artifact.name,
    'bytes': artifact.stat().st_size,
    'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(),
    'appleDistributionSigningVerified': True,
    'adHocProvisioningProfileVerified': True,
    'physicalDeviceRuntimeVerified': False,
}
pathlib.Path(output_path).write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + '\n',
    encoding='utf-8',
)
PY

echo "Ad Hoc signed iPhone IPA is ready: $artifact_path"
