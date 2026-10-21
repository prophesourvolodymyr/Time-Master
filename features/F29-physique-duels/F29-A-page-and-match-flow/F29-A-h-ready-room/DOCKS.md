# F29-A-h — Ready Room

## Purpose and Product Boundary

The Ready room is the native iPhone and native macOS meeting point between a real service-confirmed pairing and the first guided capture. Each person deliberately becomes Ready. Only the trusted service can authorize the shared three-second start and establish Go. An opponent becoming ready, two locally drawn checkmarks, or a visual timer reaching zero is never permission to start a rated match.

This document specifies product behavior and a future UI direction. It does not describe an implemented screen, an approved prototype, a deployed service, or human acceptance of the feature. The [F29 parent](../../DOCKS.md) owns the competition contract; [F29-A](../DOCKS.md) owns the surrounding journey. The explicit direction for both native platforms, complete badge rails, large vertical participants, and tactile minimal-text sports presentation takes precedence over the older parent's phone-first, optional side-by-side desktop composition and fade-only countdown proposal.

This area owns the Ready-room composition, independent readiness controls, synchronized start presentation, pre-Go exits, and the handoff at Go. It consumes shared identity, badge, timer, participant-stage, camera, safety, and match-recovery foundations. It does not create another public profile, country editor, report composer, camera setup screen, capture workflow, result screen, or competitive authority.

## Chosen Composition and Tradeoffs

The composition is a vertical fight card, not a video-call grid. Its order is always the same:

1. The compact page heading and native safe navigation.
2. A prominent, stable top timer area with one concise current instruction.
3. Complete public identity and badge rails, grouped as You and Opponent.
4. A large You participant panel.
5. A large Opponent participant panel.
6. A persistent, state-aware readiness action area, separate from the participant imagery.

The timer and safe actions stay usable while the central stage scrolls. The rails belong at the top of that scrolling stage; they are not an indefinitely pinned wall that leaves no room for the participants. Every public battle badge remains visible in the document, wrapping naturally above both large players. No three-badge cap, hidden remainder counter, horizontal badge carousel, clipped label, automatic ticker, or hover-only badge meaning is permitted.

The You panel continues the person's authorized, device-local framing preview when the camera is active. The Opponent panel contains only the real permitted public avatar or a neutral silhouette, plus service-confirmed readiness. A silhouette is an honest privacy boundary, not a loading tease for a stranger's video. Both canvases have comparable visual weight and remain vertically ordered even on a very wide Mac display. No opponent live video, early pose still, previous-match body photo, audio connection, or chat is available here.

Large participants are favored over fitting everything above the fold. On short screens and large text, each panel remains a substantial full-column visual stop; the person scrolls instead of receiving two tiny portraits. Equal panel weight is presentation, not an assertion that a profile avatar and the local camera are comparable physique evidence. Information sits in panel headers or footers, never over faces, shoulders, limbs, or the framing needed for the poses.

This choice gives up simultaneous side-by-side scanning and a constantly moving waiting-room backdrop. It preserves body framing, owner attribution for every badge, a single obvious readiness action, and low idle energy use. Tactile feedback comes from real pairing, acknowledged readiness, and real countdown beats, not from looping intimidation or invented competitive progress.

## Visual Language and Concise Copy

Use the existing near-black background, dark card surfaces, orange action accent, white primary text, Inter Black headings, Inter Regular supporting text, established card treatment, and shared spacing. Orange marks an available action or confirmed readiness, not a predicted winner. The two players receive the same surface, matte, and framing treatment. Do not introduce purple web pills, brown achievement overlays, a new global theme, a transparent camera HUD over anatomy, or a second family of glass controls.

The single page heading is Ready room. The timer well is visually stronger than that heading. The normal instruction is Mark ready when set. After own readiness is confirmed, it becomes Waiting for opponent or Waiting for start according to the real state. The normal primary label is Ready; the acknowledged reversible state exposes Not ready. Secondary labels include Cancel match, Safety, Stop camera, Resume camera, and Retry only where those actions apply.

