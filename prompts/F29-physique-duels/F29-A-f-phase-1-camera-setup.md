# Phase 1 of F29-A-f — Native Camera Setup and Preflight

## Execution Assignment

Use model **openai-codex/gpt-6.1-sol** with **thinking=max**. The complete worker assignment is **openai-codex/gpt-6.1-sol:max**; max denotes the thinking level, not a different model. Do not silently substitute another model or a lower thinking level. If the launcher cannot honor this assignment, report that exact dispatch prerequisite before implementation. This assignment selects the UI engineering worker, not the in-app ranked judge, provider, rubric, or reasoning policy.

This is a future implementation brief. The documentation-only design batch does not authorize writing app code now. Execute it only as an implementation assignment after the real shared prerequisites below are implemented, connected, and human-reviewed. Do the work as one owner; do not spawn nested agents.

## Features Included

- F29-A-f — Native iPhone and native macOS camera preparation, actual permission and device availability, large local aspect-fit preview, local diagnostic and exact face-privacy review, framing/light/single-person cues, source selection, and camera-specific recovery.
- The minimum integration of that component with the already reviewed Physique entry, single camera/session owner, search action, battle shell, explicit privacy stop, and authoritative active-match recovery.

Do not rebuild consent, the pose guide, matchmaking, timed pose capture, the badge catalog, results, moderation, account access, or global navigation. Consume their real contracts. Camera setup is not independently shippable before those required foundations are real. List the meaningful implemented pieces separately in the final human-review handoff; do not treat them as human-approved.

## Context

Physique Duels needs a real local camera preflight before its image-based competition, distinct from exercise Ranked's joint-only capture promise.
The approved direction uses native iPhone and Mac, minimal visible copy, tactile state-driven motion, and no body-obscuring HUD chrome.
This slice connects the specified camera component; it does not create a mock competitive flow or select the judging model.

## What You Need to Read First

Read the complete component product document and the relevant complete contracts before editing. Use ranges for source exploration; inspect declarations and the actual affected sections rather than opening unrelated files.

- `AGENTS.md` from the loaded project context and the current F29 implementation/review section of `CYCLES.md`.
- `features/F29-physique-duels/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md`.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-f-camera-setup/DOCKS.md`.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md`: accepted inputs, required common regions, privacy masking, capture adequacy, and evidence integrity.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md`: eligibility, one active match per account, readiness, authoritative Go, original deadlines, reconnect, cancellation races, and finality.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md`: private declarations, actual permitted attire, second-person rejection, exact local face obscuring, ambiguity, and safe rejection language.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md`: permissions versus consent, processor disclosures, camera lifetime, exact redaction, withdrawal, metadata minimization, and protected transfers.
- The actual integrated F29 shared-foundation, battle-shell, public-identity/badge, entry/consent, pose-guide, and timed-capture documents linked from those parents. Discover their registered paths; do not guess a competing ownership structure or manufacture an absent dependency.
- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing dark surfaces, orange actions, and shared controls.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter fonts, existing spacing, readable text columns, and touch-target convention.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — public availability-gated material behavior, Reduce Transparency, and shared press spring.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — sports controls and earned-rating language only; do not copy Dynamic Type clamps, false local levels, or compressed important labels.
- `TimeMaster/Views/Ranked/RankedMatchPreparationView.swift:1-78` and `TimeMaster/Services/Ranked/RankedCamera.swift:1-115` — nearby camera-status and interaction patterns, not a Physique backend or permission to change exercise privacy.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — existing exercise HUD context, not live physique scores or a layout to copy blindly.
- `TimeMaster/App/TmaxApp.swift:8-19` and `TimeMaster/App/TmaxCommands.swift:6-37` — native title-bar WindowGroup, existing 800-by-600 minimum, and reserved Mac commands.
- The actual iPhone and native Mac target sections of `TimeMaster.xcodeproj/project.pbxproj` and the camera capability/usage-description configuration they reference. Preserve iPhone iOS 16 compatibility and native macOS 14; inspect the actual target rather than raising versions to satisfy a sample API.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable cosmetic badge previews are not trusted identity, placement, competitive achievements, or verification.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the image. Borrow clear timer/participant hierarchy only; do not import its people, footage, web pills, overlays, or side-by-side arrangement.
- The actual reviewed Physique camera/session, redaction, local-frame, clean-evidence, source-ownership, and match-coordinator source files. Locate their names before choosing modifications; do not open guessed files or add a parallel capture framework.
- Installed `swiftui-pro`, specifically accessibility, data, performance, and view-lifetime guidance; installed `swiftui-animation`; installed `apple-hig-reference`, with current relevant Apple pages. The parent design owner selected `dimillian/swiftui-ui-patterns` through the UI Skills CLI. Reuse that selected context if supplied; do not repeat an installation/routing exercise. If its text is unavailable, name the limitation and use the installed native skills and actual source rather than claiming to have read it.
- Apple HIG: `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos`, `https://developer.apple.com/design/human-interface-guidelines/privacy`, and `https://developer.apple.com/design/human-interface-guidelines/motion`. Read current applicable sections before attributing a recommendation to Apple; HIG is not an API-availability declaration.

