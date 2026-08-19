# Fixer v2 visual specification

This specification separates the approved identity and information hierarchy from exploratory details in the original web prototype.

## Product posture

Fixer is a native background utility, not a web dashboard. It should feel compact,
legible, tactile, and operational. Visual character comes from warm paper,
near-black ink, one decisive signal-yellow surface, a quiet square grid, and the
approved illustrated identity—not from decorative UI density.

The interface must remain effective before impressive:

- one primary identifier per surface;
- plain product language;
- information visible where the decision is made;
- responsive eased workspace motion that never delays typing or obscures state;
- no ornamental chips, repeated labels, or competing cards;
- no interaction that risks stealing the synthetic-paste target.

## Locked palette

The current native tokens in `Sources/FixerTheme.swift` are authoritative:

| Role | Value |
|---|---|
| Warm paper | `#F2EAD8` |
| Raised panel | `#F7F1E4` |
| Quiet secondary surface | `#E9E0CE` |
| Hairline rule | `#D8CEBB` |
| Strong rule / field border | `#BFB4A0` |
| Signal yellow | `#F4BF00` |
| Dark yellow | `#C99500` |
| Yellow wash | `#FFF0A6` |
| Primary ink | `#14130F` |
| Dim ink | `#454139` |
| Muted text | `#655F55` |
| Quiet text | `#9A9488` |
| Confirmed/safe | `#2F8A52` |
| Error text | `#A4362D` |

Signal yellow has one dominant workspace role: the Action masthead. Outside
that header, keep it scarce. The compact Enabled track may use yellow when on,
and the Output selector may use the quieter yellow wash. Do not repeat solid
yellow across selection, status, and decoration merely to brand the screen.

## Typography

- Use native macOS system typography for product names, action names, controls, and body copy.
- Use monospaced system typography for shortcuts, model identifiers, and technical details.
- Large action headings may be visually dominant, but must not crowd the editor or force routine information below the fold.
- Do not import the web prototype’s Google fonts into the native app.
- Text must remain usable under Dynamic Type/accessibility scaling supported by the macOS control.

## Workspace

Reference: [`prototype/workspace.png`](prototype/workspace.png)

### Preserve

- Native master-detail structure.
- Compact Actions list on the left. Selected Action editor on the right.
- Action name as the strongest identifier in both list and detail.
- Clear selected state with text/shape contrast, not color alone.
- Visible Shortcut state and unfinished/conflict state where the Shortcut is
  edited, not repeated across the screen.
- Prompt, Shortcut, Output, Model, and enabled state arranged as operational
  settings—not marketing cards.
- Immediate persistence. No Save button.
- Default workspace size: `820 × 720`.
- Minimum practical workspace size: `760 × 620`.
- Natural total width: `817 pt`, leaving only `3 pt` of slack at the default
  width rather than a decorative trailing strip.
- Sidebar target width: `292 pt`. Keep it within the compact `280 ... 320 pt`
  working range rather than allowing it to dominate the window.

### Geometry and information order

- The editor follows one stable reading order: Action name, Prompt, Shortcut,
  Output, Model, then the single Enabled control.
- Prompt, Shortcut, Output, Model, and Enabled form one vertical column at every
  window size. Do not place settings in side-by-side columns.
- Keep the settings column at a readable maximum width. The current contract is
  `480 pt`, aligned to the leading edge of the detail pane.
- Prompt is the first editable section below the masthead. Its initial height is
  `160 ... 220 pt`. It may grow with the window but must not consume unused
  height merely to fill the page.
- Reduce the old section spacing by roughly `25 ... 35%`. Prefer a compact
  `12 / 16 / 20 pt` rhythm for related controls, sections, and major boundaries.
- Additional window height belongs first to the Prompt editor and only then to
  breathing room between groups. Do not stretch the fixed masthead, and do not
  reintroduce a sidebar footer.
- Two Actions should leave an honest quiet list background below the rows, not a
  framed decorative sheet pretending to contain more content.
- Keep secondary Action operations out of the page footer. Put **Duplicate
  Action** and **Delete Action** in the Action's `…` menu near its name. Deletion
  remains destructive and requires confirmation.

### Sidebar

