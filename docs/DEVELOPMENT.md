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
icon displays issue status only while setup is incomplete. A clock beside it opens
History, which remains available while an operation is processing.
There is no bottom sidebar footer. The detail side begins with an exactly `100 pt`
themed masthead (yellow in Light, dark ochre in Dark): its large editable Action name sits near the bottom-left and its
`28 × 28 pt` `…` menu at the top-right. The sidebar and masthead own distinct
rules at `40 pt` and `100 pt`; do not add a parent rule that pretends they align.

Pointer-state review is also mandatory. The icon-only **+**, Setup, and History controls
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

Text and voice operations share `AppState.isProcessing`, local History, and the
same delivery policy. Read [`ARCHITECTURE.md`](ARCHITECTURE.md) for detailed
ownership and persistence contracts.

```text
Text shortcut
  -> capture source app/AX element/range and snapshot the Action
  -> read verified original through Accessibility; begin History with that source
  -> save prompt -> Gemini -> save result
  -> shared ResultDeliveryService -> save delivery/status -> release latch

Voice shortcut
  -> begin History and register recovery CAF path
  -> capture bounded PCM and incrementally persist source CAF
  -> stop and encode off main actor -> save WAV
  -> transcribe -> save transcript and actual transcription model
  -> optional Action generation -> save result -> shared delivery
```

Neither runner uses synthetic Command-C to obtain source text. Required selection
must be readable from the original AX element/range; otherwise the operation
fails before sending unrelated clipboard data. Actions are immutable snapshots
for each run. Plain Dictation also archives a safely readable original selection.

Shared delivery verifies the original application, exact AX element, selection or
caret, and available text content. It revalidates immediately before posting
Command-V and never refocuses another application. If the target changed or
cannot be verified, the result stays in History and is copied by default. Settings
can disable that fallback copy. Synthetic insertion cannot be atomic across apps:
a successful dispatch is reported as **Result sent**, and History retains the
result even if the destination never consumes the key.

Pasteboard backup/restoration and modifier waiting use a dedicated serial queue;
source capture, state, and orchestration use the main actor. WAV encoding and
saved-audio decoding run off the main actor. The tap writes bounded PCM and a
preallocated ring; only the ordered background writer performs source-file I/O.

The permanent built-in **Dictation** Action stays first and cannot be renamed,
duplicated, deleted, or moved. It owns the global **Press again** / **Hold** voice
gesture. Ordinary Actions opt in with `{voice}`, optionally beside `{text}`.
Microphone permission is requested only on voice invocation and is absent from
`SetupReadiness`. Recognition uses Gemini; neither `SFSpeechRecognizer` nor
`DictationTranscriber` is used.

Audio is retained locally as well as sent to Gemini for recognition. The five-minute
capture bound also applies to loading audio for retry. A streaming CAF's written
prefix can be recovered without normal finalization; source writing flushes about
every 100 ms from a four-second ring. A crash can lose final queued/unflushed
frames, and file failure or overflow is surfaced rather than hidden. Escape before
upload drains local work, keeps the captured audio in cancelled History, and never
calls the provider. Escape is no longer offered once transcription begins.

History stores independent, atomic JSON records and private audio files. Default
retention is 30 days; failed/interrupted records stay until explicitly deleted.
Active entries cannot be deleted. Retry creates a new record from the saved Action,
reuses a transcript when available, and never resurrects an old paste target.
Completed results can be copied directly without a new provider request. Library
corruption recovery is independent: Settings keeps good/raw damaged snapshots and
salvages readable Actions without silently replacing the library with defaults.

The HUD remains one persistent, passive, non-activating, click-through panel.
`HUDPresentationModel` changes semantic phases without recreating it. It reports
**Result sent**, **Copied — also in History**, **Saved to History**, or a concrete
failure. Listening uses measured microphone-level bars. Reduce Motion keeps
structural transitions opacity-only.

### File map

