# Fixer v2 design reference

This directory gives humans and coding agents a durable visual baseline for Fixer v2. It preserves the useful visual language from the original Figma Make concept without treating that web prototype as a literal macOS implementation specification.

## Authority order

When sources disagree, use this order:

1. Shipped product behavior and tested privacy, focus-safety, accessibility, and
   data-integrity contracts in the native implementation and test suite.
2. Current v2 scope, terminology, and locked design decisions in
   [`VISUAL_SPEC.md`](VISUAL_SPEC.md). This document explicitly resolves the
   original brief's open design questions; its v2 resolutions control over legacy
   requests to add History, reordering, or choose new interface names.
3. The still-applicable functional problem and constraints in
   [`docs/DESIGN_BRIEF.md`](../docs/DESIGN_BRIEF.md), with build and architecture
   guidance in [`docs/DEVELOPMENT.md`](../docs/DEVELOPMENT.md).
4. The rendered prototype images in [`prototype/`](prototype/) for hierarchy,
   density, palette, and composition.
5. Native SwiftUI/AppKit conventions for control shape, typography metrics,
   focus, keyboard behavior, and window chrome.

A screenshot never overrides a safety or behavior requirement. In particular, the prototype contains concepts that are outside the current product scope.

## Reference files

| File | Use it for | Do not copy literally |
|---|---|---|
| [`prototype/workspace.png`](prototype/workspace.png) | Signal-paper palette, master-detail hierarchy, compact yellow Action identity, selected-action emphasis, and dense settings rhythm | The prototype's ruler, oversized/stretching Action hero, duplicate status and Shortcut indicators, Data Vault, History, search, drag handles/reordering, the Action Type switch, or exact web control styling |
| [`prototype/provider-setup.png`](prototype/provider-setup.png) | Quiet centered setup flow, trust copy near the credential field, clear primary action | Developer state tabs, exposed credential content, or wording that contradicts actual Keychain behavior |
| [`prototype/starter-library.png`](prototype/starter-library.png) | Dense two-column browsing rhythm, visible Added state, concise descriptions | A web-card treatment where a native list or sheet is clearer |
| [`prototype/menu-bar.png`](prototype/menu-bar.png) | Compact status-first menu structure and visible shortcuts | Vault entries, View History, or any menu item not implemented in the current product |
| [`prototype/hud-processing.png`](prototype/hud-processing.png) | Small stable overlay and enough context to identify the running Action | Its dark branded shell, repeated title/wordmark, progress track, activation, buttons, or repair metaphor; the native HUD is a compact warm-neutral status card |
| [`prototype/hud-success.png`](prototype/hud-success.png) | Brief success hierarchy, restrained footprint, and a semantic transition from the working state | “Done” as proof that another app accepted the paste, or a looping completion effect |
| [`prototype/hud-error.png`](prototype/hud-error.png) | Longer readable error state and stronger error detail | Clickable Fix Key / See Log controls, duplicated branding, or a second card inside a passive HUD |
| [`identity/splash-master.png`](identity/splash-master.png) | Exact approved identity composition and completeness check | A black window backdrop, redrawing, replacing, or simplifying the character, typography, signs, landscape, or edge details |

## What is deliberately not included

The raw Figma Make ZIP and its React source are not committed. The repository is public, and the source prototype contains exploratory features and obsolete behavior that should not become accidental requirements. Only reviewed, credential-free PNG renders are included.

The prototype screenshots are evidence of visual direction, not golden pixel snapshots. Native controls may differ when that improves macOS behavior. The approved splash master is stricter: its visible identity elements must remain complete.

## Native implementation map

