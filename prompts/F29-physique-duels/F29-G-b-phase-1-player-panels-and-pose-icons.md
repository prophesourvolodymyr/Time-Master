# Phase 1 of F29-G-b — Player Panels and Pose Icons

## Model Assignment

Use **openai-codex/gpt-6-astra:max**: model **openai-codex/gpt-6-astra**, thinking level **max**. This is the native UI implementation worker assignment. Do not silently use a different model or thinking level; report a real dispatch limitation before executing under a different assignment. The suffix denotes thinking level, not another product model. This worker model is not the in-app Physique judge and must not change the service-approved judge or per-match judging version.

## Features Included

- **F29-G-b — Shared large participant panel:** truthful local preview/evidence review, authorized opponent avatar/progress, privacy protection, and native platform presentation.
- **F29-G-b — Shared neutral pose icons and illustrations:** Front, Side, Back, clear state semantics, safe original artwork, and accessible guide presentation within existing flows.
- **F29-G-b — Connected native behavior:** iPhone and Mac sizing, focus, real actions, interrupted media, reduced-motion and energy behavior, and integration into the reviewed stage/capture/result owners.

These are one owned functional slice, not a new lobby, judge, timer, badge system, capture service, or media-gallery screen. List each meaningful implemented item separately for human verification and update only its corresponding implementation todos in CYCLES.md.

## Context

Build the reusable participant and pose presentation inside the existing native Physique journey, not an isolated demo.
The user requires the real timer first, every authorized public badge above the players, and large You-above/Opponent-below panels at every width.
Privacy, actual service authority, complete recovery, and native iPhone/macOS behavior take precedence over fitting a screenshot into one viewport.

## What You Need to Read First

Read the current files, not remembered summaries. Paths below are relative to the repository root unless explicitly identified as an installed skill.

### Product, ownership, and review boundaries

- `features/F29-physique-duels/F29-G-native-ui-components/F29-G-b-player-panels-and-pose-icons/DOCKS.md` — this slice's complete product contract, including its state and motion tables.
- `features/F29-physique-duels/F29-G-native-ui-components/DOCKS.md` — shared native component boundaries and stage ownership.
- `features/F29-physique-duels/DOCKS.md` — shared contract and current product map, including the F29-F identity/badge owner.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — setup, camera switching, timed capture, retakes, exit, and result routes.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — anonymous judge inputs, the three poses, comparable evidence, and prohibited inferences.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — readiness/Go, authoritative progress and finality, reconnect, no-contest/forfeit, placement, and corrections.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — contextual moderation, private rejection, hide/report, and block behavior.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — face obscuring, current access, exact-preview boundaries, camera lifecycle, expiry, and account changes.
- `CYCLES.md` — actual foundation implementation and human-review status. A checked documentation task is not an implemented service or human approval.
- `features/DOCKS.md` — current feature ownership. Follow its links and the F29 parent to the actual F29-F and other G consumers; do not guess unpublished sibling paths.

DOCKS.md contains plain-language product context, not implementation authority. Validate technical choices against the current code, installed skills, and public platform APIs. Never add source snippets, payloads, project checkboxes, execution evidence, or implementation recipes to a DOCKS.md.

### Existing source anchors

- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing colors, surfaces, and control language.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter, established spacing, touch target, and readable width.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — Reduce Transparency, public availability fallback, and the shared press spring with response 0.24 and damping fraction 0.88.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — native action and earned-rating vocabulary. Do not import its Dynamic Type clamps or small-number compression into required panel instructions.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only; its provisional score/lead display is not a Physique requirement.
- `TimeMaster/Views/Ranked/RankedCameraPreview.swift` and `TimeMaster/Services/Ranked/RankedCamera.swift` — discover and read relevant declarations as nearby camera patterns; preserve exercise image-local promises. Do not duplicate the entire exercise camera path into this component.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar, and current 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable cosmetic badge previews are not trusted competitive achievements.
- `TimeMaster.xcodeproj/project.pbxproj` — inspect the actual targets and membership before changing files. Preserve the existing native macOS 14 and iPhone iOS 16 compatibility baseline; do not raise targets to use newer convenience APIs.
- The current reviewed source under `TimeMaster/Views/Physique/`, `TimeMaster/Services/Physique/`, and its actual model location — discover before opening files. Use real contracts and actual host names rather than manufacturing them from this brief.

