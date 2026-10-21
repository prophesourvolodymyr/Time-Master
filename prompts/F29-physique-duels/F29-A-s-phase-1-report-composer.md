# Phase 1 of F29-A-s — Native Contextual Report Composer

## Assigned Model and Thinking

Run this implementation worker with **openai-codex/gpt-6.1-sol:max**. The model is **openai-codex/gpt-6.1-sol** and the thinking level is **max**. Do not silently substitute another model or thinking level. If the dispatcher cannot honor this assignment, report the actual limitation before implementation rather than claiming the requested dispatch occurred. This is the UI implementation worker assignment, not selection of the in-app appearance judge, moderation provider, or user AI Coach.

## Features Included

- F29-A-s — Contextual Report composer on native iPhone and native macOS.
- Context-bound reason and optional note, evidence disclosure, real submit/receipt/recovery, and the composer's withdrawal interaction.
- Independent immediate Hide and stage-aware Block integration, safe active-match continuity, bounded account-local draft preservation, and real private-case/scoring-review handoffs.

Each meaningful implemented item must be listed separately for human verification. Record implementation only under the authorized F29-A-s work in CYCLES.md; do not mark another owner's feature or human review complete.

## Context

Build the contextual native safety sheet for the Physique journey, not another body viewer or a generic support page.
The documentation pass chose a safe text target, required reason, optional note, bounded evidence explanation, one deliberate Submit action, and separate Hide and Block.
The service owns receipt, case identity, evidence access, blocks, match finality, and rating effects; this UI owns truthful presentation and safe local protection.

## What You Need to Read First

Read current versions before choosing source edits:

- `AGENTS.md`, as supplied in the project context, and the current `CYCLES.md` F29 plan and dependency/human-review records. Do not search the tree for additional agent instruction files.
- `features/F29-physique-duels/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-s-report-composer/DOCKS.md` — complete product behavior for this slice.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — especially Safety Access, Report Categories, Per-Image Hiding, Reporting Interaction and State Contract, Blocking Before and After Go, Private Case Status, and Evidence Minimization.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — especially Camera and Device Privacy Lifecycle, Authentication and Access, App-Controlled Data Lifetime, Deletion, and deadline semantics.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — Accepted Inputs and Judge Blindness, Explanations, and reportable explanation revisions.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — Go/cancel races, finality, blocks, one active match, and authorized correction boundaries.
- The current F29-F identity/country/badge context and already implemented caller/placeholder, case-center, scoring-review, camera, account, draft, and exit contracts. Discover their actual paths from the feature index and directory listings; do not assume proposed files exist or invent competing types.
- `TimeMaster/Utilities/Theme.swift`, lines 1–81 and 208–228: current shared palette/surfaces/actions.
- `TimeMaster/Utilities/ProfileDesign.swift`, lines 1–38: Inter typography, shared spacing, readable width, and touch convention.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift`, lines 20–80: availability-gated public materials, Reduce Transparency, and shared press response 0.24/damping 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift`, lines 15–108 and 148–188: current action and earned-Elo visual language. Do not copy its Dynamic Type clamps or imply a local display level is earned Physique authority.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift`, lines 25–151: exercise-only HUD context. Do not import live provisional appearance scores or a side-by-side duel into Physique.
- `TimeMaster/App/TmaxApp.swift`, lines 8–19: native Mac WindowGroup, normal title bar, existing 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift`, lines 6–37: preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift`, lines 23–27 and 99–109: local cosmetic badge previews and report drafts are not trusted competitive achievement, identity verification, or authoritative safety-case storage.
- `TimeMaster.xcodeproj/project.pbxproj`: preserve native macOS 14 and iPhone iOS 16 compatibility and the current toolchain; check target-specific values instead of upgrading deployment or Swift versions to satisfy a generic skill example.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png`: inspect the image. Borrow the dominant real timer and direct sports hierarchy, not its side-by-side people, overlapping badges, purple/brown web pills, faces, footage, text, or publishing rights.

The main design owner already selected **dimillian/swiftui-ui-patterns** through the UI Skills CLI. Use that selected pattern context without repeating setup or installing another visual system. Read the relevant installed SwiftUI/HIG guidance: `skill://swiftui-pro`, its accessibility/navigation references, `skill://swiftui-animation`, and `skill://apple-hig-reference`. For this task the narrow HIG chapters are Sheets, Designing for macOS, and Motion:

- https://developer.apple.com/design/human-interface-guidelines/sheets
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- https://developer.apple.com/design/human-interface-guidelines/motion

DOCKS.md is plain-language product context, not implementation authority. Reuse reviewed source patterns and independently validate technical choices against actual APIs and supported targets. Never put source code, pseudo-code, request payloads, test logs, screenshots, completion checklists, or implementation evidence into a DOCKS.md.

## What Happened Last Session

The previous work was a coordinated documentation-only design batch. This child received its own product context and this future implementation brief. No report composer Swift files, connected intake, draft store, case route, image assets, prototype, runtime proof, or human acceptance was created by that documentation pass. Existing F29 numerical policies were proposals, not measurements or blanket user approval.

The accepted direction for this pass was both native platforms, two large vertically stacked players at all widths, the real timer above complete owner-grouped public badge/identity rails, and animated minimal-text sports presentation. Some older F29-A wording permits a balanced two-column comparison and calls iPhone the first surface. The newer user direction supersedes that wording. Do not restore a horizontal matchup merely because an older document says it is permitted.

## Prerequisites and Human-Review Boundary

Implementation starts only when the real shared account, authorized persistent service, protected media, contextual safety intake, case identity/lookup, duplicate/add-context/withdrawal behavior, hide/block, draft protection, match/camera ownership, and native routing foundations are implemented and human-reviewed. Read the actual review records. A source file, pending checkbox, compiling scaffold, service proposal, or newly written DOCKS.md is not acceptance.

The report service must actually support authenticated context-bound targets, required categories and note constraints, stable submission reconciliation, existing-case lookup, case-authorized extra context and withdrawal, meaningful failure states, and the approved evidence policy. The actual service must support the documented pre-Go/post-Go block effects and no future pairing while block confirmation remains unresolved. Current operator contact, urgent-safety guidance, and the human review channel must be real, not sample URLs or a promise of staffing.

If an ordinary shared contract is already implemented but its client integration is clearly broken, diagnose and fix the scoped connected path; do not label a fixable local error unrelated. If a real prerequisite is absent or unreviewed, identify exactly which contract/review/authorization is missing and finish only genuinely reachable authorized work. Do not manufacture an endpoint, local receipt, fake peer, preview-backed production fallback, no-op destination, unsafe uploader, or a second report store to bypass it. Do not independently launch a backend or case-center implementation outside this slice.

Approved retention and operational disclosures must match the real service. The existing proposed bounds are twenty-four-hour ordinary media access, at most thirty days for necessary lawful evidence after the original received benign report, and a protected text-only draft of at most twenty-four hours or earlier discard/sign-out. Routine case correspondence is separate, with a proposed ninety-day post-closure bound. If approved policy differs, resolve that concrete product/legal discrepancy before presenting or submitting under misleading copy; do not quietly shorten or extend a hold in UI.

## Concrete Design Decisions

1. **One contextual native sheet.** A full-height iPhone composition sheet gives the note, reason, and evidence explanation enough room above the keyboard. A native parent-window-modal Mac sheet preserves scope without turning the report into a detached panel. No multi-step wizard or unowned report screen.
2. **Safe text target, no preview.** Use exact authorized match/account/content-version references with a neutral participant and pose/text-section label. Do not quote abuse or unsafe explanations, fetch thumbnails, or require enlargement. Opening an image/explanation report protects that item before any transition.
3. **No default allegation.** Require an explicit reason. Note is optional and multiline. A native semantic picker and one form are preferable to custom reason tiles or a second category sheet. The existing note budget is disclosed when relevant; do not invent another client limit.
4. **Submit is separate from protection.** Hide and Block work without a reason or report. No Report and block primary, automatic block, punishment animation, or rating advantage.
5. **Delivery is not review.** Keep Not sent, Sending, Receipt unknown, Received, Duplicate, and Withdrawal pending/unknown/confirmed distinct. A locally hidden image is not proof of a case or hold. Received means a real automated acknowledgement, not a human-review start.
6. **Preserve edits without corrupting receipt.** Capture one submitted snapshot. If text changes while sending, retain it as Not sent, not a mutation of the in-flight request. A late acknowledgement clears only its own snapshot and never silently appends newer edits to a case.
7. **Keep sports motion restrained here.** Use shared press feedback, 140–180-millisecond state acknowledgements, and one modest receipt settlement within 260 milliseconds. No ambient loop, body zoom, flashing warning, case progress meter, or celebration of punishment.
8. **Do not miniaturize the battle to fit reporting.** The composer is not another matchup. Any visible parent battle retains the real timer, all public badge rails above large vertical You and Opponent panels, aspect-fit evidence, and scrolling instead of shrinking or horizontal reflow.

