# Phase 2 of Ranked — Complete Real Tracking and the Production Ranked System

## Read This First: The Actual Assignment

Finish Ranked as a working product, not another UI demonstration. The user explicitly corrected the previous scope: real movement tracking was expected, and the next agent must complete the entire Ranked page and its connected competitive flow. Removing test notices is part of the final cutover, not a substitute for implementing the missing behavior.

The user requested this substantial continuation prompt. They do not want another handoff that only adds preview screens, simulated counters, example opponents, or explanations of what a future implementation might do.

The font/letter-generation messages in the preceding conversation were sent to the wrong task. The user explicitly withdrew them. Do not touch `junk/ribbon-font/`, its generation pipeline, or any ribbon-font references.

### Features Included — Complete Each Separately

1. Real camera capture, full-body framing, calibration, and automatic exercise tracking.
2. Exercise-specific repetition validation and continuous-hold scoring, including the advanced movement choices.
3. Real account/session identity, online matchmaking, readiness, synchronized countdown, and live opponent state.
4. Server-authoritative matches, result verification, exercise-specific Elo, and rolling match allowances.
5. Real exercise leaderboards, earned-rank presentation, persistent match history, and match details.
6. Finished native Ranked UI: compact duel HUD, useful visual guidance, complete recovery states, and consistent artwork.
7. A clean production cutover that removes simulated behavior and all test-UI notices from normal user routes.

Do not silently narrow this to item 6. Do not call the whole feature complete while the tracking or competitive systems are missing.

## Context

TimeMaster is a native SwiftUI app for iOS and macOS. Ranked already has a character-led lobby, local movement selection, an illustrated multi-screen flow, and reusable native styling. The current flow compiles and its main navigation path has been exercised, but its scoring and competitive data are still simulated.

This task modifies that existing feature. Preserve the useful screens, artwork, native navigation, and unrelated app behavior; replace the demo internals with real implementations. Do not restart the app, introduce a web wrapper, or treat a documentation reorganization as a prerequisite.

## User Decisions and Product Intent

- Ranked is a real 1v1 exercise competition, not a fake offline opponent or scripted workout animation.
- The main round is 60 seconds, with a shared countdown and clear start/end boundaries.
- Opponents perform the same exact exercise under the same rules. Knee, standard, wall-handstand, freestanding-handstand, and other variants are not interchangeable.
- Match people near the relevant exercise-specific skill/rating. Consistently strong results should lead to stronger opposition rather than repeatedly farming weaker players.
- Push-up variations share an allowance of ten started competitive matches in a rolling four-hour window. Squat variations have a separate ten-match rolling four-hour allowance. This is not ten per variation and not a midnight reset.
- Cancelling before Go must not use a match slot or change Elo. Starting a round consumes a slot. Leaving after Go is not a free cancellation.
- Every exercise needs its own leaderboard and earned competitive rating. Do not combine unrelated exercise scores into one ladder.
- Include the existing Core movements, with left and right side planks remaining independent.
- Include the advanced movement choices and take their tracking difficulty seriously. The user raised concerns about assistance such as bands and supports; research actual detection limits instead of claiming that a skeleton overlay proves an attempt is unassisted.
- Keep Practice as a real solo camera-tracked activity. It must not consume competitive allowance, invent an opponent, or award competitive Elo.
- UI direction: visual-first, concise, native grouping and hierarchy inspired by Telegram, using TimeMaster's existing dark/orange styling. Avoid long explanatory walls and generic gamer-dashboard decoration.
- Keep the existing smooth bald ivory-marble athlete, fluted lower-face mask, black clothing, and restrained orange accents. Do not regenerate it as a bear or add hair.
- Keep the existing shared button shapes. Do not use this task to redesign Home, Profile, Settings, or the global navigation.

## What You Need to Read First

### Tracking and Current Ranked Implementation

