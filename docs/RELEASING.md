# Releasing Fixer

This checklist produces the assets for a public GitHub release without using
the icon-stripped build from CI. The current release line is `0.2.x`.

## Release policy

- Release tags use semantic versions, for example `v0.2.1`.
- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` are the
  source of truth; `Info.plist` expands those build settings.
- The final app must be universal (`arm64` and `x86_64`), target macOS 13 or
  later, use the hardened runtime, include only reviewed entitlements, and omit
  `get-task-allow`.
- GitHub CI verifies deterministic behavior and a locked Release build. The
  headless macOS 15 runner cannot produce reliable AppKit pixel evidence, so the
  preview suite is a separate mandatory macOS 26 release gate.
- The CI build deliberately strips the Icon Composer asset. Never upload it as
  the public release app.

## 1. Prepare the commit

Confirm that all intended source, tests, assets, licenses, release notes, and
dependency locks are tracked. The release commit must be reviewed and CI-green
before tagging.

```sh
git status --short
git diff --check
./scripts/generate-project.sh
```

## 2. Run deterministic tests

```sh
xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skip-testing:FixerTests/V2PreviewRenderingTests \
  -skip-testing:FixerTests/WorkspaceWindowFactoryTests \
  CODE_SIGN_IDENTITY=-
```

## 3. Run the local AppKit gates

Use macOS 26 and Xcode 26+. Pass `FIXER_PREVIEW_DIR` as an Xcode build setting;
a shell-prefix environment variable does not reach the hosted test process.
The window suite is kept out of headless macOS 15 CI because that XCTest host
can crash during teardown after every test has already passed.

```sh
xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -only-testing:FixerTests/WorkspaceWindowFactoryTests \
  CODE_SIGN_IDENTITY=-
```

Then generate the visual evidence:

```sh
mkdir -p .build/design-renders-0.2.2
xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -only-testing:FixerTests/V2PreviewRenderingTests \
  FIXER_PREVIEW_DIR="$PWD/.build/design-renders-0.2.2" \
  CODE_SIGN_IDENTITY=-
```

Review every generated PNG against
[`design-reference/QA-CHECKLIST.md`](../design-reference/QA-CHECKLIST.md), then
complete the live focus, Shortcut, Accessibility, Microphone, Reduce Motion, and
mixed-language Dictation checks that a hosted render cannot prove.

## 4. Analyze and build

Ad-hoc candidate for local QA:

```sh
xcodebuild analyze \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -configuration Release \
  -destination 'platform=macOS'

xcodebuild build \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .build/release-0.2.2
```

For a public Gatekeeper-clean build, override the ad-hoc project setting with a
`Developer ID Application` identity and the correct Team ID. A secure timestamp
is required. Do not put certificate data or notarization credentials in the
repository.

```sh
xcodebuild build \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .build/release-0.2.2 \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  DEVELOPMENT_TEAM="TEAMID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp"
```

## 5. Notarize the public app

Store notarization credentials in a Keychain profile, not in shell history or a
tracked file. The commands below assume the signed app is at
`.build/release-0.2.2/Build/Products/Release/fixer.app`.

```sh
ditto -c -k --sequesterRsrc --keepParent \
  .build/release-0.2.2/Build/Products/Release/fixer.app \
  .build/release-0.2.2/notary-upload.zip

xcrun notarytool submit .build/release-0.2.2/notary-upload.zip \
  --keychain-profile FIXER_NOTARY \
  --wait

xcrun stapler staple .build/release-0.2.2/Build/Products/Release/fixer.app
xcrun stapler validate .build/release-0.2.2/Build/Products/Release/fixer.app
spctl -a -vv --type exec .build/release-0.2.2/Build/Products/Release/fixer.app
```

## 6. Package and verify a round trip

The packaging script copies the bundle as `Fixer.app`, checks version/build,
both architectures, macOS minimum, hardened runtime, entitlements, signature,
and the unpacked archive. It labels a rejected build `-adhoc` or
`-unnotarized`, preventing it from looking like the canonical public asset.

```sh
./scripts/package-release.sh \
  0.2.2 \
  4 \
  .build/release-0.2.2/Build/Products/Release/fixer.app \
  .build/release-0.2.2-assets
```

Expected notarized assets:

- `Fixer-0.2.2-macOS-universal.zip`
- `SHA256SUMS.txt`

## 7. Create a draft GitHub release

Only after the release commit is merged into `main`, CI is green, and explicit
authorization has been given for each Git operation:

```sh
git tag -a v0.2.2 -m "Fixer 0.2.2 — Reliable Titlebar Controls"
git push origin v0.2.2

gh release create v0.2.2 \
  .build/release-0.2.2-assets/Fixer-0.2.2-macOS-universal-adhoc.zip \
  .build/release-0.2.2-assets/SHA256SUMS.txt \
  --verify-tag \
  --draft \
  --title "Fixer 0.2.2 — Reliable Titlebar Controls" \
  --notes-file .github/releases/v0.2.2.md
```

Download the asset from the draft release onto a different user account or Mac,
verify `SHA256SUMS.txt`, and test the quarantined first-run path before publishing
the draft.
