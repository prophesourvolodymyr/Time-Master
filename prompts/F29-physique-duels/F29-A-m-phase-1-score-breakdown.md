# Phase 1 of F29-A-m — Native Score Breakdown

## Assigned Model and Thinking

Run this implementation worker with **openai-codex/gpt-6.1-sol**, thinking level **max**. The dispatch notation is **openai-codex/gpt-6.1-sol:max**; max is the thinking level, not a different model. No silent model substitution, lower-thinking fallback, or claim that an unavailable dispatch occurred. If the assigned worker cannot be provided, identify the actual dispatch limitation before work is assigned to another model.

This is the coding/design worker assignment. It does not select the in-app ranked judge, increase the judge's reasoning setting, authorize a provider call, or change a match's frozen model-policy version.

## Features Included

- **F29-A-m — Score breakdown:** deliberate read-only details for one authorized finalized match, four category rows for both participants, precise totals/gap and outcome boundary, common-evidence explanation, historical judging version, and existing safety/review entry points.
- **Native iPhone presentation:** large system sheet, readable scrolling/reflow, dismissal/focus restoration and single-sheet handoff.
- **Native macOS presentation:** selected-match trailing inspector, readable constrained-window presentation, live-resize continuity, keyboard/pointer/focus and window-lifecycle behavior.

Each meaningful implementation task must be listed separately for human verification and recorded separately in the relevant CYCLES.md implementation tree. These are parts of the same connected slice, not independently shippable mock screens.

## Context

Physique results require a deliberate explanation that preserves exact accepted scores without implying medical measurements, calibrated confidence, image access, or a second Elo award.
The user chose a real timer above complete owner-grouped badge rails above two LARGE VERTICAL players on both iPhone and Mac; supplemental details must not replace that composition with a horizontal matchup.
Implement only after the real shared F29 contracts, result/history host and safety routes are implemented and human-reviewed; this documentation batch does not authorize production implementation now.

## What You Need to Read First

Read these exact product contexts completely before coding:

- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-m-score-breakdown/DOCKS.md` — owns this score reader's complete native behavior, states and interruptions.
- `features/F29-physique-duels/DOCKS.md` — shared lifecycle, privacy, real-service authority and proposed numerical defaults.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — result/history host, approved vertical battle composition, capture and presentation boundaries.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — whole-point categories, fixed weights, one-decimal totals/gap, 2.9 versus 3.0, evidence sufficiency, safe explanations and historical judging policy.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — exactly-once finality, separate Elo, historical result context and audited corrections.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — immediate unsafe-text protection, distinct explanation reports/scoring disputes, real receipts and review limitations.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — authentication, current access, nonmedia history, cache/deletion rules, consent withdrawal and image expiry.
- `features/DOCKS.md` and `CYCLES.md` — discover the current shared F29 foundation, trusted identity/badge and result/safety child owners and their actual human-review boundaries. Read the linked contexts before using those dependencies; do not invent a missing path or treat a checked engineering task as human acceptance.

Read these actual source anchors and then the real reviewed F29 callers/models/services located through the current repository, not guessed filenames:

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — shared near-black surfaces, toolbar orange, card/control ownership.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — scalable Inter typography, spacing and readable-column conventions.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — supported native material fallback, Reduce Transparency and the shared press spring with response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — shared sports/action/earned-Elo language. Do not copy Dynamic Type clamps or ambiguous score scaling.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only. Provisional exercise metrics are not a valid Physique score presentation.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar and existing 800 by 600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — local cosmetic badge previews are not trusted achievements or verification.
- `TimeMaster.xcodeproj/project.pbxproj` — verify the actual app target membership and compatibility. Keep native macOS 14 and iPhone iOS 16 support; do not raise targets to follow a newer skill example.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow timer prominence and direct sports hierarchy only, not horizontal players, badge overlays, purple/brown web pills, pictured people, captions, footage or assumed asset rights.

Use the smallest relevant installed guidance: `skill://swiftui-pro` with accessibility/navigation/performance references, `skill://swiftui-animation`, and `skill://apple-hig-reference`. The coordinating owner already selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI in the specification batch; do not repeat setup or claim the worker loaded an unavailable context. Resolve and read its supplied context if available in the implementation session. Otherwise state that limitation and use the installed native references, not a fictitious downloaded pattern. STYLES.md was absent in the design batch; discover any subsequently added authorized style context rather than creating a parallel global theme.

