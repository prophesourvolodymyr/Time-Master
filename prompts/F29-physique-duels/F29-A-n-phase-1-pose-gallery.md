# Phase 1 of F29-A-n — Native Pose Gallery

## Model Assignment and Mode

Requested implementation worker: **openai-codex/gpt-6.1-sol**, thinking level **max**. Dispatch shorthand: **openai-codex/gpt-6.1-sol:max**. Max is the worker's thinking level, not a different model or the in-app judging configuration. Do not silently substitute another worker/model or claim that a requested dispatch occurred when the runtime cannot confirm it; state the actual limitation.

This is a future implementation brief produced by a documentation-only design batch. Its existence does not authorize code before the prerequisites and human-review boundaries below are satisfied. The design batch did not implement this screen, generate gallery assets, run native checks, or establish a working media service.

## Features Included

- F29-A-n — Intentional gallery entry and return for one valid AI-judged win, loss, or draw.
- F29-A-n — Native iPhone and native macOS composition: real expiry timer, complete public identity/badge rails, and two large vertical participant panels.
- F29-A-n — Synchronized Front/Side/Rear navigation, faithful aspect-fit evidence, and independently loading/unavailable images.
- F29-A-n — Per-image immediate Hide and contextual Report, using the reviewed safety/report/block/privacy owners.
- F29-A-n — Current authorization, twenty-four-hour expiry, revocation, deletion, correction, account, network, and privacy-lifecycle handling.
- F29-A-n — Keyboard/focus, assistive technologies, large text, reduced-motion/transparency, and restrained energy-aware feedback.

Implement and list each meaningful item separately for human verification. CYCLES.md alone records implementation work; no claim of human acceptance follows from passing engineering checks.

## Context

The gallery intentionally exposes only authorized, moderated selected stills after a real final judged result, never live or early opponent media.
The user requires both native iPhone and macOS, all public battle badges above large vertically ordered You/Opponent panels, animated tactile chrome, and minimal visible text.
This phase consumes reviewed shared services and native components; it does not create a second competitive authority, body-photo exporter, safety center, or mock backend.

## What You Need to Read First

Read the current files, not a remembered earlier draft. Resolve renamed source paths through the repository rather than opening guessed files.

### Product and review boundaries

- `AGENTS.md` as already supplied by project context; observe its user-direction and human-review rules.
- `features/DOCKS.md` — current F29 child map and the exact registered paths for F29-F identity/badges and shared native foundations.
- `CYCLES.md` — the F29 cycle, this child, the actual status of shared account/native/service dependencies, and any explicit runtime constraints from the user.
- `features/F29-physique-duels/DOCKS.md` — shared Physique contract and product/privacy boundaries.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — result entry, presentation ownership, safe navigation, and integration map.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-n-pose-gallery/DOCKS.md` — complete gallery behavior. Read all sections before choosing implementation.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md` — accepted inputs, common-region evidence, final judged outcomes, and anonymous clean judging context.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md` — authoritative finality, historical match context, private detail, blocks, corrections, and record invariants.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md` — per-image hiding, report receipt uncertainty, offline drafts, blocking, evidence holds, and safe case routes.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md` — current media authorization, withdrawal, local caches, snapshot privacy, deletion, exact lifetime, and service operation.
- Follow the main-owned index to the actual result-detail, contextual-report, Privacy and sharing, F29-F identity/badge, and shared stage/timer/privacy foundation documents and source. Reuse their reviewed contracts; do not guess their child names or create competing copies because a planning name differs.

DOCKS.md is plain-language product intent, not a technical implementation recipe. Validate technical choices independently against actual source, deployment targets, installed skills, and current platform documentation. Do not put source code, payloads, implementation checklists, smoke logs, or completion evidence in DOCKS.md.

### Supplied visual and source anchors

- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual reference. Borrow the direct timer/identity/player hierarchy, not its side-by-side structure, overlays, web pills, footage, text, people, or image rights.
- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing palette, surfaces, shared actions/back behavior.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter typography, existing inset/spacing, readable width, and iPhone action convention.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public/native availability fallback, Reduce Transparency, and shared press spring response 0.24/damping 0.88. No private rendering API or new glass system.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — familiar action and earned-Elo language. Do not inherit Dynamic Type clamps, tiny illegible text, exercise imagery, or fake display levels.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only. Its provisional scores, camera behavior, and exercise timer are not this gallery's state.
- `TimeMaster/App/TmaxApp.swift:8-19` — native Mac WindowGroup, normal title bar, existing 800-by-600 minimum.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable cosmetic badge previews are not trusted competitive awards or identity verification.
- `TimeMaster.xcodeproj/project.pbxproj` — inspect the actual iPhone/native Mac targets and membership; preserve iPhone iOS 16 and native macOS 14 compatibility. No target raise to use a convenient new API.
- STYLES.md was absent in the design batch. Use the existing source conventions; do not create a global style document or second theme.

### Relevant native skills and primary guidance

The coordinating owner selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selected context rather than repeating installation/setup. If not exposed as an installed worker skill, its source is `https://github.com/Dimillian/Skills/blob/main/swiftui-ui-patterns/SKILL.md`; read the relevant `references/async-state.md` and `references/sheets.md` linked there. The design worker used that upstream source because its skill resolver did not expose the selected slug. Do not treat that limitation as permission to skip native research.

