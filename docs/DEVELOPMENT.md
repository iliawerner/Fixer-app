# Development

Everything a contributor needs to build Fixer and find their way around the code.

## Requirements

- **Xcode 26+** — the app icon is an Icon Composer `fixer.icon`, which needs a
  recent Xcode. (The app itself runs on **macOS 13+**.)
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — the Xcode project is
  generated from [`project.yml`](../project.yml), which is the source of truth.
  Install with `brew install xcodegen`.

## Build & run

```sh
./scripts/generate-project.sh
xcodebuild -project Fixer.xcodeproj -scheme Fixer -configuration Release \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile build
```

The product builds as `fixer.app`. `Fixer.xcodeproj` is generated and **git-ignored**
(project.yml is the source of truth), so run `./scripts/generate-project.sh` right
after cloning; then either use the `xcodebuild` line above or open
`Fixer.xcodeproj` in Xcode and press **Run**.

The tracked `Package.resolved` pins reviewed dependency revisions. The generation
script copies it into the workspace because the `.xcodeproj` itself is not tracked.
CI additionally passes `-disableAutomaticPackageResolution` and
`-onlyUsePackageVersionsFromResolvedFile`, preventing a package range from silently
selecting a different revision.

## Design review

Use [`../design-reference/README.md`](../design-reference/README.md) before changing
the workspace, provider setup, menu, run HUD, starter library, or splash. The
prototype PNGs preserve visual direction but are not a feature specification;
[`VISUAL_SPEC.md`](../design-reference/VISUAL_SPEC.md) records which details are
locked, native-adaptable, or explicitly rejected. Run the macOS render command and
hands-on checks in [`QA-CHECKLIST.md`](../design-reference/QA-CHECKLIST.md) before
approving visual changes.

The workspace must remain a standard titled AppKit window. AppKit supplies the
running system's corner shape, shadow, resize behavior, and traffic lights. Do not
replace that chrome with a SwiftUI mask. On macOS 26, inspect the live window in
addition to the hosted PNG renders because those PNGs do not contain system chrome.
The current window contract is `820 × 720` by default, `760 × 620` minimum, with
a `292 pt` sidebar and a leading-aligned editor column capped at `480 pt`. Its
natural total width is `817 pt`; the `820 pt` default leaves no decorative trailing
strip. Window-frame restoration uses the `FixerV4NarrowWorkspace` autosave
namespace so an older wide frame cannot override this compact first launch. The
standard AppKit toolbar is itemless and uses
`.unifiedCompact`; its traffic lights and sidebar controls share the `40 pt`
titlebar's `y = 20 pt` axis. The sidebar has no visible **Actions** or **New**
titlebar text: an icon-only `28 × 28 pt` **+** starts at `x = 88 pt` and opens
exactly **Blank Action** and **From Starter Library**. A separate trailing Setup
icon remains available, but displays issue status only while setup is incomplete.
There is no bottom sidebar footer. The detail side begins with an exactly `100 pt`
yellow masthead: its large editable Action name sits near the bottom-left and its
`28 × 28 pt` `…` menu at the top-right. The sidebar and masthead own distinct
rules at `40 pt` and `100 pt`; do not add a parent rule that pretends they align.

Pointer-state review is also mandatory. The icon-only **+** and Setup controls
expose hover, press, keyboard focus, and clear tooltip/accessibility names. Rows,
the Action `…` menu, Output, Enabled, **Custom Model ID**, and primary/secondary
buttons all need coherent hover feedback. Shared hover and press durations are
`0.11 s` and `0.09 s`. These states must not change control geometry, and Reduce
Motion must remove spatial press transforms.

## Naming: `Fixer`, `fixer`, and the legacy `GeminiMacros` id

The project, target, and scheme are named **Fixer**; the built product is
**fixer.app** (`PRODUCT_NAME: fixer`). The **bundle id**, however, stays
`com.geminimacros.GeminiMacros`. The app originally shipped as *GeminiMacros*, and
the bundle id keys the saved API key (Keychain) and saved prompts (UserDefaults);
changing it would sign existing users out and drop their prompts. So it's pinned
explicitly in `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`) rather than derived from
the target name. Two string literals must never be renamed for the same reason:
that bundle id, and the Keychain service string (`com.geminimacros.apikey` in
`KeychainManager`).

