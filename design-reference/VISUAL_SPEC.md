# Fixer v2 visual specification

This specification separates the approved identity and information hierarchy from exploratory details in the original web prototype.

## Product posture

Fixer is a native background utility, not a web dashboard. It should feel calm, compact, legible, and operational. Visual character comes from warm paper, near-black ink, signal yellow, precise rules, and the approved illustrated identity—not from decorative UI density.

The interface must remain effective before impressive:

- one primary identifier per surface;
- plain product language;
- information visible where the decision is made;
- restrained motion;
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

Signal yellow is scarce. Use it for the current selection, primary action, active state, or small identity accent. Do not turn every button, label, or container yellow.

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
- Searchable Actions list on the left; selected Action editor on the right.
- Action name as the strongest identifier in both list and detail.
- Clear selected state with text/shape contrast, not color alone.
- Visible Shortcut state and unfinished/conflict state near the Action it affects.
- Prompt, Output, Model, enabled state, and provider readiness arranged as operational settings—not marketing cards.
- Immediate persistence; no Save button.
- Minimum practical workspace size: `900 × 620`.

### Adapt natively

- Window chrome and toolbar treatment.
- Split-view width behavior, scrolling, focus rings, menus, toggles, text fields, and sheets.
- Font metrics and exact spacing.

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
- One stable presentation at a time; no stacking.
- Action name is the primary identifier.
- Working state persists until resolution.
- Success is brief and does not claim the receiving app accepted the paste.
- Error remains longer and its full reason stays reachable from the persistent menu surface.
- Repeated triggers during processing acknowledge the existing run without starting another.
- No buttons or links inside the HUD.
- No progress track without real progress telemetry.
- No indefinite attention-demanding animation.
- Under Reduce Motion, remove activity motion while preserving complete textual state.

Current native preview sizes:

- working/success: `368 × 88`;
- error: `380 × 132`.

Current success details remain deliberately cautious:

- `Replace · try ⌘Z to undo`
- `Append · try ⌘Z to undo`

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

Motion rules:

- restrained staged entrance;
- subtle depth after settling;
- paper layer overscan;
- no excessive 3D deformation;
- no endless attention loop;
- Reduce Motion removes parallax and motion-dependent presentation;
- close by mouse, `Esc`, and an accessible close control;
- manual replay does not alter first-run semantics.

## Accessibility and native behavior

- Every state must have a text or shape cue; never rely on color alone.
- All interactive controls require keyboard access and meaningful accessibility labels.
- Focus order follows the visible information order.
- Disabled and unavailable states remain legible.
- Error copy must state what happened and, when available, what to do next.
- Splash and settings may activate only while Fixer is idle.
- The passive HUD must remain non-activating even when an error is shown.

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
- HUD footprint and placement;
- completeness of the splash identity;
- absence of visual clutter.

Do not fail a native implementation merely because a SwiftUI/AppKit control is not pixel-identical to its React mockup. Fail it when the hierarchy, identity, state truthfulness, accessibility, or focus-safety contract is lost.
