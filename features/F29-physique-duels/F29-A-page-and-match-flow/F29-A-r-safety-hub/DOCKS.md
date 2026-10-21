# F29-A-r — Safety Hub

## Purpose and Status

Safety is the native, private help destination for Physique Duels on iPhone and macOS. It gathers contextual reporting, the person's own cases, privacy controls, published operator support, and an inline blocked-player section. It remains reachable without opening a body image, starting the camera, buying anything, or having a match allowance.

This is product context and a future implementation design, not an implemented screen, accepted prototype, operational moderation claim, or human-verification record. The user approved an animated, minimal-text sports direction for both native platforms. The [page and match-flow parent](../DOCKS.md), [F29 parent](../../DOCKS.md), [safety policy](../../F29-D-safety-and-reporting/DOCKS.md), and [privacy policy](../../F29-E-privacy-and-service-operation/DOCKS.md) supply the shared behavioral boundaries.

This child owns the hub, its inline blocked-player presentation, and its confirmations and recovery feedback. It routes to the shared report form, private case center, privacy and sharing destination, account recovery, and state-aware match exit. It does not create alternate versions of those destinations, a support chat, a public case feed, a standalone blocked-player screen, or a new competitive authority.

## Chosen Composition and Tradeoffs

Use a calm safety bench inside the sports experience: one strong Safety heading, three unmistakable destination rows, one factual Support group, and Blocked players immediately below. A small shield symbol identifies the destination; it is not a reputation badge or a claim that an account is safe. Do not use a hero illustration, body-photo background, celebratory crest, or warning-red dashboard.

An inline blocked list is chosen over a separate manager. It keeps the protection that can be reversed visible beside the consequences and avoids another screen. The tradeoff is a longer hub for accounts with many blocks; ordinary vertical scrolling and incremental loading address that without shrinking rows or hiding the section behind a count.

Mac uses an in-window inspector when there is room for both readable safety content and the unchanged battle stage. A window-attached sheet is the compact-window alternative. iPhone uses a normal destination from the lobby and a full-height native sheet from an active match. This preserves context without pretending a stretched phone sheet is the whole desktop design.

Motion confirms a press, an expanded explanation, or a real service acknowledgement. There is no ambient loop in this safety surface. The quieter motion is intentional: safety must not compete with a live deadline or make protection look like a reward.

## Hierarchy and Visible Copy

The order is stable across platforms:

1. The existing match timer remains the top battle anchor wherever the stage is visible. If a safety sheet obscures that stage, a compact match-context strip at the top of the sheet exposes the same real time and current stage. The hub heading follows that context. Outside a match, there is no timer or fabricated matchup.
2. A contextual notice appears only when relevant: Camera stopped, Match continues, Awaiting confirmed result, Participation restricted, or a specific unavailable action. It explains the actual condition, not a generic reassurance.
3. The destination group contains Report a concern, My cases, and Privacy & sharing, with recognizable symbols and trailing navigation indicators. A contextual report can instead say Report this player, Report image, or Report explanation. Its accessible name also identifies the safe target. There is no unlabeled flag-only primary control.
4. Support shows the actual published operator contact, staffing hours and time zone, and published response expectation. Contact support is the principal action in this group. The address or public support URL is also readable and selectable, not hidden inside an unexplained icon.
5. Blocked players is an always-present inline section. Confirmed entries, unresolved local protection, loading, and failure occupy this same place. There is no separate Manage screen.
6. A short, permanently readable boundary states: Not an emergency service. For immediate danger, contact local emergency help. Any additional specialist resource is an actual operator-published link, not an invented telephone number or inferred location.

Use the existing near-black background, dark elevated surfaces, white primary text, readable secondary text, Inter hierarchy, shared orange action accent, and existing spacing and corner conventions. Orange identifies navigation or intentional action, not a positive moderation finding. Native danger styling is reserved for the relevant consequential action. A pending state always has words and an icon, not color alone. Privacy, retention, and current-match consequences may use additional lines; minimal text does not justify omitting them.

## iPhone Composition

