# Phase 1 of F29-A-b — Native Account Entry and Protected Return

## Required Model and Thinking

Assigned implementation model: **openai-codex/gpt-6.1-sol:max**. The model identifier is openai-codex/gpt-6.1-sol and the required thinking level is **max**. Do not silently fall back to another model or thinking level. If the execution environment cannot honor that assignment, report the actual dispatch limitation to the coordinating owner before editing code.

This assignment describes the UI implementation worker. It does not select the in-app physique judge, alter F29-B's approved model, raise a player's reasoning setting, or permit provider calls with participant images. A line in this prompt is not proof that a model was actually dispatched.

## Features Included

- **F29-A-b — Account entry and protected return:** a thin native wrapper around the existing real Tmax Account flow, current Physique authorization, distinct restoration/expiry/switch/restriction states, immediate private-content invalidation, and safe return to the requesting action on iPhone and native macOS.

Account forms, providers, consent, camera setup, match authority, identity badges, galleries, restrictions, appeals, and deletion retain their existing owners. Implement this connected slice against their reviewed contracts; do not replace those owners with a new authentication subsystem or production fixture.

## Context

Physique uses the existing shared Tmax account, with separate competition identity, consent, media access, and Elo.
The chosen UI is one compact Physique context block inside the existing native account page, followed by an explicit protected Continue action.
This is a future implementation brief from a documentation-only design batch; the brief is not authorization to bypass unreviewed foundations.

## What You Need to Read First

Read the current contents, not only these anchors. Discover actual current source ownership before opening files not named here.

### Product context and review boundaries

- `AGENTS.md` already supplied by project context; do not search for unrelated agent-rule files.
- `features/DOCKS.md`, specifically the current F29 ownership map.
- `CYCLES.md`, specifically the shared account/navigation human-review boundaries, Cycle 39's F29 prerequisites, and the integrated F29-A-b implementation and human-review entries. A checkbox is not evidence of human acceptance.
- `features/F29-physique-duels/DOCKS.md` — shared identity, eligibility, timing, privacy, and separate-Elo contract.
- `features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md` — entry, navigation, match exit, interruption, and return ownership.
- `features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-b-account-entry/DOCKS.md` — the complete account checkpoint composition, state matrix, private-cache boundary, and all return decisions.
- `features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md`, Accepted Inputs and Judge Blindness — account information and UI chrome do not enter judge context.
- `features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md`, Pairing Eligibility, Allowance/Cancellation/Interruption, Finality, and History — current account, existing match, real deadlines, and no duplicate reservation or charge.
- `features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md`, adult eligibility, Private Case Status, Appeals, and Enforcement — restrictions are not expired sessions; permitted safety routes remain separately owned.
- `features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md`, consent distinctions, device lifecycle, Authentication/Access, data lifetime, and deletion — current authorization, immediate shielding, protected drafts, revocation, and cleanup.
- Read the integrated public-identity/badge owner and match-recovery owner linked from the current F29 index before consuming their code. F29-F owns country and trusted public badges; do not guess a sibling directory name or use local Profile previews as a substitute.

### Existing source anchors

