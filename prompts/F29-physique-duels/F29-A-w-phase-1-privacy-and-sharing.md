# Phase 1 of F29-A-w — Native Privacy and Sharing

## Required Model and Thinking

Assigned UI implementation worker: **openai-codex/gpt-6.1-sol:max**. The model identifier is **openai-codex/gpt-6.1-sol** and thinking/reasoning level is **max**. The suffix is a worker reasoning setting, not another model, a production judge identifier, or a requirement to change the in-app judge. No silent model fallback. If the dispatcher cannot provide this assignment, report that exact limitation to the coordinating owner rather than claiming to have used it.

This is a future implementation brief produced by a documentation-only design batch. Its existence does not authorize production implementation now, certify any prerequisite, or claim a human has reviewed the resulting behavior.

## Features Included

- F29-A-w — Privacy and sharing: native iPhone and native macOS receipt, current independent choices, activity, actual recipients and retention, stage-aware withdrawal, own-photo removal, reliable request status, and direct access to global account deletion.
- Existing match/account integration strictly needed to make that surface real, including safe camera stop/return, existing match clock and exit, account isolation, current media authorization, and the existing global account destination.

Keep this one functional slice. Do not implement unrelated lobby, camera, badge catalog, viewer, report-center, judging, rating, navigation, or global-account redesigns. Do not create a second privacy service, consent authority, deletion wizard, global settings framework, or mock rated mode. List each meaningful implemented responsibility separately at handoff.

## Context

Physique shares protected stills with an approved service and, under current conditions, a paired opponent; its old exercise-camera privacy promise remains unchanged.
The design is a compact privacy receipt with three independent choices, real activity and request status, and stage-aware protective actions.
Both native platforms are first-class; any battle composition retains the top real timer, complete badge rails above two large vertical players.

## What You Need to Read First

Read the current versions before coding, not just the summaries in this brief:

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md — complete owned product behavior, both platform compositions, state matrices, motion, privacy and recovery.
- features/F29-physique-duels/DOCKS.md — shared lifecycle and explicit versus proposed product decisions.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — current entry/return/capture and stage ownership; current user-directed vertical/native-Mac decisions supersede historical side-by-side/secondary-Mac passages.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — especially distinct permissions, stage withdrawal, provider arrangements, data lifetime, requests, deletion, and operational failure states. This is product context, not proof of configured service behavior.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — Go race, explicit eligible forfeit, no-contest precedence, one match, allowance, finality and optional listing.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — current media authorization, separate hide/report/block rights, restricted case evidence, hold limits and legal-safety handling.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — clean redacted accepted inputs and identity-blind judging.
- features/DOCKS.md and CYCLES.md — current ownership, actual prerequisite review and only the approved implementation todos relevant to this slice.
- TimeMaster/Utilities/Theme.swift:1-81,208-228 — existing colors, surfaces and controls.
- TimeMaster/Utilities/ProfileDesign.swift:1-38 — Inter typography, spacing, readable width and iPhone action convention.
- TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80 — public availability-guarded materials, opaque Reduce Transparency behavior and existing press spring.
- TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188 — adjacent action/earned-rating language. Do not copy text-size clamps, badge substitution or fixed shrinking geometry.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151 — exercise HUD context only; its provisional movement scores are not Physique data or a privacy model.
- TimeMaster/Views/Ranked/RankedMatchPreparationView.swift:31-74 — existing exercise privacy explanation and contextual camera Settings route; preserve joint-only exercise promises.
- TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift:34-96,291-299 — existing global account/deletion surface and confirmation.
- TimeMaster/Services/Cloud/CloudAccountStore.swift:171-210 — current account switching and acknowledgement-first deletion behavior; do not assume it already includes future Physique data.
- TimeMaster/Views/Ranked/RankedAccountView.swift:1-28 — existing account destination, not permission to create an F29-specific replacement account wizard.
- TimeMaster/App/TmaxApp.swift:8-24 and TimeMaster/App/TmaxCommands.swift:6-37 — native WindowGroup, 800-by-600 minimum, title bar and reserved commands.
- TimeMaster/Models/LocalProfileModels.swift:23-27,99-109 — editable local badge previews are not trusted competitive achievements or verified identity.
- TimeMaster.xcodeproj/project.pbxproj — actual target membership and iOS 16/native macOS 14 deployment support. Do not raise targets or require 26-only APIs.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the image. Borrow timer-first hierarchy and directness, not side-by-side participants, body-overlay badges, people, footage, web pills, captions or rights to the reference faces.
- The actual reviewed F29-F identity/badge context and shared match, consent, protected-media, request-status and global-deletion source files present at implementation time. Discover their real paths before opening/editing; do not assume a file already exists because it is prospective here.

