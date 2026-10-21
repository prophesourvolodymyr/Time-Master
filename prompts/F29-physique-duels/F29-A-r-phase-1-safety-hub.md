# Phase 1 of F29-A-r — Native Safety Hub

## Model Assignment and Execution Mode

Assigned development worker: **openai-codex/gpt-6.1-sol:max**. Model is **openai-codex/gpt-6.1-sol**; **max is the thinking level**, not a different model or an in-app judge. Do not silently substitute another worker or thinking setting. If the requested dispatch is unavailable, report that exact limitation before representing the work as executed by this assignment.

This is a future implementation brief produced during a documentation-only design batch. It does not authorize code, tests, builds, generation, or publication during that batch. Execute the implementation directions below only after the real shared prerequisites are implemented, human-reviewed, and the owner authorizes this connected slice. No production implementation, approved prototype, actual support operation, or native verification is claimed by this brief.

## Features Included

- F29-A-r — Safety hub on native iPhone and native macOS.
- Hub entry and context continuity from the existing lobby, match, media, result, rejection and restriction routes.
- Real published support and urgent-help boundary, plus clear report, private-case and privacy access.
- Inline blocked-player collection, contextual Block, native explicit Unblock, and authoritative pending/failure/receipt recovery.
- Safe match return, immediate camera/media shielding, focus, keyboard, accessibility and energy behavior for this hub.

These are parts of one owned feature, not independent substitute report, case, privacy, capture or moderation implementations. List the meaningful items separately in the human-review handoff and update only their actual F29-A-r implementation todos in CYCLES.md.

## Context

Build the compact Safety destination defined in features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-r-safety-hub/DOCKS.md. The user requires both native platforms, minimal-text tactile sports UI, timer-first battles, every public badge above two large VERTICAL players, and real privacy/service authority. The preceding batch produces specifications and future prompts only; it does not implement or verify these surfaces.

## What You Need to Read First

Read the complete product child, then the relevant policy sections and actual shared implementation. DOCKS files are plain-language product context, not unquestionable technical recipes.

Exact product paths:

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-r-safety-hub/DOCKS.md — this complete native composition, state matrix, confirmation/recovery and motion contract.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — shared stage, entry, capture, safe exit and navigation ownership; follow the newer vertical-only user decision if older composition text remains.
- features/F29-physique-duels/DOCKS.md — competition boundaries and the distinction between user-directed behavior and proposed numerical defaults.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — Safety Access, Hiding, Reporting Interaction, Blocking Before and After Go, Private Case Status, Appeals, Published Staffing and Urgent/Legal Handling.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — consent withdrawal, camera lifecycle, protected access, bounded text drafts and media, deletion and public operator accountability.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — one-account/one-match authority, block exclusion, Go races, explicit cancellation/forfeit, reconnect and exactly-once effects.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — judge blindness, accepted evidence, no medical/identity inference and no unsupported score authority.
- features/DOCKS.md — feature ownership and dependencies.
- CYCLES.md — current F29 implementation and human-review boundaries; do not infer review from a checkbox or an automated check.

Exact source anchors, re-locating their symbols if earlier work changed line numbers:

- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228 — shared palette, surfaces and native actions.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38 — scaled Inter type, spacing, forty-four-point iPhone action convention and readable content width.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80 — public material availability fallback, Reduce Transparency and the shared response-0.24/damping-0.88 press feedback.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188 — shared close/action/metric and earned-rating visual language. Do not copy its text-size clamps or treat a cosmetic display as trusted achievement.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151 — existing exercise HUD patterns only; Physique has no live provisional appearance score.
- TimeMaster/App/TmaxApp.swift, lines 8–19 — native Mac WindowGroup, 800-by-600 existing minimum and normal title bar.
- TimeMaster/App/TmaxCommands.swift, lines 6–37 — preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109 — local cosmetic badge previews are not verified identity or service-earned competitive badges.
- TimeMaster.xcodeproj/project.pbxproj — actual iOS 16/macOS 14 compatibility and current target membership. Do not raise targets or assume 26-only API availability.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the image itself. Borrow timer prominence and direct actions only, not faces, images, text, side-by-side layout or web pills.

