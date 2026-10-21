# F29-A-n — Pose Gallery

## Purpose and Scope

An intentional, private view of the six moderated selected stills behind one valid AI-judged Physique win, loss, or draw. The gallery presents the same pose for both participants, with You above Opponent on native iPhone and native macOS. It is result evidence, not a live matchup, body-photo feed, second judging attempt, or image-export feature.

This document specifies a future native surface. It does not claim an implementation, accepted prototype, operating media service, or human approval. The user's newer direction requires vertical participants at every width and all public battle badges above the media. Earlier options in the [page-flow parent](../DOCKS.md) for wide side-by-side comparison and image expansion do not apply to this gallery. There is no separate enlarged-image destination.

The gallery owns pose selection, evidence presentation, per-image protective actions, expiry feedback, and safe return to its originating result. It reuses shared result navigation, identity and badge components, private-media access, report forms, privacy controls, and safety routes. It does not own a replacement safety center, profile, result scoreboard, camera, or export composer.

## Chosen Composition and Tradeoffs

The composition is a paired pose reel rather than a six-image grid. A single Front, Side, or Rear choice changes both participant panels together. The relationship is unambiguous without reducing people to thumbnails or requiring someone to open a suspect image to find its controls. The tradeoff is vertical scrolling; seeing two complete, useful images takes precedence over fitting both into one short viewport.

The top visual anchor is the real remaining ordinary media-access window, labelled Expires in. It is not the completed match's capture timer, a replay of Go, or a fabricated judging countdown. Immediately below it, the scrolling stage starts with the complete You identity/badge rail and complete Opponent identity/badge rail. Both rails precede both evidence panels. The upper large panel is always You; the lower large panel is always Opponent. Their order never follows the winner, score, country, selected pose, or window width.

Each panel has its participant-and-pose caption and persistent Hide and Report actions outside the image. No name, flag, badge, timer, score, button, watermark, winner ribbon, or translucent control sits over evidence. Shared opaque dark surfaces frame the originals without a camera HUD or decorative scan. Orange identifies an action or selected pose, not a supposedly superior body.

A synchronized, text-labelled pose selector remains reachable while the stage scrolls. There are no pose thumbnails, auto-advance, swiping of individual players, pinch zoom, double-tap enlargement, Quick Look, or image-specific full screen. Native app-window full screen remains available on Mac and retains the whole vertical composition.

## Visual Language and Hierarchy

Use the existing near-black background, dark elevated surfaces, white primary text, readable secondary ink, Inter Black hierarchy, Inter Regular supporting text, shared spacing, shared card treatment, and orange action styles. Reuse Theme and ProfileDesign rather than establishing a second palette, font registration path, or global sizing system. Evidence wells are opaque and neutral; glass may belong to existing native control chrome, never to a layer over the body.

The visible heading is Poses. The default supporting text is limited to the selected pose and the expiry label. Essential privacy and recovery copy is not removed to achieve minimal text. A native information action provides the exact expiry date and time, the participant-only audience, the ordinary twenty-four-hour window measured from finalization, the screenshot limitation, and a link to the existing Privacy and sharing route. A report hold can preserve narrowly authorized case evidence but does not extend this participant viewer.

### Identity and all public badges

Reuse the canonical F29-F battle identity and badge rail. Owner labels, permitted handle, optional permitted avatar, manually chosen country or region flag, Physique rating/placement context, and every currently authorized public battle badge remain outside the media. Use a neutral permitted identity glyph when no avatar is available; never upload or expose a local profile photograph merely to fill the rail.

The country flag sits beside the handle and has the accessible country or region name. Missing or unsupported country uses the shared neutral state, without inferring location or indicating verification. Country, badge artwork, rating chrome, and the gallery itself never enter judging inputs.

Show every earned launch badge: First Bell, Placed, Ten Rounds, and Three Straight when actually awarded, together with the truthful permitted tier and current streak supplied by F29-F. Placed and tier may be composed to avoid redundant captions. The shared catalog determines order and meanings; this gallery does not invent another ordering or achievement calculation. Wrap onto as many readable rows as necessary. No three-badge cap, hidden +N, clipped last row, horizontal ticker, paid advantage, cosmetic-preview migration, or hover-only explanation is allowed.