- `TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift:27-322` — the actual shared forms, persistent labels, Sign in/Create account selector, account security, provider availability, confirmation/reset requests, reset form, and real error/notice handling.
- `TimeMaster/Views/Ranked/RankedAccountView.swift:1-39` — the existing single native navigation/account host and busy dismissal rules. Reuse its pattern, not a second nested host.
- `TimeMaster/Services/Cloud/CloudAccountStore.swift:1-282` — shared busy/restored/session state, actual authentication operations, verified callback recovery, sign-out/deletion uncertainty, identity preparation, and apply/recover behavior.
- `TimeMasterCore/Sources/CloudAuthClient.swift:31-89` and its current callback/sign-out sections — offline local restoration differs from accepted service authorization; refresh is shared, identity-bound, and securely stored.
- `TimeMaster/Services/Ranked/RankedAccountStore.swift` — discover the current relevant ranges for synchronous account invalidation and account-bound recovery. Learn the boundary without coupling Physique records to exercise ratings.
- `TimeMaster/App/TmaxApp.swift:8-19,66-96` — native WindowGroup, normal title bar, existing 800-by-600 Mac minimum, startup account ownership, URL handling, and the current shared recovery presentation. Read the current containing blocks before changing presentation ownership.
- `TimeMaster/App/TmaxCommands.swift:6-37` — preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O.
- `TimeMaster/Utilities/Theme.swift:1-81,208-228` — existing palette and controls; background 0A0A0A, surfaces 141414/1C1C1C, action accent FF6A00.
- `TimeMaster/Utilities/ProfileDesign.swift:1-38` — Inter family, semantic scaling, spacing, readable bounds, and the existing iPhone interaction-area convention.
- `TimeMaster/Utilities/TimeMasterGlassControls.swift:20-80` — Reduce Transparency, public availability fallbacks, and the existing press spring with response 0.24 and damping fraction 0.88.
- `TimeMaster/Utilities/EverStore/Components.swift:65-105,193-245` — shared settings page, single scroll area, readable column, rows, and sections.
- `TimeMaster/Views/Ranked/RankedComponents.swift:15-108,148-188` — nearby sports controls and earned-Elo presentation. Do not copy Dynamic Type clamps, decorative local levels, or fixed-size assumptions.
- `TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25-151` — exercise HUD context only, not permission to display provisional physique appearance scores or its side-by-side scoreboard.
- `TimeMaster/Models/LocalProfileModels.swift:23-27,99-109` — editable local badge appearances are not trusted competitive achievements or identity verification.
- `TimeMaster.xcodeproj/project.pbxproj` — inspect the relevant current target/deployment and membership sections; preserve existing iPhone compatibility and native macOS 14 support. Do not raise minimum versions for an optional animation or glass API.
- `genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png` — inspect the actual image. Borrow timer prominence and direct hierarchy, not its side-by-side players, face overlays, purple/brown pills, people, footage, or unlicensed assets.

### Skills and current native guidance

The design batch already selected `dimillian/swiftui-ui-patterns` through UI Skills. Do not repeat registry setup or install another UI library. Use its Sheets, Deep links, and Focus references selectively. If the selected skill is not registered in this execution scope, its canonical source is `https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns`; state any remaining retrieval limitation rather than pretending it was installed here.

Read relevant installed `swiftui-pro`, `swiftui-animation`, and `apple-hig-reference` files before implementation. Their latest-OS examples do not authorize raising this project's targets. Use existing ObservableObject ownership where required by the deployment and shared account foundation; do not create a parallel Observation-only architecture.

Read current Apple topics that answer this slice's decisions:

- `https://developer.apple.com/design/human-interface-guidelines/managing-accounts` — Best practices and Deleting accounts.
- `https://developer.apple.com/design/human-interface-guidelines/designing-for-macos` — native density, resizable windows, keyboard/pointer input, and commands.
- `https://developer.apple.com/design/human-interface-guidelines/motion` — brief, purposeful, optional, cancellable feedback.

STYLES.md was absent in the design batch. Use the existing source conventions; do not create a new global design document or theme to compensate.

DOCKS.md is plain-language product context, not an implementation recipe. Verify technical directions against current source, supported APIs, skills, and real service contracts. Never put code, pseudocode, payloads, todos, or verification evidence into a DOCKS.md.

## What Happened Last Session

The account-entry specialist produced only this brief and the F29-A-b product canvas. No authentication code, Swift view, production mock, provider integration, artwork, build, runtime check, or human-verification claim was produced in that assignment.

The design work identified the existing shared cloud account view/store as the real entry mechanism. Local secure restoration is deliberately offline and therefore is not proof of current Physique service access. Existing provider buttons are availability-gated by the actual account service, not automatically functional and not necessarily permanent placeholders.

The selected direction is a small contextual sleeve around that native shared page, one explicit Continue after real access is resolved, an immediate opaque privacy boundary on identity uncertainty, and no automatic return to body media or live acquisition. Human acceptance of account/navigation/service foundations remains a separate prerequisite.

## Prerequisites and Review Boundaries

Before code, establish from actual implementation and explicit human review that all of the following contracts exist:

- Shared cloud authentication, secure local credential storage, password-manager field behavior, one verified callback handler, shared busy-operation ownership, and account-change isolation.
- Native F29 destination/presentation ownership and account-bound return context, without resetting saved page order or unrelated navigation.
- Real Physique current-account access, distinguishable auth versus service/access errors, restriction scope, canonical active-match lookup, and service-owned timing/finality.
- Immediate feature-wide account invalidation and private-cache access removal across windows, outstanding responses, media loaders, camera acquisition, queued transfers, and report drafts.
- One account/one active match/camera owner across windows and devices, state-aware cancel/forfeit/recovery, and the already-owned consent, camera, result, case, and privacy destinations used by this slice.
- An authorized configured service for native account/access smoke work. Real physical-iPhone service access requires the reviewed secure deployment; do not use a production insecure endpoint or expose provider keys to make a test run.

