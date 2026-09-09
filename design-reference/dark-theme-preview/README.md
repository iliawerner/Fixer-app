# Archived dark-theme proposal

The user approved **revision 2** (`fix-grammar-dark-v2.png`) for the Fix grammar workspace. Its warm charcoal surfaces, warm light text, dark ochre masthead, and yellow accents are now implemented in the production theme, with Light, Dark, and Follow System choices in Setup. This folder preserves the original design decision; use the production source for further theme work.

The two PNGs are native SwiftUI/AppKit renders of an isolated prototype in an 820 × 800 point window. Revision 2 responds to the feedback that dividers and outlines were too prominent: structural rules use a near-background color, field and selection outlines are quieter, and the masthead grid is fainter. Text, surfaces, layout, and yellow state indicators retain the first proposal's values. Both retained filenames currently contain the same approved v2 render.

`prototype.patch` records the approved v2 study against commit `a21a7a5a16acad4a08364f1d59e34fbbc771d882`. It is an archival recipe, not a patch to apply to today's production source. The prototype fixture uses sample Actions and a stub model catalog, without provider requests.

## Reproduce the archived study

From the repository root, run:

```sh
python3 design-reference/dark-theme-preview/prepare-preview.py
```

The script reads the pinned commit with `git archive`, creates a new isolated project under `.build/dark-theme-preview-study/approved-v2-*/project`, and applies the retained patch only there. It never copies or rewrites the current `Sources/` or `Tests/`, and never overwrites the archived PNGs or `prototype.patch`.

The script prints the exact project-generation and `xcodebuild` commands. They use the archived dependency lock, a separate Derived Data directory, the single `rendersDarkWorkspaceExample()` native rendering test, and a new `renders/` directory beside the copied project. Preparation alone does not build or render anything. Reproducing the render requires Xcode, XcodeGen, and a local macOS graphical session.

The prototype's chosen opaque palette pairs have calculated contrast ratios of 13.22:1 for primary text, 6.95:1 for secondary text, and 7.65:1 for the masthead title. These values describe the proposal, not a complete accessibility or interaction audit of the production theme.
