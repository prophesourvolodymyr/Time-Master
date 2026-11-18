# Camp 2: workouts report (CampWriter, 2026-11-18)

Files: `~/.tm-ingest/bin/camp2_content.py` (the data and `check()`), this report. Nothing in the app, the repo or the library was touched; the library was only read from disk (manifests, through `camp_lib.Resolver`).

## Result

`python3 ~/.tm-ingest/bin/camp2_content.py` prints one row per workout (96 rows) and exits 0:

```
VERDICT: PASS: 96 workouts, 0 unresolved pages, 0 workouts more than 12% off their planned minutes (range -9.1% to +9.8%), 0 problem(s)
```

| Count | Value |
|---|---|
| Workouts | 96 (8 weeks x 12 sessions, Sunday off) |
| Distinct pages | 127: 115 already in the library (incl. the 5 ball warm-up pages), 12 NEW_PAGES |
| Library pages without a clip | 7: Shadowboxing Round, Toes-to-Bar Top-Down Hold, Straddle Press Negative (Lowering from Handstand), Muscle-Up (skill), Loaded Pancake (Light Weight), Weighted Dip, Hill Sprint (20 m) |
| Pages without a clip in total | 19 (the 7 above + the 12 NEW_PAGES, which have no video yet) |
| Skill pages used | 17, only where the block is that skill (planche holds, muscle-up attempts, press attempts, boxing themes, takedowns, wall get-up) |
| NEW_PAGES | 12 |
| PLANNED_PAGES | 5 (the ball warm-up pages; all 5 already exist in the library, with clips) |
| Most foot contacts in a session | 87 (week 6 Monday; the cap is 100) |
| Longest rest value used | 120 s (fits the app's 0-120 s steppers) |

`check()` also fails on: a page that does not resolve, a NEW page whose parent folder is missing or whose title already exists, a NEW page body without the library style, fewer than 4 or more than 8 sections, an unknown type, a deep static stretch in a morning session or before the end of an evening session, PNF pancake outside Thursday and Saturday, partner rounds before week 5, more than 100 foot contacts, two pull-heavy blocks outside Monday and Saturday AM, a NEW page that is never used, and GROUPS not matching the workouts. `python3 camp2_content.py --report` prints the generated tables used below.

## How it is built

- `TEMPLATE` is week 1 as data: 12 sessions, each a list of blocks with week-1 numbers. `week_knobs()` turns them into week N with one small table set: `STEP` (small steps in weeks 2-3), `PEAK_FROM` (one extra unit in week 6), `VOL` (set and round counts in weeks 4, 7, 8), `TB` (boxing technique minutes in weeks 4, 7, 8), `HARD_FROM` (harder variants from week 5). Each block names the one knob it raises, its peak knob, what VOL/TB scale and its week-5 replacement. No workout is written by hand twice.
- Estimates use the app's own arithmetic, read from `TimeMasterCore` (`calculatedDuration`, `AgentToolbox.sectionManifest`): a 4 s prepare countdown before every set of a plain section and every round of a bundle, every bundle exercise's `restAfter`, the round rest replacing the last exercise's rest, no rest after the last round, `restAfter` (or the 20 s `restBetweenSections`) between sections. So the minutes in the table are the minutes the app will show.
- Between-sets moves (↔) are bundles `[main, move]` with the round rest = the SPEC rest minus the move's 30 s (for example explosive pull-ups: 120 s = 30 s dislocates + 90 s). Blocks with two main exercises put a move and the same full rest after each (Plyos A, planche, L-sit / V-sit).
- Rep-based blocks are `untimed: True` with an estimate in `duration` (about 3-7 s a rep plus set-up); holds, flows, stretches and rounds on a clock are timed. In an untimed bundle the 30 s move is also "until Done"; its name says 30 s.
- Every bundle exercise carries `restAfter` (the last one 0) and `repCount` where it is counted, so the builder never falls back to page defaults.

## Decisions and deviations from the SPEC

1. **Planned minutes vs block minutes.** In several sessions the SPEC's block minutes do not add up to the planned minutes once rests and the app's prepare seconds are counted. Over: Mon PM (about 79 min of content for 70), Tue AM (about 50 for 45), Sat AM (about 49 for 40). Under: Wed AM (about 30 for 40), Thu AM (about 29 for 35), Wed PM (about 58 for 70), Fri PM (about 70 for 85). I kept every block and fixed each session as follows (the 12% rule is unchanged):
   - Mon PM: technique 15 → 11.5 min (two themes of 5.5 min), called-combo rest 30 s (not given in the SPEC), "film one round and check it" folded into the names (film the last mirror round, watch it during the evening stretch) instead of its own section.
   - Tue AM: Flow B with 6 wrist moves = 9 min (wrist prep inside it, as the SPEC allows); handstand balance 7 attempts (10.5 min instead of 12); press strength 3 rounds (11 min instead of 14).
   - Sat AM: Flow B + 2 wrist moves 6 min (SPEC 8), transition drills 3 x 3 banded muscle-ups (about 4.5 min instead of 10), handstand 4 attempts (6 instead of 8), press practice 3 short rounds; no extra explosive pull-up set in week 3 (the main muscle-up progression is on Monday).
   - Wed PM: "planche leans and tuck holds 5 x 8 s" is read as 5 leans and 5 tuck holds, each followed by the 120 s (30 s leg swings + 90 s). That gives the 20 minutes the plan's 70 needs.
   - Wed AM: added sprint drills (B skip, C skip, carioca, 2 x 20 m each) and 5 build-up strides after a 4 min jog; the sprints keep 90 s (30 s walking lunges + 60 s). The walk back down happens in the rest.
   - Thu AM: holds keep their doses; the rest after each hold is 75 s (30 s move + 45 s), the light-day way to fill the 35 min.
   - Fri PM, Tue PM, Mon AM: 60-120 s `restAfter` after hard blocks or station changes (backyard to bar, band set-up, water), as the SPEC suggests ("for example 60 s after a hard block"); shots and sprawls rest 90 s.
2. **Light weeks (4, 7, 8).** Counts (sets, rounds, sprints, bike minutes) × VOL (0.65, 0.65, 0.55), half-up rounding; boxing technique minutes × TB (0.8, 0.8, 0.75); warm-ups, flows, cool-downs and evening stretches unchanged (same session shapes; they are not training load). Reps and holds stay at the week-3 level (week 4) or the week-6 level (weeks 7-8): intensity kept. The planned minutes of a light week are not in the SPEC, so they are derived: the loading week it is cut from (3 for week 4, 6 for weeks 7-8) with each block at that share. The check therefore tests that whole-set rounding keeps each light session within 12% of the rule.
3. **Order of Thursday AM**: active mobility (warm-up) → handstand → hollow + arch → L-sit / V-sit, following "skills first, fatigue later" (the SPEC lists the holds first).
4. **Checkpoint tests** (Sat AM, weeks 1, 4, 8; 40 min, Skill Work): Flow A+B short, max handstand hold x2, press attempts x3, front lever x2 (best progression), max strict pull-ups, broad jump x3, 20 m uphill sprint x2. Same as the SPEC except the order (press next to the handstand, front lever before the max pull-ups) so that the max set does not spoil the lever test. Same order in all three test weeks. The muscle-up 2 work is skipped those Saturdays, as the SPEC says.
5. **"L-sit / V-sit holds 3 x 10 s"** (Thu) = 3 holds in all, alternating L-sit and V-sit; **"hollow + arch holds 3 x 20 s"** = 3 of each (the "+" means both). "L-sit / compression holds" (Wed) = L-sit holds.
6. **Week 8 Saturday PM** is titled `Boxing 2 (easy)` (the SPEC only says "Saturday PM easy"): no finisher, fewer rounds. Weeks 4 and 7 add "(light)"; week 8 Mon-Fri keeps the plain titles, as the SPEC says.
7. **Priming (coordinator's change, 2026-11-18):** the planned page `Isometric Punch Priming` was dropped. Priming now uses the library's isometric pages with clips: `Overcoming Isometric Punch Wall` (cross into the wall, 5 s), `Overcoming Isometric Punch Pole` (hook into the door frame, 5 s), `Post-Isometric Shadow Punches` (5-8 light, fast punches), then `Banded Shadow Boxing` 30 s (optional); 2 rounds, about 3 min. PLANNED_PAGES is now only the five ball warm-up pages.
8. **Harder variants from week 5:** front lever tuck → advanced tuck (band if needed); planche lean + tuck → tuck + advanced tuck "band around the hips from the bar if needed" (the band-assisted straight-arm progression); banded muscle-up drill → muscle-up attempts (1 rep, 120 s rest); Plyos A broad jumps → bounds and continuous squat jumps; Plyos B lateral bounds continuous (reactive); uphill sprints from reactive starts (random cue); boxing counters and ring craft themes; Friday rounds → positional rounds with a partner (no partner: shadow). Holds restart at 8 s with the harder variant; week 6 adds one set (the peak). Variants are kept in weeks 7-8.
9. **Pull-heavy rule:** Monday (explosive pull-ups + muscle-up) and Saturday AM are the only sessions with two pull-heavy blocks, as the template says; Wednesday's scapular pulls are light. The test session has the lever and max pull-ups by design.
10. **Wrestler circuit on Tuesday** is 1 round (the SPEC's "1 set fewer"), Friday 2 rounds.

### Boxing themes (2-week blocks, the order taught in the boxing research)

| Weeks | Theme 1 (page) | Theme 2 (page) |
|---|---|---|
| 1-2 | Jab: step in, jab, step out (`Boxing/Jab`) | Jab defence: parry, then slip (`Boxing/Parry`) |
| 3-4 | Cross and the 1-2 (`Boxing/Straight Punch/Cross`) | Block and step back from the 1-2 (`Boxing/Block`) |
| 5-6 | Counter: slip the jab, answer 1-2 (`Boxing/Head Movement/Slip`) | Ring craft: cut off the ring, take angles (`Boxing/Cutting Off the Ring`) |
| 7-8 | Fight combos: jab to the body, 1-2 (`Boxing/Jab/Jab to the Body`) | Off the ropes: step out at 45 degrees (`Boxing/Getting Off the Ropes/Dart Out of the Corner`) |

### Wrestling takedowns (2-week blocks; Tuesday shadows the first two, Friday drills all three)

| Weeks | 1 | 2 | 3 |
|---|---|---|---|
| 1-2 | Double leg (`Wrestling/Double Leg Takedown`) | Single leg, sweep single entry (`.../Sweep Single Entry (Hit and Follow)`) | Body lock outside trip (`.../Cover and Crash Body Lock Outside Trip`) |
| 3-4 | Body lock outside trip | Arm drag (`Wrestling/Arm Drag`) | Double leg |
| 5-6 | Double to single chain (`.../Double Leg to Single Leg Chain`) | Knee pick off the underhook (`Wrestling/Underhook/Knee Pick off the Underhook`) | Double leg |
| 7-8 | Double leg | Double to single chain | Body lock outside trip |

## Pages per block

Generated by `camp2_content.py --report` (week-1 block names; "from week 5" = the harder variant's extra pages).

### Mon AM · Plyos A + muscle-up 1 (60 min, Conditioning)

| Block (week 1 name) | Pages |
|---|---|
| Flow A+B short 12 min: hips, shoulders, feet | `Mobility & Flexibility/Spine/Cat-Cow` (clip)<br>`Mobility & Flexibility/Warm-Ups/World's Greatest Stretch` (clip)<br>`Mobility & Flexibility/Hips/90-90 Hip Rotation` (clip)<br>`Mobility & Flexibility/Hips/Cossack Squat Flow` (clip)<br>`Mobility & Flexibility/Hips/Spiderman Lunge` (clip)<br>`Mobility & Flexibility/Shoulders/Resistance Band Shoulder Dislocates` (clip)<br>`Mobility & Flexibility/Stretching/Cross-Body Arm Swings` (clip)<br>`Mobility & Flexibility/Spine/Thread the Needle` (clip)<br>`Strength & Conditioning/Force Absorption & Hips/Single-Leg Balance Stand` (NEW page)<br>`Strength & Conditioning/Force Absorption & Hips/Loaded Calf Raise` (clip) |
| Plyos A 3 rounds: pogo 8, squat jumps 8, broad jumps 4 (leg swings between, 75 s) | `Strength & Conditioning/Plyometrics/Pogo Hops` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Front to Back)` (NEW page)<br>`Kickboxing/Kick Mobility & Conditioning/Squat Jumps` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Side to Side)` (NEW page)<br>`Strength & Conditioning/Plyometrics/Standing Broad Jump` (NEW page)<br>from week 5: `Strength & Conditioning/Plyometrics/Bounds` (clip) |
| Explosive pull-ups 5x3 (band dislocates between, 120 s) | `Calisthenics/Muscle-Up/Explosive Pull-Up` (clip)<br>`Mobility & Flexibility/Shoulders/Resistance Band Shoulder Dislocates` (clip) |
| Muscle-up transition drill: banded muscle-ups 6x3 | `Calisthenics/Muscle-Up/Banded Muscle-Up` (clip)<br>from week 5: `Calisthenics/Muscle-Up` (no clip) |
| Strict dips 3x8, bodyweight | `Strength & Conditioning/Lifting & Gym/Weighted Dip` (no clip) |
| Hanging leg raises 3x6 (toes-to-bar prep) | `Gymnastics/Strength Skills/Hanging Leg Raise` (clip) |

### Mon PM · Boxing 1 (home) (70 min, Boxing)

| Block (week 1 name) | Pages |
|---|---|
| Ball warm-up 4 min: 5 moves x8, small range first | `Mobility & Flexibility/Spine/Ball Spine Extension and Flexion` (clip)<br>`Mobility & Flexibility/Spine/Ball Shoulder Extension and Flexion` (clip)<br>`Mobility & Flexibility/Spine/Ball Shoulder Adduction and Abduction` (clip)<br>`Mobility & Flexibility/Spine/Ball Spine Rotation` (clip)<br>`Mobility & Flexibility/Spine/Ball Lateral Flexion` (clip) |
| Priming 3 min: isometric cross and hook 2x5 s, fast shadow punches, banded punches | `Boxing/Boxing Conditioning/Overcoming Isometric Punch Wall` (clip)<br>`Boxing/Boxing Conditioning/Overcoming Isometric Punch Pole` (clip)<br>`Boxing/Boxing Conditioning/Post-Isometric Shadow Punches` (clip)<br>`Strength & Conditioning/Bands & Cords/Banded Shadow Boxing` (clip) |
| Technique 11.5 min, 2 themes: blocked, slow to fast, mirror | `Boxing/Jab` (clip)<br>`Boxing/Parry` (clip)<br>from week 5: `Boxing/Head Movement/Slip` (clip)<br>`Boxing/Cutting Off the Ring` (clip) |
| Mirror shadow rounds 5x3 min, film the last round (shake out between, 60 s) | `Boxing/Shadow & Bag Drills/Shadowboxing Round` (no clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page) |
| Called combos 3x3 min: the timer app calls the numbers | `Boxing/Beginner Combination Ladder` (clip) |
| Finisher: punch bursts 3 rounds of 14 x (3 s all-out, 10 s easy) | `Boxing/Boxing Conditioning/Punch Bursts` (NEW page) |
| Evening stretch 10 min: hips, shoulders, hamstrings (watch the filmed round) | `Mobility & Flexibility/Stretching/Half Kneeling Hip Flexor Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Seated Glute Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Puppy Pose` (clip)<br>`Mobility & Flexibility/Stretching/Wall Chest Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Standing Hamstring Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Wall Biceps Stretch` (clip) |

### Tue AM · Handstand + press (45 min, Gymnastics)

| Block (week 1 name) | Pages |
|---|---|
| Flow B + wrist prep 9 min | `Mobility & Flexibility/Spine/Cat-Cow` (clip)<br>`Mobility & Flexibility/Spine/Thread the Needle` (clip)<br>`Mobility & Flexibility/Shoulders/Resistance Band Shoulder Dislocates` (clip)<br>`Mobility & Flexibility/Stretching/Cross-Body Arm Swings` (clip)<br>`Mobility & Flexibility/Warm-Ups/Inchworm Walk Out` (clip)<br>`Mobility & Flexibility/Stretching/Deep Squat Thoracic Rotation` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip)<br>`Calisthenics/Handstand/Reverse Wrist Circles` (clip)<br>`Calisthenics/Handstand/Wrist Circles Back of Hands` (clip)<br>`Calisthenics/Handstand/Wrist Circles Palms Down` (clip)<br>`Calisthenics/Handstand/Wrist Rocking on Fists` (clip)<br>`Calisthenics/Handstand/Finger Pulses` (clip) |
| Handstand balance 7 attempts, up to 30 s (wrist rolls between, 60 s) | `Calisthenics/Handstand/Handstand Kick-Up` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip) |
| Press strength 3 rounds: wall pike press 5, negatives 3 (90 s) | `Calisthenics/Handstand/Press to Handstand/Wall Pike Press Drill` (clip)<br>`Calisthenics/Handstand/Press to Handstand/Straddle Press Negative (Lowering from Handstand)` (no clip) |
| Shoulder shrugs + compression 3 rounds x8 | `Calisthenics/Handstand/Chest-to-Wall Handstand Shrugs` (clip)<br>`Calisthenics/Handstand/Press to Handstand/Pike Compression Lift` (clip) |
| Hollow + L-sit holds 3x15 s | `Calisthenics/Hollow Body/Hollow Body Hold` (clip)<br>`Calisthenics/L-Sit/L-Sit Hold` (clip) |

### Tue PM · Wrestling 1 (solo technique) (70 min, Wrestling)

| Block (week 1 name) | Pages |
|---|---|
| Wrestler circuit 1 round: dive bombers 10, walkouts 10, kick-throughs 30 s | `Mobility & Flexibility/Warm-Ups/Dive Bomber Push-Up` (clip)<br>`Mobility & Flexibility/Warm-Ups/Hand Walkout` (clip)<br>`Mobility & Flexibility/Warm-Ups/Kick Through` (clip) |
| Stance and motion 6 min | `Wrestling/Stance and Motion/Stance and Motion Lateral Steps` (clip)<br>`Wrestling/Mat Movement & Drills/Wrestling Stance Motion Shadow Drill` (clip) |
| Level change + shot 3x8 | `Wrestling/Penetration Step/Penetration Step Shot` (clip) |
| 2 takedowns as shadow reps 5 rounds x8: double leg, single leg (sweep single) | `Wrestling/Double Leg Takedown` (clip)<br>`Wrestling/Single Leg Takedown/Sweep Single Entry (Hit and Follow)` (clip)<br>from week 5: `Wrestling/Single Leg Takedown/Double Leg to Single Leg Chain` (clip)<br>`Wrestling/Underhook/Knee Pick off the Underhook` (clip) |
| Sprawls 4x6, hips straight down, pop up | `Wrestling/Sprawl/Sprawl Straight Down` (clip) |
| Split squat 3x8 each leg, bodyweight | `Mobility & Flexibility/Hips/Knee Over Toe Split Squat` (clip) |
| Bridge 3x20 s + neck work | `Wrestling/Wrestler's Bridge/Wrestler's Neck Bridge/Back Bridge with Hands` (clip)<br>`Wrestling/Wrestler's Bridge/Wrestler's Neck Bridge/Front Neck Bridge Rock (Hands and Knees)` (clip)<br>`Mobility & Flexibility/Neck/Lying Neck Extension` (clip) |
| Evening stretch 12 min: pancake + hips, then back relief after wrestling | `Mobility & Flexibility/Stretching/Seated Straddle Reach to Toes` (clip)<br>`Mobility & Flexibility/Stretching/Cossack Squat to Seated Straddle Fold` (clip)<br>`Mobility & Flexibility/Stretching/Couch Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Seated Glute Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Half Kneeling Hip Flexor Stretch` (clip)<br>`Mobility & Flexibility/Spine/Shoulder Roll to Supine` (clip)<br>`Mobility & Flexibility/Spine/Scorpion Stretch` (clip)<br>`Mobility & Flexibility/Spine/Cobra Side-to-Side Shift` (clip) |

### Wed AM · Uphill sprints (40 min, Conditioning)

| Block (week 1 name) | Pages |
|---|---|
| Flow A 10 min: hips, ankles, feet | `Mobility & Flexibility/Spine/Cat-Cow` (clip)<br>`Mobility & Flexibility/Wrists & Ankles/Forward Rocks` (clip)<br>`Mobility & Flexibility/Wrists & Ankles/Backward Rocks` (clip)<br>`Mobility & Flexibility/Warm-Ups/World's Greatest Stretch` (clip)<br>`Mobility & Flexibility/Hips/90-90 Hip Rotation` (clip)<br>`Mobility & Flexibility/Hips/Cossack Squat Flow` (clip)<br>`Mobility & Flexibility/Hips/Spiderman Lunge` (clip)<br>`Strength & Conditioning/Force Absorption & Hips/Single-Leg Balance Stand` (NEW page)<br>`Strength & Conditioning/Force Absorption & Hips/Loaded Calf Raise` (clip) |
| Easy jog 4 min, you can talk | `Cardio/Easy Jog` (NEW page) |
| Sprint drills + 5 build-up strides | `Strength & Conditioning/Plyometrics/B Skip` (clip)<br>`Strength & Conditioning/Plyometrics/C Skip` (clip)<br>`Strength & Conditioning/Plyometrics/Carioca` (clip)<br>`Strength & Conditioning/Plyometrics/Build-Up Sprints` (clip) |
| Uphill sprints 6x20 m (easy walking lunges between, 90 s) | `Strength & Conditioning/Plyometrics/Hill Sprint (20 m)` (no clip)<br>`Mobility & Flexibility/Warm-Ups/Walking Lunge with Rotation` (NEW page) |
| Cool-down: easy walk + leg swings (no static stretch) | `Cardio/Easy Jog` (NEW page)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Front to Back)` (NEW page)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Side to Side)` (NEW page) |