Current primary design references to recheck when relevant:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices for resizing, display use, native commands and keyboard/pointer input.
- https://developer.apple.com/design/human-interface-guidelines/sheets — scoped tasks, dismissal, large iPhone detent, one-sheet routing and Mac platform considerations.
- https://developer.apple.com/design/human-interface-guidelines/panels — selected-item inspector meaning; this design chooses a trailing pane rather than a detached floating panel.
- https://developer.apple.com/design/human-interface-guidelines/motion — brief purposeful feedback and interruptibility, not a mandate for the proposed product timings.

DOCKS.md is plain-language product context, not an implementation recipe. Research framework availability independently and reuse the reviewed source conventions. No source code, payload, pseudocode, test logs, verification evidence or project todos belong in DOCKS.md.

## What Happened Last Session

The dedicated documentation worker specified the scorecard and this future brief only. It inspected the supplied battle image, existing B/C/D/E contracts, native source anchors, installed SwiftUI/HIG guidance and the relevant live Apple chapters. No F29 app code, service, production mock, generated artwork, runtime check or human-approved implementation was produced by that worker. The coordinating owner handles documentation integration and publication; dependency implementation/review status must be read again before coding.

The main UI pattern selection was supplied by the coordinator. The worker-local skill resolver did not expose `swiftui-ui-patterns`; this is not evidence that the main owner's CLI selection failed. No replacement CLI setup was run.

## Prerequisites and Review Boundaries

Code starts only after all of the following are real, connected and human-reviewed:

1. An authenticated F29 result reader supplies one account-authorized, coherent match revision, with both accepted category sets, frozen weights, exact totals/gap, service outcome, approved explanation, judging-policy identity, historical model identity and authorized correction state.
2. The result/history host owns real selected-match navigation, the timer/complete-badge/large-vertical-player composition, own Elo, privacy shielding, one active session/camera owner and state-aware exit handling.
3. The reviewed service contract distinguishes a valid scored result, pending finality, forfeit, no-contest, access denial, safe explanation removal and authorized corrections. It does not rely on client-side judging or an editable local rating.
4. Existing explanation-report, scoring-review and private case routes operate with genuine account authorization and receipt state. No image enlargement or new photo upload is required to use them.
5. The shared privacy/access contract supports permitted nonmedia history while revoking unsafe text, unauthorized identity and expired/withdrawn/blocked images. A current gallery permission is not inferred from a score record.
6. The approved scoring policy and quality boundary have actually been reviewed. The design documentation's 40/30/20/10 weights and below-three-point draw band are not a claim that calibration or production judge approval already happened.

Discover the actual dependency files from the feature index/source. If a prerequisite is not implemented/reviewed, identify the missing contract or human decision precisely; finish any reachable analysis without manufacturing a standalone shipping view, placeholder backend, fake peer/result, no-op safety button or second service abstraction. Do not expand this UI slice into implementing the judge, Elo service, consent stack, camera stack, badge product or report system.

## Concrete Design Decisions

- **Exact numeric scorecard over chart spectacle.** Four continuous rows with separators show both accepted category values. No radar chart, anatomical heatmap, two-player score bars, confidence gauge, percent-body rating or fifth quality category. Exact units explain close results more honestly than an animated chart.
- **Deliberate disclosure, not another battle.** Score breakdown is one supplementary reader. It has participant-labelled score columns but no player-image panels, local preview or badge rails of its own. The actual host remains timer first, all public badges grouped by owner second, two LARGE VERTICAL players third, at every Mac width. Never infer permission to reduce people to thumbnails to fit the inspector.
- **iPhone large sheet; Mac trailing inspector.** Use native presentations, a fixed compact heading/Close area and one detail scroll. A large iPhone detent is intentional because the exact gap, boundary and four rows need reading space. A constrained Mac uses the same content in one window-attached sheet rather than a broken tiny stage.
- **Progressive evidence, not secret arithmetic.** Totals, absolute gap, boundary, category names, both scores and labelled weights are visible without disclosure. Rows reveal the category meaning, actual weighted contributions and only real accepted category-specific observations. Common evidence and judging policy reveal secondary context without loading images.
- **Stable final values over number theatre.** Details do not count from zero or replay a result/Elo award. Shared press feedback, native pane/sheet continuity and tactile disclosure expansion provide motion while values stay readable and correct.
- **History stays historical.** Read that match's frozen rubric/model context, not today's defaults. A provider alias is not an immutable release. Correction, saved/offline and unscored states remain distinct.