### Visual and native guidance

- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow direct timer/participant hierarchy, not horizontal player placement, purple/brown pills, over-body badges, identifiable people, or assumed image rights.
- `TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png` — inspect the existing ivory/orange family. It is not a finished pose asset, nor a safe body-template instruction.
- Installed `swiftui-pro`, especially `references/accessibility.md`, `references/design.md`, and `references/performance.md`.
- Installed `swiftui-animation`, especially scoped state transitions, availability, interruptions, and Reduce Motion. Its newest examples do not authorize a target raise.
- Installed `apple-hig-reference`, then the live Apple chapters `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` and `https://developer.apple.com/design/human-interface-guidelines/motion`.
- Main selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI for this design batch. Reuse that selected context when it is supplied. It was not exposed under `skill://swiftui-ui-patterns` in the documentation worker's catalog; do not claim to have read an unavailable package or repeat unrelated setup. Available installed SwiftUI/HIG guidance remains usable, and any continuing context limitation must be stated.

No STYLES.md was present in the design batch. Existing native sources are the style authority; do not create a global style document or parallel theme.

## What Happened Last Session

The preceding slice was documentation only. It inspected the supplied battle screenshot, the existing Ranked hero, theme/type/control anchors, Mac window/command sources, relevant F29 product rules, installed native guidance, and live Apple macOS/Motion guidance. It specified two stable vertical panels, platform-appropriate aspect-fit wells, complete badge placement, a safe pose family, privacy states, and restrained real-event motion.

That pass did not build app code, generate art, run a native surface, verify a camera, establish service readiness, or obtain human acceptance of an implementation. Do not turn those design decisions into an implementation claim. The old F29-A wording allowed a wide two-column comparison and treated Mac as secondary; the direct user direction and new G contract require native Mac and vertical ordering at every width. Main owns reconciling shared documentation; do not silently revive the old layout.

## Prerequisites and Review Boundaries

Code starts only after the real shared foundations and contracts are implemented and human-reviewed. Confirm this from CYCLES.md and the actual source, not from a placeholder view or an aspirational DOCKS.md:

- Authenticated current-account identity, one active Physique match, cross-window/device ownership, and service-owned match restoration.
- A reviewed camera/redaction contract with local-only live preview, exact face-obscured selected representations, allowed source changes, safe stopping, and no unmasked transfer fallback.
- Authoritative phase, readiness, accepted evidence, retake, submission, timing, rejection, and terminal states. The model response alone is not finality.
- Current authorization for public avatars/identity and for private pose media, including immediate local protection and server-confirmed expiry/revocation consequences.
- F29-F's trusted identity/badge components and the G stage's timer, complete badge area, scrolling, reachable actions, and stable role order.
- Reviewed host routes for capture, local selection review, guide presentation, result media, Settings/device selection, and safety. A missing real action is not permission to put a disabled no-op button in production.
- A production-safe original or licensed Front/Side/Back artwork set, with rights and attribution where required. The existing hero is a style anchor, not this set. Obtain missing art through an authorized asset owner/path; do not use an unapproved generation call or a mislabeled exercise image to claim completion.

If any prerequisite is truly absent or unreviewed, name the exact missing dependency and finish all reachable authorized work without creating a production mock, speculative service shim, hidden sample match, or compiling scaffold. No dependency may be marked human-reviewed by this worker. Do not start an unowned feature to disguise a missing prerequisite.

## Concrete Design Reasoning Outcomes

