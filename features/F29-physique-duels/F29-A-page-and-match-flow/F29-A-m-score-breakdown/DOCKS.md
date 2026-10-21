# F29-A-m — Score Breakdown

## Purpose and Boundary

Score breakdown is the deliberate, read-only explanation of one authenticated participant's finalized Physique match. It answers what was compared, how the four accepted category scores contribute to both totals, why the gap means a win, loss, or draw, and which judging policy produced that result. It does not judge again, measure a body, award Elo, or reveal pose images.

This is product specification and a future implementation direction, not a working screen, accepted prototype, measured result, or authorization to begin production code. The native iPhone and macOS direction follows the user's shared battle-composition decision. The numerical rubric remains the proposed version described by [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md); documenting its presentation does not establish calibration or human acceptance of the judge.

The parent result/history surface owns the outcome hero, the person's own Physique Elo before/change/after, the battle timer, public identities and badges, player panels, and View poses. F29-A-m owns only Score breakdown, its four category disclosures, score precision and units, common-evidence explanation, judging-version details, and entry into the existing safety/review flows. It creates no second result screen, evidence gallery, public score feed, coaching report, or model selector.

## Chosen Composition and Tradeoffs

Use a compact sports scorecard, not a radar chart, anatomical heatmap, head-to-head body bars, or percentage dashboard. Exact numbers and a consistent You/Opponent reading order explain a close outcome without making an accepted zero look like missing evidence or making a 2.9-point draw look like a three-point win. Four continuous rows with separators feel like a score sheet rather than four competing promotional cards.

The hierarchy is Score breakdown, confirmed outcome, both one-decimal totals, the one-decimal absolute gap and boundary rule, four category rows, the accepted neutral explanation, Common evidence, and Judging version. Close is the primary action for this read-only task. Request scoring review and Report unsafe explanation remain distinct, quiet text actions; neither resembles a replay or a paid upgrade.

A native iPhone sheet provides a focused reading surface without shrinking the battle into a miniature. A nonmodal trailing Mac inspector keeps the match context available while reading. When the Mac window cannot accommodate readable details alongside a large player column, the same detail content uses one window-attached system sheet instead of squeezing the people. No separate detached score window or inspector-specific navigation stack is introduced.

The sheet/inspector contains participant-labelled numbers, not a second battle composition. Numeric You/Opponent columns are not player panels. Whenever the host battle is present, its real timer or truthful terminal timer state stays above both complete, owner-grouped public badge/identity rails, followed by two LARGE VERTICAL player panels, You above Opponent. This order never changes on a wide Mac or external display. All earned public battle badges wrap; there is no three-slot limit, hidden +N, ticker, or label over a face, limb, or evidence frame. Short windows and large text scroll the stage rather than reducing participants to thumbnails. The timer and safe host actions remain reachable. Score breakdown does not duplicate, cap, or reorder the shared badge product.

## Visual Language and Visible Copy

Reuse the existing near-black background, dark elevated surfaces, white primary text, readable secondary ink, Inter Black headings, Inter Regular explanation text, and toolbar orange. Numbers use stable digit geometry and retain the existing scalable typography. The details surface is predominantly opaque; glass is not a layer behind every score. Reduce Transparency produces fully opaque readable surfaces. Existing shared margins, gaps, radii, control feedback, and measured readable widths govern spacing, not fixed screen coordinates or a new global theme.

The title is Score breakdown. Beneath it, Won, Lost, or Draw is the already confirmed outcome from the viewer's perspective. The totals have explicit labels You and Opponent and the visible unit pts / 100. A permitted match-time handle may accompany those labels, but must wrap separately rather than displace a score. A deleted, blocked, or unavailable identity uses the service-permitted neutral label; the original account name must not survive in an accessibility label or tooltip.

The gap line says Gap followed by its one-decimal value and pts. Beneath it, the short standing rule is Draw below 3.0 pts; win or loss at 3.0 pts or more. In a draw with unequal totals, neither column acquires a winner crown, victory color, or lead celebration. At an exact tie the gap is 0.0 pts, not a negative zero or a missing value.

The visible limitation is AI judgement of these poses, not a health or muscle-mass measurement. It is short, readable body text rather than a tiny disclaimer. Scores never use a percent sign. Percent signs appear only with the explicit label Rubric weight. No confidence, accuracy, body-fat, muscle-mass, attractiveness, demographic, or medical indicator belongs on this surface.