The pose protocol is a compact Three poses line with access to the existing guide. It does not repeat the full rubric, consent document, or safety form in the stage. The current camera state remains visible as Camera active or Camera stopped. A concise No live opponent preview explanation is available in the opponent panel and its accessible description; no fake camera-loading spinner suggests that video will arrive.

Retain necessary consequence, consent, recovery, and accessibility text even when it takes more than one line. Long real handles wrap; their complete value remains available without a tooltip. Rating units, provisional status, and badge definitions are not sacrificed to a word-count target.

## The Timer Is Honest

Before a service-authorized start schedule exists, the prominent timer well reads Start in with an em dash and the instruction Mark ready when set. The dash means that no countdown is running. Neither the ninety-second search limit nor the ninety-second capture period becomes a fabricated Ready-room deadline. This area introduces no arbitrary readiness timeout.

After both readiness actions are confirmed and the service authorizes a start, the well reads Start in and shows 3, 2, 1 at the shared scheduled times. Its digit position and surrounding layout stay stable. A client that receives a schedule partway through presents the actual remaining beat; it does not replay three seconds, slow the countdown for an animation, or send a new start request. Both players can be ready while the service is still checking authorization; that state says Waiting for start and retains the dash.

If a real pairing-reservation expiry is part of the reviewed service contract, its actual remaining time may occupy the same timer well under the explicit label Ready time left. It is not an estimate and cannot be introduced by this view. A confirmed reconnect grace uses the explicit label Reconnect; an unavailable grace deadline uses a dash and Reconnecting. Distinct intervals are never presented as an unlabeled number.

At an elapsed scheduled start without confirmed Go, the well becomes Start unconfirmed rather than Go. The app reconciles the same match and keeps local evidence capture inhibited. At confirmed Go, the same authoritative capture deadline belongs to the capture screen; a decorative Go label does not delay that handoff or create another ninety seconds.

A stale clock, interrupted connection, missing start authorization, or contradictory match state cannot continue a confidently presented countdown. Show Checking match or Reconnecting with the appropriate uncertainty. The service decides whether the match is still pre-Go, active, canceled, or ended.

## Identity and Complete Badge Rails

There are two clearly labeled owner groups above the participants, You first and Opponent second. Each includes the real permitted handle, an optional flag beside that handle, the correctly labeled match-time Physique Elo or Unplaced state, the actual provisional state where relevant, and the complete public battle badge collection supplied by F29-F. The same owner labels identify the player panels below. A badge is never visually attributed to both participants by floating between them.

The F29-F canonical badge order is retained. All earned launch achievements appear: First Bell, Placed when currently applicable, Ten Rounds, and Three Straight. Placed and the actual placed tier may share one composite presentation without losing either meaning. Truthful current streak is distinct from the historical Three Straight milestone. A current streak is not inferred from a badge, and the app does not show a tier for an unplaced or provisional account. No Ready-room action awards a badge.

F29-F owns eligibility and correction semantics. In particular, First Bell and Ten Rounds concern valid AI-judged results rather than forfeits or no-contests; the current placement count follows the rated-result rules of F29-C; Three Straight is a historical canonical streak achievement, not a promise of the current streak. Ready-room presentation must not recalculate these facts from cached history or editable local profile badge previews.

A confirmed empty badge collection contains no invented locked achievements. Unavailable or stale badge data is labeled Badges unavailable or Last confirmed rather than No badges. Keep the last permitted confirmed collection only for the same account and pairing; a correction or access revocation removes the affected claim immediately. Readiness is governed by the real match eligibility contract, not by whether an optional decorative badge fetch succeeded. Missing trusted match identity, rating context, or eligibility does prevent Ready until reconciled.

A flag means an optional manually chosen, self-declared country or region, not citizenship, residence, ethnicity, verified nationality, or a competitive division. If the person has not shared one, no flag is invented. If the glyph is unsupported, use a neutral region symbol with the readable permitted region name; accessibility always exposes the full region name and its self-declared meaning. No GPS, IP, device locale, photograph, or camera analysis selects a country. No flag filter, flag-based pairing preference, or country score is introduced.