Review of a specification, a compilation result, or another unreviewed view is not acceptance of those dependencies. If a required contract is genuinely unavailable, name the exact missing operation/ownership and finish all reachable research, but do not create a disconnected UI, fake API response, account store clone, placeholder route, no-op cleanup, or mock-backed production fallback. Coordinate the prerequisite with its owner rather than silently narrowing the slice.

This is one complete account-entry implementation slice. It does not authorize implementing the rest of F29, altering the physique judge, importing local cosmetic badges, adding providers, redesigning Settings/Profile, or starting paid image/model evaluation.

## Concrete Design Reasoning Outcomes

1. **Real form first, not a gateway.** Keep the single Tmax Account title and existing controls. Place one compact orange-accented Physique context block at the start of the existing shared page's scroll content. Do not wrap a second ScrollView or NavigationStack around a complete page.
2. **Explicit return, not token-change navigation.** A real signed-in session and current access checks make Continue to Physique available. A password-recovery session does not skip the new-password requirement. No account observer automatically starts a queue, camera, upload, report, or gallery.
3. **One readable column on each platform, native presentation differences.** iPhone uses a tall native account sheet and a measured safe-area Continue region after auth is complete. Mac uses an attached native sheet, readable form density, cancellation/confirmation toolbar placements, and scrollability at 800-by-600 without a phone frame or wider app minimum.
4. **Protect before waiting.** Identity uncertainty, sign-out, switching, deletion, and revoked access remove private content before asynchronous work or animation can run. A translucent cover, blurred but accessible view, or fade through an old pose is not sufficient.
5. **Restriction is not expiry.** A verified restricted account keeps its true session and receives the real private reason and safety route. An unexplained access failure is not labeled a ban, and another-account creation is not offered as an enforcement bypass.
6. **Account UI is not battle UI.** There is no fake timer or miniature matchup in the account form. When a permitted battle is restored, use the real timer, all owner-grouped public badges above two large vertical panels, You above Opponent at every width. Privacy shielding removes the entire old battle rather than changing it into an unauthorized preview.
7. **Tactile but quiet.** Reuse the existing press spring. Actual context changes crossfade over 180 milliseconds, context height may settle over 280 milliseconds, and a successful real check can settle a small checkmark within 180 milliseconds. No loop, medal, score reveal, confetti, or error shake accompanies authentication.

The product tradeoff is one deliberate Continue after authentication in exchange for predictable recovery completion and safer cross-account return. Do not remove that decision as a generic conversion optimization. Older parent wording about iPhone-first work or a wide side-by-side comparison does not override the user's native-Mac and vertical-player direction.

## What to Build

### 1. Thin native account context and presentation

Create the feature-owned wrapper around the existing shared account surface. The optional Physique context must leave ordinary Settings and exercise Ranked callers unchanged. Keep one actual title, one account-operation owner, one scroll region, and one native navigation host per presentation. The F29 context uses the shared theme and controls; it is not a reusable generic onboarding framework.

Use the exact copy hierarchy and state meanings from the product canvas. The default contextual instruction is Sign in to compete with Your Tmax account. Separate Physique Elo. History entry uses Sign in to continue. The compact context may scroll away; Close remains accessible. Signing in alone sends no physique photos and does not adopt the exercise-specific image-sharing promise as Physique consent.

Do not copy the entire account form into a new Physique view. Existing account creation, confirmation, password reset/change, account security, linking, and deletion remain their real shared screens/actions. Existing exercise-only identity and legacy-link sections remain clearly exercise scoped; they do not become Physique identity or badge controls.

### 2. Real identity and authorization states

Distinguish local restoration, service-access checking, successful transparent refresh, signed out, actual unrenewable session, network/service unavailability, secure-storage failure, missing competitive profile, actual restriction, age/consent requirements, deletion uncertainty, and cleanup failure. Do not infer identity from email, a local profile name, a cached badge, a public avatar, or an earlier view's success state.

Use the existing account service's real outcomes. Do not add another refresh loop or token store. An offline restored identity may keep unrelated local app features usable, but cannot unlock private Physique media or current participation. A generic failed access response is not proof of a restriction. A public profile not yet created, Unplaced status, or missing optional country is not an auth failure.

An account form error preserves useful editable email and shows an actual error. It does not store passwords in preferences or log them for debugging. Duplicate taps, busy states, cancellation, and retries operate on the real named request. Do not show a success check until both the actual identity and requested Physique access have been resolved.

### 3. Available providers and verified recovery