These are selected design outcomes and tradeoffs, not a request to expose private chain-of-thought or invent an alternative screen.

## What to Build

### 1. Connect the deliberate details entry

Use the actual reviewed result/history host. A named Score details action opens this selected match's authorized details. Opening is not a request to judge, reroll, reserve/consume allowance, change Elo, fetch pose media or activate a camera. Prevent duplicate detail presentations and keep one selected match association across refresh and restoration.

For a normal pending result or known forfeit/no-contest, the host should not present an active-looking numerical breakdown affordance. An old/deep/restored details route must nevertheless render the actual pending or unscored state safely instead of failing or zero-filling rows. Read-only Close has no competitive consequence.

### 2. Render one coherent score revision

Show the heading, service-confirmed perspective outcome, labelled You/Opponent totals, absolute gap and boundary rule. Use whole points for all eight categories, one decimal for both weighted totals and the gap, and explicit points-out-of-one-hundred units. Use locale formatting without changing precision. A genuine accepted zero is a score; absence is not zero. No truncated or animated number decides the winner.

Read the real accepted record using the existing contract's exact numeric representation. Do not add binary-floating outcome decisions, reinterpret provider prose, use hidden precision or independently settle a client verdict. Preserve any existing exact-tenths arithmetic/contribution convention rather than introducing a second one. If consistency checks belong to the reviewed result reader, reuse them. A contradiction prevents a newly trusted scorecard from being displayed; it does not authorize local repair, a model rerun or a local no-contest.

Keep both participants' values, policy, explanation and correction context from the same confirmed revision. A refresh cannot combine a new outcome with old totals, swap participant associations, or merge a corrected row into the previous result. Keep the previous coherent authorized snapshot only with its last-confirmed/saved label.

### 3. Build the four row disclosures

Order: Visible muscularity, Definition, Symmetry and balance, Pose presentation. For the documented policy, show Rubric weight 40%, 30%, 20%, 10% respectively. Percent refers only to the weight. Both scores remain directly readable in stable labelled columns, stacking into separately labelled lines when current content/font width requires it.

A full semantic disclosure heading and chevron expand one category at a time. Its content explains the permitted category meaning and both one-decimal weighted contributions. Contributions are explanatory and must agree with the accepted weighted total without separate rounding changing that total. Use safe accepted category observations only if the authoritative record supplies them; do not synthesize per-player findings from a match-level explanation. Close/expand actions retain reading position and focus. Keep the match-level accepted neutral explanation outside the four disclosures.

### 4. Explain evidence and historical policy without images

The always-visible evidence summary is Common regions only. Explain the accepted front double-biceps, side physique and rear double-biceps set per participant; acceptance was at judging, not a promise of present media availability. Describe the common shoulder, upper-arm, upper-back and leg contours, and the definition-specific upper-arm/calf surface requirement. Exclude front-chest and abdominal appearance/definition for both people even when visible; protected anatomy, facial appearance, demographic/medical inference, country, public badges and Elo never enter scoring.

Permitted attire is not a deduction; additional exposure is not a bonus. Required hidden evidence cannot be inferred, scored as zero, replaced with another region, dropped for one player or compensated by changing weights. Evidence insufficient before finalization means a service-owned no-contest, not an in-sheet retake invitation. Ordinary image expiry after a valid result does not retroactively invalidate accepted scores.

Show the service-owned judging-policy identifier without opening a disclosure. Its details show the frozen rubric/weight/precision/draw/explanation context, requested provider model and provider-returned identity when actually supplied. Show Provider release not supplied when applicable; never invent an immutable snapshot. A missing required policy identity is incomplete details, not permission to use today's defaults. Expose neither prompts/private model reasoning nor secrets/private eligibility declarations. The UI worker model named above is not a policy value for the in-app judge.