Read installed `swiftui-pro` and its accessibility, navigation, design, and performance sections selectively, plus installed `swiftui-animation` for scoped, interruptible motion. Their default newest-platform assumptions do not override this repository's deployment targets. Use the narrowest existing state/lifecycle pattern; no new app-wide router or observable framework solely for this gallery.

Read the live Apple HIG topics `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` and `https://developer.apple.com/design/human-interface-guidelines/motion`. Relevant principles are native resizable windows, comfortable information density, keyboard access, normal full screen, purposeful short feedback, optional motion, and cancellation. Numerical well/timer choices here are product decisions, not Apple-mandated measurements.

## What Happened Last Session

The documentation specialist read the shared batch contract, F29 parents and relevant B/C/D/E context, the supplied screenshot, native source anchors, installed SwiftUI/HIG skills, the selected upstream UI-pattern source, and the live Mac/motion HIG. Only the assigned gallery DOCKS.md and this future brief were authorized outputs.

The gallery design chooses a paired pose reel, lifetime timer, all badges outside media, equally framed aspect-fit originals, and immediate privacy/safety protection. Earlier parent options for wide side-by-side comparison and per-image expansion are superseded for this child by the user's newer direction. Main owns reconciliation of existing shared files, the index, CYCLES, integrated documentation validation, and publication of that batch.

No native gallery implementation, service deployment, moderated evidence set, physical-camera run, accepted prototype, generated asset, engineering verification, or human approval was established by this documentation work. Check the current repository/review state before starting; do not promote documentation facts into working-foundation claims.

## Prerequisites and Review Boundaries

Code starts only after all of the following exist as connected, implemented, human-reviewed foundations, with real service contracts available to inspect:

- Account/session ownership and conventional authentication, participant membership, adult-view eligibility, and account-switch cleanup.
- Service-finalized result/history semantics, including effective corrections, valid judged versus forfeit/no-contest distinctions, and the original authoritative finalization/expiry relationship.
- Protected, current participant-only media access for accepted redacted stills, per-owner authorization/revocation, removal, expiry, invalidation, and no stale-link/cache bypass.
- Operational moderation, contextual reporting with real submission/receipt/case states, viewer-hide persistence, block effects, privacy withdrawal/deletion, and published support routes.
- Canonical F29-F identity/country/badge rail and shared native timer/stage/privacy lifecycle components. Public awards come from the service, never editable local badge previews.
- Result presentation/navigation and existing report/privacy/safety destinations ready to host this surface on both native targets.

A view compiled against interfaces or previews is not an independently shippable gallery. Missing access enforcement, unsafe media storage, unknown expiry, unavailable report receipts, or unreviewed prerequisites must not be hidden with fake success, local finality, permissive cache access, or production mocks. First exhaust reachable repository/context information; state the exact missing real prerequisite and finish reachable scoped work without pretending the feature is complete. Do not build an unowned backend or unrelated screens to bypass review boundaries.

Once foundations are available, implement the complete connected child rather than a static shell. Preview-only fixtures may be clearly labelled and isolated from production if existing conventions need them; they do not satisfy native/service acceptance. Do not generate or obtain new personal-media assets for this task.

## Design Reasoning Outcomes to Preserve

