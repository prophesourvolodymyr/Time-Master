# Phase 1 of F29-A-t — Private Case Center

## Required Model and Thinking

Assigned UI implementer: **openai-codex/gpt-6.1-sol:max**. The model identifier is **openai-codex/gpt-6.1-sol** and the required thinking level is **max**. Do not silently substitute a different model or lower thinking level. If that assignment is unavailable, report the actual dispatch limitation before implementation.

This is the implementation-worker assignment, not the Physique in-app judge. It does not change the service-approved judging model, rubric, judging version, model-provider consent, or a match already under judgement. Do not call an image-generation or judging service to implement this case UI.

## Features Included

- F29-A-t — Own private case list on native iPhone and native macOS.
- F29-A-t — Authorized selection and navigation into the canonical F29-A-u Case detail, preserving account, record, reading position, and list focus.
- F29-A-t — Receipt-to-case reconciliation and real published contact while restricted or unable to sign in; no second detail, reply, or appeal implementation.
- F29-A-t — Complete empty, loading, offline, stale, access-denied, removed-record, deleted-account, lifecycle, accessibility, and reduced-energy behavior.

These are meaningful parts of one case-center slice, not separate permission to rebuild safety intake, the backend, ranking, or navigation. List each implemented part separately in the human handoff. Implementation and review tracking belongs only in CYCLES.md.

## Context

Build the signed-in person's private reports, appeals, and restriction notices as a native list and readable document, not a public allegation feed, opponent chat, or moderation console.
The latest UI direction requires both iPhone and native Mac, minimal visible text with complete safety meaning, and the unchanged real timer/full badge rails/large vertical players whenever the battle stage is visible.
The preceding work was documentation only; no case API, app surface, camera path, or human-reviewed foundation is established by this brief.

## What You Need to Read First

Read the durable product context before code, including the relevant dependency sections. Paths are from the repository root.

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-t-case-center/DOCKS.md — the complete case-center product decisions, state matrix, platform behavior, animation table, and confidentiality boundaries.
- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-u-case-detail/DOCKS.md — the canonical selected document and inline safe response; consume its reviewed implementation rather than recreate it.
- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-v-review-composer/DOCKS.md — the canonical new safety-appeal and outcome-dispute composer.
- features/F29-physique-duels/DOCKS.md — shared product contract, finality, consent, privacy, and feature boundaries.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — native routes, report receipt, active-match safety presentation, camera stop, restore, explicit exit, and focus. Apply the later vertical-player/both-native-platform direction where older prose permits a horizontal matchup or describes Mac as secondary.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — especially Safety Access and Report Entry Points, Reporting Interaction and State Contract, Private Case Status and Human Review, Appeals and Competitive Finality, Evidence Minimization and Urgent or Legal Handling, and Accessibility, Interaction, and Animation.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — especially Authentication, Access, and Secret Boundaries; App-Controlled Data Lifetime; Deletion and Other Privacy Requests; Public Privacy Information and Business Accountability; Operational and Privacy Failure States.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — Authoritative Finality and Outcome Disputes, Corrections, and Audit Meaning. Case status never becomes rating authority.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — Accepted Inputs and Judge Blindness, Explanations and Confidence, and the version/appeal boundaries. Case text is not judge context.
- CYCLES.md — current F29 implementation plan and the actual human-review state of the account, case, routing, and safety dependencies. A checked documentation item is not approval of implementation.
- features/DOCKS.md — current feature ownership and any review-approved changes since this brief.
- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188; reuse the shared visual language, not Dynamic Type clamps or exercise Elo as case status.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151; exercise HUD context only, not live provisional physique scoring or a moderation countdown.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109; cosmetic previews are not trusted competitive achievements, identity verification, or a case-cleared badge.
- TimeMaster/App/TmaxApp.swift, lines 8–19, and TimeMaster/App/TmaxCommands.swift, lines 6–37.
- TimeMaster.xcodeproj/project.pbxproj — discover real target membership, schemes, and deployment settings. Preserve iPhone iOS 16 and native macOS 14 support without raising targets.
- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — inspect the actual image. Borrow direct hierarchy only; no copying its people, footage, web pills, text, assets, or side-by-side matchup.
- Relevant installed skills: swiftui-pro and its navigation/accessibility/performance references; swiftui-animation for scoped, interruptible, reduced motion; apple-hig-reference for current platform guidance. Read the matching skill before implementation. The earlier UI Skills selection was dimillian/swiftui-ui-patterns; reuse that selection rather than repeating installation/setup.
- Dimillian SwiftUI UI Patterns: https://github.com/dimillian/Skills/blob/main/swiftui-ui-patterns/SKILL.md and its references/list.md and references/split-views.md. Use standard selection-driven native list/detail; no independent custom secondary-column system is needed.
- Current Apple HIG: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables, https://developer.apple.com/design/human-interface-guidelines/designing-for-macos, and https://developer.apple.com/design/human-interface-guidelines/motion. Apply the actual retrieved guidance, distinguish API availability, and state a live retrieval limit if present.

