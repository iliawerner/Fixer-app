# Appearance testing

Fixer 0.4.0 (build 6) includes the Light / Dark / Follow System preference. Use this checklist when verifying a release or changing the appearance implementation.

Open the gear button in the Actions workspace. **Appearance** is the first section in Setup. The choice applies immediately to open windows and saves for the next launch. **Follow System** is the default and removes Fixer's appearance override so macOS controls it.

## Manual pass

1. Select Dark, then Light, with Setup open. Check the sheet, the dimmed workspace, text fields, picker, buttons, and native window controls. Dismiss and reopen Setup to verify the selected option.
2. In Dark, open Dictation and an ordinary Action, then Starter Library and History. Check selected/unselected rows, prompt editing and focus, shortcut-conflict warnings, Output selection, and Enabled on/off. Dividers should stay quiet; focus and state indicators should remain visible.
3. Resize the workspace to its minimum size and scroll. Controls must remain reachable. Repeat the main checks in Light.
4. Quit and relaunch with Dark selected, then repeat with Light. Confirm that each saved choice returns without a light flash.
5. Select Follow System. Change macOS Appearance between Light and Dark while Fixer is open, then restore your preferred macOS setting. Verify that explicit Light or Dark ignores the opposite system setting.
6. Check a working/error status card in both themes. The splash poster retains its original artwork; it is not recolored as interface chrome.

The optional isolated launcher from the archived local appearance-testing package uses separate saved settings and sample Actions. It does not register shortcuts, read the real API key, or send provider requests. The public release can be tested by opening `Fixer.app` normally; quit any older running instance before testing actual text/voice runs.

## Automated evidence

`AppearancePreferencesTests` checks persistence, isolation, and invalid-value fallback. `AppearanceControllerTests` checks launch and live mode application, including releasing the system override. The local-only `WorkspaceWindowFactoryTests` verifies that workspace, history, splash, and HUD windows inherit the application appearance.

`FixerThemeTests` checks meaningful foreground contrast in both palettes and guards against overly prominent dark separators. `V2PreviewRenderingTests` produces light/dark screenshots of the workspace, Setup, Starter Library, History, and HUD, and proves that an existing hosting view repaints through Light → Dark → Light.

Regenerate the Xcode project before testing. Follow the locked-package build commands in [DEVELOPMENT.md](DEVELOPMENT.md), passing `FIXER_PREVIEW_DIR` as an Xcode build setting. Tests that create windows remain part of the local macOS gate, not the headless CI gate.