From the lobby, Safety opens within the existing native navigation hierarchy. Back returns to the same Physique location and scroll position. The heading and destination rows precede support and the blocked list. Use one vertical content scroll, with full-width readable rows rather than a grid of small cards. The longest address, a multiline handle, and accessibility-size text must wrap without horizontal scrolling or a smaller text clamp.

From a live pairing, capture, upload, or judging context, use an opaque full-height native sheet. Only its large presentation height is offered: report navigation and the blocked list need reading space, and a half-height panel must not leave a camera or body image showing underneath. Stop camera acquisition and cover sensitive underlying content before the presentation starts. The top match-context strip and Return to match remain reachable while the hub scrolls. A separate Exit match action invokes the existing state-aware exit flow; it is never the sheet's default dismissal action.

Close, a permitted downward dismissal, or an accessibility escape closes Safety only. It does not cancel a pairing, submit a report, confirm an unblock, restore camera acquisition, reopen poses, or forfeit the match. The enclosing active-match surface remains protected against accidental dismissal. When a routed report or privacy flow has meaningful unsaved input, its existing draft/consequence guard handles dismissal; the hub does not silently discard it.

Report, case, and privacy destinations use the existing safety navigation host rather than stacking a second custom sheet above this one. Native system confirmations are not redesigned as custom cards. The match-context host retains access to real timing and safe return while its child destination is shown.

Respect the app's measured safe content bounds, either navigation-menu edge, keyboard appearance in routed forms, and forty-four-point iPhone safety targets. Scrolling remains available on short phones, in landscape where supported, and at the largest text settings. Keep return and exit targets separated so a thumb cannot turn a close into a rated departure.

## Native macOS Composition

This is a native macOS 14-and-later surface in the existing normal-titlebar WindowGroup, not Catalyst, a browser frame, or an enlarged phone layout. Keep the app's existing 800-by-600 minimum; do not increase it to accommodate this hub.

From the lobby, Safety is a readable in-window destination with the normal Back toolbar action, a native Refresh action when useful, and the same clear section order. From an active battle, open a trailing inspector only when measured available space permits both a readable inspector and large, vertically ordered player panels. Otherwise use a window-attached native sheet with its own vertical scroll and Close control. At the existing minimum and in short laptop windows, the sheet is the deliberate compact presentation, not an inspector that squeezes the athletes.

The visible battle composition always remains real timer first, all authorized public identity and badge rails grouped by owner below it, then two LARGE VERTICAL player panels, You above Opponent. Both rails precede the player panels. They wrap to expose every public badge; no three-badge cap, hidden surplus, clipped rail, hover-only description, or horizontal ticker. A tall stage scrolls rather than shrinking both people into thumbnails. Wider, full-screen, and external-display windows never change the players into a side-by-side comparison. The inspector is supplementary information beside that vertical stage, not a third participant or a compact replacement scoreboard.

Opening Safety stops local capture and replaces exposed body media with privacy-safe placeholders immediately, including in a nonmodal inspector. Before finalization the opponent remains an authorized avatar or neutral silhouette plus real stage/count information, never a live stream or early pose. Where a block or restriction removes identity access, use the neutral identity placeholder instead of retaining the player's badges as a privacy leak. This changes authorized content, not the vertical hierarchy or comparison scale.

During live resize, content reflows without animated size changes, cropped warnings, or duplicate controls. Moving between inspector and sheet preserves the same navigation location, blocked-list scroll position, request status, and focused semantic item. It must not send an action again or replay an acknowledgement. Do not switch presentation back and forth on every resize frame. Full screen, a different display scale, or moving the window to another display does not reactivate capture or acquire another camera.

Use native pointer hover, focus rings, selectable public contact text, and normal keyboard traversal. All actions are visible without hover or a context menu. The title bar and other app windows remain usable under normal macOS modality. A secondary window may show authorized safety data but cannot claim a second active match, camera, reservation, or allowance charge. Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O and their current meanings.