### 5. Connect actual state, protection and recovery

Implement every relevant state in the product state matrix, not only a success card:

- Initial detail load, true offline without a cache, first request error and same-record Retry.
- Complete confirmed scored win/loss/draw, including genuine category zero/maximum and gap zero.
- Pending finality; valid forfeit; no-contest for insufficient evidence, invalid/refused/unsafe judgement or a missed deadline. No fake score rows, no draw-as-error fallback and no opponent gallery.
- Authorized saved/offline coherent nonmedia detail and unobtrusive refresh; never claim current service freshness or extend allowed retention.
- Incomplete, malformed or contradictory required result/policy data; retain only a labelled coherent prior revision where permitted.
- Safe explanation removal after finalization, immediate user report/hide protection and a report target that does not echo removed text.
- Scoring review pending, correction approved/settling, settled corrected scored result, and corrected no-contest. Keep effective results and original authorized review context distinguishable; do not celebrate or double-award a correction.
- Expired, withdrawn, hidden, blocked, safety-removed or deleted media. Do not load images or recover them to explain scores.
- Deleted/blocked/unavailable opponent identity, sign-out, account switch, access denial and account deletion. Prior account text and private values disappear immediately; match identifiers are not authorization.
- Background/inactive/minimized privacy protection and same-record authorized restoration. No camera, deadline reset, new session, provider call or gallery reopen.

A malformed client response or offline timeout is not itself an authoritative no-contest. Only the service can finalize or correct the result. Retry reads the same state and never performs a new judging request. Do not add unrelated retries, telemetry, provider selection or error-suppression abstractions.

### 6. Wire existing safety/review routes

Request scoring review and Report unsafe explanation are separate labelled actions with the actual match/revision/accepted-explanation context. No screenshot, image enlargement, photo attachment, user-paid access or new capture is required. A review entry explains the ordinary twenty-four-hour image window and the inability to restore expired images; evidence-preservation disclosures and actual receipt state stay with the existing route owner.

On iPhone and in a constrained Mac score sheet, dismiss this sheet before presenting the existing report/review flow from the parent. Do not stack sheets. On a wide Mac, the inspector can remain behind the actual window-attached case sheet. Returning restores this match's reading position/expanded row where still authorized. An unsent report is never a received case, cancelling never unhides unsafe text, and a report/dispute never implies an Elo reversal or newer model vote.

### 7. Deliver both native presentations and lifecycle behavior

**iPhone:** one large-detent native sheet, top Score breakdown heading, leading Close, standard swipe dismissal, compact toolbar and one reading scroll. Totals/gap/rule/four rows precede secondary explanation/evidence/version/review entries. No giant pinned score wall. Respect safe-area bounds, short landscape height, small devices and largest supported Dynamic Type. Preserve the existing forty-four-point action convention. No horizontal scrolling or type clamp to rescue a tight grid.

**macOS:** native macOS 14+ in-window trailing inspector for the selected real result, using the existing normal title bar and toolbar. Keep 800 by 600 support; do not raise the app-wide minimum. Use readable native density, selectable read-only score text, pointer hover/focus and independent inspector/stage scrolling. At laptop, large, full-screen and external-display sizes, extra space supports the inspector beside a centered readable stage; players remain vertical and equally framed.

When measured space cannot keep both a readable inspector and a large player column, use the same content in one native window-attached sheet rather than a detached window, cropped player, cramped thumbnail rail or forced full-screen mode. Preserve selected-match identity, disclosure, reading anchor and focus through live resize. Adapt the presentation once after resize settles, with no repeated sheet cycling while dragging and no duplicate inspector/sheet. Return to the nonmodal pane at wider usable space without an award replay. Use existing measured bounds/current text metrics and shared layout rules, not arbitrary fixed screen coordinates or a new global breakpoint system.

This read-only surface does not acquire camera ownership. Mac TCC denial, absent camera, external/Continuity-camera disconnection and secondary windows must not prevent authorized historic scores from being read, prompt for camera access, enable a rated file-picker replacement, charge allowance or start another match. Real active-match interruptions are handled by the shared lifecycle owner: acquisition stops/shields immediately, service clocks continue, the same state can restore without deadline reset, and a second window/device cannot create another owner.