No STYLES.md was present when the UI direction was written. Do not create a new global style file. Use the source conventions above and any subsequently user-approved existing conventions.

After these prerequisites, discover the actual implemented Physique account/session, case model/service, safe-text intake, contact publication, and routing files through the repository. Do not assume prospective files already exist or invent an endpoint from this document. Read each concrete existing file before editing it.

DOCKS.md is plain-language product context, not implementation authority. Validate technical approaches against current source, availability, relevant skills, and actual reviewed contracts. Never copy an incompatible 26-only API into the iOS 16/macOS 14 path.

## What Happened Last Session

The documentation-only design selected a private docket with concise native case rows and an authorized detail document. iPhone uses list-to-detail push navigation; Mac uses a native resizable list/detail split, retaining the existing 800 by 600 app minimum and normal title bar. Correspondence is asynchronous operator text, not player chat or a simulated live-support conversation.

Confirmed records only belong in the list. Local drafts and receipt-unknown intake do not become fabricated cases. Updated, Received, and Last checked have different meanings. Sensitive correspondence is not an offline archive, and a blocked or signed-out session cannot display stale private text.

The user requires both native platforms and large vertically ordered players wherever a battle composition appears. Full public badge rails remain above the players. The case center normally shows no battle or image evidence; an active-match entry reuses the shared safety presentation with the real timer and safe return/exit access. The list/detail split is not a horizontal player comparison.

No production screen, service behavior, accepted prototype, passing runtime check, or human implementation review was claimed. Re-read the present source and review status; do not treat this historical planning section as proof that the dependencies now exist.

## Prerequisites and Review Boundaries

Code begins only once the real shared foundations and contracts below are implemented and human-reviewed. A case-center view is not independently shippable before them.

1. The account service must authorize the caller's own case list, detail, allowed correspondence, and own restriction notices. It must reject cross-account references and supply current access semantics, including a defined case-only restricted session where offered. A normal match sign-in API is not evidence of these permissions.
2. The case contract must expose real received references, distinguish report/appeal/restriction meaning, provide authoritative state/activity/receipt times, current permitted actions, linked records where appropriate, paging, and receipt reconciliation for the same submission. Determine the actual error and unknown-state behavior. Do not convert an unknown or denied state into Closed or No cases.
3. The safety operation must have real staff review, safe-text policy, published operator contact, actual staffed expectations, and an authenticated way to handle correspondence. The fallback route when private case access fails must be a real reviewed publication usable without playing or signing into a replacement account.
4. The account privacy and lifecycle foundation must protect same-account drafts and minimal summaries, clear private state on sign-out/switch/deletion/revocation across windows, implement retention, and prevent notifications, diagnostics, replay, and cached content from exposing private text. A legal hold is not participant gallery access.
5. Existing native routing must support context restoration, exact-match links, contextual report/appeal intake, and the shared active-match coordinator. Case navigation must not create a second camera owner, deadline, slot charge, or exit rule.
6. Before integrating dependent pieces, confirm their actual human-reviewed boundary in CYCLES.md and the current handoff. Do not silently connect two unreviewed implementations. Existing documentation and a compiling stub do not satisfy this gate.

