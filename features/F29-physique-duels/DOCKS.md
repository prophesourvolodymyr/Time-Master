# F29 — Physique Duels

Physique Duels is a new, separately named page in Tmax for adult, one-versus-one physique comparisons using guided camera poses and AI image analysis. It is not another push-up, squat, plank, or workout-performance variation. It has its own earned Elo, matchmaking, standings, results, and history.

This product specification lives directly in the feature tree at the user's explicit request. The current request defines the complete native iPhone and macOS UI direction and dedicated specialist requirements; it does not authorize claiming an unbuilt interface or backend as complete. CYCLES.md owns implementation planning and human-review tracking. Nothing in this document grants App Store approval or claims measured judging accuracy, response time, accessibility, or animation performance.

## User-Directed Decisions

The feature is a new page in the existing native app. Its competitive Elo is separate from every existing exercise rating. An image-understanding AI, with GPT-6.1 Sol as the current starting candidate, compares the participants' poses. The complete experience includes UI states, capture, other scoring metrics, reporting, blocking, nudity moderation, privacy, and failure recovery. Adult men may participate shirtless in a nonsexual fitness context; the permission does not extend to unrestricted nudity or to other participants.

The user has additionally directed a highly animated but concise native UI: a top timer, all public user battle badges above the players, two large player panels stacked vertically, optional country-flag identity treatment, expressive backgrounds and icons, and animated final score counters. Both native iPhone and native macOS are required. The supplied screenshot establishes directness and hierarchy, not its horizontal player layout or permission to reuse its people. Detailed numerical competition rules, badge milestones, motion timings, media-sharing behavior, and operational limits remain explicit proposals or selected design details for human review; placement in features is not implementation acceptance.

## What We Build

- A dedicated Physique destination in the existing navigation catalog, with a lobby, rules, account access, independent rating summary, standings, match history, and safety access.
- A guided capture flow that obtains three matched poses from each participant, with local camera guidance and no unrestricted live video or voice connection between strangers.
- AI analysis of the six selected images in one paired judgement, followed by service-owned validation and finalization.
- Four clearly defined judgement categories: visible muscularity, definition, symmetry and balance, and pose presentation. Capture quality and moderation are eligibility checks, not bonus points.
- A physique-only Elo ladder. Neither the AI's numerical appearance score nor the player's existing exercise Elo is the physique rating.
- Private match details with the rubric breakdown, outcome, exact rating change, judging version, and limited, moderated still-image access for the two participants.
- Reporting of media, profiles, cheating, and unsafe generated explanations; blocking; human review; enforcement; and outcome disputes.
- Explicit consent for AI sharing and paired-opponent still-image access, minimal retention, account deletion, and honest provider-retention disclosures.
- Complete empty, loading, denied, offline, limited, interrupted, rejected, disputed, expired-media, and unavailable-service states.
- A complete battle identity and badge system with optional self-declared country/region flags, truthful earned milestones, all eligible public badges above the player panels, and no imitation of identity verification.
- A shared native UI component family for phase clocks, large vertical player panels, pose icons, battle atmosphere, final numeric counters, and Mac window/input behavior.
- A dedicated deep-design and connected-implementation brief for each custom view and complex component, with explicit model and maximum-reasoning assignments rather than a generic instruction to make the UI attractive.

There is no public body-photo feed, attractiveness voting, spectator gallery, open comments, direct messaging, wagering, cash prizes, or automatic publication of a participant's images. The page does not diagnose health, measure actual muscle mass, infer steroid use, or prescribe weight loss.

## Product Areas

| Area | Owner | Detailed product context |
| --- | --- | --- |
| Native page, capture, and full match journey | F29-A | [Page and match flow](F29-A-page-and-match-flow/DOCKS.md) |
| AI inputs, rubric, output meaning, and judgement limitations | F29-B | [AI judging and metrics](F29-B-ai-judging-and-metrics/DOCKS.md) |
| Independent Elo, matchmaking, standings, and records | F29-C | [Physique rating and matchmaking](F29-C-physique-rating-and-matchmaking/DOCKS.md) |
| Attire, nudity, moderation, reports, blocks, and appeals | F29-D | [Safety and reporting](F29-D-safety-and-reporting/DOCKS.md) |
| Permissions, data lifetime, service operation, cost, and latency | F29-E | [Privacy and service operation](F29-E-privacy-and-service-operation/DOCKS.md) |
| Public battle identity, country flags, badges, and complete top rails | F29-F | [Battle identity and badges](F29-F-battle-identity-and-badges/DOCKS.md) |
| Shared animated native components and Mac presentation | F29-G | [Native UI components](F29-G-native-ui-components/DOCKS.md) |

