# Fixer architecture

This document describes the current native macOS application, its ownership
boundaries, and the invariants that must survive refactors. It is intentionally
about implementation contracts rather than visual direction; use
[`../design-reference/README.md`](../design-reference/README.md) for design work
and [`DEVELOPMENT.md`](DEVELOPMENT.md) for build commands.

## Product shape

Fixer is a menu-bar-only (`LSUIElement`) SwiftUI application with small AppKit
bridges for windows, the pasteboard, synthetic keyboard events, and macOS
permissions. It has no local server or background daemon.

The deployment target is macOS 13. Shared UI state therefore uses
`ObservableObject`/`@Published`; adopting newer Observation APIs requires an
intentional deployment-target decision.

The generated Xcode project is not a source of truth. `project.yml` defines the
targets and dependencies, and XcodeGen includes `Sources` and `Tests`, excluding sync-conflict copies.
The project-generation script rejects conflict files before creating a project.

## End-to-end flows

### Application startup

```text
FixerApp
  -> AppDelegate.applicationDidFinishLaunching
     -> skip side effects when hosted by XCTest
     -> register bundled fonts
     -> initialize SettingsManager.shared
        -> decode and normalize actions from UserDefaults
        -> pin exactly one permanent Dictation Action first
        -> recover readable Actions or the last good backup after corruption
        -> seed defaults only when no saved library exists
     -> load History; mark unfinished records interrupted
     -> prune eligible old history using the retention preference
     -> HotkeyCoordinator.bindAll()
     -> refresh the Accessibility snapshot
     -> start permission polling
     -> show the first-run splash or the Actions workspace
```

`AppDelegate` keeps the settings `NSWindow` alive after it closes because reopening
a released cached AppKit window is unsafe. The splash instead has a short-lived
`SplashWindowController` and is released when dismissed. On first launch, the
Accessibility prompt is deferred until after the splash so the system sheet does
not cover the identity sequence.

`WorkspaceWindowFactory` creates a standard titled AppKit window with a full-size
content view. AppKit owns the corner shape, shadow, resize affordance, and traffic
lights. The window hides its title, makes the titlebar transparent, removes the
AppKit separator, and installs an itemless `.unifiedCompact` toolbar. `SettingsView`
extends content through the top safe area so its controls share the titlebar plane
instead of leaving an empty strip. The window opens at `820 × 720`, allows
`760 × 620`, and uses a `292 pt` sidebar. A `480 pt` maximum editor column plus
the sidebar, divider, and detail insets produces a natural total width of `817 pt`.
Frame restoration uses the `FixerV4NarrowWorkspace` autosave namespace so frames
from the older wide layout are not restored. `WorkspaceChromeMetrics` fixes one
`40 pt` native sidebar titlebar with a `20 pt` control axis and one exactly
`100 pt` yellow detail masthead. The sidebar shows no visible **Actions** or
**New** titlebar words: its icon-only `28 × 28 pt` add menu starts at `x = 88 pt`
and contains **Blank Action** and **From Starter Library**. One separate trailing
Setup control derives its incomplete issue treatment from `SetupReadiness`.
A clock control beside it opens the separate History window. No bottom footer duplicates these entry points. The masthead
places the large editable Action name near the bottom-left and a `28 × 28 pt`
options menu at the top-right. Sidebar and masthead draw distinct bottom rules at
`40 pt` and `100 pt`; no parent separator claims that the surfaces share a baseline.

`FixerHoverButtonStyle` and the feature-specific custom controls share stationary
pointer feedback. Hover lasts `0.11 s`, press lasts `0.09 s`, and neither changes
layout geometry. Reduce Motion preserves the visual state distinction but removes
spatial press transforms. This contract covers Action rows, the icon-only add and
Setup and History controls, the Action `…` menu, Output, Enabled,
**Custom Model ID**, and primary/secondary buttons.

### Editing an action

```text
SettingsView / ActionDetailPane
  -> mutate SettingsManager.actions
     -> @Published array didSet
        -> JSONEncoder
        -> UserDefaults["savedActions"]
  -> enable/disable/delete/create operations
     -> HotkeyCoordinator updates KeyboardShortcuts state
```

`SettingsManager.actions` is the source of truth for saved actions. The editor
uses bindings into that array, so edits to value-type `MacroAction` elements
still pass through the array observer and save immediately.