1. **Stable vertical ownership:** You remains above Opponent in pairing, capture, waiting, results, and any battle comparison in the pose viewer. Winners do not reorder or grow. Wide Mac windows do not create a horizontal matchup.
2. **Large people instead of single-viewport compression:** both panel widths and media wells match; the middle stage scrolls under reachable timer/actions. All badge rows remain above the panels. Long badge collections and large text use height, not tiny players or a hidden remainder.
3. **Native geometry without evidence cropping:** iPhone uses a three-to-four portrait well; Mac uses a four-to-three well suited to desktop cameras. This distinction improves Mac camera use without changing vertical participant order. Every source remains uniformly aspect-fit, including mismatched source ratios, and both participants receive identical rules on that surface.
4. **Identity is not live evidence:** before a valid finalized, intentionally opened pose viewer, the opponent is an authorized avatar or neutral silhouette plus actual progress. A large neutral panel is preferable to a fake rival camera. No avatar becomes a pose or a verification claim.
5. **Guides outside bodies:** a small neutral pose illustration, role/status, and concise instruction occupy non-image regions. There is no target body overlay, muscle scan, inferred measurement, face/limb badge, or image manipulation for visual drama.
6. **Illustration teaches a safe orientation:** modest ivory athlete, opaque athletic top/shorts, featureless face, restrained orange, whole-body Front/Side/Back. Do not copy the existing hero's exaggerated physique or make shirtlessness the illustrated ideal. Compact labels distinguish Front and Back even when silhouettes resemble one another.
7. **Tactile feedback without misleading progress:** actual Ready and acceptance have small bounded state motion; pose changes preserve geometry; protection is immediate. There is no second ambient loop, provider-progress percentage, provisional score, or reward replay on reopen.

Explain resulting decisions and tradeoffs in the handoff, not private chain-of-thought. Do not replace this composition with a familiar exercise scoreboard or a generic video-call grid.

## What to Build

### 1. Shared participant panel connected to real state

Create or finish the smallest shared native component that renders the current role, source type, permitted status, media state, and its real contextual actions. Reuse the actual reviewed match/camera/media owners. The panel must not acquire its own competing camera session, calculate Elo, fabricate a service result, or manage an independent match clock.

Support local guide/off, requesting/starting camera, denied/restricted/unavailable/disconnected camera, live local preview, exact selected review, checking, accepted, retake required, submitted, stale/reconnecting, protected/hidden, and authorized final still states. Support opponent-unpaired/loading identity, authorized avatar/loading/absent/failed/withheld avatar, real readiness, authorized stage/count, and all applicable privacy states. A known absent avatar is different from an unknown identity or failed authorization.

Render actual source types honestly. Camera active is only for a running local camera. A selected still is not a frozen live feed; Submitted clears the live image and stops the camera through its owner. Do not continue capture under a covered guide, report form, or result. Public avatars need current permission; never auto-publish a local profile photo or reuse a previous account's private cache.

During a battle, supply equal-width, equal-footprint panels to the reviewed stage owner. The host retains the real timer first, both complete owner-grouped identity/badge rails next, and the vertical panels afterward. Keep the badge rails scrollable with the stage instead of pinning an unbounded wall. Do not add a three-badge cap, overflow remainder, clipped row, ticker, or hover-only badge detail. F29-F owns earned launch badges, current placed tier/current streak, unknown/stale data, unlocks, and corrections; the panel does not calculate or filter achievements.

Use clean image presentation. Preserve source orientation and every original pixel through aspect-fit display; do not fill-crop, stretch, normalize body height, auto-zoom a torso, sharpen contours, animate camera transforms, or clip the raster with rounded corners. Letterboxing is honest. Camera/pose images must not be altered to make one player visually stronger or larger.

Connect narrow relevant host actions rather than inventing an action per decorative region. Examples include the actual Enable camera, permitted Settings/Retry/device selection, guide, local review/retake, and authorized Report/Hide routes. Capture, Ready, Submit poses, Exit, and Safety remain in the host's reachable controls. The panel background is not a button.