Preserve the shared email/password baseline and existing password-manager field semantics on both platforms. Do not disable paste or replace secure fields with custom drawing. Preserve current shared create/new-password policy and visible labels rather than adding a different Physique policy.

Apple/Google choices follow the existing real availability check. Unknown or disabled means explicitly unavailable; enabled means the existing provider session actually works under its configured service. Add no provider and do not make decorative placeholders act like successful authentication. Preserve native provider cancellation.

Forgot password? uses the existing nonenumerating request and same-device latest-link instruction. Verification and reset callbacks go through the existing single shared handler. Recovery temporarily establishing a session is not permission to navigate away: the actual New password and Confirm new password flow must complete before Continue is allowed. Invalid, expired, wrong-device, already-consumed, duplicate, and superseded callbacks do not stack presentations, bypass recovery, or repeat navigation.

Resolve the current app-level recovery sheet and this feature's account presentation as one owner. Do not add an independent F29 URL parser, intercept account tokens in view code, or show the same shared account view in two stacked sheets.

### 4. Owner-bound intended-action return

Implement every return row in the product canvas against the real F29 presentation owner:

- Lobby Account returns to the safe lobby and useful same-owner position.
- Find opponent returns to the next missing preparation requirement, never directly into queue or an allowance reservation.
- History opens current-account records; a different account never inherits cached rows, pagination cursors, selected matches, or reading positions.
- A particular match returns to authorized nonmedia detail only; an unavailable/wrong-owner target yields Match unavailable and the safe lobby, without leaking opponent, date, or result metadata.
- An interrupted gallery returns to its authorized result detail; viewing poses requires a new intentional action and fresh current permission checks.
- Reports, appeals, cases, and text-only drafts return only for their rightful account and still-valid reference/lifetime. Never submit a draft on return. Sign-out/switch discards it.
- A canonical active match takes precedence over starting another match. Use its real recovery choice and camera-owner handoff without a second match, reservation, or charge.
- A verified external account link with no live Physique intent stays within the actual shared account flow; do not invent a Physique redirect.

Keep return context lightweight, internal, and account-bound. No passwords, tokens, signed media URLs, image objects, arbitrary external redirect, or copied evidence. Late responses after close, identity change, or a newer request have no navigation effect. Closing cancels the deferred request but does not undo a successful sign-in. A destroyed source window cannot send a return into an unrelated window.

If a reviewed foundation persists a return across relaunch, retain only its permitted protected reference. If it cannot be safely resolved, use the actual lobby/canonical match entry. Do not add a global unscoped last-route preference.

### 5. Real account change and private-cache invalidation

Connect F29 to the shared account-change boundary, not only the visual account sheet. Changes initiated from Settings, recovery callbacks, other windows, token rejection, or deletion must produce the same protection.

Before any asynchronous identity transition can suspend, stop/shield capture, prevent new affected transfers, close body viewers, and remove private visible/accessibility content in every F29 window. Cancel or invalidate old-account requests so they cannot repopulate state. Remove old decoded media, signed links, unnecessary camera buffers, and unsubmitted candidates when authorization is lost. Do not continue a camera session behind the form.

Actual sign-out, confirmed account switch, or deletion clears old-account private Physique snapshots, media/thumbnail access, drafts, cursors, badge/country edits, cases, deferred return targets, and form secrets. A same-owner expired-session recovery may retain only minimal protected nonmedia recovery context and a still-valid text-only report draft permitted by F29-E; no body cache is an exception. Sign-out and switch remove that draft.

Use the foundation's actual cache removal and access-control operations. A failed cleanup stays shielded, presents an honest failure, and provides a working Retry cleanup. Do not ship a button that only clears an error string. Do not call local hiding remote deletion, consent withdrawal, or rating removal. Do not erase unrelated local workouts, Profile, music, library, backups, or account-owned resources from other features.

The shared account's database-sync stop and library boundary must remain intact. Failed/cancelled switching restores the original account only if the existing service actually establishes that unchanged identity; then recheck Physique. Do not optimistically relabel data or merge by display name/email.

### 6. Restrictions, deletion, and active-match account management

A real Physique restriction has its true private scope, safe reason, supplied duration, and safety owner's real notice/appeal route. Pending appeal is not reinstatement. View history, privacy, case access, or deletion only to the extent currently authorized. Do not suggest another account as a way to compete while restricted or expose a public accusation badge.

Keep deletion in the existing shared account flow with the reviewed F29-E semantics. Pending/unconfirmed deletion is not complete. Confirmed remote deletion plus failed local credential cleanup keeps the private surface inaccessible and offers the existing real cleanup/sign-out recovery. Account deletion is not implemented by merely clearing a UI session.