Inactive/background/minimized windows shield private content and suspend decorative work. Return rechecks account/access/revision without a new judgement or automatic pose media. Escape dismisses this detail surface only when a higher-priority native editing/report presentation does not own it. Closing a final result has no forfeit consequence. Command-W/Quit must still reach the shared active-match consequence handling where applicable and permitted. Force quit cannot be prevented or converted into explicit confirmed voluntary forfeit.

### 8. Deliver semantic focus, motion and energy behavior

On deliberate open, focus Score breakdown, then expose the confirmed outcome, exact You/Opponent totals and gap. Each row reads category, weight percent, both whole-point scores/units and expanded state. Final accessible values are immediate, not animated approximations. Native Tab/Shift-Tab, focused Return/Space, keyboard scrolling, VoiceOver, Voice Control, Full Keyboard Access and Switch Control reach all disclosures, Close, Retry and safety/review actions. Never globally capture Return/Space while text is selected or another route is typing. Hover is supplementary, not the only path to explanations or version. Close restores focus to the invoking Score details control or a safe result heading if that control disappeared.

Preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O; no new competing application shortcut or document window. Native selection/copy of permitted read-only text is allowed, not a new result-export workflow. Removed unsafe text cannot persist in this view's labels, tooltips or view-controlled temporary content. Do not claim to erase external copies already made.

Use the existing press spring response 0.24/damping fraction 0.88. Native sheets retain system motion and interactive dismissal. The Mac inspector uses short nonbouncy continuity with a nominal 280-millisecond settle. Disclosure chevrons turn over about 180 milliseconds while their content opens/closes over about 200 milliseconds; latest input wins without waiting for the animation. Complete load and settled correction content crossfade coherently over about 180 milliseconds. Never roll category numbers, count from zero, invent analysis progress or replay history awards.

The result host owns the one-time roughly 650-millisecond final score reveal and roughly 450-millisecond own-Elo motion, settling within 900 milliseconds total rather than a serial queue. Details do not add a competing reveal, badge pulse, haptic or sound. Safety hides, sign-out, privacy shields and revocation are immediate regardless of animation.

Reduce Motion removes scale/travel/count-up/repetition and uses immediate layout or an optional short opacity change no longer than about 120 milliseconds. Reduce Transparency uses opaque readable backgrounds. Low Power Mode and serious thermal pressure use static final details/immediate disclosure layout while retaining essential native feedback. No ambient detail loop, per-frame I/O/provider work, photo decoding, font measurement, global layout invalidation or camera reconstruction. Offscreen/inactive/minimized/backgrounded surfaces perform no decorative work; authoritative clocks elsewhere do not pause.

## Files to Create or Modify

These source names are prospective integration locations, not assertions that files already exist. Discover and reuse real reviewed equivalents before creating anything.

- Create `TimeMaster/Views/Physique/PhysiqueScoreBreakdownView.swift` for the bounded read-only details surface and native presentation integration, unless an equivalent feature-owned file already exists.
- Create `TimeMaster/Views/Physique/PhysiqueScoreCategoryRow.swift` only if no reviewed shared row provides the required accessible labelled two-participant disclosure. Keep the four uses consistent; do not create four unrelated category view systems.
- Modify the **actual reviewed result/history host under `TimeMaster/Views/Physique/`** only for the selected-match Score details action, pane/sheet routing and focus return. If its eventual name differs from an earlier prospective result filename, use the real file and report the mapping; do not create a duplicate host.
- Read existing `TimeMaster/Models/PhysiqueDuelModels.swift` and `TimeMaster/Services/Physique/` equivalents as dependency contracts. This slice does not own a new judge, backend, rating model, media cache or contract shim. Missing shared foundations must be resolved by their authorized owner, not replaced by a local production mock.
- Add focused regression coverage to the real project's established test location only for uncertain consumer-visible precision/boundary, absent-versus-zero, identity/revision coherence or correction behavior. Discover target conventions first; no source-string tests, copied snapshots of incidental copy, wiring-only assertions or forwarding mocks.
- Update only the relevant `CYCLES.md` implementation items after actual connected behavior and focused checks, with human review still pending. Do not modify other workers' targets, shared design rules, app-wide command definitions, theme foundations or unrelated features.
- Update this child DOCKS.md only for a plain-language product decision explicitly accepted by the user; engineering proof, test output, screenshots, checkboxes and implementation status stay out of it.