`MacroAction.kind` separates user-authored text Actions from the permanent
Dictation Action. Load normalization repairs the built-in Action's protected
identity and fields, keeps its Enabled and activation values, removes duplicate
built-ins, and preserves user text Actions. Dictation cannot be renamed,
duplicated, deleted, or moved. Its special one-column editor contains Shortcut,
the global **Press again** / **Hold** voice gesture, recognition/privacy copy,
and Enabled; it intentionally has no Prompt, Output, or Model controls. Ordinary
Prompt toolbars offer `{voice}` next to `{text}`.

KeyboardShortcuts does not publish recorder changes to SwiftUI. The workspace's
`shortcutRevision` value is the explicit invalidation bridge that makes shortcut
labels, readiness, and conflict checks recalculate after recording.

### Provider setup

```text
SettingsView owns ProviderSetupController as StateObject
  -> API-key edit
     -> KeychainManager saves or removes the credential
  -> model refresh
     -> GeminiAPI.fetchModels()
     -> publish models only if the credential revision still matches
```

`ProviderSetupController` owns transient setup state, not the credential itself.
Every key change invalidates the in-flight model request. A response is accepted
only when its captured key value and revision still match current state, so a
stale request cannot validate a changed or deleted credential.

### Running an action

```text
KeyboardShortcuts key-up handler
  -> HotkeyCoordinator resolves the current Action by UUID
  -> ActionRunner.run(action:)
     -> claim AppState's process-wide latch and capture the original AX target
     -> verify Accessibility and capture selected text from that AX field/range
     -> begin History with Action/app/source; keep source in memory if save fails
     -> persist the substituted prompt
     -> GeminiAPI.generateContent(model:prompt:)
     -> compose Replace / Append output
     -> persist result before any delivery
     -> ResultDeliveryService.deliver(_:to:)
        -> verifiable original target: stage clipboard, revalidate, post Command-V
        -> changed/unverifiable: copy only if fallback copy preference is enabled
     -> persist delivery/status, show feedback, release AppState
```

Selection capture is Accessibility-only. A pasteboard write observed after
synthetic Command-C cannot be attributed safely to the source application, so
neither runner uses it as source text. Unreadable required text produces a failed
history entry before a provider request. The saved Action is a value snapshot;
edits made while the request runs affect later invocations.

A nonempty response stopped by the model's token limit is an incomplete result,
not successful generation. Its partial text is retained in the failed history
entry without replacing the user's text.

### Running Dictation and `{voice}` Actions

```text
VoiceActionRunner
  -> capture Action, app, AX target, and verified original selection synchronously
  -> begin History with immutable source and claim the shared run latch
  -> register a recovery CAF path before starting the microphone
  -> VoiceAudioCapture requests permission lazily and starts AVAudioEngine
     -> locked, bounded mono PCM buffer supplies the eventual encoder
     -> preallocated ring sends source frames to an ordered background CAF writer
     -> second press / key-up / five-minute cap freezes recording
  -> WAVAudioEncoder builds a 16 kHz mono WAV off the main actor
  -> atomically persist the WAV, then replace the CAF reference
  -> persist transcription stage/model; GeminiVoiceTranscriber recognizes audio
  -> persist the transcript before any additional request
  -> Dictation uses transcript; ordinary Action substitutes {voice} / {text}
     -> persist prompt and run the Action's selected text model
  -> persist result; shared ResultDeliveryService decides paste/copy/history-only
  -> persist delivery/status and release the run latch
```

**Press again** starts/stops on Shortcut releases; **Hold** starts on key-down and
stops on key-up. The global gesture applies to every Action containing `{voice}`.
The coordinator freezes one Action per physical press and filters keyboard repeat.

Required `{text}` and nonempty/unverifiable Append selections must be readable
from the original AX element/range before recording. A collapsed caret needs no
Append source. Any safely readable selection is archived, including text replaced
by plain Dictation. No synthetic Copy fallback is used.

Escape cancels only before upload. It stops the tap, drains the source writer,
keeps the CAF in a cancelled history entry, and waits for local encoding to drain
before releasing the run latch. That path never calls the transcriber. Once
Transcribing begins, audio may already have left the Mac and Escape is no longer
offered. Permission and encoding completions carry generation identities; an old
completion cannot change a later recording or invoke its callbacks.

### History and retry