Read relevant installed skill context first: skill://swiftui-pro and its accessibility/navigation/performance references; skill://swiftui-animation for narrow, interruptible state motion; skill://apple-hig-reference for current native guidance. The orchestrator already selected dimillian/swiftui-ui-patterns through the UI Skills CLI in the design batch; use its supplied selected context if available without repeating installation/setup. Existing supported deployment targets override a skill's default newest-OS recommendation.

Consult the live Apple HIG Privacy, Designing for macOS, and Motion chapters when implementing platform-dependent behavior. Recheck actual API availability rather than inferring it from HIG or skill examples. STYLES.md was absent in the design source context; use current source conventions and do not create a parallel global style file.

DOCKS.md is plain-language product context, not implementation authority. Validate technical choices against current source, skills and actual service contracts. Never add source, payloads, pseudocode, project todos, test output or completion evidence to a DOCKS.md.

## What Happened Last Session

The documentation worker specified only this child DOCKS.md and this future brief. The chosen receipt, stage semantics, iPhone/native-Mac presentation, accessibility and event-driven motion are design instructions, not a production implementation. The reference image and existing source anchors informed the decision. No Swift code, backend, test, build, formatter, image generation or app smoke run was performed for that documentation-only slice. Shared integration, cycle updates, publication and human review belong to the coordinating owner; do not infer their completion from this brief.

## Prerequisites and Review Boundaries

Code starts only once the real shared foundations/contracts this view depends on are implemented and human-reviewed. Verify that status from CYCLES.md and the coordinating owner's handoff. The required foundations are:

1. Authenticated account identity/restoration and protected account switching; an authorized persistent HTTPS service, not a developer-local stub.
2. One service-owned active match and camera owner across windows/devices; real stages, original deadlines and stage-aware exit/finality/allowance.
3. Versioned independent AI/safety and opponent-access choices, independent Physique public-listing choice, current actual privacy disclosures and reliable acknowledgement/current-state reads.
4. Protected face-obscured upload, current participant/media authorization and link/cache revocation, scoped own-media removal, lawful hold categories, original expiry and deletion-request receipts/status.
5. Reviewed operator and named processor purpose/region/storage/logging/cache/image-exception facts, published real contact and notice, no hidden training/research permission, and an operating safety channel.
6. A global account-deletion contract that really covers the new Physique data while preserving the existing local-library boundaries and distinguishing active-system completion from lawful residuals. The existing v1 account deletion acknowledgement alone is not proof of that extension.
7. Shared battle/identity surfaces that preserve the approved top timer, ALL public badge rails above two large VERTICAL players, and currently authorized public identity without uploading local Profile media.

Missing prerequisites are not permission to start a detached UI with fake success. Name the precise missing reviewed contract to the coordinator and do not mark this child implemented or independently shippable. Do not silently invent production processors, stored consents, pending receipts, peers, results, timeouts, ranks or fallback judging. Finish reachable authorized work only within a real agreed contract; never call a disconnected preview the connected deliverable. Preview-only fixtures, if used by project convention, are explicitly labeled and isolated from production.

This brief does not authorize an unowned shared-foundation redesign. Discover the actual owner and use reviewed integration points. Small necessary caller/contract corrections are in scope only through that ownership, with real connected behavior and matching consumer contracts; do not hide a missing service feature behind disabled-looking but clickable no-op controls.

## Design Decisions and Tradeoffs

