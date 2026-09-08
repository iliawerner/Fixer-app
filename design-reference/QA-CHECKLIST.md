# Fixer v2 visual QA checklist

Use this checklist on a real Mac. CI compilation is necessary but not sufficient for native visual, focus, permission, clipboard, and hotkey behavior.

## 1. Establish the exact revision

- [ ] `git status --short --branch` is clean or all local changes are understood.
- [ ] The checked-out branch and commit are recorded with the evidence.
- [ ] `./scripts/generate-project.sh` was run after the latest `project.yml` or `Package.resolved` change.
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
./scripts/generate-project.sh
mkdir -p .build/design-renders
xcodebuild test \
  -project Fixer.xcodeproj \
  -scheme Fixer \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  FIXER_PREVIEW_DIR="$PWD/.build/design-renders" \
  CODE_SIGN_IDENTITY=-
```

Expected files:

- [ ] `.build/design-renders/workspace-default.png`
- [ ] `.build/design-renders/workspace-minimum.png`
- [ ] `.build/design-renders/workspace-expanded.png`
- [ ] `.build/design-renders/splash-settled.png`
- [ ] `.build/design-renders/feedback-working.png`
- [ ] `.build/design-renders/feedback-listening.png`
- [ ] `.build/design-renders/feedback-success.png`
- [ ] `.build/design-renders/feedback-error.png`
- [ ] `.build/design-renders/feedback-working-reduced-motion.png`
- [ ] `.build/design-renders/feedback-error-large-text.png`

Inspect every render at 100%. The prototype PNGs are semantic visual references, not pixel-golden files.

Determinism requirements:

- [ ] Preview state is injected; rendering does not read the production
      UserDefaults, Keychain, Accessibility state, global shortcuts, or network.
- [ ] The complete workspace matrix uses the same documented Actions/provider
      fixture and these exact presentations:

  | Render | Canvas | Contract under test |
  |---|---:|---|
  | `workspace-default.png` | `820 × 720` | Default launch geometry and hierarchy |
  | `workspace-minimum.png` | `760 × 620` | Minimum usable geometry, scrolling, and clipping |
  | `workspace-expanded.png` | `1440 × 900` | Bounded Dictation settings without a stretched `100 pt` masthead, a reintroduced footer, or decorative voids |

- [ ] `feedback-working-reduced-motion.png` exercises the directly injected
      static-motion branch. Policy/unit tests and an obligatory live pass still
      verify the real system setting because SwiftUI's accessibility Reduce
      Motion environment is read-only in the supported macOS 13 hosted renderer.
- [ ] `feedback-error-large-text.png` proves that long multiline copy grows the
      HUD card without clipping. Actual Increased Text and Dynamic Type remain an
      obligatory live accessibility pass because the supported macOS 13 hosted
      renderer can ignore a synthetic `sizeCategory`.
- [ ] `splash-settled.png` uses the explicit settled presentation at zero tilt;
      it does not depend on sleeping until an animation happens to finish.
- [ ] Splash render assertions pass for transparent corners and the bounded
      opaque/dark/yellow/luminance evidence of the complete five-layer artwork.
- [ ] HUD state PNGs are captured before or after transient motion, never midway
      through an entry or copy crossfade. Across working, listening, success, and error,
      they show one compact warm-neutral card and no visible **FIXER** wordmark.
      Working/busy shows the Action name once; success says **Text replaced** or
      **Text appended**; error gives one concrete reason and next step. Listening
      uses the injected measured level and does not invent a waveform or partial
      transcript.
- [ ] Repeating the render command at the same revision produces the same layout,
      copy, visible layers, and alpha/background contract.

Static evidence proves composition, hierarchy, size, clipping, and transparent
window margins. It cannot prove inertia, morph continuity, pulse suppression, or
focus retention. Capture those in the live sections below.

Workspace PNGs contain the hosted SwiftUI view without the final system frame.
They cannot prove the macOS 26 corner shape, window shadow, or traffic-light
stacking. Use the window factory tests and a live macOS 26 screenshot for that
evidence.

## 3. Workspace

Compare with [`prototype/workspace.png`](prototype/workspace.png).

- [ ] The window opens at `820 × 720`, permits `760 × 620`, and does not
      default to a near-full-screen administrative layout.
- [ ] The layout's natural total width is `817 pt`; at the `820 pt` default, no
      decorative empty strip remains after the editor controls.
- [ ] On macOS 26, the workspace uses the current rounded shape of a standard
      titled window. No custom mask or hard-coded workspace corner radius exists.
- [ ] Content reaches the top edge under a transparent titlebar with no titlebar
      separator or empty strip. The sidebar and detail draw only their deliberate
      `40 pt` and `100 pt` lower rules instead.
- [ ] The native close, minimize, and zoom controls remain visible above content.
      The standard itemless toolbar uses `.unifiedCompact`. Traffic lights, the
      add and Setup controls share the sidebar's `y = 20 pt` control axis without
      creating a second title strip.
- [ ] The sidebar shows no visible **Actions** or **New** titlebar words. Its exact
      horizontal grouping is traffic lights → icon-only `28 × 28 pt` **+** at
      `x = 88 pt` → flexible space → trailing `28 × 28 pt` **Setup**.
- [ ] The sidebar titlebar is exactly `40 pt`; the yellow Action masthead is
      exactly `100 pt`. Their lower rules end at deliberately different heights.
      No doubled line, one-pixel near miss, or fake shared baseline is visible at
      the split.
- [ ] No visible product name, logo, or slogan appears in the workspace window.
- [ ] The sidebar targets `292 pt` and stays within `280 ... 320 pt` during normal
      resizing.
- [ ] At `760 × 620`, the Actions list and editor remain usable without
      clipped controls. Scrolling begins at a deliberate boundary.
- [ ] After selecting an ordinary Action at `1440 × 900`, extra height grows the
      Prompt editor first. It does not
      stretch the masthead, recreate a sidebar footer, or create a framed
      decorative void.
- [ ] In an ordinary Action, the name is the first visual anchor, followed by
      Prompt, Shortcut, Output, Model, then Enabled.
- [ ] Prompt, Shortcut, Output, Model, and Enabled use one vertical column at all
      workspace sizes. No settings pair changes into a side-by-side layout.
- [ ] The leading-aligned editor column never exceeds `480 pt`; the Prompt input
      follows the same width instead of creating trailing empty space.
- [ ] No search field appears. The icon-only **+** is easy to find and opens a
      menu containing exactly **Blank Action** and **From Starter Library**.
- [ ] Choosing **Blank Action** creates one blank Action; choosing **From Starter
      Library** opens the library without creating an Action first. Both commands
      have usable keyboard focus, accessibility names, and deterministic ordering.
- [ ] **Setup** appears once as the separate trailing sidebar-titlebar icon. It
      stays available when complete, shows issue status only while incomplete,
      explains that status without relying on color, and is not repeated in a
      footer, banner, or detail pane.
- [ ] No bottom sidebar footer is present at any workspace size.
- [ ] Exactly one protected **Dictation** Action is pinned as the first row. It
      uses one quiet microphone glyph plus its name and Shortcut, without an
      enabled dot or extra status badge.
- [ ] The visible vocabulary is Actions, Dictation, Shortcut, Prompt, Output,
      Model, Recognition, and Enabled where each applies.
- [ ] No Vault, History, drag/reorder promise, or Action Type switch appears.
- [ ] For an ordinary Action, Prompt is the first section below the masthead and
      its default editable height remains within `160 ... 220 pt`. Two lines of
      content do not produce a mostly empty editor.
- [ ] Section spacing follows the compact `12 / 16 / 20 pt` rhythm and is roughly
      `25 ... 35%` tighter than the superseded workspace.
- [ ] The Action editor masthead is full signal yellow and exactly `100 pt` high
      at every workspace render size.
- [ ] A subtle static `18 pt` square grid gives the yellow surface texture. It is
      low contrast, non-interactive, and does not imply progress or measurement.
- [ ] No ruler, growing underline, moving rule, or progress-like line appears.
- [ ] An ordinary Action masthead contains the editable Action name and reachable `…` menu. It does
      not contain an Action number, enabled state/dot, Shortcut, save status, or
      repeated bandage/logo.
- [ ] When Dictation is selected, the same exactly `100 pt` yellow/grid masthead
      contains its fixed microphone/name identity and no editable title, `…`
      menu, or disabled menu placeholder.
- [ ] An ordinary Action's large name sits near the masthead's bottom-left and remains the
      first visual anchor. The `28 × 28 pt` `…` control sits at the top-right;
      neither pretends to share a baseline with the sidebar controls.
- [ ] Hover and focus make name editing discoverable. `Return` commits and
      `Escape` cancels without leaving a stale caret or draft.
- [ ] A sidebar row shows only name and Shortcut. Selection has one coherent
      background/typographic treatment and no enabled dot, number, or extra rail.
- [ ] Enabled appears once through the compact custom `ToggleStyle` and nowhere
      as a duplicate status summary. Its track is `38 × 22 pt`, and thumb position
      communicates state without color.
- [ ] Replace and Append use the warm custom selector at no more than `300 pt`
      wide. A checkmark, restrained warm surface, and text distinguish the
      selected mode without competing with the Action masthead.
- [ ] The Output selector and Enabled toggle do not introduce the unrelated blue
      native selection color into the warm workspace.
- [ ] The Shortcut recorder clearly communicates idle, focused/recording, clear,
      missing, and internal-conflict states. All remaining Shortcut renderings use
      the same symbols and order.
- [ ] Shortcut conflicts or missing Shortcuts are communicated in text/shape as well as color.
- [ ] Disabled Actions remain identifiable and reversible.
- [ ] The normal Model picker shows a friendly model name. **Custom Model ID** is
      an explicit editable path. A raw `models/...` identifier is not presented
      as the normal user-facing value.
- [ ] **Insert `{text}`** sits in the Prompt toolbar. Prompt prose uses the system
      UI font. `{text}`, Shortcut notation, and raw model IDs may use monospace.
- [ ] `{voice}` sits beside `{text}` in an ordinary Prompt toolbar and has the
      same compact token treatment rather than becoming a page-level action.
- [ ] The Dictation editor contains one vertical sequence: Shortcut, warm
      **Press again** / **Hold** control, recognition/privacy disclosure, and
      Enabled. Prompt, Output, Model, Duplicate, and Delete are absent.
- [ ] Dictation copy says recognition is Gemini-based, language is automatic
      including mixed-language speech, audio is sent to Google Gemini, and Fixer
      does not save recordings. It does not imply Apple/on-device recognition.
- [ ] Duplicate Action and Delete Action live in the selected Action's `…` menu,
      not in a detached bottom bar. Delete remains destructive and confirms the
      exact Action name.
- [ ] Autosave wording, if visible, says **All changes saved** and cannot be read
      as a claim that selected text is processed locally.
- [ ] Keyboard traversal follows the visible editor order.
- [ ] Focus rings are visible against paper and yellow surfaces.
- [ ] Long Action names, prompts, and model identifiers wrap or truncate deliberately.
- [ ] The icon-only `28 × 28 pt` **+** and **Setup** controls have distinct hover,
      press, and keyboard-focus feedback without permanent labelled capsules.
      Tooltips and accessibility names make both purposes unambiguous.
- [ ] Action rows, the add and Setup controls, the Action `…` menu, Output, Enabled,
      **Custom Model ID**, and primary/secondary buttons all expose coherent
      hover feedback before activation.
- [ ] Hover, focus, and press states do not move, resize, or reflow controls.

### Workspace motion and focus acceptance

Record this section on a real running build. Settled PNGs are insufficient.

- [ ] Selecting another Action uses the shared steep ease-in/ease-out motion and
      settles in `0.34 s`, without bounce or independent section timing.
- [ ] Editor replacement exits in `0.12 s` and enters in `0.24 s`. The old editor
      reaches zero opacity before the binding identity changes.
- [ ] Control and focus feedback use the responsive `0.18 s` and `0.16 s`
      timings. Pointer hover uses `0.11 s`; press uses `0.09 s`. None make the
      application feel delayed.
- [ ] Create, duplicate, delete, disclosure, and Output changes preserve spatial
      continuity and use the same responsive eased motion family where structure
      changes.
- [ ] Typing, saving, keyboard traversal, opening the `…` menu, and destructive
      confirmation respond immediately even while the visual transition settles.
- [ ] Switch between at least three Actions faster than the transition duration.
      The animation retargets or cancels cleanly. The final masthead, Prompt,
      Shortcut, Model, Enabled value, focus owner, and persistence binding all
      belong to the last selected Action.
- [ ] Rapid switching never flashes an earlier Action back into the masthead or
      Prompt, commits typed text to a different Action, or leaves two editors
      simultaneously visible.
- [ ] Start editing an Action name, then test `Return`, `Escape`, sidebar click,
      `Tab`, and rapid Action switching. Focus lands in a visible valid control and
      no production screenshot retains an accidental caret.
- [ ] Hover feedback is quicker and quieter than structural motion. Repeated
      pointer movement does not queue long-running animations, and hover/press
      feedback never changes layout geometry.
- [ ] With Reduce Motion enabled, the same state changes use opacity only. There
      is no displacement, scale, blur, bounce, or continuous loop. Structural
      insertion and removal do not interpolate, spatial press transforms are
      absent, and every control works at once.

### Workspace accessibility acceptance

Run this section manually with the system's increased-text/accessibility setting.
Do not infer it from a hosted PNG.

- [ ] At both `820 × 720` and `760 × 620`, increased text remains legible.
      Controls do not overlap and essential labels are not clipped.
- [ ] The yellow masthead stays exactly `100 pt` high. Its Action name wraps
      or truncates deliberately, and the `…` menu remains reachable.
- [ ] Prompt, Shortcut, Output, Model, and Enabled preserve reading and keyboard
      focus order when labels or helper text occupy more than one line.
- [ ] The custom ToggleStyle, custom Output selector, Shortcut recorder, Model
      picker, Action menu, and destructive confirmation expose visible focus and
      usable hit targets.
- [ ] VoiceOver announces the selected Action, editable name, Shortcut state,
      Enabled value, Output choice, Model choice, and destructive operations
      without relying on color or spatial position.
- [ ] For Dictation, VoiceOver announces the fixed identity, Shortcut, selected
      activation behavior, recognition/privacy disclosure, and Enabled state in
      visible order.

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
- [ ] With permission/key setup incomplete, the single titlebar Setup icon exposes
      a non-color issue cue and truthful accessibility value. After completion,
      the issue cue disappears while the same Setup entry remains available.
- [ ] Microphone permission is not part of general Setup readiness. A user who
      never invokes Dictation or `{voice}` sees no microphone prompt or new Setup
      issue.

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
- [ ] Fixer never takes keyboard focus during copy → model → paste. If the user
      does not change focus, the original target remains active throughout.
- [ ] Automated panel checks confirm one transparent borderless
      `.nonactivatingPanel`: it cannot become key/main, ignores mouse events, and
      has no operating-system shadow.
- [ ] The HUD is a small warm-neutral status card with near-black text, a
      restrained shadow, thin outline, and a familiar progress, check, or error
      symbol. It contains no paper, grid, stitch, seam, seal, or repair metaphor
      and does not look like a dark system banner or miniature settings window.
- [ ] No visible **FIXER** branding appears. Working and busy render the current
      Action name exactly once with one concise status phrase. Success uses
      **Text replaced** or **Text appended**. Error leads with one concrete
      reason and a useful next step—never a second title or technical stack.
- [ ] The working card becomes visible immediately after the Shortcut registers.
      Its short entry finishes within about `200 ms`; motion never delays
      acknowledgement or makes Fixer feel unresponsive.
- [ ] Working → success is one continuous state change: the card shell remains visible
      and stationary while semantic copy and glyph change.
- [ ] Working → error uses the same persistent panel/SwiftUI host and does not
      blink, stack, or briefly expose the desktop between cards.
- [ ] During working, one standard indeterminate progress indicator is visible.
      It does not claim measurable progress, loop aggressively, or add a second
      moving progress track.
- [ ] Voice uses the same panel and shell across Preparing → Listening →
      Finishing → Transcribing → optional Applying → result. No phase opens a
      second window, steals focus, blinks, or changes the established compact
      card geometry.
- [ ] Listening replaces the spinner with literal measured microphone-level bars.
      Silence settles near zero; speech visibly changes them. There is no fake
      waveform, transcript, percentage, or autonomous decorative loop.
- [ ] Pre-upload Escape changes the same card to **Dictation cancelled** and
      **No audio was sent.** Escape is not advertised once Transcribing begins.
- [ ] A changed or exactly unverifiable target resolves to **Copied — return and
      paste** with the result left on the clipboard. The HUD does not claim that
      insertion succeeded and Fixer does not reactivate the old app.
- [ ] Success crossfades to a standard check symbol and the exact outcome text.
      Append copy does not imply replacement and no completion effect loops.
- [ ] Error crossfades to a standard error symbol plus one direct readable reason
      and next step inside the same card, without stacking or replacing the panel.
- [ ] The semantic status is the primary information; the Action name is quiet
      context shown only while working or acknowledging a busy trigger.
- [ ] A second Shortcut during processing does not start another run.
- [ ] Success copy does not claim the target accepted the paste.
- [ ] Error remains readable longer than success.
- [ ] Full last-error text remains available from the persistent menu surface.
- [ ] The HUD contains no buttons, links, or focusable controls.
- [ ] There is no fake progress percentage or moving progress track.
- [ ] The card fits the phase-specific `HUDLayout` footprint without clipped copy,
      symbols, or shadow at default and increased text size.
- [ ] HUD placement respects the active screen’s visible frame and lower edge.
- [ ] With Reduce Motion enabled, all status text and symbols remain, structural
      transitions use opacity only, and there is no vertical offset, spring
      inertia, pulse, scale, rotation, or decorative loop. The working indicator
      may become a clear static symbol instead of spinning.

Record both a Replace and Append sequence on video when HUD motion changes. A
single screenshot cannot establish that the panel identity persisted or that a
phase crossfade stayed within one host. Record the external focus owner before
appearance, during working, and after success/error; Fixer must never activate.
Record one voice sequence as well, including measured listening feedback,
Transcribing, and either insertion or the changed-target clipboard notice.

## 8. Splash identity

Compare at full size with [`identity/splash-master.png`](identity/splash-master.png).

- [ ] Japanese title, `FIXER`, character, complete feet, bandage, sun, mountain, lake, trees, birds, and side signs are present.
- [ ] The five native layers align into the approved composition.
- [ ] The borderless AppKit window is clear and non-opaque with its OS shadow
      disabled.
- [ ] Desktop content remains visible in every window corner; no black, dimmed,
      paper-colored, or otherwise rectangular stage appears behind the card.
- [ ] The clear overscan leaves at least `60 pt` around the fitted card and the custom
      two-stage shadow remains visible without clipping at maximum tilt.
- [ ] Artwork, overlay typography, border, glare, close control, and shadow read as
      one coherent 3D card; no element remains on a flat plane while it rotates.
- [ ] Paper overscan prevents edge gaps at maximum pointer displacement.
- [ ] Pointer coordinates clamp to `-1 ... 1` on both axes and center resolves to
      zero tilt.
- [ ] Center-to-edge and diagonal pointer positions never rotate beyond `6°`.
- [ ] Typography and side signs stay crisp while bounded scene layers move.
- [ ] The card follows the pointer with spring inertia and returns to exact zero
      tilt after pointer exit without oscillating indefinitely.
- [ ] The broad specular highlight and directional edge light move with pointer
      tilt and stop moving after the card settles; neither runs autonomously.
- [ ] No layer tears, seams, transparent holes, or cropped feet appear.
- [ ] `splash-settled.png` is centered at zero tilt, contains all five layers, and
      has transparent corners outside the custom shadow.
- [ ] Reduce Motion produces the same complete settled composition immediately:
      no entrance offset/scale, staged layers, pointer parallax, spring inertia,
      travelling highlight, or pulse.
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
- [ ] On an abort/failure path, copy new content after Fixer's selection capture
      and confirm conditional restore leaves that newer content intact.
- [ ] On a success path, copy new content during the network wait and confirm it
      is restored after Fixer pastes the generated result.
- [ ] During the result-paste settle interval, make another app write to the
      clipboard and confirm that still-newer value wins over Fixer's backup.
- [ ] Trigger with nothing selected and inspect the resulting error.
- [ ] Trigger while another Action is processing and confirm no overlap.
- [ ] Revoke Accessibility and confirm the failure is visible and actionable.
- [ ] Before any voice run, confirm general Setup can be complete without
      Microphone permission and that no microphone prompt appears at launch.
- [ ] Invoke Dictation and confirm macOS requests Microphone access lazily. Deny
      once and verify a concrete recovery message; grant it and retry without
      disturbing text Actions.
- [ ] In **Press again** mode, one Shortcut press starts and the second stops. In
      **Hold** mode, key-down starts, keyboard repeat does not restart capture,
      and key-up stops even when held modifiers include Command or Shift.
- [ ] In both activation modes, make `{text}` unavailable through Accessibility.
      Confirm the run fails before microphone capture and posts no Command-C.
- [ ] Dictate plain Russian, plain English, and mixed Russian/English speech.
      Confirm `gemini-3.7-flash` returns only a punctuated transcript without
      translating, answering, or adding a label.
- [ ] Plain Dictation inserts the transcript directly and does not run an
      ordinary text Action afterward.
- [ ] Run an ordinary Action containing both `{text}` and `{voice}`. Confirm each
      original token occurrence is substituted once and token-looking text inside
      the selection or transcript remains literal.
- [ ] Run a `{voice}` Action without `{text}` in **Append** mode. Confirm the
      original selection is preserved above the generated result; an unavailable
      AX selection must fail before microphone capture in either activation mode.
- [ ] Run a `{voice}` Action without `{text}` and confirm Fixer does not post
      synthetic Command-C before recording when Output mode is **Replace**.
- [ ] Press Escape while preparing/listening. Confirm capture stops, the target
      is unchanged, and no Gemini request is made. Once Transcribing begins,
      confirm the UI no longer promises cancellation.
- [ ] Keep the original field focused through both text and voice runs and confirm it receives
      the result. Repeat while switching to another app, another field in the
      same app, and a context where the AX element cannot be verified: no
      Command-V is posted, and the final result remains in History. With fallback
      enabled it is also copied; with fallback disabled the clipboard stays intact.
- [ ] Exercise the five-minute boundary through the injected capture-policy test
      (or a deliberate live long run) and confirm it stops cleanly. Verify the
      inline WAV is 16 kHz mono and bounded below the upload guard.
- [ ] Inspect History after success, failure, and cancellation: the available
      original, transcript, result, error, and recording are retained locally.
- [ ] Stop during encoding or simulate a provider failure; export and retry the
      saved recording. Simulate an interrupted process and recover its CAF prefix.
- [ ] Open History via the clock beside Setup while processing; confirm the
      original paste target is no longer used and active records cannot be deleted.
- [ ] Play a saved recording and close History; audio stops. Reopen and verify
      playback remains stopped. Check active/inactive selected-row contrast.
- [ ] Retry after successful transcription and failed generation; transcription
      is not repeated, the original entry stays, and output never pastes to an old target.
- [ ] Verify Setup clipboard and retention preferences survive relaunch. Expiry
      removes old successful/cancelled records, preserving failed/interrupted ones.
- [ ] Clear a fixture History containing corrupt records; confirm active runs and
      external symlink targets are kept, and only the explicitly cleared data is removed.

## 10. Record the result

For every approval or rejection, record:

- branch and commit;
- macOS and Xcode versions;
- display scale and Reduce Motion state;
- screenshots for deterministic settled states and a screen recording for any
  changed transition, spring, progress indicator, pulse, or pointer response;
- exact divergence from `VISUAL_SPEC.md`;
- whether the difference is a bug, a deliberate native adaptation, or an outdated reference.

Do not replace reference images merely to make a test pass. Update them only after an explicit design decision.