Discover the actual reviewed Physique match coordinator, account/session owner, camera owner, route host, report intake, case center, privacy destination, block operations and public support publication in the repository before editing. They are prerequisites, not files this document asserts already exist. Read the corresponding approved child DOCKS files from the integrated F29-A index; do not guess a second destination name or create an alternate convention.

Relevant installed guidance:

- skill://swiftui-pro, especially references/navigation.md, accessibility.md and performance.md.
- skill://swiftui-animation — scoped, interruptible state-driven motion and reduced-motion behavior; use APIs compatible with the actual deployment targets.
- skill://apple-hig-reference — selectively consult the live native guidance below.
- The owner already selected dimillian/swiftui-ui-patterns through the UI Skills CLI. Use its supplied or installed native navigation/inspector patterns where available; do not rerun setup or install another UI system merely to repeat selection. The local SwiftUI/HIG skills and existing source remain the engineering basis, not a reason to silently ignore unavailable selection context.

Live primary chapters relevant to this surface:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices, resizable windows, desktop density, keyboard and menus.
- https://developer.apple.com/design/human-interface-guidelines/sheets — one scoped sheet, normal dismissal, large iPhone content where useful, window-scoped macOS modality.
- https://developer.apple.com/design/human-interface-guidelines/alerts — consequential confirmation, specific actions, Cancel and deliberate default-button behavior.
- https://developer.apple.com/design/human-interface-guidelines/motion — purposeful, brief, optional, interruptible feedback.

No STYLES.md exists in the supplied baseline. Reuse source conventions; do not create a global design file, parallel theme, custom framework alert wrapper or private-glass dependency.

## What Happened Last Session

The documentation batch selected a calm Safety hub with three direct destination rows, actual published operator information and an inline blocked list. It chose full-height iPhone safety presentation during a match and a native Mac inspector when measured room permits, otherwise a window-attached sheet. No Swift code, new backend, native smoke run, user-approved prototype or actual support contact was supplied by that work.

Existing F29-A wording allows side-by-side/wide two-column comparisons. The newer user direction supersedes that: all battles remain timer-first, complete owner-grouped public badge rails next, then large You-above-Opponent vertical panels at every width. Parent/index/CYCLES reconciliation belongs to the integrated documentation owner; do not preserve the obsolete composition because it appears in older text.

The prior context does not name actual operator contact details, staffed hours/time zone or published response expectations. Do not invent them. Their absence is a real operational prerequisite for public rated use, not an invitation to ship a fake support card or no-op Contact action.

## Prerequisites and Review Boundaries

Start connected code only when these real shared foundations exist and have been handed to and accepted by the human as required by the current dependency plan:

1. Account-scoped authenticated Physique service and reviewed native routing/session behavior.
2. One active match/camera owner across devices/windows, authoritative stages/deadlines, state-aware cancellation/forfeit and camera/media privacy shielding.
3. Server-enforced block list, block/unblock authorization, same-operation receipt/status recovery, pair exclusions and revocation of media access.
4. Real report intake, received-case status, appeal/restriction routes and privacy controls. No dead destination buttons and no locally fabricated case center.
5. Published responsible operator, working public support contact, actual staffing facts and reviewed privacy/urgent-help resources available without login.
6. Protected media/cache revocation, identity/badge authorization and actual operational moderation required by F29-D/E.

Read the relevant dependency DOCKS and CYCLES entries again before connection. A compiling placeholder, local JSON block list, preview-only case, successful model response or existing account server is not proof of those prerequisites. If external service or operating facts are genuinely unavailable after repository/tool research, name the exact missing prerequisite and finish the reachable authorized work without a mock production fallback or an implementation-complete claim. Do not start an unreviewed replacement backend or bypass human review to make this screen appear independently shippable.