- `CYCLES.md` — Cycle 36, including the production-completion handoff section.
- `TimeMaster/Models/RankedModels.swift` — modes, families, all eighteen variations, current scoring descriptions, tiers, and legacy editable levels.
- `TimeMaster/Models/RankedFlowModels.swift` — current ephemeral preview session, demo outcomes, frame values, and local quota implementation. These are not a production backend.
- `TimeMaster/Views/Ranked/RankedView.swift` — lobby, saved selection, loadout, sheets, and flow entry.
- `TimeMaster/Views/Ranked/RankedMatchFlowView.swift` — current phase transitions, countdown, simulated clock-driven scores, verification page, and example results.
- `TimeMaster/Views/Ranked/RankedMatchPreparationView.swift` — illustrated camera setup, example search, ready room, and problem states.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift` — current display/control surface. Its frame is supplied externally; it does not track a camera.
- `TimeMaster/Views/Ranked/RankedMatchResultView.swift` — current example rating/result and allowance sheet.
- `TimeMaster/Views/Ranked/RankedRulesView.swift`.
- `TimeMaster/Views/Ranked/RankedLeaderboardView.swift`.
- `TimeMaster/Views/Ranked/RankedMatchHistoryView.swift`.
- `TimeMaster/Views/Ranked/RankedTierGalleryView.swift`.
- `TimeMaster/Views/Ranked/RankedComponents.swift`.

### Profile, Persistence, Navigation, and Shared UI

- `TimeMaster/Views/Ranked/RankedProfileSection.swift`.
- `TimeMaster/Views/Ranked/RankedLevelsEditorView.swift`.
- `TimeMaster/ViewModels/LocalProfileStore.swift` — local JSON persistence and editable levels.
- `TimeMaster/Models/LocalProfileModels.swift` — legacy level storage and backup merging.
- `TimeMaster/Views/Settings/ImportedSettings/ProfileSettingsView.swift` — another entry into the local Elo editor.
- `TimeMaster/Views/MainTabView.swift` — Ranked entry and Profile-to-Ranked routing.
- `TimeMaster/Views/Navigation/SlotNavigationItem.swift` — typed Ranked navigation icon and layout behavior.
- `TimeMaster/Utilities/ProfileDesign.swift` — `ProfileStyle` and `TimeMasterFont`.
- `TimeMaster/Utilities/Theme.swift` — existing surfaces, colors, and shared button styles.
- `TimeMasterTests/RankedProfileTests.swift` and `TimeMasterTests/LocalProfileTests.swift` — existing data-preservation and navigation behavior.

### Build and Integration Boundaries

- `project.yml` and `TimeMaster.xcodeproj/project.pbxproj` — both app targets and source membership.
- `TimeMaster/Info.plist`, `TimeMaster/Info-macOS.plist`, and the platform entitlements.
- `TimeMaster/Utilities/KeychainHelper.swift` before considering reuse for authentication.
- `server.py` only to understand its existing purpose. It is an unrelated LAN video-download companion, not a Ranked server.

Follow the repository's current agent rules. Read relevant available product documentation, but do not invent a Ranked DOCKS path or restore unrelated deleted docs to satisfy a template. Current direct user decisions above supersede the older UI-only scope. Product DOCKS files are plain-language context, not implementation recipes or proof of completion; accepted product decisions are documented after user acceptance.

Before UI work, use `skill://ui-skills-root` and its CLI to select the smallest relevant context. Read `skill://swiftui-pro` and the applicable `skill://ui-ux-mastery` guidance. Read `skill://gpt-image-gen-latest` before using Fgen for missing artwork. Use independent current documentation for camera, pose estimation, authentication, backend security, and deployment; the existing UI code is not an implementation authority for those systems.

## What Happened Last Session — Useful Work, Not Production Completion

The implementation now contains:

- Lobby shortcuts for rules, exact-movement leaderboards, recent rounds, and allowance.
- Connected camera-setup illustration → search example → opponent ready room → 3–2–1–Go → timed duel → provisional verification → example result.
- Separate Practice entry that skips the opponent search/ready room.
- Match details and an in-memory recent-round list.
- Per-movement leaderboard selection, an explicit example-standings layout, and a rank collection that opens the corresponding ladder.
- Camera-denied, framing, lighting, offline, no-opponent, opponent-left, and allowance problem-state layouts.
- Four added push-up variations: diamond, wall handstand, freestanding handstand, and planche. The model currently treats these as repetition-scored push-up variants, not newly defined static-hold events.
- A pure duel HUD with timer, two scores, avatars, lead bar, and feedback presentation.
- A monotonic local round clock, stable round identity/date, and local preview-slot accounting at Go.
- Removal of the obsolete `RankedReadyRoomView.swift`; its callers now use `RankedMatchFlowView`.
- Source registration for the new files in both native app targets.

### Precisely What Is Still Fake or Missing

- There is no live camera capture or pose-estimation implementation in Ranked.
- The displayed movement image is an illustration, not a camera feed.
- `RankedMatchFlowView.runClock()` increases example scores from elapsed time. This must be replaced, not renamed.
- Feedback can be selected manually through demonstration controls.
- Alex is an invented example opponent, not a matched authenticated participant.
- Ready status and example result choices are driven by local buttons.
- Result Elo values are hardcoded examples.
- `RankedPreviewSession` stores matches and start times in memory. Relaunching loses them. It is not a secure allowance or match-history system.
- Leaderboard rows are illustrative, not a service query.
- `LocalProfileStore.rankedLevels` is user-editable local display data. It is not earned Elo and must never seed trusted competitive ratings.
- The advanced variations use SF Symbols instead of matching movement artwork.
- Searches of app services, models, and view models did not find an account-authentication service, live matchmaking, a Ranked backend, or a Vision body-tracking pipeline. Re-inspect the current tree for intervening work; do not assume those integrations exist.

The user wants all of this completed. Do not preserve the demo architecture as the normal production path.

## Observed Engineering Evidence and Limits

Both the iOS Simulator and macOS app targets built after resolving a collision between the app's `Section` model and `SwiftUI.Section`. Keep explicit `SwiftUI.Section` qualification where needed.