If an essential contract or operating channel is missing, name the exact missing prerequisite and owning area. Do not ship a production mock, fabricated empty list, local-only moderation service, unconditional support success, sample correspondence, placeholder appeal, or unavailable-only shell as this deliverable. Complete reachable real integration only where it is genuinely within the approved reviewed contract; do not take over an unowned service rebuild to conceal a dependency.

Case and support access must remain usable when the judge, camera, sharing consent, eligibility for rated play, or ordinary participation is unavailable. This UI does not itself authorize public rated participation before the remaining F29 safeguards are operational.

## Design Decisions to Preserve

- One clear Cases heading. Introductory copy: Private reports, appeals, and decisions. No public report tally, case-cleared achievement, severity rank, avatar grid, body thumbnail, or allegation excerpt.
- Native Needs you section only for an actual requested next action, followed by Cases. Sort by server case activity, not refresh time. Keep closed cases reachable while retained. Do not pretend a partial page is the whole account history.
- Row content: type, safe contextual title, confirmed status, date, and ordinary navigation/selection. Use the source type, spacing, colors, and focus treatment. Let labels wrap; no clipped status or type-size clamp.
- Detail order: current state and Updated; real next step; authorized acknowledgement or own decision scope/duration; correspondence; chronological Activity; metadata/reference disclosure. Contact and safe navigation remain easy to reach.
- Only a service-authorized real next step gets the primary action. Reply when requested/allowed; Appeal decision or View appeal through the existing flow; View match as a secondary current-authorized route. No new form with invented appeal windows.
- Use native list and split navigation rather than a web dashboard, custom drag drawer, third inspector, or administrative multicolumn table. The selected Mac row remains highlighted. Extra monitor width does not stretch text beyond the shared readable column.
- Correspondence uses speaker labels You and Support plus real dates in a document, not chat bubbles, typing dots, read receipts, reviewer avatars, live presence, or a fake support response timer. Do not imply independent human review unless it occurred.
- One deliberate Copy case reference action copies only the person's full permitted reference. There is no complaint share card or silent clipboard write.
- No ambient animation in this sensitive surface. Shared tactile press, native navigation, short status changes, and interruptible disclosure growth provide the requested animated quality without celebratory punishment.

## What to Build

### 1. Connected own-record list and routing

Connect the actual account-authorized case-list, selection, paging, and receipt-to-record routing to the reviewed Physique foundation. Consume F29-A-u for detail retrieval and correspondence. Reuse models, cancellation, account ownership, action capabilities, and pagination; do not create a second client, detail reader, or global store.

Accept normal Safety entry, exact service-confirmed receipt entry, own notice/appeal entry, and a generic notification destination. Revalidate access before showing context. Preserve the intended destination only for its authorized account. Resolve receipt uncertainty against the original request before inserting a confirmed case.

Do not show another person's incoming report about this account. Show this account's own authorized notice instead, without reporter identity, raw complaint, evidence package, or exact sanctions against somebody else. Keep distinct linked report/appeal/notice identities where the service supplies them and avoid duplicate rows across page overlap, repeated receipt resolution, refresh, or multiple windows.

Implement first load, confirmed empty, refresh retaining safe data, older-page activity/failure, individual-detail failure, offline minimal summary, stale time, expired session, access denied/unknown ID, deleted/unretained case, current-account deletion, and neutral deleted-counterpart states as specified. No failure may masquerade as a confirmed empty result. Preserve selection, keyboard focus, and visible list anchor during updates.

### 2. Accurate dates, status, and actions

Display the actual confirmed state rather than a guessed pipeline. Handle Received, Queued, In review, safe information requested, Action taken, No violation found, Inconclusive, Withdrawn, Closed, appeal receipt/review/upheld/revised, and this person's real restriction lifecycle according to the actual contract. A new unsupported service state is neutral Status unavailable with recovery, never a permissive fallback.

