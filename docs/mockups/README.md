# Dock controls and preview proposal

Status: revision 4 approved by the user on 2026-11-03; implemented in the development branch. The earlier proposal below records revision 2; revision 3 supersedes its control visibility, preset layout, and repeated app names.

- [Dock controls SVG](dock-controls-proposal.svg) · [PNG preview](dock-controls-proposal.png)
- [Preview appearance SVG](preview-style-proposal.svg) · [PNG preview](preview-style-proposal.png)

## Placement controls

Replace the external toolbar with a position tile inside the dock, using a monitor-and-dock glyph. There is no separate grip or handle piece. It occupies a leading slot, leaving app reordering unchanged. Clicking opens eight placement targets, a central rotate action, and collapse/expand. When collapsed, only the position tile remains at the same edge.

Top and bottom use horizontal orientation; left and right use vertical orientation. Corners preserve the chosen orientation. Rotate changes orientation at corners; at a centered edge it moves to the corresponding edge for the new orientation.

Dragging and border resizing are separate settings, both locked by default. The illustration shows dragging unlocked. Position buttons work while dragging is locked. When unlocked, drag empty dock background or a divider gap to reposition any existing edge or corner placement. Keep clicking the position tile dedicated to opening its popup. App icons retain their existing rearrange behavior.

The dock always snaps to a screen edge or corner. A continuous 700 ms hold at a shared display boundary transfers it to that display; retreating resets the hold. The dock follows the pointer along an edge and shows an outline of the proposed placement.

Optional border resizing scales icon size within the existing supported size range. Dock length follows its content rather than adding empty space. Layout stays attached to the chosen edge or corner.

## Six buttons within the tile

The revised controls sheet compares the recommended single icon and popup against a six-button tile at native SVG scale. In a 44 pt tile, a 3 × 2 grid gives roughly 12 × 17 pt targets after spacing. This is possible but prone to misclicks, and six actions do not cover all four corners. The recommendation remains one icon opening comfortably sized placement buttons.

## Preview appearance

Offer Square (0 pt), Subtle (6 pt, proposed default), and Rounded (14 pt) corner styles. Apply the same setting to the outer preview block, thumbnail/list cards, and keyboard switcher.

Use 6 pt gaps between adjacent thumbnail cards and between list rows, reduced from the previous 20 pt thumbnail spacing.

Keep every window title at full text contrast, with readable secondary app names. Distinguish the selected window with a system-accent outline, tinted fill, and selection indicator. In dark mode, use adaptive system text colors.

The mockups use simplified example icons and window contents. They show interaction and styling decisions, not final app artwork.

## Revision 3 — approved and implemented

[SVG](dock-refinements-revision3.svg) · [PNG](dock-refinements-revision3.png)

The dock-control tile is optional and hidden by default, with a custom image option. Settings and its popup share six presets per orientation: vertical uses left/right positions at the top, middle, and bottom; horizontal uses top/bottom positions at the left, center, and right. A collapsed dock always retains an expand control. Hover previews show only window titles; the keyboard switcher retains application names for mixed-app results.

## Revision 4 — approved and implemented

[SVG](dock-refinements-revision4.svg) · [PNG](dock-refinements-revision4.png)

One diagram shows all 12 positions without a separate orientation switch. An optional internal dotted bar collapses/expands on click, opens the diagram on right-click, and drags when unlocked. Running apps precede pinned apps; the attached dock background is flush with the screen edge. The user approved implementation and requested dots plus the collapsed-state example; both are included in the updated SVG.

[Collapsed dotted bar SVG](dock-collapsed-revision4.svg) · [PNG](dock-collapsed-revision4.png) shows the expanded control’s replacement while collapsed.

## Revision 5 — approved and implemented

[SVG](preview-contrast-revision5.svg) · [PNG](preview-contrast-revision5.png)

A fine preview-panel border and soft shadow clarify the panel against a white background. Unselected cards receive a neutral outline. The dotted bar has no separate fill, letting the existing dock material show through. Rendered, inspected, and approved by the user. Implemented in thumbnail and list hover previews; the dotted bar draws directly over the dock material.

## Hover-window highlight — awaiting approval

[SVG](hover-window-highlight-proposal.svg) · [PNG](hover-window-highlight-proposal.png)

Approved keyboard-switcher-style In Place highlighting after 150 ms hover: dim the desktop, show the window at its screen position, retain the interactive thumbnail popup, and restore the desktop on exit. Click still activates the selected window. Optional setting under Window Management → Window Preview. Rendered, inspected, and approved by the user. Implemented on `main` with a default-on optional setting and cancellation guards for stale captures.