The builds used a disposable copy of the then-current app source. The live working tree already had unrelated deleted app bootstrap files; only the temporary build copy recovered `TimeMaster/App/TimeMasterApp.swift` and `TimeMaster/App/MacCommands.swift` from HEAD. Those live deletions were not restored. Do not describe this as a clean-HEAD production verification or blindly reuse a stale temporary build directory.

A native iPhone 16 / iOS 18.6 smoke, under a separate app bundle ID and empty isolated data container, exercised:

- The actual Ranked lobby.
- Camera-setup illustration, example search, opponent ready room, countdown, and running duel HUD.
- A timer advancing from 0:59 to 0:38.
- Explicit demo completion, provisional verification, example result, match-details presentation, and its Close action.
- A recent-round row showing the resulting example score/outcome.
- Allowance changing from 10/10 to 9/10 after one Go.
- Cancelling a subsequent attempt before Go leaving it at 9/10.

The isolated app was removed. The smoke used only isolated data; no saved-checkpoint action was taken in the production app.

No real tracking, online opponent, competitive rating, server verification, hardware camera behavior, or cheating detection was proved. The existing five Ranked regression cases were not rerun in this continuation; earlier cycle notes refer to earlier runs. macOS received a build check, not an interactive check of the new flow.

A concrete UI problem was observed: at the normal 393-point iPhone width, the HUD falls back to a tall timer-over-scores card; feedback and the finish control lie below the initial viewport. Fix the layout rather than accepting this as the intended minimalist HUD.

## 1. Establish the Real Architecture and External Prerequisites

Inspect the current source, authorized environment, available service configuration, project history, and any relevant reference implementations before choosing a stack. Reuse an existing suitable backend if one has been added. Do not repurpose the unauthenticated LAN video downloader into an Internet-facing account/competition service.

If no backend exists, implement a small, conventional architecture with authenticated sessions, a transactional database, server-side match/result/rating authority, and realtime match updates. Use a maintained solution that can actually run and be deployed; do not add a maze of providers, adapters, or speculative abstractions.

The implementation needs real persisted identities, queue entries, matches, participants, readiness, rule versions, score/event evidence, verification results, per-exercise ratings, allowance start records, and history. Keep public leaderboard identity separate from private account and camera data.

Use an existing authorized deployment target when available. Do not invent endpoint URLs, credentials, account IDs, or successful deployment claims. Do not provision a paid service or make an irreversible privacy/hosting decision without authorization. If a real external choice or login is genuinely missing, identify exactly what is needed and continue all reachable implementation instead of replacing the service with fake data.

Implement authentication and secure session lifecycle. Preserve the user's local profile identity and content when linking it to a real account; do not replace their avatar, posts, collectibles, workouts, preferences, or backups with seed data. Sign-out/account changes must detach listeners and private caches correctly.

`KeychainHelper.swift` currently mirrors values into UserDefaults. Do not store production account/refresh tokens in that plaintext fallback. Use a genuinely secure credential path and handle Keychain failures honestly. Never commit service secrets or private keys; client configuration must not contain privileged service credentials.

## 2. Implement Actual Camera Capture and Setup

Build a real native camera capture service and preview, not another illustration with a viewfinder border.

Required behavior:

- Request camera permission when the user enters camera setup, not on unrelated app launch.
- Handle not-determined, authorized, denied, restricted, unavailable camera, interruption, and capture-start failure distinctly.
- Provide working Settings/retry/back actions for the relevant condition. Do not label permission as granted until the system says so.
- Select a usable camera and keep capture, preview orientation, mirrored front-camera presentation, and pose coordinates consistent.
- Show the actual feed with a clear full-body framing overlay and concise movement-specific setup guidance.
- Detect no person, multiple people, cropped required joints, poor confidence, unsuitable angle, and sustained unusable lighting instead of pretending the athlete is ready.
- Calibrate the selected movement and establish a stable usable pose before offering readiness. Recalibrate when the camera or viewpoint changes.
- Do not turn the camera on in the background or request microphone permission without an actual requirement.
- Start/configure/stop capture under one serialized owner off the main UI thread. Cancel processing and release camera resources when leaving the feature.
- Bound frame processing, discard stale frames, and avoid retaining an ever-growing buffer queue. Keep rendering and gesture interaction responsive.
- Update the real purpose strings and any required macOS camera capability/configuration in both the checked-in Xcode project and its source configuration.

Current deployment targets are iOS 16 and macOS 14. Apple's older `VNDetectHumanBodyPoseRequest` is available on these systems; the newer Swift `DetectHumanBodyPoseRequest` starts at iOS 18/macOS 15. Do not accidentally raise the minimum OS or use the new API without a real supported fallback.

## 3. Build a Real, Testable Movement-Tracking Engine

Use camera frames and detected joint observations to drive a deterministic exercise state machine. Do not count from elapsed time, random values, a tap button, or an animation cycle.

Separate capture/pose extraction from movement rules and from UI presentation. Keep the design small: reusable pose observations and explicit per-movement rules, not one giant SwiftUI body or a new generic workflow framework.

Required tracking invariants:

- Use actual frame timestamps and confidence-qualified observations.
- Correct for image aspect ratio, camera orientation, and front-camera mirroring before angle/distance reasoning and overlay placement.
- Normalize thresholds to the athlete's geometry where appropriate; do not hardcode screen coordinates or assume one body size.
- Use stable entry/exit thresholds, hysteresis, and minimum phase durations so jitter does not create extra repetitions.
- Count a repetition only after its required complete phase sequence. Starting halfway down, holding still, bouncing around a threshold, or repeating only the bottom half must not score.
- Missing/occluded joints, no body, a second person, invalid alignment, and camera movement must not silently continue awarding points.
- Keep a clear distinction between a rejected repetition, temporary tracking loss, and a verified completed repetition.
- Do not let camera preview rendering, UI refresh rate, or a changed device clock determine score.
- Define partial-repetition behavior at Go and at the deadline. Only activity inside the valid scoring interval may count.
- Keep the currently detected pose, exercise phase, accepted total, and concise invalidity reason connected to the HUD.

Exercise coverage is not one generic elbow-angle counter for every menu option:

- Standard push-ups: full down/up cycle, body alignment, appropriate arm/torso landmarks.
- Wide and close grips: meaningful hand/shoulder-relative placement checks where the chosen camera view supports them.
- Knee push-ups: distinguish the permitted knee-supported posture from a standard attempt.
- Paused variants: require the actual bottom pause, not a label applied to ordinary repetitions.
- Tempo push-ups: measure the required controlled phase timing.
- Squats: full standing/down/standing cycle, usable depth and alignment observations, and the selected stance. Paused squats require their pause.
- Diamond: distinguish the intended close hand configuration using suitable body/hand observations; body-pose wrists alone are not proof of finger contact.
- Wall handstand: inverted posture, range of motion, and wall support permitted only for this variation.
- Freestanding handstand: inverted posture and no visible wall/support dependency under the chosen validation method.
- Planche: horizontal body and feet off the floor through the required movement, not an ordinary push-up misclassified because of perspective.

Research and exercise inverted-body detection; do not assume an upright-person pose pipeline handles handstands reliably without adaptation and evidence.

For Core, the existing rule is **longest valid continuous hold within the 60-second round**. Do not sum separated hold fragments or substitute a repetition total. Track forearm plank, high plank, left side plank, and right side plank independently. A broken hold must end the current segment while preserving the previous best segment; insufficient confidence cannot manufacture hold time. Any grace/debounce rule must be explicit, short, consistent, and exercised.

Use real representative movement recordings and hardware observations to evaluate thresholds. Deterministic pose sequences are useful regression tests, but they are not proof that a real camera model recognizes every exercise accurately across people, clothing, lighting, occlusion, and angles.

## 4. Integrity, Assistance, Safety, and Privacy

Do not claim that ordinary monocular body-pose points can prove that hidden bands, off-camera supports, replayed video, or all forms of cheating are absent.

Implement the checks the selected capture/verification method can actually support. Distinguish verified, invalid, insufficient evidence, suspected visible assistance, and pending review without accusing a user from a single uncertain frame.

Research the user's advanced-assistance concern. Explain the concrete limits of the chosen approach and implement an honest handling path when a match cannot be validated. Do not silently turn unsupported advanced attempts into ranked wins; do not quietly remove these exercises from scope either. A real model/data/service prerequisite must be named and pursued, not replaced with an optimistic badge.

Client-produced skeletons and counters are not automatically trustworthy because they were sent over TLS. Establish a proportionate competitive-integrity design: authorized participants, server-issued match context, versioned rules, ordered/timestamped evidence, anti-replay handling, plausible movement bounds, and server-side validation. Consider platform attestation where appropriate, while recognizing its limits. Do not expose a public endpoint that directly writes any submitted final score or Elo.

Prefer on-device image processing and minimal derived match data. Do not silently upload or retain camera video. If a higher-assurance verification design genuinely needs imagery/video or third-party processing, make consent, retention, deletion, access control, transport/storage protection, and the privacy tradeoff explicit before enabling it. Never expose an opponent's camera feed merely because realtime score synchronization exists; video sharing is a separate consent/product decision.

Give brief practical advanced-movement cautions and an easy exit before Go. Do not make medical, injury-prevention, or cheat-proof guarantees.

## 5. Implement Real Matchmaking

The queue must be backed by authenticated server state.

- Match the same exact exercise and compatible scoring/rule version.
- Use earned exercise-specific rating/MMR, not manually editable profile levels or an unrelated overall rating.
- Start with nearby skill and widen conservatively if needed, without endlessly pairing a beginner with an expert.
- Support the user's stronger-opposition intent after strong results without treating every win as a reason to throw a novice into an extreme mismatch.
- Keep an account in at most one active queue/match. Handle repeated taps and duplicate requests idempotently.
- Use an atomic queue claim so a player cannot be assigned to multiple opponents.
- Make queue cancellation real. Resolve cancellation racing with opponent assignment through server state, not contradictory local screens.
- Expire abandoned queue entries and readiness sessions without charging a round that never started.
- Show honest searching, cancelled, timed-out/no-opponent, network-error, and matched states.
- When nobody is online, say so and allow real Practice. Never secretly inject Alex, a bot, or another demo opponent into a rated match.