The parent owns shared decisions and terminology. Each child owns the complete behavior of its named area. F29-A's view contexts and F29-G's component contexts are independently assignable design-writing areas under a fixed shared contract, not independently releasable competitive features. Their implementation briefs preserve real service, privacy, safety, and human-review dependencies.

## Architecture and Existing-App Boundaries

The native page owns presentation, local camera previews, capture guidance, and consent. The trusted service owns identities, participation eligibility, accepted evidence, match timing, moderation decisions, rating changes, history, and access to private media. A managed model provider performs image analysis; a dedicated self-hosted GPU is not a launch requirement.

The existing Ranked account and authenticated Rust service are the intended identity and service foundation, subject to their human review and authorized public deployment. Physique data is a separate competition domain. Existing exercise rules, ratings, quotas, pose-vector evidence, and histories retain their current meaning.

The existing exercise camera flow explicitly promises that images and video remain on-device and that only timestamped joint estimates reach its service. Physique Duels must have a distinct image-sharing explanation and capture path. Adding this feature must not silently invalidate that promise for exercise duels or local Practice.

The user's general AI Coach provider selection and personal API keys do not control ranked judging. Both players receive one service-approved judging policy and model version for their match. A player cannot select a more favorable model, submit a different prompt, or edit an earned rating.

An independent Physique entry is added to the navigation catalog without overwriting a person's saved page order, restoring a Ranked page they deliberately removed, or resetting the selected page. A new-install default can place Physique next to Ranked. Existing installations expose it through the normal page-add flow. Profile may link to the physique-specific rating without adding a third side indicator, combining unlike ratings, or replacing the existing exercise destination.

## Shared Match Contract

### Eligibility and preparation

Entering rated participation requires a signed-in account, adult eligibility, accepted rules, the current AI-sharing and paired-opponent media consent, an available camera, an adequate preflight capture, an available physique allowance, and a healthy judging service. Other app features remain usable if the person declines this feature's consent or is not eligible. F29-E defines stage-specific withdrawal; future processing and image access always require the corresponding current authorization.

The age and attire declarations are private eligibility information. The AI must not infer age, sex, or gender from a body or face. The shirtless exception applies to a participant who declares that he is an adult man. Other participants wear an opaque athletic top or sports bra; everyone keeps the groin and buttocks covered by opaque sports clothing. No one needs to expose more skin to obtain a better score.

The proposed allowance follows the existing Ranked pattern but is independent: ten started physique duels in a rolling four-hour window per account across devices. One slot is reserved while pairing and consumed at Go. Cancellation before Go releases it. A service failure, an invalid capture, or a moderation-aborted no-contest restores the slot once. A deliberate confirmed forfeit consumes it. Abuse restrictions may prevent repeated invalid attempts without fabricating an Elo loss.

### Pairing and capture

Only real, eligible, nonblocked participants are paired. Search lasts up to ninety seconds. Each person sees the opponent's permitted public identity and physique rating, not their exercise Elo or private account details. Both explicitly become Ready; the service then starts a synchronized three-second countdown.

Each participant captures a front double-biceps pose, a side physique pose, and a rear double-biceps pose. The side pose is an ordinary fitness presentation, not a sexualized chest close-up. A pose uses one selected still image per person. There are at most two retakes for each pose within the shared ninety-second capture period. The app guides framing, stable positioning, and usable lighting; it does not request dangerous exertion, dehydration, or an uncomfortable pose.

The live camera is local. The opponent sees only stage and readiness information while capture is in progress. Candidate images can be sent to the protected service after consent as they become available. No opponent image is exposed until both sets pass the required checks and the match reaches a final result. A bystander or second body invalidates a capture rather than becoming an extra subject for analysis.

Every transmitted selected still or candidate has its face areas obscured locally first, with an exact preview of that treatment. Redaction failure stops that upload and allows recapture or cancellation; an unmasked original is not a fallback. Privacy masking is not cheating and does not guarantee anonymity. A second person remains a rejected capture even if their face could be masked.

### Judgement and finalization