1. **Paired pose reel, not a six-tile grid.** One named pose selects both participants. Large full-width evidence avoids thumbnails and makes target identity explicit; scrolling is the deliberate tradeoff.
2. **Always vertical, not responsive side-by-side.** You stays above Opponent at every width, including Mac full screen and external displays. A wide window is not permission to reverse the user's hierarchy.
3. **Timer means remaining media access.** Use the actual twenty-four-hour deadline from finalization, explicit units, stable digits, and an Expired terminal state. Do not replay the finished match clock or invent a judging countdown.
4. **Every public badge precedes both images.** Wrap the complete canonical owner rails, with no cap, +N, ticker, clipped row, or overlay. Let rails scroll rather than pinning an unbounded wall. Unknown/corrected awards remain truthful.
5. **Equal wells, unmodified evidence.** Equal portrait 3:4 presentation wells at the same readable width, original aspect-fit orientation and neutral letterboxing. No crop, mirror mismatch, anatomy-based sizing, enhancement, mask removal, or suggestion that pixel size is a physical measurement.
6. **Safety beside evidence, never inside it.** Caption plus visible Hide and Report above each well, including safe placeholders. No enlargement, hover, thumbnail, or precise gesture is needed. Sensitive pixels disappear before network acknowledgement or decorative movement.
7. **Tactile controls, quiet evidence.** Shared press spring and synchronized pose marker provide feedback; brief image/status entrances preserve context. No ambient loop, body morph, intimate scan, confetti, unlock replay, or loser effect.
8. **No gallery exports.** No Save, Share, Copy image/link, Print, drag-out, Quick Look, image Services handoff, opponent share, or Photos saving. The separate own-result card receives no gallery media/opponent data.
9. **Current permission outranks loaded pixels.** Offline/unknown access, account switch, block, revocation, deletion, expiry, or an ineligible corrected result removes pixels and wins against late completions. The timer is not an authorization grant.
10. **Native Mac destination, not a phone modal.** Normal titlebar/toolbar, centered readable stage, scrolling at 800-by-600, keyboard work, normal full screen, and no new inspector or app-wide minimum. Reuse existing native report/privacy presentations.

## What to Build

### Connected entry and ownership

- Connect the real result's deliberate View poses action to the gallery for the current authenticated participant only. Preserve the result and invoking focus on return.
- For pending/judging, forfeits, no-contests, unknown finality, unauthorized users, or ineligible adult/restricted states, do not fetch/reveal counterpart stills. A stale route must be safe and provide Back to result plus legitimate safety access without exposing private membership.
- Resolve the account, exact result, effective correction, accepted image identity/version, owner-specific access, moderation/block state, and expiry from the reviewed shared contract. The UI does not create a second source of truth or recalculate competitive outcomes.
- Route notifications/external links to the authenticated result. They cannot directly reveal the gallery or preload a sensitive thumbnail as a preview.

### Both native compositions

- iPhone: large full-height native sheet with Poses/Close/Safety; dominant expiry readout; scrolling complete You and Opponent rails; large You then Opponent panels; reachable native labelled pose selection in the bottom safe area. Reflow large-type choices instead of clamping text or covering evidence.
- Mac: destination within the existing window; Back to result, native pose selector, Safety and information action in the standard toolbar; dominant expiry below; readable centered single scrolling stage. At 800-by-600 retain timer/actions while rails/panels scroll. Laptop, large, full-screen, external-display, and live-resize states remain vertical.
- Use existing shared colors, typography, controls, badge explanations, country fallback, and spatial conventions. Both complete identity/badge rails appear before any media. Correctly label match-time versus current public data; use canonical F29-F ordering and eligibility.
- Use equal available-width 3:4 wells with safe letterboxing and outside captions/actions. Retain the full original evidence rectangle without rounded-corner clipping. The image is inert and cannot enter an enlargement destination.
- Use the existing information/privacy presentation for exact localized expiry time, audience, twenty-four-hour origin, screenshot risk, and the bounded-report-hold distinction. Do not add another custom screen to show a few lines.

### Pose selection and real image delivery

- First intentional open selects Front. Front double-biceps, Side physique, and Rear double-biceps update both participant captions/slots together.
- Remove old-pose pixels before changing their meaning. Preserve neutral well geometry during independently loading/error/unavailable items. Never show Front opposite Side or borrow a retake/another match.
- On selection, keep selector focus and show the start of the paired evidence region rather than the previous lower-player scroll offset. The full rails remain above the pair in document order and reachable by normal scrolling; do not auto-replay them on each selection.
- Cancel obsolete display work and reject late results for the wrong account, closed destination, match, pose, media revision, permission state, or deadline. A small focused implementation is preferable to new generic request/caching infrastructure.
- Give a real retry for a recoverable same-image failure or decode error. Service-confirmed removal/expiry is not retryable access; an unknown transient problem is not a safety accusation or an expired-image claim.
- Preserve uniform scaling, judged orientation, local face treatment, and source integrity. No judge/model invocation or evidence reupload occurs in the gallery.