Badge and identity details use the existing F29-F disclosure surface. They explain meaning and freshness without disclosing account email, private age or attire declaration, identity documents, exercise Elo, private match history, moderation reports, or subscription. A permitted public competitive summary is not permission to expose private account records. Profile photographs are not automatically uploaded or made public to fill this room.

## Native iPhone Composition

The room uses the app's existing navigation shell and measured content bounds. Cancel match remains at the leading safe navigation edge; Safety is directly reachable at the trailing edge with a visible or otherwise unambiguous accessible label. The compact Ready room heading does not repeat inside every panel. The large timer well stays at the top of the content surface below navigation, with enough separation that its digits cannot be confused with Elo.

The stage below scrolls vertically in the approved order: You rail, Opponent rail, You panel, Opponent panel. Badge rows wrap at their natural readable size. Player canvases use the available column width and a portrait-friendly envelope; the full camera frame is aspect-fit into a matte rather than cropped to emphasize a torso. A square or differently proportioned authorized avatar is also aspect-fit, not stretched to imitate a full-body capture. Player headers and readiness footers sit outside the image.

A safe-area action dock contains the primary Ready or Not ready control and the actual camera stop/resume control. Camera active remains visible even when the local preview has scrolled out of view, so scrolling does not conceal ongoing local acquisition. Scrolling alone does not mark Ready or Not ready, restart the camera, or create evidence. No still is selected or uploaded before Go. Offscreen image and decorative rendering stop; the shared camera owner performs only the local preparation work actually needed.

At large Dynamic Type or in landscape, labels and the dock reflow instead of clamping type or reducing the participant canvases to fill one screen. The central stage absorbs vertical overflow. Primary and safety actions keep the app's existing at-least-forty-four-point iPhone interaction convention. Existing floating controls and either navigation-menu edge are respected; there is no guessed home-indicator spacer.

A deliberate pre-Go back or dismissal uses Cancel match semantics. Pending cancellation may return to the existing lobby only with a visible pending-match state and no ability to start a second search. After confirmed Go, accidental swipe dismissal cannot bypass the explicit active-match exit. An app switch, lock, call, or permission interruption stops and shields the local camera immediately; returning does not silently become Ready again.

## Native macOS Composition

This is a native macOS 14-or-later window surface, not Catalyst, a web view, or a scaled iPhone full-screen cover. Preserve the existing normal title bar, traffic lights, WindowGroup behavior, and app-wide 800-by-600 minimum. Do not raise that minimum to fit both players.

Use a native toolbar for the Ready room title, Cancel match, Safety, and the optional Details inspector action. The prominent timer remains in the content header, not squeezed into a toolbar item. Center the scrolling vertical stage using the existing readable-column convention and measured window space. At the minimum window size, rails and full-size portrait-friendly player panels scroll below the timer; the action strip stays reachable. Short laptop windows must not put a participant beside the other, squeeze both into tiny cards, or pin a tall badge wall over the camera.

Large, full-screen, and external-display windows retain one vertical pairing column, You above Opponent. Additional width may reveal a native inspector containing already-owned badge definitions, pose protocol, or sharing information. It never contains a second opponent camera, an alternative horizontal matchup, new private records, or essential controls available only when the inspector fits. At narrow widths that information uses the same native sheet or popover route. Closing an inspector restores available stage space without resetting the camera, pairing, timer, or scroll position.

Live resizing and moving between displays preserve the participant order, aspect-fit imagery, scroll context, focused semantic control, and current service state. Badge wrapping is a layout change, not a new Ready event. Do not replay pairing motion, allocate another camera session, or reschedule Go during resizing or full-screen transitions. Pointer hover may change a control's ordinary native treatment or show supplementary help; it cannot be the only way to read a badge or find Safety.

Camera authorization uses the real macOS TCC state. Denied, restricted, absent, busy, and disconnected cameras have different explanations. Open System Settings is offered only when permission can be changed; Retry or the existing camera-setup route handles availability and device selection. External USB and Continuity Camera loss immediately clears the last live frame, stops acquisition, invalidates local readiness, and reconciles the same match. Reconnection never supplies a fake video, prerecorded rated file, extra allowance slot, or new countdown. A device switch before Go goes through the existing preparation owner and requires explicit Ready again.