## What to Build

### 1. Connected contextual entry and presentation

Connect every already implemented authorized Report entry for selected-still tiles and placeholders, intentionally opened stills, generated explanations, permitted profile/identity, active-match Safety, and saved match details. Preserve the exact target and version, not a display-name lookup or current scroll position. Use the existing presentation owner rather than adding duplicate sheets to each caller. Do not expose poses during capture/judging, after a forfeit/no-contest, without current consent, or after expiry.

A safe target reference includes the actual item kind, participant label, pose or explanation section, and appropriate match date/context. Avoid reflecting a reported offensive username in the sheet or accessibility tree. Change item, when available, lists only existing authorized targets in the same context with no imagery. It preserves the note and requires explicit category reselection if the category no longer applies; it never retargets an already dispatched request.

One native sheet owns Report, Close, the scrollable labeled form, evidence disclosure, independent protection, and Submit/recovery. Use native confirmation alerts for consequential actions rather than a stack of custom sheets. A real private-case or scoring-review handoff dismisses the composer after safely resolving newer unsent edits, then opens that already implemented owner.

### 2. Reason, optional note, and bounded evidence disclosure

Implement all F29-D safety reasons with no preselected accusation. The Nudity reason explains the lawful nonsexual shirtless-adult-man exception without guessing age/sex/gender, withdrawing the ability to report context, or requesting proof photos. Urgent personal safety states that the app is not an emergency service and exposes actual published appropriate help without location inference. Request scoring review is a separate route, not a safety reason that produces a complaint automatically.

Keep Reason and Note — optional labels visible. Native text input supports multiline notes, selection, dictation, composed characters, paste, and the current service's actual text budget. Empty note is valid. Field errors identify the exact required reason, note constraint, target, or authorization problem and retain valid work. Never silently trim an over-limit note or require personal contact information.

Show the short recipient/evidence/ordinary-retention explanation before Submit. Expanded Evidence and privacy explains minimum existing lawful evidence, reviewer-only access, no opponent access to report text, original receipt-based hold bound, no clock reset for duplicates/comments/appeals, unavailable-media limits, ordinary gallery expiry, separate case records/processor arrangements, and restricted legal-safety exceptions. Do not hide these facts to hit a word count or pretend a generic privacy link is informed disclosure.

No camera request, image attachment, library permission, file picker, image drag/drop, screenshot, download, forwarding, or reupload is part of reporting. The form uses an existing protected reference. Text paste cannot create an unsafe attachment or a new media cache. Report text, country, badges, identity chrome, and UI screenshots never enter the appearance judge's input.

### 3. Submission, reconciliation, duplicate, and concurrent-edit behavior

Use the real service's current authenticated submission and reconciliation contract, preserving one stable pending identity. Cover editing, invalid/missing fields, ready, sending, received, definite failure, offline-unsent, possible-acceptance/unknown receipt, checking status, retry, actual duplicate, intake-limited/unavailable, authorization expiry, unavailable target, and stale case status.

Gate repeat submission only; Close, Hide, Block, safe exit, and continued note editing remain usable. Keep the original dispatch snapshot distinct from later unsent edits. Do not let an edited reason, note, or target alter a retry of an uncertain request. Resolve receipt first. If new relevant text should be sent, require an explicit add-context action to the acknowledged existing case. If a newer draft has another target, preserve it separately and make that distinction visible instead of appending it to the wrong case.

A successful response shows the real case reference and receipt time. An uncertain response says Receipt unknown and offers Check status, never Report received or definitive Not sent. A known duplicate opens the existing authorized case; no extra case vote, evidence copy, or hold extension. Automatic receipt reads on safe return are not automatic resubmission of an offline draft. A late acknowledgement cannot discard newer text, reveal media, steal focus from another window, or apply an action to another account.