Historical match Elo remains explicitly match-time context. Current tier, streak, or badge state must not masquerade as match-time evidence; retain F29-F's temporal labels and detail explanation. A historical milestone is not labelled as an ongoing streak. Reopening a result does not award a badge again. Confirmed corrections can remove an entitlement or placement state; the next authorized rail reflects the correction without inventing a new competitive event.

If badge status alone is unknown, say Badges unavailable in the rail and keep permitted evidence usable when its separate authorization is valid. An explicitly labelled last-confirmed badge set is allowed only if shared identity policy still authorizes displaying it. Unknown is not an unearned badge and is not proof that the participant has none. A block, deleted identity, or revoked visibility replaces identity and badges with the appropriate neutral state rather than preserving a stale public rail.

## Native iPhone Composition

Open from the result's explicit View poses action as a large, full-height native sheet in the existing Physique presentation hierarchy. Do not auto-open on finalization, relaunch, a history-row tap, or a notification. The sheet's compact navigation bar contains Poses, a clearly named Close action, and Safety. Its leading visual content is the large, stable-width expiry readout beneath that bar.

The timer and top safe actions stay available. The central content scrolls vertically in this order: both complete identity/badge rails, the You panel, then the Opponent panel. Badge rails scroll with the stage rather than becoming an indefinitely pinned wall. At large Dynamic Type or on a short display, they may occupy more than one viewport; none is suppressed and the people are not shrunk into stamps to make them fit.

A bottom safe-area control contains the three native segmented pose choices Front, Side, and Rear. Their accessible names are Front double-biceps, Side physique, and Rear double-biceps, including the selected position out of three. When long localized labels or large type cannot fit, the same three labelled choices reflow as a vertical group in the reachable control region; that region may scroll rather than squeeze text or cover the stage. Only one pose is selected. A selected mark and label accompany orange. No horizontal gesture is required, so scrolling a tall body or the app's existing navigation cannot accidentally change poses.

Both evidence wells span the same available readable column. Use an equal portrait three-to-four presentation well for the pair, calculated from available width rather than screen coordinates. Each accepted original is aspect-fit inside it with neutral letterboxing where necessary. This well is a presentation frame, not a crop or an instruction to change capture output. Tall and landscape originals remain complete. The result does not normalize apparent body height, magnify a smaller person, or suggest that pixels measure muscularity. The whole media rectangle, including background edges, remains inside the well; rounded card framing must not clip image corners or limbs.

The participant-and-pose caption and Hide and Report row sit immediately above their own well. At large text they wrap into readable lines. The action row is not an overlay, long-press secret, or extra enlargement step. Primary and safety targets follow the existing forty-four-point iPhone convention with separation sufficient to avoid accidental reports. The image itself is inert. Scroll to the second participant rather than replacing the pair with a single-player viewer.

Closing returns to the same result, scroll position, and invoking View poses control. Because this is already a final result, ordinary close or sheet dismissal does not show a forfeiture warning, consume allowance, or rejudge. Meaningful unsent report text follows the shared draft-discard confirmation before it can be lost.

## Native macOS Composition

Use the existing native macOS fourteen-or-later application window and normal title bar, not Catalyst, a web viewer, a new standalone image window, or a stretched phone sheet. The result's View poses opens the gallery as a destination in that window. Its standard toolbar contains Back to result, the labelled Front/Side/Rear segmented selection, Safety, and the existing information/privacy action. Button density and focus use native Mac conventions rather than mandatory phone-size chrome.

The expiry readout remains the prominent content anchor directly below the toolbar. The centered scrolling stage contains both complete identity/badge rails, then You and Opponent in one large vertical column. Reuse the app's readable-width convention and shared spacing; do not grow the body evidence across an entire external monitor. Large laptop, full-screen, and external-display windows provide surrounding breathing space and more uninterrupted vertical content, never a side-by-side matchup. The gallery does not need a new inspector: exact expiry/privacy information uses the existing native information presentation, and report details use the shared safety sheet.

