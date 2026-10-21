# Phase 1 of F29-A-x — Native Deletion Entry and Truthful Status

## Assigned Model and Thinking

Use **openai-codex/gpt-6.1-sol:max**: model **openai-codex/gpt-6.1-sol**, thinking level **max**. Max is the worker's thinking level, not a different model and not an in-app judging tier. Do not silently substitute a cheaper worker or lower thinking level. If the requested dispatch is unavailable, report the exact limitation to the owner before implementation. This assignment does not change the service-approved Physique judge, provider, rubric, or per-match model policy.

## Features Included

- F29-A-x — F29 entry to the existing global Tmax account-deletion confirmation and supported reauthentication.
- F29-A-x — Private, service-authoritative deletion receipt and recovery, including unsent, unconfirmed, received, in progress, limited hold, active-system completion, and device-cleanup failure.
- F29-A-x — Explicit pre-/post-Go consequences, earlier media expiry, neutral counterpart identity, accessibility, motion, and native iPhone/macOS lifecycle integration.

List these meaningful tasks separately in the human handoff. Record implementation only against the owner's approved CYCLES.md items. This is one connected slice, not permission to independently ship a deletion-looking card before shared account and Physique contracts are real and reviewed.

## Context

The preceding work specified this area; it did not implement, run, or approve an account-deletion UI.
Use a quiet inline receipt and one global destructive flow, not a Physique-only account, duplicate reauthentication, progress ring, or sports deletion countdown.
Both native iPhone and native macOS are required; an unavailable dependency is not permission for a production mock or silent platform reduction.

## What You Need to Read First

Use repository-relative paths from /Users/volodymurvasualkiw/GSpace/Personal /Time-Master. Read the named product sections completely before editing; follow their cross-area privacy and competitive constraints, not only a screenshot.

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-x-deletion-status/DOCKS.md — complete owned composition, states, actions, retention, native behavior, and counterpart treatment.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — account routes, capture interruption, explicit exits, result/media paths, focus and state restoration.
- features/F29-physique-duels/DOCKS.md — shared boundaries, Go, finalization, separate Physique Elo, privacy and operational dependencies.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — Distinct Permissions and Choices; Refusal, withdrawal, and reconsent by stage; Authentication, Access, and Secret Boundaries; App-Controlled Data Lifetime; Deletion and Other Privacy Requests; operational failure states; provider retention.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — Allowance, Cancellation, and Interruption Boundaries; Authoritative Finality; Private Match History and Detail; public visibility and corrections.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — received versus unsent reports, evidence minimization, legal/urgent handling, block behavior, appeals and private status.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — Accepted Inputs and Judge Blindness; Accepted Judgements and Non-Scored Outcomes; no invented scores or judging reroll.
- features/DOCKS.md and CYCLES.md — current owners, approved work, shared-foundation review state, and this area's actual implementation authorization. The documentation cycle alone does not authorize production code.
- The reviewed F29 privacy host, shared global account router/status contract, media-access store, active-match owner, and F29-F public identity/badge ownership discovered from the current code and feature index. Do not guess that a proposed filename is implemented or invent an independent contract because the owner has not supplied one.
- TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift:1-101,291-297 — existing global settings, confirmation and account scope. Re-read changed sections rather than relying on this source snapshot.
- TimeMaster/Views/Ranked/RankedAccountView.swift — the current shared account presentation, not a new F29 authentication shell.
- TimeMaster/Services/Cloud/CloudAccountStore.swift:151-210 — actual sign-out, deletion, confirmation uncertainty, local-only sync and secure-local-cleanup behavior.
- ranked_server/src/account.rs:1-16,57-85 and ranked_server/src/lib.rs:237-253,639-651 — existing account freezing, cleanup, recovery and response boundaries. These are integration evidence, not a Physique deletion implementation or authorization to change unrelated server behavior.
- TimeMaster/Utilities/Theme.swift:1-81,208-228 — existing near-black, surfaces, orange actions and shared controls.
- TimeMaster/Utilities/ProfileDesign.swift:1-38 — Inter typography, scalable type and existing readable-column/spacing conventions.
- TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80 — public material availability fallback, Reduce Transparency and press response 0.24/damping 0.88.
- TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188 — shared sports identity/action language; do not copy Dynamic Type clamps, minimum-scale workarounds or fake levels.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151 — current sports HUD context only; do not copy its exercise provisional-score comparison into Physique.
- TimeMaster/App/TmaxApp.swift:8-19; TimeMaster/App/TmaxCommands.swift:6-37; TimeMaster.xcodeproj/project.pbxproj — normal native Mac titlebar, 800 by 600 minimum, existing commands and iPhone iOS 16/native macOS 14 compatibility. Inspect current target availability before using newer APIs; do not raise targets.
- TimeMaster/Models/LocalProfileModels.swift:23-27,99-109 — editable local cosmetic badge previews do not establish trusted competitive achievements.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the image. Borrow timer prominence/directness, not side-by-side players, web pills, people, footage, captions or implied asset rights.
- Installed skills: skill://swiftui-pro, especially references/accessibility.md and the smallest relevant data/navigation/performance sections; skill://swiftui-animation; skill://apple-hig-reference with the relevant live Apple topics below. The UI Skills selection inherited from the documentation owner is dimillian/swiftui-ui-patterns. Read its selected context if available; do not rerun setup to replace the choice or claim an unavailable skill was read.
- https://developer.apple.com/design/human-interface-guidelines/managing-accounts — Deleting accounts, completion and retention clarity.
- https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/ — straightforward initiation, associated-data scope, reasonable confirmation/reauthentication, timing and billing clarity.
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos and https://developer.apple.com/design/human-interface-guidelines/motion — actual Mac conventions and brief, optional, interruptible feedback.