Keep examples and seeded development users out of real public standings and the normal production experience.

## 6. Ready Room, Countdown, and Shared Match Lifecycle

Use an explicit authoritative lifecycle: preparing, queued, matched, waiting for readiness, countdown, live, submitted/verifying, and a final completed/forfeited/invalid/cancelled outcome as appropriate.

Readiness must come from both actual participants and usable camera/tracking state. Handle an opponent leaving, failing calibration, declining, losing connection, or timing out. Do not show a green ready check based on a local illustrative boolean.

The service owns the match ID, participants, exercise, rules version, shared start/end timestamps, readiness deadline, and terminal outcome. Display the 3–2–1–Go sequence against the shared timeline and drive local time from a monotonic clock with a server-time reference. Changing device time, backgrounding, or receiving a delayed packet must not extend a round.

Only Go starts scoring and consumes allowance. Cancellation before Go releases any reservation. Competing start/cancel requests must have one consistent result.

There is no normal Pause button in a competitive round. A disconnect or background transition must not freeze one player's private clock while the opponent continues. Define and implement reconnection grace, capture interruption, app termination/relaunch recovery, and forfeit/invalid-result behavior consistently on the server and both clients.

On reconnect or uncertain network response, fetch the actual match state by its stable ID. Do not create another match, double-spend allowance, reset the timer, or award another rating update.

## 7. Live Scores and Opponent Updates

Replace elapsed-time score generation with accepted tracking events. Synchronize actual opponent progress through the match service.

- Tag events with the correct match, participant, exercise/rule version, sequence, and scoring time.
- Reject wrong-user, wrong-match, duplicate, stale, impossible, or out-of-window submissions.
- Reconcile out-of-order realtime updates without score jumps backwards or duplicate repetitions.
- Clearly distinguish a provisional live total from the final verified result.
- Preserve the scoring unit: repetitions for rep movements, valid-hold duration for Core.
- Show real connectivity/tracking status. Do not leave an old score looking live after updates have stopped.

The UI must never calculate and persist final Elo on its own.

## 8. Verification and Real Match Results

At the deadline, stop accepting scoreable movement and submit the completed evidence/state through the real protocol. The verification screen must represent an actual service operation, not an artificial delay or a button selecting Win/Loss/Draw.

Implement pending verification, verified result, invalid/unverified attempt, service failure, reconnect, and real recovery. A pending result must survive navigation and relaunch. Do not guess the winner when the server is unavailable.

Result finalization must be idempotent and transactional. Finalizing twice or retrying after a lost response must not create two history entries, two allowance charges, or two Elo changes. Both participants must see the same final outcome and compatible score/rating data.

Show real final scores, result reason, rating before/after/delta, tier/progress, and match details. Forfeits, ties, invalid rounds, and verification failures require explicit rules, not accidental fallthrough to a win. A tracking-confidence failure is not automatically proof of cheating.

## 9. Earned Elo and Legacy Local-Level Cutover

Implement a conventional, server-owned, exercise-specific rating system with explicit initial placement, expected-score calculation, update factors, bounds, ties, forfeits, provisional players, and invalid-result handling. Make the policy versioned and test meaningful boundaries.

Preserve the user's intent that stronger results eventually lead to stronger opponents. Do not mix arbitrary repetition counts directly into Elo or reward a client for submitting a huge number.

Current `RankedLevels` values are manually chosen cosmetics/display data. Never import them as trusted earned ratings. Preserve existing local profile files and unrelated content through a migration, but remove the ability for a user to edit a competitive rating through Ranked, Profile, Settings, backups, or an API call.

Migrate every affected caller, including:

- Lobby identity, selected-movement badge, and movement tiles.
- `RankedProfileSummary` and `RankedProfileSection`.
- `RankedTierGalleryView` and `RankedLeaderboardView`.
- Ready room and result presentation.
- `RankedLevelsEditorView` and the Imported Settings entry.
- Local profile serialization/merging and any backup behavior that could overwrite authoritative competitive state.

Inspect actual symbol references before changing exported APIs. Preserve old user data safely; do not retain obsolete editable-rating aliases or dead production paths merely for convenience. Historical local backups must not roll back a real server-owned rating.

Retain the existing tier artwork and thresholds unless a product change is genuinely needed. Give any overall summary a defined truthful meaning; do not invent an unexplained average of unrelated movement ladders.

## 10. Server-Enforced Rolling Allowances

Enforce the ten-in-four-hours policy on the server, per account and family, across devices and all variations in that family.

Required cases:

- Ten push-up matches do not consume the separate squat allowance.
- Standard/wide/close/diamond/etc. push-ups do not each get a separate ten-match bucket.
- The exact four-hour boundary restores the appropriate slot.
- Cancellation, failed pairing, or abandoned readiness before Go does not charge a match.
- A started match remains charged after a forfeit.
- Concurrent devices or duplicate start requests cannot exceed the limit or spend the same match twice.
- Relaunch, sign-out/in, reinstall, timezone changes, and client-clock changes cannot reset the server ledger.
- The UI shows the real remaining allowance and next eligible time, with a working return/recovery path.