`HistoryStore` owns one JSON record per operation and its audio files under
`Application Support/com.geminimacros.GeminiMacros/History/<UUID>/`. Records retain
the Action snapshot, original text, transcript, prompt, result (including partial
output), actual transcription model, stage, delivery, timestamps, and errors.
Each record is replaced atomically. A damaged record remains on disk and is
reported without preventing other records from loading. Runs still marked
`running` after a restart become `interrupted`.

Source is persisted before the next risky stage: text before generation, CAF
metadata before capture, WAV before transcription, transcript before generation,
and result before delivery. An I/O error is visible; changed in-memory entries
remain available even if a write failed. Durability is not promised after failed
storage. Private directories use mode `0700`; record/audio files use `0600`.

The recoverable CAF uses an unknown data length, so its written prefix is readable
without normal finalization. A serial writer flushes approximately every 100 ms
from a four-second preallocated ring. A crash can lose queued or unflushed final
frames; under disk backlog that can be longer than the normal flush interval.
Queue overflow or file errors fail capture visibly while preserving the available
prefix. This protects against ordinary provider/encoding failures and provides
partial recovery after a crash, not a guarantee of every recorded sample.

History opens from the titlebar clock or app menu, including during processing.
It provides original/result/transcript copying, error details, audio playback and
export, retry, individual deletion, and confirmed clearing. Active entries cannot
be deleted. Local retention defaults to 30 days (7/30/90/forever in Settings);
startup pruning removes only expired succeeded/cancelled runs. Failed/interrupted
runs remain until explicitly deleted. There is no separate disk-size quota.

`HistoryRetryController` creates a new record from the saved Action/source and
shares the same process-wide latch. An existing transcript skips transcription;
otherwise `HistoryAudioLoader` decodes a saved CAF/WAV off the main actor and
bounds it to five minutes. Retry never reuses an old AX target or automatically
pastes into a field. It uses the copy preference or leaves the result in History.
A completed result is also directly copyable without making a new model request.

The history copy preference defaults to enabled. Turning it off leaves changed
or unverifiable targets untouched and keeps their result in History. Explicit
Copy commands remain available. History is local storage; provider requests still
send the requested text/audio to Gemini.

`HUDManager` owns one passive, non-activating panel. Its persistent presentation
model changes phase without recreating the window. `Result sent` means the paste
keystroke was dispatched; it does not confirm that another application consumed
it. Other delivery outcomes say `Copied — also in History` or `Saved to History`.
Failures report a concrete reason, and the history entry retains available source.
Listening shows measured microphone levels. Reduce Motion keeps transitions
opacity-only.

## State ownership and isolation

| State | Owner | Lifetime | Isolation |
|---|---|---|---|
| Saved actions | `SettingsManager.shared` | Process plus UserDefaults persistence | Main actor |
| Current run, permission snapshot, last error | `AppState.shared` | Process | Main actor |
| Registered shortcut handlers | `HotkeyCoordinator.shared` | Process | Main actor |
| Active voice session and immutable target snapshot | `VoiceActionRunner.shared` | One voice run | Main actor |
| Microphone engine and PCM/WAV payload | `VoiceAudioCapture` | One recording | Main actor lifecycle; locked tap buffer; detached encoder |
| Recoverable source audio writer | `RecoverableVoiceRecording` | Capture through stop/cancel | Preallocated ring and lock; serial background file I/O |
| Operation records and audio paths | `HistoryStore.shared` | Persistent local history | Main actor; atomic per-entry files |
| Clipboard fallback and retention preferences | `HistoryPreferences.shared` | UserDefaults persistence | Main actor |
| History retries | `HistoryRetryController.shared` | One retry | Main actor orchestration; detached audio loader |
| Provider setup and model-loading state | `ProviderSetupController` owned by `SettingsView` | Workspace instance | Main actor |
| Settings window | `AppDelegate` | Process | AppKit/main thread |
| Splash window | `SplashWindowController` | Visible splash session | AppKit/main thread |
| HUD panel and dismissal task | `HUDManager.shared` | Process | Main actor |
| Pasteboard backup and timing state | `ClipboardManager.shared` | One serialized operation at a time | Dedicated serial queue |
| Gemini transport | `GeminiAPI.shared` | Process | Stateless client; injected session/key provider |

`ActionRunner`, `VoiceActionRunner`, and `HistoryRetryController` use
`AppState.isProcessing` as one shared single-flight latch. Each guard and assignment occurs without an `await` on the
main actor, so two shortcut events cannot both start a run. Clipboard work uses a dedicated serial dispatch queue
because its waits are blocking and must not occupy Swift concurrency's
cooperative executor.