The existing eight-hundred-by-six-hundred minimum remains unchanged. In that short window, the timer and toolbar are usable while both rails and full-size panels scroll. Enlarged accessibility text may move secondary toolbar items into the platform's standard overflow, with labelled commands still reachable; pose selection and Back to result remain accessible. Do not reduce evidence to two tiny cards to avoid scrolling. Native full screen preserves title-bar behavior and the same content order.

Live resizing refits complete originals within equal wells and reflows badges without animated body stretching, forced scrolling, a second evidence download for every size, or focus loss. A move to another display or a backing-scale change affects presentation resolution only; it does not change the accepted image, owner, expiry, or original orientation. Trackpad and wheel scrolling move the stage. Pointer hover can supply native help and a restrained shared control emphasis, but never enlarges evidence or reveals a hidden badge.

The gallery never starts a camera, requests TCC, keeps an earlier capture running, reads from an external or Continuity Camera, or asks for microphone or Photos access. Camera denial, revoked camera permission, an absent camera, and external/Continuity disconnection cannot replace authorized finalized images with a fake feed or prevent reading an otherwise permitted result. If reached from a real active-capture owner elsewhere, shared session ownership remains there; this destination cannot start another active match or allowance charge.

Escape dismisses the topmost menu or native information presentation first. In a report sheet it follows that sheet's meaningful-draft protection; otherwise it returns from the finalized gallery to the result. Command-W retains normal window behavior without a fictitious gallery forfeit. Quitting or closing an actual active-match owner elsewhere still uses the shared state-aware match-consequence handling where the platform permits. Force quit cannot be prevented or represented as an explicitly confirmed voluntary forfeit.

## Entry, Authorization, and Pose Navigation

View poses is available only through a valid, service-finalized AI-judged win, loss, or draw for the signed-in participant with applicable adult eligibility and current authorized media access. All six selected images must have passed the required capture, evidence, and moderation checks before the match can originally qualify. Later removal of one image is a per-item availability change, not permission to substitute a retake or revise the verdict locally.

Neither a forfeit nor a no-contest has this gallery, even if candidates reached the service. Pairing, countdown, capture, upload, judging, an unconfirmed result, a model response, and a pending correction cannot unlock early counterpart media. Notifications and external links lead to the authenticated result and require a new intentional View poses action, not directly to a body image.

On deliberate entry, check the current account, match relationship, effective result, owner-specific sharing, safety/block state, and expiry before revealing any still. An old link, loaded thumbnail, local original, another window, or prior approval is not a substitute. Display safe wells and a real activity indicator while checking; no blurred body skeleton, approximate progress percentage, or revealing last-frame preview appears.

The first authorized open selects Front. Changing the pose updates the selected label and both panel identities together. Old-pose images are removed before a new pose label can describe them. Each new well then resolves independently to an authorized original or a precise placeholder. One slow or unavailable image does not replace its counterpart or make Front face Side. Pose selection never triggers another judgement, moderation resubmission, match, allowance reservation, or competitive update.

Keep the chosen pose and safe scroll context during ordinary navigation or recoverable access checks within the same open gallery. Selection of a different pose returns the pair to the start of the evidence region, after the rails, rather than leaving the user halfway through the previous Opponent image. Keep focus on the selector and announce the new pose once. Do not replay the full badge-rail entry animation or force the user to scroll past all badges on every pose change. A native, labelled route back to the identity rails remains available through normal scrolling; all rails stay in document order above both players.

Rapid pose changes display only the latest requested pose for the same account, match, and accepted media version. A late completion for an old pose, removed image, closed window, expired session, or switched account cannot paint an image into a newer selection. Hide and Report target the specific participant, pose, and accepted image that their caption named, not whichever pose happens to be selected when a request completes.

## Image Fidelity and Privacy Boundaries