- Choose a privacy receipt, not a privacy score dashboard or ambiguous optimistic switch wall. Each independent row displays its real current state and names the recipient/purpose before an explicit action. This uses more vertical room but makes scope and remote authority legible.
- Keep Activity above the choices. Local camera stop, local transfer stop, service receipt and external processor cancellation are four different facts; a single green Off indicator would lie about one or more of them.
- Expand detail in place. Keep essential recipient, lifetime, exception, screenshot risk and stage consequence facts in the approval/removal review; progressive disclosure is not a legal-policy-link-only substitute.
- Stop/shield acquisition before entering privacy from a camera-owning surface, then require explicit eligible Resume camera on return. Reading never keeps a hidden camera running or resets the match clock.
- iPhone uses a full-height native match sheet, not a small card over a live body feed. The privacy receipt itself is not a battle view and does not add tiny duplicate players. Its active-match strip preserves the real timer and safe return/exit.
- Native macOS uses a trailing inspector only when measured space preserves large readable vertical players, otherwise a window-attached native sheet. Large/full-screen/external-display width is for the inspector, never a side-by-side matchup. Preserve the normal title bar and current minimum.
- Use no body grid to exercise removal. Contextual removal names My poses in this match, with an explicit All my shared poses alternative; lobby entry clearly names all-own scope. No new archive/gallery-management screen.
- Own-photo removal, AI withdrawal, opponent-access withdrawal, public unlisting, Hide opponent image, sign-out, page removal and global account deletion are different actions. Do not combine them behind one destructive label.
- Withdrawal is never covert confirmation of a forfeit. A deliberate exit is explicitly Forfeit and leave only while eligible; invalid/safety/service no-contest has precedence. Opponent-only access withdrawal after Go does not itself leave, forfeit or stop separately authorized AI participation.
- State-driven tactile feedback replaces celebratory deletion metaphors. Native disclosure, the existing press spring, and a single confirmed receipt change are sufficient; no body scanner, photo shredder, confetti or reassurance loop.

## What to Build

### 1. One connected native receipt with real entry and return

Create the native Privacy & sharing surface described in the child product specification. Connect lobby/account, capture, result and history/media-unavailable entry points to the same view with the real account and exact match context when applicable. Do not start a search, request camera permission, grant consent, transfer a still or delete anything by opening it.

From active capture, stop and shield acquisition before transition. Never auto-capture or auto-resume on Done, Escape, swipe dismissal or external-notice return. Keep authoritative deadlines running and allow real finalization to arrive without closing the privacy action or changing its scope. The active-match strip has the real phase/time and safe Return/Exit; outside an active match there is no dummy countdown. Match photo expiry derives from original finalization, not first opening.

### 2. Current independent choices and informed authorization

Present AI processing, Opponent pose access and Public standings as separate real rows. Distinguish Not chosen, Allowed, Declined, Withdrawn, Review update, desired local pending state and last confirmed remote state. Never derive consent from camera authorization, navigation, a timer, a stale local preference, blanket terms, a saved training key or another choice.

Read current policy version and actual disclosure facts before allowing new affected use. Show named operator/processors, data and purpose, current actual regions/retention/storage exceptions, limited case review, masking limits and withdrawal route. For AI, distinguish protected candidates for safety from the six accepted selected stills for the paired judge; do not send public identity, badges, country, Elo, private declarations, UI chrome or a screenshot of the battle as judging context. Fail closed if redaction or required disclosure is unavailable.

Opponent permission covers only current authorized post-result still access after an intentional View poses in a valid judged win/loss/draw, not live video, early thumbnails, retakes, a public feed or a forfeit/no-contest gallery. State screenshot/external-copy limits plainly. Reconsent applies to future use, never automatic historical gallery restoration, old-image resending, deadline renewal or a second judgement.

Public listing remains optional with equivalent Elo earning while unlisted. A confirmed allowed choice is not a live public rank when unplaced/provisional/restricted. Show Allowed — not listed yet and the true condition. Preview only genuinely permitted public identity/competition fields and F29-F badges/country, not local cosmetic previews or an automatically uploaded local avatar. Unlisting does not delete photos, private match records, Elo or the account; paired-opponent identity is not promised anonymous.

### 3. Real activity and privacy actions by stage

Use independent device-local camera, transfer, service-intake and processor-state facts. Show actual selected/received/accepted distinctions and only real progress counts/bytes. No fabricated AI percent, idle provider assertion, zero-photo count, guaranteed cancellation or all-devices-stopped claim.

