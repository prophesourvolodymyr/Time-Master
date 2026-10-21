# F29-G-d — Score Counters

## Purpose and Product Boundary

This component presents accepted Physique judgement numbers, the separate own-account rating receipt, and one synchronized result reveal on native iPhone and native macOS. It belongs inside the existing Physique match-result and saved-result surfaces; it is not another result screen, judge, rating engine, badge catalog, or camera flow.

This is product direction for future implementation. It does not claim that the UI, service contracts, assets, or motion have been implemented, measured, or human-verified. The approved visual direction is native on both platforms, animated but concise, with the real timer above all public battle badges and two large vertically stacked participants. The scoring weights, draw boundary, rating bounds, and badge eligibility remain the versioned product proposals owned by F29-B, F29-C, and F29-F, not newly approved competition policy here.

The result must remain completely understandable with animation disabled. Outcome, final numbers, units, accessible values, recovery, and safe navigation are available immediately when the corresponding authoritative state is available. No presentation event awards points, unlocks an achievement, or decides a winner.

## Chosen Composition and Tradeoffs

Use a sports score sheet with a single-stop numeral roll and fixed-endpoint score rails. Final digits make a short settling movement; they never count from zero through invented scores. The accepted endpoint of each score rail is visible immediately, with a restrained fill sweep inside that already established extent. A separate textual Physique Elo receipt prevents category points from appearing to turn into rating.

A zero-to-score odometer would briefly imply scores that were never accepted, and independently timed counters could suggest the wrong winner or draw. It is therefore rejected. A long score-then-rating-then-badge sequence would delay useful information and make reopening feel like another award; all decorative phases instead fit within one 900-millisecond interval. A horizontal desktop matchup would save vertical space but contradict the approved player hierarchy; both participants remain vertical at every width.

Numbers use the existing Inter Black hierarchy with stable digit widths; names, units, reasons, and labels use the existing readable Inter styles. Use the existing near-black background, dark surfaces, white or ivory metric ink, and toolbar orange. Orange identifies the person's own lane and supported actions, not proof that the larger-looking body won. Losses do not acquire punitive red washes, shaking portraits, or insulting copy. Do not copy the reference image's purple/brown pills, faces, footage, or side-by-side layout.

### Shared result order

1. The host's real clock remains the top visual anchor. Its state becomes clearly ended when the service ends that stage; it is not replaced by a score or replayed five-second result countdown. The concise outcome heading occupies the same top status region, below the clock and above the badge rails.
2. The complete You identity/badge rail and then the complete Opponent identity/badge rail appear above both player panels. Every authorized public battle badge, current placed tier, and truthful current streak is represented under its owner. Rails wrap without a three-item limit, hidden additional-count pill, clipped row, or ticker. Their full content can scroll; it need not become an indefinitely tall pinned wall.
3. Two equally prominent large player panels remain stacked: You first, Opponent second. Their approved avatar, neutral athlete art, or permitted evidence content follows the host's privacy state. Each panel has a solid score footer outside its image bounds: participant label, Total, one-decimal value, and points out of 100. No score, badge, label, or bar overlays a face, limb, or evidence framing.
4. Below the second panel, a small fixed readout shows the absolute Gap in points to one decimal place. It never becomes an animated lead indicator. An adjacent concise explanation distinguishes a draw band from a winning margin when relevant.
5. A separate own-account Physique Elo receipt shows Before, signed Change, and After. Its surface and spacing separate it from the score gap; there is no connecting morph, shared fill, or conversion arrow between score points and Elo. It contains text, not another public crest below the players.
6. The compact Result host offers the canonical Breakdown action rather than inserting all category rows into its first surface. F29-A-m Score breakdown composes the four category groups in rubric order: Visible muscularity, Definition, Symmetry and balance, Pose presentation. Each names its weight and presents You above Opponent with whole-point values and equal-scale rails. Those numeric rows are not a second player-image matchup. Full weights, neutral explanations, version and draw-rule meaning remain readable there without opening an image; this component does not create another details screen.
7. The host keeps Close as the safe primary result action. Details, View poses where authorized, Find another opponent where eligible, and Safety remain distinct named actions. This component does not start matchmaking or open images on appearance.