| File | Responsibility |
|------|----------------|
| `App.swift` | `MenuBarExtra` + `AppDelegate` lifecycle, first-run routing, hotkey startup, and permission request |
| `WorkspaceWindowFactory.swift`, `WorkspaceWindowMetrics.swift` | Standard titled workspace window, system-owned chrome, size bounds, and frame restoration |
| `AppState.swift` | Observable app state (`isProcessing`, permission, last error) |
| `Models.swift` | `MacroAction`, permanent Dictation identity, voice gesture, and tolerant Codable persistence |
| `SettingsManager.swift` | Owns and normalizes the action list; persists to UserDefaults; protects Dictation; drives the hotkey lifecycle |
| `HotkeyCoordinator.swift` | Registers key-down/key-up handlers, freezes one Action per physical press, and filters key repeat |
| `ActionRunner.swift` | AX source → durable prompt/result → Gemini → shared safe delivery, with the single-flight latch |
| `VoiceActionRunner.swift` | Orchestrates target capture, recording, transcription, optional Action processing, and fail-closed delivery |
| `VoiceAudioCapture.swift`, `LockedVoicePCMBuffer.swift`, `RecoverableVoiceRecording.swift`, `WAVAudioEncoder.swift`, `AudioLevelMeter.swift` | Bounded microphone capture, incremental CAF recovery, background 16 kHz mono encoding, and level telemetry |
| `Microphone*.swift` | Lazy authorization seam, policy, statuses, and user-facing capture errors |
| `VoiceInsertionTarget.swift`, `VoiceEscapeMonitor.swift` | Exact app/AX-element/caret verification and pre-upload Escape cancellation |
| `ClipboardManager.swift`, `ResultDeliveryService.swift` | Clipboard staging/restoration, checked synthetic paste, and preference-controlled fallback |
| `HistoryEntry.swift`, `HistoryStore.swift`, `HistoryPreferences.swift`, `HistoryMaintenance.swift` | Per-entry local persistence, recovery, preferences, and retention |
| `HistoryRetryController.swift`, `HistoryAudioLoader.swift` | Saved-stage retry with no old paste target; bounded CAF/WAV decoding |
| `HistoryView.swift`, `HistoryDetailView.swift`, `HistoryWindowFactory.swift` | History list/detail, audio playback/export, and a window available during processing |
| `PersistenceEnvironment.swift`, `IsolatedQAContext.swift` | Isolated preferences/history and inert system/provider boundaries for live QA |
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

Appearance is stored separately from Actions by `AppearancePreferences`.
`AppearanceController` applies Light/Dark as an `NSApplication.appearance`
override; Follow System sets it to `nil`. Windows must inherit that appearance.
`FixerTheme` uses dynamic named AppKit colors so native controls and SwiftUI
content update together. Keep foreground-on-accent, selection, and divider roles
separate from body text. See [APPEARANCE-TESTING.md](APPEARANCE-TESTING.md).

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
| Result sent | Fixer dispatched the paste keystroke; this does not confirm insertion |
| History | locally saved originals, results, transcripts, recordings, and failures |
| Copy result when target changes | preference controlling automatic fallback clipboard writes |

## Splash identity

The first-launch animation is native SwiftUI, not a web view. Five approved PNG
layers live in `Assets.xcassets` (`SplashPaper`, `SplashSun`, `SplashLandscape`,
`SplashCharacter`, and `SplashOverlay`). Keep the overlay fixed relative to the
card so the title and technical signs stay crisp while the scene layers move at
different depths. `SplashPolicy` owns the versioned UserDefaults key. The menu-bar
command **Show Splash…** replays the animation without changing that key.

## Tests and isolated live QA

Regenerate the project after adding files. Run hosted tests with the locked package
revisions and an explicit output directory:

```sh
./scripts/generate-project.sh
xcodebuild -project Fixer.xcodeproj -scheme Fixer -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/fixer-dev-tests \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile test
```

Hosted startup skips real hotkeys, permission prompts, and window activation.
`PersistenceEnvironment` gives default test singletons temporary History and an
isolated UserDefaults suite. Unit tests should still inject their own store,
AppState, credential/provider seams, inert target/keystrokes, and named pasteboard.
Never use a real microphone, Keychain credential, network request, or the general
clipboard in a lifecycle test.

`VoiceHistoryLifecycleTests` checks audio before transcription, transcript/prompt
before generation, result before delivery, failure recovery, and cancellation with
no upload. `VoiceAudioCaptureTests` covers permission/encoding generation races.
`HistoryAudioLoaderTests` exercises unfinished CAF, WAV, overflow, and invalid
recordings. Other History/store/retry/delivery suites verify corruption isolation,
retention, active deletion protection, and the clipboard preference. These checks
do not prove a physical microphone or another application's paste behavior.

For a manual History/workspace pass, launch the built app with an explicit
private data directory:

```sh
open -n --env FIXER_DATA_DIR=/tmp/fixer-live-qa \
  /tmp/fixer-dev-tests/Build/Products/Debug/fixer.app
```

This mode uses isolated History/preferences, in-memory credentials, inert shortcuts,
and offline retry responses. It does not register hotkeys, read the user's API key,
send provider requests, or paste retry results. Explicit History Copy remains a
real user command; use disposable test text. Inspect the titlebar clock, History
while busy, audio/error details, preference persistence, deletion protection, and
playback/export using fixture recordings. A live microphone/provider/paste check
is separate and must be intentional.