- Use one `40 pt` titlebar plane established by the standard AppKit window's
  itemless `.unifiedCompact` toolbar. The traffic lights and all SwiftUI titlebar
  controls share its `y = 20 pt` axis.
- Do not place visible **Actions** or **New** words in the titlebar. After the
  traffic lights, place one icon-only `28 × 28 pt` **+** menu whose leading edge
  is `x = 88 pt`. Its commands are exactly **Blank Action** and **From Starter
  Library**.
- Give the **+** distinct hover, press, and keyboard-focus states without adding
  a permanent labelled capsule. Its tooltip and accessibility name communicate
  that it creates an Action, while each menu command names the specific route.
- Keep one separate trailing **Setup** icon in this same sidebar plane. It remains
  available after setup is complete, but shows an issue/status treatment only
  while setup is incomplete. It is not a second create command.
- Do not show the product name, logo, or slogan in the workspace window.
- Do not show a search field. The current action count does not justify its
  permanent space cost. Revisit search only after a measured retrieval problem.
- A row contains the Action name and its Shortcut only. Selection needs one
  coherent background/typographic treatment. Do not add a yellow enabled dot,
  action number, rail, or redundant state badge.
- Do not keep a bottom sidebar footer. Starter-library entry belongs inside the
  **+** menu, and **Setup** appears once as the separate trailing titlebar icon.
- A colored dot or square alone is not a setup message. The incomplete state must
  also have an accessibility value, tooltip, or menu/sheet copy that explains the
  issue.

### Window and titlebar

- Use a standard titled AppKit window. The running macOS release owns the window
  corner radius, outer shape, shadow, resize affordance, and traffic lights.
- Do not draw a custom workspace mask or hard-code a corner radius. On macOS 26,
  the standard window supplies the larger current system radius.
- Use a full-size content view under a transparent hidden titlebar. Remove the
  AppKit titlebar separator and extend the workspace content to the top edge.
- Install an itemless `.unifiedCompact` toolbar to establish the native compact
  titlebar geometry while the SwiftUI controls remain inside the full-size
  content plane.
- Keep the traffic lights visible above the hosted content. Do not place an empty
  strip above the icon-only add control or the yellow Action identity.
- Start the yellow Action masthead at that same top edge in the detail pane, but
  keep it exactly `100 pt` high while the native sidebar titlebar remains `40 pt`.
- End the sidebar titlebar rule at `y = 40 pt` and the yellow masthead rule at
  `y = 100 pt`. This step is deliberate: never extend, double, or offset either
  rule to imply a shared baseline that the two surfaces do not have.
- Keep a useful hidden window title for accessibility and the Window menu. Do not
  paint the product name inside the window.

### Adapt natively

- Window chrome and toolbar treatment.
- Split-view width behavior, scrolling, focus rings, menus, text fields, and sheets.
- Keyboard and accessibility semantics for custom controls.
- Font metrics and exact spacing.

### Action editor header

The selected Action gets one characteristic yellow masthead. It creates clear
scale contrast with the compact navigation chrome without returning to the old
oversized hero banner.

- Fill the masthead with signal yellow across the detail pane.
- Keep it exactly `100 pt` high at every window size. The native sidebar titlebar
  stays `40 pt`; the two areas intentionally end at different vertical positions.
  The masthead is intrinsically sized and never absorbs spare vertical space.
- Draw a static, very low-contrast square grid across the yellow surface. The
  current cell size is `18 pt`. The grid is decorative and ignores input.
- Do not add a ruler, growing underline, progress-like rule, or animated line.
- The editable Action name is the only status-like content in the masthead and
  remains its strongest text. Remove `ACTION 01`, enabled copy/dots, Shortcut
  summaries, save indicators, and the repeated bandage mark.
- Place the large editable Action name near the masthead's bottom-left edge. Keep
  it as the strongest workspace identifier and give it enough trailing clearance
  to avoid the options control.
- Keep the `28 × 28 pt` `…` options control at the masthead's top-right. It does
  not share a baseline with the title or the sidebar controls.
- Make name editing discoverable through a stationary hover/focus surface.
  `Return` commits, `Escape` cancels, and no underline grows during focus.
- Keep the Action `…` menu available at the top-right without competing with the
  name.
