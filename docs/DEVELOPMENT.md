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
xcodegen generate   # generate Fixer.xcodeproj from project.yml — required first step
xcodebuild -project Fixer.xcodeproj -scheme Fixer -configuration Release build
```

The product builds as `fixer.app`. `Fixer.xcodeproj` is generated and **git-ignored**
(project.yml is the source of truth), so run `xcodegen generate` right after cloning;
then either use the `xcodebuild` line above or open `Fixer.xcodeproj` in Xcode and
press **Run**.

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

The whole product is one short pipeline. A global hotkey fires, and:

```
hotkey (HotkeyCoordinator)
  → resolve the live action by id
  → ActionRunner.run(action:)
      → ClipboardManager.copySelection()      (synthetic ⌘C, backs up clipboard)
      → build prompt: substitute {text}
      → GeminiAPI.generateContent(model:prompt:)
      → ClipboardManager.paste(result)        (synthetic ⌘V, then restores clipboard)
      → HUD shows success / error
```

Everything runs on the main actor except the blocking pasteboard/keystroke work,
which is confined to a dedicated serial queue in `ClipboardManager`. `ActionRunner`
guards against overlapping triggers with an `isProcessing` latch and always restores
the clipboard, even on failure.

### File map

| File | Responsibility |
|------|----------------|
| `App.swift` | `MenuBarExtra` (glyph glows red while working) + `AppDelegate` that binds hotkeys and requests permission at launch |
| `AppState.swift` | Observable app state (`isProcessing`, permission, last error) |
| `Models.swift` | `MacroAction` (a user prompt + shortcut + model) and tolerant Codable persistence |
| `SettingsManager.swift` | Owns the action list; persists to UserDefaults; drives the hotkey lifecycle |
| `HotkeyCoordinator.swift` | Registers exactly one global handler per shortcut, resolving the live action at fire time |
| `ActionRunner.swift` | Orchestrates copy → Gemini → paste, with the re-entrancy latch and guaranteed clipboard restore |
| `ClipboardManager.swift` | Serial-queue pasteboard + synthetic ⌘C/⌘V, modifier-aware, race-safe restore |
| `GeminiAPI.swift` | Gemini REST calls (header auth, model pagination, timeouts, readable errors) |
| `KeychainManager.swift` | API-key storage in the Keychain |
| `PermissionsManager.swift` | Accessibility permission checks and the Settings deep-link |
| `SettingsView.swift` / `ActionEditor.swift` | The settings window and the per-action editor |
| `HUD.swift` | The on-screen "developing frame" feedback overlay |
| `StarterLibrary.swift` | Ready-made prompts offered in the Library |
| `FixerTheme.swift` / `FixerComponents.swift` | Darkroom design tokens and reusable UI components |

## Darkroom glossary

The UI and some component names lean on the darkroom metaphor. In plain terms:

| In the app | Means |
|------------|-------|
| Darkroom | the settings window |
| Developer key | a global keyboard shortcut |
| Developing / passing through the developer | an action is running |
| Exposures | your list of saved actions |
| Safelight | the red status lamp (also flags missing permission) |
| Fixed | the action finished successfully |