## Design Decisions to Preserve

- One Safety heading and a small shield identifier, not a safety score, honor badge, art hero or red moderation dashboard.
- Stable order: current-match context when needed; Report, My cases, Privacy & sharing; Support with real visible contact and staffing facts; inline Blocked players; short urgent-help boundary.
- An inline list is intentionally chosen instead of another blocked manager. Longer lists scroll/load more in the hub; do not add a new screen, player search, bulk unblock, swipe-only action or social profile browser.
- Mac inspector is supplementary to the vertical stage. It is never permission to put participants side by side or shrink them into thumbnails. At compact/short sizes, especially 800 by 600, switch to the native sheet rather than change the app-wide minimum.
- Safety motion is tactile but quiet. Presses, state changes and confirmed actions animate; no ambient loop, reward celebration, pulsing badge wall or suspense timer belongs here.
- Native confirmation and service acknowledgement are separate. The user authorizes an action once; the local shield can be immediate, but server protection/removal/receipt is not claimed until known.
- Closing help, unblocking, resolving a case or returning from an external link never implicitly leaves a match, restarts capture, opens poses or renews image lifetime.

## What to Build

### 1. Real hub entry and composition

Connect the existing lobby and contextual entry points to this single feature-owned hub. Pass only safe authorized match/player/pose/explanation/decision references. Do not pass UI screenshots or load body imagery for identification. Carry contextual Report and Block targets truthfully; no generic fake player or invented case.

Implement native iPhone navigation from the lobby and an opaque full-height native sheet from an active match. The active sheet has the real match-context timer/stage at its top, reachable Return to match and a distinct Exit match action. Its Close, swipe dismissal or accessibility escape closes help only. Keep the enclosing active-match flow protected against accidental dismissal. Route child report/case/privacy destinations through the existing safety host; do not stack multiple custom sheets or create duplicate screen implementations.

Implement a native macOS destination from the lobby. During an active match, use the existing in-window inspector pattern only when actual measured layout accommodates a readable hub and the unchanged large vertical stage; otherwise use a window-attached native sheet with vertical scrolling. Preserve title bar, 800-by-600 minimum, current commands and standard modality. At laptop, large/full-screen and external-display sizes, maintain real timer, every authorized public badge grouped by owner above both large You/Opponent panels, and large vertically ordered participants. Short height scrolls; it does not shrink body evidence or add clipping. Aspect-fit any authorized stage evidence equally, without overlays on bodies.

Preserve focus, list position, child navigation and operation state during live resize and inspector/sheet migration. Do not animate size during drag, repeatedly oscillate presentation, send an action twice or restart acquisition because a container changes.

### 2. Connected report, case and privacy access

Report opens the real canonical form with its supplied safe target, or that owner's real target-selection/general-safety state. It does not open a dismiss-only alert or ask the person to enlarge, screenshot, email or attach suspected unlawful imagery. An image report shields the image immediately on entry; cancellation does not restore it. Distinguish scoring review from nudity/abuse reporting. Keep all received/unsent/uncertain report states owned by the reviewed intake contract.

My cases routes only to the signed-in person's real cases and decision/appeal notices. Any preview or action-needed status comes from the service. Do not fabricate totals/unread counts or call a text draft a received case. Privacy & sharing routes to the real feature controls, including withdrawal, shared-image removal and in-app account deletion. Reading privacy is not consent withdrawal. Text-only safety/help access must survive a Physique restriction, ineligibility, declined consent or zero allowance to the extent authorized by the service.

Account restoration, signed-out/expired sessions, forbidden private access, intake/status outage and deleted targets must use the specific states in the product matrix. Clear prior-account private data and pending confirmations; never replay a previous account's action after a switch. Public support remains usable.

### 3. Actual published support