Before service Go, withdrawing a required choice stops local work and cancels/reconciles preparation or pairing without Elo/consumed-slot consequence when accepted in time. Show reservation release pending until confirmed. If Go wins the race, retain the privacy stop, present the true stage and explicit eligible exit; never convert the earlier cancel to consent for a rated loss or reset time.

After Go, AI withdrawal stops new acquisition/transfers immediately and seeks cessation of further processing, but an accepted external request may not be retractable. Offer privacy withdrawal without demanding continued posing or forced consent to a rated exit. A separate deliberate Forfeit and leave follows the actual eligibility and no-contest-precedence rules. Never promise that withdrawal creates a free no-contest, refund, rating reversal, fixed outcome or private-rated mode. Retrieve the real outcome if it already finalized or may validly finalize from accepted work.

After Go, opponent-only access withdrawal revokes future authorized viewing of the owner's stills without itself cancelling, forfeiting or changing Elo. Preserve separately authorized valid participation and all current per-owner/safety/media conditions. No control here restores another person's restricted photos. After finalization, privacy choices/removal never reroll or reset a valid result.

### 4. Scoped own-pose removal and truthful receipts

Connect Remove my poses… to real own-media removal. With match context, default to My poses in this match and make All my shared poses an explicit alternative; lobby entry explicitly says all. Repeat scope in the native confirmation, destructive action and receipt. The scope includes authorized ordinary F29 own media/viewable derivatives, not opponent data, the exercise library, global account data or a guarantee about provider/external copies.

Explain evidence validity/current-match consequences, ordinary access revocation, scoped lawful holds, copy limits and unchanged legitimate Elo before submission. Stop/shield affected local work immediately; do not automatically resend the removed set because future consent remains on. Do not request body-photo access or thumbnails to exercise this right.

Implement Not sent, Not confirmed, Received, In progress, Partially held, Completed in active systems, and stale/unavailable status with durable account-bound scope/receipt context and useful recovery. Receipt acknowledgement is not completed erasure. Local cache empty, expiry reached, successful hide/block, closed sheet and HTTP uncertainty are not global deletion success.

When definitely offline/unsent, show Stopped here and Request not sent. When receipt is uncertain, show Remote change not confirmed and last confirmed state. Check/retry the same real request without duplicate apparent operations. Older responses cannot re-enable local sharing after a stronger pending withdrawal, restore removed media or overwrite a current policy choice. Reconcile before a new Allow can overtake withdrawal/removal. Close is permitted; closing is not cancellation of an acknowledged request. Do not provide a fake Undo for irreversible removal.

Expose only legally permitted limited hold categories/reason/duration or review information; delete unheld data and keep participant access revoked. A normal benign evidence hold is bounded from its original received report, never reset by retry, appeal, duplicate, comment or staff delay. Potential unlawful/exploitative media follows restricted legal-safety handling, never an ordinary attachment or a request for the user to screenshot/reupload it.

### 5. Honest lifetime, provider limits and global deletion

Retain the F29-E distinction between app-controlled ordinary media expiry and processor logs/application state/cache/safety exceptions. The proposed ordinary window is twenty-four hours after finalization, or receipt for rejected/orphaned uploads, sooner when unnecessary or removed; opening, reconsenting, cross-device fetch, retry, appeal and notification never restart it. Forfeits/no-contests still have no opponent gallery during any retention.

A benign case can retain minimum existing lawful media for at most thirty days after its original receipt, less when unnecessary; held evidence does not extend opponent access. Raw media is not put in long-lived backup to evade expiry. Nonmedia records, ordinary case correspondence, protected nonmedia backup expiry and justified legal retention stay separate. Show actual scoped provider/backup residuals rather than Everything deleted.

Do not hardcode OpenAI's default marketing/data-guide schedules as the operator's configured policy. Resolve the real endpoint, storage controls, approvals, regions and image exceptions. No unsupported no-storage, anonymous, end-to-end-encrypted, no-human-review, Zero Data Retention or EU-only claim. No hidden training/research, new vendor, personal key or local competitive fallback.

Route Delete Tmax account… to the existing global account deletion area, not a new flow, sign-out button or support email. Pass the active-match context to existing shared consequences and stop/shield capture first. Confirm the shared deletion contract covers Physique before representing that it does. Keep account-wide deletion accessible even if Physique consent is declined, media is held, a dispute is pending or the judge is unavailable. Global deletion's proposed seven-day target is not a measured guarantee or permission to extend photo retention. Preserve ordinary app/local-library behavior and the distinct effects of OS app-wide camera revocation.