### Hide, Report, block, and privacy integration

- Hide each image immediately, independently, including offline. Display Hidden by you and honest sync status. View again reverses only that hide after every other current condition allows access.
- Report immediately hides the target and opens the real shared form with safe fixed participant/pose/image context, no thumbnail/attachment. Cancelling an unsent form preserves hiding. Only a real receipt becomes Reported.
- Preserve actual editing/validation/submitting/Not sent/Not confirmed/Received/duplicate/unavailable states. Shared bounded text-only drafts and duplicate recovery apply; do not make a false case or media hold from a local draft.
- Keep existing case/support and text-based reporting reachable from unavailable/expired placeholders. Expiry during editing removes media but does not silently discard safe report text or demand a new image copy.
- Use existing Block and Privacy and sharing flows. A finalized block shields the whole pair locally immediately and follows real service confirmation; withdrawal removes the affected owner's stills, not the other's independently authorized set. No report/block/expiry action changes Elo locally or creates a forfeit.
- An unblock, reconsent, report withdrawal, appeal, or ordinary refresh never auto-reopens old images or restarts their window.

### Lifetime, lifecycle, and multiple windows

- Use confirmed finalization plus the unchanged twenty-four-hour window and service-owned current access. Local clock changes cannot extend it; ambiguous time/access shows a safe status.
- Display hours/minutes above an hour and minutes/seconds below it. At the exact deadline immediately replace ordinary media with Media expired and the timer with Expired. A signed link, decoded bitmap, thumbnail, in-flight request, or restricted case hold is not a bypass.
- Shield on app resignation/background/lock, minimized or occluded sensitive windows, and app-switch snapshots. Stop unnecessary image work and decoration immediately. Foreground return revalidates actual state and requires deliberate View poses before revealing again; retain only safe pose/scroll context.
- Account switch/sign-out/deletion clears the previous private surface and unsent drafts. A correction to no-contest or other loss of gallery eligibility removes images immediately and routes safely to the updated result without losing a meaningful report draft.
- Multiple windows/devices consume the same authoritative result/access/lifetime. A secondary window cannot inherit a reveal from another account or start another match/charge/camera owner. The gallery itself never requests or activates a camera, TCC, microphone, or Photos.
- Mac camera-denied, external/Continuity-disconnected, or camera-absent environments can still display otherwise authorized finalized evidence. Never replace it with a fake preview or rated file-picker input.
- Gallery close and Command-W have no fictitious forfeit. Preserve shared active-match close/quit safeguards elsewhere where platform permits. Force quit is not confirmable voluntary forfeiture.

### Accessibility, motion, and energy

- Preserve complete large-type text/badge reflow, explicit image target names, readable contrast, non-color state, semantic buttons, Switch Control, Voice Control, Full Keyboard Access, and independent reachable actions for both participants.
- Scope native picker arrows to picker focus; Return/Space activate only the focused semantic control, never global image/capture/submission behavior while typing. Escape closes the topmost menu/information/report layer with its existing draft rules, otherwise returns to the result. Preserve all existing application shortcuts.
- Follow the DOCKS focus entry, hide replacement, report open/return, expiry/deletion, and result return rules. VoiceOver uses safe participant/pose/status descriptions, not generated anatomical traits, hidden captions, signed links, or every timer tick.
- Reuse the shared press spring, response 0.24/damping 0.88. Actual pose-marker movement uses the same response; new authorized images/status use about 180 milliseconds; small status/placeholder changes use 140–180 milliseconds. Evidence never slides, scales, morphs, or crossfades into a differently labelled pose.
- Remove sensitive pixels immediately for Hide/Report/block/revocation/expiry/sign-out/privacy covers. Only already-safe placeholder text may animate. Retarget rapid input rather than queuing it. Navigation and sheets use native transitions without a second hero effect or artificial minimum wait.
- Reduce Motion removes travel/scale/repetition and uses immediate updates or at most 100-millisecond safe opacity. Reduce Transparency uses opaque readable chrome and shield. No gallery ambient loop, scan, flashing, score animation, badge wall pulse, or repeated celebration.
- Keep visible-precision timer work isolated from the image stage. No per-frame I/O, permissions, decoding, font measurement, or global layout invalidation. Do not eagerly decode hidden poses or retakes. Pause offscreen/inactive/background/minimized/occluded decorative work; expiry does not pause. Low Power/serious thermal state removes optional entrances and uses coarse minute precision, then Less than one minute, while enforcing the exact cutoff.

