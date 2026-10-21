# F29-G-b — Player Panels and Pose Icons

## Purpose and Decision Boundary

This area defines the shared large participant panel and neutral three-pose visual language for native iPhone and native macOS Physique Duels. The panel distinguishes a person's local camera, their exact selected evidence, an authorized opponent avatar, and protected or unavailable media without confusing any of them with live opponent footage. The pose system makes Front, Side, and Back recognizable without making an illustration a body ideal or a source of judging evidence.

This is product direction for future implementation, not an implemented component, generated asset collection, accepted prototype, or measured accessibility result. The user's direction is two large vertically stacked participants on both platforms, with the real timer first and every public battle badge above the participants. The earlier F29-A allowance for a balanced two-column comparison does not apply to this direction, including on wide Mac displays. Detailed geometry and motion below are concrete design proposals within that direction.

The [native UI parent](../DOCKS.md) owns shared composition. [F29-A](../../F29-A-page-and-match-flow/DOCKS.md) owns the match journey, capture actions, and destinations. F29-F, reached through the [F29 product map](../../DOCKS.md), owns trusted public identity, optional country or region, and competitive badges. This child consumes those decisions; it does not establish another badge catalog, capture engine, timer, permission dialog, gallery screen, rating system, or report form.

## Chosen Composition

### Timer, identity rails, then the two participants

The first visual anchor in a battle is the host's real timer and current phase. Immediately below it are the complete You and Opponent identity-and-badge groups, in that order. Both groups precede both player panels. Their role labels correspond to the panels below; badges must not be scattered onto the nearest face, shoulder, or image corner.

The stage then contains You above Opponent, always. Both panels use the same outer width, media-well size for the current platform, surface treatment, and image-fitting rule. Neither readiness, upload speed, Elo, a final win, nor a correction changes their order or makes one participant larger. There is no side-by-side breakpoint, horizontal player carousel, draggable order, expandable winner card, or picture-in-picture opponent.

The centered column uses the app's existing readable-width and spacing conventions rather than spanning an entire large display. The timer and essential actions remain reachable while the middle stage scrolls. The identity rails belong to that scrolling stage, not to an indefinitely growing pinned badge wall. Every authorized public battle badge is present in wrapping rows: no three-badge limit, hidden remainder count, clipping, automatic ticker, or hover-only discovery. A large badge collection therefore costs scroll distance, not participant size or badge completeness.

Inside each panel, a short role heading sits above the media well. The supporting status and relevant pose guidance sit below it, outside the image. The panel heading does not repeat the whole identity rail. The stage owner provides Ready, Capture, Submit poses, Exit, and Safety in its reachable action region; the panel must not create competing copies or turn its entire image into a hidden capture button.

### Why this composition

A stable vertical stack preserves ownership while a person looks between the camera and the screen. Equal presentation avoids suggesting a winner before a valid result. A shared, complete identity area keeps earned identity visible without contaminating evidence. Larger panels and scrolling are preferred to fitting everything into one short viewport. The tradeoff is that both full participants will not always be visible simultaneously; the document does not promise otherwise.

The screenshot reference supplies the immediate timer-to-participants hierarchy and direct sports character. Its side-by-side faces, over-image pills, purple and brown treatment, text, and identifiable people are not reused. The local and opponent panels deliberately differ in content: a large opponent avatar is an identity anchor, not a staged imitation of an unavailable live feed.

## Shared Panel Anatomy and Image Treatment

### Surfaces and typography

Use the existing near-black background, dark elevated surfaces, white primary text, orange action language, Inter headings, and readable body typography. Opaque dark media surrounds keep camera content legible and visually separate from toolbar materials. Do not put glass, shimmer, blur, a gradient wash, a winner tint, or an animated shader over evidence.