The service submits the accepted pose set under one judging version. Proposed category weights are forty percent muscularity, thirty percent definition, twenty percent symmetry and balance, and ten percent pose presentation. Category scores and the weighted total use a zero-to-one-hundred scale. These are subjective, rubric-relative judgements, not physical measurements or probabilities.

Required category evidence must be adequate for both people. A covered chest or a nonsexual male bare chest is not itself a penalty or a bonus. The proposed common-region rubric excludes front-chest and abdominal definition for both participants, even when visible, and compares observable shoulder, upper-arm, upper-back, and leg evidence. This preserves one physique ladder without rewarding a shirtless participant for exposing anatomy that another participant must cover; it is a proposed fairness constraint, not proof of equal judging quality. Breast and nipple appearance, facial attractiveness, skin color, tattoos, clothing cost, and the amount of exposed skin are not judging criteria. A clothing-obscured region must not be imagined, scored as zero, or replaced with different category weights. Where the fixed rubric cannot support a fair comparison, the outcome is insufficient evidence rather than a forced winner.

A valid total-score difference below three points is a draw; a difference of three points or more determines the winner. This proposed tie band and the rubric require human calibration before ranked use. The service validates the category evidence and total rather than accepting a contradictory free-text winner. A missing category, refusal, contradictory result, or unsafe explanation cannot be treated as a successful rated verdict.

The five-second interval from the final pose submission to a displayed result is a user-experience target, not a measured latency or provider guarantee. At five seconds the page honestly explains that judging is still running. The proposed judgement deadline is thirty seconds after both final pose sets are received; an unfinished or invalid judgement becomes a no-contest. Neither a late model response nor a repeated client request can finalize the same match a second time.

### Leaving and recovery

Before Go, Cancel has no rating or allowance consequence. After Go and before finalization, an explicit confirmed Forfeit and leave creates a service-recorded forfeit only while the match is otherwise eligible for a rated outcome. A safety-aborted, invalid, or unavailable-service match takes precedence over a forfeit and remains a no-contest.

Block before Go cancels the pairing without a rating change. Block after Go immediately hides relevant media and prevents future pairings, but does not by itself finalize or abandon the match. Leaving still uses the explicit state-aware exit action; only a service-established safety or invalid-evidence abort has no-contest precedence. Reporting or blocking alone cannot manufacture a win or erase a valid loss.

An involuntary interruption stops capture immediately. The service may restore the same in-progress match within a twenty-second reconnect grace without resetting its shared deadline or adding another allowance charge. If valid participation cannot be restored, the match becomes a no-contest; repeated abandonment is an abuse signal, not evidence that the other physique was superior. Closing the result never changes an already final outcome.

### Results and media

A completed result contains the outcome, both eligible score breakdowns, each player's own before-and-after physique Elo, a neutral explanation, and a judging-version label. An actual forfeit has no invented physique scores. A no-contest has no Elo change and is not disguised as a draw.

After moderation and mutual prior consent, the two participants may intentionally open the six selected stills inside a valid AI-judged win, loss, or draw result. Forfeits and no-contests have no opponent-pose gallery, even if some candidates were captured. Images are not shown in a public leaderboard or auto-opened by a notification. The participant can report or hide an individual still without first enlarging it. The ordinary media window is twenty-four hours after finalization. Expired, removed, hidden, and reported media have explicit placeholders; the score and rating history do not require permanent image storage.

Sharing an image with an opponent can allow screenshots or external recording. The feature must not promise that another person is technically unable to copy what they can see. A shareable result card contains only the sharing person's own permitted identity and result, with no opponent pose image or unconsented private information.

## Metric Families

| Metric family | Meaning | Not interchangeable with |
| --- | --- | --- |
| Category and total scores | This pose set's rubric-relative visible physique judgement | Muscle mass, health, strength, or Elo |
| Physique Elo and tier | Earned relative competitive standing in Physique Duels | Push-up, squat, plank, overall local display levels, or a body score |
| Wins, losses, draws, and rated matches | Final service-owned competitive records | No-contests, practice, or merely started captures |
| Current and best rating, streak, and standings position | Physique-ladder progression and ranked placement | A permanent scientific assessment of the person's body |
| Capture validity, stage progress, and media availability | Operational evidence and lifecycle status | Reward points or a model's claimed confidence percentage |
| Allowance and next available slot | Independent account-wide physique participation entitlement | Exercise-family allowances or AI Coach balance |