## Files to Create or Modify Prospectively

Inspect the current implementation tree first. Reuse existing reviewed gallery/evidence abstractions if they already own the behavior; do not add unused files or compatibility shims to satisfy these planning names.

- Create or complete `TimeMaster/Views/Physique/PhysiquePoseGalleryView.swift` — the native destination/sheet composition, selected pose, focus, privacy-safe rendering, and scoped shared integrations.
- Create `TimeMaster/Views/Physique/PhysiquePoseEvidencePanel.swift` only if the established shared evidence component does not already provide the external caption/actions and precise fixed-target states. Keep it feature-owned and focused.
- Modify only the actual existing result destination/presentation owner necessary to connect View poses and correct return behavior. Discover its exact path from the current F29 map; do not implement a second result screen.
- Modify only the actual reviewed `TimeMaster/Services/Physique/` access/presentation integration and `TimeMaster/Models/PhysiqueDuelModels.swift` where the established contract needs a gallery-consumer change. Do not redefine server finality, authorization, lifetime, moderation, rating, or account ownership inside the view.
- Update both actual app-target memberships only as required by their existing project convention.
- Update the matching F29-A-n implementation todos in `CYCLES.md` after working integration and exercised focused checks. Leave human-review acceptance pending.
- Update the smallest relevant product documentation only for explicitly approved product decisions, or after the human accepts resulting behavior. No verification evidence, checkboxes, source snippets, or implementation recipes in DOCKS.md. Do not create README/CHANGELOG files or unrelated design documents.

Do not alter global Theme/Profile/Ranked commands, exercise privacy, other workers' feature ownership, saved navigation, provider policy, launch badge definitions, shared allowance/rating rules, or the app-wide window minimum just to simplify this surface.

## Observable Acceptance — Native iPhone

- A deliberate View poses from the authenticated real judged result is the only path that reveals images. Pending, early, forfeit, no-contest, unauthorized, and unconfirmed results cannot reveal stills through any stale route.
- The real labelled expiry is the top visual anchor. Every authorized public badge for both owners appears above both large vertical players; no image carries chrome. Short screens and large accessibility sizes scroll rather than cap badges or shrink people.
- Front/Side/Rear change both fixed-owner panels together. Originals remain complete, aspect-fit, identically framed, face-obscured, and in judged orientation; image loading races never mislabel a pose or owner.
- Both Hide and Report are visible and reachable without enlargement for every image or safe placeholder. Hide is immediate; report cancellation leaves hiding; unsent/unknown receipt never says Reported. The real report/case/privacy routes work.
- Partial errors, withdrawn owner media, pair block, decode failures, deletion, offline access, expired images, and corrected-result invalidation have precise recoverable/nonrecoverable states with no stale-image flash.
- Real expiry, background/lock return, account switch, sign-out, and revocation enforce access rather than merely painting a label over a cached body. Foreground restoration does not auto-reopen sensitive imagery.
- No pose export, sharing, copy/link/print/drag handoff, enlargement, new camera access, model call, match, allowance charge, or local rating side effect occurs. Closing returns to the same result and sensible focus without a false forfeit.

## Observable Acceptance — Native macOS

- The surface is a native destination in the existing title-bar window, not Catalyst, a website, a detached image viewer, or a stretched iPhone modal.
- At 800-by-600, a laptop size, a large/full-screen size, and an external display where available, the timer and toolbar remain usable, every badge is reachable above evidence, and players remain large and vertical. Live resizing reflows/refits without cropping, body stretching, fetching per frame, forced scroll jumps, or focus loss. No app-wide minimum increase.
- Standard toolbar/keyboard/pointer behavior works. Tab order, native picker arrows, focused Return/Space, state-aware Escape, ordinary Command-W, shared quit handling, and all existing application commands remain intact. Typing in the report note cannot change poses or submit unexpectedly.
- Trackpad/wheel scroll and pointer actions reach each Hide/Report pair without hover or enlargement. Native full screen remains the same two-player composition. No new inspector or extra custom screen is required for expiry information.
- Minimize, deactivate, occlude, restore, multiple-window access, account switch, and expiry protect media and pause unnecessary work. Another window cannot reveal stale content or duplicate a match/camera owner/charge.
- Denied/unavailable camera permission and external/Continuity disconnect do not start capture, request new resources, create a fake preview, or stop reading an independently authorized final result. Physical camera ownership remains with the real shared match owner if one exists elsewhere.