Command-W or quit from the owning active-match window requests the existing stage-specific departure confirmation where macOS permits it. Closing just the inspector or Safety sheet does not. Closing a secondary help-only window is not a forfeit of another window's match. Force quit, a process crash, or loss of power cannot be intercepted as consent to a voluntary forfeit.

## Entry and Destination Contracts

Safety is discoverable from the lobby and current match safety action, and from permitted profile, result, unavailable-media, history, rejection, and restriction contexts. None requires image enlargement or a long press. Opening the hub carries the existing safe match, participant, pose, explanation, or decision reference; it does not attach the currently rendered screen or a photo.

Report a concern opens the canonical report intake. A supplied context is already identified using safe text. Without a supplied target, that same intake's existing target-selection state uses permitted match/reference information; it is not a new hub-owned player search, public report feed, or image browser. A general concern with no match uses the supported safety/support route. Do not fabricate a target or make a visible report button lead to a dismiss-only alert. Scoring disagreement routes to Request scoring review through the shared match/case flow, not to a nudity accusation.

Beginning an image report immediately hides that image for the reporter before the report flow appears. It does not submit the report, create a hold, or enlarge the image. Leaving or cancelling a form does not force the image back into view. Report receipt, uncertain receipt, draft lifetime, and additional safe information remain the report owner's responsibility under F29-D and F29-E.

My cases opens only the current account's case center. An actual received case, restriction notice, or action-required status may be summarized in concise text. No invented zero, unread count, review percentage, public report tally, or allegation badge fills an unknown state. The hub can show a safe pending-submission notice without calling an unsent draft a case. Cases do not require a subscription or a remaining duel slot.

Privacy & sharing opens the existing feature privacy destination, including actual consent, withdrawal, shared-image removal, and in-app account-deletion access. Reading it does not withdraw permission or start deletion. The privacy destination handles each explicit consequence; the hub does not replace in-app deletion with an email link. Declining Physique consent or adult-ineligible participation does not remove text-only support and allowed safety access.

## Published Support and Urgent Help

Support information must name the real responsible operator, a working public contact method, actual staffed hours and time zone, and the operation's published response expectation. Expand the longer legal contact information through the existing privacy/policy link, but keep the primary contact and staffing facts in the hub. Do not claim continuous staffing, an immediate human response, or a specific service-level promise from a planning target in F29-D. A receipt is automated acknowledgement, not proof that a reviewer is present.

Published contact information is available signed out, while account restoration runs, during an account restriction, and when the judging or report service is unavailable. Retain the last reviewed public contact information for offline reading, clearly identifying its last update when its freshness is uncertain. This public information is not copied from the last account's private case cache.

Contact support opens the actual published HTTPS support destination or supported system mail composition for a published email contact. Show the destination before leaving the app. Opening a browser or composer is not a report receipt or proof that a message was delivered. Public contact text can be copied explicitly if opening fails, there is no configured mail application, or the person prefers a different channel. Copy feedback is local and modest. Do not append photos, case correspondence, tokens, logs, private declarations, or a match/case reference automatically. A permitted reference can be copied separately at the person's explicit request.

Leaving for external help immediately stops/shields camera and sensitive surfaces; on return the same authoritative match state must be restored before any optional capture resumption. The service clock has continued. No flag, country selection, IP address, locale, or camera image determines an emergency number. Urgent guidance does not auto-dial or ask the person to confront, screenshot, forward, or reupload suspected unlawful content.

If actual operator contact or staffing information has not been supplied, it is a release-readiness gap, not license to ship an example address or fake chat agent. Show the specific unavailable public information honestly; any real remaining public policy/contact route stays usable. New public rated participation must remain unavailable until the operational safety prerequisites exist.

## Inline Blocked Players

### Rows and authority

Blocked players is visible below Support even when empty or unavailable. Each row uses a neutral person/protection symbol, the permitted safe display identity or Unavailable player, a concise real protection status, and a separate visible Unblock action. Do not fetch an avatar, body photo, biography, country flag, tier, achievement wall, or report history merely to render this list. An abusive or withdrawn name becomes safe neutral text. A row does not open a profile or poses.

