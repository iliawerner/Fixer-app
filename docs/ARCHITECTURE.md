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
targets and dependencies, and XcodeGen includes the complete `Sources` and
`Tests` directories.

## End-to-end flows

### Application startup

```text
FixerApp
  -> AppDelegate.applicationDidFinishLaunching
     -> skip side effects when hosted by XCTest
     -> register bundled fonts
     -> initialize SettingsManager.shared
        -> decode actions from UserDefaults, or seed the default action
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
Setup control remains available and derives its incomplete issue treatment from
`SetupReadiness`. No bottom footer duplicates these entry points. The masthead
places the large editable Action name near the bottom-left and a `28 × 28 pt`
options menu at the top-right. Sidebar and masthead draw distinct bottom rules at
`40 pt` and `100 pt`; no parent separator claims that the surfaces share a baseline.

`FixerHoverButtonStyle` and the feature-specific custom controls share stationary
pointer feedback. Hover lasts `0.11 s`, press lasts `0.09 s`, and neither changes
layout geometry. Reduce Motion preserves the visual state distinction but removes
spatial press transforms. This contract covers Action rows, the icon-only add and
Setup controls, the Action `…` menu, Output, Enabled,
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
  -> HotkeyCoordinator resolves the current action by UUID
  -> ActionRunner.run(action:)
     -> reject disabled or overlapping runs
     -> verify Accessibility permission
     -> set AppState processing state
     -> show non-activating working HUD
     -> ClipboardManager.copySelection()
        -> back up the general pasteboard
        -> wait for shortcut modifiers to be released
        -> post synthetic Command-C
        -> capture the selection and immediately restore the backup
     -> substitute {text} in the prompt
     -> GeminiAPI.generateContent(model:prompt:)
        -> read the API key from Keychain
        -> POST text to Google Gemini
        -> parse textual response parts
     -> compose replace/append output
     -> ClipboardManager.paste(_:)
        -> back up the pasteboard as it exists after the network wait
        -> write the result to the general pasteboard
        -> post synthetic Command-V
        -> conditionally restore the paste-time backup from after the network wait
     -> show success, or restore conditionally and show an error
     -> clear AppState processing state
```

The action passed to `ActionRunner` is a value snapshot taken when the shortcut
fires. Edits made while a request is in flight affect the next run, not the
current request.

`HUDManager` creates one non-activating panel and one hosted `RunFeedbackHUDView`.
`HUDPresentationModel` mutates the semantic phase inside that persistent tree, so
the warm-neutral status card never blinks or stacks while working becomes success
or error. The first frame appears immediately; only a short entry and phase
crossfade are allowed. There is no visible Fixer wordmark or repair metaphor.
Working/busy shows the Action name once with a standard progress state. Success
uses a standard check and says `Text replaced` or `Text appended`. Error uses a
standard error symbol plus a concrete reason and next step. Reduce Motion keeps
structural motion opacity-only without changing the panel's focus contract.

## State ownership and isolation

| State | Owner | Lifetime | Isolation |
|---|---|---|---|
| Saved actions | `SettingsManager.shared` | Process plus UserDefaults persistence | Main actor |
| Current run, permission snapshot, last error | `AppState.shared` | Process | Main actor |
| Registered shortcut handlers | `HotkeyCoordinator.shared` | Process | Main actor |
| Provider setup and model-loading state | `ProviderSetupController` owned by `SettingsView` | Workspace instance | Main actor |
| Settings window | `AppDelegate` | Process | AppKit/main thread |
| Splash window | `SplashWindowController` | Visible splash session | AppKit/main thread |
| HUD panel and dismissal task | `HUDManager.shared` | Process | Main actor |
| Pasteboard backup and timing state | `ClipboardManager.shared` | One serialized operation at a time | Dedicated serial queue |
| Gemini transport | `GeminiAPI.shared` | Process | Stateless client; injected session/key provider |

`ActionRunner` uses `AppState.isProcessing` as a single-flight latch. The guard
and assignment occur without an `await` on the main actor, so two shortcut events
cannot both start a run. Clipboard work uses a dedicated serial dispatch queue
because its waits are blocking and must not occupy Swift concurrency's
cooperative executor.

## Window and focus invariants

Fixer's text replacement depends on the frontmost external application remaining
the recipient of synthetic Command-C and Command-V.

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
  Setup exists once as the trailing sidebar-titlebar control, and only incomplete
  setup carries issue status. There is no bottom sidebar footer.
- The sidebar rule ends at `40 pt`; the detail masthead rule ends at `100 pt`.
  Neither is extended into a fake shared separator.
