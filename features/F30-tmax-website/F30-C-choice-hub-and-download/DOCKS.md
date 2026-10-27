# F30-C — Choice Hub and Download (Section 3)

After the film, the page changes completely and lets each visitor choose the story they care about. AI is what most people are curious about, but some visitors came for the social side, the workout builder, or the maps. The hub is a held section: the page stops moving while scrolling selects between platforms. It always offers a direct download for people who are already sold.

## What We Build

- The hub: a held section with four selectable platforms (AI, Social Media, Workout Builder, and Map). Each platform shows its name and its icon in the middle.
- The download call to action: an epic, generated cinematic background with three download buttons (App Store, Google Play, and Install IPA).
- The chapter slot: the selected chapter (default AI) renders right after the hub and slides in from the border whenever it changes.
- A compact chapter switcher at the top of every chapter, so a visitor can jump to another story at any time.
- The shared chapter template that all four chapters follow.

## Hub Behavior (current direction)

1. **Arrival:** the hub slides in from the bottom border over the end of the film. The headline asks the visitor to choose, short and confident. For example: "Pick your obsession."
2. **The platforms:** four large platform tiles sit in a row on desktop and a vertical stack on phones. Each tile is a card surface whose icon sits on a softly lit pedestal of marble and orange light, with the platform name below it in Inter Black. A small live preview (a muted app recording) plays inside the focused tile.
3. **Scrolling selects:** while the hub is held, each step of scrolling moves the focus to the next platform, in the order AI, Social Media, Workout Builder, and Map. The focused tile grows, gains the orange rim and pedestal glow, and plays its preview. The others recede.
4. **Clicking selects:** clicking or tapping a tile, or pressing Enter or Space on a focused tile, chooses that platform immediately. The chosen tile flashes once. The hub slides out through the top border while the chosen chapter slides in from the bottom border, and the page glides into it.
5. **Scrolling through without choosing:** the visitor continues into the AI chapter, the default and the topic everyone is interested in, with the same slide-in.
6. **Returning:** scrolling back up from a chapter returns to the held hub with the current chapter's tile focused.
7. **Keyboard:** the arrow keys move focus between tiles, Enter chooses, and Tab moves on to the download buttons. Every tile is a real button with its name.

## Download Call to Action

- **Placement:** the lower band of the hub, with the anchor target `#download`. Install Now in the hero and the menu bar's Install action both land here.
- **Background:** an epic, generated cinematic scene that sits behind the buttons and dissolves into pure black at its edges. It shows the marble world of the site: the David-style statue or a monumental marble form, rim-lit in orange, rising out of darkness. It is never stock imagery and contains no baked-in text.
- **Copy:** a short line for people who do not need the tour. For example: "Skip the tour. Start training."
- **Buttons:** three recreated action buttons with official brand glyphs: App Store (Apple mark), Google Play (Play mark), and Install IPA (a direct-download icon). The App Store button is prominent.
- **Configured link:** opens the store, or starts the IPA install, in a new context where appropriate.
- **Unconfigured link:** the button reads "Coming soon", is visibly disabled, cannot be activated, and explains its state to screen readers. No invented URLs.

## Chapter Template (shared by all four chapters)

- **Intro moment:** a full-screen title moment that is specific to the chapter.
- **Feature beats:** each beat slides in from a side border. A real app recording sits in a device frame, with one or two short lines of text and at most one supporting visual. Beats move fast: the scroll snaps from one beat to the next, so each swipe brings a new beat.
- **Traveling companion:** where the chapter calls for one (Talos in AI, the 3D app icon in Social), it travels with the visitor between beats along a deliberate path.
- **Outro:** the chapter clears itself away with an upward swipe and reveals the impact stats.
- **Chapter switcher:** small selection buttons with the four platform icons sit pinned at the top of the chapter while it is in view.

## States

| State | Behavior |
|---|---|
| Arrival from the film edit | The hub slides in from the bottom border. Focus starts on AI. |
| Arrival from Install Now or the menu Install action | Lands on the download band with the hub visible. |
| Focused tile | Enlarged, orange rim, pedestal glow, and a live preview. |
| Other tiles | Smaller and dimmer, with a poster still. |
| Chosen | A single flash, then the chapter transition. |
| Chapter switch while inside a chapter | The current chapter leaves through the top border while the new one slides in from the bottom, and the page stays at the chapter start. |
| Reduced motion | No hold. The tiles are a plain grid of buttons, the chapter swaps with a short dissolve, and previews show posters. |
| Phone | Tiles stack vertically. Scrolling selects in the same order. The download buttons stack full width. |
| Download link missing | "Coming soon" disabled state. |

## Dependencies

- [F30-A](../F30-A-design-system-and-chrome/DOCKS.md): the buttons, selection buttons, card surfaces, smooth scrolling, chapter state, and border slide.
- [F30-B](../F30-B-hero-and-feature-film/DOCKS.md): the film hands off to this hub.
- [F30-E](../F30-E-media-production/DOCKS.md): the app recordings and generated backgrounds.

## Children

- [F30-C-a — AI Chapter: Talos](F30-C-a-ai-chapter/DOCKS.md)
- [F30-C-b — Social Chapter](F30-C-b-social-chapter/DOCKS.md)
- [F30-C-c — Workout Builder Chapter](F30-C-c-workout-builder-chapter/DOCKS.md)
- [F30-C-d — Map Chapter](F30-C-d-map-chapter/DOCKS.md)