There is no project `STYLES.md` in the originating design context. Use the existing source conventions; do not create a global style document or another theme. If the repository has subsequently gained relevant accepted product context, read it and preserve user changes.

DOCKS.md defines product intent in plain language, not a technical recipe. Independently validate the implementation against current public APIs, the actual deployment floors, installed native guidance, and the reviewed architecture. Never put code, payloads, implementation recipes, task checkboxes, or verification evidence into a DOCKS.md.

## What Happened Last Session

The originating slice was a coordinated documentation-only batch. It specified the camera composition, full local states, privacy boundaries, native input, interruption behavior, and motion, and produced this future implementation brief. It did not create Swift files, a camera pipeline, backend handlers, generated artwork, fake preview footage, a running prototype, measured detector thresholds, or a completion claim.

The supplied screenshot and named native source anchors informed the direction. Their existence does not prove physical-camera behavior, two-platform runtime correctness, fairness of the physique rubric, production provider availability, or App Store approval. The main owner integrates shared documents and publishes the documentation batch. Re-read CYCLES.md and the accepted dependencies at execution time; do not infer review approval from a completed documentation checkbox.

## Prerequisites and Review Boundaries

Before writing this component's production code, establish all of the following through the real repository and review record:

- The existing authenticated account, native navigation, and Physique service foundations are implemented, connected, and handed off under the project's human-review policy. Pending shared Ranked or navigation review is not silently accepted.
- The canonical Physique match state exposes actual eligibility, consent version, queue state, readiness, authoritative Go and deadlines, one-active-match ownership, cancellation/forfeit/no-contest distinctions, and recovery. The UI must not invent a transport contract, local finality, or a second queue.
- There is one reviewed native camera/session owner across the applicable windows and device-restoration paths, with fresh-source identity, cancellation, permission/lifecycle events, real source enumeration, and stop semantics. Reusing a low-level camera primitive must not begin uploading exercise frames or change exercise Ranked/Practice's local-image promise.
- The real local privacy pipeline can produce the exact obscured representation without a raw fallback, preserve required body evidence, distinguish uncertainty, and invalidate stale callbacks. Its consumer contract must cover every transmitted candidate and selected still, not merely the diagnostic shown by this setup.
- Real local adequacy signals exist for framing, ordinary usable light, single-person/unclear-view handling, and privacy readiness. No invented thresholds, hardcoded successful rows, demographic analysis, identity embeddings, or random calibration progress.
- The current required adult/attire declaration, hosted-AI and counterpart-sharing consent, real service-health check, independent allowance, and protected-media contract are available through their owners. Camera TCC is not a substitute for any of them.
- The reviewed parent battle shell and F29-F trusted identity/badge presentation can retain all public rails above two large vertical players whenever recovery is embedded in a real match.