## Four Category Rows

Keep this order for both participants and for every disclosure. Both accepted scores remain visible together; choosing a player must not swap the entire card into a single-player view.

| Row | Visible rubric weight for the documented policy | Score unit | Meaning in its disclosure |
| --- | --- | --- | --- |
| Visible muscularity | Rubric weight 40% | Whole points out of 100 for You and Opponent | Apparent development in the permitted, interpretable shoulder, upper-arm, upper-back, thigh, and calf contours across the accepted poses; not physical muscle size or hidden anatomy |
| Definition | Rubric weight 30% | Whole points out of 100 for You and Opponent | Supported visible muscle separation in the common upper-arm and calf surface evidence; fabric edges, shadows, tanning, sweat, and extra skin exposure are not muscle separation |
| Symmetry and balance | Rubric weight 20% | Whole points out of 100 for You and Opponent | Apparent bilateral and upper/lower balance in the required front and rear contours; not a preferred gendered silhouette, skeletal ideal, breast symmetry, or diagnosis |
| Pose presentation | Rubric weight 10% | Whole points out of 100 for You and Opponent | Safe, recognizable alignment and consistent presentation of the three prescribed still poses above the evidence floor; not endurance, dangerous strain, seductiveness, or professional production quality |

Each row has a full-width category/disclosure heading, its labelled weight, and consistently aligned participant score values. A visible chevron makes expansion discoverable. At normal text size, the two numeric values occupy stable You and Opponent columns below the category heading. At larger text sizes or narrower inspector widths, they become two individually labelled lines inside the same row. No horizontal table scrolling, clipped category name, microscopic weight, or compressed number is acceptable.

Opening a row exposes its plain-language meaning and the permitted evidence relevant to that category. It explains the contribution to the weighted total in points, using that match's accepted score and frozen weight, with one-decimal contribution values for each participant. These contributions are explanatory, not additional scores, and are never individually rounded into a different total. A row can include a safe category-specific observation only when the accepted service record actually supplies it; a match-level explanation must not be expanded into invented per-player findings. The shared rubric meaning remains useful without manufacturing an image description.

One category disclosure is expanded at a time. Opening another closes the previous disclosure; tapping the open heading closes it. The heading stays visible in the reading position where possible, and expansion never forces a scroll to the top. The accepted match explanation remains its own compact section, so a reader does not have to open four rows to find the actual result summary.

The four weights are the frozen policy for this match, not adjustable controls. New policy versions must retain their own recorded meaning; history must not be relabelled with today's weights, category anchors, model, or draw band. A future changed rubric needs its reviewed version contract, not an implementer's guessed migration inside this view.

## Precision and the Draw Boundary

All eight category values are accepted whole-point numbers from zero through one hundred. A genuine accepted zero is displayed as 0 pts / 100 and remains a score. Missing, unobservable, refused, withheld, and transport-unavailable evidence are not numbers and never become zero, an empty progress meter, or an implied low score.

Both accepted weighted totals display exactly one decimal place on the zero-to-one-hundred scale, including 0.0 and 100.0. The absolute gap also displays exactly one decimal place. Locale-appropriate separators are allowed, but must not change precision, participant association, or the numerical boundary. The view must not decide the outcome from rounded whole-number cards, intermediate animation digits, provider prose, or additional hidden model precision.

A gap of 2.9 points is a rated draw. A gap of exactly 3.0 points is a win/loss, with the higher accepted total winning. The service's validated accepted scores, totals, policy and final outcome must agree. A larger margin is not a larger Elo award. A draw can still change each person's separate Physique Elo under [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md); this sheet does not imply No rating change merely because the match is a draw.

If the received detail contradicts its own scores, totals, policy or outcome, show that the complete details cannot be confirmed and offer Retry. Preserve a previously coherent confirmed revision only with its saved/last-confirmed label. Do not display an apparently trustworthy hybrid, select a convenient winner, locally repair the record, or silently reinterpret a final match as no-contest. Only the authoritative service can establish finality or an authorized correction.

## Common Evidence and Judging Version

Common evidence has a concise always-visible summary: Common regions only. Its disclosure explains the three accepted poses per participant: front double-biceps, side physique, and rear double-biceps. Acceptance is described in the past tense, as evidence accepted at judging, not a promise that the images still exist or remain viewable now.