You and Opponent remain readable headings. Current pose and the single most useful instruction use readable body or heading roles, not the tiny technical text used for some existing Ranked metrics. Text scales and wraps; it is not compressed to keep three chips on a row. A secondary camera or connection status is still legible against its actual background. Increased Contrast strengthens borders and text without recoloring a body. Orange indicates an actionable or current state, never a physique advantage or safety verdict.

### Media wells

On iPhone, use a portrait three-to-four media-well proportion. On Mac, use a four-to-three media-well proportion to make ordinary landscape desktop cameras usable without an excessively tall empty portrait surround. These are content proportions, not fixed screen sizes. Both participants on the same surface receive the same well. A Mac well can contain a portrait still, and an iPhone well can contain a landscape camera: the entire source remains aspect-fit with honest empty space.

Vertical describes the participant order, not permission to crop every camera into a portrait. Size wells from the available measured content column and the established readable width, never from fixed display coordinates or half of the remaining window height. At short heights, preserve large media and scroll instead of reducing both panels to thumbnails. Scroll-viewport clipping is not an image crop: the source itself remains whole and reachable. Camera review and adjustment never require horizontal panning.

Fit each source uniformly inside its well. Preserve orientation, proportions, edges, hands, elbows, legs, and feet present in the source. Do not fill-crop, stretch, auto-center on a torso, reshape, sharpen anatomy, digitally zoom one person, or normalize a participant's apparent height from inferred body measurements. Equal wells and fit rules do not prove equal real-world body scale; framing adequacy remains a capture-service concern. Rounded panel corners sit outside an inset image rectangle, so clipping the card does not cut off evidence at the image corners.

Before finalization, the opponent well contains only a currently permitted public avatar or a neutral silhouette. A square avatar is fitted and centered rather than stretched to suggest a full-body image. Its role remains explicit through the visible status Avatar · Not live. No avatar is evidence, proof of identity, or a substitute pose. No local Profile photo is automatically published, fetched through a private path, or uploaded to populate this well.

### Local preview, evidence review, and guides

The local live camera is identified as Camera active · Local only. It is never described as a live stream to the opponent. The capture owner may provide a mirrored front-camera preview for positioning, clearly labeled Mirror preview in setup. The selected redacted still is shown in the actual consistent orientation that will be transmitted, not silently mirrored again by this panel. Orientation and camera changes follow the capture owner's rules and never reassign Front, Side, or Back.

An exact selected-image review may replace the live source in the same well. It says Selected, Checking, Accepted, or Needs retake according to the actual state. It does not silently continue a camera behind the review. The selected representation is the exact locally face-obscured evidence, without the timer, handles, country, badges, pose illustration, status text, or framing graphics baked into it. If redaction is unavailable, no original is transmitted as a fallback.

Guidance is separate from the body image. Simple corner references, when useful, sit in the media surround, outside the image rectangle. A small pose illustration and one current instruction sit below the well. Do not superimpose a target body, ghost silhouette, skeleton, waist outline, intimate-region target, scanning band, or measurement grid on the participant. Guide artwork describes orientation; it is not a contour that a person must match.

The panel prioritizes one actual actionable issue: for example, Include hands and feet, Move into ordinary light, Capture alone, or Adjust the camera. Safety and redaction failures outrank cosmetic framing advice. These messages are sourced from real capture checks, not inferred from an illustration or a locally invented score. Expanded guidance and the capture owner's recovery controls remain available when the short instruction is insufficient.

## Neutral Pose System

### Fixed pose language

| Position | Compact visible label | Full accessible name | Illustration and short instruction |
| --- | --- | --- | --- |
| First | Front | Front double-biceps pose | A frontal, upright athlete with comfortably raised bent arms and both legs visible. Face the camera; keep arms and legs in frame. |
| Second | Side | Side physique pose | A whole-body profile with ordinary balanced stance and interpretable arm and leg contours. Turn sideways; keep arms and legs visible. |
| Third | Back | Rear double-biceps pose | A rear view with comfortably raised bent arms, opaque covered back and shorts, and both legs visible. Face away; keep arms and legs in frame. |