## Observable Acceptance — Shared Score Behavior

1. A real authenticated finalized scored match opens with the same effective outcome and both accepted four-category sets as its service record. Both categories and totals have explicit units; weights are labelled rubric weights, not score/confidence percentages.
2. Whole accepted categories produce one-decimal totals and gap with no hidden precision or row-contribution rounding changing the result. 2.9 points is visibly Draw; exactly 3.0 is visibly win/loss for the higher total. A genuine zero remains 0, not unavailable. Neither provider prose nor a compact rounded number overrides the service's validated outcome.
3. Deterministic nonproduction boundary examples may use You scores 80, 75, 70, 70 in row order, giving 75.5 total. Opponent scores 77, 72, 67, 68 give 72.6 and a 2.9 draw. Changing only the opponent's last category to 67 gives 72.5 and a 3.0 win/loss. These are test data, never canned production results or evidence of a real judged match.
4. Opening a row shows the correct meaning, both accepted weighted contributions and only real approved observations. All four weights remain unchanged. Common-region exclusions, missing-evidence meaning and historic version context can be read without an image or hover.
5. A completed record never exposes confidence/accuracy percentages, body-fat/muscle measurements, medical/demographic conclusions, hidden model reasoning, private declarations or player-selected judge settings. The requested UI worker's model is not accidentally recorded as the ranked model-policy version.
6. Missing/invalid evidence, forfeit, no-contest, incomplete detail and offline error have distinct truthful presentations. None has fabricated zeros, partial victorious cards, a new model call, a local outcome or an opponent gallery.
7. Refresh, reopening history, presentation adaptation, background return and duplicate taps retrieve the same record without a second judgement, Elo award, record count or allowance effect. A draw does not imply unchanged Elo. Settled corrections are explicit coherent revisions, not replayed awards.
8. Saved nonmedia details remain clearly last-confirmed and account-scoped. Sign-out, access denial, identity deletion, unsafe-text removal and revocation protect immediately; media expiry does not erase authorized textual results or cause image refetch.
9. Both safety/review entries reach genuine existing routes with correct context and honest receipts/offline behavior. No fake link, no-op action, reupload request, screenshot requirement, promised reversal or hidden image retention substitutes for the real flow.

## Observable Acceptance — Native iPhone

- From both a real result and its private history entry, Score details opens one large native sheet and returns to the same host context on Close or swipe dismissal. No nested score/report sheets and no new camera permission.
- On a small supported iPhone, short landscape height and the largest supported Dynamic Type, category labels, both scores, units, weights, gap and draw rule remain readable by wrapping/scrolling rather than shrinking/clipping. Close and the two distinct safety/review routes remain reachable.
- VoiceOver reads the exact outcome/totals/gap and each row's participant-associated values, units, weights and expansion state. Voice Control/Switch Control and available hardware-keyboard paths can operate disclosures and dismissal without precise gestures or hover.
- Returning from an existing review/report flow preserves the permitted match and reading context without revealing hidden text or opening images. App-switch protection and foreground authorization are effective; decorative transitions do not delay them.
- Wherever the battle is visible before/after this sheet, the real timer is above complete owner-grouped badge rails and You above Opponent in two LARGE VERTICAL panels. No sheet-driven reduction to thumbnail player cards, missing badges or overlays on body evidence.

## Observable Acceptance — Native macOS