Opening account management from preparation stops capture. Existing search/Ready/countdown delegates to real state-aware cancellation; before Go there is no Elo/allowance loss. If Go wins the race, the old Cancel is not silent consent to forfeit.

After Go, intentional account management uses the match owner's real confirmation and consequence. Stop and shield immediately. Offer Keep match or an actual eligible Forfeit and open account; respect invalid/safety/service no-contest precedence. An external account change, expired session, involuntary interruption, or force quit without confirmation is not automatically a voluntary forfeit. An unconfirmed remote exit is presented as unconfirmed, not a successful leave.

No auth screen resets a deadline, accepted-pose state, retake count, reservation, or result. A result finalized while sign-in is open returns as the real result; no second judgement, score animation, badge award, or fresh charge.

### 7. Complete native platform, input, and motion behavior

On iPhone, use the specified tall native sheet, shared labeled fields, measured keyboard/safe-area geometry, and one return action only once auth/recovery/access permits it. Support short phone heights, landscape, and largest accessibility text without clamping or hidden instructions. Keep ordinary touch targets at the existing forty-four-point convention and preserve text selection/password-manager behavior.

On native Mac, keep the existing normal title bar, 800-by-600 minimum, menus, commands, readable single-column sheet, native control density, keyboard focus, pointer states, and live resize. Laptop, large, full-screen, and external-display windows must remain usable without becoming a two-account/dual-player login layout. Tab/Shift-Tab, native text editing, selection, paste, and password-manager insertion work. Return and Space operate only through the focused semantic field/control; do not capture them globally or install a destructive default action. Escape/Command-W/quit follow current sheet and active-match state; force quit cannot be prevented or reported as confirmed forfeiture.

A second window cannot start another auth provider session, refresh worker, active match, camera owner, or allowance reservation. A passive duplicate checkpoint reports the real in-progress shared operation without offering a duplicate submit. Shared identity changes invalidate every window, including inactive/minimized windows. Handle system credential/browser interactions without treating their focus changes as a deliberate forfeit.

This wrapper never requests camera TCC or an iPhone system permission. Return to preparation surfaces real denied/restricted/missing/disconnected camera states under their camera owner, including external and Continuity Camera disconnect. Do not repair them with a fake preview, Photos picker, or rated file upload. Account success does not silently reactivate acquisition.

Apply the product canvas motion table: shared 0.24/0.88 press spring, 180-millisecond context crossfade, at most 280-millisecond context layout settle, small real-success checkmark settling within 180 milliseconds, 160-millisecond error appearance without shake, and approximately 280-millisecond nonmedia return continuity. Authentication success never waits for animation. Privacy removal is immediate with no old-content crossfade. No ambient loop or account celebration is required.

Reduce Motion removes scale/travel and uses immediate layout or at most a short 100-millisecond opacity update. Reduce Transparency uses opaque readable surfaces. Increased Contrast, VoiceOver, Voice Control, Switch Control, keyboard, and pointer paths retain all actions and status information. Focus changes belong to actual presentation, validation, verified recovery, or destination transitions, not each refresh/spinner frame.

Pause decorative work offscreen/background/inactive/minimized. Under low power or serious thermal constraint remove optional scaling and use static progress status where appropriate. Do not perform per-frame network/auth/file/image work, rebuild a camera for a transition, or invalidate the entire app layout. Actual service clocks continue. Announce meaningful state milestones, not every tick or spinner value.

## Prospective Files to Create or Modify

These are future implementation surfaces, not files created in the design batch. Confirm the live foundation's actual files before editing and reuse its existing ownership.