Keep Received, Updated, event time, and Last checked distinct. Use locale-aware concise list dates and full detail date/time/time zone without hover-only discovery. Unknown event time remains Time unavailable. Published expectations reflect the real operation, not F29-D's unmeasured target as a guarantee.

For restrictions, show only this account's rule category, safe reason, capabilities affected, actual effective time and duration, and available appeal. Unknown duration is No end date provided, not a fabricated permanent ban. A passed local end time does not lift the restriction: show the last confirmed state and check real access.

Follow service-authorized appeal, withdrawal, and exact-match routes. Existing appeal receipt opens that appeal rather than offering a duplicate. A closed or changed action reports the current reason and recovery; dismissing a notice never withdraws or deletes a case. Scoring-review status does not recalculate Elo, reroll a judge, restore media, erase a loss, or claim a reporter win. A real pending correction uses Rating updating after review and links to the service-owned result when permitted.

### 3. Canonical detail handoff and published contact

Do not build the detail document, a reply sheet, or an appeal form in this worker. Embed or navigate to the reviewed F29-A-u Case detail with the exact authorized selected case. That owner handles permitted inline safe responses, bounded drafts, private decisions and real acknowledgements. New safety appeals and outcome disputes use F29-A-v. Keep selection, list scroll and focus stable on return, and reconcile any changed case summary through the existing service.

The consumer-visible integrated scenarios below may traverse those owned destinations, but they do not grant this worker ownership of their source files. Resolve a missing or incompatible reviewed destination with its integration owner rather than copying it into Case center or leaving a no-op row.

Connect Contact support to the operator's actual published destination, recipient, staffing statement, and supported system handoff. Show what text/reference the person chooses to send; no hidden case transcript, credentials, or opponent data. The handoff being opened is not a received support request. Provide an honest retry or copyable published destination when a handoff fails. Do not invent an email or fall back to a no-op action. Permit the reviewed contact route while restricted, signed out, offline where authentic published details exist, or normal intake is unavailable.

### 4. Native iPhone and Mac surfaces

On iPhone, use the existing navigation stack and native grouped list; push the reviewed F29-A-u detail and restore this list on return. Maintain forty-four-point targets, full Dynamic Type, measured safe areas, keyboard-safe host integration, and reachable Back/Contact. Detail editing and confirmation remain with their owners.

On native macOS, integrate into the existing titled WindowGroup. At 800 by 600 and normal text, a resizable case list selects the canonical F29-A-u detail pane. Provide standard sidebar/collapsed navigation where geometry or large text needs it, retain selection and focus through resizing/fullscreen/displays, and do not raise the minimum or add another detail/inspector implementation. The detail's inline response stays its owner's responsibility.

Support Mac list arrows, Tab/Shift-Tab, visible focus rings, ordinary pointer/selection behavior, and screen-reader navigation. Hover/context menus may repeat, not hide, essential actions. Return and Space are scoped to the focused semantic control; no global key capture while typing. Escape closes the current transient presentation safely and never withdraws, forfeits, or signs out. Respect meaningful-draft close/quit handling.

Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O with their existing app meanings. Cmd-W and quit use the current native window/draft behavior and the shared active-match consequence confirmation where applicable and possible. Do not claim to intercept force quit or classify it as a confirmed voluntary forfeit.

### 5. Active-match and lifecycle boundary

Opening a case from a running match reuses the shared Safety presentation and immediately stops camera acquisition and shields sensitive content when leaving capture. The actual match timer and safe Return/Exit remain reachable outside the case scroll. Opening Cases does not pause/extend a clock, consume another slot, create another camera owner, or confirm a forfeit.

If a battle composition is visible, keep the real timer above COMPLETE public badge/identity rails grouped by owner, above TWO LARGE VERTICAL panels, You then Opponent, at every width including large Mac windows. No side-by-side player adaptation, badge cap, +N, clipping, body overlay, hover-only badges, ticker, distorted crop, or two tiny picture-in-picture players. Scroll the stage for short windows and large text while timer and safe actions remain usable. This standalone text-only case surface does not add a fake battle or timer just to satisfy that stage invariant.

