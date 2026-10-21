# F29-A-j — Pose Review and Retake

## Purpose and ownership

This is the selected-still review inside an already active Physique battle. It lets the participant inspect the exact face-obscured still, understand whether that particular selection is merely selected or actually accepted, and replace it within the remaining pose budget and original capture time. It is not a body-score preview, a photo editor, a new gallery, or a separate match.

The [page and match flow](../DOCKS.md) owns the surrounding battle, capture guide, three pose slots, final-set submission, exit confirmation, and stage routing. This child owns the review composition, its actions, and the visible consequences of replacement. [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns evidence meaning, [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns competition authority, [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns safety decisions, and [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns sharing and media lifetime. The shared identity and badge presentation belongs to F29-F, reached through the [F29 feature map](../../DOCKS.md), not to this review.

This document describes a proposed native product surface and its future implementation boundary. It does not describe a shipped view, human-approved prototype, or verified camera/service behavior. Both native iPhone and native macOS are first-class requirements.

## Chosen composition and tradeoffs

Use an in-place review shelf within the large You panel. The exact masked still takes the place of the local camera preview without changing the evidence frame. A compact status shelf sits beneath the image, not over the participant's body. The opponent remains a second large vertical panel below You. No full-screen review modal covers the clock; no side-by-side old/new attempt comparison offers a way to cherry-pick.

This deliberately gives the selected still more space than the earlier parent's small-thumbnail suggestion. The larger image makes the actual mask and required framing inspectable. The cost is vertical scrolling on short devices, not smaller participants, hidden badges, or a separate screen.

A deliberate **Check pose** action follows local masking and inspection. It authorizes transfer of this selected masked candidate for the already-consented protected checks; it is not new legal consent, final-set submission, or an AI score request. The additional tap avoids sending a newly captured candidate before the person has had an opportunity to inspect its exact treatment. Automatic upload on arrival at review is not the chosen behavior.

Retake opens the existing capture guide for the same pose. Opening that guide does not itself discard a good still. Actually acquiring a replacement does invalidate the earlier acceptance, even if the replacement later fails. There is no restore-previous-photo action. This preserves deliberate control without turning retakes into an unlimited archive of alternatives.

## Shared battle hierarchy

Whenever this review is inside the battle composition, the order remains:

1. The real capture timer, visually dominant at the top. It says Time left with stable, large numerals and an accessible seconds unit. Its meaning remains the original shared ninety-second capture deadline, not time spent on this review.
2. Both complete public identity and badge rails, grouped You then Opponent. Handles, optional self-declared country or region flags, truthful Physique placement/tier/streak, and every currently public earned battle badge remain above both participant panels. Rails wrap into additional lines. There is no three-badge limit, hidden extra-count pill, clipping, ticker, or hover-only badge name. Country has a spoken region name and a neutral missing/unsupported treatment; it is neither verified nor inferred.
3. Two large portrait-oriented participant panels, You first and Opponent second, in one scrolling vertical stage. The You panel contains the selected-still review. The Opponent panel contains only the authorized public avatar or neutral silhouette and genuine stage/accepted-count information. A silhouette does not purport to depict the opponent's actual physique.
4. Reachable contextual primary action and the shared Exit, Safety, and Privacy and sharing access. These controls are outside evidence framing. Keeping them reachable must not turn the entire badge rail into an unbounded pinned wall.

The timer and safe action region remain available while the central stage scrolls. At large text or short height, the rails and large panels may extend beyond one viewport. Both participants still exist at their proper size and in their proper order; they are not compressed to fit everything simultaneously. No label, badge, status chip, countdown, or action overlays a face, limb, mask, or other evidence region.

### You panel

The panel has one clear current heading, Review pose, followed by the full pose name and its position among the three required poses. The existing Front, Side, and Rear slot controls sit outside the image and identify each slot's actual selection/check state. Their concise visual labels have full accessible pose names. They may wrap; they do not become a body-thumbnail carousel.

The image is the exact selected, consistently oriented, face-obscured representation intended for the service. It is aspect-fit on a neutral dark matte. Letterboxing is preferable to cropping a limb or enlarging one participant's apparent body. No beauty filter, body reshaping, anatomical highlight, scoring heat map, original-face toggle, mask editing, or save/share action exists here. The live positioning preview may have been mirrored; the review explicitly uses the submitted evidence orientation and never silently reverses a chosen side.

Beneath the image, the review shelf contains a status symbol and word, a short state-specific instruction or private rejection reason, and the remaining retakes for this pose. The exact visible count is 2 retakes left, 1 retake left, or No retakes left when confirmed. If the budget cannot be confirmed, say Retakes unconfirmed instead of granting two new attempts. A small Masked preview label describes treatment, not anonymity or safety approval.

Before Check pose, concise transfer context names the actual service and any disclosed checking processor. It explains that the masked still is sent for checks, while opponent access remains subject to final-result permission. Full recipients, retention, withdrawal consequences, and screenshot limitations remain in the existing Privacy and sharing route; no repeated legal wall or invented processor name is added to the image. Never say Only you can see this after a candidate has been sent to the protected service.

Use the existing near-black background, dark surfaces, white/ivory primary type, Inter hierarchy, and orange primary action. A quiet outline and symbol distinguish status without making green mean a better body or amber mean a losing physique. Accepted uses a checkmark; Needs retake uses a corrective symbol and private plain-language reason. Status is always legible without color. The shelf uses existing spacing, corners, readable-column limits, and native/shared controls, not a second global theme.

## iPhone composition

On iPhone, review stays in the active capture flow rather than pushing another navigation destination. The timer occupies the top safe region; identity/badge rails begin the scrolling stage below it. The large You image is followed by its review shelf and then the equally deliberate Opponent panel. The contextual primary action is reachable in the lower safe action region with a visible secondary Retake when available. Exit and Safety remain reachable without scrolling to the very end. Avoid duplicating the same action as two separately focusable controls in the shelf and bottom region.

Use measured app navigation clearance and existing spacing. Respect the existing forty-four-point primary and safety interaction convention. On a short iPhone, landscape orientation, or the largest accessibility text, the stage scrolls and actions reflow; text is not clamped and people do not shrink into thumbnails. Retake count, rejection explanation, and transfer context can wrap. A physical keyboard, Switch Control, and Voice Control have the same named actions as touch.

Swipe-back, swiping the still, or tapping outside the stage cannot discard a selection, recover an old attempt, or leave an active battle. Opening a native explanation or the existing privacy/safety sheet keeps the same match clock running. A sheet's close action only closes that sheet; leaving the battle uses the shared state-aware exit confirmation.

## Native macOS composition

Use the existing native macOS window, normal title bar, and ordinary toolbar/sheet conventions. This is not Catalyst, a web card, or a phone-shaped modal centered inside a desktop window. The app's existing 800 by 600 minimum remains unchanged.

At that minimum and in a short laptop window, the timer remains at the top of the content, the complete rails and both large portrait panels scroll as one stage, and the contextual action region remains reachable below the stage. The window does not need to show both whole bodies at once. On a tall laptop, large display, full-screen window, or external display, center the same vertical stage within the existing readable-column conventions and use the extra height for more visible content. Increasing width never turns the players or their evidence into left/right rivals. Do not widen a body beyond its normal aspect ratio to fill a display.

Toolbar access exposes Exit, Safety, and Privacy and sharing using native controls with text or discoverable accessible labels. The exact review status, retake budget, and correction reason stay inline below the You image, not hidden in a hover tooltip or an inspector. Secondary explanations can use existing native disclosures or a native popover. This child requires no new custom inspector or extra review window. Pointer hover may show normal control feedback, never an animated body or badge wall.

Live resize preserves the reviewed pose, selected candidate, actual status, remaining retakes, focus, and a sensible scroll anchor. Layout changes must not capture a new image, recreate the match, replay acceptance, or restart checking. Moving the window between displays preserves evidence aspect ratio and authority. No new app-wide minimum, display-specific capture crop, or dedicated full-screen camera session is introduced by review.

Mac camera/TCC denial, restricted access, a busy device, and external or Continuity Camera disconnection have distinct honest explanations. A valid masked still already selected can remain reviewable under current authorization; camera loss alone is not permission to erase it or fabricate a rejection. Retake acquisition is unavailable until the existing capture owner recovers a permitted live camera. An acquired and accepted set does not require keeping a camera running merely to inspect or submit it. No automatic camera substitution, rated file picker, prerecorded fallback, or new TCC prompt loop is allowed. An intentional camera change after Go follows the parent's discard-set rule, with the original clock and spent retakes unchanged.

Only the owning active-match window/device may acquire or replace evidence. A second window is a status/resume surface for the same real match, not another camera owner, another budget, or another allowance charge. Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their existing app meanings. Return and Space activate only the focused semantic control, never a globally armed retake or shutter while someone types elsewhere.

Cmd-W or Quit while an eligible active match remains uses the shared real-consequence confirmation where the platform permits. Escape first closes the current popover/sheet, cancels an unexposed retake/self-timer, or invokes the battle exit confirmation when already at the root review. Escape never directly confirms forfeiture. Force quit, process termination, and hardware loss cannot be prevented or treated as a user-confirmed forfeit.

Inactive, minimized, hidden, backgrounded, or locked review immediately shields private evidence and stops any acquisition owned by the capture flow. Returning restores the same service state before revealing media or offering an explicit resume. It does not auto-open a prior media view, take another still, replenish retakes, or reset a deadline.

## Actual states and visible actions

The four named review statuses describe one selected candidate, not overall match progress. Operational states below qualify them without inventing additional successful evidence.

| State | Visible presentation | Actions and consequences |
| --- | --- | --- |
| No selected still for the opened slot | Neutral evidence-sized placeholder, named pose, Capture pose | Return to the existing live guide; no invented image or Selected claim |
| Preparing a private preview | Neutral frame and Preparing preview | Masking happens locally; Check pose is unavailable until the exact safe representation exists; Exit remains available |
| Selected, not sent | Exact masked still, Selected, Not sent, confirmed retakes | Check pose sends only this candidate for protected checks; Retake starts same-pose acquisition; changing slots preserves this selection without uploading it |
| Selected, transferring | Exact masked still and real transfer state beneath Selected | Show Sending, actual byte progress only if provided, or receipt unconfirmed as appropriate; suppress repeat sending; Next pose is available when another pose remains |
| Checking | Exact masked still, Checking, native activity indicator, no invented percentage | Service receipt/check state must be real; Next pose can return to another capture while checks continue; Retake remains available within the same budget/time |
| Accepted | Current candidate's exact still, Accepted, checkmark, actual retakes | Next pose advances to the next missing required pose; when all required current candidates are accepted and the service permits locking, the existing Submit poses action becomes primary |
| Needs retake, recoverable | Current safe masked still or a protected placeholder, Needs retake, one practical private reason | Retake is primary while time, authorization, and budget permit; other slots remain inspectable; no comparative body feedback appears |
| Needs retake, no attempts remaining | No retakes left and Cannot complete this pose | No third replacement, old-image restore, forced top removal, or local win/loss; obtain the service's no-contest resolution through the existing battle shell |
| Redaction cannot complete safely | Privacy placeholder, Needs retake, Face masking failed | Do not show an unmasked frozen original as a fallback and do not transmit it; allow a remaining safe retake or the shared exit route |
| Bystander, coverage, blur, framing, or evidence failure | Pose-specific private correction with no enlarged violating crop | Examples include Capture alone, Include your arms and legs, or Use ordinary lighting; never request prohibited exposure or infer age, sex, gender, health, or misconduct from appearance |
| Ambiguous clothing/safety rejection | Needs retake with restrained practical wording and Review decision access | Existing F29-D false-positive review route uses the existing candidate reference, not an unmasked proof upload; the capture deadline and acceptance do not change while a case is opened |
| Service/checking failure | Checks unavailable or a genuine retryable transfer reason | A transport retry reuses the same selected candidate and consumes no retake; required service unavailability follows the service no-contest rule rather than becoming a body rejection |
| Late rejection of a different pose | That named slot changes to Needs retake; current work stays in place | Announce the affected pose once; direct the next available capture action toward that slot without stealing the current shutter or discarding another selection |
| All three selected, some not accepted | Honest selected and accepted counts, affected slots, no success treatment | Locally unsent selections expose Check pose when opened; pending checks remain pending; Submit poses is unavailable until the real shared submission conditions are met |
| Final-set submission pending | Existing submitting/receipt-unconfirmed state with current stills locked against edits | Repeated taps, reopening review, and reconnecting cannot submit another set or unlock changes on a guessed failure |
| Set locked by service | Accepted evidence remains read-only and marked Submitted by the host | No voluntary retake; only a service-requested specific recoverable recapture within the original time and remaining budget can reopen an affected slot before paired judgement |
| Retake guide opened, no replacement acquired | Existing capture guide for this pose, remaining count and replacement consequence | Back to review or cancelling a self-timer preserves the old selected still and its acceptance; merely opening the camera spends nothing |
| Replacement acquired | New candidate replaces the selection; old Accepted is removed immediately | The previous acceptance and accepted count are invalidated; the new safe preview begins as Selected, or Needs retake if local privacy processing fails; no old accepted image can return |
| Offline, connection interrupted, or restoring | Privacy-safe paused surface, last confirmed information labeled, real recovery status | Stop acquisition; reconcile the same match/candidate/budget before enabling edits or submission; an unknown receipt is not a rejection or proof of no upload |
| Camera unavailable during review | Exact authorized still may remain, with a separate camera explanation | Reading/checking an eligible existing still is distinct from acquiring a replacement; offer only the capture owner's genuine recovery action |
| Deadline reached | Zero or Capture ended in the shared timer, no newly available capture action | Disable new acquisition/replacement and defer subsequent waiting or no-contest stage to the service; never turn a local timer into an invented terminal result |
| Consent withdrawn, account switched, signed out, safety removal, or match ended | Immediate safe cover or authorized host destination | Stop affected capture/transfers, remove unauthorized media, cancel unsafe pending presentation, and reconcile the real consequence; do not wait for an animation |

The ordinary primary is Check pose before this candidate is sent, Next pose when another required pose can be captured, Retake when the current candidate needs correction, or the host's Submit poses when the current complete set is actually eligible. With no actionable next step, keep a truthful pending state and enabled safe controls instead of a fake Continue button. Transport Retry appears only after a real recoverable failure. A request for a false-positive review neither accepts a pose nor promises that a human will respond inside capture time.

## Retake and acceptance rules

Each pose starts with its initial capture and at most two replacements. The visible remaining count is per pose, not a shared account balance. One pose's replacement cannot replenish another pose. Reopening the view, changing a slot, switching devices, cancelling the guide, or returning from privacy details cannot reset it.

Opening Retake announces Replaces this pose. It does not spend a replacement or remove the previous Accepted mark yet. The existing capture guide provides the deliberate shutter/self-timer action. A new successfully acquired replacement consumes one permitted replacement even if its mask, upload, or protected checks subsequently fail. A cancelled timer or camera failure that produces no new still consumes no new replacement. If acquisition or service receipt is uncertain, show a confirming state and prohibit another acquisition until the real budget is reconciled; do not invent either a spent attempt or a free one.

On actual replacement, earlier acceptance is no longer usable. The current accepted count decreases where appropriate, the service must recognize the new selection, and submission stays unavailable while that change is unresolved. A late Accepted response for the superseded image cannot approve the replacement, restore the old image, or increment accepted progress. Responses for another pose cannot update the open pose by position alone. Only the currently selected candidate can become Accepted.

No earlier still remains as a selectable alternate. Dispose of superseded local material and protected service candidates according to F29-E; an in-progress check may already have received an old redacted candidate, so replacement must not falsely claim that it was never shared or immediately erased everywhere. Existing lawful case handling is the only applicable exception, not a hidden attempt gallery.

Two replacements already used means No retakes left. An Accepted last attempt can continue normally. An invalid last attempt does not become a scored loss, a zero body score, or an incentive to change prohibited coverage. The trusted service determines the no-contest and any allowance restoration. Until acknowledgement, show actual resolution/refresh state rather than claiming that Elo or allowance has changed.

The clock remains live during masking, inspection, sending, checking, native sheets, review requests, retake preparation, and correction. The twenty-second reconnect grace extends neither capture time nor the later judgement deadline. A response arriving near zero is applied only if the service still authorizes the same stage and candidate. This view cannot reopen a finalized match, resurrect a late verdict, or perform a new judgement.

## Privacy and service authority

The camera is not kept acquiring while a frozen still is reviewed. It stops promptly after capture, and review shows Camera off only when that is the actual device state. Resuming the live guide is an explicit action through its sole owner. No microphone, Photos read permission, location, continuous recording, or opponent stream is introduced.

Check pose uses only the exact locally face-obscured candidate after existing required consent. Never transmit an unmasked original, a UI screenshot containing country/badges, a rejected bystander image as a valid participant, profile metadata, or identity/rating information to the physique judge. Badge/country chrome is presentation only. Local cosmetic badge previews and automatic public profile-photo upload are not sources of trusted competitive identity.

Selected means chosen locally; Checking means a real protected service check is underway; Accepted means that current candidate passed the required checks; Needs retake means it is not currently eligible. Neither Accepted nor a successful upload means a winner, identity verification, permission for immediate opponent display, or a final set lock. Capture adequacy and moderation are not scores.

The opponent receives only authorized identity and real stage/count information. No current selection, rejected image, candidate thumbnail, private rejection reason, retake photograph, or live appearance score appears in their panel. Later opponent-still access belongs to the intentional final-result gallery and only a valid judged win, loss, or draw under current permission; forfeits and no-contests have no counterpart gallery. The ordinary twenty-four-hour media lifetime is not restarted by review, replacement, reopening, or a case draft.

An explicit eligible Forfeit and leave remains distinct from technical interruption and service-established invalid/safety/service-failed no-contest. Report or Block after Go protects immediately but does not itself leave, rerate, pause the clock, or produce a free win. Withdrawing only opponent-image access is not automatically a forfeit. Processing withdrawal stops affected new capture/transfers immediately and follows F29-E's real stage consequences. A local warning, outage, or missing acknowledgement is never authority to award a result.

## Focus and accessibility

On entering a newly selected review, accessibility focus moves once to the current pose/status summary, for example Front double-biceps, Selected, 2 retakes left. Do not focus or repeatedly announce the still itself, its private visual anatomy, the rotating progress indicator, or every changing second. The image's accessible description identifies the selected pose, masked treatment, and current evidence state, not a body evaluation.

Reading order follows timer, grouped identity/badge rails, You/current review, pose slots, status/recovery actions, then Opponent. Persistent action controls remain reachable once in traversal even when visually anchored. Badge groups can be navigated past as groups without omitting individual public badges. Provide meaningful headings and native button traits, explicit disabled reasons, stable Voice Control names, and full pose labels rather than unexplained checkmarks.

Accepted is announced once for the relevant pose without stealing focus. A rejection of the open pose is announced with its concise corrective reason; a rejection of another pose names that slot without interrupting current capture. Focus moves to a corrective instruction only when the active control has become unusable and a safe replacement is necessary. Closing a sheet or cancelling an unexposed retake restores focus to its invoking control or that pose's safe successor. Removing unauthorized media puts focus on the safe placeholder or host heading, never on a now-hidden image.

The clock can be read on demand. A single ten-seconds-remaining milestone and capture-ended announcement may supplement the visible timer; never speak each tick or replay a missed threshold after returning. Text, icons, and optional haptics convey the same changes. No sound, color, hover, long press, or precision gesture is required. Optional capture sounds are output-only, never a microphone request.

On Mac, Tab and Shift-Tab follow semantic controls and system keyboard-navigation preferences; the scroll region and offscreen slots are reachable. Return/Space act only on the focused control. During native text entry in a report/privacy route, typing cannot trigger a shutter, replacement, check, or submission. Default destructive actions are never armed by focus on an image. Dynamic Type, larger system text, Increase Contrast, Reduce Transparency, VoiceOver, Voice Control, and Switch Control preserve the complete state and consequences.

## Animation and interruption rules

The chosen feel is a brief freeze-and-seat of the review controls, followed by tactile status changes. Evidence itself never flexes, zooms, pulses, flips, or receives a scanning shader. There is no new ambient loop in review; the meaningful event is the current selection/check result, not a decorative contest celebration.

| Trigger | Visible motion and timing | Interruption and reduced behavior |
| --- | --- | --- |
| A safe selected preview becomes available | Keep the evidence frame stationary; reveal the masked still from its privacy matte in 160 milliseconds. The control shelf seats beneath it over 280 milliseconds with a short decelerating movement bounded by existing control spacing | The image is available and controls work immediately; no minimum review duration. Reduce Motion replaces travel with at most 120 milliseconds of opacity |
| A review control is pressed | Existing shared press response: spring response 0.24 seconds, damping fraction 0.88; no extra image movement | Release invokes at most one valid action. Reduce Motion uses existing non-scaling press feedback |
| The current status changes | Symbol and concise text change within 180 milliseconds; current candidate identity and factual status update immediately | Newer real state interrupts the old transition. Reduce Motion uses a short opacity change or immediate replacement |
| Current candidate becomes Accepted | A single small checkmark settle, at most about 1.04 scale, finishes within 180 milliseconds; the accepted slot mark changes once | This is evidence acceptance, not a win/badge unlock. No confetti, body glow, score, or replay on reopening; Reduce Motion removes scale |
| The person changes the inspected pose | The slot's active mark moves in 180 milliseconds; another authorized masked still replaces content within the same stationary evidence frame in 160 milliseconds | Preserve slot identity and focus; no carousel of discarded attempts. Reduce Motion changes the marker/still without travel |
| Retake returns to the existing live guide | Control continuity settles within 280 milliseconds while the frame remains in place; live imagery appears only after explicit permitted camera resume | Capture can stop immediately. Cancelling before exposure returns the same old selection. Reduce Motion uses an immediate guide replacement or short opacity |
| An actual replacement invalidates acceptance | Remove the old check/accepted eligibility immediately; the displayed remaining budget updates within 180 milliseconds after confirmation | No animation may leave Submit usable for the old image. A failed replacement never animates the old check back into existence |
| The real timer advances | Stable-width numerals change in about 180 milliseconds, at most once per actual second | No bounce, urgency flash, ticking haptics, or review-local clock. Reduce Motion uses immediate digits; missed seconds are not replayed |
| Checking is actually in progress | Native indeterminate indicator only, visible while that state is present and the surface is active | It is not analysis progress or a predicted end time. Use static Checking text when repeating motion is reduced or unnecessary |
| Privacy changes, camera stops, media is hidden, or a terminal state supersedes review | Protect/stop immediately, with no decorative delay | Cancel pending presentation and discard delayed haptics/animation completions. Reduced settings do not weaken protection |

At most one focal event is emphasized; the clock remains quiet and the badge wall stays still. No transition blocks Safety, Exit, a real correction, or incoming finality. Offscreen/background acceptance does not queue a later celebration. Returning or restoring history shows current facts without replaying a new award.

Pause decorative work when offscreen, inactive, minimized, hidden, or backgrounded. Under Low Power Mode or constrained thermal conditions, remove checkmark scale and shelf travel, keep static status plus brief opacity, and avoid decorative repetition. Authoritative clocks and necessary authorized service reconciliation continue according to lifecycle rules; this is not a promise of background acquisition or background image transfer. No per-frame service polling, image decoding, provider work, font measurement, camera reconstruction, or whole-stage layout invalidation belongs to timer/status motion. Reuse the already prepared exact preview until the candidate actually changes. Reduce Transparency uses opaque readable surfaces rather than transparent text over evidence.

## Dependencies and integration boundaries

The real account/consent foundation, protected candidate intake, local masking, camera owner, authoritative candidate replacement/acceptance, deadline/budget recovery, and shared battle shell must be implemented and human-reviewed before this view can be offered as a functioning rated review. A static preview does not satisfy those dependencies. The three-pose guide and final-set action remain with the parent; this child must not start another camera controller or duplicate their state.

The trusted contract must distinguish the current candidate from superseded candidates, confirmed retakes from uncertain requests, and transfer receipt from check acceptance. These are necessary product guarantees, not permission to infer a backend from local timers. The view cannot independently ship a real competition while these guarantees, operational moderation, or authorized service/model access are missing.

The new vertical native composition supersedes the earlier parent's optional desktop two-column battle and small review-thumbnail suggestions for this surface. The new event motion refines the earlier fade-only targets without changing service timing. It does not change attire, the common-region rubric, Elo, allowance, deadline, or consent policy. Numerical judging defaults elsewhere remain proposals subject to their own review.

## Files

The locations below identify ownership; prospective source does not imply that a file or service exists.

- This DOCKS.md owns the product behavior of F29-A-j.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-j-phase-1-pose-review.md) owns the scoped engineering handoff, not product completion status.
- Prospective TimeMaster/Views/Physique/PhysiquePoseReviewView.swift owns the in-place selected-still shelf and its platform-native adaptations.
- The connected battle/capture host under TimeMaster/Views/Physique/ owns the live timer, all badge rails, vertical player panels, pose navigation, final-set submission, lifecycle, and existing safety/exit routes. Adopt its integrated file names rather than adding a competing host.
- Prospective TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift supply current authoritative evidence/status/budget and privacy-safe local capture presentation; they are shared dependencies, not an invitation to implement an alternate local judge.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own existing palette, typography, spacing, surfaces, accessibility fallback, and press feedback.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) own native windows and commands; review consumes those conventions without changing their scope.

## References

- [F29 parent](../../DOCKS.md), [F29-A](../DOCKS.md), [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D](../../F29-D-safety-and-reporting/DOCKS.md), and [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) are the real product and authority boundaries.
- [Supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy/directness reference only. Borrow the dominant timer and immediate sports presence, not its side-by-side arrangement, purple/brown web pills, text, people's likenesses, or footage. No asset rights are implied and no artwork is generated by this specification.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supplies nearby shared action and earned-Elo visual language; its Dynamic Type clamps are not adopted. [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) supplies exercise-HUD context only, not permission for physique provisional scores or lead bars.
- [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift) distinguishes editable local badge previews from trusted competitive achievements and identity verification.
- [Apple: Designing for macOS — Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) supports resizable, native, keyboard/pointer-capable, low-modality presentation. The vertical stage is the user's chosen composition, not a claim that Apple requires vertical opponents.
- [Apple: Motion — Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion) supports purposeful, brief, optional, interruptible feedback. The exact shelf/check timings here are product proposals, not Apple-prescribed values.
- Installed swiftui-pro accessibility/performance guidance, swiftui-animation guidance, apple-hig-reference, and [Dimillian's SwiftUI UI Patterns](https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns), particularly asynchronous state ownership, inform native composition and stale-candidate handling. Maintain native macOS 14 and the project's iPhone compatibility; do not raise deployment targets or require newer-only motion/glass APIs for this view.
