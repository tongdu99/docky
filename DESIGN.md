# Design

## Source of truth
- Status: Active — revision 5 approved by the user, 2026-11-03.
- Primary surfaces: dock placement controls, dragging/resizing, hover previews and keyboard switcher.
- Evidence: approved SVGs in [docs/mockups](docs/mockups/README.md), MainWindow, TileContainerView, DockyPreferences, BehaviorSettingsView and WindowManagementSettingsView.
- Future UI changes require an SVG mockup and user confirmation before implementation; see AGENTS.md.

## Brand
- Native macOS controls, typography, materials, SF Symbols and adaptive system colors.
- Quiet idle controls and readable text; preserve the user's app focus.

## Product goals
- Reposition every dock layout along usable screen edges and corners.
- Collapse to one recoverable in-dock control, rotate, and remember placement.
- Make unselected previews readable and distinguish selection clearly.
- No arbitrary floating position and no separate handle toolbar.

## Personas and jobs
- Mac users customizing dock placement and switching windows quickly.
- Move the dock independently of app-icon rearrangement.

## Information architecture
- Behavior → Placement offers editing locks, one diagram with all 12 position/orientation targets, and an optional dotted control bar.
- The leading control bar is hidden by default. Click to collapse/expand; right-click opens the same 12-target diagram as Settings; drag when repositioning is unlocked.
- Window Management → Window Preview → Corner Style offers Square, Subtle and Rounded.

## Design principles
- Empty background and dividers are drag targets when unlocked; app tiles retain their normal interactions.
- Placement buttons work regardless of editing locks.
- Corners preserve orientation. Top/bottom centered positions are horizontal; left/right centered positions are vertical.
- Maintain a recoverable control when collapsed.

## Visual language
- A small dotted bar lives inside the dock; no external handle. A collapsed dock displays only this bar.
- Popup targets are comfortably sized, rather than six tiny buttons squeezed into one tile.
- Preview card and list gaps are 6 pt. Corner radii are 0, 6 (default) or 14 pt.
- Primary titles stay readable in all selection states. Selection uses accent outline, tint and a check indicator.
- Use system foreground colors in both light and dark appearances.

## Components
- Reuse MainWindow and existing tile layout, preview services and switcher overlay.
- DockControlTileView, DockPlacementPreferences, FloatingDockController and PreviewAppearancePreferences own the added controls/state.
- Drag-only outline panel is noninteractive; it is not a toolbar.

## Accessibility
- Named control and target buttons use standard SwiftUI button semantics and tooltips.
- Twelve miniature dock targets show location and orientation together, with explicit accessible names and hover labels. Expand remains available when collapsed, even when the optional bar is hidden.
- Respect adaptive text and accent colors; do not fade unselected labels.

## Responsive behavior
- Use NSScreen.visibleFrame; clamp normalized edge offsets after screen or size changes.
- Remember display identity with fallback when a monitor disconnects.
- Continuous 700 ms crossing dwell resets on retreat or candidate-display change.
- Resizing scales icons within 16–128 pt; content determines length.

## Interaction states
- Locked: dragging and resizing off by default, normal icon interactions continue.
- Dragging: empty areas/dividers move the dock along an edge; corners snap; outline previews placement.
- Resizing: the inward-facing border changes icon size if unlocked.
- Collapsed: only the in-dock control remains; click restores content at the saved edge.
- Edge Position: fit-content sizing; edge autohide, fullscreen hiding, pointer-following placement and window reservation pause as explained in Settings.
- Empty/offline: all placement controls are local; unavailable preview images keep a status label.

## Content voice
- Use Dock Position, Collapse Dock, Expand Dock, and explicit position/orientation names.
- Explain settings with their concrete effects.

## Implementation constraints
- AppKit placement/event handling and existing SwiftUI layout, without new dependencies.
- Persist edge, normalized along-edge offset, display, collapse, editing locks, control visibility, and preview style in UserDefaults.
- Run pure geometry tests, native controller lifecycle tests and a full Debug build.
- Real monitor crossing requires manual testing on multiple physical displays; report that gap.

## Open questions
- None blocking. The control occupies the leading dock slot to keep app reordering unchanged.