The documented common regions are shoulders, upper arms, upper-back contours, and leg contours. Definition specifically requires interpretable common upper-arm and calf surface evidence. Front-chest and abdominal appearance and definition are excluded for both participants even when visible. Breast, nipple, groin, genital and buttock anatomy are never scoring regions. Facial appearance, skin color, country/region, handles, public badges, Elo, subscription and capture-device prestige are not scoring inputs. Clothes can support an interpretable outer contour without revealing definition underneath. Permitted coverage is not a penalty; extra skin is not a bonus. Required hidden evidence is neither guessed nor replaced with another region.

Missing required evidence for either person prevents a complete scored judgement under this fixed rubric. During capture, the existing capture owner may offer a safe permitted retake within the unchanged deadline and retake allowance. Score breakdown never asks the person to remove required coverage, retake after a finalized match, or upload proof. A finalized insufficient-evidence match is no-contest, not a zero-filled scorecard. Media expiring after a valid judgement is a different condition: it does not retroactively make the accepted category evidence missing or turn the match into no-contest.

Judging version has an always-visible service-supplied policy identifier. Expanding it reveals the recorded rubric/version label, category weights and scoring precision, draw band, explanation-policy context, requested provider model identifier, and provider-returned model identity when the service has one. It also explains that both participants were judged together under that match's policy frozen before Go. Relevant recorded judging settings can be named without exposing prompts, hidden reasoning, credentials, internal endpoints, raw moderation classifications, or private eligibility declarations.

If the provider did not supply an immutable release identity, say Provider release not supplied. A model alias is not labelled as an immutable snapshot. A missing required judging-policy identity makes the detail incomplete; it is not replaced by the current app default or guessed from the model's name. A version label does not assert accuracy, fairness, medical validity, or App Store approval. Historic versions remain historic even after a service upgrade.

## Native iPhone Composition

Score details opens only after an intentional tap from a real result or private history detail. Use one native, large-detent sheet with Score breakdown in its top toolbar and a leading Close control. Full height is deliberate: totals, the exact draw boundary and four labelled rows are more useful together than a half-height card that hides most of the explanation. Standard downward dismissal is allowed because this surface has no edits and closes no active participation. Close remains available without dragging or reaching the last row.

The sheet uses one vertical reading scroll. At its top are the confirmed outcome, the two labelled totals, gap, boundary rule and four-row scorecard. Explanation, Common evidence, Judging version, and the two review/safety entries follow. Only the compact toolbar stays fixed; large text must not turn pinned totals into a wall that leaves no room to read the rows. The parent match retains its timer, complete badge rails and two large vertical players beneath the sheet, but the sheet does not try to reproduce them in the remaining visible sliver.

Portrait, short-height landscape, small iPhone displays, safe-area changes and the largest supported Dynamic Type sizes use wrapping and vertical scrolling. The category heading and weight can occupy separate lines. Both participant labels and units remain explicit when value columns stack. The sheet does not request the camera, Photos, microphone or location. Returning from a permission change elsewhere does not start a capture.

Opening a report or review hands control to the existing owner through the parent presentation route: close this sheet before presenting that flow. Do not pile a report sheet on top of the score sheet. Returning restores the same match, expanded category and reading position when still authorized; it does not replay a result reveal or automatically reopen pose images. Cancelling a report does not restore unsafe text the person has hidden.

## Native macOS Composition

This is a native macOS 14-or-later surface in the existing Tmax WindowGroup, not Catalyst, a web panel, or a stretched iPhone. Retain the normal title bar and the existing 800 by 600 minimum. A labelled Score details toolbar control shows or hides the trailing in-window inspector for the explicitly selected finalized result. The inspector has a Score breakdown heading and a clearly named Close score breakdown action. It does not replace the match's toolbar or hijack an app-wide shortcut.

The inspector occupies a readable supplementary column with its own vertical scroll and the same scorecard hierarchy. Its native divider can adjust reading width without stretching the stage across an ultrawide display. On laptop, full-screen and external-display layouts, the match remains a centered, measured player column with You above Opponent; extra width supports the inspector, not a horizontal body matchup. Score numerals are selectable read-only text where native selection is available, never editable rating fields.