## Window and focus invariants

Fixer reads source text through Accessibility and uses synthetic Command-V for
optional delivery. The external target must remain verifiable immediately before
that event is posted.

- The run HUD is a borderless, non-activating `NSPanel` that cannot become key or
  main, ignores mouse input, and never calls `NSApp.activate`.
- The workspace is a standard titled `NSWindow` with `.fullSizeContentView`.
  AppKit owns its corner radius and system controls. No custom workspace mask or
  hard-coded corner radius may replace the running macOS shape.
- The workspace title is hidden and its titlebar is transparent. The AppKit
  separator is disabled. Hosted content reaches the top edge while the system
  traffic lights stay visible.
- An itemless `.unifiedCompact` toolbar establishes the `40 pt` titlebar plane.
  Traffic lights, add, and Setup controls share its `20 pt` control axis in the
  sidebar. The detail masthead is independently fixed at `100 pt`.
- The workspace geometry contract is `820 × 720` default, `760 × 620` minimum,
  `817 pt` natural total width, a `292 pt` sidebar, and a leading-aligned editor
  column capped at `480 pt`. The icon-only `28 × 28 pt` add control starts at
  `x = 88 pt`; the Action options menu is also `28 × 28 pt`. No visible
  **Actions** or **New** words occupy the titlebar.
- The add control opens exactly **Blank Action** and **From Starter Library**.
  Setup exists once beside the History clock, and only incomplete Setup carries
  issue status. There is no bottom sidebar footer.
- The sidebar rule ends at `40 pt`; the detail masthead rule ends at `100 pt`.
  Neither is extended into a fake shared separator.
- Interactive state changes never alter layout geometry. Under Reduce Motion,
  pressed controls do not translate or scale.
- Workspace and splash activation is blocked while an Action is processing.
- History remains accessible during processing. Opening it can change the target;
  the shared delivery check then chooses clipboard/history fallback.
- The menu-bar icon may update, but that update must not activate Fixer.

Both runners use `SystemVoiceInsertionTarget`. It records the running application,
PID, focused AX element, selection/caret range, selected text, and an available
fingerprint of the field value. Delivery checks identity, range, and content;
unavailable evidence fails closed. No operation reactivates the original window,
restores selection, or steals focus to force delivery.

AX queries and posting a synthetic key are separate OS operations. Another process
can change focus or content during them, and receiving a key is not an
acknowledgment of insertion. The checks reduce misdelivery risk; they do not make
cross-application insertion atomic. History remains the durable result source.

## Clipboard contract

Production source capture does not touch the general pasteboard. Synthetic Copy
and unchecked-paste entry points have been removed.
`ClipboardManager.paste(_:ifTargetCurrent:)` first validates the target, then
waits for shortcut modifiers on its queue, snapshots the current clipboard, and
stages the result. It validates again on the main actor immediately before
posting Command-V, with no actor suspension between that check and the event.
If validation fails, it restores the staged backup conditionally and does not
post a key.

After posting, the queue allows a settle interval and restores the backup only
if `changeCount` still matches Fixer's write. A user Copy during a provider request
therefore becomes the new paste-time backup, and a later write wins over restore.
The settle interval is a heuristic; a slow application may not have consumed the
result before restoration. A `pasteSent` delivery records only the dispatched key.

For changed/unverifiable targets, `ResultDeliveryService` calls `copyText(_:)`
only when `copyResultWhenTargetChanges` is enabled. With it disabled, fallback
delivery does not write the clipboard. An explicit History Copy command is a
separate user action. Pasteboard operations remain best-effort coordination:
`changeCount` is not an atomic lock against external writes.

## Persistence identities

The following identifiers are part of compatibility. Do not rename them without
an explicit migration and regression tests.