Keep published support and urgent-help access available when intake is unavailable or limited. Reporting remains free and independent of match allowance or judge credits. Do not add report counts, fake review progress, telemetry for private content, undocumented retry policy, or an extra moderation-provider integration.

### 4. Protected drafts, closure, and account lifecycle

Persist only permitted safe references, chosen reason, note text, original expiry, and the reviewed minimum pending receipt metadata; no photo, signed image link, thumbnail, quote copied by the app, or screenshot. Protect on the current signed-in device with a maximum twenty-four-hour text-draft lifetime measured from original draft creation; edits and reopening do not silently renew it. Clear sensitive unsent text on discard, expiry, sign-out, switch, and deletion. Do not synchronize drafts to other devices or reuse editable local Profile report records as service case authority.

A meaningful draft is a deliberate category choice or note edit, not an untouched contextual form. Close/swipe/Escape on an untouched form dismisses directly. With meaningful unsent work, use native Keep draft, Discard draft, Continue editing behavior. Offer truthful local-save status, including the real expiry time and a Draft not saved state when protected persistence fails. Do not claim Keep draft succeeded when storage failed. Discard never undoes local hiding, a confirmed block, or a possibly received request.

Closing a sent or uncertain request is not withdrawal. Preserve the service-authorized bounded minimal receipt reference needed to reconcile an already possible acceptance without preserving sensitive expired text indefinitely. At draft expiry, clear the note but do not claim a possibly received case vanished. A restored draft must belong to the same authenticated account and exact authorized context; late account restoration cannot leak old notes behind a new account.

### 5. Independent protection and stage-aware safe exit

Opening an image report immediately shields it; hiding applies before sheet motion or network work. Hidden image/explanation descriptions, captions, and help text must not expose old content to accessibility or app snapshots. Cancel and Close leave protection intact. Accurate placeholders distinguish Hidden by you, Reported only after receipt, Removed for safety, Sharing withdrawn, Blocked player, and Media expired. The composer has no View again control and cannot bypass a report quarantine or other access barrier.

Block requires its own standard confirmation, using actual service stage. Before Go it cancels a pairing without rating change; after Go it shields/excludes future pairings without leaving or finalizing the match. For a finalized match preserve the person's real record. Offline protection is immediate locally and labeled Block pending; do not claim cross-device or future-pair protection before confirmation, and do not permit another pairing until the block resolves. Do not expose the reporter's note or a who-blocked-you notification to the other account.

Opening reporting from capture stops acquisition and any pending capture timer immediately and shows Camera stopped. Match time continues. Reporting does not withdraw distinct processing permission or recall an already accepted processor request. Reuse the parent camera/privacy owner; do not rebuild it in the sheet. Keep the real stage/timer and Exit match reachable inside the modal. Report, Hide, Block, composer Close, and consent withdrawal must not masquerade as Forfeit.

Use the actual pre-Go cancellation and explicit otherwise-eligible post-Go Forfeit and leave route. A safety/invalid-evidence/service-established no-contest retains precedence. Handle a Cancel or Block racing Go from authoritative state rather than treating an earlier tap as consent to a loss. Preserve the original ninety-second capture deadline, retake counts, twenty-second reconnect grace, and thirty-second judging deadline after both sets are received. A result arriving during composition updates compact context without dismissing the draft or running a result celebration behind it. Closing returns to the safe actual current match state.

### 6. Real receipt and withdrawal interaction

Received shows a modest acknowledgement, actual case reference/time, View case, and Close. No auto-dismiss, guaranteed response time, claim of immediate human review, rating reversal, or punishment reveal. Use existing authorized case data for duplicates and later status. A stale response shows last confirmed status and retry, not a decorative review progression.

From a confirmed received case, Withdraw report is a secondary disclosed action. Confirm that review or a lawful hold may continue and that Hide/Block remain. Use real withdrawing, withdrawal-not-sent, withdrawal-not-confirmed, confirmed-withdrawn, rejected/no-longer-applicable states. Reconcile uncertain withdrawals against the same case/request. Report receipt still unknown requires receipt lookup first, not a fictional withdrawn success. Withdrawal is not data erasure, removal of an opponent, restored gallery access, consent withdrawal, or a competitive correction.

## Explicit Platform Deliverables

### Native iPhone

