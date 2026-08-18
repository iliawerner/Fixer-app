# Fixer v2 design reference

This directory gives humans and coding agents a durable visual baseline for Fixer v2. It preserves the useful visual language from the original Figma Make concept without treating that web prototype as a literal macOS implementation specification.

## Authority order

When sources disagree, use this order:

1. Current product behavior, privacy, focus safety, and accessibility requirements in [`docs/DESIGN_BRIEF.md`](../docs/DESIGN_BRIEF.md), [`docs/DEVELOPMENT.md`](../docs/DEVELOPMENT.md), and the test suite.
2. Locked decisions in [`VISUAL_SPEC.md`](VISUAL_SPEC.md).
3. The rendered prototype images in [`prototype/`](prototype/) for hierarchy, density, palette, and composition.
4. Native SwiftUI/AppKit conventions for control shape, typography metrics, focus, keyboard behavior, and window chrome.

A screenshot never overrides a safety or behavior requirement. In particular, the prototype contains concepts that are outside the current product scope.

## Reference files

| File | Use it for | Do not copy literally |
|---|---|---|
| [`prototype/workspace.png`](prototype/workspace.png) | Signal-paper palette, master-detail hierarchy, selected-action emphasis, large action heading, compact settings rhythm | Data Vault, History, drag handles/reordering, the Action Type switch, or exact web control styling |
| [`prototype/provider-setup.png`](prototype/provider-setup.png) | Quiet centered setup flow, trust copy near the credential field, clear primary action | Developer state tabs, exposed credential content, or wording that contradicts actual Keychain behavior |
| [`prototype/starter-library.png`](prototype/starter-library.png) | Dense two-column browsing rhythm, visible Added state, concise descriptions | A web-card treatment where a native list or sheet is clearer |
| [`prototype/menu-bar.png`](prototype/menu-bar.png) | Compact status-first menu structure and visible shortcuts | Vault entries, View History, or any menu item not implemented in the current product |
| [`prototype/hud-processing.png`](prototype/hud-processing.png) | Small stable overlay, action name as the primary identifier, secondary technical state | A progress bar without telemetry, repeated-shortcut instructions, activation, or buttons |
| [`prototype/hud-success.png`](prototype/hud-success.png) | Brief success hierarchy and restrained footprint | “Done” as proof that another app accepted the paste |
| [`prototype/hud-error.png`](prototype/hud-error.png) | Longer readable error state and stronger error detail | Clickable Fix Key / See Log controls inside a passive HUD |
| [`identity/splash-master.png`](identity/splash-master.png) | Exact approved identity composition and completeness check | Redrawing, replacing, or simplifying the character, typography, signs, landscape, or edge details |

## What is deliberately not included

The raw Figma Make ZIP and its React source are not committed. The repository is public, and the source prototype contains exploratory features and obsolete behavior that should not become accidental requirements. Only reviewed, credential-free PNG renders are included.

The prototype screenshots are evidence of visual direction, not golden pixel snapshots. Native controls may differ when that improves macOS behavior. The approved splash master is stricter: its visible identity elements must remain complete.

## Native implementation map

| Reference area | Production implementation |
|---|---|
| Palette and typography | [`Sources/FixerTheme.swift`](../Sources/FixerTheme.swift) |
| Workspace shell and provider UI | [`Sources/SettingsView.swift`](../Sources/SettingsView.swift) |
| Action detail and starter library | [`Sources/ActionEditor.swift`](../Sources/ActionEditor.swift) |
| Native fields, buttons, state indicators | [`Sources/FixerComponents.swift`](../Sources/FixerComponents.swift) |
| Passive run feedback | [`Sources/HUD.swift`](../Sources/HUD.swift) |
| Menu, activation, reopen, and splash policy | [`Sources/App.swift`](../Sources/App.swift) |
| Layered identity and parallax | [`Sources/SplashView.swift`](../Sources/SplashView.swift) and [`Sources/Assets.xcassets`](../Sources/Assets.xcassets) |
| Deterministic native renders | [`Tests/V2PreviewRenderingTests.swift`](../Tests/V2PreviewRenderingTests.swift) |
| HUD geometry | [`Tests/HUDLayoutTests.swift`](../Tests/HUDLayoutTests.swift) |
| Splash behavior | [`Tests/SplashPolicyTests.swift`](../Tests/SplashPolicyTests.swift) |

## Provenance

- Original user-supplied archive: `Create Low Fidelity Wireframe.zip`
- Archive SHA-256: `07495afcb05df3f0f0d548361767adfd18857c19b6071415c1121220e2c82b3f`
- Prototype capture viewport: `1280 × 720`
- Capture preparation: selected the relevant initial state, added query-driven screen/state selection, and hid the prototype’s developer jump control. No palette, typography, spacing, or component styling was changed.
- Approved splash source SHA-256: `0986c0748a4eed5a84a31e7d364d4bb92ce833161303504218efeca3e7ce0978`
- The committed splash PNG has identical image data with the source EXIF chunk removed;
  its repository hash is recorded in `manifest.json`.
- File-level dimensions and hashes: [`manifest.json`](manifest.json)

## Generate current native evidence on a Mac

```sh
xcodegen generate
mkdir -p .build/design-renders
FIXER_PREVIEW_DIR="$PWD/.build/design-renders" \
  xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=-
```

The rendering suite writes:

- `workspace.png`
- `splash-settled.png`
- `feedback-working.png`
- `feedback-success.png`
- `feedback-error.png`

Compare those renders and a real running build against [`QA-CHECKLIST.md`](QA-CHECKLIST.md). Do not approve from compile success alone.

## Updating this reference

Only update a reference image when the design direction changed intentionally. In the same commit:

1. explain the decision in `VISUAL_SPEC.md`;
2. replace only the affected reference files;
3. regenerate `manifest.json`;
4. run the native rendering suite on macOS;
5. inspect the affected state at full size;
6. record any deliberate divergence from the original prototype.
