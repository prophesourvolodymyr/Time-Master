# Phase 1 of F29-A-c — Native Eligibility and Consent

## Assigned Model and Execution Boundary

Requested worker model: **openai-codex/gpt-6.1-sol:max**. The model is openai-codex/gpt-6.1-sol; **max is the thinking level**. Use this exact assignment. Do not silently substitute another model or claim an unavailable assignment ran. This is the implementation worker's configuration, not the in-app physique judge, its reasoning setting, a provider choice, or permission to change a match's frozen model.

This is a future implementation brief written during a documentation-only design batch. It does not authorize app implementation now. Begin code only after explicit implementation authorization and the real shared foundations/contracts below are implemented and human-reviewed. A view is not independently shippable before that. Do not turn missing service, capture, legal-disclosure, or match contracts into mocks, a scaffold, new infrastructure invented in this UI slice, or a production fallback.

## Features Included

- **F29-A-c — Eligibility and consent:** one native initial-entry/reconsent form for private adult/attire choices, rules acceptance, separate sharing grants, decline, and real grant-state recovery. Ongoing management and withdrawal delegate to the canonical F29-A-w privacy owner.

No other new custom view is included. Inline native disclosures and standard system sheets/confirmations are parts of this surface, not a reason to create new product screens. Connect to the reviewed account, camera preparation, match exit, safety, and account-privacy destinations; do not replace their owners.

Each meaningful implementation item must be listed separately for human verification. CYCLES.md records implementation and review handoff only; no automated check or this prompt grants human approval.

## Context

Physique Duels requires informed, independently affirmative image-processing and opponent-sharing choices without breaking existing exercise privacy. The user requires native iPhone and native macOS, minimal but sufficient text, tactile motion, and always-vertical battle players. This slice connects one consent surface to real eligibility/policy/withdrawal and match authority.

## What You Need to Read First

Read these exact product-context paths before code:

- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-c-eligibility-and-consent/DOCKS.md — complete chosen composition, copy, platform behavior, states, transitions, and privacy invariants.
- features/F29-physique-duels/DOCKS.md — shared lifecycle, explicit user directions versus proposed defaults, separate competition, and policy risks.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — surrounding account, preparation, capture, stage, navigation, and exit ownership.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — accepted inputs, judge blindness, common-region evidence, and score limitations.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — eligibility, one active match, Go/cancellation race, allowance, and finality.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — private adult/attire declarations, no image-based trait inference, ineligibility/restriction/correction, bystanders, and safety access.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — distinct choices, complete actual recipient/retention disclosure, stage-specific withdrawal, access/deletion, processor changes, and failure states.
- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-w-privacy-and-sharing/DOCKS.md — the sole ongoing choice-management, withdrawal, image-removal, listing, and privacy-receipt owner; reuse its protective request mechanism.
- CYCLES.md — the current F29 implementation/review entries and the actual reviewed prerequisites; do not assume the documentation batch completed production work.

Read relevant installed skills before implementation. The shared UI Skills selection was **dimillian/swiftui-ui-patterns**; use its available native forms/navigation/sheet guidance without repeating a broad selection/setup exercise. Also read swiftui-pro, particularly accessibility and navigation, swiftui-animation for scoped/interruptible motion, and apple-hig-reference for live native guidance. Follow actual target availability rather than an installed skill's assumption of a new iOS 26-only application. If a selected skill is not installed or registered in the current execution environment, state that accurately and use the accessible relevant installed native guidance; do not claim the missing skill was read.

Inspect the supplied image:

- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — directness and hierarchy only, not its people, side-by-side layout, overlaid labels, purple/brown pills, text, or asset rights.

Read the supplied source anchors and the real connected callsites they identify:

- TimeMaster/Utilities/Theme.swift, lines 1–81 and 208–228 — 0A0A0A background, 141414/1C1C1C surfaces, FF6A00 action accent, existing controls.
- TimeMaster/Utilities/ProfileDesign.swift, lines 1–38 — scalable Inter typography, spacing, readable column, and iPhone interaction convention.
- TimeMaster/Utilities/TimeMasterGlassControls.swift, lines 20–80 — public material fallback, Reduce Transparency, and shared press response 0.24/damping 0.88.
- TimeMaster/Views/Ranked/RankedComponents.swift, lines 15–108 and 148–188 — nearby action and sports language; do not copy Dynamic Type clamps or imply fake earned/verified status.
- TimeMaster/Views/Ranked/RankedMatchPreparationView.swift, lines 8–74 — preserve the exercise path's actual joint-only privacy promise and native camera Settings/Retry patterns.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift, lines 25–151 — exercise HUD reference only, not live provisional physique scores.
- TimeMaster/Models/LocalProfileModels.swift, lines 23–27 and 99–109 — editable local cosmetic previews are not trusted competitive badges or adult/identity verification.
- TimeMaster/App/TmaxApp.swift, lines 8–19 — native Mac WindowGroup, normal title bar, existing 800-by-600 minimum.
- TimeMaster/App/TmaxCommands.swift, lines 6–37 — preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O.
- TimeMaster.xcodeproj/project.pbxproj — inspect the actual relevant target configuration; retain native macOS 14 and iPhone iOS 16 compatibility rather than raising targets for this view.

Find, then read the implemented Physique policy, eligibility, consent receipt/withdrawal, authenticated session, immediate capture stop/privacy cover, navigation, and active-match owners. They are prerequisites, not assumed files already present under prospective names. Follow discovered file paths; do not open guessed filenames or establish a second policy store. STYLES.md was absent during this design pass; reuse current source conventions rather than creating a global styles document.

Live native guidance to inspect selectively:

- https://developer.apple.com/design/human-interface-guidelines/privacy — Requesting permission; Pre-alert screens, windows, or views; Protecting data. This is separately declineable legal consent, not a counterfeit camera pre-alert.
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices for readable large displays, resize/full-screen, keyboard/pointer, and normal window integration.
- https://developer.apple.com/design/human-interface-guidelines/motion — Best practices and Providing feedback, especially brief, purposeful, optional, cancellable motion.

DOCKS.md is plain-language product context, not an implementation recipe. Validate technical choices through current source, skills, and platform availability. Never add source snippets, payloads, implementation recipes, project checkboxes, logs, screenshots, or verification records to a DOCKS.md.

## What Happened Last Session

The prior work was documentation only. The F29-A-c specification chose one vertically ordered eligibility/consent form for both native platforms, inline progressive disclosure, five distinguishable decision areas, explicit refusal, service-confirmed state, and independent immediate withdrawal actions. No Swift view, backend endpoint, consent persistence, native prototype, camera proof, generated artwork, build/test result, or human acceptance of an implementation was produced by that pass.

The shared visual decision requires a real timer above complete owner-grouped badge/identity rails and two large vertical players wherever a real battle composition exists. Initial consent deliberately contains no battle or fake countdown. Older F29-A side-by-side/wider-window wording is not the current user direction. The integrated documentation owner reconciles shared wording; this implementation must not reintroduce it.

## Prerequisites and Human-Review Boundaries

Before modifying app code, establish from current code and CYCLES.md that these are implemented, connected, and human-reviewed:

1. Real authenticated account/session and Physique navigation ownership, including account switch/sign-out clearing and ordinary app access after decline.
2. Trusted eligibility and restriction authority, including the current minimum adult requirement and a reviewed permitted correction/support route, without image-based age/sex/gender inference.
3. Current approved policy retrieval and versioning; actual operator/contact; model and safety processors; purposes; exact retention and region facts; real current-choice receipts; grant/withdrawal operations; account/match scope; and safe stale-version/concurrent-change handling.
4. Real camera setup ownership with deliberate system permission, immediate acquisition/transfer stop, fail-closed local face obscuring, protected app-switch/background behavior, and no prerecorded rated fallback.
5. The active-match owner: service Go boundary, real stage/deadlines, one account/one active match and camera owner across windows/devices, authoritative cancellation/recovery/finality, explicit forfeit confirmation, and ordinary allowance effects.
6. Working required privacy/safety destinations and operational constraints from F29-D/E. Do not create a dead “Contact” or “Delete account” button to simulate integration.

Unknown operator/processor facts are a missing prerequisite, not permission to enable a generic Accept screen. A not-yet-built consent backend is not a UI task to fake. If a prerequisite is absent or unreviewed, name the exact missing contract/review and finish reachable authorized nonproduction work only; do not call a mock-connected view implemented. Do not execute dependent implementation until those boundaries are met.