Return fetches the same service-owned match; a camera resumes only through the permitted explicit existing action. Respect the ninety-second capture, twenty-second reconnect grace, thirty-second final-set judging deadline, and no reset of retakes or allowance. If the match ended while a reply was being written, update the shared status without forced navigation, draft loss, pose auto-opening, or repeated reward animation.

Cases remains functional with iPhone camera permission denied, Mac TCC denied/restricted, camera missing/busy, and external or Continuity Camera disconnected. It never acquires a camera. Returning to capture uses the actual device/permission recovery, never fake video or a rated file-picker fallback.

On app deactivation, lock/background, minimization, sign-out, account switch, deletion, or access revocation, shield sensitive case text immediately and reconcile the actual account/current state before revealing it again. Clear affected private state in every account window. A secondary window cannot start another match or independently charge an allowance. Do not auto-submit when the window becomes active.

### 6. Accessibility, motion, and energy

Use the product document's complete focus and copy behavior. Announce heading/status when entering a detail; do not automatically summon a keyboard. Reply-sheet dismissal returns focus to Reply or a safe replacement. List return restores the selected row. Routine status refresh does not steal reading focus, text insertion, scroll, or selection. A meaningful change is announced once; no every-tick, spinner-cycle, or interpolated-number announcements.

Honor larger text, VoiceOver, Voice Control, Switch Control, silent use, increased contrast, Reduce Motion, and Reduce Transparency. Text, action labels, errors, dates, scopes, consequences, retention, and contact recipients remain readable. No unsafe hidden caption survives a privacy replacement. Use words as well as color and symbols. Do not reproduce the nearby Ranked Dynamic Type clamps.

Preserve these motion decisions with availability-safe APIs:

- Shared enabled-button press: response 0.24, damping fraction 0.88; no extra scale under Reduce Motion.
- Native navigation and sheets: native gesture/timing rather than a custom body/evidence zoom.
- Local selection emphasis: at most about 140 milliseconds, never a queue of detail transitions.
- Disclosure growth: about 280 milliseconds, non-bouncy ease-out, anchored to the reader's position and reversible from the current state.
- Confirmed status/reply update: about 180 milliseconds; the real state and timestamp are accessible immediately and navigation never waits.
- Case/page insertion: about 160 milliseconds, no staggered cascade or large motion and no anchor jump.
- Reduce Motion: immediate layout or at most about 100 milliseconds of opacity; same content and actions, no scaling, travel, repeat effects, or emotional punishment.
- Privacy stop/revocation/shield: immediate, before decorative animation; no revealing fade.
- No ambient loop, pulsing case wall, celebratory punishment, rank animation, fake progress, arbitrary minimum wait, or replay when a case reopens.

Pause optional visual work offscreen/background/inactive/minimized. Low power and serious thermal pressure prefer static disclosure/selection and short opacity, preserving authoritative clocks and all safety behavior. No per-frame I/O, provider call, image decoding, text measurement, camera rebuild, or broad layout invalidation. Network activity indicators run only for genuine work and may be static when necessary; motion never drives a refresh or send.

## Prospective Files and Change Ownership

Names below are prospective, not assertions that these source files exist. Reuse an equivalent reviewed feature-local file if it already owns the responsibility; do not add a second convention.