Show confirmed account blocks and distinguish any local protection awaiting confirmation. A local-only entry says Hidden here · Block not confirmed, not Blocked everywhere. The list is account-scoped and shared through the real service. Ordering is stable by confirmed block recency when available; unresolved actions remain visibly associated with their original row instead of jumping with every refresh. Do not expose a total unless the service actually supplies a complete total. Load subsequent pages inline through Load more; a page failure retains loaded rows and offers a row-level Retry. There is no arbitrary display cap and no separate blocked-manager route.

Only a successfully loaded empty collection says No blocked players. A loading failure, inaccessible page, signed-out state, or expired session is not an empty collection. The person can read public help and use other allowed safety routes while the list is loading or an individual request is pending.

### Contextual Block

When an entry carries a real permitted player target, offer the shared Block player action beside the contextual reporting access. If already blocked, show the current protection state and move the person's explicit management action to the corresponding inline row. Without a real target, there is no generic username lookup or fabricated Block button.

The native confirmation explains the service stage at the time it is shown. Before Go, blocking excludes future pairing and cancels this pairing without rating change. After Go, blocking shields media and excludes future pairs but does not leave, finalize, or rerate the current match. In a final result, it removes paired-gallery access and preserves the lawful result with neutral player presentation. Block and Report remain separate choices.

On explicit confirmation, local shielding takes effect before waiting for the network. Pending service acknowledgement is labeled. Another pairing cannot start while required block state remains unresolved. Cancellation of the confirmation sends no block. Closing Safety never removes the shield or silently resubmits the action. A pre-Go confirmation cannot become an implicit forfeit if Go won the service race; show the now-current after-Go consequence and never infer consent to leaving.

### Explicit Unblock

Unblock is a button, not a switch, swipe gesture, row tap, bulk selection, keyboard delete action, or disappearing undo toast. It opens a native confirmation titled Unblock this player? with safe identity context. The concise consequence is: Future pairing may be allowed. This will not contact them, rematch, or reopen poses. For the current opponent, add that the current match continues and leaving is separate. Buttons are Cancel and Unblock. Do not assign a global default Return action or focus the consequential action automatically.

Unblock becomes pending only after explicit confirmation. Disable repeat mutation for that row, not the whole hub. Keep the local shield and last confirmed block visibly in place until the service confirms the current state. The normal blocked collection does not optimistically remove the row. If offline is already known, show Connect to unblock and explain that the confirmed block remains; do not queue an automatic future unblock.

A successful service update, including an authoritative status check resolving a lost acknowledgement, removes the row and shows a persistent inline Player unblocked acknowledgement until the next relevant action or navigation. It means only that this person's block was removed. Other eligibility, mutual-block, consent, restriction, expiry, and media permissions still apply; do not reveal whether the other account has blocked this person.

If the request is known to have failed, retain the row and offer Retry with the reason that is safe to disclose. If receipt is uncertain, say Unblock not confirmed · Protected here and offer Check status for the same action. Do not assert remote pairing protection is unchanged when the request may have succeeded. Do not blindly send a second mutation or automatically replay it on connectivity return. A retry after a definitively unsuccessful action requires the same explicit unblock intent, with a new confirmation if target or consequences have changed.

Unblocking restores no body image, avatar cache, hidden image, gallery, contact, old link, match, or expired media automatically. A later fresh View poses action can request only currently authorized, unexpired media from a valid AI-judged result; an image separately hidden by the person still needs its own explicit View again action where allowed. Report quarantine, removal, withdrawal, or other access denial always wins. Forfeits and no-contests still have no opponent gallery.

## States, Actions, and Recovery

