# fixer

A tiny macOS menu-bar app. Select text in any app, press a global keyboard
shortcut, and Google Gemini rewrites it in place — fix grammar, translate,
summarize, whatever prompt you configure.

**The concept is a photo darkroom.** Your selected text is the *latent image*,
the hotkey is the *developer*, and **fixer** sets the result. The UI is a
darkroom: near-black surfaces, a red *safelight*, amber and Kodak-yellow film
markings. The menu-bar lamp glows red while an action develops, and the result
"emerges" out of grain in an on-screen frame.

> The app is technically still built under the bundle id
> `com.geminimacros.GeminiMacros` so your saved API key and actions carry over —
> only the product name and look changed.

## Run it

A ready-to-run build is on your **Desktop**: `fixer.app`. Double-click it. It
lives in the menu bar (look for the film glyph) — no Dock icon or main window.

On first launch it opens the **Darkroom** (settings) automatically and asks for
**Accessibility** permission.

### First-time setup (3 steps)

1. **Grant Accessibility.** macOS will prompt, or open *System Settings → Privacy
   & Security → Accessibility* and enable **fixer**. Required so it can copy your
   selection and paste the result. A red safelight in the menu bar / footer means
   it isn't granted yet.
2. **Paste your Gemini API key** (from <https://aistudio.google.com/app/apikey>)
   into the Darkroom. It is stored in the macOS Keychain. Click **Fetch Models**.
3. **Add an action:** click **New** (or load one from the **Library**), record a
   developer key (shortcut), pick a model, and write a prompt. Use `{text}` where
   the selected text should go, e.g. `Translate to French: {text}`.

Then, in any app: select text → press your shortcut → the result replaces (or is
appended to) your selection.

> If macOS refuses to open it (“unidentified developer”), right-click the app →
> **Open** → **Open**. This build is ad-hoc signed for local use, not notarized.

## About keyboard shortcuts

Global shortcuts **require a modifier** — ⌘, ⌥, or ⌃ — plus a key (e.g. ⌥Q,
⌃⌘F). This is a macOS rule, not a bug: a bare key like `Q` as a global shortcut
would fire every time you typed the letter anywhere.

Some keys **cannot** be recorded because macOS reserves them:
- **Tab** on its own moves focus out of the recorder (it is not a modifier).
- The dedicated **🌐 / Spotlight / search key** is intercepted by the system
  before any app sees it.

The action editor shows this hint inline while you record.

## Build from source

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 26+ (the app
icon is an Icon Composer `fixer.icon`).

```sh
cd GeminiMacros
xcodegen generate
xcodebuild -project GeminiMacros.xcodeproj -scheme GeminiMacros -configuration Release build
```

The product builds as `fixer.app`.

## How it works

| File | Responsibility |
|------|----------------|
| `App.swift` | `MenuBarExtra` (glyph glows red while working) + `AppDelegate` that binds hotkeys and requests permission at launch |
| `FixerTheme.swift` / `FixerComponents.swift` | Darkroom design tokens + components (film frame, sprockets, safelight switch, grain) |
| `HotkeyCoordinator.swift` | Registers exactly one global handler per shortcut, resolving the live action at fire time |
| `ActionRunner.swift` | Orchestrates copy → Gemini → paste, with debounce and guaranteed clipboard restore |
| `ClipboardManager.swift` | Serial-queue pasteboard + synthetic Cmd+C/Cmd+V, modifier-aware, race-safe |
| `GeminiAPI.swift` | Gemini REST calls (header auth, pagination, timeouts, readable errors) |
| `SettingsView.swift` / `ActionEditor.swift` | The Darkroom window and the action editor |
| `HUD.swift` | The "developing frame" on-screen feedback overlay |
| `KeychainManager.swift` | API-key storage in the Keychain |

Requires macOS 13+ (Icon Composer icon renders fully on macOS 26+).