DOCKS.md is plain-language product context, not implementation authority. Validate architecture, API availability and service behavior independently with current code, the relevant installed skills and current primary documentation. There is no STYLES.md in the documentation baseline; use existing source conventions and do not create a parallel global style document. No source, payloads, pseudocode, checklists or verification evidence belongs in DOCKS.md.

## What Happened Last Session

The documentation specialist chose an inline account-deletion entry/receipt, specified every request/recovery state, and separated the five easily confused actions: photo removal, sign-out, page removal, unlisting and global account deletion. The design preserves earlier media expiry, current authorization, private lawful holds, service-owned finality, and neutral counterpart labels.

The inspected global settings surface already presents a shared Delete your Tmax account confirmation and preserves the unrelated local library. The inspected account store treats deletion as a confirmed completion or error, disables database sync after uncertainty, and distinguishes remote success from secure-local-cleanup failure. That snapshot does not expose the granular received/progress/hold receipt, post-revocation status-reentry mechanism, deletion-specific reauthentication contract, or reviewed Physique match integration required here. Do not claim those capabilities already exist. Re-read current implementations: a later foundation slice may have added them.

The user-approved visual direction is native on both platforms, real timer first, every public badge in owner-grouped rails above two LARGE VERTICAL players, and animated but minimal-text sports feedback. Older balanced two-column wording in F29-A does not override it. No code, asset generation, runtime check, implementation completion, or human acceptance was established by the documentation pass.

## Prerequisites and Human-Review Boundaries

Begin production code only when the owner's shared foundations and the relevant contracts are implemented, connected and human-reviewed. Read their current DOCKS.md and CYCLES.md records; never infer acceptance from a compiling app, documentation placement, or automated checks.

Required account foundations:

- One shared global account route, supported reauthentication/ownership verification, and final confirmation capable of showing actual F29 stage consequences without another destructive wizard.
- Real account-scoped request authority with reliable distinction between never sent, acknowledgement uncertain, received, ordinary deletion work, limited retention, active-system completion and device-cleanup failure.
- A secure, bounded way to re-enter deletion status after ordinary account sessions are revoked. A receipt reference alone is not authorization. Do not keep a usable general session, require re-creation of a deleted account, or expose secrets to make the UI convenient.
- Actual local-cleanup recovery, cross-device reconciliation, an operator contact, adopted completion expectations, truthful backup/processor disclosures, and any real billing scope.

Required F29 foundations:

- Shared Privacy and sharing host and authorized global-account status slot, media revocation/cache clearing, account lifecycle and single camera owner.
- Service-owned Go ordering, explicit eligible forfeit, safety/invalid/service no-contest precedence, once-only rating and allowance effects, and final-result ordering.
- Protected image expiry/removal, lawful narrow evidence holds, no raw-media backup resurrection, private receipt authorization, and neutral counterpart identity/badge invalidation.

If a prerequisite remains absent, finish any reachable authorized integration analysis, identify the exact missing contract and owning area, and return that dependency to the main owner. Do not manufacture a local state machine, fake receipt, unimplemented button, preview-only production fallback, dummy service response, or a new global account system. Do not narrow delivery to one platform or a static card. This prompt is not authority to rescue all shared foundations in an unrelated rewrite.