- iOS 16-compatible native large-detent composition sheet, leading Close, no auto-focused note/keyboard, safe target and persistent labels, scrollable form, and a safe-area Submit/recovery footer following actual keyboard geometry.
- Live-match timer/stage and Exit match remain reachable while the form scrolls. The camera is stopped, not hidden behind a sheet. Large text and short/landscape viewports scroll instead of cropping fields, hiding consequences, or shrinking people.
- At least the existing forty-four-point target convention for primary and safety actions, proper separation, accessible native reason selection, and intact multiline text editing. Keyboard Done ends editing, not reporting; hardware Return inserts a newline in Note and activates only a focused semantic button elsewhere.
- Swipe/outside/Close behavior obeys the actual draft/request state. Protection is immediate. Returning focus lands on the Report trigger or safe surviving placeholder/Safety action, never an automatically opened still.
- Any visible battle stage remains real timer, all public owner-grouped identity/badge rails, large You, large Opponent. No side-by-side reflow, hidden +N, three-slot cap, auto-ticker, badge overlay on a body, unequal image scale, cropping, or warping.

### Native macOS

- Native macOS 14 window-attached sheet, not Catalyst/web/stretched phone/persistent inspector. Keep the normal title bar, current commands, and app-wide 800-by-600 minimum. Bound sheet size to measured parent geometry and the existing readable-width convention; use a scrolling content region and native trailing action row.
- At minimum size, laptop sizes, full screen, large/external displays, and during live resize/display moves, keep target, text, disclosure, recovery, timer, and Exit reachable without text loss or new image requests. The parent players stay large and vertical at every width. Do not raise app/window minima or add a second matchup/report column.
- Support pointer hover, native pop-up selection, selection/caret editing, Tab/Shift-Tab, Full Keyboard Access, VoiceOver, and visible focus. No hover-only safety, lifting target cards, global Return/Space capture, or command reassignment. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- Escape closes transient pickers/input-method composition/confirmation first, then requests draft-aware composer Close. Cmd-W when the sheet owns interaction requests sheet close rather than silently falling through to an active-match window. Normal underlying window close/quit uses actual match consequences where confirmation is possible. Force quit cannot be prevented or called a confirmed voluntary forfeit.
- Other windows remain usable without creating another match, second camera owner, report transaction, or charge. The same report returns to its owning sheet/existing case rather than cloning private text. Inactive/minimized/background/locked windows stop acquisition and decoration and cover sensitive text/media; restore the same authenticated service state without resetting deadlines.
- TCC denied/revoked, missing camera, external-camera removal, and Continuity disconnect do not block reporting, erase text, open a camera alert, or generate a fake preview. Parent capture resume is explicit with current ownership/permission; no rated file-picker substitute.

## Motion, Accessibility, and Energy Acceptance

Match the complete animation table in the child DOCKS. Native sheet/keyboard timing stays system-owned. Feature-owned targets are: shared press response 0.24/damping 0.88; reason selection 160 milliseconds; disclosure settling 180; safe hide acknowledgement 140 after immediate shielding; sending/check status transition 160; real receipt symbol at most 1.04 scale over 180 and whole receipt section settled within 260; error/block/withdrawal/stage changes 160–180; inherited real timer digit change about 180. No artificial minimum wait or deferred action. Latest real state interrupts prior motion.

Do not add a composer ambient loop or run parent ambient/badge/result celebration while reporting. All safety, camera stop, authorization clearing, receipt state, and text preservation happen immediately, independent of animation. Reduce Motion removes scale/travel/repeating decoration and shows the same information with static replacement or brief opacity. Reduce Transparency uses readable opaque surfaces. Inactive/offscreen/minimized/background, low-power, and thermal behavior stop nonessential work; authoritative time and real receipt reconciliation continue. No per-frame provider work, I/O, image decoding, camera rebuilding, global geometry invalidation, or note persistence.

Observe actual heading/target/reason/note/disclosure/protection/action reading order. Status changes announce once; do not announce every tick or move the caret when a receipt arrives during newer text editing. Field errors identify the actionable field. After hiding, focus lands on the safe placeholder; closing returns to a surviving safe trigger. Hidden names, poses, and unsafe explanations must not remain in labels/tooltips/captions. Dynamic Type is not clamped, and accessible meaning does not depend on color, sound, haptics, hover, drag, long press, or motion. Apply the app's actual contrast and supported native accessibility settings rather than copying an older component's incidental limits.