If these prerequisites are missing, identify the exact unreachable or unreviewed dependency. Do not ship production mock state, placeholder callbacks, fake live imagery, a local-only pretend ladder, permissive redaction, a second camera pipeline, or a camera-unavailable screen masquerading as a complete implementation. Finish only legitimately reachable work within the user's authorized slice; do not claim the connected feature is complete. Once prerequisites exist, do the full connected slice rather than handing off avoidable integration work.

## Concrete Design Decisions and Tradeoffs

1. **One self-view before pairing.** A large aspect-fit camera image dominates preparation. Device, cues, status, and controls stay outside the evidence pixels. There is no fake opponent or pre-match countdown. This preserves body framing instead of forcing a decorative duel frame onto setup.
2. **A local diagnostic, in the same view.** Live preparation leads to Check setup, an exact masked sample held locally with acquisition stopped, then Find opponent. Adjust setup resumes local preparation. This adds one explicit review action but makes the privacy treatment understandable. The diagnostic is never uploaded, saved to Photos, scored, charged, or counted as a rated attempt.
3. **Freshness is rechecked on search.** Find opponent explicitly rearms the selected camera and validates fresh local state before the real parent search command. A held sample cannot prove a still-connected camera, an unchanged room, current consent, or service eligibility.
4. **Upright and unmirrored throughout.** Live and exact reviewed evidence use one stable unmirrored orientation. Explain that choice in Camera details. This gives up selfie-mirror familiarity to prevent an unexplained left-right change; do not add a mirror toggle or a body-flip transition.
5. **Named gates, not scores.** Framing, Light, Privacy, and Alone have real discrete states, symbols, a concise current correction, and accessible details. There is no adequacy percentage, body metric, scan line, face recognition, gender inference, or local moderation verdict.
6. **Fail-closed privacy.** Use the actual opaque local face treatment in the reviewed image. No reveal-original control, separate decorative overlay over an unmasked upload, weakened mask, raw fallback, or masked-bystander approval. A failed/uncertain process blocks that image; it is not anonymous or verified identity.
7. **Native source control with no silent fallback.** iPhone offers real supported camera choices. Mac uses a native device pop-up for actual built-in, external, and OS-provided Continuity sources. A disconnect shields immediately and requires explicit Retry or replacement selection; hot-plug never steals selection.
8. **Native Mac, not a stretched phone.** Preserve the title bar, existing minimum, toolbar, native-density actions, resizable central stage, optional supplementary inspector, keyboard, pointer, full screen, external displays, and window ownership. Do not use the Mac's width to place participants side by side.
9. **Tactility without a camera shader.** Reuse the press spring; a brief matte-perimeter latch marks real local readiness, and status/control lanes have short state-driven transitions. Live preview consumes the continuous-motion budget, so there is no ambient loop or pulsing badge wall.
10. **New direction overrides stale layout text.** Both native platforms and vertical players at every width are required even if an older parent paragraph says iPhone first or permits a balanced two-column Mac comparison. Surface that conflict; do not silently resurrect it or broaden the slice into a desktop redesign.

## What to Build

### 1. Connect Entry, Acquisition, and Explicit Stop

Use the real reviewed entry and session owner. Start no camera from lobby browsing, rules, account fields, or consent reading. Start camera opens the genuine system camera request only when authorization is undetermined; already authorized access starts only the explicitly requested local session. Keep legal sharing choices distinct. Do not add a permission pre-alert, copied system alert, incentive, or microphone request.