At 800 by 600 and other constrained content widths, category scores can stack within a row and the stage can scroll vertically. If the measured content cannot support both a readable inspector and a large, properly framed player column, present the same inspector content as one native window-attached sheet. Do not raise the app minimum, shrink people into a thumbnail rail, truncate the scoring policy, or make the whole app enter full screen. During live resize, preserve the selected match, expanded category, reading anchor and focus; make any necessary pane/sheet adaptation once the resize settles rather than repeatedly opening and closing presentations while the pointer moves. There is only one score-details presentation, never an inspector plus an identical sheet. Returning to a wider window restores the nonmodal pane without replaying the score or changing the selected match.

The fixed inspector heading/close control and the host's timer and safe actions stay reachable in short windows. Trackpad, wheel and keyboard scrolling remain independent between inspector and stage. A native report/review sheet attaches to the window through the existing owner; the nonmodal inspector can remain behind it, but any constrained score sheet closes first. No detached panel follows an unrelated app window or reveals another selected account's scores.

Opening, resizing, copying permitted text, refreshing or closing score details never accesses a built-in, external or Continuity camera. TCC denial, a missing camera or a disconnected device is not a reason to block authorized historical scores or offer a rated file-picker substitute. Any concurrently owned active-match camera interruption remains with the shared lifecycle owner: stop/shield immediately, restore the same service state within the real grace period if permitted, and never extend a deadline. This detail view cannot acquire a second camera owner, start another session, or consume another allowance in a secondary window.

Window deactivation, minimization, backgrounding and display changes stop decorative work and shield private visible content according to the shared privacy lifecycle. Restoration rechecks the current account and authorized revision before exposing private content; it never restarts a clock or fetches images to decorate a stale result. Closing a finalized result has no forfeit consequence. If the shared host has an actual active participation consequence, Command-W or Quit uses that owner's state-aware confirmation where the platform permits; this read-only inspector must not swallow it. Force quit cannot be prevented or interpreted as an explicit confirmed voluntary forfeit.

## States, Actions and Recovery

| Actual state | Visible treatment | Available action and consequence |
| --- | --- | --- |
| First detail retrieval | Score breakdown, Loading score details and native activity feedback; no illustrative scores or fake rows | Close remains available; the request retrieves this match only |
| Confirmed scored win/loss/draw | Both exact totals, gap, boundary, four complete accepted rows, safe explanation and recorded version | Expand rows/evidence/version, Close, Request scoring review, or Report unsafe explanation; no judgement call or rating write |
| Genuine accepted zero or maximum | The actual 0 or 100 whole-point category and the correct one-decimal total/contribution | Same controls as any other valid score; no missing-value label |
| Result pending or not yet finalized | Scores not available yet, with the actual pending stage if authorized | Close or refresh existing result state; normal host does not offer active-looking breakdown entry before finality |
| Valid forfeit | No physique scores — match ended by forfeit, with the actual safe outcome context | Close or the existing dispute route; no four empty rows, score comparison or opponent gallery |
| No-contest, including insufficient evidence/refusal/deadline | No physique scores with the service-approved private reason and no Elo change | Close or the applicable review/support route; no draw badge, numerical fallback, recapture after finality or gallery |
| Initial request fails or device is offline without permitted saved detail | Unable to load score details; distinguish connection failure from an unscored match | Retry for the same record or Close; failure does not create a new competitive outcome |
| Offline with a complete authorized saved nonmedia revision | Saved result — not refreshed and a last-confirmed time; numbers stay together under their historical policy | Read disclosures, Close, explicit Retry when useful; no current-service claim or body-image load |
| Refresh in progress | Keep the coherent last-confirmed card with an unobtrusive refreshing state | Close and safe reading remain usable; repeated Retry cannot start parallel score requests or rerun judging |
| Required score/policy detail missing, malformed or internally contradictory | Complete score details unavailable; preserve a prior coherent revision only when allowed and labelled | Retry or existing scoring-review/support path; never zero-fill, guess a model version, combine revisions or locally repair a winner |
| Explanation removed after finalization | Explanation unavailable in the explanation slot; confirmed permissible numbers remain if the service still authorizes them | Existing unsafe-explanation report/case route where applicable; do not regenerate a euphemistic replacement or imply an automatic rating reversal |
| Person reports or hides unsafe explanation | Replace that text immediately with a safe placeholder; preserve the report target without echoing unsafe words | Hand off to the existing report flow; cancellation does not unhide it and an offline draft is not a receipt |
| Scoring review pending | Under review beside the current confirmed revision and a private case-status entry | Read the effective result or open the actual case; no predicted reversal or promise of another model vote |
| Correction approved but settling | Correction pending / Rating updating after review with a clearly labelled last-confirmed score revision | Read the permitted correction reason/case; no mixed original totals and corrected outcome, and no local Elo adjustment |
| Corrected scored result settled | Corrected label and date, coherent corrected outcome/detail, original judging context and permitted change explanation | Read the correction context or existing case; no winner celebration or second award |
| Corrected to no-contest | Corrected — No contest and the authorized reason; the old scorecard is not the effective result | Existing review history can distinguish the original record where authorized; no active opponent gallery or fabricated replacement scores |
| Pose media expired, withdrawn, hidden, blocked, deleted or removed | Nonmedia scores remain only as authorized; evidence text says accepted at judging, not available now | Image actions stay with the host's reason-specific placeholders; no thumbnail recovery, automatic View poses, regeneration or renewed expiry |
| Opponent identity unavailable, deleted or blocked | Safe neutral identity label, no discoverable prior handle or profile link | Permitted own match facts remain; a block does not itself rerate the result |
| Result access denied, account switched, signed out or account deleted | Remove prior private values and present the appropriate safe account/unavailable state | Existing account recovery or Close; a match identifier never bypasses authorization and Retry never shows another account's cache |
| Backgrounded/minimized/inactive, then restored | Shared privacy shield and no decorative activity; restore only currently authorized content | Restore the same selected record without a new judgement, allowance use, gallery or score-award animation |