| Reference area | Production implementation |
|---|---|
| Palette and typography | [`Sources/FixerTheme.swift`](../Sources/FixerTheme.swift) |
| System workspace window and geometry | [`Sources/WorkspaceWindowFactory.swift`](../Sources/WorkspaceWindowFactory.swift), [`Sources/WorkspaceWindowMetrics.swift`](../Sources/WorkspaceWindowMetrics.swift) |
| Workspace shell, titlebar row, and provider UI | [`Sources/SettingsView.swift`](../Sources/SettingsView.swift), [`Sources/ActionLibraryTitlebarRow.swift`](../Sources/ActionLibraryTitlebarRow.swift) |
| Action detail and starter library | [`Sources/ActionEditor.swift`](../Sources/ActionEditor.swift), the `Sources/ActionEditor*.swift` sections, the permanent Dictation components in `Sources/Dictation*.swift`, and [`Sources/StarterLibrarySheet.swift`](../Sources/StarterLibrarySheet.swift) |
| Shared fields, buttons, and state indicators | [`Sources/FixerComponents.swift`](../Sources/FixerComponents.swift), [`Sources/ActionEditorOutputControl.swift`](../Sources/ActionEditorOutputControl.swift), [`Sources/ActionEditorEnabledControl.swift`](../Sources/ActionEditorEnabledControl.swift) |
| Passive run feedback | [`Sources/HUD.swift`](../Sources/HUD.swift), [`Sources/HUDManager.swift`](../Sources/HUDManager.swift), [`Sources/HUDPanel.swift`](../Sources/HUDPanel.swift), [`Sources/HUDPresentationModel.swift`](../Sources/HUDPresentationModel.swift), [`Sources/HUDVisuals.swift`](../Sources/HUDVisuals.swift), and [`Sources/HUDVoiceLevelIndicator.swift`](../Sources/HUDVoiceLevelIndicator.swift) |
| Menu, activation, reopen, and first-launch routing | [`Sources/App.swift`](../Sources/App.swift) and [`Sources/SplashPolicy.swift`](../Sources/SplashPolicy.swift) |
| Floating splash window and identity motion | [`Sources/SplashWindowController.swift`](../Sources/SplashWindowController.swift), [`Sources/SplashView.swift`](../Sources/SplashView.swift), [`Sources/SplashCardView.swift`](../Sources/SplashCardView.swift), [`Sources/SplashMotion.swift`](../Sources/SplashMotion.swift), and [`Sources/Assets.xcassets`](../Sources/Assets.xcassets) |
| Deterministic native renders | [`Tests/V2PreviewRenderingTests.swift`](../Tests/V2PreviewRenderingTests.swift) |
| Action editor geometry and palette bounds | [`Tests/ActionEditorLayoutTests.swift`](../Tests/ActionEditorLayoutTests.swift) |
| Standard workspace window configuration | [`Tests/WorkspaceWindowFactoryTests.swift`](../Tests/WorkspaceWindowFactoryTests.swift), [`Tests/WorkspaceWindowMetricsTests.swift`](../Tests/WorkspaceWindowMetricsTests.swift) |
| HUD geometry, panel contract, and persistent state | [`Tests/HUDLayoutTests.swift`](../Tests/HUDLayoutTests.swift), [`Tests/HUDPanelTests.swift`](../Tests/HUDPanelTests.swift), and [`Tests/HUDPresentationModelTests.swift`](../Tests/HUDPresentationModelTests.swift) |
| Splash policy, motion, and transparent window | [`Tests/SplashPolicyTests.swift`](../Tests/SplashPolicyTests.swift), [`Tests/SplashMotionTests.swift`](../Tests/SplashMotionTests.swift), and [`Tests/SplashWindowTests.swift`](../Tests/SplashWindowTests.swift) |

## Provenance

- Original user-supplied archive: `Create Low Fidelity Wireframe.zip`
- Archive SHA-256: `07495afcb05df3f0f0d548361767adfd18857c19b6071415c1121220e2c82b3f`
- Prototype capture viewport: `1280 × 720`
- Capture preparation: selected the relevant initial state, added query-driven screen/state selection, and hid the prototype’s developer jump control. No palette, typography, spacing, or component styling was changed.
- Approved splash source SHA-256: `0986c0748a4eed5a84a31e7d364d4bb92ce833161303504218efeca3e7ce0978`
- The committed splash PNG has identical image data with the source EXIF chunk removed;
  its repository hash is recorded in `manifest.json`.
- File-level dimensions and hashes: [`manifest.json`](manifest.json)

The archive and approved-source hashes are provenance records. They cannot be
recomputed from a public clone because those source artifacts are deliberately not
committed. The hashes and dimensions of every committed PNG are independently
recomputable from `manifest.json`.

## Generate current native evidence on a Mac