Public tier crests and achievement badges stay in the top rails. The lower rating receipt can name the actual resulting placement state in text, but must not create a second badge wall. All result actions work during the reveal.

## Distinct Numeric Meanings

The following are separate value kinds, not one interchangeable number with a different caption. Presentation consumes the accepted meaning and version supplied by the shared domain. It does not invent an alternative scoring or rating convention.

| Value kind | Visible and accessible form | Valid meaning and boundary |
| --- | --- | --- |
| Accepted category score | Whole points out of 100, with participant and full category name | Zero through 100 under the current proposed rubric. Zero is a valid observation only when accepted evidence supports it. Missing, unobservable, rejected, or pending evidence is not zero. |
| Accepted weighted total | Exactly one decimal place, points out of 100 | Zero through 100 with tenths precision for the proposed whole-category, fixed-weight rubric. It is not rounded to a whole number in this result surface. |
| Absolute total gap | Exactly one decimal place, explicitly labeled Gap and points | Nonnegative difference between the accepted totals under the same result version. It has no plus/minus sign and is not an Elo change, confidence, or win probability. |
| Settled Physique Elo value | Whole rating points, explicitly scoped Physique Elo | The person's actual settled before or after rating; proposed bounds are zero through 5000. It is not a body score or local editable profile level. |
| Effective Physique Elo change | Signed whole rating points; positive plus, typographic minus for negative, plain zero for unchanged | The actual effective settlement, including bounds. Zero is labeled Unchanged, never negative zero. No balancing transfer is inferred for the opponent. |
| Review adjustment | Separately labeled signed whole Physique Elo points and its own settlement context | A correction to the current confirmed account, not the original match's award replayed or a new body score. |

Under the proposed rubric, weights are 40 percent visible muscularity, 30 percent definition, 20 percent symmetry and balance, and 10 percent pose presentation. A percentage appears only beside the explicit word Weight, never as a score suffix. The full scale is points out of 100, not an ideal-body percentage, percentile, health measure, body-fat value, or accuracy claim.

The accepted whole categories and version determine the accepted one-decimal totals without separately rounding contributions into another total. The service owns the outcome: a proposed gap of 2.9 is a draw, while exactly 3.0 is a win/loss. The page does not determine that outcome from formatted strings, rail lengths, transitional geometry, model prose, or a separately rounded summary. The static gap is present throughout the reveal so the boundary never appears to move.

Locale-appropriate digits, decimal separators, and grouping retain the same precision and sign meaning. Signs and units have stable space and do not roll with the magnitude. A value reaching 100.0 or an Elo value reaching 5000 must fit without truncation or shrinking accessibility text. Right-to-left layout keeps each participant, sign, number, and unit together; You remains before Opponent in reading and vertical order.

No client clamping repairs an out-of-range or internally inconsistent purported result. An untrusted, unsupported, partial, or mixed-revision numeric group is unavailable until the authoritative contract supplies a coherent group. A score of zero has an empty score rail and a visible zero; it must not be embellished with a minimum orange sliver. A score of 100 fills exactly its scale, without overshoot. Negative category scores, totals, or absolute gaps are not valid results. A negative Elo change is valid and receives the same legibility and restrained timing as a positive change.

### Rating receipt and placement

Only the signed-in person's permitted before/change/after receipt is exposed. The opponent's permitted match-time rating and placement state remain identity context; no private opponent transaction, current-account adjustment, or inferred mirrored delta is added.

For the first rated result, the compact receipt says First earned rating rather than implying that the pairing seed was previously earned. The exact service input remains available in rating details, explicitly named Pairing seed — not earned. Subsequent results use the actual before rating. The current proposed first-five placement progress is shown only from confirmed record state. No tier appears while unplaced or provisional, and an eligible fifth rated result may establish placement only when the service confirms it.

A draw can produce a positive, negative, or zero own Elo change. A win at a rating bound can produce zero change. A large score margin does not create extra Elo. The actual signed change and before/after values are shown without substituting an unconstrained calculation or an assumed equal-and-opposite opponent change.

Historical receipts retain their match-time settlement. Current rating belongs to the current account summary. Corrections distinguish the original receipt, the effective reviewed outcome, and any later adjustment to current rating; they do not replace historical before/after values with today's account balance.

## Native iPhone Composition

