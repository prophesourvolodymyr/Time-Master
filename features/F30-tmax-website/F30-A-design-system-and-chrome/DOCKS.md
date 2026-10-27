# F30-A — Design System and Site Chrome

The website's controls, surfaces, type, and colors are recreated from the native Tmax app. Every interactive element should feel like it was taken from the app. The menu bar and the footer are new components built from these same parts.

## What We Build

- Web versions of the app's button styles: the tinted-glass action button, the circular icon button, the selection button, a segmented control made from selection buttons, the card surface, the glass surface, and the disclosure indicator.
- Design tokens that mirror the app theme, with one deliberate website difference: the page background is pure black (#000000) instead of the app's #0A0A0A.
- The app typography on the web: Manrope Regular, Inter Black, genuine Inter Black Italic, and the original TimeMaster ribbon typeface, served from the app's own font files and their licenses.
- The menu bar (the top navigation) and the footer.

## Recreated Controls

### Action Button (from the app's shared action style)

- A tinted-glass capsule. The surface blurs and saturates whatever is behind it and is tinted with the app's orange at 46 percent strength, or 58 percent when the button is prominent.
- A one-pixel light rim at 18 percent white, strengthened to 32 percent when the visitor asks for increased contrast or reduced transparency.
- Corner radius: at full expansion the corners use the app's 18 pt control radius. Reducing the expansion rounds the button toward a full capsule, exactly as the native style interpolates between half the button height and the control radius.
- Minimum size: 44 pt tall and 44 pt wide. The default horizontal padding is 14 pt and scales with expansion. An optional full-width mode stretches it across its container.
- Labels are white Inter Black. The toolbar-wide variant uses 17 pt and the text variant uses 15 pt. An optional leading or trailing icon sits beside the label.
- A destructive role swaps the orange tint for the system red.
- Pressed: the button shrinks to 94 percent and dims to 86 percent opacity, using the app's quick, nearly critically damped spring (0.24 second response, 0.88 damping). Releasing springs back the same way. With reduced motion, only the dimming remains.
- Disabled: 45 percent opacity, no press feedback, and not reachable as an action.
- Keyboard focus: a crisp two-pixel white ring at 75 percent opacity follows the button's own shape.
- Reduced transparency: the glass becomes the app's solid #141414 surface, and the tint and rim stay.
- Works as a real button or as a link with the same appearance.

### Icon Button

The action button in a perfect circle (44 pt by default) holding a single icon. It always has an accessible name.

### Selection Button and Segmented Control

- The selection button is a 44 pt minimum control with an 18 pt radius. It shows a white Inter Black 16 pt label and 14 pt horizontal padding.
- Unselected: a transparent fill with a 14 percent white rim (45 percent with increased contrast).
- Selected: a solid orange fill.
- Focus: the rim becomes 75 percent white and two pixels wide.
- It uses the same spring press feedback as the action button.
- The segmented control groups selection buttons into one choice, such as Per person and Collection in the stats. It behaves as a radio group: arrow keys move the choice, and the selected segment changes with a short slide of the orange fill.

### Card Surface

- A rounded card with a 20 pt radius. The fill is a diagonal gradient from #1C1C1C at the top left to #141414 at the bottom right. The hairline border is a diagonal gradient from 20 percent white to 6 percent white.
- Emphasized cards add a 12 percent orange wash from the top left and an orange rim at 65 percent.
- Flat cards use a solid #141414 fill with an 8 percent white hairline. Emphasized flat cards use a 30 percent orange hairline.
- Increased contrast strengthens the rims.

### Disclosure Indicator

A 44 pt flat card square with a 12 pt radius that holds a semibold chevron at 80 percent white. It is purely decorative.

## Tokens

- **Colors:** page background #000000; surface #141414; raised surface #1C1C1C; primary text white; readable secondary text white at about 62 percent, with the app's 45 percent reserved for decorative or tertiary text; separator white at 8 percent; accent orange #FF6A00; live green #34C759; destructive red #FF3B30. The app's eight icon colors are available for the agent customization moment.
- **Typography scale, from the app:** page title in the ribbon typeface, 44 pt; display, Inter Black 28; title, Inter Black 24; heading, Inter Black 20; section title, Inter Black 17; row title, Inter Black 15; label, Inter Black 16; body, Manrope 16; secondary, Manrope 14; caption, Manrope 12; micro, Manrope 11; technical, Manrope 12 with tabular digits. Marketing headlines scale up fluidly from these roles. They stay Inter Black, with tight tracking and generous size.
- **Spacing, from the app:** 4 for label insets, 8 small, 12 for stacks, 16 for insets, and 24 for sections. The readable text width is 640.
- **Radii:** 18 for controls, 20 for cards, and 12 for chips and small squares.
- **Spring:** a 0.24 second response with 0.88 damping for press feedback. Larger transitions use smooth, slightly slower eases.

## Menu Bar (Top Navigation)

- **Composition:** the Tmax M mark sits on the left as the home link. Section links (AI, Social, Builder, Map, and Stats) sit in the middle or on the right. They choose the chapter when relevant and glide to it. A prominent orange Install action on the far right glides to the choice hub's download call to action. The height stays at or below 72 pixels, and everything sits on one line on desktop.
- **At the top of the page:** fully transparent over the hero, with white text.
- **After scrolling:** a dark glass bar fades in behind the items. It has a blur, a hairline bottom separator, and the app's surface tint.
- **During immersive held moments** (the film's push-in and word sequence, the three-second edit, and the AI agent-creation moment): the bar slides up out through the top border. It returns by sliding down when the visitor scrolls upward or the held moment ends.
- **Hover and press:** links brighten from secondary to primary white and show a small orange underline that slides in from the left. Buttons use the recreated press feedback.
- **Active section:** the link for the section in view stays white with the orange underline.
- **Mobile:** the M mark and a circular menu icon button. Opening it slides a full-screen black sheet down from the top border with large Inter Black links, the three download buttons, and a close button. The sheet traps focus while open. Escape, the close button, or choosing a link closes it by sliding it back up. The page behind it does not scroll.
- **Keyboard:** a skip link to the main content appears first on focus. All items are reachable in visual order.

## Footer

- **Composition:** pure black with a top hairline. A huge Tmax wordmark in the ribbon typeface bleeds wide across the footer, with a subtle marble-grey sheen. Beneath it are compact columns: Product (AI, Social, Workout Builder, Map, Stats), Get the app (App Store, Google Play, Install IPA, following the same configured-or-unavailable rules as the hub), and Contact. A bottom row holds the copyright for Tmax with the current year and a back-to-top icon button that glides to the top.
- **Behavior:** the wordmark rises slightly into place as the footer enters the view. Links follow the menu bar's hover treatment.
- **Honesty:** the footer contains no dead links. The legal pages and the NFT promotion's official rules are added when they exist.

## States

| State | Menu bar | Footer |
|---|---|---|
| Top of page | Transparent | Not visible |
| Scrolled | Dark glass | Not visible |
| Immersive hold | Hidden above the top border | Not visible |
| Mobile menu open | Full-screen sheet; page locked | Hidden behind the sheet |
| Reduced motion | No hide-on-hold; the sheet appears without sliding | The wordmark is static |
| Reduced transparency | Solid #141414 bar | Unchanged |
| Store link not configured | The download item shows "Coming soon" styling and cannot be activated | Same |

## Dependencies

- The app's theme, glass controls, and typography definitions are the direct source.
- The app's font files and licenses.
- The M mark from the app icon.

## Reference

- `TimeMaster/Utilities/Theme.swift`, `TimeMaster/Utilities/TimeMasterGlassControls.swift`, and `TimeMaster/Utilities/ProfileDesign.swift` are the direct source styles.
- `emails/` is the earlier TypeScript recreation of the app's look and a pattern to learn from.