The three names and positions persist across setup, capture, review, and authorized result details. Compact labels never imply that a side silhouette proves left or right anatomy. The capture protocol, not an asset's decorative facing direction, defines any required side. A mirrored positioning view cannot change the evidence pose identity.

The full guidance tells the person to breathe normally, keep a comfortable stance, and stop if a pose hurts. The rear pose can be understood before turning away; the person must not twist unsafely to read a screen. The existing capture flow's optional spoken cue or self-timer supports this use without microphone access. A mobility limitation or a comfortable variation is not a low score. Only the reviewed evidence contract can determine whether a variation remains comparable; the UI never invents medical judgments or a physically impossible adaptation.

### Original ivory-athlete artwork

Use one coherent, original or appropriately licensed ivory-athlete family for the three poses. Large examples may have quiet sculptural depth; compact icons use a simplified silhouette derived from the same poses. The figure has a featureless face, ordinary athletic proportions, an opaque neutral athletic top, and opaque shorts covering groin and buttocks in every view. Restrained orange garment or state accents connect it to Tmax. The artwork does not imply that participants of a particular gender, build, or skin tone are more valid.

The existing Ranked hero establishes an ivory-and-orange visual family, not a ready-made Physique pose guide. Its exaggerated muscles, exposed torso, face detail, mask, and costume must not become a required body template. The three new poses must be recognizable by orientation and limb placement without copied people, fetish framing, glossy anatomical emphasis, breast or genital detail, or a heroic ideal that a person is instructed to imitate.

Front and Back are not distinguishable by color alone. Larger art can use the plain top's front neckline and rear shoulder panel to reinforce orientation; compact views always retain Front and Back text. A featureless face is an illustration choice, not a picture of the actual face-obscuring treatment or a promise of anonymity.

Artwork must fit completely with consistent optical padding and preserve fingers, raised elbows, feet, and the whole side stance. It must remain legible in monochrome, at increased contrast, on both dark surfaces, at accessible text sizes, and at native display scales. No photographic competitor, screen capture from the reference, exercise icon mislabeled as a physique pose, or generated photoreal stranger substitutes for this set. Asset rights and any required attribution must be available before production use. These documents do not assert that the assets exist.

### Pose state meaning

Pose icons can be informational or part of an existing semantic control; they do not add a new screen. Reading an illustration does not capture, select, retake, upload, or request a judgement. A control's visible action states what it does, such as Pose guide or Review front. A disabled retake remains explained by the capture owner rather than appearing to be a broken icon.

The local pose slots distinguish Not captured, Selected, Checking, Accepted, and Needs retake. Current pose uses an outline and text, Accepted uses a checkmark and text, and Needs retake uses a warning mark and reason. A checkmark means actual acceptance, not merely that a photo was taken. A retake removes the superseded acceptance immediately; a late response for that old selection cannot restore it. At most two retakes per pose remain within the original ninety-second capture period.

The opponent receives only the permitted stage and actual accepted count. Do not infer which named pose has passed from an aggregate count or infer progress from elapsed time. Named opponent pose states appear only if the reviewed service contract explicitly supplies and permits them. Otherwise show the truthful count, such as 1 of 3 accepted, without inventing three individually checked poses.

## State, Action, and Recovery Contract

A neutral state surface with a working recovery action is deliberate product content, not a mock competitor. The panel presents state supplied by its real owners and routes actions to them. It does not settle a match or create a successful receipt locally.