Support the existing iPhone deployment range, including iOS 16; this design does not raise the target or depend on iOS 26-only effects. The result stays inside the current native navigation and safe-area conventions.

The top clock/outcome region and safe Close/Safety access remain reachable while the badge rails, two large participants, receipts, and category details scroll. The central stage is allowed to exceed the viewport. Long badge collections and accessibility text never force the two people into tiny thumbnails merely to fit the whole match onscreen at once.

Use measured available width and existing readable-column and spacing conventions. Both panels share comparable framing and prominence; approved evidence is aspect-fit without cropping, stretching, or selectively enlarging one person. A stopped result does not keep a camera preview alive behind a score footer. Ordinary results use the permitted avatar/silhouette presentation until the person intentionally chooses View poses through the existing host route.

Short phones, landscape, display zoom, long localized category names, and the largest accessibility sizes use more vertical space. Before/change/after can become three labeled lines; paired category rows remain You then Opponent. The gap does not squeeze between two tiny totals. Result details use a native sheet or existing disclosure, not a custom score overlay covering the people or safe actions. Interactive controls follow the existing at-least-44-point iPhone action convention; passive numbers are not disguised buttons.

## Native macOS Composition

This is a native macOS 14-or-later surface, not Catalyst, a web dashboard, or an enlarged phone modal. Preserve the app's normal title bar, traffic lights, window behavior, and existing minimum of 800 by 600. This child must not raise that app-wide minimum.

At the minimum window size and in short laptop windows, a central readable stage scrolls in the same order as iPhone. The clock/outcome region and safe actions remain reachable. All public badge rails remain above both large player panels; the stage grows vertically instead of compressing people, clipping badges, or converting to a horizontal matchup.

In larger, full-screen, and external-display windows, preserve the centered vertical stage. The Result host keeps outcome, totals, static gap and own receipt concise, with the canonical Breakdown action. The Breakdown host presents all four category groups and complete meaning in its own native document; its optional supporting inspector has a readable inline/sheet fallback. No essential value requires hover, and no inspector moves Opponent next to You.

Live resize reflows measured columns and rails without restarting the reveal, changing a number's precision, losing focus, or moving a control under an active pointer press. If resize would make the short numeral movement awkward, settle it immediately; the values are already final. Moving a window between displays does not change scale meaning, restart an award, or alter camera ownership. Use native control density and focus treatment rather than applying a phone-sized button grid to the toolbar.

Details and Safety use native toolbar controls and native sheets/inspectors. Escape closes the topmost transient detail surface first and restores its invoking focus; from a terminal result it returns through the host's ordinary Close behavior. Return or Space operates only the focused semantic control; neither is a global capture, replay, rematch, or submit key while a report field is being edited. Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O and their existing app meanings.

Command-W and normal quit have no competitive penalty on a confirmed final result. If this component is hosted while the surrounding match is still active, close/quit requests use the host's actual stage-specific confirmation where the platform permits: cancellation before Go, explicit confirmed forfeit only in an otherwise eligible started match, and safety/invalid/service no-contest precedence. Force quit cannot be prevented or treated as confirmed voluntary forfeiture.

Result reading never requests camera/TCC access. Denied, restricted, missing, in-use, external-camera, or Continuity Camera disconnection states belong to setup/capture and must not erase existing permitted result text. Returning to a new match uses the real camera recovery route, not a fake preview or rated file-picker substitute. Inactive, minimized, background, locked, or interrupted acquisition is stopped and sensitive media shielded immediately by the host. A returning window retrieves the same authoritative state without resetting deadlines, retakes, or allowance. One account has one active match and one camera owner across windows/devices; secondary result windows are read-only presentations and never acquire a second celebration, session, or charge.

## States, Actions, and Recovery