| State | Visible presentation | Available action and consequence |
| --- | --- | --- |
| First public entry | Safety heading, real public support and urgent boundary; account-specific areas identify sign-in requirement | Read support, privacy policy, or enter existing account recovery without camera activation |
| Restoring account | Public information remains; private rows show Restoring account without the prior account's content | Wait or use public help; no private action is sent under a guessed identity |
| Loading blocked collection | Stable section heading, Loading blocked players, native activity feedback | Public help and permitted report/case/privacy navigation remain usable; no false empty state |
| Confirmed empty list | No blocked players | Other safety actions remain available; no example users |
| Loaded collection | Safe identities, actual protection states, visible per-row Unblock | Native explicit confirmation; no profile or media opening |
| Loading more | Existing rows and one inline loading area | Continue using loaded rows; no duplicate entries or jump to top |
| Additional page failed | Loaded rows remain and a concise unavailable-page notice appears | Retry the failed page; do not claim the collection is complete |
| Refreshing known data | Last confirmed rows retained with visible freshness state | New authority replaces old data; no false success or clearing of blocks |
| Offline | Last confirmed public contact and permitted protected block metadata are labeled as such | Copy/read contact, keep local shielding, explicit Retry when connected; no new pairing under unresolved protection |
| Block confirmed locally but not by service | Hidden here · Block not confirmed on the contextual entry | Check status or the supported explicit retry; no claim of cross-device protection |
| Unblock confirmation | Safe target and exact consequences in native confirmation | Cancel does nothing; Unblock sends this authorized action once |
| Unblock in flight | Row retained, Unblocking, repeat action disabled | Close/navigate safely; no premature removal or restored media |
| Unblock receipt unknown | Unblock not confirmed · Protected here | Check the same action's authoritative state; no blind duplicate or automatic retry |
| Unblock known unsuccessful | Specific safe failure beside the row | Retry where permitted; support remains available |
| Unblock confirmed | Row removed, concise persistent acknowledgement | No rematch, camera restart, contact, or media restoration |
| Target deleted, renamed, or no longer displayable | Current safe name or Unavailable player; original authorized block association retained | Unblock only if the service still permits it; never reveal a replacement identity or internal identifier |
| Private collection temporarily unavailable | Last confirmed permitted data or a specific unavailable section, never a fake empty list | Retry and published support; other functioning sections remain usable |
| Report/case service unavailable | Specific intake or status-unavailable message | Shared report owner retains only allowed text draft; published support and immediate local protection remain reachable |
| Account restricted or age-ineligible | Private scope/reason and end time only when actually known; no body content | Own decision/appeal, allowed reports, privacy and public support remain reachable without new rated entry |
| Mutation forbidden by real account policy | Unblock unavailable for this account, with permitted safe explanation | View own decision or contact support; do not invite an alternate-account bypass |
| Session expired | Private rows, requests and sensitive drafts cleared from this surface; public support stays | Sign in to the existing account; do not replay a prior account's mutation |
| Wrong-account or unauthorized case link | Generic unavailable private record | Existing account recovery or public contact; do not confirm someone else's case or block |
| Active match changes while help is open | Actual new stage/finality in the context strip, with no modal interruption for ordinary progress | Return to that same match or permitted final result; a finalized result is not a reason to close help automatically |
| Public support link cannot open | Contact text remains visible, with a concise opening failure | Explicit Copy contact or another actually published channel; not a fake Sent receipt |
| Support publication missing or stale | Exact availability/freshness notice; no made-up address, hours, or response promise | Use any real remaining public channel; participation readiness follows F29-D/E |

## Active Match, Camera, and Window Lifecycle

Opening or closing Safety is not a match exit. Before Go, entering a camera-stopped safety surface withdraws local Ready and informs the authoritative match owner so an unattended countdown cannot authorize capture. Pairing and search state remain service-owned; their genuine cancellation, expiry, or Go race is shown rather than invented by the hub. Any later Ready is explicit.

After Go, stopping acquisition is immediate. The shared capture deadline and twenty-second reconnect grace continue without extension. Do not create a second safety countdown or restart the ninety-second period. Opening help does not guarantee that valid capture can still finish; explain the real opportunity to return. If both sets are already received, service judging can finish while help remains open. A block, report, support launch, or case lookup cannot manufacture a no-contest, free win, or Elo reversal.