| Identity | Current value | Purpose |
|---|---|---|
| Application bundle id | `com.geminimacros.GeminiMacros` | UserDefaults domain and installed-app identity |
| Actions preference key | `savedActions` | JSON-encoded `[MacroAction]` |
| Keychain service | `com.geminimacros.apikey` | Namespace for the Gemini credential |
| Keychain item key | `apiKey` | Credential record inside the service |
| Default shortcut name | `defaultAction` | KeyboardShortcuts identity for the seeded action |
| Built-in Dictation action id | `D1C7A710-0000-4000-8000-000000000001` | Canonical protected Action identity |
| Built-in Dictation shortcut name | `builtInDictationAction` | Stable KeyboardShortcuts identity for Dictation |
| Per-action shortcut name | Random UUID string, persisted in `MacroAction` | Stable handler/recorder identity for that action |
| Splash-seen key | `fixer.v2.splash.seen.1` | Versioned first-run presentation policy |
| Output-mode raw values | `Replace`, `Append` | Persisted Codable values |
| Action-kind raw values | `text`, `dictation` | Persisted ordinary/built-in Action distinction |
| Voice-activation raw values | `toggle`, `hold` | Persisted process-wide voice gesture |

`MacroAction` uses tolerant decoding so one missing or malformed field does not
make the entire saved array fail. Its coding keys and fallback behavior are data
compatibility contracts. A deleted shortcut name is never reused: the underlying
library appends handlers and has no API for removing a registered callback.

`SettingsManager` also keeps a last-good Actions snapshot and preserves damaged
raw payloads. It salvages readable array members before falling back to the good
backup. If neither can be decoded, it exposes recovery feedback without replacing
the damaged library with starter Actions. This is separate from operation History.

The product/target name may evolve independently from the pinned bundle id and
Keychain service.

## External boundaries

### Accessibility

`PermissionsManager` reads `AXIsProcessTrusted` and can ask macOS to display the
Accessibility prompt. The prompt does not grant access by itself; the user must
enable Fixer in System Settings. Accessibility is needed for synthetic keyboard
events, not for the Gemini network request.

Source capture and target verification read the current focused Accessibility
element, selection/caret, and available text. Unreadable required source stops the
request. Unverifiable delivery uses History and the user's clipboard preference.

### Microphone

`SystemMicrophoneAuthorizer` and `VoiceAudioCapture` request macOS Microphone
permission only when Dictation or a `{voice}` Action is invoked. Microphone state
is intentionally absent from `SetupReadiness`: users who never use voice do not
receive a permission prompt or an incomplete Setup state. The app declares the
microphone usage description and hardened-runtime audio-input entitlement, and it
does not use `SFSpeechRecognizer` or `DictationTranscriber`.

### Gemini

`GeminiAPI` authenticates with the `x-goog-api-key` header. The key is read from
Keychain for each request and is not placed in the URL. Selected text, Action
Prompts, and—in voice flows—recorded audio are sent to Google's
`generateContent` endpoint.

Voice capture produces a 16 kHz mono PCM WAV saved locally before transcription. The internal
transcription request uses inline Base64 audio, a `14 MiB` raw-payload guard, a
120-second transport timeout, and `models/gemini-3.7-flash`. Its fixed instruction
asks for only a punctuated transcript, preserves multilingual code-switching, and
forbids translation, rewriting, summarizing, or answering. The audio leaves the
Mac; the source recording, transcript, and result are also retained in local
History. Fixer performs no silent provider fallback. The recording hard limit is five minutes.

Model discovery currently includes catalog entries that advertise
`generateContent`; that capability alone does not guarantee text output. The
generation parser consumes textual response parts only and rejects an incomplete
finish reason, preserving partial text for History instead of delivering it.

### Third-party packages

- `KeyboardShortcuts` records and invokes global shortcuts.
- `KeychainAccess` stores the Gemini credential in the macOS Keychain.

Both dependencies are wrapped behind small project-owned boundaries where tests
need substitutes: `HotkeyBinding` and `APIKeyStoring`.

## File navigation