- Native macOS 14+ uses the existing title-bar WindowGroup and an appropriate trailing inspector, not Catalyst/web content. Score details opens for the explicitly selected real result and can be read alongside the large vertical player stage at suitable width.
- At the existing 800 by 600 minimum, laptop sizes, large/full-screen windows and an external display, the surface remains readable and uses the defined single-sheet fallback when measured space is insufficient. No target/minimum-window increase, horizontal body matchup, body crop/warp/favored scale, hidden badge count or fixed-screen-coordinate layout.
- Live resize preserves match selection, expanded row, reading anchor and focus. Inspector/sheet changes settle once after the resize, with no duplicated presentation, repeated modal cycling or award replay. Native divider and independent scrolling do not make host timer/safe actions unreachable.
- Pointer, native focus rings, Tab/Shift-Tab, focused Return/Space, selectable read-only text, Escape and Close work coherently. Reserved commands remain intact and text editing in the report flow is not intercepted. Command-W/Quit retain actual shared active-match consequences where appropriate; force quit is not claimed to be confirmable.
- TCC denial, missing/external/Continuity camera disconnection and a secondary window do not trigger camera acquisition or block authorized historical score reading. Shared live-match handling still stops/shields acquisition immediately and keeps the same service deadline/account owner. No fake feed or rated file-picker fallback.
- Deactivate, minimize, background, move between displays and restore: private visible content is protected, decorative work stops, and the same authorized record returns without a new session, clock reset, judge request, image load or allowance charge.

## Focused Checks and Actual Native Smoke

Run only after prerequisite review and implementation, not during the documentation batch. Use the smallest relevant build/typecheck/test path and fix clear failures within this slice. Do not rerun a user-reported failure just to confirm the report. Tests alone and a compile alone are not proof of the changed native surface.

1. **Real connected read:** on iPhone runtime and native macOS runtime, sign into an authorized staging/account environment and open an already finalized permitted real Physique result from result/history. Observe four accepted pairs, exact totals/gap, recorded policy, native presentation, row expansion, Close and same-result restoration. Confirm through existing service observability that this read-only path does not invoke judging, mutate Elo, consume allowance or load gallery media. Do not add telemetry solely for this check, create a new rated match just to fill the card, or upload real player images without authorization.
2. **Uncertain numeric edges:** use deterministic isolated contract/presentation tests or a clearly labelled nonproduction harness for the 75.5 versus 72.6/72.5 examples, genuine category 0/100, zero gap, locale decimal separators, missing category/policy, contradiction and participant-order mapping. Keep consumer-visible regression coverage for the exact draw boundary and absence-versus-zero where appropriate. Do not add permanent tests that pin UI wording, source text, forwarding, incidental defaults or mock echoes.
3. **Real recovery paths:** exercise same-record refresh failure/offline recovery, permitted saved nonmedia reading, incomplete detail, pending/unscored outcomes, safe explanation removal and an existing correction/review state through the established nonproduction service/harness. Distinguish which scenarios used real service state and which used test-only input. No fixtures enter production or masquerade as a successful judge/service.
4. **Actual safety handoff:** open the existing contextual explanation-report and scoring-review routes, verify target/focus and one-sheet behavior, and cancel safely or submit only an authorized test case. Report only an observed receipt if genuinely submitted. Confirm immediate protection and no image fetch; no invented case or automatic Elo reversal.
5. **Native accessibility:** inspect the actual surface with VoiceOver and native keyboard focus on both available runtimes. Exercise largest supported iPhone text, long/neutral opponent labels, reflow, weights-versus-points announcements, Close/Escape return, Reduce Motion, Reduce Transparency and increased contrast. State separately any Voice Control/Switch Control path not actually exercised; do not call a partial check a full accessibility audit.
6. **Mac lifecycle/resize:** exercise 800 by 600, short/laptop/wide/full-screen sizes, live resize and inspector adaptation, independent scrolling, external-display movement when available, native commands, deactivation/minimization and a second window. Verify no camera acquisition. If a concurrently active camera/session scenario is available, check shared disconnection shielding without changing its deadlines or duplicating ownership; do not fabricate physical-camera proof from a simulator.
7. **Energy/interruption:** observe no looping detail motion, restart/replay, per-frame service/image work or active decorative updates while hidden/minimized/inactive. Exercise available low-power/Reduce Motion conditions, interrupt an expansion with Close/account change/privacy protection, and check that safe state wins immediately. Serious thermal pressure not available in the environment must be named as unexercised, not simulated into a measured claim.

If one platform runtime, real authorized result service or physical external/Continuity-camera hardware is unavailable, first exhaust the available repository/environment path to that prerequisite. Finish reachable work and state exactly what native surface/scenario could not be exercised and why. Never silently substitute a web mock, preview, simulator photo, fake camera or static fixture for that proof, and never call the implementation complete solely because it compiles. Remove throwaway scripts/harnesses after smoke proof; keep only useful isolated regression coverage and explicitly labelled development previews.