## Concrete Design Reasoning Outcomes

1. **One global deletion route.** F29's Delete Tmax account… row opens the existing account deletion section. It never deletes on navigation and does not hide whole-account scope behind a Physique trash icon. A second confirmation wizard would create inconsistent behavior from Settings and F29.
2. **Receipt, not progress game.** The card keeps heading, state, short explanation and last-confirmed time. Access, Account data and conditional Retention are fact rows, not numbered steps. Details discloses more without hiding a hold, uncertainty, overdue estimate, cleanup failure or residual-completion qualification.
3. **Protection precedes receipt.** A deliberate deletion decision stops affected local capture/transfers and shields media immediately. The UI separately reports remote acknowledgement and remote revocation. Local hiding never pretends to erase another device or the service.
4. **No privacy delay for competition.** Opening help is not a forfeit; deletion never requires continuing capture, opponent approval or a resolved appeal. Only an informed post-Go departure accepted by the service can be an eligible rated forfeit. A stale pre-Go confirmation cannot silently authorize one.
5. **Earlier image expiry wins.** The proposed seven-day account target never extends ordinary twenty-four-hour media expiry or turns a lawful limited hold into public gallery access. Actual adopted service dates replace hardcoded operational promises.
6. **No deletion preview of bodies.** The receipt has no pose image or miniature duel. Wherever an authorized battle remains visible, keep the top real timer, all public identity/badge rails and two LARGE VERTICAL players, You above Opponent, even on a large Mac display. Missing authorization removes identity data, not just its caption.
7. **Private exceptions, neutral counterpart.** Use Unavailable player consistently for unavailable/deleted counterpart identity; remove identifying avatar/handle/country/unique badge combination/profile navigation when no longer authorized. Never expose received, held, appeal or legal status to the other player.
8. **Tactile but not celebratory.** Use the existing press spring and a single small receipt/check settle tied to real acknowledgement/completion. No pulsing badge wall, deletion countdown, progress ring, trophy, confetti or humiliating opponent motion.

## What to Build

### 1. Connect the scoped entry to the real shared account flow

Integrate one Delete Tmax account… row in the reviewed Privacy and sharing host, after its ordinary media/sharing controls and within a separate Account grouping. Keep the helper Deletes this account, not just Physique. Route through the existing shared presentation owner directly to its deletion section; do not stack two account sheets or auto-confirm a destructive action. Reuse the supported account verification and native confirmation controls.

Keep global scope, actual account identity, the unrelated local-library boundary, applicable billing facts, current match effect, earlier media removal and actual retention exceptions visible before confirmation. Do not reproduce the photo-removal, listing, consent-editing, support intake, page-management or authentication feature. Their distinction and existing route are enough.

The post-Go global confirmation must explicitly incorporate the departure consequence. A suitable action label is Delete account and leave match beside the visible conditional forfeit loss/used-allowance explanation. Its information and explicit consent must be equivalent to the match owner's Forfeit and leave confirmation; a generic account button must not silently perform a rated exit. No-contest precedence and finalization-first ordering remain real service decisions.

### 2. Connect the private receipt to authoritative state

Use the shared account owner's real request/status data and authorization. Add a single scoped presentation component, not another deletion authority or polling service. Support the complete DOCKS state matrix, including these distinct recoveries:

- Known unsent: Not sent, no received date, local protection stated separately, and explicit retry via the same shared flow after refreshing account/match context.
- Delivery uncertainty: Not confirmed and Check status first; never claim a lost response proves the server did not receive the request.
- Sending: genuine in-flight activity and duplicate prevention, with safe dismissal that does not promise to cancel accepted work.
- Received: real receipt and timestamp, confirmed access facts and actual completion expectation; not a completed account.
- In progress: real remaining work, no percentage, task-count animation, invented order or countdown.
- Limited hold: permitted category/reason/review or release condition; ordinary deletion continues and ordinary image access stays closed.
- Unheld data complete while a hold remains: Other account data deleted. Limited hold remains. Do not collapse to unqualified completion.
- Overdue or revised expectation: retain original receipt, show actual revised information or explicitly unknown completion time, with published contact and status refresh.
- Completed in active systems: show actual completion scope/time and visible bounded backup/processor qualification; ordinary sessions/media remain inaccessible.
- Remote complete/local cleanup failed: Account deleted. This device still needs cleanup. Retry device cleanup, not another account deletion or resumed upload.
- Offline/status error after receipt: retain last confirmed state/time and distinguish inability to refresh from stopped or cancelled deletion.
- Lost/expired receipt authorization: use the global secure status-recovery route; an error or HTTP gone/unauthorized response alone is not a completion receipt.
- Another device/late response: reconcile one request and current account scope; no state leak, duplicate operation, stale rollback or replayed animation.