The current preview class applies a generic bucket to Core too. That is demo code, not an approved additional competitive fatigue policy. Do not turn it into production policy without resolving its meaning against the user's decisions; keep the requested push-up/squat separation exact.

## 11. Real Exercise Leaderboards and Rank Collection

Query persisted, verified competitive ratings for the selected exact exercise. Remove the example-standing toggle and fictional rows from the user path.

Implement loading, populated, no competitors, unplaced current user, current user outside the loaded page, offline/stale cache, permission/authentication error, and recoverable service error. Use stable ordering/tie handling and real pagination. Jump to my position must locate the real user, not row five in a sample array.

Opponent rows open the actual permitted public identity. Respect profile privacy and do not expose private posts, account identifiers, camera evidence, or other non-public data through the leaderboard.

Your ranks must show earned exercise-specific rating, tier, placement/provisional state where relevant, and navigation into that exact leaderboard. Never display a manually edited legacy value as an earned placement.

## 12. Persistent Recent Matches and Details

Replace the in-memory preview list with persisted authoritative match history. It must remain correct after restart, reconnection, pagination, and viewing the same result from more than one entry point.

Show actual opponent identity where permitted, exact exercise, time, result status, scores/units, final rating delta, and any appropriate verification/forfeit explanation. Pending matches must update to their real terminal state without duplicate rows.

Keep Ranked match history separate from existing workout history unless the user explicitly approves a cross-feature recording rule. Do not overwrite or fabricate workout sessions.

## 13. Complete the Native Ranked UI

Reuse the existing screen structure and shared native components. Finish it as a real product rather than adding more preview menus.

### Duel HUD — Priority Layout Correction

Two reference directions were supplied in chat:

1. A compact dark panel with centered 0:33, opposing 16/14 scores at the ends of a shared orange/neutral lead bar, a small +2 lead indication, and compact avatars/names.
2. Avatars/scores at both ends, centered TIME / 60s, and a shared bar underneath.

Combine their compact hierarchy with TimeMaster's palette and typography. Do not reproduce blue/red gamer colors or let repeated explanatory copy force the scoreboard into a huge vertical card at normal phone width.

The main view should prioritize the shared timer, two readable scores, lead, real camera/framing feedback, and a deliberate leave action. Keep the critical status visible at ordinary phone sizes. Accessibility sizes may use a properly designed scrolling/stacked layout; do not shrink all content to unreadable sizes to force a fit.

Remove the production Finish demo action and manually selected feedback controls. Normal completion comes from the real deadline; leaving uses the actual forfeit policy. Keep advanced diagnostics in development tooling, not in a user-facing Preview states menu.

### Other Screens

- Lobby: actual account/rating/allowance state, saved movement, useful shortcuts, and one clear Battle/Practice action.
- Loadout: complete movement coverage, selected-state clarity, rules/requirements, and real availability rather than a disconnected card.
- Rules: visual movement/position guidance and concise valid/invalid examples. Do not show fake video-play controls for a non-existent tutorial.
- Camera setup: actual feed, calibration, framing and lighting feedback, ready affordance, real permission/error recovery.
- Search: actual queue state and cancellation, concise skill/exercise context, no fabricated elapsed matchmaking progress or fake opponent.
- Ready room: actual opponent, actual readiness/camera state, shared rules and countdown.
- Verification: actual pending state and real failure recovery.
- Result: actual outcome, scores, rating delta, tier progress, replay/history/leaderboard navigation as appropriate; no invented results.
- Allowance: real server values and next slot, not an always-full ten-segment sample sheet.
- Leaderboards/history/ranks: real empty/loading/populated/error states with correct navigation and dismiss/back behavior.

Use `Theme`, `TimeMasterFont`, `ProfileStyle`, existing toolbar/selection/card button styles, and `AppToolbar`. Preserve minimum touch areas, readable contrast, VoiceOver meaning, Dynamic Type, Reduce Motion, safe areas, global navigation clearance, and working macOS keyboard/focus/dismissal behavior. Do not announce every camera frame or flood accessibility with timer updates.

## 14. Finish Missing Movement Artwork

The original fourteen movement illustrations and tier assets already exist in `TimeMaster/Resources/Assets.xcassets/`. The four advanced additions currently fall back to SF Symbols.

Create matching, anatomically coherent artwork for diamond, wall-handstand, freestanding-handstand, and planche push-ups using the existing bald masked athlete as the direct visual reference. Read the Fgen skill and use one movement per generation. Preserve the same material, clothing, face mask, lighting, and restrained orange accents. Register real assets and remove the temporary advanced-art fallback when the images are connected.

An illustration explains a movement; it does not prove the real tracker validates it. Finish both tasks separately.

## 15. Remove Test UI Only Through a Real Cutover

Once real services and tracking drive the normal flow, remove production occurrences and behaviors such as:

