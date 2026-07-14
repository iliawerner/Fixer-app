# Fixer

**Fixer** is a lightweight, single-purpose macOS micro-app designed to quickly process selected text through an LLM using predefined prompt templates.

## ✨ Why Fixer?

As a non-native speaker, you might often find yourself asking an AI to "fix the grammar and make it sound more natural." Fixer automates this entirely. 

Simply select any text on your screen, press a keyboard shortcut, and Fixer will instantly replace the selected text with an LLM-polished version. No need to copy, paste, open a browser, and paste back!

## 🚀 Features

- **Instant Text Replacement**: Select text anywhere, hit a shortcut, and get the processed result instantly typed back.
- **Bring Your Own Prompts**: Create any number of custom prompts (e.g., "Make it sound professional", "Translate to Spanish", "Fix grammar").
- **Custom Hotkeys**: Assign a unique global keyboard shortcut to each of your templates.
- **Powered by Gemini**: Designed to work with Google's Gemini models (like the incredibly fast `gemini-2.5-flash-lite`).

## 💰 Pricing & Cost

Fixer itself is **Open Source and completely free**.

It uses your personal **Gemini API Key**. Because Gemini offers a generous free tier (and is incredibly cheap even on paid tiers), everyday personal usage for text fixing is very likely to cost you **absolutely nothing**. Fast models like Flash-Lite handle these tasks perfectly with near-instant response times.

## 🛠️ How to Setup

1. **Download the App**: Grab the latest release from the [Releases](../../releases) page and move it to your `Applications` folder.
2. **Get a Gemini API Key**:
   - Go to [Google AI Studio](https://aistudio.google.com/app/apikey).
   - Create a new API key.
3. **Configure Fixer**:
   - Open the app and paste your API key in the settings.
   - Add a new prompt template (e.g., *Fix grammar and make this sound natural*).
   - Assign a global hotkey to your new template.
4. **You're all set!** Highlight some text anywhere, press your hotkey, and watch the magic happen.

## 🧑‍💻 For Developers: Building from Source

If you want to build the project yourself or contribute:
1. Clone the repository.
2. Open the project in Xcode.
3. Build and run!

## 🤖 Vibecoding Disclaimer

Please note that this project was almost entirely **"vibecoded"** using AI tools (Fable 5, Opus 4.8, and Gemini 3.1 Pro). 
Because of this, there shouldn't be high expectations regarding the originality, architecture, or conventional best practices of the underlying code. It works, it solves the problem, but it might not be a masterpiece of software engineering!

---
*Created with ❤️ (and AI) to save you thousands of copy-pastes.*