Render the actual responsible operator, public contact method, staffed hours/time zone and published expectation. Make the address or HTTPS destination visible/selectable. Use the real published channel with native external opening or supported system mail composition. Copy contact is an explicit fallback if opening fails or there is no configured mail application. Do not mark an opened browser/composer or clipboard copy as a sent report or received support request.

Use approved public contact publication independently of private account caches and retain last-reviewed public facts for offline reading with an honest update/freshness label. No invented address, placeholder hours, implied continuous staffing or repinned planning target. A missing operating safeguard keeps public rated participation unavailable under the existing readiness contract; do not make the hub itself a fake substitute for staffed operation.

Show Not an emergency service. For immediate danger, contact local emergency help. Use only actually published specialist resources. Do not infer an emergency number from country flags, IP, locale or imagery. Contact actions never auto-attach a photo, credential, private declaration, case text, log or match reference. If a permitted reference can be copied, require that separate explicit choice.

### 4. Inline blocks and native confirmations

Load the current account's real block collection. Keep its heading visible while loading, empty, offline or failed. Show safe display identity or Unavailable player, neutral symbol, actual status and visible per-row Unblock. No avatars, body thumbnails, public-badge wall, profile drilldown, public accusations or alleged violation counts. Preserve last-confirmed rows on refresh/failure, distinguish unknown from zero, and load subsequent pages inline with recoverable page failure and no duplicates.

Contextual Block uses the shared authorized action. Its native confirmation must explain pre-Go cancellation/no Elo effect versus after-Go shielding/future exclusion without leaving or rerating. A final result's underlying lawful outcome remains. On explicit confirmation shield locally before network acknowledgement, label pending authority accurately, and prevent new pairing while required protection state is unresolved. Cancel sends no block. A service Go race cannot reinterpret a pre-start action as consent to a rated forfeit.

Unblock is an explicit per-row button and native confirmation with a safe target. State: Future pairing may be allowed. This will not contact them, rematch, or reopen poses. Add the current-match-continuity sentence for the current opponent. Use Cancel and Unblock; no global default Return shortcut, automatic consequential focus, suppression checkbox or unrelated nested form.

After confirmation, keep the row and local shield until successful service state is known. Disable only repeated mutation for that row. Known offline state says Connect to unblock and does not queue an automatic future unblock. In-flight, known failure, receipt unknown, authorization denied and successful update are distinct. Unknown receipt says Unblock not confirmed · Protected here and offers Check status for the same action, not a blind duplicate or a remote-safety promise. Retry only a known unsuccessful action through the existing contract, reconfirming if target/consequence changed. Preserve account ownership through late responses.

Only authoritative success removes the row and creates a persistent inline Player unblocked acknowledgement. Move focus safely if that row was focused; otherwise announce without stealing focus. Do not reveal reciprocal block status. Unblock does not restore media, open a profile, contact the player, rematch, rerate, renew links or restart capture. A later intentional View poses remains subject to valid AI-judged win/loss/draw, permissions, no blocking/restriction/quarantine, real expiry and separate Hide/View again choices. Forfeit/no-contest never acquire galleries.

### 5. Safe lifecycle and match return

Opening Safety stops acquisition and shields exposed sensitive content before any transition, even in a nonmodal Mac inspector. Before Go, withdraw local Ready through the real owner so an unattended countdown cannot authorize capture; preserve and display actual service pairing/expiry/Go state. After Go, the shared ninety-second capture deadline and twenty-second reconnect grace continue; no help action adds time. Judging may finalize on the service while help remains open. Update real context without dismissing the person's help task or faking a no-contest.

Return to match refreshes the same authoritative match/account/access state. A permitted capture resumes only through the capture owner's explicit Resume camera action. Handle real denied/restricted camera permission, Mac TCC denial, absent/busy camera, external webcam or Continuity Camera disconnection and interruption without a fake preview or rated file picker. Do not reset retakes, deadlines, allowance, self-timers or selected evidence. A result return keeps poses closed; no history reopen, unblock, appeal, foreground event or new window restores media automatically.

