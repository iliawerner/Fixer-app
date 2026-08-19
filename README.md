# Fixer

[![CI](https://github.com/iliawerner/Fixer-app/actions/workflows/ci.yml/badge.svg)](https://github.com/iliawerner/Fixer-app/actions/workflows/ci.yml)

**Fixer** is a tiny macOS menu-bar app that rewrites selected text in place with
Google Gemini. Select text in any app, press a global keyboard shortcut, and the
selection is replaced with an LLM-polished version — fix grammar, translate,
summarize, or whatever your prompt says. No copy, paste into a browser, and paste
back.

A typical use: *"fix the grammar and make it sound natural."* Fixer turns that
request into a single keystroke, anywhere.

> **Design:** Fixer uses warm paper, signal yellow, near-black type, and thin
> technical rules. During a run, a compact warm-neutral status card uses
> familiar progress, success, and error symbols with direct copy. It never
> repeats the Fixer wordmark or takes focus from the active app. A
> layered version of the yellow Fixer poster introduces v2 on first launch and
> can be replayed from the menu-bar menu. The Actions workspace opens as a compact
> `820 × 720` native window with a `40 pt` sidebar titlebar and a deliberately
> taller `100 pt` yellow Action masthead, plus compact non-shifting pointer
> feedback.

Design work and visual QA must use the curated
[`design-reference`](design-reference/README.md) package. It records the approved
hierarchy, palette, identity master, intentional native adaptations, and concepts
from the original prototype that must not be copied into the product.

## ✨ Features

- **Instant in-place rewrite** — select text anywhere, hit a shortcut, get the result typed back where you were.
- **Your own prompts** — create any number of templates (fix grammar, translate, make it professional…). Put `{text}` where the selection should go, e.g. `Translate to French: {text}`.
- **A shortcut per prompt** — assign a unique global hotkey to each template.
- **Actions workspace** — create, enable, and edit actions in one compact native master-detail window. Changes save immediately.
- **Focused run feedback** — a passive status card reports working, success, and error states without taking focus from the app that receives the result.
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
2. **Grant Accessibility.** On first launch Fixer plays its short identity animation,
   then opens the Actions workspace and asks for Accessibility permission
   (*System Settings → Privacy & Security → Accessibility*).
   It's required so the app can read your selection and paste the result.
3. **Paste your Gemini API key** (from
   [Google AI Studio](https://aistudio.google.com/app/apikey)) into the settings.
   It's stored in the macOS Keychain. Click **Check key & load models**.
4. **Add a prompt** — open the toolbar **+** menu and choose **Blank Action** or
   **From Starter Library**, then record a shortcut, choose a model, and write
   your prompt. The separate **Setup** control stays available beside the menu
   and calls attention to itself only while setup is incomplete.

Now, in any app: select text → press your shortcut → the result replaces (or is
appended to) your selection.

To replay the first-launch animation later, open the Fixer menu-bar menu and choose
**Show Splash…**. The animation respects **Reduce Motion**.

## ⌨️ Keyboard shortcuts

A global shortcut needs a modifier (⌘, ⌥, or ⌃) plus a key — a bare key like `Q`
would fire whenever you typed the letter. A few keys can't be recorded because
macOS reserves them (Tab on its own, the 🌐/Spotlight key). The recorder shows this
hint inline while you set a shortcut.

## 🛠️ Building & contributing

Fixer is open source and easy to build (XcodeGen + Xcode). See
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build steps, the architecture, and a
map of the code. See [design-reference/QA-CHECKLIST.md](design-reference/QA-CHECKLIST.md)
for the required hands-on macOS visual and interaction pass.

## 🤖 A note on the code

This project was largely **"vibecoded"** with AI tools (Fable 5, Opus 4.8, and
Gemini 3.1 Pro). It works and solves a real problem, but don't expect a masterpiece
of software architecture under the hood.
