# F30-B — Hero and Feature Film (Sections 1 and 2)

The opening of the site is one continuous film that the visitor drives by scrolling. It opens on a classical white marble statue looking down at a phone that shows the real Tmax app. The film pushes in until the phone fills the screen, races through every feature of the app, and ends in a three-second TikTok-style edit before the page changes completely.

## What We Build

- The hero: the statue film on pure black, the headline, the live member counter with its NFT prize tag, and Install Now.
- The scroll-driven film: the camera push-in from the hero composition to the phone held in the marble hand.
- The phone screen: the film's green screen is replaced by real Tmax recordings. The recording always sits correctly inside the phone screen in perspective, behind any marble finger that overlaps it.
- The feature word sequence above the phone and a TikTok-style action rail beside it.
- The three-second word-highlight edit that hands off to the choice hub.

## The Film Itself

- It is generated once with Kling 4.0 on Higgsfield from two approved still frames ([F30-E](../F30-E-media-production/DOCKS.md)). The first frame is the hero composition: the statue's head at the upper left, the phone near the center, and the right side empty for the copy. The last frame is the phone upright, centered, and facing the viewer, held by the marble fingers, with the statue's head out of focus at the far left.
- Between those frames, the statue lifts the phone and turns it toward the viewer while the camera pushes in. The statue behaves like living marble: it is slow, calm, and never deformed.
- The phone screen in the source film is flat chroma green. On the site it shows our recordings, with the black Dynamic Island staying on top as on a real phone.
- The film's background is pure black and matches the page exactly. Its edges dissolve into the page so no frame boundary is ever visible.

## Section 1 — Hero

- **Composition (desktop):** the statue film fills the viewport. The headline "A Fitness Everything App You Dreamed Of" sits in the empty right side, in large Inter Black across up to four lines. Below the headline sits the member counter, and to its right the Install Now action. This follows the sketch.
- **Member counter:** a compact card that shows a large, comma-separated member count, such as 27,726. A green live dot gently pulses beside it. The number only ever goes up. It rises at a believable rate, with occasional small bursts, and its digits roll upward like an odometer. Every visitor sees roughly the same number at the same moment, and it continues where it left off after a reload. It is simulated by design.
- **Prize tag:** a small tilted label that reads "$10–150" is pinned over the counter's top-left corner like a price sticker. It explains the promotion: every new sign-up gets a chance to win a free NFT worth $10 to $150. Hovering over or focusing the counter reveals a one-line explanation. Screen readers hear the full sentence once.
- **Install Now:** the prominent recreated action button. Activating it glides the page quickly, in about one and a half seconds, through the whole film to the choice hub's download area. The visitor glimpses the film flying past, which is meant to tempt them to scroll back up. The glide skips the three-second edit.
- **Feel:** the hero should feel like fear of missing out. The number is moving, the prize is real, the app is already running in the statue's hand, and the call to action is impossible to miss.
- **Idle life:** while the visitor rests at the top, the phone screen keeps playing a real app recording. When the source film allows it, the first moments of the film also breathe in a gentle, seamless loop.

## Section 2 — The Feature Film (Scroll Story)

1. **Push-in:** as the visitor scrolls, the page is held while the film advances frame by frame with the scroll position, and it rewinds when they scroll back. The hero copy leaves by sliding out through the right and bottom borders as the camera starts moving. The menu bar slides away upward.
2. **The word:** when the phone arrives at the center, a large word appears above it: "Workout...", with the dots typing in. The phone shows the matching recording.
3. **Every feature, faster and faster:** each further scroll step swaps the word and the phone's recording to the next feature. The first steps are generous. Every following step is noticeably shorter, so the changes accelerate until they flicker past. The sequence covers every feature of the app, ordered so that each word matches its recording: Workout, Timer, Builder, Database, Map, Routes, AI Coach, Agents, Analytics, Streaks, Schedule, Music, Ranked, Duels, Profile, and Collectibles. Recordings that do not exist yet are skipped rather than faked.
4. **The action rail (current interpretation of the sketch's four circles):** four circular glass buttons sit on the phone's right edge, TikTok-style: like, comment, share, and save. Their counts tick up with every feature change, and the like heart pops in orange.
5. **The page-change edit (three seconds):** when the sequence reaches the end, a timed three-second edit takes over the whole screen. A wall of big feature words fills the frame. One word at a time is highlighted with a solid orange block and black text. The highlight jumps between words extremely fast and keeps accelerating, while the whole scene zooms in cinematically toward the viewer. Brief flash frames land on the beat. The page holds still for these three seconds. Scrolling cannot interrupt the moment, but it is never blocked for longer.
6. **Hand-off:** after the edit, the page changes completely. The choice hub slides in from the bottom border and covers the film. The edit plays again only if the visitor scrolls back into the film's end and comes down again.

## States

| State | Behavior |
|---|---|
| Loading | The poster (first frame with a real app screen) appears instantly. The remaining film frames load progressively, and the film scrubs through the nearest loaded frame without blanks. |
| Recording not loaded | The phone shows that recording's poster image. |
| Visitor scrolls backward | The film rewinds smoothly. Words and recordings step back. Hero copy returns by sliding back in. |
| Install Now glide | Passes through the film without triggering the edit and lands on the hub. |
| Mid-edit | Three seconds, no input interruption, then the hand-off. |
| Reduced motion | No held film. The hero shows the poster with a playing recording. Section 2 becomes a calm, static list of features with stills. The edit is replaced by a simple dissolve to the hub. |
| Phone, portrait | The film is cropped around the statue and phone. The headline sits above the art, and the counter and Install Now sit below it. The word sits above the phone, and the rail fits within the screen's safe area. |
| Tablet and small laptop | The headline wraps tighter and the film crop shifts to keep the face and phone. |
| Large display | The film covers the viewport on black. Text stays within a comfortable width. |
| No JavaScript | Static poster, the headline, the counter number, and Install Now as a plain link to the hub. |

## Animation Rules

| Animation | Feel | Timing | Trigger |
|---|---|---|---|
| Film push-in | Exactly follows scroll | Tied to the hold distance | Scroll |
| Hero copy exit | Slides out through its nearest border | First fifth of the push-in | Scroll |
| Counter digits | Odometer roll upward | About 0.6 s per change | Simulated arrival |
| Live dot | Soft pulse | About 1.6 s loop | Always |
| Word swap | A quick cut with a short upward slide | About 0.25 s at first, then near instant | Each feature step |
| Rail counts | Tick up, with the heart popping | Under 0.4 s | Each feature step |
| Page-change edit | Highlight jumping faster and faster, zooming in, flashes on the beat | Exactly 3 s | Reaching the end |
| Hub hand-off | Hub slides in from the bottom border | About 0.9 s | After the edit |

## Dependencies

- [F30-A](../F30-A-design-system-and-chrome/DOCKS.md): the buttons, tokens, menu bar behavior, and smooth scrolling.
- [F30-E](../F30-E-media-production/DOCKS.md): the generated film, its derived frames and phone-screen tracking, and the app recordings.
- [F30-C](../F30-C-choice-hub-and-download/DOCKS.md): the hub that receives the hand-off and the download area that Install Now targets.

## Reference

- `genesis/REFERENCE/website/hero-film/`: the approved first and last frames, the prompts, and the generated source film. These are direct assets.