| State | What the person sees | Action and recovery |
| --- | --- | --- |
| Capture, upload, checks, or judging | The host's actual stage and timer; no category meter, live physique score, predicted gap, or likely winner | Existing safe exit, recovery, and privacy actions remain available. Accepted-image counts are operational progress, not score points. |
| Result finality or rating settlement not confirmed | Result pending, with only the appropriate labeled last-confirmed account rating outside the absent receipt | Retry retrieves this same match. The client does not declare a win, zero change, or no-contest because its own wait elapsed. |
| Confirmed outcome with unavailable details | The separately confirmed outcome may remain, with Score details unavailable or Rating details unavailable in the affected complete group | Retry fetches the missing authoritative data. Do not compare one participant's new values against another's older values or fabricate a receipt. Close and Safety remain usable. |
| Valid judged win or loss | Final outcome text, both accepted totals, static gap, four category pairs, own actual receipt, versioned details | One eligible fresh reveal; no change of player order or size. Details, permitted View poses, Close, and safe new-match entry remain usable immediately. |
| Valid draw | Draw, both actual totals, exact gap, draw-band explanation, and actual signed Elo change | Never rename a draw No contest or promise unchanged Elo. There is no crown for a slightly larger total inside the draw band. |
| Valid zero score or equal totals | Explicit zero values or equal accepted values; gap 0.0 when appropriate | No placeholder substitution, minimum fill, tie-breaking decoration, or extra judgement. |
| Positive, negative, or zero effective Elo | Signed gain, signed loss, or Unchanged, with matching settled before/after context | The receipt never changes sign during motion. Bound-limited zero is not a fetch failure or withheld reward. |
| Unplaced or provisional | No invented earned seed or placed tier; after a first settlement, actual earned rating and confirmed provisional progress | Details explain the pairing seed without presenting it as an achievement. A service-confirmed placement update changes the top identity rail. |
| Eligible own forfeit or opponent forfeit | Forfeited or Won by forfeit, actual rated receipt, and No physique scores | No category bars, total zeros, superiority explanation, or pose gallery. A neutral rating transition is allowed for a fresh settlement; no winner trophy is manufactured. |
| No-contest | No contest, No Elo change, safe reason, and confirmed restoration status when available | No scores, draw medal, category placeholders shaped like zero meters, or new placement contribution. Restoration pending is not a promised extra slot. |
| Duplicate final event or ordinary refresh | The same coherent final values | No second roll, haptic, badge reward, or advancement. Refresh does not call another judge. |
| History, deep link, relaunch, reopened details, second window, or result first retrieved after an interruption | Static final data, with saved/corrected context where relevant | No award replay or deferred celebration, even when this device never displayed the original reveal. |
| Offline with a permitted same-account result cache | Saved result and freshness state; complete last-confirmed numeric groups | Retry refreshes the same record. No new Elo, badges, live standing, or media authorization is inferred from the cache. |
| Offline without a permitted cache | Unable to load result, Retry, Close, Safety where available | Do not show empty history, fake zeros, sample opponents, or a local result. |
| Scoring review pending | Current confirmed outcome and receipt, plus Under review and private status access | Request scoring review does not reroll the judge, provisionally refund Elo, or accuse the opponent. |
| Authorized correction settling | Rating updating after review; labeled last-confirmed coherent snapshot and safe review context | New rated entry remains unavailable while the seed is unsettled. Failed refresh retains pending status rather than mixing old scores with new rating. |
| Authorized correction settled | Corrected result, updated effective outcome and permitted scores, separately labeled original settlement and current adjustment | Replace the effective numeric group coherently. Invalidated scores and awards disappear immediately; no reverse count-through, celebration, or automatic image opening. |
| Badge data not yet confirmed | Existing confirmed complete rail, with the badge owner's honest updating/unknown status | Do not assume an empty collection, grant an unlock from local arithmetic, or postpone the result until badges arrive. Later confirmation is a quiet state update, not a second result ceremony. |
| Badge or placement removed by correction | Corrected effective rail and appropriate notice; provisional/unplaced where confirmed | Remove the invalid entitlement immediately. A removed focused badge returns focus to its owner's rail heading or the correction notice. |
| Hidden, reported, blocked, withdrawn, expired, or removed media | Host-owned accurate privacy placeholder; allowed nonmedia result stays readable | Protection is immediate. No animation retains the last sensitive frame or revives a cached image. Hiding or blocking alone does not rerate the match. |
| Blocked, deleted, or unavailable opponent | Safe player placeholder and permitted result context | No private profile action, hidden identity leak, or inferred missing badge inventory. Do not expose a restriction accusation. |
| Account switch, sign-out, access revocation, or account deletion | Prior account's private result and animation state removed | No residual score, receipt, case, badge event, or image appears under another account. Reauthentication follows the existing access flow. |