Only the owning active window can acquire the camera or submit readiness for the account's one reserved or active match. Another window or device shows the actual existing-match state and the supported route to the owner; it does not start a parallel session, silently take over, or charge again. Minimizing, hiding, switching away, losing active ownership, or entering the background stops and shields acquisition and suspends decoration immediately. Returning checks the service before an explicit Resume camera and Ready action; elapsed service deadlines are not reset.

Retain Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O with their current app meanings. Existing commands must not become start-duel shortcuts. Return and Space activate only a focused semantic control, never a global Ready or capture action while someone types a report or uses another window. Tab and Shift-Tab follow the visual reading order and keep a visible native focus indicator.

Escape first dismisses the foremost harmless popover or sheet, respecting a meaningful unsent report draft. With no such surface, Escape invokes the state-aware Cancel match or active-match exit route; it never silently forfeits. Cmd-W and quit stop the camera promptly. A known pre-Go close requests cancellation without a fake loss warning. A known post-Go close uses the existing explicit active-match consequence confirmation where the platform permits. Unknown state is described as unknown and is not converted into consent to Forfeit and leave. Force quit cannot be prevented or confirmed and is handled as interruption, not proof of a voluntary rated loss.

## Independent Ready and Start Behavior

Ready is enabled only for the authenticated match owner while the room is active, the real pairing and eligibility are confirmed, required consent and rules are current, the selected camera is available, and local preparation remains adequate. A disabled state gives the specific repair action: Resume camera, Camera setup, Review sharing, Check match, or the existing account route. Merely arriving in the room, inspecting an avatar, granting a camera permission, or receiving the opponent's Ready does not mark this person ready.

The two player statuses remain independent. Initially each shows Not ready unless the current service state says otherwise. Pressing Ready gives immediate shared press feedback and an own Sending Ready status. A checkmark and the confirmed Ready label appear only after acknowledgement. The opponent's status changes only from their own service-confirmed action; their avatar loading, presence dot, or assumed elapsed preparation time is not readiness.

An acknowledged own Ready exposes Not ready in the persistent action area until Go. Withdrawing locally inhibits start and capture immediately and sends the corresponding change to the service. While unresolved, show Stopping readiness or Ready withdrawal pending, not a claim that the other device has already been updated. Repeated taps do not send competing start requests or create another match. A failed or ambiguous Ready operation reconciles the same pairing and offers a real retry only after its status is known.

When both are Ready but the service has not supplied a start schedule, keep Waiting for start. The service rechecks eligibility, block status, allowance, camera participation, and its judging policy before authorizing Go. Readiness is not a permanent permission that survives consent withdrawal, sign-out, inactivity, camera loss, or opening a consequential detail flow.

Opening Rules, Pose guide, identity/badge details, Safety, or Privacy deliberately disarms local readiness. If that surface covers the preview, stop acquisition before presenting it. The Mac inspector follows the same explicit reading boundary rather than allowing an unnoticed start while the person reads. The other person's confirmed Ready is not locally reset. On closing, restore focus and current state; resuming the camera and becoming Ready are explicit actions. During an already scheduled countdown, this interruption stops local participation immediately and requests the corresponding service update. The UI must not claim the shared countdown is canceled before acknowledgement or assume a late Go cannot occur.

At confirmed Go, hand off once to the existing first-pose capture surface with the same match and authoritative remaining capture time. Do not take an automatic still, upload a Ready-room snapshot, start another camera owner, or wait for a decorative Go animation. The service consumes the reserved allowance once at this boundary. A late-resuming client joins the actual active stage only if participation is still authorized; otherwise it shows the real ended or unavailable state.

## Cancel, Block, and Go Races

Cancel match before Go is a no-penalty operation and needs no alarming forfeit confirmation. Stop local acquisition and inhibit local start immediately, send cancellation for the existing pairing, and show Cancelling while confirmation is unresolved. Only authoritative confirmation means the reservation was released and no started match exists. A cancellation request is not itself permission to award a rated loss.

