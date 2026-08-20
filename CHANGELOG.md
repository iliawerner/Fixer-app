# Changelog

All notable changes to Fixer are documented here. Fixer follows semantic
versioning while it is in public beta, so breaking changes may still occur in a
`0.x` release and will be called out explicitly.

## [0.2.0] - 2026-08-20

### Added

- Gemini-powered Dictation with **Press again** and **Hold** activation modes.
- A permanent, protected Dictation Action that inserts speech at the original
  cursor without requiring a user-written Prompt.
- The `{voice}` Prompt token for combining speech with ordinary Actions and
  optional `{text}` context.
- Exact voice-target verification with a safe clipboard fallback when the app,
  field, selection, or cursor changes.
- Lazy Microphone authorization, a five-minute recording limit, measured input
  feedback, and explicit listening/transcription states.
- A new compact Actions workspace, redesigned passive feedback HUD, and layered
  first-launch splash presentation.

### Changed

- Redesigned the interface around a warm, native macOS visual system.
- New Actions default to Gemini 3.6 Flash; existing model choices are preserved.
- Simplified provider Setup, Starter Library, model selection, and Action editing.
- Release builds now use the hardened runtime and the audio-input entitlement.

### Privacy and reliability

- Voice recordings stay in memory and are not retained by Fixer.
- Existing Actions, Shortcuts, and the Keychain credential migrate without being
  reset; the new Dictation Action is added automatically.
- Improved clipboard restoration, Shortcut lifecycle handling, Keychain error
  reporting, target-focus safety, and stale-request rejection.
- Locked dependency revisions and separate Debug-test and Release-build CI gates.

## [0.1.0] - 2026-07-14

- First public beta with selected-text Actions, custom Prompts, Gemini models,
  and global Shortcuts.

[0.2.0]: https://github.com/iliawerner/Fixer-app/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/iliawerner/Fixer-app/releases/tag/v0.1.0