## How it works

Text Actions retain the original short pipeline:

```
hotkey (HotkeyCoordinator)
  → resolve the live action by id
  → ActionRunner.run(action:)
      → ClipboardManager.copySelection()      (synthetic ⌘C, immediately restores clipboard)
      → build prompt: substitute {text}
      → GeminiAPI.generateContent(model:prompt:)
      → ClipboardManager.paste(result)        (synthetic ⌘V, then restores clipboard)
      → HUD shows success / error
```

Everything runs on the main actor except the blocking pasteboard/keystroke work,
which is confined to a dedicated serial queue in `ClipboardManager`. `ActionRunner`
guards against overlapping triggers with an `isProcessing` latch and always restores
the clipboard, even on failure.

Voice uses the same process-wide latch and HUD, but adds one bounded recording
stage:

```text
voice shortcut (HotkeyCoordinator key-down / key-up)
  → VoiceActionRunner captures the app, exact focused AX element, and caret/range
  → VoiceAudioCapture records in memory (16 kHz mono WAV, maximum five minutes)
  → GeminiVoiceTranscriber sends inline audio to models/gemini-3.7-flash
  → built-in Dictation: use transcript directly
    ordinary {voice} Action: substitute {voice}/{text}, then run its text model
  → exact target still focused: paste
    changed or unverifiable target: leave result on clipboard for manual paste
```

The permanent built-in **Dictation** Action is normalized to the first row on
every load and cannot be renamed, duplicated, deleted, or moved. It owns the one
global voice gesture: **Press again** starts and stops on two Shortcut presses;
**Hold** records from key-down to key-up. Ordinary Actions opt into the same flow
by putting `{voice}` in their Prompt, optionally alongside `{text}`.

Microphone authorization is lazy: it is requested only when a voice Shortcut is
actually invoked and is not counted by `SetupReadiness`. Capture and the encoded
WAV remain in memory; Fixer writes no audio or transcript history. Audio is sent
to Google Gemini, so it leaves the Mac. The implementation deliberately does not
use `SFSpeechRecognizer` or `DictationTranscriber`.

Escape is monitored only before upload and guarantees that no audio is sent on
that cancellation path. Once Transcribing begins, Escape is no longer offered.
Automatic voice delivery is also fail-closed: the original running application,
exact focused Accessibility element, and selected-text range or caret must all
still match. If any cannot be verified, `copyText(_:)` leaves the result on the
clipboard and the HUD asks the user to return and paste.

The run HUD is one persistent, non-activating, click-through compact warm-neutral
status card.
It appears immediately and uses only a short entry and phase crossfade.
`HUDPresentationModel` changes working/success/error content inside the same
host; do not recreate or activate the panel between phases. Omit a visible Fixer
wordmark and all repair metaphors. Working/busy shows the Action name once with a
standard progress state. Success says `Text replaced` or `Text appended` with a
standard check. Error gives a concrete reason and next step with a standard
error symbol. Reduce Motion keeps structural transitions opacity-only.
Voice phases reuse that same panel and geometry. Listening replaces the generic
spinner with measured microphone-level bars; preparing, finishing, transcribing,
applying, inserted, copied, and cancelled remain direct text/glyph state changes
inside the persistent host.

### File map