If cancellation reached the service before Go, return through the existing lobby with no Elo change, no consumed allowance, no rated history row, and no automatic replacement opponent. If Go won the race, say Match started. Cancel was not accepted in time. Offer Resume match and the separate explicit Forfeit and leave action under the active-match contract. The canceled-looking countdown never silently becomes a forfeit request.

Safety exposes separate Report identity and Block actions through their existing owners. Reporting does not automatically block, leave, change Elo, or create a no-contest. The report flow preserves its own sending, received, unsent, draft, and retry semantics; this room never displays Report received without a real receipt.

The pre-Go block confirmation says Block and cancel match and explains No rating change if canceled before Go and future pairing exclusion. Confirming immediately shields the permitted local opponent surface and sends the block/cancellation operation. A locally pending block is labeled Pending; cross-device exclusion is not claimed until confirmed, and another pairing cannot start while that protection is unresolved. The other player receives neutral match availability, not an allegation or the blocker's reason.

If the service confirms the block before Go, release the pairing with no rating or allowance cost. If Go occurred first, retain immediate protection and future-pairing exclusion, but explain Blocking does not leave this match. Show the actual active-match route and separate Forfeit and leave confirmation. A stale pre-Go confirmation must never be repurposed as approval of a rated loss. Block after Go is not an automatic forfeit, win, rerating, or no-contest. Service-established safety, invalid-evidence, or unavailable-service precedence remains unchanged.

## States, Actions, and Recovery

| State | Visible presentation | Available action and authoritative consequence |
| --- | --- | --- |
| Pairing restoration | Timer dash, Checking match, role-labeled safe panels; no invented handle, badge, or readiness | Reconcile the existing match; Cancel and Safety remain reachable; Ready is unavailable until required identity and state are known |
| Real paired room, neither ready | Complete rails, local preview when active, private opponent avatar/silhouette, independent Not ready labels | Ready only after current eligibility and preparation; Cancel has no pre-Go penalty |
| Opponent ready first | Only the opponent has the confirmed check and Ready label | Own Ready is still deliberate; no local three-second countdown begins |
| Own Ready sending | Own Sending Ready, unchanged opponent state, timer dash | Duplicate submission unavailable; Cancel, Stop camera, and Safety remain usable |
| Own Ready confirmed | Own check and Ready, Waiting for opponent when appropriate | Not ready is available; no rating, allowance consumption, or badge award |
| Ready not acknowledged or rejected | Ready not confirmed, or a specific private prerequisite reason | Reconcile before retry; do not assume accepted Ready or create a second match |
| Both ready, authorization pending | Two actual Ready states, Waiting for start, timer dash | Service authorizes or refuses; safe exit and withdrawal remain available |
| Service-scheduled countdown | Stable top 3, 2, 1, Starting, complete rails and two vertical participants | Cancel, Not ready, Stop camera, and Safety remain effective requests until the real Go boundary; visual zero is not authority |
| Start time elapsed, Go unknown | Start unconfirmed or Checking match; no automatic evidence capture | Retrieve same state; do not locally charge, forfeit, cancel, or declare no-contest |
| Not ready or details interruption pending | Immediate local camera/start inhibition; Ready withdrawal pending | Same pairing reconciles; no claim that shared start has already stopped |
| Camera stopped by person | Privacy-safe own panel, Camera stopped, specific readiness repair | Resume camera explicitly; new Ready after adequate preparation; Cancel remains pre-Go safe |
| Camera permission denied or restricted | Own neutral panel, correct permission reason, no stale last frame | Open Settings/System Settings only when actionable; otherwise return or existing support; no repeated system prompt |
| Camera absent, busy, disconnected, or preparation invalid | Specific camera or framing reason outside the canvas; Ready unavailable | Retry or existing setup, same pairing only if still service-eligible; no fake preview or rated library input |
| Required sharing/rules/eligibility changed | Specific private explanation, stopped acquisition, no confirmed usable Ready | Existing consent/account route or Cancel; no consent by countdown, public disclosure of the reason, or alternate-account bypass |
| Optional flag/avatar absent | Real handle, no invented flag, neutral region treatment where needed, privacy-safe large silhouette | Room remains usable if required match identity and eligibility are confirmed |
| Badges empty, stale, unavailable, or corrected | Honest empty collection, Last confirmed, Badges unavailable, or corrected rail | Existing detail/retry where supported; no fake locked badge, hidden earned item, or local achievement recomputation |
| Cancellation or block awaiting confirmation | Cancelling or Block pending; stopped own camera; immediate local protection | Check the existing operation; no new pairing or unconfirmed release claim |
| Pre-Go cancellation, block, opponent departure, or service expiry confirmed | Neutral Match canceled or Opponent unavailable | Existing lobby; reservation released once; no scores, Elo, started history row, or automatic requeue |
| Cancel/block/withdrawal arrives after Go | Match started with actual stage and safe opponent shielding where requested | Explicit Resume match or separately confirmed Forfeit and leave; no silent conversion of the earlier action |
| Offline or state uncertain | Reconnecting or Checking match; stale readiness is not live; no confident start numeral | Stop and shield acquisition; reconcile same match, Cancel request or supported return; no locally finalized outcome |
| Service-authorized reconnect | Named actual grace remaining when known; original start/capture timing remains authoritative | Resume same eligible match; the twenty-second grace extends no deadline and consumes no second slot |
| Grace elapsed or client timeout with no service result | Awaiting confirmed match status, not a client-invented no-contest | Check state or existing lobby pending entry; actual no-contest and restoration appear only after confirmation |
| Active match restored | Real active stage and time, not a replayed ready countdown | Handoff to existing capture/recovery owner; explicit resume and active-match exit semantics |
| Another window/device owns participation | Actual match state and Active in another window or device | Supported open/resume route; no second Ready owner, camera, reservation, charge, or silent takeover |
| Match ended, restricted, safety-aborted, or service unavailable | Actual neutral ended/unavailable state and permitted private explanation | Existing recovery/result/lobby route; no substitute peer, local score, or invented allowance restoration |
| Sign-out, account switch, or deletion | Cleared prior-account identity, camera, drafts, and private cached surface | Existing account or lobby route; stale callbacks cannot repopulate the old match |