Display the original accepted, locally face-obscured evidence, in the same orientation that was judged, with only uniform display scaling and necessary view-resolution decoding. Original here never means the unmasked camera original. Do not mirror one side, crop bodies to equal heights, stretch, retouch, reconstruct anatomy, undo face masking, apply an appearance filter, sharpen a participant selectively, add anatomical boxes, or paint an AI score onto a body. Decoding failure is unavailable media, not permission to generate an illustration of the submitted body.

No gallery control exports any pose, including one's own. No Save, Share opponent, Copy image, Copy link, Print, drag-out, Quick Look, image Services handoff, or Photos action appears in the media or its context menu. A context menu may duplicate Hide and Report but cannot be their only access. The separate result owner's optional own-result card remains outside this gallery and receives no gallery image, opponent identity, signed media link, or screenshot of the paired composition.

Face obscuring does not promise anonymity. Authorized viewers may make operating-system screenshots or external recordings; the app must not claim copy-proof display or remote deletion of someone else's copy. Privacy and misuse-report routes remain available without asking the person to save, forward, screenshot, email, or reupload suspected unlawful imagery.

The gallery requests no extra capture, file-picker input, model call, or sensitive analytics. Body stills, image-bearing screen replay, private report text, authorization links, and evidence copies do not enter routine logs or crash reports. App-switcher snapshots and inactive/background surfaces are shielded immediately. Gallery images are not an offline photo collection or a long-lived local archive.

## Per-Image Actions and Recovery

### Hide

Hide image immediately replaces that still with an opaque neutral well labelled Hidden by you, before any animation or service acknowledgement. The other participant's corresponding still remains independently governed. Hiding does not file a report, delete the image owner's data, change an outcome, revoke the owner's sharing, or alter Elo.

Maintain the local hide if the service is unavailable, with Hide sync pending where needed. Do not claim another signed-in device has updated until the service confirms. View again reverses only a viewer-owned hide after a fresh successful access check. It cannot bypass a received report restriction, moderation hold, block, expiry, owner withdrawal, deletion, lost eligibility, or failed authorization. Retry sync never reveals the image. Focus moves to the safe replacement well and its available actions.

### Report

Report image is available beside every selected still and from its safe placeholder without enlargement. Opening the shared contextual report form hides that image immediately. Identify it using safe match, participant, and pose context; never copy a thumbnail into the form. Cancelling an unsent form leaves the image hidden, with no false received-report label.

Reuse F29-D's categories, optional persistent-labelled note, retention explanation, independent Block option, and existing case receipt flow. A report of one's own still keeps that ownership clear and routes the relevant privacy or processing concern rather than accusing the opponent of submitting it. Scoring disagreement uses the separate existing result-review route, not a newly invented gallery vote or reroll.

Editing, missing category, sending, Not sent, Not confirmed, Received, duplicate, and intake-unavailable states reflect actual service state. Only confirmed receipt becomes Reported and links to the real private case. A failed or offline submission retains local hiding and the permitted protected text-only draft, with explicit Retry and published support access; it is not a case or an image-preservation promise. Unsent drafts last at most twenty-four hours and clear earlier on discard or sign-out. Ambiguous receipt resolves the same submission rather than making another apparent case.

A received report may preserve only necessary lawful evidence under the shared bounded policy; its ordinary maximum thirty-day hold does not lengthen the twenty-four-hour participant gallery. At expiry during report editing, remove imagery immediately, retain allowed safe text and target reference, and explain that deleted imagery cannot be recovered for the report. No receipt or case update auto-dismisses before it can be read. Report withdrawal or an appeal does not silently unhide the image or restore access.

### Block and privacy routes

Safety exposes the existing Block player action and Privacy and sharing route. In a finalized match, block immediately shields the pair's entire gallery and relevant opponent identity locally; confirmed service policy removes gallery access between the accounts and excludes future pairings. Neither the loss nor its earned rating is erased. If offline, say Block not confirmed and retain local shielding, without claiming remote exclusion is already complete. Unblock belongs to Safety and never auto-reopens these stills.