Background/lock/minimize/inactive windows stop acquisition immediately, privacy-cover camera, body stills and sensitive safety/account/report text, and pause decoration. Reopen/foreground rechecks authority without catch-up animation. External support opening has the same stop/shield behavior. One account retains one active match/camera owner across windows/devices. A secondary help window cannot reserve or charge another match, acquire the camera, or forfeit a different owning window merely by closing.

Exit match invokes the shared state-aware flow: real pre-Go cancellation, explicit confirmed eligible Forfeit and leave after Go, or the actual already-established final/no-contest outcome. Service-established safety/invalid/unavailable no-contest has precedence. Offline uncertainty is not local finality. Command-W/quit in the owning active-match window uses that confirmation where platform permits; closing help alone does not. Force quit cannot be prevented or classified as confirmed voluntary forfeit.

### 6. Accessibility, focus, motion and energy

Use existing semantic controls, scaled Inter styles, spacing, public material fallbacks, contrast, Reduce Transparency and iPhone safety targets. No Dynamic Type clamp or smaller text to preserve a fixed layout. Addresses, long permitted handles, explanations and pending errors wrap. No essential hover/right-click/swipe-only discovery. VoiceOver, Voice Control, Switch Control, full keyboard access and silent operation have equivalent actions.

Opening focuses the heading/critical notice; closing returns to the invoking safe action/current placeholder. Native confirmation exposes safe target and consequence before action. Escape/Command-period cancels the top confirmation first, then follows the current child draft guard or closes help; one key event never cascades into match exit. Tab order matches visible reading order. Return/Space activate only the focused semantic control and do not intercept routed text editing. Preserve all existing app commands.

Announce meaningful confirmed status/failure once, not every timer tick or interpolated frame. A focused removed blocked row hands focus to the next safe row or section/acknowledgement; background completion never steals focus. No transient toast is the only record of protection or error. Hidden imagery and captions stay hidden from accessibility.

Use the exact motion contract in the child: shared response-0.24/damping-0.88 press spring; native sheet transition without extra zoom; roughly 280-millisecond inspector reveal/260-millisecond close; 160–180-millisecond truthful status crossfades; 180-millisecond disclosure; immediate protection; confirmed unblock row removal settling within 240 milliseconds total; approximately 140-millisecond Copy feedback; stable-geometry real timer digits about 180 milliseconds. There is no artificial minimum wait. Controls and final information are usable immediately.

Reduce Motion removes travel/scale/list motion and uses immediate replacement or at most a 100-millisecond opacity change. Reduced energy/thermal conditions remove nonessential repeated activity motion; offscreen/background/minimized/inactive surfaces stop decoration. No ambient loop, shimmer, strobe, body scanning, humiliating shake, confetti, per-frame I/O/provider work/image decode, camera rebuild, repeated font measurement or global stage invalidation. Never let a privacy stop or access revocation await animation completion.

## Files to Create or Modify

These are prospective implementation surfaces, not assertions that Physique code exists in the documentation baseline. Discover and reuse actual reviewed files from prerequisites; prefer their established names rather than a parallel implementation.