| File | Responsibility |
|------|----------------|
| `App.swift` | `MenuBarExtra` + `AppDelegate` lifecycle, first-run routing, hotkey startup, and permission request |
| `WorkspaceWindowFactory.swift`, `WorkspaceWindowMetrics.swift` | Standard titled workspace window, system-owned chrome, size bounds, and frame restoration |
| `AppState.swift` | Observable app state (`isProcessing`, permission, last error) |
| `Models.swift` | `MacroAction`, permanent Dictation identity, voice gesture, and tolerant Codable persistence |
| `SettingsManager.swift` | Owns and normalizes the action list; persists to UserDefaults; protects Dictation; drives the hotkey lifecycle |
| `HotkeyCoordinator.swift` | Registers key-down/key-up handlers, freezes one Action per physical press, and filters key repeat |
| `ActionRunner.swift` | Orchestrates copy → Gemini → paste, with the re-entrancy latch and guaranteed clipboard restore |
| `VoiceActionRunner.swift` | Orchestrates target capture, recording, transcription, optional Action processing, and fail-closed delivery |
| `VoiceAudioCapture.swift`, `LockedVoicePCMBuffer.swift`, `WAVAudioEncoder.swift`, `AudioLevelMeter.swift` | In-memory microphone capture, five-minute bound, 16 kHz mono encoding, and real level telemetry |
| `Microphone*.swift` | Lazy authorization seam, policy, statuses, and user-facing capture errors |
| `VoiceInsertionTarget.swift`, `VoiceEscapeMonitor.swift` | Exact app/AX-element/caret verification and pre-upload Escape cancellation |
| `ClipboardManager.swift` | Serial-queue pasteboard + synthetic ⌘C/⌘V, modifier-aware restore, and changed-target copy fallback |
| `GeminiAPI.swift`, `GeminiVoiceTranscriber.swift`, `VoiceTranscribing.swift`, `VoiceAudio.swift` | Gemini text/inline-audio REST calls and provider-neutral transcript boundary |
| `KeychainManager.swift` | API-key storage in the Keychain |
| `ProviderSetupController.swift` | Cancellable provider validation tied to the current Keychain credential |
| `PermissionsManager.swift` | Accessibility permission checks and the Settings deep-link |
| `SettingsView.swift`, `ActionLibraryTitlebarRow.swift`, `ActionLibraryRow.swift`, `ProviderSetupSheet.swift` | Edge-to-edge Actions workspace, add/library menu, titlebar Setup entry, and setup flow |
| `ActionEditor.swift`, `ActionEditor*.swift`, `Dictation*.swift`, `StarterLibrarySheet.swift` | Live-bound ordinary editor, protected Dictation editor, and starter library |
| `V2Support.swift` | Pure activation/readiness policies, action filtering, feedback copy/timing, and HUD geometry |
| `HUD.swift`, `HUDManager.swift`, `HUDPanel.swift`, `HUDPresentationModel.swift`, `HUDVisuals.swift`, `HUDVoiceLevelIndicator.swift` | Persistent passive warm-neutral status card, non-activating panel, standard symbols, voice levels, and semantic transitions |
| `SplashPolicy.swift`, `SplashWindowController.swift`, `SplashMotion.swift`, `SplashView.swift`, `SplashCardView.swift` | First-launch policy, transparent window, motion model, and layered card |
| `StarterLibrary.swift` | Ready-made prompts offered in the Library |
| `FixerTheme.swift`, `FixerComponents.swift`, `FixerHoverButtonStyle.swift`, `WorkspaceChromeMetrics.swift` | Signal-paper tokens, shared UI components, pointer states, and shared workspace chrome metrics |
| `ActionEditorOutputControl.swift`, `ActionEditorEnabledControl.swift` | Warm custom Output selector and compact accessible ToggleStyle |

## Interface vocabulary

Fixer uses plain product language. These terms should stay consistent in UI copy,
documentation, and accessibility labels:

| Term | Means |
|------|-------|
| Actions | saved AI transformations |
| Dictation | permanent built-in voice Action that inserts the transcript directly |
| Shortcut | the global keyboard shortcut assigned to an action |
| Prompt | the instruction sent to Gemini; `{text}` is replaced with the selection and `{voice}` with one recorded transcript |
| Output | replace the selection or append the result |
| Model | the Gemini model used for an action |
| Result sent | the action completed and Fixer posted the paste keystroke |

## Splash identity

The first-launch animation is native SwiftUI, not a web view. Five approved PNG
layers live in `Assets.xcassets` (`SplashPaper`, `SplashSun`, `SplashLandscape`,
`SplashCharacter`, and `SplashOverlay`). Keep the overlay fixed relative to the
card so the title and technical signs stay crisp while the scene layers move at
different depths. `SplashPolicy` owns the versioned UserDefaults key. The menu-bar
command **Show Splash…** replays the animation without changing that key.