## Concrete Design Decisions and Tradeoffs

- **Single document, not a wizard.** One heading, brief overview, private adult/attire group, separate rules acceptance, separate AI/safety consent, separate opponent-sharing consent, then one primary action and a legible decline. Comparability and recoverability are worth vertical scrolling.
- **Critical facts stay visible.** Actual recipient names, material retention limits, what the opponent can view/when, copy risk, and refusal/forfeit consequences are not hidden to meet an arbitrary word count. Full details unfold inline in ordinary readable type; no forced-scroll acceptance or nested legal-screen chain.
- **No fabricated battle.** No timer, player image, badge rail, waiting opponent, rating reward, or ambient consent celebration on first entry. If a real battle is visible around a native inspection sheet, preserve its timer → all owner-grouped public badges → large You then Opponent vertical order at all widths. Do not put labels over bodies or shrink the players to fit a legal form.
- **Native platform adaptation.** iPhone uses safe-area-aware vertical groups and comfortable action targets. Mac uses a readable document column, native radio/checkbox density, normal titlebar/commands, keyboard/pointer, live resize, and an attached sheet only where a real active-match context needs it. No Catalyst, WebView, stretched phone panel, new app-wide minimum, or obligatory inspector.
- **Receipts, not optimistic consent.** A local affirmative selection is a draft until acknowledged for that account/current policy. Materially changed scope needs fresh affected permission; unchanged current acceptance remains visibly existing rather than silently regranted.
- **Privacy reductions are immediate.** Named separate withdrawal actions stop affected local use before animation or any exit confirmation. Remote uncertainty remains explicit. Opponent-only withdrawal after Go is not a forfeit; an intentional eligible exit still requires the real explicit forfeit confirmation.
- **Tactile, quiet reading.** Shared press feedback, direct selected-state feedback, short disclosure expansion, and one real receipt marker; no looping ambient animation, confetti, simulated progress, moral reward, or consent-driven streak threat.

These are chosen outcomes and tradeoffs, not a request for chain-of-thought or a new visual exploration. Do not redesign the whole app while implementing them.

## What to Build

### 1. Connect one real eligibility/consent surface

Create the grant/reconsent form in the existing feature architecture. Keep local draft, disclosure, and focus state only, and consume the reviewed account, policy, grant, capture, and match owners. F29-A-w owns ongoing management/withdrawal and can invoke this canonical form for a new grant or policy review. Do not create another privacy store, settings route, controller, generic form framework, or theme.

The entry heading is Before you pose, inspection/regrant is Sharing choices, and changed-policy review is Review sharing changes. The full management destination retains F29-A-w's Privacy & sharing title. Camera off describes this feature's real stopped acquisition only.

Show three poses, ninety-second capture, retake limit, separate Physique Elo, subjective score meaning, no extra-skin advantage, local live preview, locally obscured transmitted stills/candidates, and bystander invalidity in the short overview/rules hierarchy specified by the child context. No health/body-fat/muscle-mass/identity measurement claim or five-second guarantee appears.

### 2. Implement private adult and attire decisions

Start first use unanswered, not preselected. Display the actual minimum requirement, at least eighteen under the proposed launch policy, without jurisdiction inference from country flag, GPS, locale, IP, body, or face.

Use a native radio-like adult group with an affirmative declaration and “I don't meet it.” A negative draft produces the private ineligible state with clear return/rules access; it does not upload evidence, show body media, shame the person, or introduce a false loss. Service-established ineligibility/restriction is not removable by changing local selection. Use only the authorized correction/support route; no alternate-account advice or invented lockout/end date.

Keep attire choices vertical and unselected on first use: Athletic top, or Shirtless adult man with the explicit adult-man/nonsexual-fitness declaration. The latter requires adult eligibility; explain the disabled reason. An adult man may choose a top without disclosing another gender field. Explain opaque top/sports bra, lower coverage in all poses, and no exposure bonus. No model infers sex/gender or verifies the declaration from an image.

### 3. Keep rules and both sharing choices separate

Provide an initially unselected Physique-rules choice with readable actual consequences and a separate Read rules action. Opening/closing detail, scrolling, Return, navigation, or a timer must never select it.

