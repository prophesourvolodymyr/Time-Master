# F30-D — Impact Stats (Section 4)

The section that shows the scale of everything Tmax fixes, all at once. Per the user, it is funny and punchy at the same time, so visitors get it at a glance.

## What We Build

- **The headline:** "The damage report."
- **A segmented control** recreated from the app's selection buttons, with two options: Per person and Collection. Collection is selected first because it shows the biggest numbers. Switching modes rolls every number to its new value.
- **Eight cards** in a three, three, and two grid. The last two are centered beneath the first six, as in the sketch. Each card shows a small label, a huge number, an outcome word, and a one-line joke:

| Label | Collection | Per person | Outcome | Joke |
|---|---|---|---|---|
| Workout procrastination | 55,000,000 h | 312 h | Saved | Every "I'll start Monday", cancelled. |
| Database of exercises | 500+ | 500+ | Collected | Including at least 40 ways to hate leg day. |
| Useless subscriptions | $150,000,000 | $480 | Saved | Five apps walked so one could run. |
| Fitness community | 100,000+ | 38 | Collected | Gym friends, minus the awkward small talk. |
| Ranked rivals | 5,775 | 4 | Collected | They want your Elo. Let them try. |
| NFT money | $15,000,000 | $10–150 | Made | Sweat in. Collectibles out. |
| Muscle | 558,848 lb | 6 lb | Gained | About 93 elephants of pure gains. |
| Main-character energy | 4,774,774 | 100% | Gained | Unit of measurement pending. |

- The two cards that set the tone, NFT money and main-character energy, use the emphasized orange card treatment.
- **A small footnote** keeps it honest: "Playful math. Real gains vary."

## Interpretation Notes

- The sketch labels two cards "Fitness Community People". The second card, 5,775, is presented as Ranked rivals so the two cards don't repeat. The last sketch card has a number but no label, and is presented as main-character energy.
- The figures are the user's playful marketing numbers, not measurements.

## States

| State | Behavior |
|---|---|
| Entering view | Each number counts up from zero once. |
| Switching mode | Numbers roll from their current value to the new value. Text values such as $10–150 swap directly. |
| Reduced motion | The numbers appear final immediately, with no counting. |
| Phone | One column, then two columns on wider phones and tablets. Numbers never wrap mid-number. |
| Screen reader | Each card reads its label, final value, outcome, and joke. |

## Dependencies

- [F30-A](../F30-A-design-system-and-chrome/DOCKS.md): the card surfaces and the segmented control.