- At narrow widths and increased text size, the name truncates or wraps
  deliberately while the menu remains reachable. The masthead does not grow past
  its `100 pt` contract.

The yellow masthead is an identity anchor, not permission to repeat yellow through
the rest of the editor.

### Editor controls and copy

- Keep Enabled as the only canonical enabled state. Use the compact custom
  `ToggleStyle` with a `38 × 22 pt` track and a position-changing thumb.
- Use Fixer's warm yellow, paper, and ink states for the toggle. Do not import the
  unrelated blue system switch appearance.
- Use the compact custom Replace / Append selector. Keep it at no more than
  `300 pt` wide. Give the selected segment a checkmark, clear text contrast, and
  a restrained warm surface.
- Preserve Button, keyboard, focus, selection, and VoiceOver semantics in both
  custom controls. Do not use color as the only state cue.
- Give the Shortcut recorder an explicit recording state, visible focus ring,
  clear affordance with a tooltip, and a local conflict/error message. Render the
  Shortcut consistently everywhere it remains visible.
- Show a friendly model name in the normal picker. Expose **Custom Model ID** as
  an explicit editable path. Show the technical `models/...` identifier only in
  that path or as quiet secondary detail.
- Keep **Insert `{text}`** inside the Prompt toolbar rather than styling it as a
  page-level action. Prompt prose uses the system UI font. Reserve monospace for
  `{text}`, Shortcuts, and model IDs.
- Use concise helper text. Prefer `Use {text} to position the selected text.
  Otherwise it is added at the end.` and `Undo availability depends on the
  active app.` over tentative or implementation-shaped copy.
- If autosave is shown, say **All changes saved**. Never use **Saved locally** as
  ambiguous privacy copy: settings persist locally, while selected text is sent
  to Gemini when an Action runs.

### Interactive surface states

- Hover and press feedback must be coherent across Action rows, the icon-only
  **+** and **Setup** controls, the Action `…` menu, Output segments, Enabled, **Custom
  Model ID**, and primary/secondary buttons. A pointer should reveal what is
  actionable before the user clicks.
- Hover transitions last `0.11 s`; press transitions last `0.09 s`. Both use the
  shared strongly eased motion family and retarget immediately when the pointer
  moves.
- Feedback may change fill, border, shadow, and foreground emphasis, but must not
  change layout geometry. Do not move, resize, or reflow a control between rest,
  hover, focus, and press.
- Keyboard focus remains visible independently from hover. Hover cannot be the
  only affordance or the only state cue.
- Under Reduce Motion, preserve all state distinctions but remove spatial press
  transforms. Do not translate or scale a pressed control.

### Workspace motion

Workspace transitions should feel tactile and intentional while the app remains
fast.

- Use the shared steep ease-in/ease-out family. Current durations are `0.34 s`
  for workspace selection, `0.18 s` for controls, and `0.16 s` for focus.
- Editor replacement uses a `0.12 s` exit and a `0.24 s` entrance. The state swap
  happens after the old editor reaches zero opacity.
- Preserve spatial continuity: the old content eases away, the new content
  arrives within the same bounded pane, and only one editor exists at a time.
  Avoid overlapping crossfades, abrupt identity swaps, bouncing, and independent
  animations that finish at unrelated times.
- Update the selected Action and accessibility value immediately. The visual
  transition may not delay typing, saving, keyboard traversal, menus, or
  destructive confirmation.
- Cancel or retarget an in-flight transition when the user switches Actions
  rapidly. The final frame, focus owner, and bindings must always belong to the
  most recently selected Action. Intermediate names or prompts must never flash
  back into view.
- Hover feedback stays quicker and quieter than structural transitions. Do not
  queue animations for repeated pointer movement. Use `0.11 s` for hover and
  `0.09 s` for press, without geometry changes.
- With Reduce Motion enabled, retain complete state and hierarchy but replace
  workspace displacement, scale, and blur with a short opacity-only transition.
  Structural insertion and removal must not interpolate. Press feedback must not
  translate or scale. No continuous or decorative loop is permitted.

These timings apply to the interactive workspace. The passive HUD and floating
splash retain their separate focus-safety and motion contracts below.

### Explicitly reject from the prototype