The receipt remains in the same privacy-host position while ordinary account access is permitted. After session revocation, use the global account owner's authorized status slot/re-entry route without retaining unrelated private data or creating a new F29 status destination. A different signed-in account must never inherit the old card or an unsent draft. Respect the shared store's bounded protected context; do not persist passwords, normal sessions, body-image copies or confidential case text to keep the card alive.

Keep only supported actions. Do not add Cancel deletion, account restoration, a scheduling grace period, receipt export, a new provider, sign-in to a nonexistent deleted account, or guaranteed notifications. Contact support is a real existing recovery route, not a mandatory way to initiate deletion or evidence that an email was received by the deletion service.

### 3. Preserve stage-aware competition and media privacy

Before authoritative Go, acknowledged deletion cancels pairing without Elo change and releases the reservation once. After Go, only an explicit informed eligible departure is a forfeit with the slot consumed; safety, invalid evidence and unavailable service take no-contest precedence. A final result accepted first is not overwritten. A late pre-Go request cannot silently authorize a rated loss. Do not block privacy protection while resolving ordering, require the person to keep posing, or promise a processor recall that is unavailable.

Opening review/receipt alone is not withdrawal, account deletion or a rated exit. Camera acquisition stops when leaving its surface. Resume the same allowed state only by explicit existing Resume, with the real remaining deadline and no extra capture time, retakes, judgement, allowance charge or result. Existing capture, reconnect and judging owners remain in control.

Show the correct unavailable-media reasons through the existing media owner. Enforce current authorization across cached thumbnails, old signed links, another device and restored backups. Images are replaced immediately by safe placeholders; no old body fades behind an Expired badge. Pose galleries exist only for a valid judged win/loss/draw with intentional View poses and current permission, never for forfeit/no-contest. Judge only clean locally face-obscured accepted images, never this UI, country, badges or account context.

Use the real operator schedules. F29-E proposes ordinary account deletion within seven calendar days after confirmed receipt; selected/ordinary derived media by twenty-four hours after finalization or earlier authorized removal; orphaned uploads by twenty-four hours after receipt when not needed; necessary benign received-report evidence at most thirty days from the original report receipt; protected nonmedia backups at most thirty days under its separate policy. Do not treat proposals as deployed guarantees, renew holds, recover expired media for a new report, or apply a blanket seven-/thirty-day body-photo exception. Legal/urgent preservation and provider retention remain their actual disclosed scopes. No support action requests an unsafe screenshot, download, forwarded image or reupload.

### 4. Preserve native composition and interaction on both platforms

**iPhone:** use the existing safe content bounds and readable column. The row becomes a status card in place. Wrap all text and dates; fact labels stack at accessibility sizes. Use native account presentation/confirmation/secure entry with a full readable height when needed. Keep the host's safe dismissal and state action reachable above the keyboard. Retain the existing forty-four-point action convention, Dynamic Type, VoiceOver, Voice Control and Switch Control. Do not cap type or scale text down to preserve card geometry.

**macOS:** use the actual native target, normal titlebar and an attached shared account sheet. Keep the 800 by 600 minimum, native density, pointer hit testing, focus rings, permitted text selection and familiar toolbar actions. In short windows, scroll facts rather than hiding the primary/cancel action or raising the minimum. Laptop, large, full-screen and external-display layouts remain readable; live resizing does not reset focus, status, scroll or request identity. No separate floating receipt window or gratuitous inspector.

On either platform, this card creates no battle preview. If battle content is visible, its real timer is topmost, all public badges wrap in owner-grouped rails immediately below it and above both LARGE VERTICAL panels, and You remains above Opponent at every width. No hidden +N, three-badge cap, ticker, body overlay, favoritism in aspect-fit evidence or Mac two-column matchup. The stage scrolls in short/large-text windows; timer and safe actions remain usable. Current public badges are not copied from editable local cosmetic previews. Optional country remains self-declared and is removed when identity authorization ends.