No state quietly starts another search, uses the exercise allowance, creates an AI opponent, or turns a connectivity problem into a comparative physique judgement. Reopening or retrying restores the same match rather than repeating readiness, charging, or award effects.

## Accessibility, Focus, and Input

Reading order is heading, timer and current instruction, You identity/badges, Opponent identity/badges, You participant and state, Opponent participant and state, then the action area. Native navigation and persistent actions remain directly reachable. Group each identity and its badges by owner; hide decorative silhouettes from repetitive screen-reader output while exposing the participant's role and actual status.

Announce a real pairing, acknowledged own or opponent Ready, start authorization, cancellation, camera failure, protection pending/confirmed, and the Go handoff once when meaningful. Announce Starting in three seconds once for an ordinary full countdown; do not speak every timer tick or replay missed countdown beats after reconnecting. The current timer remains inspectable with its interval label and unit. Optional gentle haptics or an already-supported output cue may reinforce real beats; they require no microphone and do not replace text.

Keep the Ready control's accessible identity stable while its label/state changes, and announce pending versus confirmed status explicitly. Voice Control can invoke Ready, Not ready, Cancel match, Safety, Stop camera, and Resume camera by their visible labels. Switch Control and keyboard use the same semantic actions; there is no swipe-only exit, long-press-only safety control, hover-only badge definition, or global capture key.

Focus enters at Ready room. Ordinary incoming readiness or a badge refresh does not steal focus from a control, report, or details surface. An error associates its specific reason with the affected action. Closing details returns focus to the invoking badge or control if it still exists, otherwise to its owner rail or the stage heading. At the actual Go handoff, focus moves once to the first-pose instruction. If the service ends the match while a sheet is open, its existing owner presents that real transition without submitting a draft or activating a stale destructive button.

