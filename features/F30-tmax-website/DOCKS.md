# F30 — Tmax Marketing Website

The public, professional website for Tmax: a single long cinematic page that sells Tmax as "A Fitness Everything App You Dreamed Of." It is built as a Next.js and TypeScript site that lives in the repository's `website/` folder, next to the native app, the email workspace, and the servers.

## Source of Truth

- The user's seven annotated sketch frames from 2026-10-26: Section 1 (hero), Section 2 (feature film), Section 3 (the choice hub, the download call to action, and the AI and Social chapters), and Section 4 (impact stats).
- The user's direct answers in the same session: the hero film shows a classical, curly-haired, David-style white marble statue; the AI mascot's name was delegated, and the mascot is named **Talos**. The name references the bronze automaton of Greek myth, which suits both an AI agent and the site's marble theme.
- The user's spoken directions: the website background is pure black, and the hero film's background is the same pure black. The site uses Next.js with clean TypeScript. Button styles are recreated from the native app. The menu bar and footer use the app's style. The hero film is made in one perfect generation without wasting credits. The user first asked for Seedance 2.5; Seedance 2.5 and Seedance 2.0 both require a Higgsfield Pro plan, so the user approved Kling 4.0 for the single take. Still cinematics are generated with `fgen` and composited by us. Every app recording on the site is recorded by us from the real app.

Where this document interprets a sketch, the interpretation is labeled as the current direction for human review.

## What We Build

- One page, which flows top to bottom: Site Chrome (menu bar) → Section 1 Hero → Section 2 Feature Film → Section 3 Choice Hub with Download call to action → the selected Chapter (AI, Social, Workout Builder, or Map) → Section 4 Impact Stats → Footer.
- A recreated web version of the app's button and surface system, written in TypeScript, used by every interactive element on the site ([F30-A](F30-A-design-system-and-chrome/DOCKS.md)).
- The Section 1 hero and Section 2 film: a generated marble-statue film whose green phone screen is replaced by real Tmax recordings, driven by scroll ([F30-B](F30-B-hero-and-feature-film/DOCKS.md)).
- The Section 3 choice hub with a download call to action and four chapters, one for each way a visitor can choose ([F30-C](F30-C-choice-hub-and-download/DOCKS.md) and its children).
- The Section 4 funny, punchy impact numbers ([F30-D](F30-D-impact-stats/DOCKS.md)).
- Every media asset the page needs: app recordings, the hero film, the Talos 3D model, and generated cinematic stills ([F30-E](F30-E-media-production/DOCKS.md)).

## Page Flow

1. The visitor lands on pure black. The marble statue looks down at a phone that is already showing the real app. The headline, the live member counter with its prize tag, and Install Now sit on the right.
2. Scrolling stops moving the page and starts playing the film. The camera pushes toward the phone, the hero copy leaves, and the phone ends centered, still held by the marble hand.
3. A single word above the phone names the feature currently shown on the screen, starting with "Workout...". Each step of scrolling brings the next feature, and the changes get faster and faster until every feature in the app has appeared.
4. A three-second, TikTok-style word-highlight edit plays: one highlighted word switches extremely fast while the scene zooms in cinematically. Then the page changes completely.
5. The choice hub slides in from the bottom border. The page is held still while scrolling moves through four platforms: AI, Social Media, Workout Builder, and Map. A download call to action with an epic background is always available here.
6. The visitor's choice, or AI by default, slides in from the border as the next chapter. Each chapter tells its feature's story with slide-out app recordings and ends by clearing itself away with an upward swipe.
7. The impact stats prove the scale of the problems Tmax solves, and the footer closes the page.

Install Now in the hero fast-scrolls through the whole film straight to the choice hub. The visitor catches only flashes of the film, which is intended to make them want to scroll back up and watch it.

## Global Visual Language