| Area | Files |
|---|---|
| Entry point, menu, window lifecycle | `Sources/App.swift`, `Sources/WorkspaceWindowFactory.swift`, `Sources/WorkspaceWindowMetrics.swift` |
| Process state and activation/readiness policies | `Sources/AppState.swift`, `Sources/V2Support.swift` |
| Persisted action model and starter data | `Sources/Models.swift`, `Sources/StarterLibrary.swift` |
| Action persistence and shortcut lifecycle | `Sources/SettingsManager.swift`, `Sources/HotkeyCoordinator.swift` |
| Runtime orchestration and delivery | `Sources/ActionRunner.swift`, `Sources/VoiceActionRunner.swift`, `Sources/ResultDeliveryService.swift` |
| History storage, presentation, retry | `Sources/History*.swift`, `Sources/RecoverableVoiceRecording.swift`, `Sources/PersistenceEnvironment.swift` |
| Pasteboard and synthetic keyboard events | `Sources/ClipboardManager.swift` |
| Gemini text/audio transport and credential storage | `Sources/GeminiAPI.swift`, `Sources/GeminiVoiceTranscriber.swift`, `Sources/VoiceTranscribing.swift`, `Sources/VoiceAudio.swift`, `Sources/KeychainManager.swift` |
| Microphone capture and encoding | `Sources/VoiceAudioCapture.swift`, `Sources/LockedVoicePCMBuffer.swift`, `Sources/AudioLevelMeter.swift`, `Sources/WAVAudioEncoder.swift`, and the `Sources/Microphone*.swift` policy/authorization files |
| Voice target and cancellation safety | `Sources/VoiceInsertionTarget.swift`, `Sources/VoiceEscapeMonitor.swift` |
| Provider setup and Accessibility | `Sources/ProviderSetupController.swift`, `Sources/PermissionsManager.swift` |
| Actions workspace and setup | `Sources/SettingsView.swift`, `Sources/ActionLibraryTitlebarRow.swift`, `Sources/ActionLibraryRow.swift`, `Sources/ProviderSetupSheet.swift` |
| Action editor | `Sources/ActionEditor.swift`, the `Sources/ActionEditor*.swift` feature components, `Sources/DictationEditorContent.swift`, `Sources/DictationEditorHeader.swift`, `Sources/DictationActivationControl.swift`, `Sources/DictationPrivacySection.swift`, plus `Sources/StarterLibrarySheet.swift` |
| Passive run feedback | `Sources/HUD.swift`, `Sources/HUDManager.swift`, `Sources/HUDPanel.swift`, `Sources/HUDPresentationModel.swift`, `Sources/HUDVisuals.swift`, `Sources/HUDVoiceLevelIndicator.swift`, plus presentation/layout values in `Sources/V2Support.swift` |
| Splash policy, window, motion, and rendering | `Sources/SplashPolicy.swift`, `Sources/SplashWindowController.swift`, `Sources/SplashMotion.swift`, `Sources/SplashView.swift`, `Sources/SplashCardView.swift` |
| Design tokens and reusable controls | `Sources/FixerTheme.swift`, `Sources/FixerComponents.swift` |
| Unit and render tests | `Tests/` |

The tests mirror these boundaries: prompt composition, tolerant persistence,
action storage and Dictation migration, stale provider responses, Gemini
text/audio bodies and parsing, WAV encoding, microphone authorization policy,
voice prompt substitution and target verification, durable lifecycle ordering,
CAF/WAV recovery, cancellation with no upload, stale recording completions,
corruption/retention, retry, clipboard preference and restore/fallback behavior, window configuration, activation policy, HUD copy/layout,
splash policy/assets, and render capture. Render tests create PNG evidence; they
are not golden-image or pixel-diff assertions. Hosted workspace PNGs do not prove
the system-drawn window radius or traffic-light stacking, which require a live pass.

## Comment philosophy

Comments are part of the maintenance contract:

- Use `///` for ownership, lifetime, persistence, concurrency, privacy, and API
  contracts that callers need to understand.
- Use inline comments for a non-obvious reason or invariant, especially around
  AppKit focus, Keychain/UserDefaults identities, shortcut handler lifetime,
  stale async responses, and pasteboard change counts.
- Use `MARK` sections to make files with multiple responsibilities navigable.
- Do not narrate obvious SwiftUI layout or restate a function name.
- Do not claim a safety guarantee that the implementation and tests do not prove.
- Update the comment and this document whenever an invariant changes.

## Refactor checklist

Before accepting an architectural change, verify that it preserves:

- the pinned persistence identities above;
- one live shortcut callback per never-reused shortcut name;
- current-action lookup when a shortcut fires;
- main-actor ownership of shared UI/run state;
- serial confinement of all mutable clipboard backup state;
- stale-response rejection when a credential changes;
- non-activating HUD behavior and the external application's focus;
- lazy microphone authorization and no microphone dependency in Setup readiness;
- recoverable local audio, bounded capture/writer queues, and bounded inline upload;
- source/result persistence before provider/delivery stages and visible I/O failures;
- shared target verification and preference-controlled clipboard fallback;
- failed/interrupted history preservation and active-record deletion protection;
- Escape cancellation only while audio is guaranteed not to have been uploaded;
- conditional clipboard restoration on every abort and error path;
- hosted-test startup suppression before application side effects.