Support the largest text settings without clipping, horizontal badge scrolling, single-line handle requirements, or scaled-down legal text. Ready is distinguishable through a checkmark and text rather than orange alone; uncertainty has text rather than a dimmed check. Increased contrast uses readable surfaces and boundaries, not fine low-opacity strokes as the only state. Reduce Transparency replaces material effects with opaque dark surfaces while keeping the same hierarchy.

## Animation and Interruption Rules

| Trigger | Concrete motion and timing | Interruption and accessible/energy behavior |
| --- | --- | --- |
| Real pairing first appears | The two existing player-panel surfaces settle upward by at most half one shared spacing step while fading into place together over about 280 milliseconds, with gentle deceleration and no body zoom | Present real identities and usable actions immediately; reuse/reopen/resize does not replay the entrance; Reduce Motion uses at most a short opacity replacement |
| Button press | Existing shared tactile press treatment, with response 0.24 and damping fraction 0.88 | Semantic activation is independent of spring completion; disabled actions do not bounce; Reduce Motion removes scale |
| Confirmed Ready | Only the readiness mark gains a check with a 160-millisecond replacement and a single small settle no larger than 1.04 scale, complete within 200 milliseconds; panel outline changes over about 180 milliseconds | Pending Ready never receives the confirmed animation; a reversal goes directly to the latest real state without queuing; the person and camera geometry remain fixed |
| Real readiness revoked or preparation fails | State icon and text replace within 140–180 milliseconds; no player shake or red full-screen flash | Camera stop and local start inhibition occur immediately, before any motion; Reduce Motion is static or short opacity |
| Service-scheduled countdown beat | One current numeral appears at actual scheduled second boundaries, with a maximum 1.06-scale pop settling within 220 milliseconds and about 180 milliseconds of digit replacement in stable geometry | No animation completion schedules the next tick; late beats are skipped, not replayed; cancellation, uncertainty, or Go removes the old beat immediately; Reduce Motion uses static replacement |
| Confirmed Go | Reuse the stage's stable geometry while the capture instruction replaces the readiness state within about 280 milliseconds | Route, safe actions, and authoritative capture time update immediately; animation cannot delay capture availability or take an automatic still; Reduce Motion uses at most a short fade |
| Real badge, identity, or status revision | About 180 milliseconds for the affected label/mark only; wrapping settles without a badge celebration or auto-scroll | Corrections/removals take effect immediately; no badge wall pulse, re-award, or focus jump; resizing uses direct responsive layout |
| Pending network operation | Reuse the ordinary native activity indication only for actual pending work, beside explicit status | No simulated percent, rotating rank, predicted body score, or minimum loading duration; stop indication when request ends or surface disappears |
| Cancel, block, privacy stop, or inactive transition | Immediate shielding and camera stop; a harmless text acknowledgement may replace over about 140 milliseconds | Protection never waits for dismissal, a countdown pop, or a panel transition; no animation reexposes a protected frame |

The room deliberately has no continuous decorative ambient loop. At most one focal event is active; a countdown takes precedence over a readiness flourish, and the newest authoritative state interrupts older motion. No flashing, strobe, intimate-body scan, camera shader, provocative silhouette movement, losing-player shake, animated rank lottery, or implied winner is acceptable.

Pause offscreen decorative work, background/minimized/inactive work, and work in a non-owning window. Low Power Mode and elevated thermal pressure disable optional scale/settle effects before reducing functional readability. The service clock continues. Do not rebuild a camera, decode an avatar, remeasure a font, reflow the entire stage, contact a provider, or perform network work on each animation frame or timer digit update. Camera privacy stops and deadlines are independent of all animation lifetimes.

## Data, Privacy, and Service Invariants

Only a real, authorized pairing supplies the opponent. Required participation facts and readiness come from the trusted match authority; optional identity presentation comes from the permitted F29-F contract. Unknown does not mean zero, empty, ready, canceled, or verified. There is one account-wide reserved or active match and one camera/readiness owner across devices and windows.

