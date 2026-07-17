# Contributing to Fixer

Thanks for taking a look! Fixer is a small, single-purpose macOS app, so
contributions stay simple.

## Getting set up

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `Fixer.xcodeproj` in Xcode 26+ and press **Run**.

Full build details, the architecture overview, and a map of the code are in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## The `.xcodeproj` is generated — don't commit it

[`project.yml`](project.yml) is the **single source of truth** for the Xcode
project. `Fixer.xcodeproj` is generated from it by XcodeGen and is **git-ignored**.

- To change build settings, targets, files, or dependencies, edit `project.yml`
  and run `xcodegen generate` — never edit the `.xcodeproj` by hand.
- Do **not** commit `Fixer.xcodeproj`. (This avoids the merge conflicts a
  committed, generated project always causes.)

## Things that must not change

Renaming these would break every existing user's saved data:

- The **bundle id** `com.geminimacros.GeminiMacros`
  (`PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`) — keys the saved prompts (UserDefaults).
- The **Keychain service** `com.geminimacros.apikey` (`KeychainManager.swift`) —
  stores the API key.

Both are commented in place. See the "Naming" section in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for why.

## Pull requests

- Keep changes focused; this is a hobby-scale codebase.
- Make sure `xcodegen generate` + a Release build succeed before opening a PR.
  (CI runs this on every PR.)
- Match the surrounding style. Comments should explain **why**, not narrate the
  code.