## Superseded revision 3
- Revision 3 implemented an optional/customizable control tile, orientation-specific position presets matching actual placements, and hover previews without repeated application names.
- Approved reference: `docs/mockups/dock-refinements-revision3.svg`. App names remain in mixed-app keyboard switcher results.
- Vertical resize bug repair preserves explicitly requested size using existing overflow scrolling when needed; this is a behavior fix to the approved resize interaction.
- User confirmed Docky should be excluded from macOS window tiling. Disable native moving/resizing and fullscreen tiling for the dock and its drag outline, preserving app-controlled placement and resize.

## Accepted revision 4
- Review reference: `docs/mockups/dock-refinements-revision4.svg` (rendered and inspected).
- Replace text-only presets and the orientation segment with one screen diagram containing 12 independent miniature dock targets: six vertical and six horizontal. Only a position click changes placement.
- Replace the optional icon tile with an internal dotted bar: click collapse/expand, right-click the same position diagram, drag when repositioning is unlocked. A collapsed dock retains the bar.
- Put unpinned running apps before pinned apps, preserving pinned order and trailing files/Trash. For bottom-anchored layouts, new running apps grow away from the pinned block.
- Remove the outer gap on the attached edge; keep internal icon padding.
- User approved implementation, adding dots to the bar and a collapsed-state example. The updated SVG was rendered and inspected before implementation.

### Independent window-policy repair
- Removed MainWindow's constant level getter/ignored setter. The interaction policy now configures a floating panel and assigns a real elevated level after that configuration.
- Native tests inspect WindowServer's backing layer after the panel is ordered, in addition to movement, resize and Space flags. Desktop edge-drag behavior still requires runtime validation; fullscreen tiling flags alone do not prove desktop-tiling exclusion.

- Running unpinned apps precede Finder/pinned apps, with files/Trash last. Bottom-anchored docks grow upward, preserving the pinned suffix.

- Live revision 4 checks confirmed the 12-target chooser in Settings and on right-click, collapse to the dotted bar, direct corner-orientation selection while collapsed, and bar dragging without accidental collapse. Real monitor crossing and macOS desktop tiling remain manual validation gaps.

## Accepted revision 5
- Rendered review reference: `docs/mockups/preview-contrast-revision5.svg`.
- Add a fine adaptive border and soft shadow around the hover preview panel so it remains distinct over white applications; add subtle neutral outlines to unselected cards while preserving the blue selected highlight and corner preference.
- Remove the dotted bar's separate grey fill. Draw the dots over the dock's existing material in expanded and collapsed states.
- User confirmed the SVG. Implemented for thumbnail and list hover previews, using adaptive outlines and a native window shadow. The dotted bar draws only dots over the dock material.

## Corner-drag regression repair — 0.9.11
- Capture chrome size/anchor at gesture start instead of feeding live panel size (which changes at corner endpoints) back into offset calculations.
- Snap within 24 pt; hold until a deliberate 36 pt retreat. Reset the latch when the edge, display, or gesture changes.
- Keep monitor-dwell polling active; unchanged placement updates do not rewrite preferences or relayout the dock.

## Hover-window highlight experiment
- Branch: `codex/hover-window-highlight`, based on the merged/pushed 0.9.11 main.
- Review reference: `docs/mockups/hover-window-highlight-proposal.svg` (rendered and inspected).
- Interpret requested keyboard-switcher-style highlight as the existing In Place behavior: dim the desktop and display the hovered window capture at its screen bounds, without activating the app.
- Trigger only after explicit thumbnail/row hover, with 150 ms dwell; changing hover cancels stale capture. Leaving the popup, dismissal, menu presentation, or clicking to activate clears the highlight.
- Add an optional Highlight hovered window setting in Window Management → Window Preview. The visual overlay ignores mouse input so the dock and popup remain usable.
- Reuse existing capture/cache support; handle minimized or uncapturable windows without inventing a desktop position. Preserve normal thumbnail fallback.
- User approved the rendered SVG. Implemented as a nonactivating, mouse-transparent overlay below the dock and preview popup. The setting defaults on for this experiment; disabling it or opening the keyboard switcher clears the overlay.

### Hover highlight recovery
- After the dwell, use an existing thumbnail immediately while requesting a full-size capture, so a stalled capture does not prevent visual feedback.
- Preserve physical hover during temporary setting, permission, menu, or keyboard-switcher interruptions; restart after the dwell when eligible again. Exit and dismissal still cancel all pending work.
- Validate thumbnail and list-row hover callbacks against their originating popup presentation, including delayed exits from replaced hosting views.