Readiness is separate from permission and data-sharing consent. The room never asks for microphone, location, broad Photos access, contact access, health data, a personal model key, an identity document, or a body photo to prove age or gender. No new still evidence or opponent media is transmitted by this pre-Go surface. Every later transmitted candidate or selected still still requires local face obscuring, an exact outgoing preview, appropriate current consent, and fail-closed redaction under F29-D and F29-E. Bystanders remain invalid even when masked.

Handles, flags, Elo, placement, achievements, current streaks, and UI chrome never enter judge imagery or judge context. Capture uploads clean, appropriately redacted evidence rather than a screenshot of this stage. No live provisional appearance score, model confidence percentage, body-fat estimate, muscle measurement, or exercise score appears in the Ready room.

No pose-gallery permission is created by Ready or Go. Only a valid AI-judged win, loss, or draw with current authorization and an intentional View poses action can later expose moderated counterpart stills within their ordinary twenty-four-hour lifetime. Forfeits and no-contests never gain such a gallery. Blocking, removal, expiry, and consent withdrawal cannot be bypassed by an avatar cache, prior thumbnail, restored window, or copied link.

## Dependencies and Review Boundary

- [F29-A page and match flow](../DOCKS.md) supplies reviewed entry, preparation, native navigation, capture handoff, and recovery destinations.
- [F29-B AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) supplies judge blindness, valid-evidence meaning, and the absence of live comparative scores.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) supplies real pairing, independent rating/placement, reservation accounting, the authoritative Go boundary, and cancellation/reconnect precedence.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) supplies report receipt behavior, block protection, contextual safety, and before/after-Go consequences.
- [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) supplies current consent, camera/TCC lifecycle, sharing boundaries, protected access, and uncertain-state recovery.
- F29-F supplies trusted public identity, optional self-declared country/region, complete badge entitlement, canonical order, freshness, and corrections. The shared F29 visual/component owner supplies reusable timer, rails, participant stage, and action language; this room does not fork them.
- Real account/session foundations, reviewed match readiness/invalidation/start authorization, shared camera ownership, authorized HTTPS operation, service health, and operating moderation are prerequisites. A view is not independently shippable before these foundations are implemented and human-reviewed. Missing authority is not permission for a local timer, fake peer, or production fixture.

## Files and Ownership

- This DOCKS.md owns only the Ready-room product decisions.
- [The future F29-A-h implementation brief](../../../../prompts/F29-physique-duels/F29-A-h-phase-1-ready-room.md) owns the prospective connected implementation work, not a claim that it has begun.
- Prospective TimeMaster/Views/Physique/PhysiqueReadyRoomView.swift owns this composition inside the reviewed match journey. It reuses the integrated shared stage, identity/badge, timer, and native action controls instead of creating a parallel design system.
- Existing and future reviewed match routing, camera preparation/ownership, service presentation, safety, and identity owners remain responsible for their own screens and authoritative contracts. Their actual filenames must be discovered from the integrated implementation rather than assumed from this document.
- Existing TimeMaster/Utilities/Theme.swift, ProfileDesign.swift, and TimeMasterGlassControls.swift remain the style authorities. TimeMaster/App/TmaxApp.swift and TmaxCommands.swift remain the native Mac window and command authorities.

## References and Deliberate Deviations

- [Battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy/directness reference only. Its visible large timer and obvious participant identity inform this design; its side-by-side web layout, purple/brown pills, face overlays, people, footage, wording, and implied asset rights do not.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices: use the actual resizable window, large displays, menu commands, and precise keyboard/pointer input without changing the vertical pairing requirement.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback: motion is purposeful, brief, optional, and cancelable. The exact Ready and countdown timings here are product choices, not Apple requirements.
- Installed SwiftUI engineering and animation guidance informs stable view identity, scoped state-driven motion, accessible semantics, and pausing unnecessary work. Availability is checked against existing iPhone iOS 16 compatibility and native macOS 14; no deployment-target increase or assumption of 26-only glass, animation, or symbol APIs is authorized.
- The older F29-A desktop comparison and countdown proposals are intentionally superseded for this child by the explicit shared direction. No other competition, privacy, attire, allowance, or finality rule is changed by the composition.