Represent actual idle, requesting, starting, fresh running, denied, restricted, absent, interrupted, stale, busy/unavailable, and failed camera states. Provide the specific useful recovery rather than a generic error. On iPhone use the supported app-settings route for denial. On Mac use the real System Settings camera-privacy route when available, with a readable manual path if opening it fails. A managed restriction is not fixable through repeated permission requests. Configuration/capability defects must be diagnosed and fixed rather than blamed on a denied grant.

Stop camera, Close, navigation, inactivity, minimization, hiding, lock, backgrounding, loss of ownership, and account changes must cancel the relevant pending intent, stop acquisition, and shield sensitive content immediately. A late permission result, frame, mask result, or device callback cannot reacquire or reveal anything after stop. Distinguish automatically stopping acquisition to hold a deliberately requested diagnostic from cancelling the entire diagnostic work; an explicit privacy stop or closure still cancels both.

### 2. Build the Local Framing Lane and Exact Diagnostic

Implement the iPhone and Mac compositions in the product document with measured geometry, actual frame aspect, no body cropping or nonuniform scaling, and no labels over evidence. Reflect real local cues without doing camera work in the view's rendering or animation closures. Present all blockers accessibly, prioritize the current practical instruction, and settle repeated guidance without delaying a privacy defect.

Check setup takes one transient diagnostic using the canonical full-evidence and redaction path, stops acquisition, and displays only the exact safe masked representation when available. Show Checking locally honestly until it is ready; no minimum fake delay. Discard unnecessary originals and failed samples. The held sample says Local check · not sent and has Adjust setup and Find opponent. Failed privacy or additional-person checks never expose an unsafe still or produce a successful check.

No diagnostic goes to the server, opponent, model, Photos, workout history, or analytics. It consumes no pose slot, retake, allowance, or match. On Find opponent, obtain fresh authorized local evidence, recheck real upstream eligibility, and invoke the existing parent search once. A failure remains the actual local or upstream state, not a synthetic search success. On successful admission, preserve the same reviewed camera owner; do not recreate it because the view changed.

Every later candidate/still must independently preserve the exact pre-transfer redacted representation required by the capture and privacy contracts. Do not treat a reviewed diagnostic as consent to transmit later unmasked originals. If the canonical path cannot honor the exact-review boundary, resolve that prerequisite with its owner rather than faking a mask at the UI layer.

### 3. Connect Real Camera Selection and Disconnection

Use current native device enumeration and selection. Keep meaningful source names visible and accessible. Support real iPhone front/back choices and other sources only where genuinely supported. On Mac include supported external and Continuity devices supplied by the OS. Do not emulate OS pairing, promise hardware support that does not exist, or add a photo/library fallback.

Source changes immediately stop the old source, cover sensitive content, invalidate the diagnostic and old readiness, and accept only new-source frames/results. Cancel the stale pending search intention. Hot-plug updates choices but does not change selection. Selected-source loss shows Camera disconnected, not a cached live frame or silent fallback. An apparently connected source that stops producing fresh frames must lose readiness too. Explicit reconnection or replacement requires fresh local validity and privacy.

Preserve the reviewed evidence-integrity contract for virtual or appearance-altering sources without inventing perfect detection. Do not add beauty processing, body reshaping, scoring-oriented lighting effects, or demographic classification.

### 4. Integrate In-Match Recovery Without Owning Finality

Within an existing pairing, use the parent shell: real timer first, complete grouped public identity/badge rails next, then large You and Opponent panels stacked vertically at all widths. Setup occupies the own panel/control lane. The opponent remains the permitted avatar/silhouette and actual stage/count, never live video or early images. Consume all public badges; no slot cap, hidden +N, clipping, ticker, or hover-only details. Allow stage scrolling instead of shrinking players.

Before Go, camera invalidity removes local Ready eligibility and informs the real coordinator. Resolve a cancellation/Go race through authoritative state; a pre-Go Cancel must not silently become a deliberate forfeiture.