A details or report sheet already being used takes priority over a result arrival. Do not dismiss it, move keyboard focus, or run a celebration behind it. The result is available statically when the person returns. Closing a final result never forfeits, cancels a settlement, or consumes another allowance.

## One Result Choreography

### Eligibility and start

The reveal belongs to the original service-confirmed finalization arriving while the active match's result presentation owner is visible and foregrounded. It is not triggered by view appearance, row insertion, numerical inequality, a redraw, or receiving a cached object. At most one presentation owner responds to that event. History and recovery routes always use the settled static presentation.

The reveal starts when authoritative values become available, not after a minimum suspense delay. It is skipped when the surface is obscured, inactive, offscreen, in energy-constrained mode, or already showing a correction. An accepted result does not wait for an illustration, image download, badge fetch, or animation completion.

### Timings and visible behavior

All offsets below share one start. They are not serial waits. The complete decorative response ends within 900 milliseconds, including any host transition that participates in this reveal.

| Phase | Timing from confirmation | Behavior |
| --- | --- | --- |
| Semantic publication | Immediately | Outcome, all available accepted numbers, units, accessible values, and allowed actions become final. Current badge/placement facts update without waiting for emphasis. |
| Host stage continuity | 0–280 milliseconds | Existing waiting/result content transitions in place. Player order, scale fairness, and top timer location remain stable. The host must not hide final text until this transition completes. |
| Score numeral settle | 0–220 milliseconds within the score reveal | Only final total and category glyphs make one short vertical settling roll, no more than fifteen percent of their current text line height, using a quick ease-out. Complete final glyphs remain legible from the first frame; no clipping mask hides the value. Labels, decimal precision, and units remain stable. There are no intermediate numeric readings. |
| Score rail fill | 0–650 milliseconds | Each complete final extent and endpoint are visible immediately. A soft leading-edge fill sweep brightens only within that accepted extent, ending at the same fixed endpoint. All paired rows share progress and scale; no racing lead color, moving score marker, overshoot, or fluctuating gap appears. A zero has no sweep. |
| Gap and outcome | Static from confirmation | Never interpolate the gap, flip an outcome icon, or infer a temporary winner from animation. |
| Own Elo numeral settle | 200–650 milliseconds; 450 milliseconds total | The final signed change and after value settle once within their own receipt. Before stays still; sign and scope stay fixed. Final values are readable throughout. No traversed rating, intermediate tier, slot-machine digit loop, or score-to-Elo morph appears. Zero uses static Unchanged. |
| One crest or badge response | 600–900 milliseconds | Use one eligible focus: newly confirmed badge group first, otherwise a confirmed changed placed-tier crest, otherwise an existing placed crest for a positive earned change. Newly earned badges receive one restrained shared outline emphasis, not independent bouncing. A crest may rise to at most 1.03 scale and settle with a heavily damped spring. Other changed items update statically. |
| Review or correction notice | Up to 180 milliseconds, not an award phase | New authoritative values take effect immediately; only the notice or neutral surrounding surface may crossfade. Never interpolate between conflicting outcomes or retain an invalidated badge during its removal. |
| Ordinary detail/status interaction | 140–200 milliseconds where the shared native control calls for it | Preserve input focus, respect cancellation, and reuse shared press feedback rather than creating a second button-motion style. |

This component introduces no ambient loop. It treats the score/receipt/relevant crest as one coordinated result event, with subdued supporting motion and one emphasis target, not simultaneous competing celebrations. The host's optional ambient layer must yield while this event is active. No flashing, strobing, body scanning, particle storm, screen shake, loser deformation, or pulsing badge wall is permitted.

F29-F owns whether an achievement actually exists and its ordering. First Bell and Ten Rounds exclude forfeits/no-contests; Placed follows effective placement; Three Straight follows the canonical streak, including eligible opponent-forfeit wins. A loss may legitimately earn First Bell, and a draw may settle a positive rating change: these facts update truthfully without pretending the person won. All earned badges remain represented above the players. An unlock arriving after the interval gets a quiet normal state update, not a restarted 900-millisecond ceremony. This component neither calculates milestone eligibility nor migrates editable local badge previews into earned status.

### Interruptions and replay prevention