- UI PREVIEW, preview-only, example scores/opponent/standings, local preview slots, and no-live-matchmaking notices.
- Preview opponent found, Preview countdown, Preview result, Finish demo, and the problem/result selection menus.
- Hardcoded Alex and hardcoded Elo/result score changes.
- Elapsed-time repetition generation and manually selected tracking feedback.
- In-memory-only competitive history/allowance as the source of truth.
- The leaderboard sample-data toggle.
- Editable local values presented as competitive ratings.

Do not do a blind text deletion and leave the same fake behavior behind. Migrate every caller to the real domain state and remove obsolete preview models and unused code. Keep development fixtures isolated from normal routes, if they remain useful at all.

Real Practice/no-rating explanations, permission messages, insufficient-evidence results, unavailable-camera states, and genuine empty/error states are product behavior, not test notices. Do not suppress them to make the page look complete.

## 16. Files to Modify and Likely New Areas

Modify the existing Ranked model/view files listed above, the Profile/Settings competitive-rating callers, native privacy/capability configuration, project source membership, relevant existing tests, and `CYCLES.md`.

Create cohesive real services/stores for capture, pose processing, movement scoring, authenticated account/session state, online match state, verified rating/leaderboard/history data, and the server implementation/migrations. Choose exact names and locations after inspecting current conventions. A likely native area is `TimeMaster/Services/Ranked/`; this is a proposed new area, not a claim that those services already exist.

Keep backend implementation and deployable configuration in a clearly owned project area. Do not hide competitive authority in SwiftUI views, local defaults, `server.py`'s downloader handler, or a committed secret. Keep source/configuration and the checked-in Xcode project consistent for both targets.

Do not edit the font experiment, unrelated Profile redesigns, Maps, workout builders, or the global navigation styling. Preserve the existing user-controlled removal/order of the Ranked navigation item and keep Profile-to-Ranked entry working.

## 17. Implementation Order — Connected Work, Not Artificial Handoffs

Use this dependency order while keeping the complete product as the goal:

1. Inspect the real integration situation; establish auth/backend ownership, domain state, privacy boundaries, and versioned exercise rules.
2. Implement real capture/calibration and tracking with a real Practice path as the first hardware-exercisable consumer.
3. Implement authenticated queue/ready/countdown/live match state and server-owned allowance.
4. Connect tracking events and actual opponent updates; implement verification, finalization, ratings, history, and leaderboards.
5. Migrate Profile/Settings/rank callers; complete visual guidance/artwork and compact HUD layouts.
6. Remove demo paths and notices through the real cutover; exercise recovery, restart, invalid-input, and multi-user boundaries.
7. Deploy/run the real implementation, fix reproducible failures, update tracking, commit/push, and hand all implemented items to the human.

Do not stop after a camera-shaped view, after creating service protocols, after compiling a server, or after making one local mock match. Do not generate another prompt solely for running tests, fixing obvious errors, updating documentation, committing, or pushing.

## 18. Focused Verification That Must Actually Happen

Use relevant existing checks and a real smoke. Do not create source-text, wiring-only, hardcoded-default, or mock-echo tests.

### Tracking

- Real supported camera input and actual repetitions; zero movement must stay at zero.
- One complete repetition counts once; partial repetitions and threshold jitter do not count.
- Selected variation, range, stance, pause/tempo, occlusion, out-of-frame, orientation/mirroring, and interrupted capture.
- Valid continuous hold, break/restart, longest-segment scoring, and independent left/right behavior.
- Advanced exercise evidence and known model limits, including inverted poses and visible assistance.
- Deadline boundaries and no scoring before Go/after the end.

Use deterministic movement-state regressions for plausible count/hold bugs. Use actual recordings/hardware to assess the vision pipeline. Simulator/video fixtures must be clearly described as such and must not be exposed as production camera fallback.

### Competition and Persistence

- Two authenticated participants match on the same variation, both ready, see the same start/end, and receive compatible live/final state.
- Cancel/assignment races; duplicate queue/start/score/finalization requests.
- Full 60-second round and actual server finalization, not a debug finish button.
- Win, loss, draw, forfeit, invalid/insufficient-evidence, delayed verification, disconnect, background, relaunch, and recovery.
- Exactly-once Elo/history effects and authorization against a different user's data or match.
- Separate family allowance, cross-variation sharing, simultaneous-device enforcement, and exact four-hour expiry.
- Real leaderboard ordering/pagination/current-user jump and real history after cold restart.
- Account changes and legacy local-profile/backup migration without loss of unrelated data or local edits becoming earned Elo.

### Native UI and Builds

- Actual iPhone-size surface at ordinary and accessibility text sizes, including the fixed compact HUD and reachable essential controls.
- Rules, loadout, camera, search, ready room, round, result, history, details, leaderboard, ranks, allowance, and error/recovery routes.
- Both app targets compile; exercise the changed native surface. macOS camera/focus/lifecycle behavior must not be claimed from an iOS Simulator screenshot.
- Preserve production documents/checkpoints. Use isolated accounts/app containers for destructive or state-consuming checks.

Run the existing relevant Ranked/Profile regressions when the corresponding contracts change; update genuinely broken behavior tests to the new authoritative-rating contract without re-pinning incidental wording. Add only meaningful deterministic tests for uncertain boundaries and actual consumer-visible failures.

