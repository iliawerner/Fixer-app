# Fixer

> *For those who, like me, are tired of waiting for operating systems to natively and simply integrate obvious LLM use cases.*

**Fixer** is a lightweight, single-purpose macOS menu-bar app. Select text in any
app, press a global keyboard shortcut, and Google Gemini rewrites it in place —
fix grammar, translate, summarize, whatever prompt you configure. No copy, paste,
open a browser, paste back.

As a non-native speaker, you might often find yourself asking an AI to "fix the
grammar and make it sound more natural." Fixer automates this entirely.

**The concept is a photo darkroom.** Your selected text is the *latent image*, the
hotkey is the *developer*, and **fixer** sets the result. The UI is a darkroom:
near-black surfaces, a red *safelight*, amber and Kodak-yellow film markings. The
menu-bar lamp glows red while an action develops, and the result "emerges" out of
grain in an on-screen frame.

## ✨ Features

- **Instant Text Replacement**: Select text anywhere, hit a shortcut, and get the processed result instantly typed back.
- **Bring Your Own Prompts**: Create any number of custom prompts (e.g., "Make it sound professional", "Translate to Spanish", "Fix grammar"). Use `{text}` where the selected text should go.
- **Custom Hotkeys**: Assign a unique global keyboard shortcut to each of your templates.
- **Powered by Gemini**: Designed to work with Google's Gemini models (like the incredibly fast `gemini-2.5-flash-lite`).
- **Menu-bar only**: Lives in the menu bar (`LSUIElement`) — no Dock icon, no main window.

## 💰 Pricing & Cost

Fixer itself is **Open Source and completely free**.

It uses your personal **Gemini API Key**. Because Gemini offers a generous free tier
(and is incredibly cheap even on paid tiers), everyday personal usage for text
fixing is very likely to cost you **absolutely nothing**. Fast models like
Flash-Lite handle these tasks perfectly with near-instant response times.

## 🚀 Setup

1. **Download the app**: Grab the latest release from the [Releases](../../releases)
   page and move `fixer.app` to your `Applications` folder.
   - If macOS refuses to open it (“unidentified developer”), right-click the app →
     **Open** → **Open**. Release builds are ad-hoc signed for local use, not notarized.
2. **Grant Accessibility.** On first launch it opens the **Darkroom** (settings) and
   asks for Accessibility permission (*System Settings → Privacy & Security →
   Accessibility → enable fixer*). Required so it can copy your selection and paste
   the result. A red safelight in the menu bar / footer means it isn't granted yet.
3. **Paste your Gemini API key** (from <https://aistudio.google.com/app/apikey>) into
   the Darkroom. It is stored in the macOS Keychain. Click **Fetch Models**.
4. **Add an action**: click **New** (or load one from the **Library**), record a
   developer key (shortcut), pick a model, and write a prompt, e.g.
   `Translate to French: {text}`.

Then, in any app: select text → press your shortcut → the result replaces (or is
appended to) your selection.

## ⌨️ About keyboard shortcuts

Global shortcuts **require a modifier** — ⌘, ⌥, or ⌃ — plus a key (e.g. ⌥Q, ⌃⌘F).
This is a macOS rule, not a bug: a bare key like `Q` as a global shortcut would fire
every time you typed the letter anywhere.

Some keys **cannot** be recorded because macOS reserves them:
- **Tab** on its own moves focus out of the recorder (it is not a modifier).
- The dedicated **🌐 / Spotlight / search key** is intercepted by the system before any app sees it.

The action editor shows this hint inline while you record.

## 🧑‍💻 Build from source

Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Xcode 26+ (the app
icon is an Icon Composer `fixer.icon`; it renders fully on macOS 26+). Requires
macOS 13+ to run.

```sh
xcodegen generate   # regenerate GeminiMacros.xcodeproj from project.yml (source of truth)
xcodebuild -project GeminiMacros.xcodeproj -scheme GeminiMacros -configuration Release build
```

The product builds as `fixer.app`. A generated `GeminiMacros.xcodeproj` is also
committed, so you can simply open it in Xcode and hit **Run** without XcodeGen.

> The app is still built under the target/bundle id `com.geminimacros.GeminiMacros`
> so an existing user's saved API key and actions carry over — only the product name
> and look are "fixer".

## 🔧 How it works

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

## 🤖 Vibecoding disclaimer

Please note that this project was almost entirely **"vibecoded"** using AI tools
(Fable 5, Opus 4.8, and Gemini 3.1 Pro). Because of this, there shouldn't be high
expectations regarding the originality, architecture, or conventional best practices
of the underlying code. It works, it solves the problem, but it might not be a
masterpiece of software engineering!

---
*Created with ❤️ (and AI) to save you thousands of copy-pastes.*