The image owner's withdrawal revokes access to that owner's stills, including previously issued links. It does not automatically delete the counterpart's independently authorized images or change the valid record. The result keeps separate unavailable wells when only one owner withdraws. A whole-pair block takes precedence over any individual View again. Removing one's own shared images uses the existing privacy action and confirmation, not Hide opponent image. Reconsent does not restore removed old photos or restart expiry.

## States and Access Precedence

The following states apply to both native platforms. Wells retain stable participant/pose context when that context remains permitted. No unavailable state shows a sensitive last frame under a blur, tint, progress overlay, or disabled button.

| State | Visible surface and permitted recovery | Media and record consequence |
| --- | --- | --- |
| Result not yet final, forfeit, or no-contest | No View poses entry. A stale route uses a safe Poses unavailable for this result message with Back to result and existing safety access | No gallery, early thumbnail, candidate display, or invented scores |
| Signed out, account switched, or relationship unauthorized | Protected surface removed; conventional account recovery or Back to result as appropriate. Unauthorized targets use a generic unavailable message without revealing private match membership | Clear former account images, private identity, and unsent drafts; successful sign-in does not auto-reopen images |
| Adult access or account capability missing/restricted | Private access-unavailable explanation and existing account/Safety route | No photo-based age check, public accusation, or media bypass |
| Checking current access | Neutral empty wells and honest activity/status; Close and Safety remain usable | No cached opponent reveal while authorization is unknown |
| Gallery authorized | Real expiry, all permitted public badges, selected matched pose, large vertical originals and external actions | Same finalized evidence; no new competitive side effect |
| One image loading | Only that well says Loading image; counterpart may appear if independently authorized | Never borrow another pose or a retake as a preview |
| Transfer failed or image cannot decode | Image unavailable and Retry image for a recoverable item; preserve the permitted counterpart | Retry rechecks access to the same selected still, not judging or substitute upload |
| Media expected but missing | Image unavailable, Retry only when the service identifies a temporary problem; support/report remains available | Missing is not Hidden by you, zero physique score, or proof of misconduct |
| Checks pending or renewed safety hold | Image unavailable while checks complete, with report/status route as permitted | Fail closed. Do not claim a violation or reveal previously approved cached bytes |
| Hidden by you | Opaque Hidden by you well, View again only after a successful current check, Report, and any hide-sync status | Local shield immediate; no remote-deletion or complaint claim |
| Report draft, unsent, or receipt unknown | Hidden well plus precise draft/submission status and existing form/case recovery | No Reported label before receipt; no image hold from a draft |
| Received report or report quarantine | Reported or Image unavailable as disclosed by service, existing case access, no gallery unhide shortcut | Revisit, report cancellation after receipt, and another device cannot bypass restriction |
| Removed for safety | Safe Removed for safety well and relevant permitted safety/review route | No prohibited-content preview, cached recovery, automatic result reversal, or accusation badge |
| Sharing withdrawn | That owner's three wells unavailable with Sharing withdrawn; other independently permitted owner can remain | Old links and reconsent do not restore old media; valid result remains |
| Owner deleted/shared images removed | Accurate Image removed or Unavailable player state; no rediscoverable avatar/flag/badges/profile link for a deleted identity | Preserve only authorized nonidentifying result facts; no restoration from another device |
| Block in either direction | Pair's wells shielded, neutral permitted identity, Blocked player only when that label can be disclosed; Safety and Back to result | No pair gallery, new pairing, automatic unhide, loss deletion, or fabricated forfeit |
| Offline or access service unreachable | Shield images, show Connect to view poses or Unable to check access, Retry, Close, Safety and permitted text-only report recovery | No offline image cache bypass, remote-success claim, or local finality change |
| Twenty-four-hour window ends while open | At the actual cutoff every ordinary well becomes Media expired, timer becomes Expired; Back to result and safe reporting remain | No fading remnant, delayed protection, extension from a hold, refresh, hiding, appeal, or viewing |
| App/window inactive, backgrounded, locked, minimized, or sensitive snapshot requested | Immediate opaque privacy cover; permitted non-sensitive result context only | Cancel unnecessary display work and withhold stills; expiry and revocations continue |
| Foreground return or restored window | Retain safe pose choice, show shielded state, revalidate actual account/result/access, require deliberate View poses to reveal again | Never automatically reopen sensitive imagery, reset expiry, or resume a camera |
| Effective result corrected but remains judged and eligible | Updated authorized nonmedia context; recheck media permission, retain safe selection where valid | No award replay, new evidence, or silently mixed original/corrected labels |
| Effective result becomes no-contest or loses gallery eligibility | Immediately remove images and show safe unavailable message with Back to updated result; a report draft can still finish with safe context | No gallery retained under the original verdict; rating corrections remain service-owned |