After Go, interruption recovery resumes the same match within the real grace and original deadline. Do not reset the ninety-second capture window, twenty-second reconnect grace, attempts, pose acceptance, quota, opponent, or request identity. Resuming the same source does not itself discard prior accepted poses. A confirmed change to another source during an editable set requires the real whole-own-set invalidation contract and the explicit Restart my poses consequence; no source change after a locked submission or during judging. If both final sets are already received, keep the camera off and restore the actual judging/result state.

Stop camera protects immediately without automatically declaring Forfeit. Explain that an active timer continues, offer explicit permitted resume, and route leaving through the state-aware shared confirmation. Service-established invalidity or safety no-contest precedence remains intact. Offline means status unknown where applicable, not a locally awarded outcome, restored slot, or invented result.

### 5. Complete Native Input, Lifecycle, and Motion

Implement semantic labels, clear focus rings, readable device names, Dynamic Type wrapping, VoiceOver, Voice Control, Switch Control, safe tap targets on iPhone, and native Mac control density. The video is one concise accessible element; local cues expose actual discrete meanings without per-frame announcements. Announce meaningful local review completion, privacy failure, or disconnect once. Do not read every timer tick.

Mac must support the existing minimum, laptop/large/full-screen windows, external display moves, live resize, ordinary scrolling, pointer input, keyboard focus, native toolbar/pickers, and the supplementary inspector/disclosure. No second camera owner in a new window and no second account-wide active match. An actual owning window can be brought forward; do not display a dead Open active match button when no real route exists. Cross-device restoration must follow the reviewed service contract rather than local takeover.

Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O. Return and Space operate the focused semantic control only, never a global shutter/search/resume action while typing. Escape first dismisses native transient controls, then follows the component's specified local cancellation or parent state-aware exit. Command-W and ordinary quit/window-close paths surface actual post-Go consequences where the platform allows; destructive forfeit is not the default action. Force quit cannot be prevented or reclassified as an explicit voluntary forfeit.

Apply the component's exact motion contract: shared press response 0.24/damping 0.88; roughly 200-millisecond exterior framing latch; 160-millisecond cue replacement; 280-millisecond status/control continuity; 180-millisecond safe-frame reveal; privacy cover immediate, with at most a later 140-millisecond harmless status fade. If embedded, the shared real timer uses its stable approximately 180-millisecond digit change. No body flip, image geometry tween, scan, flashing, reward pulse, or ambient loop. Latest real state interrupts earlier success and all actions obey real state immediately.

Reduce Motion uses static state or at-most-100-millisecond opacity, no scale/travel. Reduce Transparency uses readable opaque controls. Low power or thermal pressure removes optional motion; it never weakens privacy, turns stale frames into ready evidence, changes accepted still content, or extends service deadlines. Inactive/offscreen/minimized/background work stops immediately. Do not perform per-frame network work, image decoding, font measurement, device discovery, camera rebuilds, or global layout updates as an animation side effect.

## Prospective Files and Scope

Use the actual reviewed architecture and names discovered in the repository. These are expected ownership locations, not permission to create unused scaffolds or aliases:

- Create the feature view at `TimeMaster/Views/Physique/PhysiqueCameraSetupView.swift` if it does not already exist under the reviewed foundation; otherwise modify its canonical existing owner. Use small feature-local subviews only where actual complexity warrants them, not a separate framework for every native picker or alert.
- Reuse the reviewed Physique preview and local camera/privacy owner under `TimeMaster/Views/Physique/` and `TimeMaster/Services/Physique/`. Make only the necessary scoped integration changes for the documented diagnostic, selection, freshness, and cancellation behavior. Do not create a second exercise-derived camera implementation because a proposed filename differs.
- Modify the actual reviewed Physique entry/match-coordinator integration only to route this surface, the real search event, explicit stop, source replacement consequence, and recovery state. Parent routes and canonical service authority remain single owners.
- Adjust the actual target membership, camera usage description, or native Mac capture capability only if required for the connected change. Keep the deployment floors and use public availability-gated APIs. Do not alter the app-wide minimum, reserved commands, or global theme to avoid local layout work.
- Update only the approved matching implementation todos in `CYCLES.md` after the work is connected, focused checks pass, and it is clearly handed to the human. Do not mark the entire F29-A journey complete for this component.
- Product decisions remain in `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-f-camera-setup/DOCKS.md`; update accepted decisions at the required review boundary, not to portray unimplemented or unverified behavior as complete. No new README, changelog, global design document, or unrelated prompt is needed.