### 6. Native input, focus, motion and energy

On iPhone, support short screens, landscape constraints and largest Dynamic Type through wrapping/scrolling, measured safe areas and visible protective/close/retry actions. On Mac, exercise the actual 800-by-600 minimum, laptop, large, full-screen and external-display layouts, live resizing, independent stage/receipt scrolling and inspector-to-sheet continuity without resubmitting or losing focus. Do not raise the minimum or make the players tiny to fit details.

Where a battle is present, keep the real timer topmost, all public badges grouped by owner above two LARGE VERTICAL players, You above Opponent at every width. No clipped extras, hidden +N, three-badge cap, ticker, hover-only information or badge overlay on evidence. Before finality the opponent is authorized avatar/silhouette plus actual stage/count. After finality, use moderated stills only through intentional permitted viewer access, aspect-fit without body cropping or comparative favoritism. This receipt does not create another gallery or auto-open one in an inspector.

Preserve native Mac titlebar, toolbar and window lifecycle. Preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O. Tab/Shift-Tab and native focus rings reach every row, detail, scope, confirmation, retry, contact and deletion link. Return/Space acts only on a focused semantic control, never global capture or accidental destructive default while typing. Escape cancels the innermost unsubmitted confirmation or closes only the privacy presentation; it neither reverses acknowledged privacy work nor silently forfeits. Real Cmd-W/quit while owning an active match uses reviewed stage consequences where possible; secondary-window close is not another match exit and force quit is not a confirmable forfeit.

Camera/TCC not requested/denied/restricted/busy/missing and external/Continuity disconnect are real distinct states. Privacy browsing never requests permission. Settings/Retry appear only when useful. Inactive, minimized, hidden, backgrounded, locked and fast-user-switched surfaces immediately stop/shield acquisition/private content; authoritative clocks and received service work continue. Return reconciles the same match, without new allowance charge, deadline reset, extra retakes or automatic camera restart. Other windows/devices never create a second camera owner or claim a remote camera stopped solely from local inactivity.

Apply the existing press spring. Detail unfolding is 180 milliseconds ease in/out; confirmed state/receipt text changes are 160–180 milliseconds, narrowly scoped to that event. Native sheet/inspector motion is native, not an extra chained animation. Shared timer digits may use the approximately 180-millisecond stable-geometry treatment. Receipt data, safe actions and final statuses are usable immediately. Latest real state retargets animation; reopening/history does not replay an achievement. Privacy stop, expiry, deletion protection and account switch are immediate, with no revealing outgoing-image fade.

Reduce Motion removes rotation/travel/scale/repetition and uses immediate updates or at most a 100-millisecond opacity change with identical information. Reduce Transparency uses opaque readable surfaces and cover. No privacy ambient loop; if the battle inspector coexists with its shared ambient layer, do not add another. Low power/thermal stress, inactive/minimized/background/offscreen states remove decorative work. No per-frame network/provider/storage/image decoding, font measurement, camera reconstruction or broad layout invalidation. No fake minimum wait or deletion progress percentage.

VoiceOver focus enters at heading, moves to native confirmation on explicit invocation, then to the receipt after deliberate submission. Restore safe focus to the invoking row/control on return. Remote refresh must not steal focus while reading. Announce meaningful acknowledgements, failures, holds, completion, permission loss and match finality once, not every timer tick/spinner cycle. Named controls and equivalent paths must work for Voice Control, Switch Control, Full Keyboard Access, touch/pointer and silent/reduced-motion use. Keep concise facts readable instead of writing intimate image descriptions for accessibility.

## Files to Create or Modify Prospectively

Only after prerequisite review and implementation authorization:

- Create or extend TimeMaster/Views/Physique/PhysiquePrivacySharingView.swift — this connected receipt, inline choice detail, activity, removal scope/receipt and platform presentation. Use feature-local responsibility-sized subviews only when needed; do not create wrappers for every standard control.
- Modify the actual existing reviewed Physique lobby/account, match/capture, result/history entry/return owners discovered under TimeMaster/Views/Physique/ — route to this view, carry exact context, reuse shared real timer/exit, and preserve stopped-camera return. Do not fabricate prospective parent files because a name looks plausible.
- Modify the actual existing reviewed presentation model/store in TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift only for missing consumer-facing privacy state needed by this view. Reuse existing identity, request, clock and media authority conventions; do not introduce a second server or protocol.
- TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift and TimeMaster/Services/Cloud/CloudAccountStore.swift remain global-owner surfaces. Reuse the existing destination. Any truly necessary Physique deletion coverage/copy correction requires that owner's reviewed contract, minimal scope and real service support, not a parallel local implementation.
- Feature-local existing contract tests may change only for real changed consumer behavior. A new permanent regression is justified for uncertain concurrent withdrawal/acknowledgement, pre-Go/Go or account-isolation behavior; never for forwarding, source spelling, copies, mock echoes or incidental animation defaults.
- CYCLES.md — update only approved implementation todos for actually connected, exercised work and human-review handoff; no completed checkbox for a detached preview or missing prerequisite.

Do not edit unrelated app code, reusable system files, other UI-worker targets, global theme, deployment targets, badges catalog or project plans. Register new source with both native targets according to the existing project convention. No new documentation/README/changelog files or disposable production assets are required. Product-decision documentation updates occur only after user acceptance, with the smallest relevant DOCKS.md and no verification logs inside it.

## Observable Acceptance — iPhone and Native macOS

1. The same signed-in account's real current AI, opponent and listing choices appear independently on both platforms; an unresolved request never displays false saved consent, public removal or remote erasure. A different account cannot inherit any private receipt, media, focus target or draft.
2. Before any new affected transfer, actual named recipients, purposes, region/storage/retention exceptions, masking limits, current policy and copy risk are readable. Missing facts block new authorization/participation without blocking decline, withdrawal, account deletion, contact or unrelated app use.
3. Opening privacy from capture stops/shields immediately without a new permission alert; closing does not resume or capture. Both platforms show actual local versus remote activity and continue the same clocks and match identity.
4. Pre-Go withdrawal/cancellation releases the reservation only when confirmed; a cancellation that loses the Go race does not silently become a rated forfeit. After-Go AI withdrawal stops new work; opponent-only withdrawal does not itself leave/forfeit; valid explicit forfeit versus no-contest remains service-owned. A finalized result and Elo never reroll from a privacy operation.
5. Scoped own-photo removal works without loading a body grid. Only the owner's chosen ordinary media is removed/revoked; a legitimate hold removes ordinary access and deletes unheld data. The actual receipt distinguishes sent/unknown/received/progress/held/active-system completion and separate residuals.
6. Offline/uncertain requests show local protection plus honest remote uncertainty and useful recovery. Reopen, retries, multiple windows/devices and stale replies cannot create duplicate apparent requests, restore revoked photos, re-enable sharing or reset expiry/allowance.
7. Public listing is optional; unlisted/provisional/allowed-but-not-yet-listed are distinct. No fake rank, public pose photo, local avatar upload, cosmetic-preview achievement or changed Elo appears.
8. Original twenty-four-hour expiry and original report-hold bounds remain original across viewing/reconsent/retry/appeal/device changes. Provider, lawful-hold and nonmedia-backup limits are separate; no claim of universal instant/24-hour erasure or recalled screenshot.
9. Delete Tmax account… reaches the actual global deletion area and represents Physique coverage only when that real contract exists. Decline preserves unrelated features; the app-wide camera Settings effect is explained honestly.
10. iPhone short/large-type states remain fully actionable. Mac native 800-by-600, laptop, wide/full-screen/external-display, live resize and short-window states retain readable receipt, usable timer/exit and large vertically ordered players wherever the battle exists. All public badges stay above the players and remain discoverable without hover, clipping or hidden extras.
11. Native Mac keyboard/pointer/window behavior preserves reserved commands, focused semantic Return/Space, safe Escape, stage-aware Cmd-W/quit, nonconfirmable force-quit handling and single camera/match ownership. TCC and external/Continuity camera failures are recoverable or honestly unavailable, never prerecorded/fake rated input.
12. Dynamic Type, VoiceOver, keyboard/Voice Control/Switch Control, contrast, reduced motion/transparency, inactive/minimized/background states, low power and thermal reduction retain the same facts and protective timing. No privacy action waits for decoration and no animation frame initiates I/O or changes authority.