| Actual state | Panel presentation | Action and recovery boundary |
| --- | --- | --- |
| Local guide without camera | Pose art and local guidance, with no live indicator or peer | Pose guide can be read without permission or upload. Camera setup remains an explicit host action. A guide-only surface is not a fake battle. |
| Camera permission not requested | Safe camera symbol, Camera off, and a concise purpose | Enable camera invokes the real system request through setup. Reading a guide or mounting a panel does not request permission. |
| Camera starting | Stable empty well and Starting camera; no frozen sample image | Stop and safe exit remain available. Only a real first preview becomes Camera active. |
| Permission denied | Camera access is off, with platform-appropriate Settings action | iPhone Settings or Mac System Settings is offered only when useful. Return explains that access must be rechecked; it does not repeatedly trigger a denied prompt. |
| Permission restricted | Camera access is restricted and a nonaccusatory explanation | No misleading Settings cure or file-picker substitution. Return and allowed help remain usable. |
| Camera missing, busy, or unavailable | Specific No camera, Camera in use, or Camera unavailable state | Retry when meaningful; setup can select an actual available device. Do not invent a preview, silently choose a new source, or accept rated library media. |
| External or Continuity camera disconnected | Immediately replace stale pixels with Camera disconnected | Reconnect or choose an available camera through the host. After Go, a changed camera discards the affected selected set and restarts capture only within the original deadline. |
| No opponent yet, if a battle-shaped search surface is used | You remains first; the second full-size well says Finding opponent with a neutral empty silhouette | Cancel search is real. The silhouette has no handle, badges, fabricated readiness, or simulated progress. Search expiry produces No opponent found and real retry or return. |
| Real pairing identity loading | Opponent well is neutral and says Loading player | Unknown identity or badge data is not presented as none earned. A protected identity failure cannot be repaired with someone else's cache. |
| Avatar loading, absent, failed, or withheld | Safe silhouette plus respectively Loading avatar, No avatar, Avatar unavailable, or the permitted neutral state | Avatar failure alone need not block an otherwise valid match. Existing account/refresh controls handle recovery; no separate permanent Retry avatar button is required. |
| Ready or waiting for readiness | Camera only while permitted; neutral opponent avatar and actual Not ready, Ready, or Waiting for opponent | Ready is explicitly confirmed by the host. Permission loss removes readiness; an old ready check cannot survive withdrawal. |
| Shared countdown | Same two wells and identities; stage countdown above, no second countdown over a body | Go comes from the service, not the last visual numeral. A pre-Go cancellation racing Go returns the real state and never silently becomes consent to forfeit. |
| Active capture | Stable local aspect-fit preview, current named pose, private guidance; opponent avatar and permitted progress | Capture and its optional three-second self-timer belong to the host. No tap on empty panel space captures. Both participants retain their locations. |
| Bad framing or lighting | One actionable private instruction and a non-color cue outside the well | Adjust and retry only within real remaining time. No visible muscle score, confidence percentage, exposure bonus, or model advice. |
| Second person or failed redaction | Capture alone or Privacy mask unavailable; affected still is not approved or transmitted through this path | Safe recapture or state-aware exit. Masking a bystander is not a remedy. Do not display an enlarged rejected region. |
| Own selected still | Exact redacted review with Selected and the actual transfer state | Review and retake target that named pose. Selected does not mean accepted by moderation or the service. |
| Checking or uploading | Honest local slot states and real transferred or accepted counts | Retry only when the real owner allows the same submission. No artificial completion percentage, new match, or extra allowance charge. |
| Recoverable rejection | Needs retake, named pose, practical private reason, and real remaining retakes | Retake or applicable review/help route. The opponent sees neutral progress, never the rejected image, reason, or an accusation. |
| Retakes exhausted or deadline reached | Capture unavailable and the actual reason; no capture-like disabled mystery icon | Fetch the authoritative next state. Do not label a match no-contest solely because a local timer reached zero while offline. |
| Own set submitted | Camera off; neutral pose art and Submitted, rather than an old frame pretending to be live | No automatic resumption or new evidence. Wait or use the host's permitted navigation/exit. Editing occurs only for a real recoverable service request. |
| Waiting for the other set | Submitted locally; opponent avatar and last confirmed authorized stage | Accepted counts are not a prediction of a win. If updates are stale, say Updating or Reconnecting rather than animating assumed progress. |
| Judging | Camera off; both panels retain safe identity/progress content | No opponent still, body scan, speculative score, or five-second result countdown. The host owns honest judging status and the thirty-second deadline. |
| Offline or reconnecting | Privacy cover for live/private sources, Reconnecting, and explicitly stale non-sensitive stage information | Stop acquisition. Restore the same match within the twenty-second grace without extending deadlines or resetting retakes. Unconfirmed finality remains unconfirmed. |
| Inactive, minimized, locked, or backgrounded | Immediate privacy cover, never a cached body frame | Capture stops immediately. Returning restores account, service state, permission, and camera ownership before an explicit permitted resume. No automatic still or upload. |
| Session active in another window or device | Camera off and Active in another window or device; no second local owner | Route to the existing session where available. No second match, camera, charge, or automatic session takeover. |
| Valid final win, loss, or draw before View poses | Camera off; avatar or neutral illustration remains | Result arrival alone does not reveal stills. View poses belongs to the authorized result flow and rechecks current access. |
| Intentional authorized pose viewing | Each permitted selected still stays labeled by owner and pose, aspect-fit, with protection controls outside the image | Retain You above Opponent whenever this battle comparison is used. Report and Hide are reachable before enlargement. The viewer owner manages navigation and expansion. |
| Forfeit, no-contest, or unconfirmed result | Appropriate safe avatar/art and actual host status | No counterpart gallery, invented totals, locally awarded win, or premature rating animation. |
| Hidden, reported, removed, withdrawn, blocked, expired, or deleted media | Replace image immediately with the precise permitted reason | Hidden by you may offer View again only when all current access checks pass. A report quarantine, block, removal, withdrawal, deletion, or ordinary twenty-four-hour expiry cannot be bypassed by it. |
| Block requested offline or after Go | Immediate local shielding and honest confirmation-pending status | Block alone does not leave, rate, or finalize the match. Future-pair exclusion is not claimed confirmed until the real service confirms it. |
| Corrected identity, badge, result, or access | Use the current permitted state without celebratory replay | F29-F owns badge removals and stale/unknown distinctions; F29-C owns corrections. Protected pixels disappear immediately, even during another animation. |
| Sign-out, account switch, or deletion | Remove the previous account's private panel content and drafts immediately | Never show the last participant's cached image under the next account. Resume requires the newly authorized account state. |

