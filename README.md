<div align="center">

<img src="docs/images/logo.png" width="128" alt="Docky logo">

# Docky

### The same old dock, on steroids. Now free and open source.

Docky is a Dock replacement for macOS that elegantly replaces the system one. It
brings the Dock back into reach: quieter, smarter, and native-feeling, with a
configurable layout, widgets, a fullscreen Launchpad, a live window switcher,
custom icons, and scripted actions.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://getdocky.com)
[![Universal](https://img.shields.io/badge/Apple%20Silicon%20%26%20Intel-Universal-orange)](https://getdocky.com)
[![Website](https://img.shields.io/badge/getdocky.com-Download-brightgreen)](https://getdocky.com)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/josejuanqm)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-ffdd00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/josejuanqm)
[![Discord](https://img.shields.io/badge/Discord-join-5865F2?logo=discord&logoColor=white)](https://discord.gg/vAwVNtPSgE)

[**Download**](https://getdocky.com) &nbsp;·&nbsp; [**Website**](https://getdocky.com) &nbsp;·&nbsp; [**Build from source**](#building-from-source)

</div>

<div align="center">
  <img src="docs/images/hero.jpg" alt="Docky on macOS" width="900">
</div>

## Hover window highlight experiment

On `main`, hover a thumbnail or window row for 150 ms
to highlight that window in place against a dimmed desktop. Clicking activates
the window; leaving the preview restores the desktop without changing focus.
Toggle **Settings → Window Management → Window Preview → Highlight hovered window**
to disable it. Screen Recording permission is required; minimized or unavailable
windows keep their normal preview without the desktop highlight.

## Dock controls — 0.9.11

On `main`, open **Settings → Behavior → Placement**
to choose among 12 miniature docks in a screen diagram. Each target sets both
position and orientation in one click; corners offer both orientations.
Enable **Show control bar in the dock** for an optional dotted bar:

- Click to collapse or expand.
- Right-click to open the position diagram.
- Drag to move when repositioning is unlocked.

The dots share the dock background without a separate grey fill.
The bar is hidden by default. A collapsed dock always retains only the bar so
it can be expanded. Unpinned running apps appear before Finder and pinned apps;
files and Trash remain last. At bottom-left, new apps grow the dock upward while
the pinned section stays anchored. The attached edge has no outer gap.

Enable **Settings → Behavior → Placement → Allow dragging to reposition** to
move the dock from empty background and divider gaps. The dock stays attached
to an edge or corner; hold across a monitor boundary for 0.7 seconds to transfer.
App icons retain their normal click and rearrange behavior. Docky uses a real elevated floating-panel level and disables native window
dragging/resizing and fullscreen tiling. Its own placement and border-resize
controls remain available; macOS desktop edge tiling still needs a manual check.

**Allow border resizing** independently unlocks the inward-facing border to
scale dock icons in either orientation. Crowded docks switch to scrolling when
needed to preserve the requested size. Both editing options are off by default. Placement, display,
and collapse state are remembered. Edge Position modes use fit-content sizing
and pause edge auto-hide, fullscreen hiding, pointer-following placement and
window reservation. Select a standard edge mode to resume those settings.

**Settings → Window Management → Window Preview → Corner Style** selects
Square (0 pt), Subtle (6 pt, default), or Rounded (14 pt) corners. Hover previews
and the keyboard switcher share this style, tighter 6 pt spacing, readable labels,
and accent outlines/tinted selection highlights. Hover previews show only window
titles; the keyboard switcher keeps app names for mixed-app results. Hover preview
panels have a thin adaptive border and native shadow, with subtle neutral outlines
on unselected cards and rows to stay visible over light applications.

See [the approved SVG mockups](docs/mockups/README.md). Future UI changes require
an SVG design review before implementation.

Geometry and native lifecycle checks can be run on macOS:

```sh
swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/DockAppSectionOrder.swift scripts/test_dock_app_section_order.swift -o /tmp/test-dock-app-section-order
/tmp/test-dock-app-section-order
swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/FloatingDockGeometry.swift scripts/test_floating_dock_geometry.swift -o /tmp/test-floating-dock-geometry
/tmp/test-floating-dock-geometry
swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/FloatingDockGeometry.swift Docky/Services/DockPositionPreset.swift scripts/test_dock_position_presets.swift -o /tmp/test-dock-position-presets
/tmp/test-dock-position-presets
swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/FloatingDockGeometry.swift Docky/Services/DockPositionPreset.swift Docky/Services/DockPlacementPreferences.swift Docky/Services/DockWindowInteractionPolicy.swift Docky/Views/MainWindow/FloatingDockController.swift scripts/test_floating_dock_controller.swift -o /tmp/test-floating-dock-controller
/tmp/test-floating-dock-controller
swiftc -module-cache-path /tmp/docky-test-module-cache Docky/Services/DockWindowInteractionPolicy.swift scripts/test_dock_window_interaction.swift -o /tmp/test-dock-window-interaction
/tmp/test-dock-window-interaction
```

The native lifecycle test requires access to WindowServer.

## Fork changes — 0.9.11

- Edge-attached dragging, optional border resizing, and a dotted collapse/expand bar.
- A screen diagram with all 12 position/orientation targets, available in Settings and on bar right-click.
- Stable corner snapping: drag geometry is fixed for each gesture; corners snap within 24 pt and release after 36 pt of retreat.
- Unpinned running apps before the pinned section; flush screen-edge placement.
- Preview corner styles, tighter spacing, readable titles, clearer selection, adaptive borders and a native shadow.
- Correct floating-panel window level and native movement/fullscreen-tiling restrictions.

## Fork changes — 0.9.10

This fork includes the following customizations on top of upstream v0.9.7:

- **Bottom-left placement:** choose **Settings → Behavior → Window Position →
  Bottom Left** to anchor a vertical dock to the bottom of the left screen edge.
- **Hover thumbnails:** previews pick up images that finish capturing after the
  popup opens and show a status message when an image is unavailable or Screen
  Recording permission is missing.
- **Preview dismissal:** dismiss the hover popup immediately to avoid an old
  fade-out hiding a reopened preview, and ignore stale hover callbacks.
- **Instant Focus:** keep the window switcher overlay visible while each selected
  window receives focus.
- **Faster In Place previews:** reduce the initial wait from one second to
  150 ms and display a cached image while live capture starts.
- **Shortcut guidance:** clarify that Docky's default shortcut is **Option+Tab**.
  Configure it under **Settings → Window Management → Window Switcher**.

For Instant Focus, enable **Window Switcher** and **Switcher Preview**, choose
**Thumbnails**, and select **Instant Focus**. Screen Recording permission is
required for thumbnail capture. The hover preview delay is configured separately
under **Window Preview**.

## Why Docky

The Dock is the most-used surface on a Mac, and it has barely changed in years.
Docky rebuilds it for focus: it can run alongside, mirror, or fully replace the
system Dock, and it moves with your workflow instead of getting in the way.

- **Free and open source.** No paid tier, no upsell. Licensed under GPLv3.
- **Native-feeling.** A universal binary for Apple Silicon and Intel, notarized
  by Apple.
- **Yours to shape.** Pin what you reach for, arrange it how you think, and drop
  in widgets and actions that match how you work.

## Features

### Tiles and layout

Add and arrange anything in one strip: apps, widgets, Smart Stacks, folders,
spacers, and dividers. Pin what you reach for, drag to reorder, and let the
layout follow your workflow.

<div align="center"><img src="docs/images/feature-layout.jpg" alt="Tiles and layout" width="820"></div>

### Window switcher, live

A global, Cmd-Tab-style window switcher with live window previews, plus per-tile
hover previews so you can see a window before you raise it.

<div align="center"><img src="docs/images/feature-window-switcher.jpg" alt="Live window switcher" width="820"></div>

### Built-in Launchpad

A fullscreen, searchable app launcher with full keyboard navigation, its own
layout, and an optional global shortcut.

<div align="center"><img src="docs/images/feature-launchpad.jpg" alt="Built-in Launchpad" width="820"></div>

### Widgets in the dock

Built-in widgets (Calendar, Reminders, Batteries, System, Weather, Now Playing,
and more) live right in the dock. Stack several into a single tile with **Smart
Stacks** and cycle through them in place. Add community `.dockywidget` bundles
through the widget store.

<div align="center"><img src="docs/images/feature-widgets.jpg" alt="Widgets and Smart Stacks" width="820"></div>

### Rich app folders

Group apps into folders with nested navigation, Quick Look, and drag-and-drop.
Optionally show running apps inline so a folder doubles as a live workspace.

<div align="center"><img src="docs/images/feature-folders.jpg" alt="Rich app folders" width="820"></div>

### More

- **Custom app icons:** override the icon for any pinned, running, or
  widget-backed app.
- **Scripted actions:** catalog-backed AppleScript and menu-click automation,
  plus curated commands.
- **Themes and profiles:** themeable appearance and switchable configuration
  profiles.

## Download

Get the latest notarized build from [getdocky.com](https://getdocky.com), or grab
a release from the [Releases page](https://github.com/josejuanqm/docky/releases).

### Homebrew

```sh
brew install --cask josejuanqm/tap/docky
```

Updates are delivered in-app via Sparkle. No tap trust step is needed for a normal
install. If you run Homebrew with `HOMEBREW_REQUIRE_TAP_TRUST=1`, trust the cask
first with `brew trust --cask josejuanqm/tap/docky`.

Docky needs **Accessibility** and **Screen Recording** permissions to manage
windows and render previews. It prompts for these on first launch.

> [!NOTE]
> Docky uses private SkyLight / CoreGraphics Services and Accessibility SPI (see
> `Docky/Private/`) to position windows, capture previews, and drive the system
> Dock. Because of this, **Docky cannot be distributed on the Mac App Store**.
> It is built from source or distributed directly.

## Building from source

```sh
git clone --branch codex/docky-customizations https://github.com/tongdu99/docky.git
cd docky
open Docky.xcodeproj
```

Build and run the `Docky` scheme. Swift Package dependencies (Sparkle) resolve
automatically on first build.

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16 or later to build from source

## Documentation

- [External widget bundles](docs/external-widgets.md): the `.dockywidget` bundle
  contract and how to build community widgets.

## Supporting Docky

Docky is free and open source with no paid tier. If it earns a place in your
Dock, you can help fund ongoing development:

- **[GitHub Sponsors](https://github.com/sponsors/josejuanqm)**: one-time or
  monthly, with tiers from ☕ Coffee to ❤️ Patron.
- **[Buy Me a Coffee](https://buymeacoffee.com/josejuanqm)**: a quick one-off
  thank-you.

Sponsors also get a supporter role in the [Docky Discord](https://discord.gg/vAwVNtPSgE).
Supporters are credited in [SUPPORTERS.md](SUPPORTERS.md); sponsoring teams can
have their logo featured there. Every bit helps keep Docky maintained and free.

## Dependencies

- [Sparkle](https://github.com/sparkle-project/Sparkle): software update
  framework (BSD 3-Clause).

## License

[GNU General Public License v3.0](LICENSE). Copyright (C) 2026 Jose Quintero.