Do not change public-identity/badge rules, saved navigation, Profile's two-side shape, exercise/privacy semantics, Elo, allowances, moderation policy, provider settings, or unrelated files. No generated artwork or media is required. Use native symbols, honest neutral unavailable covers, and already authorized assets; not the screenshot's photographed people.

## Observable Acceptance — iPhone

- Opening ordinary Physique content does not start the camera. Start camera requests only the real camera resource in context; denial, restriction, unchanged settings, absence, and actual runtime failure have distinct useful states and exits.
- The own preview is large, actual, upright, unmirrored, and aspect-fit in portrait, landscape, short screens, and large text. All required evidence can remain visible without image overlays or nonuniform stretching. Safe actions remain reachable with the existing app navigation clearance.
- Framing, Light, Privacy, and Alone reflect actual local state. Uncertainty and a stopped/stale source do not enable local check or search. No demographic/body-quality inference, body score, fake percentage, or unsafe posing instruction appears.
- The diagnostic uses actual canonical masking, is held locally with acquisition stopped, says not sent, and leaves no rated slot/attempt/charge/Photos side effect. Find opponent rearms and revalidates before a single real search; Adjust setup and Close have their stated local effects.
- A second person stays invalid even masked. Redaction failure or uncertainty cannot transmit an original. Country, badges, names, timer, cues, and app chrome never enter the clean evidence.
- Stop, interruption, lock, app switch, and background immediately protect the surface and stop acquisition; returning requires the real state and explicit resume. There is no old body frame labeled live, automatic source fallback, photo-library substitute, microphone prompt, or accidental second match.

## Observable Acceptance — Native macOS

- The surface is in the existing native title-bar window and remains usable at 800 by 600 without raising the app minimum. Native-density actions, a real source pop-up, toolbar, keyboard focus, ordinary scrolling, and supplementary details feel like Mac controls, not mobile chrome enlarged.
- Laptop, large, short, full-screen, and external-display layouts preserve source aspect and safe actions. Live resize and display moves do not rebuild acquisition or reset state. Whenever the battle shell is present, the timer and all public rails remain above two large vertically ordered players, including on wide displays.
- Actual TCC undetermined/granted/denied/restricted states are distinct from no camera, an unsupported source, a busy device, stale frames, and disconnect. System Settings failure has useful manual recovery, not an invented permission grant.
- Built-in, available external, and actual OS Continuity sources can be explicitly selected. Removing the selected source immediately shields and clears readiness without falling back. Hot-plug does not steal selection; a late old-source result cannot change the new view or queue state.
- Deactivating the app or owner window, minimization, hiding, sleep/lock, fast user switching where available, and closing stop and shield immediately. A second window cannot start another session, take ownership opportunistically, or reserve another slot. Returning restores the actual service state without deadline reset.
- Keyboard-only navigation reaches every relevant action and device choice. Return/Space are focused actions, Escape is state-aware, reserved commands retain their meanings, and ordinary close/quit confirmation reflects real consequences. Force quit is not promised preventable or treated as deliberate confirmed forfeiture.

## Focused Actual Native Exercise and Checks

These are future execution scenarios, not checks performed by the documentation batch. Run the actual changed surface on both native platforms wherever runtime is available. A build or a test suite alone does not prove this UI works. Use consenting adults and safe ordinary sports attire for physical-camera checks; never obtain unconsenting bystander images or unsafe poses as test material. Do not log, persist, or publish raw body images as a proof package.