A physique pose session does not automatically log a completed workout, calories, repetitions, training duration, or a HealthKit measurement. Any existing workout streak and schedule completion remain unaffected.

## States

| State | What the person sees | Core behavior |
| --- | --- | --- |
| First visit or unplaced | Named Physique page, separate rating identity, rules, and participation entry | No invented earned rating or standings position |
| Eligible lobby | Own physique rating, record, remaining allowance, recent matches, and Find opponent | Start only after real eligibility checks |
| Signed out or consent missing | The specific missing step and a conventional action | No upload, pairing, or consent-by-navigation |
| Age-ineligible or restricted | A private explanation and return to the rest of the app | No body analysis or public age disclosure |
| Loading or refreshing | Existing Tmax activity feedback and retained non-sensitive content | Stale records are labeled; no guessed availability |
| Empty history or standings | A meaningful empty message and relevant entry or retry | No example opponent, fake match, or fabricated rank |
| Camera denied or unusable | Camera-specific explanation, Settings or Retry when possible | No replacement with a prerecorded rated submission |
| Searching, ready, countdown, capture | Real stage, named pose, local guidance, and safe exit controls | No live stranger stream or premature opponent images |
| Uploading or judging | Real accepted-image progress and an indeterminate judgement state | No fake analysis percentage or guaranteed countdown |
| Won, lost, drawn, or forfeited | Accurate outcome, earned rating effect, and permitted details | No humiliating celebration at the opponent's expense |
| No-contest or capture rejected | A concrete private reason and any restored allowance | No fake category scores, winner, or rating update |
| Offline, interrupted, or provider unavailable | Recoverable state and server-authoritative finality | No local competitive result or silent second match |
| Reported, blocked, suspended, or under appeal | Protected media, private case status, and allowed actions | No retaliatory contact, public allegation, or automatic free win |
| Media expired or deleted | A clear unavailable-media placeholder | No regeneration, old signed-link access, or hidden restoration from backup |

F29-A specifies each screen's detailed layout, actions, focus behavior, transitions, and unusual states. F29-D and F29-E own safety and data-lifetime consequences across those screens.

## Visual and Emotional Direction

Use the app's existing native dark visual language, Inter typography, orange shared action styles, readable spacing, familiar headers, and original orange-and-ivory sports illustrations. The reference colors are the existing near-black background, dark elevated surfaces, white primary text, and toolbar orange; they are reused theme values, not an unrelated design system. Public native material fallbacks preserve current iOS and macOS compatibility.

The active battle reads from top to bottom as timer, the two clearly owner-grouped complete badge/identity rails, then a large You panel above a large Opponent panel. Players remain vertical at every Mac width. Secondary details may use a Mac inspector; they do not replace the requested vertical matchup with side-by-side people. Badge rows wrap without a hidden-count cap and never cover faces, limbs, or evidence. Short windows and large text can scroll the stage rather than reduce the players to tiny icons. Only authorized local camera or counterpart-media states appear.

Physique must feel like a clear sports comparison with private evidence and respectful feedback. It must not resemble a sexualized swipe feed or a humiliating body-rating game. Minimal text means concise task labels and deliberate details, not missing units, consent, error recovery, or safety consequences. A future interactive battle-to-results mockup can reduce composition and motion rework; it is optional, has not been created or accepted, and does not replace these requirements.

## Animation Rules

The app's existing press feedback, navigation, sheets, and loading indicators remain the base. Real pairing, readiness, countdown ticks, pose acceptance, final results, earned rating, and badge changes receive purposeful tactile motion. The timer keeps stable readable geometry; a quiet state-responsive background adds depth without moving capture framing. A successful final result has one coordinated counter and crest reveal, not four serial delays, a false live score, or an unconfirmed award. The full motion vocabulary and interruption behavior belong to F29-G and its children.

Reduce Motion removes scale, travel, count-up, and repeating decoration while preserving the same meaning. Reduce Transparency uses readable opaque surfaces. Inactive, minimized, background, low-power, and thermal states reduce decorative work as appropriate without pausing authoritative deadlines. Camera stop, privacy shielding, and media hiding are immediate. History, reconnection, and window changes do not replay an award. Both native platforms require their actual input, resizing, focus, availability, and energy behavior, not an iPhone-only animation pasted into a Mac window.

## Files and Ownership Boundaries