## Prospective Files and Scope of Edits

Do not assume these files already exist; discover current source and reuse established ownership before creating anything.

- Prospective create: `TimeMaster/Views/Physique/PhysiqueReportComposerView.swift` — one adaptive native contextual sheet, using semantic system controls and shared styling.
- Prospective create only if not already owned: `TimeMaster/Models/PhysiqueReportComposerModel.swift` — disposable form/snapshot/draft/receipt presentation, not a second case service or rating authority. Keep state observation compatible with the current project rather than requiring a toolchain upgrade.
- Consume the already reviewed report/case, hide/block, protected draft, account, media-permission, camera, and match owners under `TimeMaster/Services/Physique/` and `TimeMaster/Models/PhysiqueDuelModels.swift`. Name their actual files in the pre-edit plan. Do not create a parallel network client, storage convention, retention engine, or local moderation authority.
- Modify only actual already implemented F29 caller/router files needed for the image/placeholder, explanation, identity, active-match Safety, saved-detail, private-case, scoring-review, and safe-exit handoffs. Establish the exact paths before editing; do not guess a gallery/case file or take ownership of those screens.
- Modify target membership/configuration only when the chosen native file placement actually requires it; preserve iPhone/macOS deployment and app capabilities. Do not edit the global theme, Profile shape, existing exercise privacy, root navigation choices, unrelated camera flow, or menu commands to accommodate this sheet.
- Add or update focused behavior tests only where they catch a plausible consumer-visible uncertainty and follow existing isolated test conventions. No source-text checks, wording pinning, mock forwarding echoes, or duplicate wiring tests.
- Update only the authorized implementation todos and honest handoff state in `CYCLES.md`. Product DOCKS changes after implementation require the user's acceptance of resulting behavior, except an already approved direct decision. Never add verification evidence or implementation checkboxes to DOCKS.md.

The target documentation files are this prompt and the child DOCKS. Do not generate unrelated prompts, README/CHANGELOG files, mockups, art, custom framework wrappers, or new feature documentation as part of implementing the report surface. If a shared caller/type is being edited concurrently by another owner, coordinate a single-owner serialized integration rather than overwriting that work.

## Observable Acceptance for Both Platforms

1. A real authorized report entry opens the exact safe item without enlargement, new body-media fetch, unsafe quotation, or extra attachment. Image/explanation protection precedes presentation and remains after Cancel/Close/failure.
2. Reason requires an explicit choice, optional empty note submits, relevant rule help and the minimum recipient/retention explanation are readable, and field errors preserve text. Request scoring review is a real separate route and does not send a safety allegation.
3. The service receives the selected snapshot once. Repeated taps, uncertain delivery, process/window recovery, late replies, and an existing duplicate resolve to one authorized case. Newer edits survive a late acknowledgement and are not silently appended or retried with changed content.
4. Offline before dispatch is Not sent; possible acceptance is Receipt unknown; Received requires the actual case acknowledgement. Draft preservation is truthful and account/device-bounded, never an evidence hold or automatic reconnect upload. Expiry/sign-out/switch clear sensitive text.
5. Hide and Block work without submission. Offline Block is locally shielded and pending, future pairing waits for confirmation, and pre-Go/post-Go/finalized consequences match the actual service state without rerating or leaving automatically.
6. Withdrawal uses the exact received case, distinguishes unsent/unknown/confirmed outcomes, and never promises deleted evidence, stopped legal review, reopened media, or a changed competitive result. View case reaches the real signed-in case owner without stacking sheets.
7. During live composition the camera is stopped, the real timer and safe exit remain reachable, deadlines do not reset, and an arriving terminal result preserves the report draft. Background/inactivity, TCC/Continuity interruptions, normal close/quit, and force termination retain their distinct meanings.
8. Native iPhone keyboard/large-text/short-screen interaction and native Mac 800-by-600, live-resize, external/full-screen, keyboard/pointer/multiwindow behavior are actually exercised. Parent battle hierarchy stays top timer, complete badges, large vertical You, large vertical Opponent wherever visible.
9. VoiceOver/keyboard focus, Reduce Motion, Reduce Transparency, high contrast, inactive/minimized, and low-energy behavior preserve every safety and recovery action without unsafe accessibility leftovers or replayed result/badge effects.
10. No production fixtures, fake case/peer/rating, provider key, no-op navigation, unsafe proof-photo requirement, private report logging, or claim of human approval exists. Public readiness is not claimed before actual protected intake and staffed moderation are available.