Any access-denying condition wins over loaded pixels and viewer-owned unhide. Account authorization failure clears the private surface first; a block, removal, withdrawal, or expiry cannot be overridden by a lower-priority loading or hide state. Where several reasons coexist, use the service's permitted reason, avoid revealing another person's private restriction, and offer no restoration action unless every current condition allows it. A temporary fetch failure must not be mislabeled as expiry, and ordinary expiry does not invalidate the score.

## Expiry Timer and Service Authority

Ordinary availability ends twenty-four hours after authoritative finalization, not twenty-four hours after opening, downloading, returning, or changing poses. Use the service-confirmed deadline and a reliable elapsed-time relationship; changing a local clock must not lengthen access. Exact expiry is available in localized date/time form with its time-zone meaning. If the deadline or current permission cannot be established, show Checking access or Access unavailable rather than a guessed countdown or body image.

Use explicit units: hours and minutes while more than an hour remains, minutes and seconds within the last hour. The isolated readout changes only at its displayed precision; stable digit geometry prevents a dancing header. At zero, say Expired rather than leaving a frozen 00:00 above visible photos. The local display can conservatively stop access at the confirmed deadline even when offline; only current service authority can authorize any subsequent view. Closing, reporting, unblocking, requesting review, a legal hold, and reconsent never extend the original ordinary window.

A post-finalization removal, permission change, corrected verdict, or block shields affected images as soon as known and prevents late completions from reintroducing them. When authorization cannot be kept current, hide and recheck rather than treating the timer as a sufficient access grant. Links, view-resolution images, and local caches obey the same removal and expiry as the source. The gallery cannot promise deletion of processor copies or external screenshots merely because participant access expired.

## Accessibility, Keyboard, and Focus

Read in a meaningful order: Poses and real expiry, complete You identity and badges, complete Opponent identity and badges, selected-pose control, You caption/actions/evidence or placeholder, then Opponent caption/actions/evidence or placeholder. Native toolbar placement may differ visually; named landmark/navigation actions preserve discoverability. Use stable element identity so a timer tick, badge wrap, or image load does not reset reading position.

VoiceOver describes only safe context such as Opponent, rear double-biceps, selected still, face obscured, or the actual unavailable reason. Do not generate anatomical descriptions, guess traits, read hidden content from an old caption, or expose signed URLs. Repeated availability checks, loading indicators, timer seconds, interpolated numbers, and badge decoration are not repeated live announcements. Announce one meaningful event for pose selection, successful hide, authorization loss, expiry, or confirmed receipt without interrupting an active report note unnecessarily.

All badges remain readable with their shared text explanation on activation, not just color, shape, or hover. Large text reflows handles, labels, action rows, and badge rails without clamping Dynamic Type. Use readable secondary contrast and increased-contrast outlines when needed; do not inherit an unreadable low-opacity caption merely because it exists in an older Ranked view. Reduce Transparency makes all surrounding chrome and the privacy shield fully opaque. Do not tint or alter the original evidence for contrast; place readable labels on their own surface.

Tab and Shift-Tab follow the visible control hierarchy. The native pose picker handles its normal arrow-key selection only while focused. Return and Space activate the focused semantic control, never a global pose change, image action, capture, or report submission while someone is typing. Full Keyboard Access, Voice Control, and Switch Control can reach each pose, the two independent Hide and Report pairs, expiry details, Safety, and Close/Back without a gesture, long press, or hover.