Deleting/status does not require camera permission. TCC denial, no hardware, an external-camera unplug and Continuity Camera disconnect leave privacy entry operational and update only the real match/capture state. No fake preview, rated library upload or camera permission prompt on the receipt. Inactive/minimized/background/locked or nonowning windows stop acquisition and shield sensitive content immediately. Service clocks/deletion continue. Return fetches the same authorized state, never resumes a camera or opens a gallery automatically, and never starts a second match or charges another slot across windows/devices.

### 5. Implement exact focus and motion behavior

Focus the shared review heading on entry, not Delete. Use shared field-specific authentication errors. After deliberate submission and a real receipt, focus/announce the receipt once. Later updates announce only meaningful changes without taking focus from Details, selected text or another task. Dismissal returns focus to the original row or its receipt replacement; if the account is gone, use a safe available account control. Preserve neutral placeholder focus after revocation.

Return and Space act on focused semantic controls or native form submission only. Do not intercept them globally for Capture, Delete or Forfeit. Keep native text-editing shortcuts and the app's Cmd-N, Cmd-Shift-R, Cmd-comma and Cmd-Option-O. Escape cancels unsent review/authentication or closes an already sent receipt; it is not deletion, implicit forfeiture or request cancellation. Cmd-W/quit use the match owner's real state-aware consequence where the platform permits it, without duplicate deletion alerts. Force quit cannot be prevented and is not an explicit confirmed forfeit.

Use the DOCKS motion targets and supported APIs:

- Existing press response 0.24 seconds, damping 0.88; no second button effect.
- Native sheet/navigation/confirmation motion, with protection before presentation.
- First genuine receipt: one approximately 1.04-to-rest symbol settle over 200 milliseconds, concurrent with 180-millisecond status opacity. No replay on reopen or duplicate event.
- Real state-symbol/text changes: 160–180 milliseconds, newest authorized state interrupts older motion.
- Details: approximately 260 milliseconds, smooth, reversible, local to its card, stable scroll/focus; no expansion animation during live resize.
- First newly observed active-system completion: one quiet check settle around 220 milliseconds with the status text at 180 milliseconds, all settled within 300 milliseconds; residual qualification appears immediately, not after the animation.
- Privacy shielding, capture stop, access loss and account switch: immediate safe replacement; no outgoing sensitive frame, animated unblur or delayed revocation.
- Reduce Motion: static symbols/final text with immediate or at-most-120-millisecond opacity, no scale/travel/repeating decoration. Reduce Transparency: existing opaque readable fallback. Increased contrast and non-color status remain complete.
- No ambient deletion loop; pause underlying decorative battle work during consequential account review. Only a real in-flight foreground request gets an indeterminate native indicator. No infinite resting-state spinner, display-linked polling, per-frame provider/file work, image decode, camera rebuild or font measurement. Pause decoration when offscreen/inactive/minimized/backgrounded; use static feedback for low power/elevated thermal constraints. Do not pause authoritative clocks or erasure work.

Use only public APIs available at the existing deployment targets, with existing availability fallbacks. The installed SwiftUI skills' newest-OS examples do not authorize a target raise or private material APIs.

## Prospective Files and Integration Boundaries

Discover current files before modifying them and reuse established ownership. These paths are a prospective map, not a claim that a skeleton already exists or an instruction to create all of them.

- Create, if not already supplied by the owner: TimeMaster/Views/Physique/PhysiqueDeletionStatusView.swift — scoped entry/receipt presentation. Keep smaller native rows/disclosures local unless a real existing shared component already owns them. No unnecessary framework or duplicate generic status abstraction.
- Modify only the reviewed F29 Privacy and sharing host under TimeMaster/Views/Physique/ — insert the row/card and wire the already-reviewed account route. Resolve its actual filename from current source; do not create a parallel settings host to match a guess.
- Modify the reviewed active-match/counterpart/media presentation at the narrow owned seam, only if needed to route the account context or remove now-unauthorized identifying content. Retain existing safety/finality owners and every public badge of accessible players.
- TimeMaster/Models/PhysiqueDuelModels.swift and TimeMaster/Services/Physique/ — reuse the reviewed real presentation models, match and privacy owners. Do not add a second account-deletion state machine, auth client, media cache, countdown authority or status polling service here.
- TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift, TimeMaster/Views/Ranked/RankedAccountView.swift and TimeMaster/Services/Cloud/CloudAccountStore.swift — shared foundation boundaries. Use their existing reviewed entry/context/status contracts; any missing reauthentication, secure receipt, global deletion semantics or session cleanup belongs to the prerequisite owner, not an unreviewed rewrite inside this UI task.
- ranked_server/src/account.rs, ranked_server/src/lib.rs and ranked_server/schema.sql — trusted global/Physique service authority. No local substitute and no unrelated server rewrite. A required service-contract change must be explicit and reviewed by its owner before this consumer is claimed complete.
- Existing relevant behavior/contract tests — update only when a changed consumer-visible contract requires it. Keep real boundary/error/ordering coverage; do not add source-text assertions, forwarding mocks, copied-state tests or incidental-wording snapshots.
- CYCLES.md — update only the approved scoped implementation todos and honest human-review status. Do not reorder cycles or check off pending foundation/human-review items.
- The owned DOCKS.md — product decisions only, with changes after human acceptance except a directly approved prior decision. No completion evidence, task checkboxes, logs, screenshots, payloads, code or implementation recipe.