### Wed PM · Straight-arm day: planche + lever (70 min, Gymnastics)

| Block (week 1 name) | Pages |
|---|---|
| Wrist prep 5 min | `Calisthenics/Handstand/Wrist Circles` (clip)<br>`Calisthenics/Handstand/Reverse Wrist Circles` (clip)<br>`Calisthenics/Handstand/Wrist Circles Back of Hands` (clip)<br>`Calisthenics/Handstand/Wrist Circles Palms Down` (clip)<br>`Calisthenics/Handstand/Wrist Rocking on Fists` (clip)<br>`Calisthenics/Handstand/Finger Pulses` (clip)<br>`Calisthenics/Handstand/Finger Press` (clip)<br>`Calisthenics/Handstand/Fist Pumps` (clip) |
| Handstand balance 4 attempts, up to 30 s (wrist rolls between, 60 s) | `Calisthenics/Handstand/Chest-to-Wall Handstand Toe Pulls` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip) |
| Planche lean 8 s + tuck hold 8 s, 5 rounds (leg swings between, 120 s) | `Calisthenics/Planche/Parallette Planche Lean` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Front to Back)` (NEW page)<br>`Calisthenics/Planche/Tuck Planche` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Side to Side)` (NEW page)<br>from week 5: `Calisthenics/Planche/Advanced Tuck Planche` (clip) |
| Tuck front lever holds 5x8 s (T-spine twists between, 120 s) | `Calisthenics/Static Holds/Tuck Front Lever Hold` (NEW page)<br>`Mobility & Flexibility/Stretching/Standing Torso Twist Arm Swings` (clip)<br>from week 5: `Calisthenics/Static Holds/Advanced Tuck Front Lever Hold` (NEW page) |
| Protraction and scapular work 3 rounds x10 | `Calisthenics/Planche/Forearm Plank Protraction` (clip)<br>`Upper Body/Pull/Scapular Pulls` (clip) |
| L-sit / compression holds 3x10 s | `Calisthenics/L-Sit/L-Sit Hold` (clip) |
| Evening stretch 11 min: pike + pancake, 2 rounds | `Mobility & Flexibility/Stretching/Seated Single Leg Forward Fold` (clip)<br>`Mobility & Flexibility/Stretching/Seated Straddle Reach to Toes` (clip)<br>`Mobility & Flexibility/Stretching/Half Split` (clip)<br>`Mobility & Flexibility/Stretching/Standing Hamstring Stretch` (clip) |