- **Background:** pure black (#000000) everywhere, including behind and around every film and image. There are no visible seams where media meets the page.
- **Accent:** the app's orange (#FF6A00) is the only accent color. Green (#34C759) is reserved for the live indicator.
- **Surfaces:** the app's near-black surfaces (#141414 and #1C1C1C), hairline white rims, and tinted glass on controls.
- **Imagery:** white Carrara marble, dramatic low-key light, warm key light, a cool rim light, and orange light accents. Images never contain baked-in text or fake interface.
- **Typography:** Inter Black for headlines, controls, and numbers; Manrope Regular for body copy and small labels; genuine Inter Black Italic for emphasis. The original TimeMaster ribbon typeface is reserved for top-of-page and navigation titles only.
- **Corners:** controls use the app's 18 pt control radius, cards use 20 pt, and small chips use 12 pt. No other radius family is introduced.
- **Copy:** short, punchy, confident, and a little funny. Copy creates fear of missing out without inventing features. No em dashes appear in visible copy.

## Signature Motion

- **Slide in from the border:** every change of section, chapter, or menu slides in from a page edge, usually the top or bottom border, instead of fading from nowhere. The incoming surface moves from beyond the edge to rest while the outgoing surface leaves through the opposite edge. This is the site's single, recognizable transition.
- **Held sections:** the film, the hub, and chapter moments hold the page still while scrolling continues to drive the animation. Holds release naturally at their ends.
- **Smooth scrolling:** the page scrolls with gentle inertia. Programmatic jumps, such as Install Now and menu links, use a fast, eased glide rather than a teleport, except where reduced motion asks for an instant jump.
- **Press feedback:** every control shrinks slightly and dims while pressed, using the app's spring.

## Global States

| State | Behavior |
|---|---|
| First load | Black page, hero poster frame, and copy appear immediately. The film's remaining frames and recordings load progressively, and the hero is usable before they finish. |
| Media still loading | Held sections show the nearest loaded frame. The film never shows blank frames or spinners over the art. |
| Slow or failed media | Posters replace videos. The page remains readable and every control works. |
| Reduced motion | No held-scroll hijacking, no timed autoplay sequences, and no zooms or flashes. Sections show their key frames and final states, and transitions become short dissolves. |
| Reduced transparency | Glass controls become solid app surfaces. |
| Keyboard only | Every control is reachable in order, focus rings are clearly visible, the hub can be operated with arrow keys and Enter, and timed sequences never trap focus. |
| Screen reader | The film is described in text, decorative motion is hidden, live counter changes are not announced continuously, and every chapter has a real heading. |
| Small phone, portrait | Films are cropped around the subject, copy stacks below the art, held sections shorten, and the menu becomes a full-screen sheet. |
| Large display | Content stays within a comfortable width while art bleeds to the edges on black. |
| No JavaScript | Static hero poster, readable copy for every section, working download and anchor links. |

## Honesty Rules

- The live member counter is simulated. The user approved this explicitly, and it must still behave believably by only ever counting upward.
- The NFT prize (a free NFT worth $10 to $150 for new sign-ups) describes a planned promotion that starts after launch.
- Impact numbers are playful marketing figures requested by the user and are presented with humor.
- Download buttons use configured store and IPA links. While a link is not configured, the button presents an honest unavailable state instead of a broken destination.
- Every app recording is a real recording of the real app.

## Sub-Features

- [F30-A — Design System and Site Chrome](F30-A-design-system-and-chrome/DOCKS.md)
- [F30-B — Hero and Feature Film](F30-B-hero-and-feature-film/DOCKS.md)
- [F30-C — Choice Hub and Download](F30-C-choice-hub-and-download/DOCKS.md)
  - [F30-C-a — AI Chapter: Talos](F30-C-choice-hub-and-download/F30-C-a-ai-chapter/DOCKS.md)
  - [F30-C-b — Social Chapter](F30-C-choice-hub-and-download/F30-C-b-social-chapter/DOCKS.md)
  - [F30-C-c — Workout Builder Chapter](F30-C-choice-hub-and-download/F30-C-c-workout-builder-chapter/DOCKS.md)
  - [F30-C-d — Map Chapter](F30-C-choice-hub-and-download/F30-C-d-map-chapter/DOCKS.md)
- [F30-D — Impact Stats](F30-D-impact-stats/DOCKS.md)
- [F30-E — Media Production](F30-E-media-production/DOCKS.md)

## Dependencies

- The existing native app features that are recorded: workouts and the player, the builder, the exercise database, outdoor maps, the AI coach and agent settings, analytics, schedule, music, Ranked, profile, and collectibles. The website does not change any native behavior.
- Brand assets: the app icon and M mark, the Talos mascot artwork, and the app's fonts and their licenses.
- Higgsfield (Kling 4.0 video and image-to-3D) and `fgen` for generated media.

## Reference

- `genesis/REFERENCE/website/`: hero film prompts, candidate frames, and the generated film source. These are direct production assets.
- `genesis/REFERENCE/tmax-branding/` and the app's asset catalog (`RankedHero`, `AppIcon`, `TmaxLogo`): brand marks and the mascot. These are direct assets.
- `emails/`: the precedent for recreating the app's native style in TypeScript. This is a pattern to learn from.
- The app's `Theme.swift`, `TimeMasterGlassControls.swift`, and `ProfileDesign.swift`: the source styles that the web buttons and type recreate. This is a direct reference.

## Open Questions

- Real App Store, Google Play, and signed IPA destinations do not exist yet. The site is built to take them from configuration.
- The official sweepstakes rules for the NFT promotion and the privacy and terms pages are not written yet. The footer leaves room for them.
- The sketch's four circles beside the phone in Section 2 are interpreted as a TikTok-style action rail. This interpretation awaits review.
- The AI chapter's agent-creation moment gives the agent its own username, as the user described. The current app does not yet have usernames for bots, so the moment presents an upcoming capability.
- Posts, reactions, and replies in the app currently stay on the user's own profile. The Social chapter copy avoids implying that other people react to them until public sharing exists.