### 2. Shared pose icon and illustration presentation

Use Front double-biceps, Side physique, Rear double-biceps in that order. Visible compact labels are Front, Side, Back; accessible labels use the full names. A compact icon and a large guide example may use approved variants of the same art family, not unrelated silhouettes.

Artwork must preserve head, hands, elbows, feet, and full ordinary side stance with balanced optical padding. Use featureless facial treatment, ordinary athletic proportions, opaque top and shorts, and restrained orange. No sexualized region emphasis, unsupported anatomical detail, copied real person, superhero comparison target, or inferred gender identity. Artwork illustrates posture, not a participant's actual body or the redaction algorithm.

Pose presentation includes readable safe instructions, not merely unlabeled glyphs. The rear pose is understandable before turning away. Existing self-timer/output cues can be offered by the capture host without a microphone request. Supported pose variations come from the evidence contract; the icon component cannot authorize a different rubric or label inability as a physique loss.

Local states are Not captured, Selected, Checking, Accepted, and Needs retake. Use semantic text plus outline/check/warning shape; color is supplementary. Selected count and accepted count remain distinct. Replacing a still invalidates the older acceptance immediately, and stale old-image responses cannot restore it. Retake availability and remaining count come from the real owner and obey at most two retakes per pose inside the original ninety-second capture period.

Do not derive named opponent slot acceptance from an aggregate count. If the reviewed service exposes only stage/count, display only that information. An accepted count of one does not prove that Front is the accepted pose after retakes.

### 3. Privacy-safe media lifecycle

Connect privacy at the real media boundary, not just by adding an opaque visual overlay over a still-fetching view. Hide, report, block, withdrawal, expiry, account change, and loss of authorization must prevent an already-pending reveal or stale asynchronous image completion from repainting protected content. Clear visible sensitive pixels immediately and remove their accessibility descriptions. Preserve legitimate nonmedia result history where authorized.

Transmit the camera owner's clean locally face-obscured evidence, never a snapshot of the view. Handles, optional self-declared country/region and flag, badges, Elo, avatars, pose art, framing guides, and all UI chrome remain outside judge images and context. Failed redaction stops transfer; a second person remains invalid even if masked. Neither view updates nor guide selection trigger upload.

Before finalization, no opponent live video, candidate, retake, or thumbnail appears. After a valid judged win/loss/draw, an intentional View poses route and a current access check are both required. Every relevant owner permission and safety gate still applies. Forfeit and no-contest never reveal a gallery. Ordinary media expiry is twenty-four hours after finalization and cannot reset on viewing or restoration.

Show accurate Hidden by you, Reported, Removed for safety, Sharing withdrawn, Blocked player, Media expired, or deleted/unavailable states as permitted. View again can reverse only a viewer's own hide choice while all other access conditions remain valid; it is not a bypass. Report/Hide stays reachable before enlargement. Block after Go shields and excludes future pairing but is not itself leave, a win, or a rating reversal. Offline local protection is immediate, while remote confirmation remains pending.

### 4. Real native iPhone and Mac behavior

On iPhone, use the host's measured safe areas and floating-control clearance. Keep the timer and essential actions reachable while both badge groups and both panels scroll. Large text wraps labels and may stack Front/Side/Back controls vertically rather than shrinking type or hit targets. Keep forty-four-point action areas. Rotation and landscape never switch to side-by-side players or reconstruct the camera just to resize.

On Mac, retain the normal title bar, native toolbar density, existing 800-by-600 minimum, and native permission prompts, device menus, sheets, focus, and keyboard conventions. At the minimum and short laptop windows, scroll the large vertical stage. At larger windows, full screen, and external displays, keep a centered readable column; a host-owned inspector may show secondary guidance but never move required badges or essential actions out of the main stage. Do not add a custom window chrome system or increase the app-wide minimum.

