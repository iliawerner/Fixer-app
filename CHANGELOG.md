# Changelog

All notable changes to Fixer are documented here. Fixer follows semantic
versioning while it is in public beta, so breaking changes may still occur in a
`0.x` release and will be called out explicitly.

## [0.3.0] - 2026-09-09

### Added

- Local History beside Setup, with originals, results, transcripts, errors,
  audio playback/export, deletion, and retry from the last usable input.
- Recording recovery before WAV encoding and provider calls. Interrupted runs
  are retained and identified at the next launch.
- Configurable clipboard fallback, enabled by default, and History retention
  (30 days by default; failed/interrupted entries require explicit deletion).

### Fixed

- Shared text/voice target validation immediately before Paste; changed or
  unverifiable targets leave results in History instead of posting a key.
- Incomplete Gemini responses retain partial output without replacing text.
- Stale recording completions cannot terminate a newer recording.
- Malformed Action storage preserves backup data and recovers valid records;
  duplicate identities and Shortcut names are repaired without discarding
  distinct Actions.
- Removed obsolete synchronization conflict copies and added a project-generation
  guard against their accidental inclusion.

### Privacy change

- Fixer now retains local input, prompt, transcript, result, and audio history.
  Setup explains retention, cleanup, and clipboard behavior. History files use
  owner-only permissions and are not separately encrypted.

## [0.2.2] - 2026-08-29

### Fixed

- Made the toolbar **+** menu and **Setup** button respond reliably to physical
  mouse clicks in the macOS system titlebar.
- Kept traffic-light controls and empty-area window dragging native while
  routing the two visible Fixer controls through correctly aligned AppKit hit
  targets.
- Kept those hit targets aligned when the system toolbar is shown or hidden,
  without adding duplicate or invisible VoiceOver and keyboard-focus controls.

## [0.2.1] - 2026-08-20

### Fixed

- Restored normal mouse clicks for the toolbar **+** menu and **Setup** button.
- Replaced window-wide background dragging with explicit titlebar drag regions,
  so dragging the window no longer consumes Action and Dictation masthead
  controls.

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

[0.3.0]: https://github.com/iliawerner/Fixer-app/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/iliawerner/Fixer-app/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/iliawerner/Fixer-app/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/iliawerner/Fixer-app/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/iliawerner/Fixer-app/releases/tag/v0.1.0