## Native iPhone Composition and Interaction

The timer sits in the safe top region; the single scrolling stage contains both complete badge groups and both large participants. Primary capture/submit and safe exit actions remain in the host's safe reachable controls. Existing navigation placement and floating-control clearance are measured; there is no guessed bottom spacer. Landscape and smaller iPhones retain the same vertical player order and scroll rather than changing to a horizontal duel.

Pose labels and statuses wrap at large Dynamic Type. If the three local pose slots cannot fit with readable labels and full touch targets, they become vertically arranged controls in the same Front, Side, Back order. This changes the control layout, not player order or progress meaning. Critical reason text is not replaced by a tooltip. Primary, recovery, and safety actions retain the existing minimum forty-four-point interaction area.

Tapping a pose guide opens the host's existing guide presentation; tapping an authorized review action opens that exact local selection or permitted result item. Dragging or pinching the live panel does not alter framing, zoom the evidence, switch the active pose, or issue a capture. Any image enlargement belongs to the intentional viewer and never overrides its access checks. Closing that viewer restores focus to the invoking control.

A sheet that covers or replaces active camera use cannot leave capture running unnoticed underneath it. The host's camera/privacy owner controls the stop and explicit return. The match clock does not pause while the person reads guidance, changes a setting, or files a report. Instructions and self-timer options remain available before Ready so ordinary preparation need not consume the capture period.

## Native macOS Composition and Window Lifecycle