Live resize and display-scale changes preserve camera/session identity, role order, current pose, selected media, retake counts, focus, and scroll anchor. Avoid layout-driven restart of an underlying platform camera view. The source camera does not change when the window moves to a display without a camera.

Handle real Mac TCC denial/restriction, missing camera, another app holding a camera, and external/Continuity disconnection. No fake feed or rated file-picker fallback. Camera switching after Go uses the existing selected-set discard and recapture contract within the unchanged deadline. A temporary disconnect is not permission for an invisible new source or a client-forged no-contest.

Stop and shield immediately on inactive owning window, minimization, hiding, lock/background, or loss of current authorization. Restore the same service state before explicit permitted resume. No second camera/match/charge in a secondary window or device. Judging already accepted by the service may finish while the camera is stopped; return fetches its real result.

Route normal Cmd-W/Quit through the host's real pre-Go cancellation, eligible post-Go forfeit confirmation, or ordinary final-result close behavior where the platform permits. Stop camera independently of confirmation/animation. Force quit cannot be reliably intercepted and is not evidence of a confirmed voluntary forfeit. Do not override Cmd-N, Cmd-Shift-R, Cmd-comma, or Cmd-Option-O.

### 5. Focus and accessibility

Keep role headings and the actual visual/reading order. Expose each public badge through its real owner, not one giant inaccessible battle label. Group a camera as one local-preview description with actual phase and current guidance; do not announce frames or generate body descriptions. Mark an opponent avatar as not live video. Decorative pose art beside a named control is not a duplicate VoiceOver stop.

Expose complete pose names, meaningful status, remaining retake availability, and actionable private failures. Announce acceptance, interruption, retake needs, locked submission, and access removal once per meaningful transition. Do not announce every timer tick or steal focus on every acceptance/update. A blocking failure focuses its heading/recovery; returning from a sheet restores its invoker or the nearest surviving heading.

Use native semantic buttons and real disabled reasons. Keyboard navigation, VoiceOver, Voice Control, and Switch Control reach the same actions. Return/Space activates only the focused semantic control, not a global shutter while typing. Escape first cancels a reversible self-timer or handles the active presentation through its owner, then invokes state-aware exit rather than silent forfeiture. Do not discard report drafts through a panel-level key handler.

Hover and context menus are supplementary. No hover-only detail, body zoom, hidden safety control, or automatic image reveal. Color, animation, sound, and haptics are never the sole state signal. Increased Contrast, Reduce Transparency, and the largest supported text sizes retain the actual action and recovery path.

### 6. Scoped motion and energy behavior

Match the product motion table rather than inventing a second animation system:

- Existing shared press spring: response 0.24, damping fraction 0.88; no panel-wide press transform.
- Host stage continuity: approximately 280 milliseconds, once, preserving the two role locations.
- Actual Ready mark: at most 1.04 scale, settle within 200 milliseconds; remove immediately on readiness loss.
- Current pose: 180-millisecond guide crossfade and selected-outline change; never morph anatomical silhouettes.
- Current selected pose actually accepted by the service: one check/state-stroke event within 200 milliseconds, at most 1.04 scale. Final Accepted text is available immediately.
- Ordinary framing instruction: 150-millisecond status change, not a repeated per-frame pulse.
- Authorized loaded avatar or intentionally opened still: at most 180-millisecond reveal from neutral content. Never animate from another person's old image.
- Normal stop/submission: clear camera pixels immediately; only the non-sensitive icon/status may settle over 160 milliseconds.
- Privacy, safety, account, interruption, and media-revocation changes: immediate protection, cancelling every competing reveal or transition.

The panel adds no ambient loop, countdown, timer animation, Elo count-up, or badge-award choreography. The host may use its one quiet ambient layer and one focal event. Its real timer remains authoritative; no fake five-second judgement countdown. Do not replay acceptance, pairing, or rewards on resize/history/reopen.