Missing category evidence before a valid verdict and missing media after ordinary expiry are intentionally different states. A cached detail is not permission to retain revoked identities, unsafe text, private case data or images indefinitely. Shared access/deletion rules take precedence over reading continuity.

## Actions, Focus and Accessibility

Score details is a named semantic button, never a score-value tap target that only a sighted person can discover. It is available from the correct authorized result/history context, without requiring a photo to be opened. The sheet/inspector is read-only; Close does not submit, withdraw consent, delete evidence, forfeit, queue again or alter rating.

On deliberate opening, VoiceOver focus moves to Score breakdown, followed by the confirmed outcome and exact totals/gap. The reading order is heading, outcome, You total, Opponent total, absolute gap and rule, each category with You then Opponent, explanation, evidence/version, review/safety, Close as reachable toolbar action. A category announces its name, rubric weight, both whole-point scores, units and expanded/collapsed state. Points out of one hundred and weight percent are spoken distinctly. The final numbers are available immediately to assistive technology even when presentation moves.

Keyboard Tab and Shift-Tab follow native control order. Return or Space activates only the focused semantic control, not a global capture, Ready, Close or review action while the person selects text or types in another route. Category disclosures operate with normal keyboard activation and native focus rings. On macOS, selectable text supports normal selection/copy commands without adding an export workflow. Pointer hover may strengthen a control outline but cannot reveal the only explanation, safety action, weight or version.

Escape closes a focused score-details sheet or inspector when no higher-priority native presentation or editing action owns it. If a report/review flow is open, that owner's draft/confirmation rules take precedence. It does not close the host match twice or manufacture a forfeit. Close restores focus to the invoking Score details control; if it no longer exists after correction or deletion, use the safe result heading. A refreshed result or review update is announced once without repeatedly stealing a reader's focus or speaking every intermediate digit. A safety removal takes effect immediately and may move focus to its safe notice.

All iPhone actions retain at least the existing forty-four-point interaction convention. Mac controls keep native density with visible focus and readable labels rather than adopting giant phone buttons. Dynamic Type, supported larger Mac text, Voice Control, Full Keyboard Access and Switch Control can reach every disclosure, Retry, Close and safety/review action without a precision gesture or hover. Color, haptics, sound, trophy shape and animation are never the sole outcome or state cue. No image inventory, intimate anatomical narration or demographic guess is introduced into accessibility text.

Preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O. Score details registers no competing shortcut, app-wide key handler, camera command or new document window.

## Motion, Interruption and Energy

The motion character is tactile and precise, not an animated analysis machine. Numbers in this deliberate detail view are already final: they do not count upward from zero, roll past a win threshold or replay the host's award. All actions, exact values and safety access are available before a transition settles.