Do not redesign shared Settings, Profile, navigation, exercise privacy, public badges, provider configuration, billing or the whole app. Preserve unrelated/user/other-worker edits. No new global design document, README, changelog, IDE task JSON, asset pack or mock backend is in scope.

## Observable Acceptance — Both Native Platforms

These are future acceptance conditions, not reported results. The full owned DOCKS matrix also applies.

| Scenario | Observable required behavior |
| --- | --- |
| Enter from F29 and from global account settings | Same real global account deletion/verification path and scope; F29 does not submit on entry or add another destructive wizard |
| Photo removal, unlisting, sign-out and page removal | Their own existing functions remain distinct; none is reported as account deletion or a rating reset |
| Cancel review or reauthentication | No request or explicit rated forfeit is fabricated; camera remains stopped until a permitted explicit resume, original match state/deadlines remain real |
| Definitely offline versus response lost | Not sent differs from Not confirmed; local shielding is immediate; no remote deletion claim; Check status/retry resolves the same authorized request |
| Received and in progress | Genuine timestamps and actual remaining work/expectation; no percentage, countdown, sample receipt or inferred completion |
| Go occurs during a pre-Go request, or finalization wins the race | No silent conversion of pre-Go consent to a rated forfeit, no overwritten final result, no privacy delay, no extra allowance effect; service-owned outcome shown |
| Eligible post-Go explicit departure versus invalid/safety/service abort | Correct informed forfeit or no-contest precedence; no model/body scores or gallery for forfeit/no-contest; no local Elo |
| Limited hold and ordinary work completion | Scope/reason/release information as allowed; unheld data removed; ordinary viewing closed; state remains visibly qualified while hold remains |
| Ordinary media expiry during pending account deletion | Earlier expiry wins on all devices/old links/caches; no seven-day gallery or report-draft hold; no restored photo after sign-in/reconsent |
| Active-system completion with backup/provider residuals | Visible truthful qualifier, revoked ordinary access, correct completion time and supported recovery; no instant-everywhere-erasure claim |
| Remote success with local credential cleanup failure | Remote completion remains true, private UI stays shielded, retry is device cleanup and does not resend deletion/resume sync |
| Status error, expired authorization or deleted account session | Last confirmed facts retained safely; global secure status recovery works without ordinary deleted-account login; an error is not a success receipt |
| Different account, second window/device, relaunch and delayed response | No prior-account leak, second request, badge replay, restored session, duplicate match/charge or stale state rollback |
| Counterpart record after deletion | Unavailable player, neutral silhouette, no identifying avatar/handle/flag/badge trail/profile link or private hold details; only lawful minimum own-record facts remain |
| Visible battle on iPhone and Mac at every width | Real timer first, all current public owner rails above LARGE VERTICAL You/Opponent panels, no side-by-side layout, clipping, hidden badge cap or body overlays |
| iPhone largest type and native keyboard | Consequences and all actions remain readable/reachable with normal forty-four-point targets, no type clamp, no sheet stack or obscured submit/cancel |
| macOS 800 by 600, short laptop, large/full-screen/external display, live resize | Native attached sheet/titlebar, native focus/pointer/text selection, readable scrolling/actions, unchanged minimum, no reset or new camera/request on resize |
| VoiceOver, Full Keyboard Access, Voice Control and Switch Control | Correct heading/state/recovery order, field errors and return focus, no destructive default/global key interception, no per-tick announcement or hover-only information |
| TCC denial, missing/disconnected external/Continuity camera, inactive/minimized/background and force quit | Deletion remains available; capture stops/shields immediately; shared clocks/state remain authoritative; no fake preview, deadline reset or inferred confirmed forfeit |
| Reduce Motion, Reduce Transparency, increased contrast, low power and thermal constraints | Same facts/actions with static/short opacity feedback and opaque readable surfaces; no repeating decoration/polling/per-frame work or delayed privacy effect |