- Create or extend TimeMaster/Views/Physique/PhysiqueCaseCenterView.swift for the actual private list, native iPhone route, native Mac split composition, and safe empty/loading/failure surfaces.
- Consume the reviewed F29-A-u PhysiqueCaseDetailView.swift and F29-A-v review destination through their real interfaces. Do not create, extend, or rewrite their document/editor sources as part of this worker; only the bounded case-selection connection belongs here.
- Extend the actual existing Physique navigation/Safety presentation only for Cases entry, confirmed receipt/notice linking, generic notification restoration, focus, and the shared active-match timer/return boundary. Discover its current exact path before editing.
- Extend the already reviewed TimeMaster/Services/Physique/ case/session store and TimeMaster/Models/PhysiqueDuelModels.swift only where this consumer needs an established contract represented. Do not invent a client-side authorization authority, new endpoints, backend schema, new rating engine, or separate request-retry framework in this UI task.
- Update native target membership in TimeMaster.xcodeproj/project.pbxproj only if the established project workflow requires it. Preserve target settings and existing app commands.
- Use focused existing test locations for a necessary uncertain consumer-visible boundary; discover their real paths and conventions. Do not create tests that assert source wording, copy forwarding, mock echoes, incidental view wiring, bare not-throw, or nonempty results.
- Update only the actual F29-A-t implementation todos in CYCLES.md after implementation and focused checks. Record implementation separately from human verification. Do not silently reorder shared plans or mark a dependency human-approved.
- This product document changes only for a necessary accepted product decision after the user reviews/accepts behavior, unless the user directly approves the decision earlier. No implementation recipes, test logs, screenshots, checkboxes, completion evidence, or new source comments in DOCKS.md.

Do not modify unrelated screens, other workers' targets, global theme, app-wide keyboard commands, Profile's two-side shape, exercise image privacy, existing exercise quotas, or ranked provider settings. Existing code and unexpected user edits are not disposable scaffolding.

## Observable Acceptance — iPhone

- Actual account A sees only its service-confirmed reports/appeals/notices. A received report opens the correct detail; an unsent or unknown-receipt report does not become a fake row. Account B cannot access A's record via notification, case reference, restored route, list cache, or draft.
- No cases is shown only after a real successful empty response. A first-load, detail, older-page, offline, auth, or service error has its own accurate recovery instead of a blank success.
- A status change has the real server date. Received, Updated, and Last checked remain distinguishable. Full date/time/zone is readable without hover; a restriction is not lifted by the device clock.
- Native list-to-canonical-detail navigation, Back restoration and Contact support work on short screens and the largest text settings without clipping or hidden actions. This worker does not introduce another reply sheet.
- An integrated visit can exercise F29-A-u's permitted safe response and F29-A-v's review route with genuine receipts; their implementation remains with those owners. Returning reconciles the existing case summary once rather than creating a duplicate row or activity.
- Restricted and declined-consent users can access permitted cases or truthful published contact. The route does not demand camera, Photos, microphone, payment, a new account, or a proof image.
- VoiceOver identifies case type, status, dates, next action, errors, and full reference; focus returns correctly after sheet/detail. Voice Control/Switch Control can reach the same actions without a swipe-only or long-press-only path.
- Backgrounding shields case text immediately. Account switch/sign-out/deletion do not reveal A's cases or drafts under B. Reopening a case never auto-opens evidence or awards Elo/badges.
- During an actual active-match safety entry, the real timer/return remains usable, camera stops immediately, and the same match/deadlines are restored without charge/reset. Any visible battle keeps complete badge rails above two large vertically stacked players.

## Observable Acceptance — Native macOS

- Launch the native Mac target, not a web view or Catalyst build. At 800 by 600 with standard text, the real case list and selected detail are usable with the normal title bar, native toolbar, persistent row selection, and no raised minimum.
- Live resize, shorter content height, sidebar collapse, laptop/large/full-screen/external-display use preserve selected record, readable text, scroll, and draft. Extra width does not create horizontal players, a third moderation inspector, or an overwide transcript.
- Keyboard-only list arrows, Tab/Shift-Tab, disclosures, Copy case reference, Contact, reply editing, Send/Cancel, and native confirmation work with visible focus. Return in multiline text stays a newline; Space/Return never trigger a global capture/submit handler.
- Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their existing commands. Escape and Cmd-W do not withdraw or delete a case; meaningful draft and actual active-match exit consequences use the correct existing native handling. Do not claim a force-quit confirmation.
- Two account-authorized windows reconcile one received reply/case rather than duplicating it. Sign-out, switch, deletion, restriction revocation, and stale notification access shield every affected window, not just the active one.
- Cases and contact work while camera TCC is denied/restricted or external/Continuity hardware disconnects. A case window does not activate the camera. Returning to an active match uses the established one-camera-owner and actual permission/device-recovery rules without file-picker substitution.
- App deactivation/minimization immediately hides private text and pauses decoration; reactivation rechecks the same state without a duplicate send, match, camera start, or slot charge. Authoritative match time continues.
- Native VoiceOver and keyboard navigation read full status/date/zone and own decision scope without hover or visual-only color. Larger text, increased contrast, Reduce Transparency, Reduce Motion, low power, and thermal simplification leave all real information and actions available.