Return to match first refreshes the same authoritative state. If eligible capture remains, show a protected stopped-camera panel with an explicit Resume camera action owned by the capture flow. A disappeared camera, denied macOS TCC/iPhone permission, external webcam disconnection, or Continuity Camera interruption shows the actual reason and the existing Retry or Open Settings route only when useful. Safety itself does not request camera access, switch sources, open a file picker, show a fake preview, or submit prerecorded rated evidence. Resume never silently rebuilds capture, restarts a self-timer, uploads another original, resets retakes, or consumes another allowance slot.

Return to a result keeps its poses closed, including when Safety was opened over a viewer. It preserves legitimate Hide and Report choices. Neither an unblock, successful appeal, foreground return, relaunch, nor a new window automatically opens media or renews its original twenty-four-hour lifetime.

Backgrounding, locking, minimizing, window inactivity, permission withdrawal, account switch, and sign-out stop acquisition and obscure camera, body media, report text, and private safety details immediately. Published public contact can remain non-sensitive. A returning window rechecks identity, match authority, pending actions and access before display. Decorative motion does not catch up or replay. The same account has at most one active match and one camera owner across windows/devices; a help window cannot seize either.

Exit match is separate from Return and Close. Before Go it requests actual cancellation without rating/allowance loss. After Go it invokes the existing explicit Forfeit and leave confirmation only when that is a valid possible consequence. A service-established safety, invalid-evidence, or unavailable-service no-contest has precedence. If authority cannot be confirmed, keep the status uncertain; never convert a close gesture, lost connection, expired permission, or force quit into a confirmed voluntary forfeit.

## Focus, Keyboard, and Accessibility

Opening Safety moves accessibility focus to its heading or the active critical notice. Reading order is context/timer, heading, relevant notice, Report, My cases, Privacy & sharing, Support, Blocked players, and urgent guidance. When the stage and inspector are both visible on Mac, the existing stage timer remains the single timer focus element; do not create a second rapidly changing announcement.

Each blocked row has a unique accessible target name such as Unblock this player, followed by the permitted safe handle when available. Unavailable-player rows remain distinguishable using safe supplied context, not a spoken private identifier. Names and addresses grow naturally. No hidden-content description, old photo caption, intimate body description, moderation allegation, country inference, or untrusted text is read as a substitute.

Use standard semantic links and buttons, visible focus rings, section headings, persistent error/status text, adequate contrast, and native selection of public contact information. VoiceOver, Voice Control, Switch Control, full keyboard access, and silent operation expose the same actions. No important action requires hover, swipe, right-click, sound, or haptics. Increase Contrast and Reduce Transparency retain readable opaque protection and status surfaces.

Tab and Shift-Tab traverse the native controls in reading order. Return or Space activates only the focused semantic control; neither is a global unblock, forfeit, capture, or report shortcut, and typing in a routed note retains normal editing behavior. Escape or Command-period first cancels the current native confirmation, then follows the routed destination's draft guard or closes the help surface. It never cascades through both confirmation and match exit in one key event. On iPhone, accessibility escape has the same safe meaning.

Confirmation opens with its target and consequence available to read; no automatically focused consequential button and no assigned default Return shortcut. On cancellation, return focus to its row. If a successful unblock removes the focused row, move focus to the next surviving row's safe action, or to the Blocked players heading and acknowledgement when none remain. If the person has moved elsewhere while a request resolves, announce the meaningful result without stealing focus or jumping the scroll position. Closing Safety restores focus to the invoking safe action or its current placeholder, not a removed image or disabled capture control.

Announce real loading failure, confirmed protection changes, and newly relevant restrictions once. Do not announce every timer second, spinner frame, partial list refresh, or animated intermediate value. A time value remains inspectable on demand. No help information or decision disappears on a short toast timeout.

## Animation Rules