Reduce Motion removes travel, scale, and repeating decoration while preserving final information immediately. Reduce Transparency uses the existing opaque fallback. Pause decorative work offscreen and when inactive/minimized/hidden/backgrounded; disable unnecessary decoration in Low Power Mode or elevated thermal conditions. Service deadlines continue. Evidence quality must not silently fall under an energy optimization; use the real unavailable/recapture behavior if the capture foundation cannot meet its contract.

Keep animation updates narrowly scoped. No per-frame network/provider calls, image decoding, filesystem work, badge sorting, font measurement, or full-stage invalidation. Preserve native preview identity through status changes and resizing. Avoid unnecessary image copies or bitmap snapshots, especially copies of sensitive frames. No private APIs, 26-only assumption, third-party renderer, or unrelated abstraction layer.

## Prospective Files and Scope

Discover the reviewed feature layout before deciding names. These are proposed ownership locations, not claims that files already exist:

- `TimeMaster/Views/Physique/Components/PhysiquePlayerPanel.swift` — the shared participant panel and its composition of real media/status/actions.
- `TimeMaster/Views/Physique/Components/PhysiquePoseIcon.swift` — shared named pose art and semantic state presentation, including approved compact/large variants where needed.
- Approved Front/Side/Back artwork in the existing `TimeMaster/Resources/Assets.xcassets/` catalog, with names agreed with the actual asset owner. Do not assume the illustrations are already delivered or hide their absence behind generic production mocks.
- The actual reviewed Physique stage/capture/result callsites that consume these components — identify their exact names from the repository and migrate all affected consumers; do not create extra screens just to demonstrate a component.
- A focused existing test location only for a genuine uncertain consumer-visible invariant or regression. Do not create a second test convention or source-text/wiring tests.
- `TimeMaster.xcodeproj/project.pbxproj` only if actual native target membership requires it; no target raise or unrelated project rewrite.
- `CYCLES.md` only for the implemented F29-G-b work and honest human-review state.

Reuse existing theme, fonts, materials/fallbacks, press feedback, standard dialogs, and native controls. Do not modify exercise scoring/privacy, Profile's two-side shape, local cosmetic semantics, provider configuration, or another worker's feature. Necessary host integration is part of this slice only after its ownership/review boundary is satisfied; coordinate an actual shared-file conflict rather than overwrite it.

## Observable Acceptance — Both Platforms

The deliverable is connected behavior, not compiling components or a preview gallery.

| Scenario | Required visible and behavioral result |
| --- | --- |
| Real pairing and all public badges | Real timer first; both complete owner-grouped identity/badge rails above the two large panels; You stays above Opponent at every width. No badge appears over evidence or vanishes into a remainder. |
| Small iPhone, largest text, and short Mac window | Readable controls/instructions, complete badges, and large panels remain reachable by vertical scrolling. Timer and safe actions remain available. Both full panels need not fit simultaneously. |
| Native Mac 800-by-600, laptop, full screen, and external display | Native title bar/toolbars/focus; centered vertical stage; no minimum-size increase or horizontal player breakpoint. Resize does not change camera ownership, selected evidence, pose state, or focus identity. |
| Portrait, landscape, and unusually shaped sources | Entire source remains aspect-fit with equal paired wells and honest padding. No rounded-corner body loss, stretch, dynamic torso crop, or favorable per-player scale adjustment. |
| Camera start and permissions | Permission is requested only after explicit setup action. Starting, active, denied, restricted, absent, busy, and disconnected states are distinguishable and have only real applicable recovery. |
| Selected evidence and source orientation | Exact face-obscured still is reviewable in its transmitted orientation; live mirroring is not silently applied to evidence. Uploaded media contains no panel chrome, identities, flags, badges, or guide art. |
| Local pose acceptance and retake race | Selected is not Accepted. Retake immediately removes superseded acceptance. A late result for the old image cannot reapprove it; counts/retakes/deadline remain authoritative. |
| Opponent capturing or submitted | Authorized avatar/silhouette and real stage/count only. No live video, early still, fake individual-pose acceptance, confidence, or provisional body score. |
| Submission, judging, reconnect, and terminal states | Camera stops/shields correctly. No resetting capture time, duplicate charge, fake countdown, or client-made finality. Forfeit/no-contest never exposes a pose gallery. |
| Valid finalized result | Still images appear only after intentional View poses and current permission. Role order, fit, full pose labels, and Report/Hide-before-enlargement remain intact. |
| Hide/report/block/expiry/withdrawal during a reveal | Sensitive pixels and their accessibility descriptions disappear immediately and cannot reappear from pending decode/load completion. Permitted nonmedia history remains. |
| App/window lifecycle and second window | Background/inactive/minimized state stops camera and shields immediately; return restores the same service state before explicit resume. A second window/device creates no new match, camera, or charge. |
| Keyboard, assistive input, and reduction settings | Same usable actions with keyboard, VoiceOver, Voice Control, and Switch Control; no global Space/Return capture while typing, hover-only action, or lost focus. Reduced modes retain truthful progress and recovery. |
| Reopen, resize, or result correction | No reward replay, duplicate acceptance, participant reorder, or stale badge privilege. Corrections/access changes are reflected only from their real owners. |