## Focused Verification and Actual Native Smoke

After implementation is authorized and prerequisites are satisfied, run the smallest relevant existing builds/checks for both actual app targets. Fix clear scoped failures; compilation alone is not native proof. Do not rerun a user-reported failure merely to confirm it. Never report an unrun or simulated case as observed behavior.

Exercise the actual changed native surface on iPhone and native Mac where runtimes exist. Use authorized controlled accounts and lawful moderated test-service evidence, not someone else's production media or a production mock path. A labelled isolated preview can help a visual edge, but cannot stand in for authenticated service behavior. If particular hardware/service fixtures are unavailable, finish reachable checks and name the missing proof specifically.

Focused scenarios:

1. **Intentional entry and exclusions:** open an actual eligible result, navigate all three poses, close and reopen. Inspect pending/forfeit/no-contest and unauthorized stale routes through the actual navigation/access path. No early thumbnail, gallery, second judgement, Elo award, or allowance charge.
2. **Fidelity and races:** use authorized images with identifiable neutral pose framing/orientation and differing source aspects. Inspect full edges and masks on both platforms. Change Front to Rear rapidly with a genuinely delayed response; only the latest fixed participant/pose/version can paint.
3. **Protection and report recovery:** Hide one image, change poses, revisit, and explicitly View again under valid access. Open Report then cancel; keep it hidden. Exercise the real failed/unknown/confirmed/duplicate receipt path supported by the reviewed service, with honest labels and no thumbnail. Expire media while a meaningful text draft exists and finish/report safely without recovering deleted imagery.
4. **Access invalidation:** use authorized service controls to withdraw one owner's access, block the pair, remove media, revoke session/switch accounts, and correct a judged result to no-contest. Observe immediate safe replacement and no reappearance from a late image completion or another window. Probe old-link/cache access through the real access boundary without logging secrets or copying private images into artifacts.
5. **Expiry and network:** exercise a controlled service result near its actual original expiry, including an in-flight fetch across cutoff and a restricted case hold. Check that images become unavailable, the timer becomes Expired, and refresh/reopen/reconsent does not extend it. Exercise offline and return: shield, honest retry, deliberate re-open, same authoritative record. Do not change the machine's global clock or production records to manufacture the case.
6. **iPhone accessibility/layout:** inspect a short display and largest supported accessibility text, all wrapped launch badges, long handles/regions/localization, complete images, all forty-four-point safe actions, the reflowed selector, report keyboard clearance, VoiceOver target/order/focus, Voice Control/Switch Control reachability where available, and Reduce Motion/Transparency. Do not clamp size to make a screenshot look compact.
7. **Mac interaction/layout:** launch the actual native target; exercise 800-by-600, laptop, large/full-screen and external-display sizing where available, live resize, scroll, picker arrows, Tab/Shift-Tab, Return/Space while typing, Escape layer priority, Command-W, preserved commands, minimize/deactivate/restore, and secondary-window account/access behavior. Inspect focus and native toolbar behavior, not just a compiled desktop target.
8. **Camera/resource boundary:** with Mac TCC denied or no camera and, where physical hardware exists, an external/Continuity camera disconnected, verify that this finalized gallery does not request/restart capture or invent evidence. No camera hardware proof is required to pretend a gallery run captured a live match; name physical-camera coverage separately and do not claim it from a fixture.
9. **Energy/privacy:** observe idle timer updates, rapid selection, hidden/offscreen panels, inactive/minimized/background behavior, and reduced/low-power settings through available native tooling. No decorative timer/loop/image decoding or whole-stage invalidation should continue offscreen. Inspect that a privacy cover precedes sensitive snapshots and logs/replay contain no images, notes, or authorization URLs.

Prefer existing consumer-behavior regressions for genuine uncertain boundaries such as late completion after revocation, cross-account leakage, and expiry precedence if the project has a suitable deterministic convention. Do not add permanent tests for source text, exact copy, forwarding, default values, mock echoes, or incidental layout constants. Throwaway focused harnesses are appropriate when native/contract behavior can be exercised more directly; remove them after use. Do not keep debug entry points, fake galleries, service bypasses, or fixture-data switches in production.