## Focused Native Smoke, Accessibility and Energy Scenarios

Run this section only in the future authorized implementation session. Use the smallest relevant existing build/test path, then actually launch and exercise the changed native surface on both platforms. Compilation or a preview is not proof. Do not rerun a user-reported failure merely to reconfirm it; diagnose from the supplied observation and verify after a fix.

Use approved isolated service operation and disposable test accounts, never the user's real account/data and never a live unsuspecting counterpart. Use consenting adults and lawful test media for physical-camera match scenarios. Do not manufacture a report against a real person or an unlawful-content upload to obtain a hold state. Any supported isolated operator controls must exercise the actual reviewed service contract, not a fake production client state.

1. **iPhone real entry/recovery:** open F29 Privacy and sharing, enter shared account review, cancel supported reauthentication/confirmation and return. Then perform an authorized disposable deletion. Observe the actual receipt/completion path, shield/access behavior, one request, and reachable status after normal-session revocation. Exercise both a definitely unsent request and a lost-response/refresh recovery through the approved service/network facilities.
2. **Mac real native interaction:** launch the native Mac target and perform the same entry/receipt route in an 800 by 600 window. Resize short and wide, enter full screen and use an external display when available. Operate pointer, Tab/Shift-Tab, focused Return/Space, Escape and permitted Cmd-W/quit. Keep existing commands working. Open a second window and confirm one shared request with no camera/match duplication or data leak.
3. **Boundary and ordering:** use the reviewed service's controlled isolated match scenario to cover pre-Go cancellation, Go crossing while receipt is uncertain, eligible explicit post-Go departure, a service-established no-contest, and a result finalized before deletion. Observe authoritative counterpart/result/allowance state, no silent forfeit, and immediate privacy protection. Use real physical cameras/two consenting adults where available; simulator or controlled service operation alone is not physical-camera proof.
4. **Retention and limited scope:** exercise the supported isolated ordinary-expiry/removal and lawful limited-hold paths with test data. Observe ordinary image access closed while only justified evidence is held, unheld data progressing, original clocks not renewed, no stale thumbnail/old-link/other-device bypass, and qualified active-system completion. Exercise remote success/local-cleanup failure through the existing approved isolated facility if available; do not add a shipping failure switch.
5. **Accessibility:** use VoiceOver and the largest relevant iPhone text sizes; on Mac use VoiceOver and Full Keyboard Access. Observe heading/error/receipt/placeholder focus, neutral labels, readable scope/retention/date/time zone, state announcements once, reflow/scrolling and recovery without hover/drag/precise gesture. Check Reduce Motion, Reduce Transparency and increased contrast on the actual changed surface.
6. **Lifecycle and energy:** open account review from a real active capture when available, switch apps/lock on iPhone and deactivate/minimize the owning Mac window. Observe immediate camera stop/privacy cover and actual unchanged service deadlines/status on return. Cover TCC denial and external/Continuity disconnect when hardware permits. Leave Received/Limited hold resting and offscreen; observe no decorative loop or display-driven status polling, with low-power/static feedback where available. Source inspection alone cannot prove physical power use; name the actual observation and unavailable instrumentation plainly.

Fix clear reproducible failures found in this focused work. If a contract edge is uncertain, retain a deterministic consumer-visible regression test following existing conventions, such as distinguishing unknown receipt from definitely unsent, preventing stale pre-Go confirmation from authorizing rated departure, or recovering local cleanup without resending deletion. Do not test mocked forwarding echoes, source text, implementation wording, mere nonempty content or bare not-throw. Temporary smoke helpers stay out of production and are removed after use. No permanent UI-test scaffold, screenshot package or exhaustive performance campaign is required.

If a native runtime, authorized service transition, camera hardware, second consenting participant, external/Continuity device or energy instrumentation is unavailable, state exactly what was and was not exercised. Use an honest focused throwaway smoke for reachable nonvisual behavior where appropriate, but do not call it native visual or physical-camera proof. Missing real infrastructure is a prerequisite gap, not permission to fabricate a success or mark end-to-end acceptance complete.

## Human Verification Handoff — Required