Provide independent, initially unselected AI/safety and opponent-still-access legal choices. Do not merge them into a broad terms checkbox. Both are required for this proposed rated mode; refusal still leaves unrelated available Tmax features usable. No unannounced private-rated variant, local fake opponent, or local Elo workaround is introduced.

Before accepting AI/safety consent, visibly show actual operator/model/safety recipients, what each receives/why, material provider retention, app-versus-provider lifetime distinction, and relevant exceptions. The scoring judge sees clean accepted redacted pose evidence and neutral context, not public country/badges/handle/Elo, private declarations, UI screenshots, or personal provider preferences. Do not expose provider credentials or ask for a personal API key.

Before accepting opponent access, visibly show that only the matched participant may intentionally open three approved stills after a valid judged win/loss/draw, the twenty-four-hour window from finalization, no live/early/forfeit/no-contest gallery, current-access checks, and real screenshot/external-copy risk. Optional standings listing, result export, research, training, marketing, and body-photo publication are not bundled.

### 4. Provide full accessible detail without another custom screen

Use native inline disclosures for full rules, AI/retention details, and Who can see my poses. Make every trigger focusable and named. Expanded content uses body-sized wrapping text and selectable ordinary policy/contact information on Mac, not small image text or hover-only popovers.

Connect actual operator contact, existing privacy/image-removal/account-deletion, rules, and safety destinations. Preserve the draft while reading and return focus to the invoking control. Do not create placeholder routes or duplicate those products.

Full information must faithfully expose all relevant F29-E data families and their actual approved lifetimes, actual regions/cross-border arrangements, separate processor logs/application state/caches/files and safety-review exceptions, app ordinary media expiry, orphan/candidate disposal, bounded report/legal holds, nonmedia record/backup distinctions, external-copy limits, withdrawal and deletion consequences, and score subjectivity. Do not state that the app's twenty-four-hour image deletion erases provider logs or existing screenshots. Unknown material facts produce the real Sharing details unavailable state and block new consent, not template names or a generic promise.

### 5. Save and reconcile real account choices

“Continue to camera setup” saves the explicit current decisions and advances only after current-policy service acknowledgement. It does not start the camera, show the TCC/system camera prompt, queue, spend/reserve allowance, grant optional listing, or select a model. The next owner still requires deliberate camera setup.

Explain the next missing required group beside the disabled action; preserve all valid deliberate input. Saving has honest activity and duplicate-submit protection. A failed/timed-out/offline request says Choices not confirmed, preserves this account's valid draft/version, and reconciles actual receipt on Retry before assuming success or failure.

Render existing accepted choices as confirmed existing state with their actual scope/version. Changed recipients/purpose/region/retention require fresh affected permission, not blanket resetting of unrelated values or prechecked new scope. Show a short What changed summary and readable current/relevant prior terms. If policy changes while reading/saving, a late old-policy response must not enable new use. Do not silently hot-swap a match's frozen provider/rules or reauthorize past transfers.

### 6. Canonical withdrawal handoff and reconsent

Do not implement a second current-choice privacy-management screen or withdrawal engine. Route to reviewed F29-A-w Privacy and sharing, or reuse its canonical protective action where this form needs immediate withdrawal access. Protection begins before navigation/animation, the original request identity and stage are retained, and one owner supplies acknowledgement, uncertainty, retry and receipt. This form's withdrawal states reflect those real outcomes, not separate mutations.

Before Go, missing required permission cancels/prevents entry without Elo or consumed-slot loss, showing actual cancellation/reservation-release state. Respect the Go race: a Cancel accepted too late is not retrospectively a confirmed forfeit; show the true active state and explicit options.

After Go, AI withdrawal stops new collection but cannot promise to retract work already accepted by a processor. Do not locally choose no-contest, forfeit, or a winner. Opponent-only withdrawal revokes future ordinary access without itself cancelling, forfeiting, reversing rating, or revoking separately authorized AI. The real service retains eligibility and finality authority, including safety/evidence/service no-contest precedence.

An intentional exit from an otherwise eligible active match uses the shared explicit Forfeit and leave confirmation. Inspecting privacy/help, dismissing this sheet, withdrawing opponent access, Cmd-W ambiguity, or involuntary backgrounding is not that action. Already-final matches do not accept stale forfeit requests.