1. **Native entry and local review:** launch the actual iPhone app and native Mac app through the real route. Observe camera off, explicit start, fresh preview, a useful correction, a successful local diagnostic, acquisition stopped during review, Adjust setup, and the actual single search handoff on an authorized service. Observe that the diagnostic does not upload or charge. If real match/service prerequisites are absent, report that boundary rather than substituting a mock queue.
2. **Authorization and recovery:** exercise actual supported undetermined/denied/granted flows in an appropriate isolated app/device context, plus useful settings return. Exercise restricted/no-device states where the runtime can actually provide them. Do not reset unrelated system privacy grants or pretend a simulated flag proves native TCC.
3. **Privacy and ambiguity:** exercise the actual redaction path and a failure/uncertain path. Confirm the reviewed representation and the clean encoded/transfer boundary are the same safe treatment, not a UI-only overlay. Use a consenting helper only for a local extra-person check; ensure that view cannot proceed as valid merely because faces are masked. Inspect behavior without persisting originals or revealing forbidden regions.
4. **Device continuity:** on Mac, use a physical external camera and Continuity if available; select, disconnect, reconnect, and explicitly retry or replace. Observe immediate cover, actual source labels, no silent built-in fallback, and no stale old-source success. On iPhone, switch the actual supported sources and rotate through available orientations. A simulator proves neither physical-camera compatibility nor Continuity behavior.
5. **Lifecycle and ownership:** stop during startup and during a local check, navigate away, open a guide/settings route, background/lock iPhone, deactivate/minimize/hide Mac, and restore. Exercise a second native window and the shared existing-match route. Observe no reacquisition from delayed callbacks, no camera indicator left active on stopped surfaces, no second queue, and an explicit resume.
6. **Active-match integration:** with the real reviewed test service and consenting participants, exercise a pre-Go camera failure, cancellation/Go race, same-source recovery, and a source replacement while editing when supported. Observe unchanged original deadlines/attempt policy and the real whole-own-set invalidation before new evidence. Restore a match already judging and confirm the camera stays off. Never label a local timeout as confirmed no-contest.
7. **Layout and accessibility:** exercise iPhone short/landscape and largest available accessibility sizes, and native Mac 800-by-600, short, large/full-screen, live resize, and display moves. Exercise VoiceOver focus/announcements, keyboard-only controls, source selection, Voice Control/Switch Control where available, visible focus, long device names, Reduce Motion, Reduce Transparency, Increased Contrast, and Differentiate Without Color. In any battle recovery verify every public badge is represented above both large vertical panels and safe actions are not buried by scrolling.
8. **Motion and energy:** observe real trigger-based latch and transition interruption, no success replay after failure, and immediate privacy protection. Enable low power where available and exercise relevant thermal-policy behavior safely through supported diagnostics. Observe inactive/offscreen acquisition and local-analysis stop. Use native profiling only where it answers a concrete issue; do not claim a numerical battery/frame-rate improvement without measurements.
9. **Focused engineering checks:** run the project's smallest relevant target build/type checks and existing focused camera/privacy/match contract tests after integration. For any uncertain privacy race, keep a deterministic regression only if it catches a plausible consumer-visible bug, such as stale callbacks revealing a frame after stop, a raw fallback reaching transfer, or an old source approving a replacement set. Do not add source-text, wiring, mock-echo, incidental-default, or tautological tests. Use throwaway smoke instrumentation only as needed and remove it before publication.

Report only scenarios actually exercised and their observed result. Name missing physical iPhone, external-camera, Continuity, native accessibility, second-device, or staging-service proof exactly. Do not claim complete physical-camera validation from a simulator, screenshots, compilation, a preview fixture, or tests alone. An unavailable device is a real verification limit, not permission to silently remove that platform or its behavior.

## Human Verification Handoff — Required