- Create TimeMaster/Views/Physique/PhysiqueSafetyHubView.swift if no reviewed hub file already exists. Keep its inline blocked section feature-local; separate a genuinely reusable native component only if existing patterns justify it. Do not create another blocked-manager screen or universal wrapper framework.
- Modify the actual reviewed Physique lobby/context route host and active-match presentation host only for this hub's entry, inspector/sheet presentation, safe Return and shared exit integration. Do not rewrite capture, result, badge or navigation ownership.
- Modify the existing reviewed Physique presentation/coordinator/service state only for necessary hub consumption, account-scoped request continuity and safe block/unblock status. Do not invent endpoints or a second authority. The relevant domain surfaces may be under TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift; verify before choosing files.
- Modify TimeMaster.xcodeproj/project.pbxproj only if current source-membership conventions require it; preserve all deployment targets, build platforms and native Mac configuration.
- Update only this slice's implementation todos in CYCLES.md when the connected behavior and focused checks are actually handed off. Do not mark dependencies human-approved or alter unrelated work.
- Keep this product DOCKS truthful. Any newly accepted product decision is documented in the smallest relevant DOCKS only after the human accepts it; no test output, screenshot, checkbox or completion record goes there. Do not edit other specialists' product documents to disguise a missing dependency.

Theme.swift, ProfileDesign.swift, TimeMasterGlassControls.swift, TmaxApp.swift and TmaxCommands.swift are pattern/integration constraints, not an invitation to a global redesign, new minimum window size, target raise or shortcut rewrite. Do not add assets, dependencies, telemetry, automatic retries or new screens outside the owned hub need.

## Observable Acceptance — iPhone

- Lobby Safety is a native destination; current match Safety is an opaque full-height native sheet with real timing and safe Return/Exit. Close/swipe/accessibility escape closes only help, never forfeits or restores camera/media.
- All three destinations open their real authorized flows. A contextual report identifies the correct target without revealing/enlarging imagery; a scoring dispute is not mislabeled as abuse. Private data never flashes across sign-in, restore, restriction or account switch.
- Actual support contact/staffing facts and urgent boundary are readable without login and offline where last-reviewed public information exists. Failed external opening offers real Copy contact, never fake delivery.
- Blocked players is inline through loading, empty, partial, offline, pending, denied and failure. Unblock always requires native explicit confirmation and real successful state; unknown receipt retains local protection and provides same-action status recovery.
- All protection actions shield immediately. Return follows the original stage/deadline/allowance, requires explicit camera resumption and keeps result poses closed, including after confirmed unblock.
- Short screens, landscape where supported and largest Dynamic Type remain vertically scrollable with reachable safety actions and no clipped address/consequence. VoiceOver/Voice Control/Switch Control and hardware-keyboard paths preserve equivalent semantics.
- Where a battle composition is visible, real top timer and every authorized owner-grouped public badge rail precede two LARGE vertically stacked players. No side-by-side fallback, thumbnail stage, hidden badge surplus, cropped body or invented live score.

## Observable Acceptance — Native macOS

- Native macOS 14-and-later app, not Catalyst/web. Existing title bar and 800-by-600 minimum remain; keyboard/menu commands keep their current meaning.
- At minimum and short-window sizes the native window-attached sheet scrolls. With sufficient measured room a readable in-window inspector supplements the full-size vertical stage. Laptop, large/full-screen and external-display layouts never place the two players side by side.
- Live resize and inspector/sheet migration preserve focus, navigation, list position and same-operation state without duplicate mutation, animated size pumping, media flash or camera acquisition. All public badge rails remain complete above vertical players wherever the battle is exposed.
- Pointer targets, visible native focus, text selection, Tab/Shift-Tab, focused Return/Space and state-aware Escape work. No hidden hover-only action and no global key capture while a note is being edited.
- Window-specific sheet modality does not lock unrelated windows. Closing help or a secondary window is not match exit. Owner-window Command-W/quit asks the actual current consequence where possible; force quit is not a confirmable voluntary forfeit.
- Mac TCC denial, external/Continuity camera disconnection, inactive/minimized windows and explicit return do not activate a fake preview, file-picker substitute, second match, extra charge or auto-restored media. Public support and permitted private safety access remain available without camera.

## Focused Native Smoke, Accessibility and Energy Scenarios

Run the actual changed native surface after connection, using the existing focused build/check path and authorized authenticated staging/service data. Compiling, unit tests, a design screenshot or a preview alone is not proof of the changed behavior. Preview-only fixtures must be clearly labeled and must not become production fallback behavior. Use consenting accounts and permitted material; never create or upload prohibited imagery for a smoke scenario.