Reconsent permits only future authorized use and never restores removed galleries, resends historical images, resets expiry/deadlines, rerolls ratings, or reopens a final match. Same-policy regrant during a still-active match does not auto-start capture; the existing owner/service must authorize remaining participation under the same frozen policy/original deadlines. A newer withdrawal from another window/device wins over a stale local draft/late response.

### 7. Implement both native compositions and lifecycle boundaries

On iPhone retain the normal Physique navigation/safe content bounds, vertical rows, forty-four-point interaction convention, multi-line text, current floating-navigation clearance, and usable Return/Not now. Let the action area flow into scrolling when landscape/short screens/large type would otherwise leave no readable document. No fixed screen coordinates, hidden last paragraph, hardcoded bottom clearance, Dynamic Type clamp, or shrink-to-fit legal text.

On macOS use a centered readable document at 800 by 600 and larger, normal titlebar, native checkbox/radio density, visible focus, keyboard/pointer, live resize, large/full-screen/external-display behavior, and normal document-attached inspection sheets. Keep current choices, disclosure expansion, focus, and reading anchors stable while resizing or moving displays. Do not raise the app-wide minimum or create a new consent command menu/inspector. Return/Space act only on the focused semantic control; preserve existing commands and normal text selection/copy.

For active-match inspection, stop acquisition and shield sensitive content before showing the native sheet. Place the real stage/time context and safe exit at its top using the existing match owner. No duplicate clock or deadline reset. Any visible underlying stage retains the real timer, complete public owner-grouped badge rails, and two large vertical players without badge/body overlays or hidden earned badges. Do not recreate a scaled-down battle inside this form.

Handle Escape by the top presentation state, not a global exit handler. Cmd-W/quit use real stage-aware confirmation where supported; force quit cannot be prevented or called voluntary forfeit. Inactive/minimized/background/locked/user-switch states protect private declarations and stop previous camera ownership immediately; return reconciles account/policy/match before sensitive display or capture recovery. One camera/match owner across windows/devices remains intact.

Camera/TCC denial, restriction, unavailable hardware, and external/Continuity disconnect belong to real camera setup. Consent is neither a camera repair nor an OS permission. No camera access, fake preview, broad Photos/microphone/location request, or rated file-picker fallback is added here.

### 8. Implement accessible, interruptible, energy-aware feedback

Preserve native checkbox/radio/disclosure/button/link semantics and logical reading order. Keep required state and consequences programmatically associated with controls. On entry focus the heading; on requested validation/save failure focus the relevant error/group once; passive refresh does not steal reading focus. Return from disclosures/rules/confirmations restores the invoking control. Voice Control/Switch Control and keyboard reach every detail, decline, retry, withdrawal, and safe exit.

Use shared press response 0.24/damping 0.88 without duplicating native feedback. Selected-state/accent changes settle around 160 milliseconds with stationary labels; detail expansion is around 180 milliseconds; one service-confirmed marker can settle from at most about 1.04 scale within 180 milliseconds; feature-owned stage continuity is around 280 milliseconds. Native navigation/sheet timing remains platform-owned. Real active-match digits use the existing approximately 180-millisecond stable timer transition, not a new clock. Full status/actions are available immediately, not after animation completion.

Reduce Motion removes added scale/travel/repetition, using immediate state or at most a short 100-millisecond opacity change for disclosure content. Reduce Transparency uses opaque readable surfaces/privacy cover. Latest state interrupts prior motion; no replayed grant receipt, queued tick animation, consent celebration, ambient loop, humiliation, flashing, per-frame I/O/image decoding/camera rebuild/font measurement, or global invalidation. Offscreen/inactive/minimized/background surfaces suspend decorative work; low-power/serious thermal conditions remove added decoration while keeping truthful status, privacy protection, clocks, and controls. Announce receipts/errors/policy changes once, not every spinner/tick or interpolated marker.

## Prospective Files and Scope

Discover current files before editing. The intended new surface is:

- **Create:** TimeMaster/Views/Physique/PhysiqueEligibilityConsentView.swift — this view's platform-adapted document/sheet composition and local draft/disclosure/focus presentation only.

