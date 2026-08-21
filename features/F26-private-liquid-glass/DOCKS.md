# F26 — Private Liquid Glass Controls

A focused Liquid Glass treatment for the app's circular top-level actions and the circular controls in the Music settings surface. The older-system path intentionally uses the private backdrop renderer from the pinned LiquidGlassKit revision. The feature is for development and sideloaded builds; it is not App Store-safe while that renderer remains linked.

## What We Build

- Circular Liquid Glass surfaces behind every icon-only primary toolbar action on iOS pages.
- A matching circular Liquid Glass treatment for the Music Library controls reached from Settings.
- A single cross-version surface that uses the private renderer below iOS 26 and the native public Liquid Glass implementation on iOS 26 and later.
- A solid, readable surface when Reduce Transparency is enabled.
- Press feedback that slightly contracts and dims the circular control while preserving the icon's center and hit area.
- The existing bottom slot navigation surface remains its own feature and keeps its native iOS 26 treatment and earlier-system material fallback.

## Architecture

The SwiftUI toolbar and settings controls keep ownership of actions, labels, accessibility text, and navigation. A UIKit bridge owns the visual surface. On older iOS versions it hosts the LiquidGlassKit effect view, whose Metal renderer captures the backdrop through the private Core Animation backdrop layer. On iOS 26 and later it hosts Apple's native glass effect. The surface is placed behind the label and does not receive touches; the surrounding Button remains the hit target.

## States

| State | Size | Style | Content | Behavior |
|---|---|---|---|---|
| resting | Circular, sized to the icon control | Dark translucent glass with edge depth and backdrop distortion | Centered SF Symbol | Remains attached to the toolbar or settings control while the surrounding content changes |
| pressed | Same circle and hit area | Slightly dimmed and contracted | Icon remains centered | Spring-like contraction returns to rest after release; the action fires once |
| disabled | Same circle | Reduced contrast without an active highlight | Disabled icon | Does not respond to input and remains legible against the dark app background |
| Reduce Transparency | Same circle | Opaque dark surface with a clear edge | Centered icon | Avoids backdrop capture and refraction while preserving contrast and layout |
| Reduce Motion | Same circle | Resting glass appearance | Centered icon | Suppresses the press scale animation but keeps immediate pressed feedback |
| iOS 26 or later | Same circle | Native public Liquid Glass | Centered icon | Uses Apple's native implementation rather than the older private renderer |
| older supported iOS | Same circle | LiquidGlassKit Metal glass backed by the private backdrop capture path | Centered icon | Continuously updates the refracted backdrop at the renderer's capped frame rate |
| unavailable renderer | Same circle | Opaque dark surface | Centered icon | Prevents a blank control when the private renderer cannot create a Metal surface |

## Animation Rules

| Animation | Feel | Trigger |
|---|---|---|
| Press contraction | Short, interruptible spring; approximately ninety-two percent scale at the deepest point | Pointer or touch-down on a circular icon control |
| Press release | Same spring returns to one hundred percent scale and full opacity | Pointer or touch-up, cancellation, or action completion |
| Backdrop response | Continuous low-rate renderer update, without moving the control's layout frame | Resting glass surface is visible |
| Reduced motion | No scale transition; opacity changes remain immediate | Reduce Motion is enabled |

## Files

- `project.yml` — pins LiquidGlassKit to the known-good source revision and links it only to the iOS application target.
- `TimeMaster.xcodeproj/` — generated package and target integration.
- `TimeMaster/Utilities/PrivateLiquidGlass.swift` — UIKit bridge and cross-version surface modifier.
- `TimeMaster/Utilities/Theme.swift` — shared circular toolbar button style and AppToolbar helpers.
- `TimeMaster/Views/Settings/MusicGlassControls.swift` — circular Music settings controls using the shared surface.
- `TimeMaster/Views/**` toolbar owners — icon-only primary actions routed through the shared circular style.

## Dependencies

- F24 — existing slot navigation and page hierarchy must remain intact; this feature does not replace the bottom navigation surface.
- F25 — Music settings owns the circular controls that receive the shared surface.
- LiquidGlassKit at revision `51ef8d187a466345882b90d281865ceec7bad3b0` — private renderer for older iOS systems.
- F28 — applies the same iOS 26 native and iOS 16–25 private-renderer split to morphing route pines while keeping their geometry and state relationships identical.
- Metal-capable iOS hardware or simulator — required for the older-system renderer.

## Reference

- `genesis/REFERENCE/` — check for existing app visual references before changing the surface language.
- `https://github.com/ThijsMussig/LiquidGlassKit` — direct implementation dependency for the private renderer. The pinned revision is used because the newer upstream revision currently has a shader compilation defect.
- Apple native Liquid Glass APIs — public implementation used on iOS 26 and later.

## Distribution Boundary

The older-system implementation references private Core Animation backdrop APIs through LiquidGlassKit. This is an intentional private-build choice requested for the app, not an App Store submission path. A future App Store build must use a separate public-only target or remove the private dependency before archive and submission.