On entry, focus Poses or the access status, not an image. On pose choice, retain selector focus and identify the new selection once. On Hide, focus the replacement well or its safe action. On report open, focus the shared form heading; after dismissal, return to that image's safe placeholder rather than the now-hidden pixels. If expiry, deletion, or a correction removes the target, return to its permitted placeholder or Back to result. Returning from the gallery focuses its original View poses action when still allowed, otherwise the updated result status.

## Animation, Interruptions, and Energy

Motion is tactile chrome feedback and clear state continuity, not animation of a person's anatomy. Native navigation/sheets provide their platform transition; do not stack a second hero zoom or six-image cascade onto them. Pose selection and shared presses supply the sports UI's physical response. The evidence itself stays geometrically stable.

| Trigger | Motion and timing | Interruption and accessibility behavior |
| --- | --- | --- |
| Intentional gallery open or Back/Close | Native platform navigation or large-sheet transition, with content immediately usable when authorized | Dismiss can interrupt; no mandatory reveal delay. Respect the system's reduced-motion transition |
| Pointer/touch/key press | Existing shared press spring, response 0.24 and damping fraction 0.88, on controls only | Release or cancellation cancels feedback without a second action. Reduce Motion removes scale |
| Actual pose selection | Selected chrome marker settles with the shared press spring; previous evidence is removed, safe labels/wells update together, newly authorized stills may appear with a 180-millisecond opacity entrance | Latest selection wins. No old/new body morph, swipe travel, wrong-pose overlap, delayed Hide, or forced waiting. Reduce Motion uses immediate selection and at most a 100-millisecond opacity entrance |
| Real expiry-readout change | Approximately 180-millisecond localized digit/content replacement with reserved unit/digit space | Does not relayout the stage or announce every tick. Reduce Motion uses immediate digits |
| Loading resolves or recoverable error changes | Status icon/text changes over 140–180 milliseconds; wells keep their geometry | Cancel obsolete display work when pose/account/access changes. No shimmer, fake percentage, or minimum spinner time |
| Confirmed public badge/identity refresh | A single 180-millisecond mark/text change through the shared badge rail | No unlock replay, pulsing wall, celebratory body movement, or stale entitlement held for animation; removed permission wins immediately |
| Hide, Report entry, block, revocation, expiry, sign-out, or privacy cover | Remove sensitive pixels immediately; only the already-safe placeholder text may settle over 140 milliseconds | Protection never waits, fades out the unsafe body, or briefly unblurs on interruption. Same immediate protection with Reduce Motion |
| Report/privacy information presentation and return | Existing native sheet, popover, or navigation motion | Shared draft protection and focus restoration apply; no custom stacked modal choreography |

There is no gallery ambient loop, automatic pose playback, pulsing badge wall, confetti, countdown pop, score animation, or new result celebration. This is a deliberate quiet phase after the result; adding an ambient loop would compete with evidence and consume energy without new information. At most one focal chrome event runs at a time. Rapid actions retarget the present state instead of queuing animations.

Keep timer updates scoped to the timer and image display work scoped to the visible authorized pose. Do not decode, measure fonts, fetch media, check permissions, or invalidate the entire stage per animation frame. Do not eagerly decode an archive of retakes or download hidden poses merely for a transition. Necessary private-media checks belong to shared service policy, not decorative loops.

Pause all decoration, image work that is no longer needed, and timer repainting offscreen, backgrounded, inactive, minimized, or occluded. Authoritative expiry does not pause. On Low Power Mode or serious thermal constraint, remove optional entrances and use coarse minute precision until the final minute; Less than one minute remains truthful without constant repainting. Expiry protection still happens at the actual deadline. Return uses the current safe state, never a backlog of missed ticks, badge unlocks, or animations.

## Ownership, Files, and Dependencies

These are product ownership and prospective integration locations, not claims that the future files exist or instructions to replace an established service design.