## Focused Native Smoke and Verification Plan

These are future actions, not evidence from the design batch. Run the changed native surface, not only unit tests or SwiftUI previews. Use the project's actual reviewed development service and real authenticated accounts, with consenting eligible adults for any camera/image exercise. Never create fake production peers/receipts or use another person's images. Do not incur unapproved generation/provider charges or perform destructive production-account testing; use an authorized disposable test account and reviewed service environment.

### Connected iPhone scenarios

- Open from lobby without starting camera; review current choices and details, decline either required choice, leave and use a noncamera/local feature. Confirm no capture/upload/pairing occurred and public listing did not implicitly turn on.
- Open from a real capture/search context, observe local stop/cover and real clock, dismiss, and observe explicit resume rather than automatic capture. Exercise a pre-Go withdrawal and a controlled Go-boundary race using the real service's supported deterministic scenario. Observe actual reservation/outcome, not a local assumed loss/refund.
- Exercise after-Go opponent-only withdrawal and own-pose removal from a real permitted context; observe the actual current-match state, counterpart authorization denial and safe placeholders through existing media surfaces. Never claim a local view change proves another device or remote storage deletion.
- Interrupt network before sending and after sending before acknowledgement. Observe Not sent versus Not confirmed, durable receipt/context on reopen, and one reconciled request after recovery. Withhold/late-deliver an older state through the established integration-test mechanism and confirm it cannot restore consent/media after withdrawal.
- Open a valid post-result context near original media expiry; leave/reopen/reconsent/retry and verify the same expiry and denied old-link/cache access. Exercise held and already-removed states only through genuine service fixtures/test records supported by that reviewed environment, not a client-invented success state.
- Follow global deletion to the real account destination. On an authorized disposable account, observe actual request and account/media cleanup boundaries, including a safe uncertain response if supported. Do not delete the user's production account to obtain proof.

### Connected native Mac scenarios

- Run the macOS target at 800-by-600 and a normal laptop window, then large/full-screen and on an external display when available. Resize live while an expanded detail, focus and request receipt are present. Observe inspector/sheet continuity, no resubmission and vertically stacked large players with complete badge rails.
- Traverse using keyboard only, activate focused controls with Return/Space, type into the existing account fields without triggering capture, dismiss innermost confirmation with Escape, and check the four reserved app shortcuts retain their existing meaning. Exercise primary-owner versus secondary-window Cmd-W and platform-permitted quit consequences without treating force quit as a confirmed voluntary forfeit.
- Exercise camera denied/restricted where available, external/Continuity camera disconnect/reconnect on actual supported hardware, minimize, deactivate, hide and return. Observe acquisition stop/shield, TCC-appropriate recovery, same service clock/match and no automatic restart, extra allowance, second camera or file-picker fallback.
- Open a secondary window/device using the same account. Observe one active match, shared choice/request state, correctly limited local activity claims and no old-account leakage after sign-out/switch. Simultaneous permitted privacy views must not weaken a pending local stop.

### Accessibility, motion and energy scenarios

- Use largest supported iPhone Dynamic Type and a readable enlarged Mac text/accessibility setup; expand long recipient/exception text. Observe complete copy, reachable destructive scope/cancel/retry and no clipped timer/badges/players or offscreen focus trap.
- With VoiceOver and keyboard/full-access traversal, observe entry/confirmation/receipt/return focus and one meaningful state announcement. Confirm no every-second countdown speech, unsafe anatomical narration or focus theft from remote refresh.
- Enable Reduce Motion and Reduce Transparency; trigger expansion, request receipt, failure, hold and completion. Observe identical authoritative information, immediate protection and no travel/scale/revealing body fade.
- Observe the native process while the receipt is idle, sending, offscreen and minimized/backgrounded under available low-power/thermal controls. Use the focused native diagnostic tools available to verify no idle decorative/rendering loop or per-frame image/network/storage work from this surface. Do not claim battery/frame-rate measurements from code inspection alone.