List separately the implemented camera composition, permission/device states, exact local review, source/disconnect handling, recovery integration, accessibility/input behavior, and reduced-motion/energy behavior. List every changed file separately with what it owns. Ask the user to review the code changes and state that each implemented item is ready for human verification, not human-verified.

State observed native scenarios and focused checks concisely, without a screenshot/recording/log archive or completion evidence package. State any missing runtime/hardware/service prerequisite and known behavior limitation plainly. Do not call an unconnected component complete. Accepted product changes go into the smallest relevant DOCKS.md at the required review boundary, with plain-language behavior only. Task state remains only in CYCLES.md.

## Mandatory Agent Rules

1. **Single owner, no nested agents.** Do this implementation yourself. Do not spawn agents to review or implement the repository. Honor the exact model/thinking assignment and report dispatch limitations rather than silently falling back.
2. **Research before editing.** Read the actual relevant source and accepted contracts, use installed native skills/current Apple documentation, respect deployment availability, and reuse the canonical architecture. Documentation is not proof of a real foundation.
3. **User direction wins.** Both native platforms, complete badges above large vertical participants, real authority, and privacy are mandatory. Surface stale parent wording and follow the newer user decision. Do not invent extra scope or a different product to avoid a difficult camera/privacy path.
4. **No fake production path.** No generated people, production mock preview, demo opponents, hardcoded detector success, no-op action, fake identity/badge, raw privacy fallback, local rating, photo-library rated input, or silent platform omission. Clearly labeled Preview/test fixtures never substitute for runtime behavior.
5. **Respect ownership and user changes.** Change only the camera component and necessary reviewed integration/configuration described here. Do not rewrite shared theme, unrelated work, Profile shape, global commands, existing exercise capture, or provider settings. Do not add needless framework wrappers or abstractions.
6. **Complete the connected slice.** Implement actual states/actions/recovery, native semantics, source freshness, exact privacy representation, and service integration. Resolve clear local build/runtime failures encountered in the affected path; do not stop at a compiling scaffold or hand off avoidable obvious fixes.
7. **Exercise the native surface.** Run focused relevant checks and the actual changed path on both native platforms where available. Fix clear reproducible failures. Do not rerun a user-reported failure simply to confirm it, invent unobserved output, or equate builds/tests with human approval.
8. **Maintain the real task system.** Update only the matching approved implementation todos in CYCLES.md after connection/checks and a clear handoff. Do not create IDE task JSON, duplicate task dashboards, or completion checklists/evidence inside product docs. Do not mark dependent features reviewed.
9. **Commit and publish scoped edits.** During the future implementation session, inspect each completed work slice, commit with a clear message, and push the scoped changes to origin/main under the repository's rules. Never force-push or include secrets/unrelated user edits. Report the exact publication blocker if it fails; no local-only completion claim. The originating documentation worker did not perform those implementation actions.
10. **Keep product documentation honest.** Preserve accepted behavior, describe any material deviation, and update the smallest relevant product context only at the required approval boundary. No code, pseudocode, payload, implementation recipe, verification evidence, or completion claim in DOCKS.md.
11. **No pointless next prompt.** Finish reachable work now. Create a later prompt only for a substantial separately authorized implementation slice, never just to run tests, fix obvious bugs, update docs, commit, or push. Do not create another UI direction or independent sibling screen as a follow-up.
12. **Clean handoff.** Remove throwaway instrumentation and scaffolds after smoke proof, list every meaningful implemented item and changed file for human review, state actual limits, and never claim App Store approval, anonymity, demographic verification, measured detector quality, or human acceptance.

## Scope Decision Before Finish

State what is connected and exercised, what genuinely remains, whether any real external prerequisite prevented acceptance, and whether a substantive next prompt was needed. Do not mark the component complete because a placeholder renders or the project compiles. Human review remains pending until the user explicitly accepts the behavior.