## Focused Verification — Future Implementation Only

This section is a future execution brief, not a claim that any scenario has run. Build/typecheck alone is not smoke proof.

Use the actual native schemes/targets and established tools discovered in the repository. Run the smallest relevant checks for the changed code, then launch and exercise the changed case surface on iPhone and native macOS where those runtimes exist. Use isolated authenticated development accounts and operator-controlled staging case transitions. Do not submit fabricated production allegations, use another person's photos, manufacture unlawful test images, or generate fake production data to make a screen look full. Labeled previews can aid layout only; they are not the runtime evidence.

Exercise these focused consumer-visible paths:

1. Real acknowledged report to list/detail; an actual service-requested reply; one received reply after acknowledgement; reopen without duplicate case/message or award. Observe request-unknown recovery for the same submission, not a mock echo or repeated local row.
2. Empty account, older-page failure, detail refresh failure, network offline with minimal permitted summary, stale time, reconnect, case action changed while editing, and service-authoritative restriction expiry. The visible result must distinguish unknown, last confirmed, denied, and genuinely empty.
3. Two account boundaries and two Mac windows: wrong-account/deep-linked reference, session expiry, sign-out/switch, notification return, current-account deletion, and known revocation. Confirm no private row, correspondence, draft, or cached title leaks. An opaque unavailable response must not reveal unauthorized case existence.
4. A restricted-account safe contact and real supported system handoff, including cancellation and a failed/unreachable handoff. Observe the actual recipient/reference preview and truthful unsent state. Do not claim delivery merely because mail or a browser opened.
5. Both platform compositions: short iPhone/large type/keyboard; Mac 800 by 600, live resizing, sidebar toggle, short/laptop/large/full-screen geometry, and a real external display when available. Inspect actual action reachability, stable selection/scroll, and absence of evidence images or horizontal players.
6. Focus and accessibility with actual native VoiceOver where available, keyboard-only Mac navigation, larger type, increased contrast, reduced transparency, reduced motion, and silent input. Observe focus on entry/dismissal and that refresh/receipt changes do not interrupt typing or reading.
7. Inactive/background/minimized return and low-power/thermal simplification using supported runtime facilities. Observe privacy cover and no decorative work, unsolicited send, camera activation, or reset. Do not manufacture an energy or frame-rate claim from source inspection.
8. If the reviewed active-match foundation is available, open Cases through the real Safety route during a real eligible session, observe immediate camera stop, continuing timer, safe return, unchanged deadline/retakes/allowance, and the required badge/vertical-player composition. Exercise TCC/permission denial and a real external or Continuity disconnect where hardware exists. A simulator or dependency injection does not prove physical capture behavior.

Keep a permanent regression test only when it catches a plausible uncertain consumer-visible bug, such as cross-account case disclosure, unauthorized cached restoration, or duplicate acknowledgement under a defined existing contract. Follow deterministic isolated existing test conventions. For straightforward layout/wiring, use the throwaway smoke path rather than permanent source-text or forwarding assertions. Remove temporary smoke scaffolds after actual proof. Fix clear reproducible failures within the slice; do not rerun a user-reported failure just to confirm it.

Report exactly which native surfaces and scenarios were exercised and their observed result. Name missing physical iPhone, native Mac runtime, external display, Continuity camera, TCC interaction, service access, or live staff-channel proof individually. Do not turn an unavailable physical scenario into a claimed pass or present source inspection, previews, screenshot styling, or a compile as a complete native flow. Screenshots, recordings, or an extended evidence package are not required.