## Focused Actual Native Smoke and Checks

Run the changed surface, not just a build or snapshot. Use the actual authorized development/staging service and two consenting test accounts where a match is required. Test records must be unmistakably authorized test data; do not create false harassment/urgent-safety accusations against real people or alert an operating emergency channel just to prove a UI state. Preview-only fixtures may assist layout exploration only when clearly labeled and isolated from production; they are not service or camera proof.

Exercise a focused connected path on both iPhone and native macOS where runtime is available:

- Open from a safe existing image tile/placeholder without enlargement; observe immediate protection, exact neutral target, unselected reason, optional empty note, evidence disclosure, actual receipt, and real case navigation. Repeat an entry from the explanation and player-identity contexts to prove correct scoping and that system text is not blamed on a player.
- Type and edit a meaningful note, select a reason, close/keep/reopen, and exercise the actual validation boundary. Lose connection before dispatch, restore it without auto-send, then explicitly retry. Observe what was preserved and the eventual real receipt.
- Interrupt after possible acceptance and check the existing submission. Trigger a real known duplicate safely using the service's authorized test flow. Verify one case, no retention-clock reset, and preserved new context. Reorder a delayed acknowledgement while editing newer text using established deterministic test controls; the old snapshot cannot clear or submit the new draft.
- Switch/sign out and attempt safe restoration. Exercise discard and the existing bounded draft-expiry mechanism using established clock/test facilities, without changing device clocks or manipulating rated records. Verify no private old-account text, images, or receipt access. Simulate protected-storage failure through the existing test seam if present and observe honest unsaved recovery rather than adding a new production fallback.
- Independently Hide, Block before Go, Block after Go, and Block with confirmation unavailable. Observe local protection, real cancellation/continuation, no automatic forfeit or Elo correction, no second pairing while block is pending, and no body image reopening after form cancellation.
- From a confirmed safe test case exercise withdrawal and connection loss before/after possible receipt, then reconcile that same request. Verify no claim that every evidence record was deleted or review stopped.
- During an actual authorized active test match, open reporting and observe camera acquisition stop, unchanged service timer/deadline, accessible Exit, and safe return. Let a real stage transition occur while the draft is open. Do not fake this proof using a static timer or a file-picker pose set.
- On iPhone use the keyboard, large accessibility text, VoiceOver, hardware keyboard if available, small/landscape geometry, meaningful-draft swipe dismissal, and safe focus return. Confirm Submit/Close/evidence and active timer/exit remain reachable.
- On native Mac resize to 800 by 600, then laptop/full-screen/large-display sizes; exercise Tab/Shift-Tab, native reason picker, multiline Return, focused-button Space/Return, Escape, Cmd-W, existing app commands, another window, inactivity/minimization, and safe state restoration. Check that no duplicate camera/match/report or leaked report text appears. Name if a physical external display was unavailable rather than claiming it was tested.
- Run with Reduce Motion, Reduce Transparency, increased contrast, and the platform's available energy constraints. Observe immediate shields, unchanged receipts/timer/focus, no ambient or acknowledgement replay, and stopped decoration on inactive/minimized/background surfaces. Inspect actual native accessibility names, not only view source.
- If real camera/TCC/Continuity hardware exists, exercise denial or disconnect while composing and the parent's explicit resume. Otherwise name the missing physical-camera proof; a simulator or build cannot establish external/Continuity Camera behavior.

Run the smallest relevant current iPhone/macOS builds and focused existing behavior checks after locating actual schemes and test conventions. Keep permanent regression coverage for genuinely uncertain consumer-visible transitions, such as late receipt versus newer draft edits or account switching during receipt restoration, when the test infrastructure permits deterministic isolation. Do not create tests that merely assert copied strings, source code, forwarding, incidental colors/defaults, or nonempty output. Remove any throwaway smoke scaffolds after observing results; do not leave a test endpoint, mock receipt, changed device clock, or production fixture behind.