- **Create:** `TimeMaster/Views/Physique/PhysiqueAccountEntryView.swift` — only the feature context, native hosting integration, protected return affordance, and feature-owned accessibility/motion presentation.
- **Modify narrowly if required:** `TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift` — optional contextual insertion/hosting seam and state/focus integration. Preserve all real forms, default callers, password-manager semantics, security destinations, and availability gating; do not duplicate or wholesale replace it.
- **Modify narrowly if required:** `TimeMaster/Services/Cloud/CloudAccountStore.swift` — integrate with the existing real identity-change and outcome boundary where the reviewed foundation exposes it. Do not create another auth client, add provider behavior, or weaken sync/credential isolation.
- **Modify narrowly if required:** `TimeMaster/App/TmaxApp.swift` — reuse the one verified recovery presentation owner. No second callback handler, app shell, new unrelated command, or global routing rewrite.
- **Modify the reviewed existing F29 presentation owner under:** `TimeMaster/Views/Physique/` — request origin, safe source-window return, next preparation requirement, and existing destination actions. Its actual source name is a prerequisite supplied by the implemented foundation, not a reason to invent a second root view.
- **Modify the reviewed existing F29 account/match/privacy owner under:** `TimeMaster/Services/Physique/` and its existing model location — consume its canonical account access, error/restriction states, private-cache lifecycle, active-match lookup, and same-owner late-response protection. No parallel account store or generic event framework.
- **Modify only if source membership requires it:** `TimeMaster.xcodeproj/project.pbxproj` — include the real view in both current native targets, preserving deployment versions and build configuration.
- **Update:** `CYCLES.md` — only this slice's implementation items and honest remaining human-review/runtime boundaries after actual focused checks.
- **Modify existing focused account/return behavior tests only when their contract changes or a plausible consumer-visible edge requires a regression.** Discover their exact current paths first. Do not add source-text assertions, wiring tests, mock echoes, or a duplicate test suite for the shared account implementation.

Do not edit unrelated worker targets, parent product policy, public badge design, imported Profile, exercise evidence, workouts, provider/model preferences, or navigation ordering. Do not create README/CHANGELOG files or documentation inside source directories. DOCKS.md remains product context; accepted product changes are documented only with the user's approval, never as a place for test logs or completion evidence.

## Observable Acceptance — iPhone

- Entering Physique and reading Rules/Pose guide requires no account, camera, or upload. The account checkpoint appears only for a genuinely account-required action or deliberate Account access.
- Sign in, Create account, confirmation-needed, invalid credentials, disabled/unknown providers, actual configured providers where available, Forgot password?, verified recovery, invalid/latest-link recovery, password change, switching, sign-out, and deletion all operate on the real shared flow. No dead button or simulated success stands in for unavailable configuration.
- Ordinary Return/Next submission and an available password manager preserve native field behavior. Recovery does not expose Continue before the actual password change is complete. Error correction retains useful email without revealing a password or clearing the entire form.
- A local restored identity first resolves real service access. Offline does not falsely mean Session expired; actual session expiry does not retain visible private Physique content.
- After sign-in, Continue is explicit and returns to the correct allowed nonmutating destination. It does not queue, reserve, capture, upload, become Ready, send a report, or reopen body images. Close cancels the deferred intent without undoing a real account operation.
- Same-owner reauthentication can resume a permitted detail/draft. A changed account cannot inherit another owner's history, pose image, report draft, case, cursor, country/badge draft, or match target, even if an old response arrives afterward.
- A restricted verified account receives its real private notice and permitted appeal route, not an expired-password form or a create-another-account suggestion.
- The existing current match wins over another start request. A pre-Go cancel/Go race cannot silently become a forfeit. Auth changes do not reset deadlines, duplicate a slot, or override a finalized result.
- At short heights, landscape, keyboard-visible state, and largest accessibility text, every label, field, error, Close, recovery action, and permitted Continue is reachable without shrinking text, obstructing the keyboard, or hardcoded spacers.
- Any returned battle shows the real top timer, all public owner-grouped identity/badge rails above two large vertical panels, You then Opponent. No unauthorized battle remains behind the account sheet. Media never auto-opens on return.
- VoiceOver focus, announcements, Voice Control/Switch Control, Reduce Motion, Reduce Transparency, contrast, inactivity shielding, and low-energy behavior match the canvas. Privacy stop never waits for animation.

## Observable Acceptance — Native macOS

- The actual macOS app, not Catalyst/web, opens the attached native account sheet in its requesting window. It preserves normal title-bar controls, existing menu commands, and the 800-by-600 app minimum.
- At minimum, laptop, large, full-screen, external-display, and live-resized window sizes, the single readable form scrolls and retains focused field/selection. There is no stretched phone form, redundant account sidebar, or side-by-side returned players.
- Native pointer, text selection, paste, password-manager, Tab/Shift-Tab, focused Return/Space, and state-aware Escape/Command-W behaviors work without a global submit or forfeit interceptor. Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O are not repurposed.
- A second window does not create another authentication/provider operation, callback sheet stack, match, charge, or camera. Account invalidation reaches every window before old-account private content can reappear. A late response from the first account does not affect the second account or reopen a closed source window.
- Background, inactive, hidden, and minimized windows protect account/private data and pause decoration; activation reads current state without repeating sign-in, resetting a service deadline, or turning on a camera.
- Returning to camera preparation correctly exposes TCC denial/restriction, no camera, unavailable external camera, or Continuity disconnect if present. Sign-in never opens a rated file-picker substitute. Missing physical-camera proof is reported separately from exercised account behavior.
- Voluntary active-match management follows actual cancel/forfeit confirmation and service authority. Involuntary session loss, browser focus transfer, close/quit interruption, or force quit is not misreported as an accepted voluntary forfeit.
- Complete wrapped public badges, real timer, large vertical players, optional self-declared country semantics, and clean evidence/judge blindness remain intact whenever an authorized battle is actually shown.
- VoiceOver, keyboard focus visibility, long labels, readable errors, increased contrast, reduced motion/transparency, and low-energy/inactive behavior work on the native surface, not only a preview.