These are current integration surfaces or prospective feature-owned locations, not an instruction to follow an unverified implementation recipe.

- This directory and its child DOCKS.md files own the F29 product context in the feature tree.
- features/DOCKS.md registers F29; CYCLES.md contains the work and human-review plan.
- TimeMaster/Views/MainTabView.swift and the existing navigation catalog own page registration and destination routing.
- TimeMaster/Views/Ranked/ and TimeMaster/Services/Ranked/ supply existing account, shared interaction, and service patterns; exercise-specific privacy and competition behavior are preserved.
- TimeMaster/Views/Profile/ owns the existing profile entry and rating presentation boundaries.
- TimeMaster/Utilities/Theme.swift and TimeMaster/Utilities/ProfileDesign.swift own the shared palette and typography.
- Prospective TimeMaster/Views/Physique/, TimeMaster/Services/Physique/, and TimeMaster/Models/PhysiqueDuelModels.swift own the new page, capture, match, and physique-only records.
- ranked_server/src/ and ranked_server/schema.sql are the existing trusted-service and persistence integration surfaces. Physique adds distinct competition ownership rather than pretending to be a movement variation.

## Dependencies

Existing account/session behavior, native navigation, shared styling, and the authenticated Rust service are the intended foundations. Their pending human reviews in CYCLES.md must not be treated as automatically accepted. An authorized persistent HTTPS service, configured model access, protected media handling, and an operating human moderation channel are required before public rated participation.

F29-B depends on a valid, consented capture contract from F29-A. F29-C depends on validated results from F29-B. F29-D and F29-E constrain the entire journey, including what can be captured, submitted, displayed, retained, or rated. No child is permission to ship a competitive flow without the others.

F29-F depends on legitimate account presentation and service-owned competitive records, not editable local badge previews. F29-G depends on the same B/C/D/E invariants and supports all F29-A views on both native targets. New country and public badge fields require explicit disclosure and authorized identity handling; they are never image-judge inputs. Independent documentation work does not bypass these dependencies before production integration.

Existing F28 outdoor work is not a product dependency. Physique does not change route recording, workout playback, AI Coach, exercise quotas, or the user's saved navigation choices.

## Policy and Product Risks

Apple's prohibition on objectification of real people may still apply to a physique-versus-physique ladder. Consent, adult access, sport terminology, a shirtless-men exception, and moderation do not guarantee that Apple considers this acceptable. The prohibition on random or anonymous chat is another reason not to introduce an unrestricted live stranger stream. An App Review appointment is informational and cannot preapprove the feature.

The user-directed physique comparison is preserved here, not silently replaced by exercise performance. No numerical App Store approval probability is supportable. The feature remains a product decision with residual policy risk.

Visual judging is subjective and sensitive to capture conditions. Model marketing, a confidence field, a cheap token calculation, and a successful response do not establish fair ranking. Human comparisons, repeatability, player-order reversal, clothing coverage, skin tone, body type, device, and lighting differences determine whether the fixed rubric is suitable for competition. A judge that does not meet the agreed quality bar cannot silently award Elo.

## Reference

- [LarpGPT Battle](https://larpgpt.com/battle) is an interaction and paired-image-judging reference, not a direct licensed code import or proof of its private model provider. Its public experience is not an App Store policy precedent.
- [User-supplied battle screenshot](../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) supplies direct timer/player/badge hierarchy. The requested adaptation uses vertical players, the app's own styling, no premature opponent imagery, and no imported faces or footage.
- genesis/REFERENCE/APP IMAGE REFERENCE/push up tracker competition.png is an existing visual reference for a camera-based sports-duel HUD. Its mocking caption, unrestricted footage, and exercise score are not requirements for Physique Duels.
- [GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol) describes image input, structured output support, reasoning, and current pricing. It does not establish bodybuilding-judging accuracy.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) provide the relevant UGC, objectification, safety, capture-consent, privacy, deletion, and digital-purchase conditions.
- [Apple Privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy) and [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) inform resource requests, readable states, accessible controls, and reduced-motion behavior.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) informs native window resizing, menu/keyboard/pointer behavior, and readable desktop composition.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) informs optional, brief, purposeful, interruptible feedback rather than animation that blocks actions.
- [App Review appointments](https://developer.apple.com/help/app-review/before-submitting-for-review/app-review-appointment/) explain the limits of pre-submission guidance.