1. **Real route round trip, both platforms:** Open Safety from lobby, a contextual match/result and a restriction notice. Open each real report/case/privacy destination and return. Observe correct safe target, account and focus, retained navigation, no camera start and no invented case count.
2. **Published public help:** Sign out or allow session restoration; read actual operator contact/staffing facts. Take the device offline and inspect last-reviewed public data/freshness. Exercise the actual supported external contact open and a genuine unavailable-opener path where the platform permits; observe Copy contact without automatic private attachments or a false Sent/Received label.
3. **Authoritative unblock:** With a real existing block, cancel the native confirmation and observe no mutation. Confirm once and observe pending then actual success, safe row removal/focus and no contact/rematch/media opening. Reopen the hub and observe current authoritative state without replaying success motion.
4. **Receipt uncertainty:** Use approved service/network controls to interrupt acknowledgement of the same unblock after consent. Observe Protected here and Check status, not premature row removal or a second request. Reconcile that action against the real service. Exercise a definitively unsuccessful/forbidden update separately and observe the correct retry/restriction route. Do not build a production fake backend to manufacture the scenario.
5. **List boundaries:** Exercise a genuinely empty list, an unavailable initial fetch and a later-page failure through the existing approved service harness. Observe distinct states, retained rows, inline Load more/Retry and no duplicates. These are consumer-visible boundary states, not a source-text or forwarding test.
6. **Live match safety:** With authorized consenting participants, open Safety before Go and after Go, invoke the actual contextual block where permitted, and return. Observe immediate shield/stop, withdrawn pre-Go Ready, current service stage, unchanged deadline/retakes/allowance, separate explicit exit and no synthetic outcome. Resolve a Go/cancellation race through the existing authority harness if physical timing is not deterministic.
7. **No restored media:** Intentionally open permitted unexpired result poses, enter Safety, and close it or confirm an unblock. Observe closed poses. Verify that a fresh intentional View poses still obeys consent/block/expiry/removal and that separately hidden images require the allowed explicit View again. Use real expiry/access state from the authorized service; do not reset the clock locally.
8. **iPhone accessibility:** Largest text, VoiceOver, Reduce Motion, Reduce Transparency, silent mode and hardware keyboard where available. Reach every hub action; read long contact/handle/error text; cancel a confirmation with accessibility escape; verify one meaningful announcement and no per-tick stream. Name any assistive-technology path not actually exercised.
9. **Mac windows and input:** Launch the actual native Mac target. Exercise 800-by-600, short laptop, roomy/full-screen and external display if available; resize through inspector/sheet fit. Use keyboard-only traversal, Escape/Command-period, focused Return/Space, public contact text selection and existing commands. Open a second app window and close its help without affecting the owning match. Observe persistent vertical players and complete authorized badge rails when the stage is present.
10. **Camera/lifecycle:** Observe the actual camera indicator/acquisition stop on help entry, background/lock/minimize/inactivity and external contact launch. Exercise denied TCC/iPhone permission and actual external or Continuity disconnect if hardware is available. Return must restore state with a stopped panel and explicit permitted Resume, not a new session. Simulators cannot establish physical camera privacy proof; name that missing proof honestly.
11. **Energy and interruption:** In normal and reduced-motion/low-power conditions where available, interrupt transitions with close/reopen and resize; background/minimize while a request is pending. Observe no decorative catch-up, success replay, offscreen ambient loop, camera work or per-frame requests. Use existing profiling tools if available to inspect the changed path; do not claim a measured energy saving or frame rate without measurement.

Use existing deterministic behavioral tests only where they catch uncertain consumer-visible boundaries such as an acknowledged-versus-unknown unblock or cross-account stale completion. Do not add tests of source text, view wiring, forwarded arguments, incidental defaults or mock echoes. A throwaway focused probe is preferable for straightforward integration. Report only commands/scenarios actually run and the observed result. No screenshots, recordings, device evidence package or exhaustive audit is required.