This is a native macOS 14-and-later surface inside the existing title-bar WindowGroup, not Catalyst, a web view, or a stretched phone sheet. The existing 800-by-600 app minimum is retained. A normal title bar and native toolbar provide window navigation and the host's safe actions; the real phase/timer remains the leading content anchor. Standard native sheets, permission prompts, camera menus, and help presentations are reused rather than wrapped in new custom lookalikes.

At the minimum window and short laptop windows, the timer and essential controls remain reachable while the complete badge area and full-size vertical panels scroll. At large, full-screen, and external-display sizes, keep a centered readable stage and use spare width for an optional existing details inspector, not a second participant column. The inspector may explain poses, rules, or status; it never becomes the only location for a badge, primary instruction, safety action, or required recovery. Collapse it before sacrificing the stage's readable controls.

Live resize recalculates the usable column and text wrapping without changing camera source, selected pose, accepted counts, match reference, focus identity, or scroll anchor. It does not restart the capture engine or replay a pairing transition. Moving between displays with different scale factors preserves complete aspect-fit images and sharp original artwork; display choice is not a judging input. A large Mac screen does not force giant phone-sized buttons, and a small Mac screen does not justify tiny instructions.

TCC permission denial, managed restriction, no built-in camera, a camera held by another app, and external or Continuity disconnection remain distinct states. Native device selection is available only where the capture owner permits it. Switching after Go retains the existing discard-and-recapture consequence and original deadline; it is not an invisible continuity repair. A file chooser, prerecorded video, or test image is never a rated substitute.

One account has one active match and one camera owner across windows and devices. Opening another window displays the existing state without opening another camera or charging another match. Deactivating the owning window, minimizing, hiding, locking, or backgrounding stops acquisition and shields sensitive content immediately. Return restores the real state and offers an explicit permitted resume. A service judgement already in progress can finish while the camera is stopped.

Cmd-W and normal Quit requests use the host's state-aware confirmation where the platform permits: before Go, cancellation; after Go, the actual eligible forfeiture consequence; after finalization, ordinary close. The camera stop itself must never wait for that dialog or an animation. Force quit, process termination, and device loss cannot be intercepted reliably and are not proof of a voluntary confirmed forfeit.

## Focus, Keyboard, and Assistive Technology

The reading order is phase/timer, You identity and badges, Opponent identity and badges, You panel and local pose state, Opponent panel and permitted progress, then the remaining host controls in a consistent navigation order. Both roles are accessible headings. The complete badge list remains individually discoverable through its owner; do not flatten the whole battle into one long inaccessible label.

A camera is one descriptive accessibility element, not a sequence of frames or a generated body description. A useful local summary is Your camera, local only, Camera active, Front double-biceps, followed by the current actionable guidance. The opponent summary identifies an avatar or neutral silhouette, explicitly says Not live video, and gives only real stage/count information. Hidden imagery loses its image description as well as its pixels. Pose icons duplicated beside a named control are decorative to VoiceOver; standalone guides expose the full pose name and instruction once.

Announce meaningful transitions such as camera interrupted, pose accepted, a named retake requirement, submission locked, or media no longer available. Do not announce every frame, timer tick, interpolated number, connection sample, or unchanged instruction. Acceptance changes do not steal focus from a person reviewing another pose. A blocking failure or deliberate stage navigation moves focus to its heading or recovery explanation. Dismissing a guide or sheet returns focus to its invoker; if that action no longer exists, use the nearest surviving heading, not an arbitrary capture control.

Native keyboard focus and a visible focus ring apply to genuine controls, not the whole panel. Tab and Shift-Tab follow the native keyboard-navigation setting. Space or Return activates only the focused semantic action; neither key is registered as a global capture shortcut while a person types or uses another window. Escape first cancels a reversible local self-timer or dismisses the top eligible presentation through its owner; otherwise it requests the host's state-aware exit. It never silently forfeits, discards a report draft, or restores hidden imagery.

Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O. A pointer hover may clarify a native control, but it must not reveal an otherwise unavailable action, magnify a body, expose an image, or move an avatar. Context menus are optional duplicates, never the only route to Report, Hide, or recovery. Voice Control names distinguish Review front from Capture, and Switch Control reaches the same actions without precision gestures. Silence, lack of haptics, and reduced motion do not remove required instructions.