- Data Vault and sensitive-field actions.
- An Action Type switch between AI Prompt and Data Vault.
- History as a promised product feature.
- Drag handles or action reordering until real reorder behavior exists.
- Old `AI`, `API Key`, and web-dashboard vocabulary where current product language is clearer.

## Provider setup

Reference: [`prototype/provider-setup.png`](prototype/provider-setup.png)

- Explain that the credential is stored in macOS Keychain and selected text goes to Gemini.
- Never display a real credential in documentation, previews, screenshots, logs, or errors.
- Distinguish missing, available, and unreadable Keychain states truthfully.
- If a credential may still exist after a read failure, keep removal available and state the uncertainty plainly.
- Saving, validation, removal, loading, and failure states must be visible in text—not inferred from color.
- Preserve a compact setup flow; do not reproduce the prototype’s developer-only state tabs.

## Starter library

Reference: [`prototype/starter-library.png`](prototype/starter-library.png)

- Keep names and descriptions immediately scannable.
- Open it through **From Starter Library** in the icon-only **+** menu. Do not
  duplicate the entry in a footer or permanent sidebar row.
- Show whether a starter is already added.
- Explain that a new starter needs a Shortcut before it can run.
- Prefer native lists/sheets and keyboard navigation over literal web cards.
- Do not add decorative filters or categories unless they solve a demonstrated retrieval problem.

## Menu bar

Reference: [`prototype/menu-bar.png`](prototype/menu-bar.png)

- Status comes first: ready, processing, permission problem, or last failure.
- Show only current Actions and truthful Shortcut state.
- Keep Settings, Show Splash, last-error access, and Quit easy to locate.
- Do not add Vault or History because they appear in the concept.
- While an Action owns the paste target, menu commands that would activate Fixer must be blocked or deferred.

## Run feedback HUD

References:

- [`prototype/hud-processing.png`](prototype/hud-processing.png)
- [`prototype/hud-success.png`](prototype/hud-success.png)
- [`prototype/hud-error.png`](prototype/hud-error.png)

The prototype supplies scale, placement, and hierarchy—not literal behavior.

Locked requirements:

- Non-activating and click-through; never take keyboard focus.
- Use one persistent non-activating AppKit panel and one persistent SwiftUI host
  for the process lifetime. Phase changes update observable presentation state;
  they do not replace the panel or blink between independent cards.
- One stable presentation at a time; no stacking.
- Render one compact warm-neutral status card with near-black text, a thin
  outline, restrained shadow, and one familiar progress, check, or error symbol.
  Do not use paper layers, grids, stitches, seams, seals, or another repair
  metaphor. It must belong to the same visual family as the workspace without
  looking like a miniature settings window.
- Do not display a visible **FIXER** wordmark. Working and busy show the Action
  name once as quiet context; resolved states do not repeat it.
- Working state persists until resolution.
- Working must transition into success or error while the card keeps spatial identity.
  Changing copy may use a short opacity crossfade; the shell must not
  jump or disappear between phases.
- Make the card appear immediately after the Shortcut fires. Use only a short
  ease-out entry of about `160 ms`; it must never delay the first visible
  acknowledgement.
- During working, use one standard indeterminate progress indicator. It
  communicates activity without pretending to measure progress; do not add a
  custom loop or a second progress track.
- Success is brief, uses a standard check symbol, and says exactly **Text
  replaced** or **Text appended**. It reports what Fixer attempted without
  claiming that the receiving app accepted the paste.
- Error keeps the same card and uses a standard error symbol plus one concrete,
  readable reason and a useful next step. Do not stack branding, state labels,
  repeated titles, or provider jargon above the actionable message.
- Error remains longer and its full reason stays reachable from the persistent menu surface.
- Repeated triggers during processing acknowledge the existing run without starting another.
- No buttons or links inside the HUD.
- No progress track without real progress telemetry.
- No indefinite attention-demanding animation.
- Under Reduce Motion, preserve complete textual state and symbols, use a brief
  opacity-only phase change, and replace indeterminate motion with an
  understandable static state when necessary. Remove positional offsets, scale,
  rotation, spring inertia, pulse, and every decorative loop.