A simulator cannot demonstrate a physical camera. If hardware, an authorized deployment, account provisioning, or consent is truly unavailable, finish everything reachable, name exactly what is missing and what was attempted, and do not label the whole system complete. Do not substitute mocks and remove warning text to conceal the missing requirement.

## 19. Source-Tree and Publication Safety

The working tree has had substantial concurrent edits, deleted app entry points, and deleted feature documents unrelated to Ranked. Treat them as the user's work. Inspect the current situation before edits; never restore/delete/stage everything as cleanup.

The previous build recovered missing bootstrap files only inside a disposable build copy. If those live deletions remain, use repository/history evidence to resolve the build boundary without overwriting the user's working tree. Do not blindly rerun a known missing-file build failure or quietly commit unrelated recovery changes.

Commit and push every completed scoped work slice to `origin/main` as required by the project. Never force-push. Use scoped staging or an isolated index when necessary to avoid publishing concurrent unrelated edits. Do not commit secrets, local device data, throwaway fixtures, or generated completion-evidence packages.

## 20. Agent Rules — Mandatory

1. **USER DIRECTION WINS.** The latest requirement is real tracking and the complete working Ranked feature. Older UI-only wording no longer limits this task. The withdrawn font messages are not part of it.
2. **NO SUB-AGENT REPOSITORY REVIEWS.** Do the repository work yourself in the next session; do not outsource the plan or replace implementation with review reports.
3. **INDEPENDENT IMPLEMENTATION.** Use relevant skills and current primary documentation. Validate the inherited code and numerical/model assumptions instead of blindly following them.
4. **COMPLETE CONNECTED BEHAVIOR.** No fake data, stub protocols, empty services, no-op buttons, placeholder endpoints, simulated tracking, or demo-to-production relabeling.
5. **CLEAN CUTOVER.** Migrate callers and remove obsolete demo paths, manual competitive-rating paths, and dead code. Preserve real user data through deliberate migration.
6. **UPDATE CYCLES.md.** Track implementation and remaining work there only. Mark an item implemented only after it is connected and relevant checks pass; this does not mean human acceptance.
7. **NO DUPLICATE IDE TODOS.** Do not create separate task JSON/checklists in source or put implementation todos in DOCKS files.
8. **FOCUSED CHECKS AND REAL SMOKE.** Fix clear failures in the current slice. Tests alone do not prove camera, native interaction, or real multi-user behavior.
9. **COMMIT AND PUSH.** Publish scoped changes to `origin/main`; preserve unrelated working-tree edits and never expose secrets.
10. **HUMAN VERIFICATION IS REQUIRED.** List each implemented item and changed file, ask for review, and do not claim the human approved anything.
11. **HONEST EXTERNAL BLOCKERS.** Investigate information available from tools, configuration, code, references, and history first. Ask only for genuinely unavailable authorization, hardware, credentials, or materially different irreversible product/security choices. Keep implementing reachable work.
12. **NO ARTIFICIAL NEXT HANDOFF.** Complete small remaining fixes/checks/publication now. Create a further prompt only for a genuinely substantial remaining implementation slice or an explicit user request; never hand off only testing, documentation, a commit, or a push.

## 21. Primary Research Starting Points

These are starting points, not proof that the current tracker works:

- [Apple: VNDetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest) — older API compatible with the current minimum OS versions.
- [Apple: Detecting Human Body Poses in Images](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images) — supported body observations and pose-processing context.
- [Apple: DetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/detecthumanbodyposerequest) — newer API; observe its higher OS availability.
- [Apple: AVCaptureVideoDataOutput.alwaysDiscardsLateVideoFrames](https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput/alwaysdiscardslatevideoframes) — frame backpressure and buffering behavior.

Also research the selected auth/database/realtime/deployment system from its current official documentation. Do not choose a camera or backend architecture from a marketing summary or assume the existing local downloader supplies it.

## Human Verification Handoff — Required

Report separately:

- Camera capture, calibration, and permission handling.
- Repetition tracking, each variation's rules, and hold scoring.
- Advanced tracking/assistance handling and explicit real limits.
- Account/session integration.
- Matchmaking, ready/countdown/live synchronization, and recovery.
- Verification, outcomes, Elo, and rolling allowances.
- Leaderboards, earned ranks, and persistent history/details.
- Native visual/HUD/artwork completion.
- Removal of simulated behavior, test notices, and editable competitive ratings.
- Migration/data preservation, deployment, each changed file, and checks actually exercised.

State any external prerequisite and any unproved hardware/model behavior plainly. Ask the user to review the code and actual feature. Screenshots, recordings, or an evidence package are not required. Product DOCKS updates follow user acceptance; implementation status belongs in `CYCLES.md`.

## Scope Decision Before Finish

- Completed: connected real behavior, integration, focused checks, and publication actually achieved.
- Remaining: every real unfinished requirement, not softened into a future enhancement.
- Decision: complete handoff for human verification, a user-requested substantial continuation, or an exact external blocker. Never call a simulated subset the finished Ranked system.