Modify only the discovered existing Physique entry/privacy route and reviewed state owner needed to present and connect this view. Reuse the already implemented service, policy, account, capture, and match contracts; do not duplicate them in new consent-specific models/stores. Any indispensable internal helper belongs to this owned surface under existing conventions, not a new unowned custom screen or generic framework.

- **Modify if required:** existing target membership for this actual new native file, preserving deployment targets.
- **Modify:** CYCLES.md, only the approved F29-A-c implementation and human-review handoff entries warranted by observed work.
- **Modify focused existing behavioral tests only if needed:** consumer-visible edge coverage for real consent/version/withdrawal behavior. A new permanent test is justified only by an uncertain plausible boundary, not a wiring/wording check.

Do not edit unrelated workers' surfaces, exercise camera/privacy semantics, Profile's two-side structure, public badge/catalog ownership, shared navigation order, global theme, account architecture, or server schema for convenience. Do not make a new README/CHANGELOG, global STYLES file, evidence document, TODO file, production mock backend, or generated athlete asset.

The child DOCKS is not an implementation ledger. New accepted product behavior belongs there only after human acceptance; current implementation/check facts and todos stay in CYCLES.md and the review handoff. If a prerequisite contract unexpectedly needs a substantial change, name its ownership/security/product impact rather than silently expanding this slice.

## Observable Acceptance — Both Platforms

These are future acceptance conditions, not statements that this design batch exercised them.

### Shared behavior

1. A real signed-in first entry displays a complete current approved disclosure and unselected new decisions. No image, camera session, TCC prompt, match reservation, public-listing grant, score, or badge is produced by opening or reading this view.
2. The current adult threshold and private attire rules are visible; ineligible/restricted states reveal no body media and offer real allowed return/correction paths without an appearance-derived age/gender verdict.
3. Rules, AI/safety, and opponent sharing are distinct semantic decisions. Reading a disclosure, pressing Return while reading, navigating back, or waiting never grants them. Either sharing refusal prevents this rated mode without blocking unrelated available app functionality.
4. Actual recipient names, material retention, app/provider distinction, when the opponent can view, twenty-four-hour origin, external-copy risk, and actual pre-/post-Go consequences are legible before grant. Full details and real contacts/privacy routes are reachable without a new custom screen or tiny footer.
5. Valid explicit input advances to camera setup only after the real service confirms the current account/policy. A timeout/offline/old-version response is not Accepted; retry restores/reconciles the same operation without duplicates or lost valid input.
6. A material policy change leaves affected new scope unselected and explains what changed. An unchanged current grant remains visibly existing; a late response cannot regrant withdrawn/newer-policy permission, apply to a different account, or swap an active frozen provider.
7. Both withdrawal actions protect locally immediately and report real remote receipt/uncertainty. Before-Go cancellation has the real no-loss boundary. After-Go opponent-only withdrawal leaves separately authorized AI and real match finality intact; no automatic forfeit/no-contest/Elo update is invented.
8. An intentional eligible post-Go exit requires the actual explicit forfeit confirmation, including a Go race and an already-final result. Privacy help, dismissal, inactive state, force quit, or ordinary consent draft closure never impersonates that confirmation.
9. Reacceptance does not reopen historical images/results or reset deadlines/expiry. Account switch, newer remote withdrawal, sign-out, and background restoration never leak private prior-account declarations or restore a stale grant.
10. Selection/failure/changed/withdrawn states have text and native semantics independent of color, animation, sound, haptics, or hover. Reduced/energy behavior leaves all information, safe actions, and protection available immediately.

### iPhone surface

- Short/standard/tall iPhone layouts, portrait/landscape, largest supported accessibility text, and either app navigation edge remain readable, vertically scrolling, and actionable without clipped recipient/retention/consequence text or a footer covering the final paragraph.
- VoiceOver and Switch Control can choose, inspect detail, decline, submit/recover, and withdraw with stable logical focus. The primary action and clear Not now/Return remain operable at the existing forty-four-point convention.
- An actual active-match inspection stops/shields capture first, preserves the real remaining time and safe exit, and returns through the same authorized recovery path without automatic camera startup or deadline reset.

### Native Mac surface