## Human Verification Handoff — Required

List separately:

- Native iPhone hub/navigation and active-match help composition.
- Native Mac destination/inspector/compact-sheet, resize and multiwindow behavior.
- Real report/case/privacy routing and published support/urgent boundary.
- Inline blocks, contextual Block, explicit Unblock and real acknowledgement/failure recovery.
- Immediate shielding, safe Return/Exit, explicit camera resume and no automatic media restoration.
- Focus, keyboard, accessibility, motion and energy behavior.
- Every changed file, with what changed in it.

Ask the human to review the code changes and verify each item. State focused checks and actual native scenarios exercised, missing service/operator facts, unavailable hardware/runtime/assistive-technology paths and any unresolved decision plainly. Do not call the implementation human-verified or accepted. A build alone cannot satisfy this handoff.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do all work for this slice yourself. Do not delegate repository review or generation and do not touch another worker's owned files or unrelated changes.
2. **User direction wins.** The newer native-both-platform, all-badges-above-large-vertical-players direction overrides old side-by-side wording. Preserve privacy and service authority; surface a genuine security/product conflict rather than silently change behavior.
3. **Real data and real behavior.** No production mocks, fake peers/cases/blocks/contact, static success, no-op controls, invented scores, false receipts, bypassed consent or placeholders presented as a feature. Labeled previews are not service substitutes.
4. **Prerequisites first.** Use the implemented human-reviewed shared contracts. Do not duplicate the report/case/privacy/camera/match owners or invent an alternate service to unblock a visual task. Diagnose accessible repository information before declaring an external prerequisite missing.
5. **Complete the owned connected slice.** Build, connect, run focused checks, exercise the actual native surface, fix clear failures, update its truthful implementation status and hand it to the human. Do not stop at a compile-only scaffold or create a testing-only next handoff.
6. **Privacy before animation.** Stops, shielding, revocation and account isolation are immediate. No animation, pending network receipt, help dismissal or unblock can reopen protected media, manufacture finality or implicitly consent to forfeit.
7. **Preserve architecture and compatibility.** Existing styles, public API availability fallbacks, iOS 16/macOS 14, native Mac title bar/window minimum and current commands remain. No new global theme, private API, arbitrary screen coordinates or unrelated wrapper/dependency.
8. **Scoped commit and push for future implementation.** After a complete verified work slice, inspect its meaningful result, commit only owned authorized changes with a clear message and push to origin/main. Never force-push, rewrite remote history, stage unrelated work or leave this slice local. Report an exact commit/push blocker honestly. This rule applies to future implementation, not the coordinated documentation-only worker batch that created this prompt; that batch's main owner publishes the integrated documents.
9. **CYCLES is the only project todo system.** Update only the actual F29-A-r implementation todos after connected checks and handoff. A checked implementation item is not human approval. No duplicate IDE tasks, standalone completion checklist or evidence in DOCKS.
10. **Honest documentation.** The product child remains plain-language behavior, not code, payloads, logs, screenshots, checkboxes or implementation evidence. Document accepted product changes after human acceptance; do not rewrite policy to hide incomplete behavior.
11. **No automatic scope creep or pointless next prompt.** Complete small remaining owned work now. Do not add unrelated screens, automatic retry systems, analytics, new judging models or artwork. A further prompt is warranted only for a real substantial separately owned slice, never just for checks, straightforward fixes, documentation, commit or push.

## When You Finish

Report every implemented meaningful item and changed file separately, exercised native/check results, actual limitations and scoped publication result. Ask for human review. State whether any further substantial prompt is genuinely needed; this brief itself does not require generating one. Never claim current design documentation, previews, compile success or an unrun scenario proves implementation or human acceptance.