Start with the Xcode and XcodeGen requirements in
[`docs/DEVELOPMENT.md`](../docs/DEVELOPMENT.md#requirements), then run:

```sh
./scripts/generate-project.sh
mkdir -p .build/design-renders
xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  FIXER_PREVIEW_DIR="$PWD/.build/design-renders" \
  CODE_SIGN_IDENTITY=-
```

The rendering suite writes:

- `workspace-default.png` (`820 × 720`)
- `workspace-minimum.png` (`760 × 620`)
- `workspace-expanded.png` (`1440 × 900`)
- `splash-settled.png`
- `feedback-working.png`
- `feedback-listening.png`
- `feedback-success.png`
- `feedback-error.png`
- `feedback-working-reduced-motion.png`
- `feedback-error-large-text.png`

Compare those renders and a real running build against [`QA-CHECKLIST.md`](QA-CHECKLIST.md). Do not approve from compile success alone.

### Deterministic evidence contract

Static render evidence must not depend on network timing, a real Keychain,
recorded global shortcuts, pointer position, or an animation sampled mid-flight.

- The three workspace renders use the same injected Actions/provider fixture,
  with the protected **Dictation** Action pinned first and selected. The
  default, minimum, and expanded canvases verify the `820 × 720` launch size,
  `760 × 620` minimum, `1440 × 900` expansion, `817 pt` natural total width,
  `292 pt` target sidebar, a leading-aligned editor column capped at `480 pt`,
  the protected Dictation editor at all three sizes, a non-stretching `40 pt`
  native sidebar titlebar, and the fixed `100 pt` yellow Action masthead.
  Ordinary-Action Prompt growth remains covered by layout tests and the live
  workspace pass rather than this Dictation-selected matrix.
- Workspace PNGs render the SwiftUI content, not the operating-system frame.
  They do not prove the macOS 26 corner shape, shadow, or traffic-light stacking.
  `WorkspaceWindowFactoryTests` checks the AppKit configuration. A live macOS 26
  pass must verify the final system-drawn window.
- Every detail masthead is an exactly `100 pt` full-yellow identity surface
  with a quiet square grid. It has no ruler or animated underline. Its only
  state-like content is the Action identity near the bottom-left. An ordinary
  Action uses its large editable name and a top-right `…` menu. Dictation uses a
  fixed microphone/name identity and no options menu because it cannot be
  renamed, duplicated, or deleted. Action number, enabled state, Shortcut, save
  state, and repeated identity art are not duplicated there.
- An ordinary editor renders Prompt, Shortcut, Output, Model, and Enabled in one
  vertical column. The Dictation editor renders Shortcut, **Press again** /
  **Hold**, recognition/privacy disclosure, and Enabled in one column, with no
  Prompt, Output, or Model controls. The sidebar renders each Action's name and
  Shortcut without an enabled dot or redundant selection rail.
- The standard AppKit window uses an itemless `.unifiedCompact` toolbar. Its
  traffic lights and sidebar controls share one `40 pt` plane with a `20 pt`
  control axis. The sidebar shows no **Actions** or **New** titlebar words: its
  icon-only `28 × 28 pt` **+** begins at `x = 88 pt` and opens exactly **Blank
  Action** and **From Starter Library**. A separate trailing **Setup** icon is
  always available and shows issue status only while setup is incomplete.
- The sidebar hairline ends at `40 pt`; the yellow masthead hairline ends at
  `100 pt`. Their intentionally different heights must not be hidden behind one
  fake shared separator.
- Pointer feedback is part of the evidence contract: the icon-only add and
  **Setup** controls have hover, press, and keyboard-focus states plus clear
  tooltip/accessibility names. Rows, the Action `…` menu, Output, Enabled,
  **Custom Model ID**, and primary/secondary buttons use the same coherent
  stationary feedback language.
- `splash-settled.png` uses the explicit settled presentation: zero tilt, all five
  layers visible, no animation task, and transparent pixels outside the card and
  its custom overscan shadow.
- HUD PNGs represent stable semantic states. They verify the warm-neutral status
  card, standard state symbol, concise copy, hierarchy, and clipping. Working and
  busy show the Action name once; success shows the exact Replace/Append outcome;
  error gives a reason and next step. `feedback-listening.png` additionally
  verifies that measured microphone-level bars fit the same compact shell without
  becoming a fake waveform, transcript, or decorative loop.
  `feedback-working-reduced-motion.png` exercises the HUD's explicit static-motion
  policy, while `feedback-error-large-text.png` verifies that long multiline copy
  grows the card instead of clipping. Neither bitmap substitutes for the matching
  live system-accessibility pass.
- Live HUD evidence must show an immediate first frame, a short entry and phase
  crossfade, and the opacity-only structural alternative under Reduce Motion. It
  must also prove that the panel does not activate Fixer or change the external
  focus owner.
- Motion is approved only from a real run or a screen recording with the initial
  state, transition, and settled state visible. Editor replacement uses a brief
  ease-in/ease-out dissolve (`0.08 + 0.12 s`) over stationary panel and masthead
  surfaces, with no lateral movement or light sweep. Controls use `0.18 s`. A separate
  pointer layer uses `0.11 s` hover and `0.09 s` press transitions without
  geometry changes. A separate Reduce Motion pass must show no structural or
  press displacement. Rapid Action switching and focus retention are mandatory
  live acceptance checks.

Reduce Motion is verified through policy/unit coverage, the directly injected
HUD policy render, and an obligatory live pass. SwiftUI exposes the system
environment as read-only in the supported macOS 13 hosted-render path, so the
generated bitmap proves the HUD's static branch, not that macOS delivered the
user's setting to the running app.

The large-text HUD render deterministically proves intrinsic growth for long copy.
Actual Increased Text and Dynamic Type behavior remains live/manual accessibility
evidence: the supported macOS 13 hosted-render path can ignore a synthetic size
category, and a bitmap cannot establish keyboard focus or VoiceOver quality.

The automated layout checks may enforce bounded geometry and control semantics,
such as the workspace size matrix, `292 pt` sidebar target, the `40 pt` sidebar /
`100 pt` masthead split with `28 pt` titlebar controls, Prompt-first vertical order,
one canonical Enabled state, a maximum splash tilt of six degrees, and transparent
non-activating panel/window configuration. These checks complement visual review.
They do not replace it.

The settled-splash render test validates transparent corners and bounded
opaque/dark/yellow/luminance evidence from the complete composition. These
content checks are deliberately broader than a pixel-golden comparison, so a
deliberate rendering improvement does not require rewriting a bitmap baseline.

## Updating this reference

Only update a reference image when the design direction changed intentionally. In the same commit:

1. explain the decision in `VISUAL_SPEC.md`;
2. replace only the affected reference files;
3. regenerate `manifest.json`;
4. run the native rendering suite on macOS;
5. inspect the affected state at full size;
6. record any deliberate divergence from the original prototype.