A new authoritative correction cancels the remaining reveal and immediately publishes the new effective state. Older or duplicate revisions cannot overwrite it or restart motion. Correction approval without settled consequences keeps the labeled last-confirmed snapshot; it does not preview a likely adjustment.

Navigation away, scrolling that removes a readout from view, opening Details or Safety, live resize that disrupts the motion, backgrounding, minimizing, camera/privacy interruption, account change, Reduce Motion activation, or an energy constraint ends decorative work. The values stay final wherever still authorized. Returning never resumes an unfinished award. Category rows first revealed by scrolling appear final and still; they are not a staggered second celebration.

The entire view does not move accessibility or keyboard focus at an animation boundary. Repeated taps never replay. There is no Replay award button, no tap-to-collect Elo, and no haptic for each digit. If an existing app preference permits haptics, at most one quiet finalization cue may accompany the original eligible event on supported iPhones; sound is unnecessary and no new microphone permission is involved.

## Accessibility, Keyboard, and Focus

The result heading is concise: Won, Lost, Draw, Forfeited, Won by forfeit, or No contest. Meaning is never carried only by a crest, color, arrow, sound, or the sign of a rating change. Copy retains necessary units, safe reasons, current/saved status, and consequence language rather than hiding them to achieve minimal text.

Reading order follows the visual hierarchy: clock/status, outcome, both complete owner-grouped badge rails, You and total, Opponent and total, gap, own Physique Elo receipt, the four category pairs, and detail/recovery actions. Within each category, announce its full name, weight, participant, and accepted whole points. Decorative rails and moving copies of glyphs are not additional accessibility elements.

On an unobscured transition from waiting to final result, move accessibility focus once to the result heading and provide one concise final-result announcement with the actual outcome and own Elo gain/loss/unchanged state. Further exploration reads the final values, never interpolated digits or every timer tick. Ordinary refreshes and reveal completion do not repeat the announcement. A material correction receives one concise correction announcement without moving a person out of an active report or text field.

Buttons have semantic names and visible focus; passive scores do not enter the action tab order. Details can expose selectable native result text, but no drag, scrub, hover, long press, or timed tooltip is required to discover a value or meaning. Pointer hover uses quiet shared feedback and never triggers a reveal. Voice Control names match visible controls. Switch Control and Full Keyboard Access can reach Close, Retry, Details, Safety, and all authorized host actions.

Dismissed details return focus to their invoking control. If a correction removes the focused control or badge, move to the nearest meaningful surviving owner heading or correction notice, not an unrelated action or the underlying camera. Long text and large fonts reflow without clamping accessibility sizes. Preserve contrast on opaque score surfaces; Reduce Transparency must not leave text over a moving image. Non-color differentiation includes participant labels, explicit outcome, signed values, and placement wording.

Reduce Motion uses immediate static final numbers, filled rails, and badges, with at most a short 120-millisecond opacity change on a surrounding status notice. It removes glyph travel, fill sweeps, scale, spring motion, and decorative looping. Enabling it halfway through a reveal snaps to the same final information without replay. Low Power Mode where available, serious thermal pressure, and the app's equivalent energy-saving state use this static path too. Inactive/offscreen content schedules no decorative updates. The real service clock, result retrieval, safety response, and camera shutdown are never delayed to finish motion.

## Authority, Privacy, and Safety Invariants

Only an accepted service-owned result can supply competitive numbers. Raw provider output, local pose analysis, a client countdown, a profile edit, or a cached pending response is not a scored verdict. Retry retrieves the same match; it is not another model vote. Result presentation has no authority to apply Elo, placement, allowances, records, or badges.

All values in a compared group belong to the same match, participant assignment, judging version, and effective result revision. The owner account and permission context must remain current. Safety/access removal can happen immediately even while another part of the result is refreshing; privacy does not wait for visual snapshot coherence.

The opponent before finalization remains only an authorized avatar/silhouette plus real stage/count. Own live preview stays local. Only valid judged win/loss/draw results with current authorization can offer intentional View poses; forfeits and no-contests never gain a gallery. Ordinary media expiry is 24 hours after finalization, not after the counter animation. Hiding, reporting, blocking, withdrawal, expiry, or deletion removes the relevant media immediately and does not change a settled score by itself.