Run the smallest relevant builds/typechecks and existing behavior/contract tests after exercising the surface. Fix clear failures in the changed path. For uncertain consumer-visible race/isolation behavior, retain deterministic failing-before/passing-after regression coverage following repository conventions. Do not add wording tests, copied-default assertions, wrapper/mock-echo tests, source-text tests or broad unrelated suites merely for ceremony. Use throwaway scripts for simple feature/API smoke, remove them afterward and report only actual exercised verification.

Where native runtime or physical camera/external display/second device is unavailable, state exactly which proof is missing, what available runtime was exercised and what the human must verify. Do not claim both-platform or physical-camera success from a simulator, compile, static inspection, preview or unrun scenario. Missing hardware is not permission to ship a production mock. No completion based solely on compiling or passing unit tests.

## Human Verification Handoff — Required

List each implemented responsibility and changed file separately. Explain the actual service integration and any known limitation, especially provider disclosure/global-deletion coverage, cross-device revocation and unavailable physical-camera proof. State which iPhone/native-Mac scenarios and focused checks were actually exercised, distinguishing them from remaining human verification.

Ask the user to review the code changes and the native behavior of every item. Ready for human verification is not human-verified, accepted or public-release-ready. Do not write logs, screenshots, completion checklists or implementation evidence into DOCKS.md. No screenshot/recording/evidence package is required. After the user accepts resulting behavior, update only the smallest relevant product context with the accepted plain-language decision.

## Agent Rules — Mandatory

1. **Single owner; no nested agents.** Do all work in this slice yourself. Do not spawn repository reviewers, design workers or delegated implementation agents.
2. **User direction wins.** Follow current explicit user decisions over historical side-by-side/secondary-Mac wording. Preserve the real physique product, not a substituted exercise or local-AI mode. Raise concrete security/legal/architecture conflicts instead of silently changing behavior.
3. **Independent implementation research.** Read relevant skills and actual code/contracts first. Reuse established account, style, native presentation, lifecycle and service conventions. Do not blindly translate DOCKS.md or newest-OS skill examples into code.
4. **Real connected behavior.** No production mock, placeholder/no-op button, invented recipient/retention fact, fake fallback judge/opponent/result, optimistic remote success or detached screen sold as complete. Preview fixtures stay explicitly labeled and isolated.
5. **Respect ownership and scope.** No unrelated feature, system-rule, target-minimum or global-theme edits. Shared privacy/match/global-deletion foundation changes require the reviewed owning contract; do not create a second convention.
6. **Complete and exercise the slice.** Connect callers, run actual changed native surfaces where runtime exists, run focused checks, fix clear failures, update affected consumer contracts and give an honest human-review handoff. Do not create a testing-only or obvious-bug-fix next phase.
7. **CYCLES is the task system.** Update only approved implementation todos after connected exercised work and the handoff are ready. A checkbox records implementation, never human acceptance. No IDE todo JSON or task checkboxes in DOCKS/prompts/audits.
8. **Keep product docs honest.** No code/payloads/recipes, implementation evidence or completion status in DOCKS.md. Accepted behavior updates occur after user review in the smallest relevant product context. Do not manufacture approval.
9. **Commit and push the scoped completed slice to origin/main.** Once implementation is authorized and focused native checks/handoff are ready, inspect the actual result, commit with a clear message and push normally. Do not stage or modify other workers' changes, force-push, rewrite history or leave this slice only local. If publication fails, state the exact blocker without claiming completion.
10. **No pointless next prompt.** Finish all reachable work of this functional slice. Create another prompt only for genuinely substantial separately owned implementation work authorized by the user, not testing, cleanup, documentation, a commit or a push. Missing real prerequisites are reported to their owner, not hidden by calling a scaffold a milestone.

## When You Finish

Report each meaningful implemented item and changed file, actual iPhone/native-macOS runtime checks, remaining explicit limitations and publication result. Ask for human review. State whether another substantial authorized prompt was needed; none is expected for this one surface. Do not claim accepted design, deployed processor configuration, completed deletion, physical-camera validation or human verification unless actually established by the relevant authority.

## Scope Decision Before Finish

Use ordinary factual statements, not a new project checklist: what is connected and exercised; what remains genuinely unavailable and why; whether a substantial authorized next implementation slice exists; and the decision to finish this slice, create that authorized next brief, or report the exact external/review prerequisite. No scope shrink or unimplemented action may be hidden behind an MVP/foundation label.
