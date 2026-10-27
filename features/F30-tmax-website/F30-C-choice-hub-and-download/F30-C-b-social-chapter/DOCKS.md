# F30-C-b — Social Chapter

Proves without words that Tmax's social side outclasses every other platform. It then shows the real social features and reminds visitors about the NFT collectibles.

## What We Build

- **The cinematic opening (no body text, one big title):** a large title sits on top. Below it is a cinematic parallax scene that unfolds as the visitor scrolls. The logos of the big platforms (Instagram, TikTok, YouTube, X, and Facebook) are monumental marble figures or forms. They stand in a dark arena and turn toward a towering Tmax mark in the center, watching it the way a crowd watches a champion. The scene is generated with `fgen` as separate depth layers: the environment, the five spectator forms, and the central monument. Real vector platform logos and the Tmax M mark are composited by us onto blank faces. A logo is never AI-generated.
- **Parallax:** while the visitor scrolls, the layers move at different speeds. The camera seems to push into the arena, the spectators drift past at the edges, the monument grows, and dust and light move slowly.
- **The return of the app icon:** after the parallax, the Tmax app icon (the M on its black rounded square) suddenly drops back in from the top and becomes the chapter's companion. It floats in 3D as it travels beside the visitor: it tilts, catches light on its edges, and bobs slowly.
- **Social features:** beats slide out from the side borders with real recordings and short lines covering the profile, Ranked battles, Physique Duels, posts and media comments, and collectibles. Each claim matches what the app really has.
- **The NFT moment:** on one beat, one of the platform logos from the opening, such as the TikTok mark, shatters or morphs into Tmax collectibles, which become NFT objects in the planned promotion. This ties the visual story back to the prize in the hero.
- **The clear-out:** the chapter swipes upward and reveals the impact stats.

## States

| State | Behavior |
|---|---|
| Arrival | The chapter slides in from the bottom border, with the title already in place over the arena. |
| Layers loading | Each layer fades in where it belongs. The scene never shows empty frames or boxes. |
| Reduced motion | A single composed still of the arena with the title. The beats are static. The logo-to-collectible change shows as a before-and-after pair. |
| Phone | A portrait crop of the arena focused on the monument, with fewer and smaller spectators. The beats stack. |

## Dependencies

- [F30-C](../DOCKS.md) for the chapter template and the switcher.
- [F30-E](../../F30-E-media-production/DOCKS.md) for the generated layers and the social recordings.
- Platform marks come from Simple Icons, under CC0. They remain the trademarks of their owners and are used for comparison.