- Launch the actual native Mac target at the current 800-by-600 minimum, normal laptop size, large/full-screen/external display, and live resize. The document uses readable width/native density with all decisions and actions reachable; it is not a phone form scaled across a display.
- Tab/Shift-Tab, native checkbox/radio interaction, focused Return/Space, text selection/copy, pointer, visible focus, and state-aware Escape work. Existing Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O retain their meaning.
- Attached active-match sheets retain real time/exit context and do not duplicate/shrink/reorient the stage. Wherever battle remains present, timer → all owner-grouped public badges → large vertical You/Opponent is preserved at every width.
- Cmd-W/quit, inactive/minimized/locked/user-switch, multiple windows, and second-device current-state updates follow the real ownership/privacy contract. No second camera/session/charge or stale cross-window grant appears. Forced termination is not claimed preventable or voluntary forfeit.
- TCC denial/restriction, missing camera, and external/Continuity disconnection remain honest camera-owner states after deliberate setup, independent of legal choices. No prerecorded rated substitute or extra permission request appears.

## Focused Checks and Actual Native Smoke

Use the smallest relevant existing build/test path after prerequisites and implementation are real. Fix clear local compile/runtime/integration failures found in this slice. Do not rerun a user-reported failure merely to confirm their observation. Do not equate compilation or a mocked service echo with working consent.

Run the changed native surface on iPhone and native Mac where runtimes exist. Exercise actual reviewed nonproduction services/accounts with no sensitive participant-image upload needed for basic consent checks. Use real current policy/receipts rather than a production fixture route. Never recruit an ineligible person or use another person's body image to test a restriction.

Focused scenarios:

1. Fresh account decisions: inspect all disclosures, decline, return, then make explicit permitted choices and observe the actual current service receipt and transition to camera setup without camera activation/pairing.
2. Recovery boundary: disconnect during a real choice save, observe Not confirmed and retained draft, reconnect/retry, and observe authoritative reconciliation. Exercise a real service-supported stale-policy conflict and a newer withdrawal so an old response cannot unlock use. If the approved environment cannot safely produce a live policy update, name that unexercised boundary and use existing behavior-level test support without creating a mutable production policy switch.
3. Stage distinction: with two authenticated consenting adults and the reviewed match owner, exercise a before-Go withdrawal/cancel, a Go-race recovery when supported, post-Go opponent-only withdrawal, processing withdrawal, and separate explicit exit. Observe immediate local stop/shield, real request status, unchanged deadlines, and real finality/allowance consequences. Do not invent those states with a view-only flag.
4. Privacy lifecycle: background/lock on iPhone; deactivate/minimize/close/reopen and switch windows on Mac; inspect a later withdrawal on another authorized window/device. Observe protected private content and current service restoration without stale drafts or a second camera owner.
5. Accessibility/layout: largest supported iPhone text, VoiceOver, Switch Control or available equivalent, native Mac keyboard/VoiceOver, narrow/short/live-resized/full-screen/external-display layouts, increased contrast, Reduce Transparency, and Reduce Motion. Check actual focus return, complete facts, readable footer, and no global Return acceptance.
6. Energy/interruption: observe this surface while idle, details expanded, saving, and receiving an acknowledgement; then inactive/minimized/background and low-power/available thermal constraints. Confirm no ambient loop or continued decorative work, no camera/per-frame service activity from this view, and immediate protection despite interrupted animations. Do not claim measured energy/frame-rate behavior from source inspection alone.
7. Camera boundary: after deliberate next-step camera setup, exercise available iPhone permission denial and native Mac TCC denial plus real external/Continuity disconnect where hardware exists. Observe the real camera-owner explanation without altering legal consent or introducing file upload.

Use existing focused behavior tests for uncertain stale-version/newer-withdrawal/account-switch/Go-boundary cases where appropriate. Keep permanent tests isolated, deterministic, and consumer-visible. Do not add tests that assert exact copy/source text, forward mock calls, count view children, pin incidental defaults, or merely prove a method does not throw. Throwaway smoke scaffolds are removed before delivery, not shipped as fixtures or a substitute service.

State precisely which platforms/scenarios were exercised. If a runtime, two-adult service environment, hardware camera, external/Continuity device, controlled policy transition, or low-power scenario is unavailable, identify that missing proof honestly and finish all reachable authorized work. No screenshot package is required, and visual/camera completion cannot be claimed from builds alone.