## Animation Rules

The camera and evidence remain spatially steady. Motion belongs to small state markers, the selected pose treatment, and host-controlled stage continuity. It never morphs one human body into another or treats the opponent as a loser animation.

| Trigger | Visible motion and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Press a real action | Reuse the shared press spring, response 0.24 and damping fraction 0.88; no additional panel-wide scale | Release or cancellation restores the control immediately; Reduce Motion removes scale. No disabled control fires an action. |
| Actual pairing or host stage replacement | The surrounding stage may settle over 280 milliseconds; player roles and image geometry retain their positions | The host owns this one transition. Panels do not add a second stagger or delay camera access. Reduce Motion uses immediate placement or a short opacity change. |
| Actual Ready confirmation | The small readiness mark settles from at most 1.04 scale to rest within 200 milliseconds with a brief opacity change | Camera/consent loss immediately removes Ready. Latest state wins; no queued repeated pop. Reduced mode uses a static mark. |
| Current pose changes | Named guide crossfades over 180 milliseconds; the current-slot outline transfers with a short, nonbouncing emphasis | Do not morph between anatomical poses. A new selection replaces the previous transition. Reduced mode replaces the guide and selection immediately. |
| Service accepts the current selected pose | A small checkmark settles from at most 1.04 scale and its surrounding state stroke completes once within 200 milliseconds | The final Accepted text is available immediately. No celebration for an upload receipt. Retake, rejection, or supersession cancels the effect and removes the old check immediately. |
| Real private framing instruction changes | Instruction and non-color status change over 150 milliseconds while media geometry stays fixed | Urgent safety or privacy changes are immediate. Stable repeated samples do not retrigger. Reduced mode uses immediate replacement. |
| Authorized avatar or intentionally opened still finishes loading | Replace the neutral loading surface with the fully authorized image over at most 180 milliseconds | Do not crossfade from a different person's old image. Access revocation cancels reveal and clears pixels immediately. Reduced mode may use immediate appearance. |
| Submitted or camera stopped normally | Clear live pixels immediately; a non-sensitive icon/status may settle over 160 milliseconds | Stopping is never delayed for the fade. No frozen last frame is left as background. Reduced mode is immediate. |
| Disconnect, hide, report, block, withdrawal, expiry, or account change | Immediate opaque protection and correct status; no animated concealment | Overrides every reveal, scale, and stage transition. Safety never waits for animation completion. |
| Resize, display move, or accessibility text change | Natural layout and wrapping; no springing of the camera rectangle or participant reorder | Preserve focus and logical scroll position. No pairing, readiness, or reward replay. |
| Real result or earned badge arrives | Panels stay in place; the host and F29-F may run their single authorized result/unlock treatment outside evidence | No independent score animation, loser shake, badge wall pulse, or award on history reopen. Final values and safe actions are available immediately. |

This component adds no ambient loop. If the shared stage uses its single quiet approximately twelve-second ambient treatment, the panels remain static around it. The host's real-second countdown, stable timer digit updates, and final result reveal are not duplicated inside the wells. At most one focal event runs with that ambient layer; stale or superseded events are discarded rather than replayed as a queue.

Offscreen panels pause decorative work. Inactive, minimized, backgrounded, or hidden windows pause it immediately. Low Power Mode and elevated thermal pressure remove decorative motion and unnecessary redraws while retaining truthful status and readable controls. Privacy/camera stopping follows the real lifecycle regardless of animation settings. Neither energy saving nor reduced motion pauses service deadlines, changes evidence quality silently, or invents accepted progress. Reduced Transparency uses opaque readable surfaces; reduced motion retains every status, action, and recovery route.