## Focused Engineering Checks and Actual Native Smoke

Use isolated app data and authorized test accounts/service state. Never change production identities, restrictions, libraries, saved sessions, or private body media to manufacture a demonstration. Do not run paid model/image generation; account entry does not require judge calls. Use the current repository's smallest relevant build and existing focused auth/return regressions. Fix clear failures in the connected path.

Build both affected current native targets with the existing supported deployment versions. A build is not the smoke proof. Launch and exercise the actual changed native account presentation on iPhone Simulator or an available iPhone and the native Mac app where runtimes exist. If a platform runtime, secure deployment, credential service, configured provider, password-manager environment, or physical camera is unavailable, finish reachable work and state exactly which scenario was not exercised and why. Do not substitute a rendered preview, fake identity, or mock camera for that claim.

Exercise these meaningful scenarios without turning the task into an exhaustive evidence package:

1. **Entry and return:** open from Find opponent, private history, and one authorized saved detail. Complete actual sign-in and choose Continue; observe the correct destination and no queue/charge/camera/upload. Close a separate completed sign-in and observe no deferred action executing.
2. **Creation and recovery:** exercise the real configured creation/confirmation behavior; correct a rejected password without losing email. Request a reset and follow a real verified link in an authorized isolated setup. Observe recovery gating, actual update completion, and duplicate/invalid/expired-link handling through the shared handler. Name unavailable email/provider configuration honestly rather than marking it passed.
3. **Restoration versus expiry versus offline:** relaunch with a real stored session, observe access checking, and exercise offline access and actual unrenewable credentials separately. Observe privacy shielding and the correct recovery instruction rather than inferring success from a label.
4. **Cross-account isolation and late completion:** use two isolated actual accounts with distinguishable permitted records. Delay a first-account request through the authorized test environment, switch to the second, then release it. Observe no old records, images, drafts, return route, or readiness replacing the second account. A regression here is justified if the existing suite does not cover the consumer-visible race.
5. **Restriction and cleanup:** use actual controlled service restriction state and a controlled cleanup failure in the isolated environment, never a production UI hardcode. Observe the true private restriction route, no bypass suggestion, inaccessible old cache, and a Retry that performs real work. Confirm service-unavailable/unknown access is not relabeled as a ban.
6. **Current-match boundary:** with the reviewed service, exercise pre-Go cancellation versus Go, same-account interruption return, and a result finalized while the checkpoint is open. Observe the same match, original clock and charge, explicit eligible forfeit only after confirmation, and no auto-open gallery. A physical capture round is required only for claims about the actual camera handoff; no derived fixture proves body/camera behavior.
7. **Native layout and input:** on iPhone exercise short/landscape/keyboard and largest text; on Mac exercise 800-by-600, laptop/full-screen/live resize, a second window, focus traversal, focused submission, native text editing, state-aware dismissal, and preserved commands. Check a real password manager where one is configured without recording secrets.
8. **Accessibility and energy/lifecycle:** use actual VoiceOver focus and status announcements, Reduce Motion/Transparency, and contrast settings on the changed surfaces. Background/inactivate/minimize while an operation is pending, then return; observe immediate shielding, no decorative work offscreen, no duplicate operation, and no camera reactivation. Use available native energy/inspection tools for this focused observation; do not claim a measured energy improvement without measurement.

Tests may cover a plausible stale-owner race, authorization transition, or recovery boundary. Do not permanently test labels/source text, copied defaults, forwarding, mock echoes, incidental animation numbers, bare not-throw behavior, or already-covered identical paths. Use disposable smoke scenarios for wiring and remove disposable scaffolding after actual proof. No test fixture or preview fake may become the production service path.

No screenshots, recording, device-proof bundle, or extended log package is required. Report concise exercised scenarios and exact limitations. Do not claim human acceptance, physical-camera behavior, configured-provider success, or energy measurements from compilation or an unrun plan.

## Human Verification Handoff — Required