## Human Verification Handoff — Required

List each implemented meaningful part separately: private list and routing; authorized status/detail/date behavior; restricted access and contact; safe correspondence/receipt recovery; native iPhone composition; native Mac composition/input/window behavior; privacy/lifecycle; motion/accessibility/energy. Identify intentionally unchanged or externally unavailable parts honestly rather than claiming a narrower subset completes the slice.

List every changed file separately with its responsibility. State the focused verification actually exercised, exact remaining external limitations, and any product deviation needing review. Ask the user to review the code changes and verify each implemented item. Say ready for human verification, not human-verified or approved. No screenshots, screen recordings, logs, or completion-evidence bundle is required.

After the user accepts behavior, update the smallest relevant DOCKS.md with accepted plain-language product decisions only. CYCLES.md records implementation and pending human review. An automated check, a received support reply, and a committed change are not human acceptance of the UI.

## Mandatory Agent Rules

1. **Single owner, no nested agents.** Do this feature slice yourself. Do not spawn review/design/code workers, split to other models, or take other owners' files. Preserve the exact required model/thinking assignment; report any real dispatch limit.
2. **Scope and user direction win.** Direct user decisions outrank older documentation. Keep both native platforms, complete public battle badges above large vertical participants, service authority, and privacy. Do not silently shrink scope, introduce chat/media/export screens, or add unrelated abstraction, telemetry, provider routing, retry policy, or app redesign.
3. **Real contracts and data.** No production mocks, placeholders, no-op buttons, fake cases/status/progress/reviewer presence, fabricated permissions, or offline local verdicts. A labeled preview is never a release fallback. A missing real prerequisite is explicit, not disguised as an empty account.
4. **Independent implementation.** Read matching skills and relevant source before edits; research technical availability instead of blindly following DOCKS. Reuse the existing theme, account, native presentation, request reconciliation, retention, and safety patterns. No private API or deployment-target raise.
5. **Native smoke, not compile-only completion.** Run focused relevant checks, launch and exercise the actual changed native surfaces, fix clear failures, and name unexercised hardware/runtime limits. Do not claim human acceptance or unobserved output. Do not use permanent tests for source text, wording, copied wiring, incidental defaults, mock echoes, or tautologies.
6. **Privacy and immediate protection.** Access checks are real and account-scoped. Shield/revoke/stop capture before motion. No opponent allegation access, public case badge/count, unsafe proof attachment, correspondence in judge context, media-window renewal, or private data in notifications/logging/replay. No claim that screenshots are technically impossible.
7. **Scoped commit and push for the implementation phase.** After a completed coherent implementation/edit slice, commit only your authorized changes with a clear message and push to origin/main before yielding. Do not stage other owners' or unexpected user edits, force-push, rewrite remote history, or run destructive git commands. If publication fails, report the exact blocker instead of completion. The earlier documentation-only worker did not perform this implementation publication.
8. **CYCLES only for implementation tracking.** Update the appropriate approved implementation todos after the connected work and checks; never mark human review as completed by the AI. No IDE-specific task JSON, duplicate checkbox tracker, shifting shared plan, or implementation evidence/checklist in DOCKS.md.
9. **Complete the connected slice.** Update affected real callers/contracts/tests deliberately, remove obsolete in-scope paths without compatibility shims, resolve clear local failures, and remove throwaway scaffolds after smoke proof. Do not leave stubs, speculative TODOs, fake fallbacks, or a testing-only handoff.
10. **No pointless next prompt.** Complete small remaining implementation, check, documentation, commit, and publication work here. Create another prompt only for a genuine separate substantial user-approved functional slice, not to defer an obvious fix or missing check. A pending human review is a real boundary, not permission to start dependent work.

## When You Finish

Report every implemented item and changed file separately, the observed native verification and limitations, publication result, and a clear request for human code/behavior review. State whether a further implementation prompt is genuinely needed. Do not repeat proposed acceptance as if it were exercised evidence, call a screen independently shippable before its prerequisites, or report screenshots/completion packages as required deliverables.
