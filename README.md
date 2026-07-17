# Fixer

**Fixer** is a tiny macOS menu-bar app that rewrites selected text in place with
Google Gemini. Select text in any app, press a global keyboard shortcut, and the
selection is replaced with an LLM-polished version — fix grammar, translate,
summarize, or whatever your prompt says. No copy, paste into a browser, and paste
back.

A typical use: *"fix the grammar and make it sound natural."* Fixer turns that
request into a single keystroke, anywhere.

> **Aesthetic:** the app is themed as a photo darkroom — near-black surfaces, a red
> safelight, and Kodak-yellow film markings. Your text is the *latent image*, the
> hotkey is the *developer*, and the result "emerges" in an on-screen frame. It's
> just a look; the sections below use plain words.

## ✨ Features

- **Instant in-place rewrite** — select text anywhere, hit a shortcut, get the result typed back where you were.
- **Your own prompts** — create any number of templates (fix grammar, translate, make it professional…). Put `{text}` where the selection should go, e.g. `Translate to French: {text}`.
- **A shortcut per prompt** — assign a unique global hotkey to each template.
- **Menu-bar only** — no Dock icon, no window in the way.

## 💰 Pricing

Fixer is open source and free. It uses **your** personal Gemini API key, and
Gemini's free tier is generous — for everyday text fixing with a fast model like
`gemini-2.5-flash-lite`, typical personal usage is likely to cost nothing.

## 🚀 Setup

1. **Download the app** from the [Releases](../../releases) page and move
   `fixer.app` to your `Applications` folder.
   - If macOS blocks it ("unidentified developer"), right-click the app → **Open**
     → **Open**. Releases are ad-hoc signed and not notarized, hence the warning.
2. **Grant Accessibility.** On first launch Fixer opens its settings and asks for
   Accessibility permission (*System Settings → Privacy & Security → Accessibility*).
   It's required so the app can read your selection and paste the result.
3. **Paste your Gemini API key** (from
   [Google AI Studio](https://aistudio.google.com/app/apikey)) into the settings.
   It's stored in the macOS Keychain. Click **Fetch Models**.
4. **Add a prompt** — click **New** or pick one from the **Library**, record a
   shortcut, choose a model, and write your prompt.

Now, in any app: select text → press your shortcut → the result replaces (or is
appended to) your selection.

## ⌨️ Keyboard shortcuts

A global shortcut needs a modifier (⌘, ⌥, or ⌃) plus a key — a bare key like `Q`
would fire whenever you typed the letter. A few keys can't be recorded because
macOS reserves them (Tab on its own, the 🌐/Spotlight key). The recorder shows this
hint inline while you set a shortcut.

## 🛠️ Building & contributing

Fixer is open source and easy to build (XcodeGen + Xcode). See
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build steps, the architecture, and a
map of the code.

## 🤖 A note on the code

This project was largely **"vibecoded"** with AI tools (Fable 5, Opus 4.8, and
Gemini 3.1 Pro). It works and solves a real problem, but don't expect a masterpiece
of software architecture under the hood.
