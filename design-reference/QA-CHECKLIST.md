# Fixer v2 visual QA checklist

Use this checklist on a real Mac. CI compilation is necessary but not sufficient for native visual, focus, permission, clipboard, and hotkey behavior.

## 1. Establish the exact revision

- [ ] `git status --short --branch` is clean or all local changes are understood.
- [ ] The checked-out branch and commit are recorded with the evidence.
- [ ] `xcodegen generate` was run after the latest `project.yml` change.
- [ ] The old Fixer build is quit before testing global Shortcuts.
- [ ] Test data and credentials are isolated from the published v1 when required.

> **Identity safety:** preview/render tests use injected state and do not read the
> production preferences, Keychain, Gemini service, or Accessibility prompt. A
> direct Run of the repository’s normal target is different: it uses the target
> identities declared in `project.yml` and `Info.plist`. Do not run it beside v1
> or enter a production credential unless that is intentional. A simultaneous
> test install needs a separate bundle identifier, preferences identity, Keychain
> service, and Accessibility identity; renaming the `.app` alone is not isolation.

## 2. Generate deterministic native renders

```sh
mkdir -p .build/design-renders
FIXER_PREVIEW_DIR="$PWD/.build/design-renders" \
  xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY=-
```

Expected files:

- [ ] `.build/design-renders/workspace.png`
- [ ] `.build/design-renders/splash-settled.png`
- [ ] `.build/design-renders/feedback-working.png`
- [ ] `.build/design-renders/feedback-success.png`
- [ ] `.build/design-renders/feedback-error.png`

Inspect every render at 100%. The prototype PNGs are semantic visual references, not pixel-golden files.

## 3. Workspace

Compare with [`prototype/workspace.png`](prototype/workspace.png).

- [ ] At `900 × 620`, the Actions list and editor remain usable without clipped controls.
- [ ] The selected Action is the first visual anchor in the list and detail.
- [ ] Search, add Action, and starter-library access are easy to find.
- [ ] The visible vocabulary is Actions, Shortcut, Prompt, Output, and Model.
- [ ] No Vault, History, drag/reorder promise, or Action Type switch appears.
- [ ] Prompt editing remains the dominant working area rather than decorative cards.
- [ ] Replace and Append are distinguishable before running.
- [ ] Shortcut conflicts or missing Shortcuts are communicated in text/shape as well as color.
- [ ] Disabled Actions remain identifiable and reversible.
- [ ] Keyboard traversal follows the visible editor order.
- [ ] Focus rings are visible against paper and yellow surfaces.
- [ ] Long Action names, prompts, and model identifiers wrap or truncate deliberately.

## 4. Provider setup

Compare with [`prototype/provider-setup.png`](prototype/provider-setup.png) for hierarchy only.

- [ ] Keychain storage and Gemini data flow are stated plainly.
- [ ] A key is never shown in full by default.
- [ ] Missing, saved, validating, valid, rejected, and read-failure states are textually distinct.
- [ ] Keychain read failure does not claim the credential is absent.
- [ ] Remove key remains available when a credential may still exist.
- [ ] Save, read, validation, and removal errors use operation-specific wording.
- [ ] Model loading cannot validate a changed or removed credential with a stale response.
- [ ] Setup controls are reachable by keyboard and have meaningful accessibility labels.

## 5. Starter library

Compare with [`prototype/starter-library.png`](prototype/starter-library.png).

- [ ] Names and descriptions scan quickly at normal window size.
- [ ] Already-added starters are clearly marked without duplicate visual noise.
- [ ] Adding a starter leads to the missing-Shortcut requirement.
- [ ] The sheet/list remains usable by keyboard and with increased text size.

## 6. Menu bar

Compare with [`prototype/menu-bar.png`](prototype/menu-bar.png) for density and status order.

- [ ] Ready, processing, permission, and last-error states are understandable at a glance.
- [ ] Only current Actions and implemented commands are shown.
- [ ] Open Settings, Show Splash, and Quit are easy to locate.
- [ ] Opening settings, replaying splash, or handling reopen is blocked/deferred during processing.
- [ ] The menu does not promise Vault or History.

## 7. Passive run feedback

Compare with the three `prototype/hud-*.png` files for footprint and hierarchy.

- [ ] Working HUD appears without activating Fixer.
- [ ] The original target app keeps keyboard focus throughout copy → model → paste.
- [ ] The Action name is more prominent than the technical state.
- [ ] A second Shortcut during processing does not start another run.
- [ ] Success copy does not claim the target accepted the paste.
- [ ] Error remains readable longer than success.
- [ ] Full last-error text remains available from the persistent menu surface.
- [ ] The HUD contains no buttons, links, or focusable controls.
- [ ] There is no fake progress percentage or moving progress track.
- [ ] Working/success fit `368 × 88`; error fits `380 × 132` without clipping.
- [ ] HUD placement respects the active screen’s visible frame and lower edge.
- [ ] Reduce Motion removes activity animation without removing status text.

## 8. Splash identity

Compare at full size with [`identity/splash-master.png`](identity/splash-master.png).

- [ ] Japanese title, `FIXER`, character, complete feet, bandage, sun, mountain, lake, trees, birds, and side signs are present.
- [ ] The five native layers align into the approved composition.
- [ ] Paper overscan prevents edge gaps at maximum pointer displacement.
- [ ] Typography and side signs stay crisp while scene layers move.
- [ ] Parallax is restrained and settles; it does not feel like a 3D card demo.
- [ ] No layer tears, seams, transparent holes, or cropped feet appear.
- [ ] Reduce Motion produces a complete static composition.
- [ ] Mouse close, `Esc`, and the accessible close control all work.
- [ ] Manual replay works without changing first-launch policy.
- [ ] Automatic first-launch handoff waits until processing is idle.

## 9. Real pipeline smoke test

Run in at least one native text editor and one browser text field:

- [ ] Grant Accessibility and confirm Fixer notices without restart.
- [ ] Trigger Replace on selected text.
- [ ] Trigger Append on selected text.
- [ ] Verify the target app—not Fixer—receives the synthetic paste.
- [ ] Verify clipboard restoration after success and failure.
- [ ] Copy new content during a run and confirm Fixer does not overwrite that newer clipboard content.
- [ ] Trigger with nothing selected and inspect the resulting error.
- [ ] Trigger while another Action is processing and confirm no overlap.
- [ ] Revoke Accessibility and confirm the failure is visible and actionable.

## 10. Record the result

For every approval or rejection, record:

- branch and commit;
- macOS and Xcode versions;
- display scale and Reduce Motion state;
- screenshots for the affected states;
- exact divergence from `VISUAL_SPEC.md`;
- whether the difference is a bug, a deliberate native adaptation, or an outdated reference.

Do not replace reference images merely to make a test pass. Update them only after an explicit design decision.
