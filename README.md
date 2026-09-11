# Fixer

[![CI](https://github.com/iliawerner/Fixer-app/actions/workflows/ci.yml/badge.svg)](https://github.com/iliawerner/Fixer-app/actions/workflows/ci.yml)

**Current beta: 0.4.1** · [Changelog](CHANGELOG.md) · [Roadmap](ROADMAP.md)

**Fixer** is a tiny macOS menu-bar app that rewrites selected text and turns
speech into text with Google Gemini. Select text in any app, press a global
keyboard shortcut, and the selection is replaced with an LLM-polished version —
fix grammar, translate, summarize, or whatever your prompt says. Or trigger the
permanent **Dictation** Action and speak directly into the field that already has
your cursor. No browser round-trip.

A typical use: *"fix the grammar and make it sound natural."* Fixer turns that
request into a single keystroke, anywhere.

> **Design:** Fixer offers warm paper and warm charcoal themes, with signal yellow
> accents and quiet dividers. During a run, a compact neutral status card uses
> familiar progress, success, and error symbols with direct copy. It never
> repeats the Fixer wordmark or takes focus from the active app. A
> layered version of the yellow Fixer poster introduces Fixer 0.2 on first launch and
> can be replayed from the menu-bar menu. The Actions workspace opens as a compact
> `820 × 720` native window with a `40 pt` sidebar titlebar and a deliberately
> taller `100 pt` Action masthead, plus compact non-shifting pointer
> feedback.

Design work and visual QA must use the curated
[`design-reference`](design-reference/README.md) package. It records the approved
hierarchy, palette, identity master, intentional native adaptations, and concepts
from the original prototype that must not be copied into the product.

## ✨ Features

- **Safe in-place rewrite** — select text in an accessible field and hit a shortcut. Fixer pastes only while the original target remains verifiable; otherwise the result stays in History.
- **Your own prompts** — create any number of templates (fix grammar, translate, make it professional…). Put `{text}` where the selection should go, e.g. `Translate to French: {text}`.
- **Built-in Dictation** — one permanent, protected Action transcribes speech and inserts it at the original cursor. Stop with a second Shortcut press or choose hold-to-talk.
- **Voice inside any Action** — add `{voice}` to an ordinary Prompt to record speech, substitute the transcript, and then run the Action. `{voice}` and `{text}` can be used together.
- **A shortcut per prompt** — assign a unique global hotkey to each template.
- **Actions workspace** — create, enable, and edit actions in one compact native master-detail window. Changes save immediately.
- **Appearance** — choose Light, Dark, or Follow System at the top of Setup. The choice applies to open windows and saves immediately; Follow System is the default.
- **Local History and recovery** — the clock beside Setup opens originals, results, transcripts, errors, and recordings. Copy text, play or export audio, and retry failed processing without repeating completed transcription.
- **Focused run feedback** — a passive status card reports working, success, and error states without taking focus from the app that receives the result.
- **Menu-bar only** — no Dock icon, no window in the way.

`{voice}` can be an instruction, not only dictated body text. For example:

```text
Reply to this selected message:

{text}

Follow this spoken instruction:
{voice}
```

Trigger the Action, say “accept Tuesday, but ask whether three o'clock works,”
and Fixer writes the finished reply back into the original app.

## 💰 Pricing

Fixer is open source and free. It uses **your** personal Gemini API key, and
any provider billing or quota applies to that key. Plain Dictation normally makes
one audio request; an ordinary `{voice}` Action normally makes an audio
transcription request followed by its configured text-model request. Google's
free-tier availability and limits can change, so check the current terms for your
account.

## 🚀 Setup

1. **Download the app** from the [Releases](../../releases) page and move
   `Fixer.app` to your `Applications` folder.
   - If macOS blocks it ("unidentified developer"), right-click the app → **Open**
     → **Open**, or use *System Settings → Privacy & Security → Open Anyway*.
     Releases are ad-hoc signed and not notarized, hence the warning. Never
     disable Gatekeeper globally.
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
5. **Optional: configure Dictation** — select the permanent **Dictation** row,
   record its Shortcut, and choose **Press again** or **Hold**. macOS asks for
   Microphone permission only when a voice Shortcut is first invoked; microphone
   access is not part of the ordinary Setup readiness state.

Now, in any app: select text → press your shortcut → the result replaces (or is
appended to) your selection if the original target still matches. Controls that
do not expose a verifiable text selection through macOS Accessibility cannot be
used as selected-text input.

### Updating Fixer

Quit the old app, replace it with `Fixer.app` 0.4.1, and launch it. The release
keeps the same bundle identifier and storage locations for existing Actions,
Shortcuts, Dictation settings, the Gemini key in Keychain, and local History.
Existing History retention rules still apply at launch. macOS may ask for
Accessibility again after replacing an ad-hoc signed build.

Open **Setup → Appearance** to choose Light or Dark, or leave **Follow System**
selected to use the macOS appearance.

Starting with 0.3.0, Fixer retains local text and audio in History for recovery.
Review the retention and clipboard options in Setup; see [Local History](#local-history)
for what is stored and how to delete it.

To replay the first-launch animation later, open the Fixer menu-bar menu and choose
**Show Splash…**. The animation respects **Reduce Motion**.

## 🎙️ Voice privacy and safety

Dictation is Gemini-first. Fixer records a maximum of five minutes, saves a local
recovery recording while you speak, and sends a 16 kHz mono WAV to Google Gemini
`gemini-3.7-flash` for transcription. Audio therefore leaves your Mac. Fixer does
not use Apple `SFSpeechRecognizer`. Escape cancels before upload; the local
recording remains in History. After transcription begins, audio may already have
been sent.

Fixer remembers the destination application, exact focused Accessibility
element, selected-text range or caret, and available text when a text or voice
Action starts. It checks again immediately before sending Paste. If the target
changed or cannot be verified, Fixer saves the result in History and, by default,
also copies it to the clipboard. Turn off **Copy result when the original target has changed**
in Setup to preserve your clipboard in this case. Fixer never moves focus back.
Keyboard-based paste cannot prove that another application accepted the result;
the saved copy remains available either way.

## Local History

History saves the Action snapshot, available source text, prompt, transcript,
result, error, and voice recording in
`~/Library/Application Support/com.geminimacros.GeminiMacros/History`. Inputs are saved before requests
and results before delivery. If a save fails, processing stops before sending
or pasting that unsaved stage, and available material stays visible in memory.
An interrupted recording retains its written prefix; a crash may lose the last
queued audio fragments.

History is local, with owner-only file permissions; it is not separately
encrypted and is not a cloud backup. Setup controls automatic cleanup: successful
and cancelled runs expire after 30 days by default (7, 90, or forever are also
available). Failed and interrupted runs stay until you delete them. History
supports deleting an entry or clearing finished entries; active runs are protected.
Retry creates a new entry, uses its saved Action, and sends only the stages still
needed to Gemini. A retry never pastes into the previous target.

## ⌨️ Keyboard shortcuts

A global shortcut needs a modifier (⌘, ⌥, or ⌃) plus a key — a bare key like `Q`
would fire whenever you typed the letter. A few keys can't be recorded because
macOS reserves them (Tab on its own, the 🌐/Spotlight key). The recorder shows this
hint inline while you set a shortcut.

## 🛠️ Building & contributing

Fixer is open source and easy to build (XcodeGen + Xcode). See
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for build steps,
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for runtime ownership and data-flow
contracts, and [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
The [design QA checklist](design-reference/QA-CHECKLIST.md) defines the required
hands-on macOS visual and interaction pass.

Maintainers can follow the reproducible [release checklist](docs/RELEASING.md).
Bundled dependency and font licenses are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 🗺️ Roadmap

Planned directions include more cloud API providers, optional local models for
offline text and speech, and a privacy-first **Quick Insert** library for
addresses, phone numbers, signatures, and other reusable information. These are
directions rather than promised dates. See [ROADMAP.md](ROADMAP.md) for scope and
data-safety principles.

## 🤖 A note on the code

This project was largely **"vibecoded"** with AI tools (Fable 5, Opus 4.8, and
Gemini 3.1 Pro). It works and solves a real problem, but don't expect a masterpiece
of software architecture under the hood.