## Focused Actual Native Smoke and Accessibility Scenarios

Run the changed surface, not only tests. Use the real reviewed development/staging services, authorized test accounts, and consenting adult camera subjects. Never upload unsafe media or another person's reference photo just to exercise a state. Preview-only fixtures are explicitly labeled and remain unreachable from production participation; they are not a substitute for real connected proof.

1. Launch the native Mac target and the iPhone app. Enter the real Physique flow, show both rails and panels, and exercise the changed guide/review/capture or recovery path. Record exactly which runtime and state was exercised in the handoff, without storing sensitive screenshots or frame logs.
2. On iPhone, inspect the smallest supported layout, portrait and landscape, large Dynamic Type, safe-area action clearance, and VoiceOver traversal. Confirm whole-image fitting and that long instructions and three pose controls wrap instead of compressing or clipping. Exercise a timed-capture cancellation without accidental capture from an unrelated key or gesture.
3. On Mac, start at 800-by-600, then live-resize, shorten the usable content area, use full screen, and move to an available external display. Observe stable camera/pose state and vertical ordering. Exercise native keyboard navigation, focus return from guide/permission/safety presentation, and unchanged existing app shortcuts.
4. Use the actual permission/device path for camera denial and recovery. Where hardware exists, disconnect/reconnect an external or Continuity camera and demonstrate the real post-Go source-change restriction. Minimize/deactivate the owning window and return; verify camera stopping and explicit same-match restoration, not just that an overlay appeared.
5. Exercise one current-selection acceptance followed by a permitted retake and a stale old-selection response through the real reviewed contract. Confirm that the visible check/count cannot regress to the superseded image. Do not write a permanent test that merely asserts view wiring or echoes a mock.
6. With a real authorized result, intentionally open permitted media, hide/report without enlargement, and exercise revocation or expiry while a reveal/load is pending. Confirm no stale pixels or accessible image description returns. Also inspect real forfeit/no-contest routes and confirm that no counterpart gallery is offered.
7. Open a second permitted native window and restore the account state. Confirm a single camera owner and no second match/charge. Exercise ordinary close/exit confirmation separately from involuntary app/window interruption; do not label force termination as a confirmed forfeit.
8. Enable Reduce Motion, Reduce Transparency, and Increased Contrast. Inspect static equivalents, readable focus/status, and meaningful announcement frequency. Exercise supported low-power/thermal or equivalent controlled development conditions and offscreen/inactive transitions; observe that decorative work stops while deadlines remain real. Do not claim energy measurements from code inspection alone.