| Real trigger | Motion and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Press a shared action or disclosure heading | Existing press feedback with the shared spring response of 0.24 seconds and damping fraction 0.88; no second custom bounce | Release/cancel follows the normal semantic action; Reduce Motion removes added scale |
| Open/close iPhone sheet or constrained Mac sheet | Native platform presentation and interactive dismissal, with no custom delay or forced spring overriding system behavior | Dismissible immediately; system reduced-motion presentation is respected; no app timer waits for it |
| Open/hide the in-window Mac inspector | A short, nonbouncy trailing-pane continuity transition with a nominal 280-millisecond settling target; native live resize remains direct | Reverse from the current position if toggled again; Reduce Motion uses immediate layout or at most a 120-millisecond opacity change |
| Expand/collapse one category, Common evidence or Judging version | Disclosure indicator turns through its ordinary quarter-turn in about 180 milliseconds; content opens/closes over about 200 milliseconds with a soft, nonbouncy settle | Latest action wins from the current presentation; preserve the reading anchor and focus; Reduce Motion replaces layout travel with immediate layout and optional short opacity |
| Complete a genuine detail load | The complete coherent scorecard replaces loading together in about 180 milliseconds; no serial row fanfare or intermediate numbers | Close, account change, revocation or a newer revision cancels the reveal; saved/history reopen has no award animation |
| Receive an authorized correction | Revised text and permitted score values crossfade together over about 180 milliseconds after settlement, with the correction label already present | No count-up, winner flash or Elo animation; safety/deletion can replace immediately; announce the revision once |
| Remove unsafe text, revoke access, sign out or shield a backgrounded surface | Immediate replacement with the safe notice/privacy shield | Never wait for a fade, sheet motion or pending number transition |
| Return to a wider Mac layout after resize | Native pane continuity, at most the same 280-millisecond settle after the final layout choice | Preserve the match, expanded disclosure, scroll anchor and focus; no repeated transitions during a live resize |

The host owns any one-time confirmed final score reveal of roughly 650 milliseconds and own-Elo motion of roughly 450 milliseconds, with the whole result presentation settling within 900 milliseconds rather than serial celebrations. This view does not schedule another celebration, badge pulse, sound or haptic on opening, history revisit, refresh, correction or restoration. Its transitions join the host's existing focal event or wait quietly; they must not create a competing focal layer.

There is no ambient loop, scanning beam, animated anatomical map, shimmering score skeleton, fluctuating score, loser shake, flashing badge wall or per-row repeating indicator. Low Power Mode or serious thermal pressure uses static final details and immediate disclosure layout, retaining essential native focus/press feedback. Offscreen, inactive, minimized and backgrounded detail surfaces perform no decorative work or automatic replay. Privacy stops are immediate, authoritative match clocks continue elsewhere, and no per-frame networking, provider call, image decode, font measurement or global stage invalidation is part of score motion.

## Data Authority, Privacy and Safety

One complete service-confirmed match revision supplies both participants' accepted categories, weights, totals, gap, outcome, safe explanation, judging version and applicable correction context. It is bound to the authenticated participant and selected historical match. The view is a reader, not a second validator that can settle competitive outcomes. Retry refreshes that same record; expansion, closing, app restoration and switching presentations issue no judgement, reroll, rating transaction or allowance charge.

Opening the scorecard downloads no pose image or rejected candidate and never uses a thumbnail as a placeholder for missing text. View poses remains intentional in the host, only for a valid judged win/loss/draw under current permission, moderation, participant access and the original ordinary twenty-four-hour window. A forfeit/no-contest has no opponent gallery. A lawful review hold does not extend counterpart viewing. Score/version history does not require permanent image storage.

Public country/region, badges, handles and competitive identity remain presentation only. Country is optional and self-declared; no location permission, inferred country, verification claim, regional scoring or country filter is added here. Neither score UI nor battle chrome is captured as judge evidence. The existing locally face-obscured clean-image path remains mandatory before every transmitted candidate or still, and an unmasked original is never a recovery fallback. This read-only surface cannot upload a local profile photo or access private attire/age declarations.