State copy stays concise and truthful: the Action name appears once while
working/busy; success says **Text replaced** or **Text appended**; error gives a
concrete reason and next step. Undo wording, when present, must say that
availability depends on the active app rather than promising restoration.

## Splash identity

Reference: [`identity/splash-master.png`](identity/splash-master.png)

The master is strict identity evidence. Preserve:

- cream paper texture;
- black, cream, and signal-yellow palette;
- complete Japanese title and spaced `FIXER` wordmark;
- yellow sun behind the mountain;
- mountain, lake, rocks, trees, clouds, and birds;
- centered back-facing yellow character;
- jacket bandage mark, hands, legs, and complete feet;
- left and right technical signs, dots, bars, barcodes, and edge markers.

The native splash must use the five approved source layers already in the asset catalog: paper, sun, landscape, character, and overlay. Do not flatten the implementation, redraw the artwork, crop the feet or side signs, or expose gaps at maximum parallax.

### Floating-card window

- The AppKit window is transparent, borderless, and floating. It must use a clear
  background, `isOpaque = false`, and no operating-system window shadow.
- Never draw a black or dimming rectangle across the window bounds. Desktop and
  underlying windows remain visible around the card.
- Reserve clear overscan around the card for rotation and the custom SwiftUI
  shadow; the current geometry reserves `60 pt` per side.
- The visible card owns its rounded shape, directional edge light, close control,
  and two-stage custom shadow.
- Artwork, overlay typography, highlight, border, and close control share one 3D
  plane. No flat overlay may remain behind while the artwork tilts.

Motion rules:

- Pointer position is normalized independently on both axes to `-1 ... 1` and
  clamped before it reaches rendering.
- Combine horizontal and vertical input into one axis-angle rotation with a hard
  maximum of `6°`, including diagonal input.
- Use a restrained spring entrance and spring re-targeting so pointer motion has
  inertia without a timer-driven or endless animation loop.
- On pointer exit, spring back to zero tilt and settle cleanly.
- Drive one broad specular highlight and the edge lighting from normalized pointer
  tilt. The highlight must not animate autonomously after settling.
- Preserve subtle bounded layer depth within the single tilted card plane.
- paper layer overscan;
- no excessive 3D deformation;
- no endless attention loop;
- Reduce Motion presents the complete settled card immediately at zero tilt:
  no entrance offset/scale, layer staging, pointer parallax, spring inertia,
  highlight travel, or pulse. Static lighting may remain.
- close by mouse, `Esc`, and an accessible close control;
- manual replay does not alter first-run semantics.

Deterministic splash rendering uses a dedicated settled presentation rather than
waiting an arbitrary number of seconds for animation. Its output must have the
complete five-layer identity, zero rotation, a centered card, and transparent
window corners outside the custom shadow.

## Accessibility and native behavior

- Every state must have a text or shape cue; never rely on color alone.
- All interactive controls require keyboard access and meaningful accessibility labels.
- Focus order follows the visible information order.
- Disabled and unavailable states remain legible.
- Error copy must state what happened and, when available, what to do next.
- Splash and settings may activate only while Fixer is idle.
- The passive HUD must remain non-activating even when an error is shown.
- Increased-text/Dynamic Type acceptance requires a live manual pass at default
  and minimum workspace sizes. Do not treat a macOS 13 hosted render with a
  synthetic `sizeCategory` as evidence: that path ignores the override, so it
  cannot verify wrapping, truncation, control growth, focus, or VoiceOver.

## Current terminology

Use these words consistently:

- **Actions**
- **Shortcut**
- **Prompt**
- **Output**
- **Model**

Do not revive obsolete darkroom/safelight language or exploratory Vault terminology.

## What a visual comparison should measure

Compare the native app to the references for:

- hierarchy and primary identifiers;
- information density;
- palette roles;
- selection and readiness clarity;
- spacing rhythm;
- HUD status-card footprint, placement, symbols, and semantic copy;
- continuity of the HUD shell through working-to-result transitions;
- completeness of the splash identity;
- transparency around the splash card, bounded tilt, and coherent one-plane depth;
- absence of visual clutter.

Do not fail a native implementation merely because a SwiftUI/AppKit control is not pixel-identical to its React mockup. Fail it when the hierarchy, identity, state truthfulness, accessibility, or focus-safety contract is lost.