List every implemented meaningful task separately: global F29 entry; authoritative receipt/recovery; stage-aware privacy/finality; counterpart cleanup; iPhone composition; native Mac composition/lifecycle; accessibility/focus; reduced-motion/energy behavior. List every changed file separately and explain its narrow role. Ask the user to review the code changes and state which items are ready for human verification.

Report only checks actually exercised, the native platforms actually launched, and specific remaining real limitations. Do not claim human approval, operational deletion timing, legal anonymity, physical-camera coverage, measured power savings or completion from unrun checks. No screenshots, recordings, logs or completion evidence package are required. DOCKS.md never receives that material.

The human remains the final verifier. Update the smallest appropriate product context only after the user accepts a new behavioral decision, unless the user directly approved it before implementation. Do not mark a foundation or review dependency complete on behalf of another owner.

## Agent Rules — Mandatory

1. **Single owner; no nested agents.** Do the scoped implementation yourself. Do not spawn review, research, generation or implementation workers, change the requested worker model, or add an unrelated prototype/asset-generation task.
2. **Respect actual authorization and dependencies.** This prompt is future implementation context, not authorization from a documentation-only batch. Start code only once the main owner authorizes the slice and the required real shared foundations/contracts are human-reviewed. No independent release of a card over missing service behavior.
3. **Reuse, do not fork.** Use one shared account confirmation/reauthentication/deletion/status authority and the reviewed F29 owners. No second account service, retry engine, generic framework wrapper, fake backend, UI-only deletion, production fixture or local rating.
4. **User direction wins.** Follow the user-approved native iPhone/Mac, timer-first, all-badges-above-large-vertical-players direction over older two-column docs. Surface genuine privacy/security/product conflicts and concrete deviations rather than silently changing behavior. Resolve ordinary implementation details from source and existing patterns.
5. **No unrelated changes.** Preserve user and other-owner edits. Do not redesign shared Settings, Profile shape, navigation, exercise privacy, provider choice, billing, public badges or unrelated screens. Use only the smallest already-reviewed integration seams.
6. **Real state and privacy.** No fabricated peer, receipt, hold, score, completion date, percentage, confidence, rank or assets. Preview-only fixtures, if genuinely needed for development, are clearly labeled and never production fallbacks. Privacy/camera stop never waits for motion. Do not commit credentials, status-access secrets or personal test media.
7. **Focused actual checks.** Run the relevant focused checks, fix clear failures, launch the changed native surface on both platforms where possible and exercise the actual state/recovery path. Tests/builds alone do not prove native behavior. Report missing runtime/hardware/authorization honestly; do not substitute source-text tests or speculative exhaustive debugging.
8. **CYCLES only for implementation todos.** Update only approved scoped implementation lines after connected behavior and focused checks, with the human-review handoff prepared. Never mark human verification yourself. No IDE task JSON or task checkboxes in product docs, prompts or audit notes.
9. **Scoped commit and push.** After each completed implementation slice, inspect the scoped result, commit a clear change and push to origin/main using the owner's coordinated publication process. Do not stage/commit another worker's or the user's unrelated edits. Never force-push. If publication fails or coordinated ownership prevents it, report the exact blocker; do not claim the change is published.
10. **Complete the whole authorized slice.** Build real behavior, exercise it, fix clear failures, update approved implementation status, hand off every item and publish within the implementation session. Do not leave dead buttons, mock states, placeholder contacts, stubs or a testing-only/commit-only handoff.
11. **Keep product docs honest.** No implementation evidence, screenshots, logs, code, API payloads or checklists in DOCKS.md. Do not turn proposed seven-day or provider/backup limits into measured guarantees. Update accepted behavior in the smallest relevant product document after human review.
12. **No pointless next prompt.** Complete small remaining reachable work in this slice. Create a next prompt only for a genuinely separate substantial authorized implementation area; not for obvious fixes, testing, documentation, a commit or a push. A blocked prerequisite is named with its owner and missing contract, not hidden by a scaffold.

## When You Finish

Report the implemented items and changed files separately, native/focused checks actually exercised, known limitations and publication status. Ask the user to review every listed code change and identify the items ready for human verification. State whether a next prompt was needed; do not generate one by default.

### Scope Decision Before Finish

- Completed: only connected behavior actually implemented and exercised, with specific files and checks.
- Remaining: only real unresolved work or unavailable prerequisites, with the exact owner/contract/hardware/service gap.
- Decision: no next prompt, a separately authorized meaningful next slice, or blocked by the explicitly identified real prerequisite; never claim the human verified the work.