- [This document](DOCKS.md) owns the gallery's product behavior.
- [F29-A](../DOCKS.md) owns the result entry, return route, shared match lifecycle, and overall native journey. Its newer integrated child map must supply the result and safety owners before implementation.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns accepted pose meaning, clean judged evidence, valid outcomes, and the prohibition on inferred anatomy or identity.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns historical match context, effective finality, corrections, and rating records. This gallery cannot settle or repair them.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns Hide, reports, blocks, safe reasons, case receipts, appeals, and human review.
- [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns current consent, authenticated media access, revocation, ordinary expiry, cache limits, withdrawal, deletion, and provider-retention disclosures.
- F29-F owns the canonical country/identity/badge presentation and public-entitlement source. The main feature index resolves its final document path; this child must reuse it rather than add a competing catalog.
- Shared native stage, timer, access, and privacy-lifecycle foundations registered by the main owner are prerequisites, not gallery-owned replacements.
- Prospective TimeMaster/Views/Physique/PhysiquePoseGalleryView.swift owns native destination composition, synchronized pose choice, and safe presentation.
- Prospective TimeMaster/Views/Physique/PhysiquePoseEvidencePanel.swift owns one fixed-owner, fixed-pose evidence well with external caption/actions and precise placeholders, if an existing shared evidence component does not already provide it.
- Existing or future TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift supply the reviewed private-media, account, result, and safety contract. The gallery consumes their actual authority; this child does not create a fake media client or alternate match state.
- The separate [future implementation brief](../../../../prompts/F29-physique-duels/F29-A-n-phase-1-pose-gallery.md) owns execution scope. CYCLES.md alone tracks implementation and human-review work.

Implementation begins only after the real account/session, result, private-media access and revocation, safety/report/block, privacy lifecycle, and shared identity/badge foundations are implemented and human-reviewed. They must offer actual current authorization and removals, not just successful compilation or preview fixtures. An unavailable public service, missing authorization contract, or nonoperational moderation channel is not permission to ship a mock gallery. This document alone does not make the view independently shippable.

## References

- [Physique Duels parent](../../DOCKS.md) and the area documents above define finality, consent, accepted evidence, and privacy boundaries.
- [Supplied battle screenshot](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) informs the direct timer/identity/player hierarchy only. Its side-by-side layout, over-image badges, purple/brown styling, people, footage, captions, and implied asset rights are not imported.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), especially lines 1–81 and 208–228; [ProfileDesign](../../../../TimeMaster/Utilities/ProfileDesign.swift), lines 1–38; and [shared controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift), lines 20–80, define palette, typography, readable columns, native availability fallback, and press feedback.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift), lines 15–108 and 148–188, inform control/earned-rating language, not Dynamic Type clamps, exercise metrics, or fake levels. [Ranked duel HUD](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift), lines 25–151, is exercise context, not a provisional physique score source.
- [Native app window](../../../../TimeMaster/App/TmaxApp.swift), lines 8–19, and [commands](../../../../TimeMaster/App/TmaxCommands.swift), lines 6–37, establish the minimum window, normal title bar, and commands that remain unchanged. [Local profile models](../../../../TimeMaster/Models/LocalProfileModels.swift), lines 23–27 and 99–109, distinguish editable cosmetic previews from competitive achievements.
- [SwiftUI UI Patterns](https://github.com/Dimillian/Skills/blob/main/swiftui-ui-patterns/SKILL.md), especially its selected sheet and async-state references, informs narrow state ownership, cancellation, and real loading/error states. Installed swiftui-pro and swiftui-animation supply accessibility, stable layout, selective animation, and availability-aware guidance; this feature retains iPhone iOS sixteen compatibility rather than inheriting a skill's newer default target.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices, supports resizable native windows, comfortable density, keyboard work, and normal full-screen behavior. [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback, supports purposeful, brief, optional, interruptible feedback. The gallery's particular portrait wells, lifetime timer, and pose-selector choreography are product choices, not numerical Apple requirements.