- Interactive state changes never alter layout geometry. Under Reduce Motion,
  pressed controls do not translate or scale.
- Workspace and splash activation is blocked while an action is processing.
- Menu commands that open those windows are disabled during processing.
- The menu-bar icon may update, but that update must not activate Fixer.

Fixer does **not** capture and later restore the original application, window, or
text field. Paste is delivered to whichever control is focused when the network
response completes. Preventing Fixer's own windows from stealing focus is an
invariant; a user-initiated focus change during the request remains a current
limitation.

## Clipboard contract

`ClipboardManager` attempts to copy the data representation for every declared
type in every pasteboard item before posting Command-C. It remembers the
`changeCount` produced by each short stage and conditionally restores only when
the pasteboard still contains that stage's value.

There are four distinct stages:

1. `copySelection()` captures the selection and restores the pre-copy backup
   immediately, before the Gemini request starts.
2. On abort or request failure, `restore()` is normally a no-op because the copy
   stage has already completed its own restoration.
3. On success, `paste(_:)` backs up the clipboard again as it exists after the
   network wait, writes Gemini's result for Command-V, and restores that fresh
   backup. A user Copy during the request is therefore preserved.
4. A clipboard change made after the result write is also preserved during the
   settle interval because its `changeCount` no longer matches Fixer's write.

The pasteboard is a shared system boundary, so selected text and generated output
still pass through it briefly during their respective synthetic keystrokes. The
change-count checks are best-effort coordination, not an atomic lock against every
possible external write between two pasteboard calls.

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
| Per-action shortcut name | Random UUID string, persisted in `MacroAction` | Stable handler/recorder identity for that action |
| Splash-seen key | `fixer.v2.splash.seen.1` | Versioned first-run presentation policy |
| Output-mode raw values | `Replace`, `Append` | Persisted Codable values |

`MacroAction` uses tolerant decoding so one missing or malformed field does not
make the entire saved array fail. Its coding keys and fallback behavior are data
compatibility contracts. A deleted shortcut name is never reused: the underlying
library appends handlers and has no API for removing a registered callback.

The product/target name may evolve independently from the pinned bundle id and
Keychain service.

## External boundaries

### Accessibility

`PermissionsManager` reads `AXIsProcessTrusted` and can ask macOS to display the
Accessibility prompt. The prompt does not grant access by itself; the user must
enable Fixer in System Settings. Accessibility is needed for synthetic keyboard
events, not for the Gemini network request.

### Gemini

`GeminiAPI` authenticates with the `x-goog-api-key` header. The key is read from
Keychain for each request and is not placed in the URL. Selected text and the
action prompt are sent to Google's `generateContent` endpoint.

Model discovery currently includes catalog entries that advertise
`generateContent`; that capability alone does not guarantee text output. The
generation parser consumes textual response parts only.

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
| Runtime orchestration | `Sources/ActionRunner.swift` |
| Pasteboard and synthetic keyboard events | `Sources/ClipboardManager.swift` |
| Gemini transport and credential storage | `Sources/GeminiAPI.swift`, `Sources/KeychainManager.swift` |
| Provider setup and Accessibility | `Sources/ProviderSetupController.swift`, `Sources/PermissionsManager.swift` |
| Actions workspace and setup | `Sources/SettingsView.swift`, `Sources/ActionLibraryTitlebarRow.swift`, `Sources/ActionLibraryRow.swift`, `Sources/ProviderSetupSheet.swift` |
| Action editor | `Sources/ActionEditor.swift` and the `Sources/ActionEditor*.swift` feature components, plus `Sources/StarterLibrarySheet.swift` |
| Passive run feedback | `Sources/HUD.swift`, `Sources/HUDManager.swift`, `Sources/HUDPanel.swift`, `Sources/HUDPresentationModel.swift`, `Sources/HUDVisuals.swift`, plus presentation/layout values in `Sources/V2Support.swift` |
| Splash policy, window, motion, and rendering | `Sources/SplashPolicy.swift`, `Sources/SplashWindowController.swift`, `Sources/SplashMotion.swift`, `Sources/SplashView.swift`, `Sources/SplashCardView.swift` |
| Design tokens and reusable controls | `Sources/FixerTheme.swift`, `Sources/FixerComponents.swift` |
| Unit and render tests | `Tests/` |

The tests mirror these boundaries: prompt composition, tolerant persistence,
action storage, stale provider responses, Gemini parsing/pagination, clipboard
restore behavior, window configuration, activation policy, HUD copy/layout,
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
- conditional clipboard restoration on every abort and error path;
- hosted-test startup suppression before application side effects.