Request scoring review enters the existing distinct dispute flow with this match/revision context. It explains that ordinary images expire twenty-four hours after finalization and that expired images cannot be recreated; any preservation disclosure belongs to that flow before submission. Report unsafe explanation targets the accepted explanation without asking for a screenshot, photo enlargement or new body-image attachment. Actual report receipts, unsent/offline state, private case progress and corrections stay service-owned under [F29-D](../../F29-D-safety-and-reporting/DOCKS.md). Opening either route does not itself preserve media, reverse a result, grant a free win or change Elo.

A safety removal after finalization can withhold text while the confirmed numbers remain permitted. It does not authorize a friendly generated replacement or an automatic correction. Unsafe wording cannot remain in hidden accessibility labels, copy buffers controlled by this surface, tooltips or app-switcher snapshots after removal. Do not promise control over external copies a person has already made.

## Dependencies and Review Boundaries

- [F29-A page and match flow](../DOCKS.md) supplies the real result/history selection, vertical timer-and-badge battle host, navigation restoration, and safe lifecycle owner. This child consumes that shared composition rather than redefining it.
- [F29-B AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns accepted whole-point categories, fixed weights, one-decimal totals/gap, exact draw boundary, comparable evidence, safe explanation and frozen judging-version meaning.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns authoritative finality, effective history, separate Elo and audited corrections. This view cannot be connected to provisional local awards.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) supplies working explanation reports, score disputes, private case status, content protection and human review.
- [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) supplies real authentication, account-scoped access, allowed nonmedia caching, retention/deletion, privacy shielding and processor disclosures.
- F29-F owns trusted public identity, optional country/region and the complete earned-badge product. This score reader neither migrates editable local badge previews nor creates a second badge system.
- Shared native state, service and presentation foundations, plus the result/history and safety destinations above, must be implemented and human-reviewed before this score reader is connected. A preview or a promised future service is not sufficient. The current documentation-only batch grants no independent shipping authorization.

## Files and Ownership

These are ownership locations, not a claim that the future implementation files exist.

- [This product context](DOCKS.md) owns the scorecard behavior and native composition.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-m-phase-1-score-breakdown.md) assigns this bounded connected slice to the specified UI worker model.
- Prospective TimeMaster/Views/Physique/PhysiqueScoreBreakdownView.swift owns this read-only detail content and its iPhone/Mac presentation integration.
- Prospective TimeMaster/Views/Physique/PhysiqueScoreCategoryRow.swift owns the reused four-row numeric/disclosure treatment, if an equivalent reviewed shared row does not already exist.
- The real result/history host under TimeMaster/Views/Physique/ owns the invoking action, selected match, timer/badge/player composition, gallery route and focus restoration. Only its bounded details connection belongs to this slice.
- Prospective TimeMaster/Models/PhysiqueDuelModels.swift and TimeMaster/Services/Physique/ supply reviewed authoritative result state. Missing contracts are a prerequisite, not permission to invent a second model, backend or production mock here.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift) and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) remain the shared styling and feedback owners.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) remain the native Mac window/command owners; no app-wide redesign belongs to score details.
- [CYCLES.md](../../../../CYCLES.md) alone owns implementation tasks and human-review tracking. No implementation status or verification evidence belongs in this document.

## References

- [F29 parent](../../DOCKS.md), [F29-A](../DOCKS.md), and the B/C/D/E contexts above are product and authority boundaries, not implementation proof.
- [Supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) informs timer prominence and immediate sports hierarchy only. Do not copy its side-by-side player layout, badge overlays, web pills, pictured people, captions or presumed image rights.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supplies existing action/earned-rating visual language, not permission to copy text-size clamps, ambiguous score units or fabricated local levels.
- [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) is exercise-HUD context only; its live provisional exercise scores do not belong in physique details.
- [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift) distinguishes editable cosmetic previews from trusted competitive achievements.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices, supports a resizable native workspace, keyboard/pointer input and useful supplementary content rather than a stretched phone screen.
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), especially Best practices and iOS/macOS platform considerations, informs the scoped large iPhone sheet, visible dismissal, one-sheet routing and constrained-window Mac presentation.
- [Apple HIG — Panels](https://developer.apple.com/design/human-interface-guidelines/panels), especially inspector guidance, informs a selected-match inspector; a trailing pane rather than a detached floating panel is the product choice here.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Providing feedback, informs brief purposeful and interruptible motion. The durations above are proposed product targets, not Apple-mandated timings or measured performance.