### Thu AM · Gymnastic strength + active mobility (35 min, Mobility)

| Block (week 1 name) | Pages |
|---|---|
| Active mobility 10 min: joint circles, squat rocks, Cat-Cow (no deep stretch) | `Upper Body/Arm Circles` (clip)<br>`Mobility & Flexibility/Warm-Ups/Standing Hip Circles` (NEW page)<br>`Calisthenics/Handstand/Wrist Circles` (clip)<br>`Mobility & Flexibility/Wrists & Ankles/Forward Rocks` (clip)<br>`Mobility & Flexibility/Wrists & Ankles/Backward Rocks` (clip)<br>`Mobility & Flexibility/Spine/Cat-Cow` (clip)<br>`Mobility & Flexibility/Hips/90-90 Hip Rotation` (clip)<br>`Mobility & Flexibility/Spine/Thread the Needle` (clip)<br>`Mobility & Flexibility/Warm-Ups/Inchworm Walk Out` (clip) |
| Handstand balance 6 attempts, up to 30 s (shake out between, 75 s) | `Calisthenics/Handstand/Chest-to-Wall Handstand Toe Pulls` (clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page) |
| Hollow + arch holds 3x20 s (shake out / leg swings between, 75 s) | `Calisthenics/Hollow Body/Hollow Body Hold` (clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page)<br>`Calisthenics/Static Holds/Superman Rocking` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Front to Back)` (NEW page) |
| L-sit / V-sit holds 3x10 s, alternate (arm circles / shake out between, 75 s) | `Calisthenics/L-Sit/L-Sit Hold` (clip)<br>`Upper Body/Arm Circles` (clip)<br>`Calisthenics/L-Sit/Parallette V-Sit` (clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page) |

### Thu PM · Easy bike + long stretch (55 min, Conditioning)

| Block (week 1 name) | Pages |
|---|---|
| Easy bike ride 35 min: you can talk the whole time | `Cardio/Easy Bike Ride` (NEW page) |
| PNF pancake 3 rounds: push 5-10 s at half effort, relax, go deeper | `Mobility & Flexibility/Stretching/PNF Pancake` (clip) |
| Pike 7 min: 2 rounds | `Mobility & Flexibility/Stretching/Seated Single Leg Forward Fold` (clip)<br>`Mobility & Flexibility/Stretching/Standing Hamstring Stretch` (clip) |
| Front split prep 7 min: hip flexor + half split, 2 rounds | `Mobility & Flexibility/Stretching/Half Kneeling Hip Flexor Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Half Split` (clip) |

### Fri AM · Plyos B + handstand + press (60 min, Conditioning)

| Block (week 1 name) | Pages |
|---|---|
| Flow A+B short 12 min: hips, shoulders, feet | same pages as Monday AM |
| Plyos B 3 rounds: lateral bounds 6, skaters 6 (leg swings / hip circles between, 75 s) | `Strength & Conditioning/Plyometrics/Lateral Bounds` (clip)<br>`Mobility & Flexibility/Warm-Ups/Leg Swings (Side to Side)` (NEW page)<br>`Cardio/Skaters` (clip)<br>`Mobility & Flexibility/Warm-Ups/Standing Hip Circles` (NEW page) |
| Handstand balance 7 attempts, up to 30 s (wrist rolls between, 60 s) | `Calisthenics/Handstand/Handstand Kick-Up` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip) |
| Press strength 3 rounds: wall pike press 5, negatives 2 (wrist rolls between, 90 s) | `Calisthenics/Handstand/Press to Handstand/Wall Pike Press Drill` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip)<br>`Calisthenics/Handstand/Press to Handstand/Straddle Press Negative (Lowering from Handstand)` (no clip) |
| Tuck front lever holds 4x8 s (T-spine twists between, 120 s) | `Calisthenics/Static Holds/Tuck Front Lever Hold` (NEW page)<br>`Mobility & Flexibility/Stretching/Standing Torso Twist Arm Swings` (clip)<br>from week 5: `Calisthenics/Static Holds/Advanced Tuck Front Lever Hold` (NEW page) |
| Pike compression lifts 3x6 | `Calisthenics/Handstand/Press to Handstand/Pike Compression Lift` (clip) |

### Fri PM · Wrestling 2 (drilling + rounds) (85 min, Wrestling)

| Block (week 1 name) | Pages |
|---|---|
| Wrestler circuit 2 rounds: dive bombers 10, walkouts 10, kick-throughs 30 s | `Mobility & Flexibility/Warm-Ups/Dive Bomber Push-Up` (clip)<br>`Mobility & Flexibility/Warm-Ups/Hand Walkout` (clip)<br>`Mobility & Flexibility/Warm-Ups/Kick Through` (clip) |
| Stance and motion 6 min | `Wrestling/Stance and Motion/Stance and Motion Lateral Steps` (clip)<br>`Wrestling/Mat Movement & Drills/Wrestling Stance Motion Shadow Drill` (clip) |
| 3 takedowns drilled 6 rounds x8: double leg, single leg (sweep single), body lock outside trip | `Wrestling/Double Leg Takedown` (clip)<br>`Wrestling/Single Leg Takedown/Sweep Single Entry (Hit and Follow)` (clip)<br>`Wrestling/Body Lock Takedown/Cover and Crash Body Lock Outside Trip` (clip)<br>from week 5: `Wrestling/Single Leg Takedown/Double Leg to Single Leg Chain` (clip)<br>`Wrestling/Underhook/Knee Pick off the Underhook` (clip) |
| Shadow rounds 4x2 min (hip circles / arm swings / shake out between) | `Wrestling/Wrestling Conditioning/Stance and Motion Shadow Wrestling Drill` (clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page)<br>from week 5: `Wrestling/Hand Fighting/Hand Fighting Quadrants` (clip) |
| Sprawl + wall get-up 4 rounds (sprawls 6, get-ups 3) | `Wrestling/Sprawl/Sprawl Straight Down` (clip)<br>`Wrestling/Wall Get Up` (clip) |
| Evening stretch 10 min: back relief after wrestling, hips, hamstrings | `Mobility & Flexibility/Spine/Shoulder Roll to Supine` (clip)<br>`Mobility & Flexibility/Spine/Scorpion Stretch` (clip)<br>`Mobility & Flexibility/Spine/Cobra Side-to-Side Shift` (clip)<br>`Mobility & Flexibility/Stretching/Half Kneeling Hip Flexor Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Seated Glute Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Standing Hamstring Stretch` (clip) |

### Sat AM · Muscle-up 2 + handstand (40 min, Gymnastics; weeks 2, 3, 5, 6, 7)

| Block (week 1 name) | Pages |
|---|---|
| Flow B + wrist prep 6 min | `Mobility & Flexibility/Spine/Cat-Cow` (clip)<br>`Mobility & Flexibility/Spine/Thread the Needle` (clip)<br>`Mobility & Flexibility/Shoulders/Resistance Band Shoulder Dislocates` (clip)<br>`Mobility & Flexibility/Stretching/Cross-Body Arm Swings` (clip)<br>`Mobility & Flexibility/Warm-Ups/Inchworm Walk Out` (clip)<br>`Mobility & Flexibility/Stretching/Deep Squat Thoracic Rotation` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip)<br>`Calisthenics/Handstand/Reverse Wrist Circles` (clip) |
| Explosive pull-ups 4x3 (band dislocates between, 120 s) | `Calisthenics/Muscle-Up/Explosive Pull-Up` (clip)<br>`Mobility & Flexibility/Shoulders/Resistance Band Shoulder Dislocates` (clip) |
| Muscle-up transition drill: banded muscle-ups 3x3 | `Calisthenics/Muscle-Up/Banded Muscle-Up` (clip)<br>from week 5: `Calisthenics/Muscle-Up` (no clip) |
| Strict dips 2x8, bodyweight | `Strength & Conditioning/Lifting & Gym/Weighted Dip` (no clip) |
| Handstand balance 4 attempts, up to 30 s (wrist rolls between, 60 s) | `Calisthenics/Handstand/Handstand Kick-Up` (clip)<br>`Calisthenics/Handstand/Wrist Circles` (clip) |
| Press practice 3 rounds: straddle jumps 3, negatives 2 | `Calisthenics/Handstand/Press to Handstand/Straddle Jumps` (clip)<br>`Calisthenics/Handstand/Press to Handstand/Straddle Press Negative (Lowering from Handstand)` (no clip) |
| Toes-to-bar steps 3x5: feet to bar, 3 s hold, lower to L | `Calisthenics/Core & Compression/Toes-to-Bar Top-Down Hold` (no clip) |

### Sat PM · Boxing 2 (home) (70 min, Boxing)

| Block (week 1 name) | Pages |
|---|---|
| Ball warm-up 4 min: 5 moves x8, small range first | same 5 ball pages as Monday PM (clip) |
| Priming 3 min: isometric cross and hook 2x5 s, fast shadow punches, banded punches | same 4 pages as Monday PM (clip) |
| Technique 10.5 min, 2 themes: blocked, slow to fast, mirror | `Boxing/Jab` (clip)<br>`Boxing/Parry` (clip)<br>from week 5: `Boxing/Head Movement/Slip` (clip)<br>`Boxing/Cutting Off the Ring` (clip) |
| Mirror shadow rounds 4x3 min (shake out between, 60 s) | `Boxing/Shadow & Bag Drills/Shadowboxing Round` (no clip)<br>`Mobility & Flexibility/Warm-Ups/Shake Out` (NEW page) |
| Footwork + defence rounds 3x2 min: move, slip, step off | `Boxing/Eight-Direction Footwork With Side Dodge` (clip) |
| Finisher: punch bursts 2 rounds of 14 x (3 s all-out, 10 s easy) | `Boxing/Boxing Conditioning/Punch Bursts` (NEW page) |
| Long stretch 14 min: pancake, splits, shoulders | `Mobility & Flexibility/Stretching/PNF Pancake` (clip)<br>`Mobility & Flexibility/Stretching/Loaded Pancake (Light Weight)` (no clip)<br>`Mobility & Flexibility/Stretching/Half Split` (clip)<br>`Mobility & Flexibility/Stretching/Half Kneeling Hip Flexor Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Puppy Pose` (clip)<br>`Mobility & Flexibility/Stretching/Wall Chest Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Wrist Flexor Stretch` (clip)<br>`Mobility & Flexibility/Stretching/Wrist Extensor Stretch` (clip) |

### Sat AM weeks 1, 4, 8 · Checkpoint tests (40 min, Skill Work)

| Block | Pages |
|---|---|
| Flow A+B short 12 min: hips, shoulders, feet | same pages as Monday AM |
| Max handstand hold, 2 tries (time it) | `Calisthenics/Handstand/Handstand Kick-Up` (clip) |
| Press attempts 3x1 (note the best) | `Calisthenics/Handstand/Press to Handstand/Handstand Press` (clip) |
| Front lever hold, best progression, 2 tries | `Upper Body/Pull/Scapular Pulls` (clip)<br>`Calisthenics/Static Holds/Tuck Front Lever Hold` (NEW page)<br>week 8: `Calisthenics/Static Holds/Advanced Tuck Front Lever Hold` (NEW page) |
| Max strict pull-ups, 1 set (count clean reps) | `Gymnastics/Strength Skills/Locked-Elbow Pull-Up` (clip) |
| Broad jump x3, best distance | `Strength & Conditioning/Plyometrics/Standing Broad Jump` (NEW page) |
| 20 m uphill sprint x2, timed on the phone | `Strength & Conditioning/Plyometrics/Build-Up Sprints` (clip)<br>`Strength & Conditioning/Plyometrics/Hill Sprint (20 m)` (no clip) |

## NEW_PAGES (12, plain, no video yet)

Bodies follow the library style (one sentence, Level · Equipment · Targets, 2-4 cues, Notes with "No video yet" and the source); no dose beyond the plan. Every parent folder already exists (checked).

| Path | Used in | Why |
|---|---|---|
| `Mobility & Flexibility/Warm-Ups/Leg Swings (Front to Back)` | Mon AM, Wed AM, Wed PM, Thu AM | SPEC list; the library has no standing leg swings |
| `Mobility & Flexibility/Warm-Ups/Leg Swings (Side to Side)` | Mon AM, Wed AM, Wed PM, Fri AM | SPEC list |
| `Mobility & Flexibility/Warm-Ups/Standing Hip Circles` | Thu AM, Fri AM | SPEC list |
| `Mobility & Flexibility/Warm-Ups/Shake Out` | Mon PM, Thu AM, Fri PM, Sat PM | SPEC list |
| `Mobility & Flexibility/Warm-Ups/Walking Lunge with Rotation` | Wed AM (between sprints) | SPEC list |
| `Strength & Conditioning/Force Absorption & Hips/Single-Leg Balance Stand` | Mon AM, Wed AM, Fri AM, Sat AM (feet and balance) | SPEC list |
| `Cardio/Easy Bike Ride` | Thu PM | SPEC list |
| `Cardio/Easy Jog` | Wed AM (jog, and the easy walk of the cool-down) | no jog or walk page in the library |
| `Boxing/Boxing Conditioning/Punch Bursts` | Mon PM, Sat PM finisher | SPEC: "Punch bursts page, find or create"; none found |
| `Calisthenics/Static Holds/Tuck Front Lever Hold` | Wed PM, Fri AM, tests | the library has no front lever page at all |
| `Calisthenics/Static Holds/Advanced Tuck Front Lever Hold` | Wed PM, Fri AM from week 5, week-8 test | week-5 harder variant; no page |
| `Strength & Conditioning/Plyometrics/Standing Broad Jump` | Mon AM weeks 1-4, tests | only "Broad Jumps to Box" exists and there is no box |

## PLANNED_PAGES (5)

`Mobility & Flexibility/Spine/Ball Spine Extension and Flexion`, `.../Ball Shoulder Extension and Flexion`, `.../Ball Shoulder Adduction and Abduction`, `.../Ball Spine Rotation`, `.../Ball Lateral Flexion`. Sections reference them as `NEW:<exact title>`; all five already exist in the library with a clip, so they resolve to the library pages. `Isometric Punch Priming` was removed (decision 7).

## Per-week progression

| Week | Phase | Rule (tables in the code) |
|---|---|---|
| 1 | foundation | week 1 as written (with the fixes in decision 1) |
| 2 | foundation | STEP 1: reps +1 (plyos about +10% contacts, dips, leg raises, shots, sprawls, split squat, takedown reps, press reps), holds +2 s (planche, lever, L-sit), bridge +5 s, sprints 6 → 7, lateral bounds +1 |
| 3 | foundation | STEP 2: the same steps again; one more set on the main skill block (explosive pull-ups Mon, handstand Tue), boxing mirror rounds 5 → 6 (Sat 4 → 5), sprints 8, hollow / L-sit holds 15 → 20 s, skaters +1 |
| 4 | deload | week-3 reps and holds; sets, rounds, sprints and bike minutes × 0.65; technique minutes × 0.8; warm-ups and stretches unchanged; "(light)" |
| 5 | specific | harder variants (decision 8) at the week-3 volume; holds restart at 8 s |
| 6 | specific, peak | one more unit on the peak knob: planche and Wednesday lever +1 set, plyo reps +1 (87 contacts max), Friday rounds 4 → 5, dips / leg raises / shots / sprawls +1 rep |
| 7 | taper start | week-6 intensity; sets, rounds, sprints, bike × 0.65; technique × 0.8; "(light)" |
| 8 | taper + tests | week-6 intensity; × 0.55 (technique × 0.75); Saturday AM tests; Saturday PM easy (no finisher) |

One raised variable per block per week: each block raises only reps, or hold time, or sets, or the sprint count; the week-5 change is the variant only.

### Numbers per week (knobs that change)

| Session | Block | Knobs | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|---|---|---|---|---|---|---|---|---|---|---|
| Mon AM | plyo_a | sets/reps/third | 3/8/4 | 3/9/4 | 3/10/4 | 2/10/4 | 3/10/6 | 3/11/7 | 2/11/7 | 2/11/7 |
| Mon AM | epu | sets | 5 | 5 | 6 | 4 | 6 | 6 | 4 | 3 |
| Mon AM | mu_work | sets/att_sets | 6/6 | 6/6 | 6/6 | 4/4 | 6/6 | 6/6 | 4/4 | 3/3 |
| Mon AM | dips | sets/reps | 3/8 | 3/9 | 3/10 | 2/10 | 3/10 | 3/11 | 2/11 | 2/11 |
| Mon AM | hlr | sets/reps | 3/6 | 3/7 | 3/8 | 2/8 | 3/8 | 3/9 | 2/9 | 2/9 |
| Mon PM | technique | f | 1 | 1 | 1 | 0.8 | 1 | 1 | 0.8 | 0.75 |
| Mon PM | shadow_rounds | rounds | 5 | 5 | 6 | 4 | 6 | 6 | 4 | 3 |
| Mon PM | called_combos | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Mon PM | finisher | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Tue AM | hs_balance | sets | 7 | 7 | 8 | 5 | 8 | 8 | 5 | 4 |
| Tue AM | press_strength | sets/reps | 3/5 | 3/6 | 3/7 | 2/7 | 3/7 | 3/7 | 2/7 | 2/7 |
| Tue AM | shrugs_comp | sets/reps | 3/8 | 3/9 | 3/10 | 2/10 | 3/10 | 3/10 | 2/10 | 2/10 |
| Tue AM | hollow_lsit | sets/hold | 3/15 | 3/15 | 3/20 | 2/20 | 3/20 | 3/20 | 2/20 | 2/20 |
| Tue PM | stance_motion | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Tue PM | shots | sets/reps | 3/8 | 3/9 | 3/10 | 2/10 | 3/10 | 3/11 | 2/11 | 2/11 |
| Tue PM | takedown_shadow | sets/reps | 5/8 | 5/9 | 5/10 | 3/10 | 5/10 | 5/10 | 3/10 | 3/10 |
| Tue PM | sprawls | sets/reps | 4/6 | 4/7 | 4/8 | 3/8 | 4/8 | 4/9 | 3/9 | 2/9 |
| Tue PM | split_squat | sets/reps | 3/8 | 3/9 | 3/10 | 2/10 | 3/10 | 3/10 | 2/10 | 2/10 |
| Tue PM | bridge_neck | sets/hold | 3/20 | 3/25 | 3/30 | 2/30 | 3/30 | 3/30 | 2/30 | 2/30 |
| Wed AM | sprint_warmup | drill_reps/strides | 2/5 | 2/5 | 2/5 | 1/3 | 2/5 | 2/5 | 1/3 | 1/3 |
| Wed AM | sprints | count | 6 | 7 | 8 | 5 | 8 | 8 | 5 | 4 |
| Wed PM | hs_balance | sets | 4 | 4 | 4 | 3 | 4 | 4 | 3 | 2 |
| Wed PM | planche | sets/hold | 5/8 | 5/10 | 5/12 | 3/12 | 5/8 | 6/8 | 4/8 | 3/8 |
| Wed PM | front_lever | sets/hold | 5/8 | 5/10 | 5/12 | 3/12 | 5/8 | 6/8 | 4/8 | 3/8 |
| Wed PM | protraction | sets/reps | 3/10 | 3/11 | 3/12 | 2/12 | 3/12 | 3/12 | 2/12 | 2/12 |
| Wed PM | lsit_holds | sets/hold | 3/10 | 3/12 | 3/14 | 2/14 | 3/14 | 3/14 | 2/14 | 2/14 |
| Thu AM | hs_balance | sets | 6 | 6 | 6 | 4 | 6 | 6 | 4 | 3 |
| Thu AM | hollow_arch | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Thu AM | lv_sit | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Thu PM | bike | min | 35 | 35 | 35 | 23 | 35 | 35 | 23 | 19 |
| Fri AM | plyo_b | sets/lat/skate | 3/6/6 | 3/7/6 | 3/7/7 | 2/7/7 | 3/7/7 | 3/8/7 | 2/8/7 | 2/8/7 |
| Fri AM | hs_balance | sets | 7 | 7 | 7 | 5 | 7 | 7 | 5 | 4 |
| Fri AM | press_strength | sets/reps | 3/5 | 3/6 | 3/7 | 2/7 | 3/7 | 3/7 | 2/7 | 2/7 |
| Fri AM | front_lever | sets/hold | 4/8 | 4/10 | 4/12 | 3/12 | 4/8 | 4/8 | 3/8 | 2/8 |
| Fri AM | pike_comp | sets/reps | 3/6 | 3/7 | 3/8 | 2/8 | 3/8 | 3/8 | 2/8 | 2/8 |
| Fri PM | wrestler_circuit | sets | 2 | 2 | 2 | 1 | 2 | 2 | 1 | 1 |
| Fri PM | stance_motion | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Fri PM | takedown_drill | sets/reps | 6/8 | 6/9 | 6/10 | 4/10 | 6/10 | 6/10 | 4/10 | 3/10 |
| Fri PM | wrestle_rounds | sets | 4 | 4 | 4 | 3 | 4 | 5 | 3 | 3 |
| Fri PM | sprawl_wall | sets/reps | 4/6 | 4/7 | 4/8 | 3/8 | 4/8 | 4/8 | 3/8 | 2/8 |
| Sat AM | epu | sets | tests | 4 | 4 | tests | 4 | 4 | 3 | tests |
| Sat AM | mu_work | sets/att_sets | tests | 3/3 | 3/3 | tests | 3/3 | 3/3 | 2/2 | tests |
| Sat AM | dips | sets/reps | tests | 2/9 | 2/10 | tests | 2/10 | 2/10 | 1/10 | tests |
| Sat AM | hs_balance | sets | tests | 4 | 4 | tests | 4 | 4 | 3 | tests |
| Sat AM | press_practice | sets/reps | tests | 3/3 | 3/4 | tests | 3/4 | 3/4 | 2/4 | tests |
| Sat AM | t2b | sets/reps | tests | 3/5 | 3/6 | tests | 3/6 | 3/6 | 2/6 | tests |
| Sat PM | technique | f | 1 | 1 | 1 | 0.8 | 1 | 1 | 0.8 | 0.75 |
| Sat PM | shadow_rounds | rounds | 4 | 4 | 5 | 3 | 5 | 5 | 3 | 3 |
| Sat PM | footwork_defence | sets | 3 | 3 | 3 | 2 | 3 | 3 | 2 | 2 |
| Sat PM | finisher | sets | 2 | 2 | 2 | 1 | 2 | 2 | 1 | none |

`mu_work` uses `sets` (banded drill) in weeks 1-4 and `att_sets` (muscle-up attempts x1) from week 5. Blocks not listed (flows, stretches, ball warm-up, priming, jog, cool-down) are the same every week.

### Estimated / planned minutes (app arithmetic)

| Session | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|---|---|---|---|---|---|---|---|---|
| Mon AM Plyos A + muscle-up 1 | 60/60 | 60/60 | 63/60 | 45/44 | 64/60 | 65/60 | 46/44 | 41/40 |
| Mon PM Boxing 1 (home) | 72/70 | 72/70 | 76/70 | 58/53 | 76/70 | 76/70 | 58/53 | 53/49 |
| Tue AM Handstand + press | 44/45 | 45/45 | 47/45 | 33/33 | 47/45 | 47/45 | 33/33 | 32/29 |
| Tue PM Wrestling 1 (solo technique) | 66/70 | 68/70 | 70/70 | 51/51 | 70/70 | 71/70 | 51/51 | 49/46 |
| Wed AM Uphill sprints | 37/40 | 39/40 | 40/40 | 33/33 | 40/40 | 40/40 | 33/33 | 31/31 |
| Wed PM Straight-arm day: planche + lever | 67/70 | 68/70 | 69/70 | 49/53 | 68/70 | 75/70 | 55/52 | 47/47 |
| Thu AM Gymnastic strength + active mobility | 33/35 | 33/35 | 33/35 | 25/27 | 33/35 | 33/35 | 25/27 | 23/24 |
| Thu PM Easy bike + long stretch | 55/55 | 55/55 | 55/55 | 43/43 | 55/55 | 55/55 | 43/43 | 39/39 |
| Fri AM Plyos B + handstand + press | 58/60 | 58/60 | 59/60 | 44/45 | 58/60 | 58/60 | 44/45 | 40/40 |
| Fri PM Wrestling 2 (drilling + rounds) | 78/85 | 80/85 | 82/85 | 59/61 | 82/85 | 86/85 | 59/61 | 52/54 |
| Sat AM (W1, W4, W8 = checkpoint tests) | 38/40 | 40/40 | 41/40 | 38/40 | 41/40 | 41/40 | 28/29 | 38/40 |
| Sat PM Boxing 2 (home) | 66/70 | 66/70 | 70/70 | 52/56 | 70/70 | 70/70 | 52/56 | 48/48 |

## Warnings and risks

1. **Mon PM boxing runs long**: 76 min in weeks 3, 5, 6 (+8.5% on the 70-min slot) and +9.8% in weeks 4 and 7, the closest to the 12% limit. Cause: the SPEC rests (60 s between 3-min rounds, finisher rests) plus the 6th round from week 3. If he wants it nearer 70, cut the technique block, not the rounds.
2. **SPEC block minutes trimmed** (decision 1): Mon PM technique 15 → 11.5, Tue AM handstand 12 → 10.5 and press 14 → 11, Sat AM flow 8 → 6, transition drills 10 → about 4.5, handstand 8 → 6, press practice 8 → 7.5. Added: Wed AM sprint drills and strides. These are the places where the session no longer matches the agreed block minutes.
3. **No video yet on key pages**: the front lever (both steps), broad jump, punch bursts and all between-set moves are new plain pages; 7 library pages have no clip, among them Shadowboxing Round (the main boxing block), Weighted Dip (used for bodyweight strict dips), Hill Sprint (20 m) and the Muscle-Up skill page (week 5-8 attempts).
4. **Harder variants may be too hard**: advanced tuck planche from week 5 for an athlete the research calls "a true zero" on planche; the band is offered in the names, and holds restart at 8 s. Muscle-up attempts from week 5 depend on the banded drill going well; "band if no rep" is in the name.
5. **Light-week targets are derived**, not given by the SPEC (decision 2). The check proves that whole-set rounding keeps each light session within 12% of the volume rule, not that the user agreed to those exact minutes.
6. **Bundles with timed moves inside untimed blocks** (plyos, sprints, pull-ups, takedowns): the 30 s move has no countdown; the user taps Done. The builder must pass `untimed` and the bundle exercises' `repCount`; the old `section_ops` passes `repCount` but not `untimed`.
7. **Estimates of untimed sets** are my estimates (3-7 s a rep plus set-up); slow takedown shadow reps or a long walk back after the sprints will add minutes.
8. **Partner work**: takedowns, positional rounds and the wall get-up pages show a partner; the names say "partner or shadow" and the check blocks partner rounds before week 5.

## Could not place exactly (nearest page used)

| Idea | Page used | Note |
|---|---|---|
| Strict bodyweight dips | `Strength & Conditioning/Lifting & Gym/Weighted Dip` (no clip) | no plain dip page; name says "bodyweight" |
| Calf raises 2 x 15, both feet | `Strength & Conditioning/Force Absorption & Hips/Loaded Calf Raise` | done without weight, both feet (name says so) |
| Arch hold | `Calisthenics/Static Holds/Superman Rocking` | held, not rocked (name says so) |
| Max strict pull-ups (test) | `Gymnastics/Strength Skills/Locked-Elbow Pull-Up` | strict pull-up from a dead hang; no plain pull-up page |
| Squat jumps | `Kickboxing/Kick Mobility & Conditioning/Squat Jumps` | best squat jump page; not in a preferred folder |
| Hanging leg raises | `Gymnastics/Strength Skills/Hanging Leg Raise` | shown on wall bars; same move on the pull-up bar |
| Toes-to-bar steps | `Calisthenics/Core & Compression/Toes-to-Bar Top-Down Hold` (no clip) | the camp's T2B progression page |
| Mirror shadow rounds | `Boxing/Shadow & Bag Drills/Shadowboxing Round` (no clip) | the only shadow round page; its body still describes the old camp's rounds |
| Called combos from a timer app | `Boxing/Beginner Combination Ladder` | shadow combinations by number |
| Footwork + defence rounds | `Boxing/Eight-Direction Footwork With Side Dodge` | footwork with head dodges |
| Positional rounds (week 5+) | `Wrestling/Hand Fighting/Hand Fighting Quadrants` | partner hand fight; name says "no partner: shadow" |
| T-spine rotations between lever sets | `Mobility & Flexibility/Stretching/Standing Torso Twist Arm Swings` | |
| Joint circles, arm circles | `Upper Body/Arm Circles` | generic folder |
| Scapular work | `Upper Body/Pull/Scapular Pulls`, `Calisthenics/Planche/Forearm Plank Protraction` | |
| Easy walk (cool-down) | `Cardio/Easy Jog` (NEW) | the page says "walk instead when the plan says walk" |
| Band-assisted planche | `Calisthenics/Planche/Advanced Tuck Planche` (skill) | band set-up given in the name, no separate page |