| Trigger | Motion and timing | Interruption and safety | Reduced motion and energy behavior |
| --- | --- | --- | --- |
| Press/release on existing shared controls | Existing response 0.24-second, damping 0.88 press spring; no second custom bounce | Release does not trigger twice; state and privacy action never wait for settling | Remove scale with Reduce Motion; native focus/pressed contrast remains |
| Open/close native iPhone or compact Mac sheet | Native presentation transition; no extra camera-to-sheet zoom or second content slide | Shield/stop occurs first; dismissal returns only to the same protected parent | Respect native Reduce Motion; no animation keeps capture alive |
| Open/close roomy Mac inspector | One restrained approximately 280-millisecond ease-out reveal or 260-millisecond dismissal where the existing host permits | Content is usable immediately; fast reversal starts from the current visual state; no stage image is exposed during travel | Immediate placement or at most 100-millisecond opacity change; no travel under Reduce Motion |
| Actual loading, failure, restriction, or request-status change | Icon and concise status crossfade over 160–180 milliseconds | Latest real state replaces an interrupted transition; no fake minimum loading duration | Immediate/static text or at most 100-millisecond opacity; low-power/thermal limits remove nonessential repeated activity motion |
| Explicit longer support explanation disclosure | Native disclosure with approximately 180-millisecond ease-out content change | Primary address, staffing facts and urgent boundary never depend on this disclosure; no automatic collapse | Immediate layout; keep information and focus identical |
| Confirmed block | Protection appears immediately; a small confirmation symbol may settle once within 180 milliseconds | Shield precedes all visual feedback; no victory effect, body shake, or pending-as-success state | Static symbol and text; no haptic or animation dependency |
| Confirmed unblock | Row opacity exits over about 180 milliseconds and surrounding rows settle within 240 milliseconds total | Confirmed state and safe focus are set immediately; rapid navigation cancels travel, not the acknowledgement or authority | Immediate removal or short opacity only; no list travel with Reduce Motion |
| Explicit Copy contact | Existing shared press feedback and local Copied text/icon change over about 140 milliseconds | This means clipboard copy only, not support delivery; no auto-copy on entry | Immediate text change; no sound required |
| Timer while an active sheet obscures the stage | Existing real timer digit change about 180 milliseconds with stable digit geometry | Same service deadline; no reset, artificial grace, flashing final seconds, or per-tick accessibility announcement | Immediate digits with the same accessible time value |
| Live resize or inspector/sheet migration | Immediate measured reflow; no animated width/height pumping | Preserve current navigation, focus, list position and pending action; no duplicate requests | Same static behavior; no decorative work during resize |

There is no shimmering placeholder, badge pulse, rotating warning wall, confetti, scanning body effect, or ambient camera shader. At most one focal feedback event runs; ordinary activity feedback must not become a competing celebration. Offscreen, background, minimized and inactive surfaces stop decorative work. Restoring focus or reopening the hub does not replay past confirmations. No per-frame service request, disk access, image decode, camera creation, font measurement, or whole-stage layout refresh is justified by this motion.

## Data and Privacy Invariants

The service owns block authority, private case visibility, account restrictions, match stages, deadlines, finality, and competitive records. The hub may protect the local display immediately but must not call remote protection, report receipt, withdrawal, deletion, or an unblock complete before confirmation. One pending operation remains the same operation after recovery, not an extra case, match, charge, or rating effect.

Use only necessary safe player/reference metadata in the blocked list and protection state. No raw or derivative pose media is required for hub entry, list loading, contact opening, a report draft, or case summary. Account-specific cached data is protected and cleared appropriately on sign-out/account switch; public support publication is separate. Do not put case text, allegations, block lists, private declarations, credentials, or pose images in diagnostics, notifications, public badges, clipboard content without explicit choice, or support-link query strings.

All country and earned-badge presentation remains owned by the shared identity/badge area. An optional country is self-declared, not verified, located, or inferred. Local cosmetic previews are not trusted achievements. Where the battle stage is present, show every currently authorized public badge above the two large vertical players; the hub itself does not add a safety-goodness, no-reports, or verification-looking badge. Identity chrome, country, reports, blocks, and UI screenshots never become judge input. Face obscuring remains fail closed before every transmitted candidate/still; the hub does not weaken that capture contract.