In the final implementation response, list each meaningful implemented item separately:

- Thin native iPhone/macOS account checkpoint and shared-form reuse.
- Real restoration, expiry, provider, confirmation/recovery, restriction, and cleanup states.
- Owner-bound return decisions and intentional Continue/Close behavior.
- Immediate private-cache invalidation, cross-window/account isolation, and late-response protection.
- Real match/camera/lifecycle handoff without deadline, rating, gallery, or allowance side effects.
- Keyboard, focus, large text, accessibility, motion, transparency, and low-energy behavior.

List every changed file separately and ask the user to review the code changes. State that each implemented item is ready for human verification, not human-verified. Name known runtime/configuration/hardware limitations and any genuinely unresolved product decision plainly. Report only exercised checks. Shared foundations are intentionally unchanged unless a narrow necessary integration change was explicitly made and listed.

Mark implementation items only in CYCLES.md. Do not mark a human-review entry, whole F29 area, dependent feature, or public-release readiness complete from these checks. Accepted product changes belong in the smallest relevant plain-language DOCKS.md only after user approval; no test logs, code snippets, status checklist, or screenshots go there.

## Agent Rules — Mandatory

1. **Single owner; no nested agents.** Do this account-entry implementation yourself. Do not spawn reviewers, delegate repository work, or start media/model generation.
2. **Complete the connected slice.** Build against real reviewed contracts, run the changed native surface, fix clear reproducible failures, update permitted implementation status, provide the human handoff, and publish the scoped work. No stubs, dead actions, fake providers, disconnected view, mock-backed production fallback, or testing-only next handoff.
3. **User direction wins.** Both native iPhone and native macOS are required. A battle has a real timer, every public badge above two large vertical players at all widths. Do not follow older contradictory two-column/iPhone-only wording; surface genuine security/product conflicts rather than silently changing behavior.
4. **Reuse actual ownership.** Keep shared authentication, verified callbacks, password managers, service authority, native presentation, camera owner, existing theme, and app commands. No second router, account store, theme, auth worker, or generic abstraction added merely for this wrapper.
5. **Scope changes.** No unrelated code, workers' custom components, Profile/Settings redesign, exercise privacy changes, judge/model changes, new permissions/providers, or local-user data modification. Never delete user edits. Discover and re-read intervening changes before acting.
6. **Real data and privacy.** Use authorized actual account/service outcomes. No fabricated peers, Elo, badge unlocks, provider success, restriction result, cleanup success, or camera. No keys/tokens/passwords/body images in source, preferences, logs, prompts, or support output. Preview-only fixtures must be labeled and cannot substitute for production integration.
7. **Focused proof.** Exercise both changed native surfaces where runtimes exist and report unavailable proof honestly. Compilation and tests alone are not runtime proof. Never rerun a user-reported failure merely to dispute it; use that report as ground truth and check the corrected behavior.
8. **CYCLES only for implementation tracking.** Mark only the actual F29-A-b implementation items satisfied by connected code and focused checks, and keep human review pending. Do not create IDE todo JSON, checkboxes in product docs/prompts, duplicate dashboards, or evidence in DOCKS.md.
9. **Scoped commit and push.** After a complete scoped edit/work slice, inspect its result, create a clear commit, and push the implementation to origin/main using the repository's safe existing workflow. Do not force-push, rewrite history, include unrelated edits, or leave the work only local. Report exact commit/push blockers instead of claiming publication. This is a future implementation requirement; the documentation-batch worker does not run git.
10. **No pointless next prompt.** Finish small reachable integration, obvious fixes, focused checks, and publication now. Create another prompt only for a genuinely substantial separately authorized implementation slice, never just testing, cleanup, documentation, or commit/push. Do not generate dependent work before this slice's human review.
11. **Honest product documentation.** DOCKS.md is product context, not technical implementation authority or completion evidence. Preserve its accepted decisions, propose necessary behavior changes explicitly, and update accepted plain-language context at the smallest owner only after approval. No README/CHANGELOG creation or speculative promise of release approval.

## When You Finish

Report every implemented item and every changed file separately, the actual focused native/accessibility/lifecycle scenarios exercised, concrete blockers or limits, and the scoped publication result. Ask for human review of the code and each listed behavior. Do not call an unreviewed dependency accepted or this slice independently shippable.

End with a concise scope decision: what is connected and checked, what actually remains, whether any prerequisite is externally unavailable, and whether another substantial implementation prompt was needed. Do not invent a next prompt for the rest of F29 or imply completion of this future brief during the documentation-only design batch.