## Human Verification Handoff — Required

List separately:

- F29-A-m's real result/history details connection and exact score/unit/boundary behavior.
- Four category disclosures, common evidence and historical judging-policy presentation.
- Native iPhone sheet, reflow, focus and existing safety/review handoff.
- Native Mac inspector/constrained presentation, resize/input/window and camera-independent behavior.
- Saved/offline/error/unscored/review/correction/account/privacy states actually implemented.
- Accessibility, reduced-motion/transparency and energy/interruption behavior actually implemented.
- Every changed source/test/project/documentation file and why it changed.

Ask the user to review the code changes. State that each implemented item is ready for human verification, not human-verified or accepted. Report only exercised checks and name unavailable runtime/service/hardware scenarios, remaining uncertainty and any real blocker precisely. Do not provide a screenshot/log/evidence package as a substitute for a clear code handoff. Put implementation tasks/status only in CYCLES.md. Update the smallest DOCKS.md with an accepted plain-language product decision only after the user accepts the behavior.

## Mandatory Single-Owner Rules

1. **No nested agents.** Do this bounded slice in one owner session. Do not spawn agents, re-run batch orchestration, generate imagery or modify other workers' UI targets.
2. **User direction wins.** Follow the timer/complete-badges/large-vertical-players direction on both platforms. State any remaining contradiction with older docs, do not let it silently produce a horizontal player layout, and do not treat previous numerical proposals as human judge calibration.
3. **Real connected behavior.** No production mock, fabricated peer/score/rating, placeholder screen, no-op report button, fake camera, client Elo, provider-key setting, unapproved provider fallback, or silent local judgement. Preview/test fixtures are labelled and confined to nonproduction.
4. **Respect ownership.** Reuse existing native patterns and reviewed shared contracts. No unrelated navigation/Profile/theme/command rewrite, parallel service layer, compatibility shim, app-wide minimum increase, deployment-target raise or new permission. Keep the current Profile's two-side shape and exercise image privacy intact.
5. **Complete this slice.** Wire actual callers and every specified reachable state/action; exercise the actual native surface, fix clear focused failures, and hand off the full changed path. Do not stop at a compiling component or generate a testing-only follow-up prompt.
6. **Scoped commit and push.** This is the rule for the future implementation session, not the coordinated documentation worker. After a completed functional work slice and focused checks, commit only this owner's authorized edits with a clear message and push to `origin/main`. Preserve others' work, do not force-push or rewrite history, and report an exact commit/push blocker instead of claiming publication.
7. **CYCLES only for implementation status.** Update only the approved relevant implementation todos after connected behavior/focused checks and the human-review handoff. A checkbox means implemented, never human-approved. Do not create IDE task JSON or put todos/evidence in DOCKS.md.
8. **Independent research and honest proof.** Check real API availability for iOS 16/macOS 14 and respect native platform differences. Read only relevant skills/current primary guidance, do not re-run UI Skills setup already completed for the design batch, and do not claim an unavailable skill/model/runtime was used. Existing documentation is not runtime proof.
9. **No unapproved product-document rewrite.** Keep DOCKS.md plain-language and free of code, payloads, project tasks and verification evidence. Capture accepted behavior in the smallest relevant context after human acceptance; don't rewrite docs to disguise an incomplete dependency or failing feature.
10. **No pointless next prompt.** Complete small remaining wiring/fixes/checks now. Create another prompt only if genuinely substantial separately authorized implementation remains; never one only for tests, obvious fixes, CYCLES, a commit or a push.

## When You Finish

Give the complete itemized human-review handoff, changed files, actual focused native checks, any exact missing prerequisite and publication status. Say whether a next prompt was needed. Do not claim all of F29, judge fairness, an App Store outcome or both physical-camera platforms were verified merely because this read-only score surface works.

## Scope Decision Before Finish

State what was implemented and exercised, what remains unresolved, and whether the correct decision is no next prompt, a separately authorized substantial implementation prompt, or a precise external/review prerequisite blocker. Do not turn a routine local failure into an unrelated handoff or invent a completion/verification claim.