## Human Verification Handoff — Required

List every meaningful implemented item separately:

- Private adult/attire and ineligible/restriction presentation.
- Separate rules/AI/opponent decisions and complete recipient/retention/copy-risk disclosures.
- Real service-confirmed save, policy changes, concurrent-state reconciliation, decline and recovery.
- Immediate independent withdrawal and correct pre-/post-Go consequences.
- Native iPhone composition, input, focus, accessibility, and lifecycle.
- Native macOS composition, resize/window/keyboard/camera boundaries.
- Motion, reduced/energy behavior, and any justified behavioral regression coverage.

List every changed file separately with its concrete role. Ask the user to review the code changes and state that each implemented item is ready for human verification, not human-verified. Report only observed focused checks/native smoke; name all missing proof, external prerequisites, deviations, and unresolved product/security decisions plainly. No completion/evidence record goes into DOCKS.md. No screenshots, recordings, or logs package is required.

After the user accepts the resulting behavior, update the smallest relevant product DOCKS with accepted plain-language decisions only. Do not archive this area, mark human review complete, or connect unreviewed dependent work because automated checks passed.

## Agent Rules — Mandatory

1. **Single owner, no nested agents.** Do all work for this slice yourself. Do not spawn review/research/implementation subagents or change another worker's owned surface.
2. **Exact requested model.** Use openai-codex/gpt-6.1-sol with thinking max; no silent fallback. Never confuse the worker assignment with the in-app judge.
3. **Real prerequisites and data.** Code starts only after the listed reviewed foundations/contracts. No invented operator/retention fact, client-authoritative eligibility/finality, fake peers/scores/badges, fixture-backed production consent, no-op route, secret client key, or mock completion.
4. **Current user direction wins.** Native iPhone and native macOS are both required. Wherever a battle exists, real timer first, all public owner-grouped badges next, then two large vertical players. Older side-by-side/stretched-desktop wording cannot override this. Do not infer acceptance of every numerical proposal.
5. **No unrelated changes.** Reuse established source/theme/control/service patterns. Preserve exercise privacy, saved navigation, Profile shape, existing commands, deployment targets, and trusted service ownership. Do not add new screens, global abstractions, validation regimes, telemetry, research collection, or assets outside this slice.
6. **Focused actual verification.** Run the changed native surface and observe behavior on both supported platforms where runtimes exist. Tests/compilation alone are not proof. Fix clear failures; label unavailable physical-camera/service/energy proof without fabricating output or reducing scope silently.
7. **Update only CYCLES implementation todos.** Keep approved F29-A-c implementation/handoff status honest; an implementation checkmark is not human verification. No duplicate IDE tasks, completion checkboxes, screenshots, logs, or implementation evidence in feature DOCKS.
8. **Scoped commit and push.** After a complete checked implementation slice, inspect the result, stage only authorized owned changes including the relevant CYCLES entries, create a clear commit, and push to origin/main before yielding. Do not stage unrelated user/coordinator edits, force-push, rewrite history, or claim publication if it fails. This rule applies to the future authorized implementation, not the earlier documentation-only worker batch.
9. **Complete the reachable slice.** No placeholders, scaffold handoff, fake local fallbacks, or testing-only next prompt. Finish code, real integration, focused checks, failures, review handoff, and scoped publication in one complete authorized work slice. If a real outside prerequisite is missing, identify exactly what is missing and what was tried; do not pretend a view has shipped.
10. **No pointless next prompt.** Generate another prompt only for a genuinely substantial independently owned remaining implementation slice with reviewed dependencies. Testing, a commit, a documentation checkbox, obvious fixes, or missing physical-camera proof alone do not justify a separate implementation prompt.

## When You Finish

Return each implemented item and changed file separately for human review, concise exercised verification, actual limitations/conflicts, the scoped commit/push result, and whether any next prompt was needed. State explicitly that human verification remains pending. Do not claim an accepted design prototype, deployed privacy system, judged-match correctness, App Store approval, or camera/platform validation that was not observed.

## Scope Decision Before Finish

Report the completed connected behavior, any real remaining work, and the concrete decision: no next prompt, a substantial next implementation prompt, or an exact external/review blocker. Do not narrate model/session budgets or use a phase boundary as a reason to stop while actionable owned work remains.
