# History and recovery validation — 2026-09-08

Branch: `codex/history-recovery`, based on `b2a1e423`.
Environment: macOS 26.6.2 (25G83), Xcode 26.6 (17F113), Apple Silicon.

## Automated checks

- Full hosted suite: **228 tests in 40 suites passed**, including local AppKit
  windows, window-close lifecycle, and visual rendering.
- Real temporary files and private pasteboards cover source durability before
  requests, result durability before delivery, unavailable/changed targets,
  both clipboard preferences, concurrent clipboard writes, and cancellation.
- Recovery tests cover partial Gemini output, failed metadata writes, failed WAV
  encoding, unfinished CAF decoding, interrupted records, corrupt Action arrays,
  duplicate identities, archived backups, retention, and retries that preserve
  completed transcription.
- Release build and static analysis pass. Universal `arm64`/`x86_64`, hardened
  runtime, microphone entitlement, and absence of `get-task-allow` are verified.
- Synchronization conflict copies were compared and removed only after a
  checksum-verified external backup. Project generation rejects new source/test
  conflict copies. The existing unrelated local `memory/` folder is excluded
  from this change.

## Native interface checks

Actual PNGs inspected: History recovery, minimum busy window, empty and corrupt
states, Setup with History preferences, and default/minimum Actions workspaces.

The running QA app used a private `FIXER_DATA_DIR`, fictional source text, a
20-second silent WAV, inert hotkeys, and offline provider responses. Checked:

- Titlebar clock opens the cached History window.
- Failed/interrupted entries and their original text remain after relaunch.
- Retry creates a separate successful record, preserving the original and audio.
- Audio export produces a readable 20-second WAV (640,044 bytes).
- Clipboard fallback can be disabled; the choice and 7-day retention survive
  relaunch. Scrolling reaches the retention explanation.
- Active blue selection has readable white text.
- Playback stops when History closes and remains stopped after reopening.

The last two checks initially exposed defects; both were fixed and verified
again in the rebuilt app. A separate review found direct History Copy racing
paste preparation; all in-app clipboard writes now use one serial manager.

## Limits of this validation

No real Gemini request, microphone recording, or synthetic input into a user's
application was performed. Provider and input boundaries were injected in tests.
Live cross-application compatibility and physical microphone quality remain a
separate release pass. Accessibility cannot verify every editor; those sources
fail safely or use History. Sending Paste is not proof that an app accepted it.
An abrupt crash may lose queued audio frames; recovery keeps the written prefix.
History is local with owner-only file permissions, not separate encryption or a
backup service. This change does not publish or install a new app release.