## Privacy and Authority Invariants

Only approved local capture produces evidence. The judge receives clean locally face-obscured candidates or stills and the necessary anonymous pose context, never a screenshot of this panel. Handles, country or region, flags, badges, ratings, icons, camera controls, guidance, and public avatars are not judging inputs. A selected public flag is optional and self-declared, not inferred from GPS, IP, locale, a photo, or an identity-verification claim.

No local panel calculation creates readiness, accepted evidence, Elo, placement, a streak, a result, or a confirmed block/report. Unknown is not zero, stale is not live, and selected is not accepted. Editable local badge previews and legacy display levels are never competitive evidence. F29-F supplies all authorized public badges and their ordering, removal, correction, and stale-state meaning; this panel never chooses a favored three.

Counterpart stills require intentional View poses after a valid judged win, loss, or draw, current participant access and sharing permission, all necessary checks, no prohibiting block or safety restriction, and unexpired media. Ordinary access expires twenty-four hours after finalization, not first viewing. Forfeits and no-contests never unlock the gallery. Hiding, reopening, a restored window, a cached thumbnail, an old link, or an appeal cannot extend access. Protection is immediate even if network confirmation is pending; service-wide effects remain honestly labeled.

There is no live opponent stream, microphone, chat, private profile scraping, body measurement, confidence gauge, face recognition, demographic inference, or automatic Photos save. Permitted shirtlessness does not become a visual reward or a requirement in the artwork. Screenshots and external copying cannot be guaranteed impossible; an illustration or privacy shield must not imply otherwise.

## Dependencies and Files

The [F29 parent](../../DOCKS.md), [F29-A flow](../../F29-A-page-and-match-flow/DOCKS.md), [F29-B evidence rules](../../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-C authority](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety](../../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy](../../F29-E-privacy-and-service-operation/DOCKS.md) constrain every state. F29-F supplies trusted identity and the full badge rails; the G stage owner supplies the timer, scrolling container, action region, and participant ordering. Capture and result/media owners supply their real actions and privacy-aware media. They do not need a second implementation inside this child.

Production work requires human-reviewed account/session, camera/redaction, service state, authorization, and lifecycle foundations, plus production-safe pose assets with usable rights. A panel is not independently releasable while those dependencies are mocked or absent. Their implementation and human-review status belongs only in [CYCLES.md](../../../../CYCLES.md).

Prospective component responsibilities are the shared participant panel and the shared pose icon/illustration presentation under TimeMaster/Views/Physique/, with approved art under the existing asset catalog. The future brief names candidate files; it must adapt to the actual reviewed feature structure rather than creating a parallel theme or speculative service abstraction. Existing Theme, ProfileDesign, shared controls, native app/window commands, and exercise camera privacy remain unchanged except for a separately authorized necessary integration.

## References

- [F29 battle screenshot](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): hierarchy and directness only, not reusable people, image rights, overlays, or horizontal layout.
- [Existing Ranked hero](../../../../TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png): ivory/orange sculptural family only, not a physique pose or required anatomy.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift): current native color, type, spacing, material fallback, and press-feedback language.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) and [exercise player](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift): existing sports context, not Dynamic Type clamps, a Physique provisional score, or a second scoring HUD.
- [Native Mac app](../../../../TimeMaster/App/TmaxApp.swift) and [commands](../../../../TimeMaster/App/TmaxCommands.swift): existing window minimum, title bar, and reserved commands.
- [Apple HIG: Designing for macOS — Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): native resize, multiple displays, keyboard/pointer interaction, and comfortable information density inform the centered scrolling Mac stage.
- [Apple HIG: Motion — Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion): purposeful, brief, optional, interruptible feedback informs small state motion and immediate protection. This does not claim runtime compliance.