The result reveal never uploads, prefetches, exports, or reconstructs body imagery for decoration. Existing exercise image privacy remains unchanged. Every transmitted physique candidate/still must already have passed the separate local face-obscuring path; redaction failure remains fail-closed. A bystander remains invalid even when masked. Scores make no medical, identity, age, sex, gender, or verification claim.

Country/region is optional, manually self-declared, and presented by the identity owner with a neutral missing/unsupported state. Country, handles, Elo, public badges, UI chrome, and score overlays must never enter judge images or context. No UI screenshot is submitted as evidence and no local profile photo becomes a public avatar automatically. No screen replay, image-bearing telemetry, or private result export is introduced by this component.

## Ownership, Dependencies, and Files

- [F29 parent](../../DOCKS.md) owns the shared product, service authority, and competition boundaries.
- [F29-G native UI components](../DOCKS.md) owns shared native composition and coordination with sibling components. This child owns numeric presentation and the bounded result choreography, not another shell, timer, player panel, or inspector framework.
- [F29-A page and match flow](../../F29-A-page-and-match-flow/DOCKS.md) owns navigation, result host, safe actions, camera lifecycle, selected-image details, and focus entry/return.
- [F29-B judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns accepted score precision, weights, evidence validity, outcome boundary, and neutral explanations.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns actual settlements, proposed bounds, placement, exactly-once effects, historical receipts, and coherent corrections.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) and [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) own permission, hiding, reporting, review, lifecycle, retention, and service recovery.
- F29-F owns trusted public identity, optional country, the complete badge collection, confirmed unlock/removal facts, badge order, and current-versus-historical labeling. The score component consumes those facts; it does not establish another badge policy or profile surface.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-G-d-phase-1-score-counters.md) specifies the connected engineering slice and later human-review handoff.

Real shared result, correction, account, and badge contracts and their native host integrations must be implemented and human-reviewed before this component's production integration starts. Existing Ranked account/service work is a foundation to inspect, not evidence that Physique already exists. The view is not independently shippable with fake records or a local-rating substitute.

Prospective feature-owned files are the score-counter component and its small reveal coordinator under TimeMaster/Views/Physique/Components/. The existing or future result/history host supplies the accepted snapshot and action routing. TimeMaster/Models/PhysiqueDuelModels.swift and TimeMaster/Services/Physique/ remain shared foundation ownership; no competing transport model, settlement engine, or service is introduced here. Exact existing integration files are discovered before implementation rather than assumed present.

[Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) remain the style authorities. [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supplies nearby earned-crest and labeled-action language, not permission to copy its accessibility-size clamps or exercise-specific rating semantics. [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) is exercise HUD context only; its live provisional scores do not apply to Physique. [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) own the native window and preserved menu commands. [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift) contains local cosmetic previews, not competitive achievements.

## Direction Conflicts and Limits

The approved large vertical-player direction supersedes F29-A's earlier optional balanced two-column desktop comparison wherever a battle composition is present, including an opened paired-evidence context. The main documentation owner reconciles that shared text; this child does not silently retain side-by-side participants on wide Mac windows.

The shared result-motion direction refines F29-A's earlier simple final fade: final information remains immediate, and stage continuity, score settle, Elo settle, and the single badge/crest emphasis fit within 900 milliseconds total. Numerical proposals remain owned by B/C and versioned by the service. A future policy change must update those contracts rather than cause this UI to guess a new tie band or decimal convention.

Modern SwiftUI skill examples that assume iOS 26 or newer are not deployment authority. Public available APIs and equivalent older-platform presentation must preserve iOS 16 and native macOS 14 compatibility. No private glass API, target raise, new global theme, generated athlete asset, production preview fallback, or unrelated Profile redesign is authorized.

## References

- [Supplied battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): borrow the prominent timer, direct sports identity, and immediate result legibility; not the horizontal arrangement, colors, people, or publishing rights.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Best practices and Providing feedback: purposeful, brief, optional, interruptible motion. The single-stop roll and 900-millisecond envelope are this product's decisions, not Apple-mandated timings.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices: resizable windows, large-display information density, native input, menu commands, and full-screen behavior. Vertical participant order remains the user's product decision.
- Installed swiftui-pro guidance on accessibility and performance, and swiftui-animation guidance on scoped state-driven motion, cancellation, and reduced motion. Availability must be checked against the actual app targets rather than copied from newer sample APIs.