A block or report does not erase an otherwise valid loss. An unblock or successful review does not restore removed or expired media. Ordinary galleries require intentional View poses, current authorization and a valid AI-judged win/loss/draw, and ordinarily expire twenty-four hours from finalization. Necessary lawful case evidence is not a participant gallery; the bounded report hold and separate legal-safety exceptions remain F29-D/E policy, not a promise of unlimited photo retention. Do not ask people to attach unlawful material, reveal sex/gender or age through a body image, or supply a personal judge key to obtain help.

## Dependencies and Files

Real shared account/session, navigation, authoritative match lifecycle, protected-media access, block management, report intake, cases, privacy controls, and operational support publication must be implemented and human-reviewed before this native view is independently connected for release. Existing CYCLES review gaps remain real. A polished view or preview fixture is not the missing service. Missing contact/staffing facts or unavailable authenticated block authority cannot be replaced with mock production data.

Product ownership and references:

- [F29-A page and match flow](../DOCKS.md) owns entry, safe match navigation, capture ownership, responsive stage and destination routing.
- [F29-B AI judging](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns accepted evidence, judge blindness and valid scores; this hub never submits judging input.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns block exclusions, Go, allowances, finality and corrections.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) owns reports, blocks, case decisions, appeal policy, published staffing and urgent/legal handling.
- [F29-E privacy and operation](../../F29-E-privacy-and-service-operation/DOCKS.md) owns permission, withdrawal, deletion, bounded drafts, access and data lifetime.
- [Future safety-hub implementation brief](../../../../prompts/F29-physique-duels/F29-A-r-phase-1-safety-hub.md) owns the authorized future work slice; it is not current implementation evidence.
- Prospective TimeMaster/Views/Physique/PhysiqueSafetyHubView.swift contains this one hub and its feature-local inline blocked section; actual established feature files take precedence over a duplicate convention.
- The existing or prospectively shared TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift provide reviewed presentation state and authenticated authority. This child does not independently invent their contracts or a new moderation service.
- [Theme](../../../../TimeMaster/Utilities/Theme.swift), [Profile design](../../../../TimeMaster/Utilities/ProfileDesign.swift), [shared controls](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift), and [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) provide visual patterns, not permission to copy text-size clamps, fake levels, or a new global theme.
- [Native app scene](../../../../TimeMaster/App/TmaxApp.swift) and [commands](../../../../TimeMaster/App/TmaxCommands.swift) constrain Mac window and shortcut integration.

## Reference and Reconciliation Boundaries

The [supplied battle image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) supplies timer prominence and direct sport actions, not its side-by-side bodies, overlay pills, faces, text or rights to reuse them. No art is generated or asserted to exist here.

The shared F29-A direction requires two large vertical players at every width, with all authorized public badge rails above them. A safety inspector may sit beside that stage; it cannot turn the participants into side-by-side cards or reduce native Mac to deferred phone-first polish.

Public operator contact details, staffed hours/time zone and actual response expectations are not supplied by the existing product context. They are required operating facts for future connection, not a decision this UI document can invent. General numerical service targets remain proposed/unmeasured unless the owner has separately established them. The residual App Store objectification risk in F29-D is not resolved by this hub.

Native guidance for the chosen design:

- [Apple HIG — Designing for macOS, Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos): readable desktop density, resizable/full-screen windows, keyboard and menu integration. The inspector-versus-sheet choice is this product's application of those principles, not an Apple-mandated exact layout.
- [Apple HIG — Sheets, Best practices and platform considerations](https://developer.apple.com/design/human-interface-guidelines/sheets): one scoped sheet at a time, normal navigation/dismissal, full-height content where useful, window-specific Mac modality.
- [Apple HIG — Alerts, Buttons](https://developer.apple.com/design/human-interface-guidelines/alerts): concise consequences, specific action titles, Cancel, and no default button when deliberate reading is important.
- [Apple HIG — Motion, Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion): brief, purposeful, optional, interruptible feedback. Protection and service state never wait for animation.

The installed SwiftUI engineering, accessibility, navigation, performance and animation guidance informs future implementation. Keep iOS 16 and macOS 14 compatibility and public availability fallbacks; do not require 26-only glass or newer animation APIs, raise a target, or add private API merely to implement this design. No separate STYLES file or parallel UI theme is required.