Record only exercised checks in the final handoff, including unavailable hardware/runtime/service proof. No compile-only completion, fabricated native smoke, inferred human approval, or broad accessibility/energy certification. If either target cannot run, state the exact missing runtime prerequisite and finish all reachable real work rather than disguising a narrower deliverable as both-platform verification.

## Human Verification Handoff — Required

List each implemented item separately for human review:

- Native iPhone composer, keyboard/layout, safe target and category/note/evidence interaction.
- Native macOS sheet, resize/multiwindow/lifecycle, keyboard/pointer/focus interaction.
- Connected send/unknown-receipt/duplicate/add-context behavior and preservation of newer edits.
- Bounded account-local drafts, persistence failure, expiry, sign-out/switch clearing, and safe close.
- Independent Hide/Block and real active-match camera/clock/exit continuity.
- Real case receipt/handoff and withdrawal/recovery interaction.
- Accessibility, reduced-motion/transparency, and energy behavior actually exercised.

List every changed file separately and explain its change. Ask the user to review the code changes and state that each implemented item is ready for human verification, not human-verified or accepted. State actual focused checks and the exact unexercised hardware/service/runtime limits. Do not produce a screenshot/recording/evidence package as a substitute for the handoff, and never put evidence in DOCKS.md. After the user accepts behavior, update only the smallest relevant product context in plain language.

## Agent Rules — Mandatory

1. **Single owner, no nested agents.** Do all implementation and review of this slice yourself. Do not spawn research/review workers, generation calls, or another model to implement the form.
2. **User direction wins.** Follow direct current decisions over older parent/prompt wording. Preserve native iPhone plus Mac, top timer, all public badges above large vertical players, minimal but truthful copy, and the real safety/privacy consequences. Surface genuine product/security/legal conflicts rather than silently narrowing scope.
3. **Independent implementation.** Use installed relevant skills and reviewed source patterns, not a second theme, unsupported version-26-only API, new toolchain, private API, or blind transcription of implementation recipes from docs.
4. **Real data and complete behavior.** No fabricated receipt, peer, score, rank, model confidence, staff response, backend fallback, no-op route, TODO implementation, fake attachment, client Elo, or production preview fixture. Preview-only data is clearly labeled and cannot enter production paths.
5. **Scoped integration only.** Implement the full connected composer and all affected actual callers/tests in this slice. Preserve unrelated work and every other worker's ownership. No Profile redesign, new badge system, backend rescue, camera rewrite, or unowned safety/case/scoring-review screen.
6. **Privacy is immediate.** Hide, camera stop, account clearing, and permission revocation never wait for animation or network. No sensitive report text/image-bearing session replay, provider keys, new camera/Photos/microphone permission, unsafe download/reupload, or appearance-based identity inference.
7. **Focused native checks.** Exercise the changed UI on both platforms where runtime exists, with the specific delivery/draft/protection/recovery scenarios above. Fix clear reproducible failures. Tests/builds alone are not running proof. Name physical-camera, display, or actual service limits honestly.
8. **CYCLES is the only todo system.** Update only the authorized implementation entries after connected behavior, focused checks, and a clear review handoff. Never mark human verification. No IDE todo JSON, new plan scaffolds, or evidence/checklists in DOCKS.md.
9. **Commit and push the implementation slice.** For this future implementation session, inspect the actual changed result, stage only your authorized files, commit each completed functional slice with a clear message, and push to `origin/main`. Preserve user/other-worker changes; never force-push, rewrite remote history, or claim publication when push fails. This rule does not retroactively authorize git in the earlier coordinated documentation worker batch.
10. **No unnecessary next prompt.** Finish the whole authorized connected slice, checks, clear fixes, CYCLES implementation record, handoff, and publication in this session. Do not hand off only testing, obvious bug fixes, documentation, commit, or push. Create another prompt only when real remaining work is a separate substantial approved implementation slice, never as a default phase-boundary ritual.

## When You Finish

Report the implemented items and changed files separately, actual exercised verification and limits, exact commit/push outcome, remaining external prerequisites or unresolved product decisions, and the human review request. Do not claim accepted visual direction beyond the user's actual decisions or imply that an automated receipt proves staffed review.

State a concrete scope decision: what connected behavior is implemented, what real work remains, and whether another implementation prompt is genuinely needed. The documentation pass that wrote this brief did not implement or verify any of these acceptance scenarios.
