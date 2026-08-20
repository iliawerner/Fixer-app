#!/bin/sh
set -eu

usage() {
    echo "Usage: $0 <version> <build> <path-to-app> <output-directory>" >&2
    exit 64
}

[ "$#" -eq 4 ] || usage

expected_version=$1
expected_build=$2
source_app=$3
output_dir=$4

[ -d "$source_app" ] || {
    echo "App bundle not found: $source_app" >&2
    exit 66
}
[ -f "$source_app/Contents/Info.plist" ] || {
    echo "Invalid app bundle (missing Info.plist): $source_app" >&2
    exit 65
}
[ ! -e "$output_dir" ] || {
    echo "Output path already exists; choose a new directory: $output_dir" >&2
    exit 73
}

stage_dir=$(mktemp -d /tmp/fixer-release.XXXXXX)
trap '/bin/rm -rf "$stage_dir"' EXIT HUP INT TERM

staged_app="$stage_dir/Fixer.app"
/usr/bin/ditto "$source_app" "$staged_app"

plist="$staged_app/Contents/Info.plist"
executable="$staged_app/Contents/MacOS/fixer"

actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
actual_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
minimum_system=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")

[ "$actual_version" = "$expected_version" ] || {
    echo "Expected version $expected_version, found $actual_version" >&2
    exit 65
}
[ "$actual_build" = "$expected_build" ] || {
    echo "Expected build $expected_build, found $actual_build" >&2
    exit 65
}
[ "$minimum_system" = "13.0" ] || {
    echo "Expected macOS minimum 13.0, found $minimum_system" >&2
    exit 65
}

architectures=$(/usr/bin/lipo -archs "$executable")
case " $architectures " in
    *" arm64 "*) ;;
    *) echo "Release is missing arm64: $architectures" >&2; exit 65 ;;
esac
case " $architectures " in
    *" x86_64 "*) ;;
    *) echo "Release is missing x86_64: $architectures" >&2; exit 65 ;;
esac

/usr/bin/codesign --verify --deep --strict --verbose=2 "$staged_app"

signature_info=$(/usr/bin/codesign -dvvv "$staged_app" 2>&1)
case "$signature_info" in
    *"runtime"*) ;;
    *) echo "Release is missing the hardened runtime flag" >&2; exit 65 ;;
esac

entitlements=$(/usr/bin/codesign -d --entitlements - "$staged_app" 2>&1)
case "$entitlements" in
    *"com.apple.security.device.audio-input"*) ;;
    *) echo "Release is missing the audio-input entitlement" >&2; exit 65 ;;
esac
case "$entitlements" in
    *"com.apple.security.get-task-allow"*)
        echo "Release must not contain get-task-allow" >&2
        exit 65
        ;;
esac

artifact_suffix=""
if ! /usr/sbin/spctl -a -vv --type exec "$staged_app" >/dev/null 2>&1; then
    case "$signature_info" in
        *"Signature=adhoc"*) artifact_suffix="-adhoc" ;;
        *) artifact_suffix="-unnotarized" ;;
    esac
    echo "Warning: Gatekeeper rejected this build; packaging as${artifact_suffix}." >&2
fi

/bin/mkdir -p "$output_dir"
archive_name="Fixer-${expected_version}-macOS-universal${artifact_suffix}.zip"
archive_path="$output_dir/$archive_name"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$archive_path"

roundtrip_dir="$stage_dir/roundtrip"
/bin/mkdir -p "$roundtrip_dir"
/usr/bin/ditto -x -k "$archive_path" "$roundtrip_dir"
roundtrip_app="$roundtrip_dir/Fixer.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$roundtrip_app"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$roundtrip_app/Contents/Info.plist")" = "$expected_version" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$roundtrip_app/Contents/Info.plist")" = "$expected_build" ]
[ "$(/usr/bin/lipo -archs "$roundtrip_app/Contents/MacOS/fixer")" = "$architectures" ]

(
    cd "$output_dir"
    /usr/bin/shasum -a 256 "$archive_name" > SHA256SUMS.txt
)

echo "Created $archive_path"
echo "Created $output_dir/SHA256SUMS.txt"