Use the smallest relevant build/check path for touched native targets and resolve clear local failures. Keep a permanent regression test only for a plausible consumer-visible bug or uncertain boundary, such as a revoked image resurfacing or superseded acceptance restoring; follow existing deterministic conventions. Do not test wording, file text, incidental default values, forwarding, or copied constants. Remove throwaway scaffolding after smoke proof.

If a physical iPhone, external/Continuity camera, external display, current service access, or another required runtime is unavailable, first verify what is actually reachable through the available tools/context. Name the precise unexercised scenario and missing prerequisite. Simulator layout proof is not physical camera/redaction proof; a Mac launch is not iPhone proof; a successful compile is neither. Do not claim the full connected feature complete while required foundations or real actions are absent.

## Human Verification Handoff — Required

List every meaningful implemented item separately: shared participant panel, pose art/state presentation, host integrations, privacy recovery, each native platform's behavior, and accessibility/motion work. List every changed file, say what changed, and ask the user to review the code changes and both native flows. Each implemented item is ready for human verification only after its real path and focused checks have been exercised; never claim human acceptance yourself.

State actual exercised verification and precise limits. No screenshots, recordings, evidence package, or sensitive image logs are required. DOCKS.md receives no test output, implementation checklist, or completion evidence. Update the smallest product context only after user acceptance, unless the user explicitly approved a product decision before implementation. Keep implementation status only in CYCLES.md.

## Mandatory Agent Rules

1. **Single owner; no nested agents.** Do the implementation and focused investigation yourself. Do not spawn review agents, silently reassign the requested model, or write another component owner's target.
2. **Respect prerequisite review.** Shared foundations/contracts must be real and human-reviewed before dependent implementation. No production mock service, fake camera, invented opponent, placeholder action, no-op recovery, local rating, or library-photo rated fallback.
3. **Complete the functional slice.** Build, connect every affected consumer, exercise actual native paths, fix clear failures, and hand off the complete scoped behavior. Do not stop at compiling UI or defer obvious integration/fix work to another prompt.
4. **Preserve native and privacy boundaries.** Both iPhone and native macOS are required. Preserve target compatibility, app commands, exercise image-local promises, one match/camera owner, authoritative deadlines/finality, and immediate media protection. Never commit secrets or sensitive captures.
5. **No unrelated changes.** Reuse established source/style patterns. No duplicate theme, custom framework-permission wrapper, speculative abstraction, global accessibility clamp, extra screen, provider change, or app-wide badge rewrite.
6. **Scoped commit and push.** For the future implementation session, commit each completed scoped work slice with a clear message and push to `origin/main`; never force-push, stage another worker's changes, or claim publication without observed success. This does not instruct the preceding documentation-only worker to run git; main publishes that integrated documentation batch.
7. **CYCLES only for implementation todos.** Mark only work actually implemented and checked, with a clear human-review handoff. Do not mark human verification or add IDE task JSON. Documentation tasks and implementation tasks are different.
8. **User direction wins.** Preserve the always-vertical native sports composition over old two-column or iPhone-only suggestions. Raise real security/product conflicts with a concrete safe alternative; do not silently substitute exercise performance for physique comparison.
9. **Independent implementation research.** Read the exact relevant source/skills and current public guidance; do not blindly implement recipes from product docs or copy unsupported newer APIs. Do not fabricate a missing runtime, asset, or check result.
10. **No pointless next prompt.** This brief owns the complete panel/pose slice. Do not generate a next prompt only for tests, obvious fixes, docs, commit, or push. A remaining substantial separately owned feature follows its existing approved plan, not an invented handoff.

## Scope Decision Before Finish

Report the implemented and actually exercised behavior, any real remaining prerequisite or platform limit, and whether any substantial separately owned work remains. State no next prompt when this slice is complete. If blocked, identify the exact unavailable dependency and attempted routes without presenting a scaffold or partial production fallback as a finished feature. Ask for human review of the code changes and native behavior; do not claim approval.