## Human Verification Handoff — Required

List each implemented item separately: intentional entry/return; iPhone composition; native Mac composition; pose/fidelity behavior; all identity/badges; per-image Hide/Report integration; authorization/expiry/revocation/lifecycle handling; accessibility/focus; and motion/energy behavior. List every changed file with its responsibility.

State only the builds/checks/native scenarios actually exercised, their observed result, and exact remaining hardware/service/runtime limitations. Distinguish native Mac interaction from a Mac build, protected-service behavior from a preview, and physical-camera proof from a gallery fixture. Do not create a screenshot/recording/log evidence package or place such evidence in DOCKS.md.

Ask the user to review the code changes and the resulting behavior on both platforms. Each implemented item is ready for human verification only when actually connected and exercised; do not mark it human-verified or accepted. Keep unresolved external prerequisites and product decisions explicit. Human acceptance precedes dependent connection and post-acceptance product-document changes.

## Mandatory Agent Rules

1. **Single owner, no nested agents.** Do the work yourself. No sub-agent review swarm, generation call, or unrelated asset creation. Keep this child and its minimal reviewed integration as the scope.
2. **User direction wins.** Preserve native iPhone and native Mac, timer/all badges/vertical players, privacy, and current service authority. Do not silently fall back to side-by-side, enlarged viewing, hidden badges, early media, a static mock, or a simpler invented product.
3. **Research and reuse.** Read the actual native skills, current source, reviewed contracts, and relevant live guidance. Use established theme, state, routing, sheet, safety, badge, and service patterns; no second global abstraction because a snippet suggests it.
4. **Real connected behavior only.** No placeholder button, fake opponent/score/rating/receipt, permissive media cache, generated replacement body, no-op report, fallback vendor, own-provider key, or production mock. Missing prerequisites stay honestly missing, not visually disguised.
5. **Preserve boundaries.** Exercise media remains local under its existing promise. Camera, adulthood/attire declarations, country/badges, model inputs, public identity, rating authority, consent, reporting, and deletion retain their documented owners. No secrets in client code, docs, logs, commits, or support artifacts.
6. **Focused actual checks.** Run the changed native surface and focused real service scenarios on both platforms where available; fix clear failures and report unexercised limits. Tests or compilation alone do not prove the UI. Do not perform speculative unrelated cleanup or exhaustive proof packaging.
7. **CYCLES only for implementation work.** Mark only corresponding implemented todos after connected checks and a clear human-review handoff. Leave human acceptance pending; no IDE-specific todo JSON. DOCKS contains product context only, never implementation checklists or evidence.
8. **Scoped commit and push.** For the future authorized implementation session, publish each completed functional slice with a clear scoped commit and push to `origin/main`, following the coordinating owner's integration plan. Preserve all unrelated/user changes; no force-push, history rewrite, or blanket staging. Exact commit/push failure is a publication blocker, not a completion claim. The earlier documentation-only worker did not run Git; main owned that integrated batch.
9. **No premature dependency work.** Shared foundations must be implemented and human-reviewed first. Do not build dependent result/safety/profile screens here or call a disconnected gallery independently shippable.
10. **Complete the whole child.** Entry, both native surfaces, media/safety/privacy paths, actual checks, cleanup of throwaways, CYCLES implementation status, human handoff, and publication belong to this implementation slice. No testing-only or commit-only follow-up prompt.
11. **No pointless next prompt.** Finish small reachable work now. Create another prompt only for an explicitly approved substantial new independent implementation slice, never because checks, a clear fix, documentation, commit, or push remain. Do not expand this task into a new feature.

## When You Finish

Report every implemented meaningful item and changed file separately, exercised native/service checks, any real external prerequisite still missing, and the publication result. Ask for human review on both platforms and state that acceptance is pending. Say whether another prompt was actually needed; the expected outcome for this complete child is no next prompt.

## Scope Decision Before Finish

State concrete facts under Completed, Remaining, and Decision. Completed means connected and actually checked, not a scaffold. Remaining names actual gaps rather than implying an unobserved result. Decision is no next prompt, a user-approved substantial next slice, or an exact external prerequisite; do not claim feature completion or human acceptance to hide an unfinished surface.
