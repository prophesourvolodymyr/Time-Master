# F29-A — Physique Page and Match Flow

This area owns the new native Physique page and every participant-facing step from browsing rules to capturing poses, receiving a result, reporting content, and returning to the app. The [parent specification](../DOCKS.md) owns the shared product contract. The user requested this specification directly in features. Detailed choices remain proposed defaults for review, not an accepted mockup or implemented screen.

## What We Build

A real page, not a renamed exercise selection, opens from the existing navigation catalog and has its own preserved navigation state. Its lobby presents the person's physique-only competitive identity, meaningful metrics, recent matches, rules, and Find opponent. The rated journey continues through consent, camera setup, matchmaking, readiness, a synchronized countdown, three guided poses, uploading and judging, and a final result.

A local illustrated Pose guide explains the three poses without uploading images, awarding scores, inventing a practice opponent, or changing Elo. This is not a second unrequested cloud-analysis mode. Browsing the page and reading rules must not turn on the camera or submit personal data.

The app's normal page catalog, saved page order, top-or-bottom navigation placement, and current selected destination remain intact. Adding Physique must not automatically reinsert a Ranked page the person previously removed. Physique is offered through the usual Add page control; new installations may include it beside Ranked.

## View Hierarchy and Composition

### Lobby

The page uses the existing near-black background, dark elevated surfaces, white primary text, toolbar orange, Inter headings and body fonts, shared button shapes, shared loading feedback, and measured expanding-header behavior. Theme values are the existing background 0A0A0A, surfaces 141414 and 1C1C1C, and toolbar accent FF6A00. They identify the current app language rather than introduce another palette.

The expanded header says Physique, with a small Physique Duels subtitle when space permits. Header actions open Rules and Account. The compact header retains the page name and accessible actions rather than collapsing into unexplained symbols. Scrolling follows the same title-growth and action-collapse behavior as other main pages.

Below the header, the person's account handle, earned Elo, and placed physique tier when available form one clear competitive identity. A visible Physique Elo label prevents confusion with an exercise rating. A person without a completed rated result sees Unplaced, not a public 1,000-point award. Provisional progress remains next to an actual earned rating after the first eligible result; an assigned tier and public standing wait until placement is complete.

A restrained sport illustration or abstract physique silhouette can support the identity, but never replaces the rating or turns the page into a carousel of strangers' bodies. The initial design reuses the current Ranked page's readable sports hierarchy, not its sixty-second exercise timer or movement loadout.

The metric area contains current Elo, peak Elo, and wins, losses, and draws. Win rate and streak appear in the expanded record section rather than crowding the main action. Every value has a short visible label and an accessible full meaning. Unknown data uses a dash or Unavailable; a real zero remains zero. No sample standings or fabricated opponents fill an empty account.

The primary action is Find opponent. Immediately above it, a compact allowance line states the remaining physique matches and the next slot's availability. The line explicitly belongs to Physique, not push-ups or squats. Beneath or alongside it, clearly labeled secondary actions open Pose guide, History, Leaderboard, and Safety. A single short notice explains that AI judges visible physique presentation and that images require consent; the full rules remain one action away.

Recent matches use concise rows showing the opponent's permitted display name, date, outcome, and this person's physique Elo change. A no-contest row states No rating change. A forfeit row does not display invented category scores. A row opens its exact saved match, not a new session or a generic results placeholder.

### Setup and eligibility

Find opponent resolves the missing participation requirement before progressing. A signed-out person receives the existing conventional account flow with persistent labels, password-manager support, keyboard submission, and real sign-in errors. The feature does not present unimplemented Apple or Google sign-in as working choices.

The entry explanation gives the adult-only rule, the permitted clothing rule, the three poses, the image-sharing policy, and the subjective nature of the scores. It also explains the proposed common-region rubric: shoulder, upper-arm, upper-back, and leg evidence, with front-chest and abdominal definition excluded for both participants. Extra visible skin is not a scoring advantage, and covered anatomy is not guessed. The person can read the complete rules without losing the entry's state.

The private attire choice is Athletic top or Shirtless adult man. The second choice includes the explicit adult-man declaration and the nonsexual fitness restriction. Other participants use an opaque athletic top or sports bra. All participants keep the groin and buttocks covered by opaque sports clothing. The choice is not shown on the leaderboard and is not sent as a ranking signal to the judge. It is not an invitation to submit identity documents or let an AI decide someone's gender.

Separate, clearly worded consent choices cover hosted AI processing and access to the selected moderated stills by the paired opponent after the result. Neither is preselected. Required consent must be affirmative before joining a rated match, but declining leaves the rest of the app available. The provider, purpose, image lifetime, and screenshot risk appear before permission is granted. A future research or training permission is not bundled into the launch screen.

The camera resource request is distinct from the data-sharing consent. The standard system prompt appears only after the person's explicit camera setup action. An explanatory legal-consent screen is not a fake operating-system permission alert. No microphone, broad Photos access, location, Contacts, or HealthKit request is part of this journey.

### Camera preparation

The local preview is the largest element. It is portrait-oriented on iPhone with the person's relevant body and poses visible; controls occupy safe edges, not the shoulders, waist, or feet the camera needs to assess. The preview can be mirrored for self-positioning, but the selected evidence has a consistent orientation and never silently exchanges left and right.

A named framing cue, a simple outline, and a short text instruction explain what needs adjustment: move the camera, include the required limbs, improve ordinary lighting, remain still, remove another person from view, or change clothing. The cue is not a medical assessment or a live muscle score. Text, symbols, and optional haptics accompany color changes.

Face areas are obscured locally by default before any selected still leaves the device. The preview of the selected image shows the exact masking that will be sent. This is ordinary privacy treatment, not cheating or an appearance penalty. If required redaction cannot be applied, that image is not uploaded; the person can recapture or cancel. Masking a face does not guarantee anonymity and does not make a second person's capture acceptable.

Camera switching is available in setup. A selected camera and framing remain stable for the complete rated pose set. Switching after Go requires discarding that person's selected set and restarting capture inside the original ninety-second deadline; it does not restart the match clock or reveal the opponent's images. If that cannot be completed, the result is a no-contest.

The page shows the camera's current privacy/activity state and a persistent Stop or Close control. It never activates capture in the background. Camera denied, restricted, missing, unavailable, and interrupted are separate explanations, with Open Settings or Retry offered only when those actions can help. A simulator or unsupported device does not receive a fake camera feed or a rated upload-from-library fallback.

Once preflight is adequate, Continue starts a real search. The app may keep local framing guidance available during search but does not take evidence before Go. Clear exit controls remain available. The person can read clothing guidance without having to capture a revealing image first.

## End-to-End Journey

### Search

The search screen shows the person's physique rating, the current skill-search range in plain language, honest activity feedback, and the ninety-second maximum search duration. It does not show a predicted opponent, a fabricated queue length, or an estimated wait without real data. Cancel confirms cancellation with the service and releases the reservation; stale service state shows Cancelling rather than pretending the request has finished.

No available opponent becomes No opponent found, with Try again and Return. It does not become an AI opponent or an unrequested exercise match. Losing the network stops queue eligibility or shows recovery according to the authoritative match state.

### Opponent and readiness

A real pairing displays the two permitted public identities, their Physique Elo or provisional status, readiness, and the pose protocol. The opponent's account email, age, attire declaration, exercise ratings, and private profile fields are never revealed. A privacy-safe silhouette is used when no permitted avatar exists; a local profile photo is not silently uploaded as a public avatar.

Ready is an explicit action available only while the camera and required permissions remain valid. The person can inspect the opponent's limited public competitive record, report an identity, or block before Go. Blocking releases the match without rating change. When both are ready, the service establishes the shared start and the screen shows 3, 2, 1, then Go.

Before Go, an exit is Cancel match and has no rating or allowance consequence. A ready state is not permanent consent to capture after the person withdraws, signs out, backgrounds the app, or loses camera access.

### Pose capture

The capture screen identifies the current pose, the shared time remaining, and three compact pose slots. The local preview remains primary. The opponent is represented by an accepted-pose count and readiness, not live footage or a live appearance score.

The order is front double-biceps, side physique, then rear double-biceps. Each pose has an illustrated neutral guide and one short instruction. The side guide avoids sexualized chest or breast framing. The person is never instructed to expose prohibited regions, exert to exhaustion, hold their breath, dehydrate, or continue through pain.

An accessible Capture control can use a three-second self-timer so the person can move safely into position. An optional sound cue or spoken pose name is output only and needs no microphone access. The silent flow remains complete through text and haptics. A stability cue describes framing readiness but does not award a body score.

After a capture, a small exact selected-image preview shows the private face mask and current status: Selected, Checking, Accepted, or Needs retake. Selected is not mislabeled as moderation acceptance. The person may continue through the pose guide while a selected image is being checked; a later rejection points back to the affected slot. Both the selected count and the accepted count stay honest.

Each pose permits at most two retakes. Retaking replaces that pose's selected still and invalidates its earlier acceptance; a stale check cannot reapprove an old version. Retakes do not restart the ninety-second shared capture deadline. No model feedback or opponent still is shown to help cherry-pick a more favorable submission.

When three valid selected poses are complete, Submit poses locks that person's set. Editing after submission is unavailable unless the service requests a specific recoverable recapture within the same capture period and before paired judgement. The other participant sees only that the person has submitted. A completed participant can wait safely without maintaining a strenuous pose.

No incoming opponent pose image is visible during capture. A screenshot of the local preview belongs to the person taking it, but the app does not save a body image to Photos automatically or pretend to prevent operating-system screenshots.

### Uploading and checks

Candidate images may transfer during capture after consent, reducing the work remaining after the final pose. The page displays actual image counts or real transfer progress. It does not estimate AI analysis as a percentage. Upload completion, moderation acceptance, and judging are separate states.

If a transfer is interrupted, the page explains whether the same submission can resume before its deadline. Retrying an accepted image does not add another pose, opponent, allowance charge, or match. A failure requiring the original camera set is not repaired by taking an unrelated photo outside the match.

A rejected capture shows a private reason and the affected pose. The other participant gets a neutral match-status message, not an accusation or a preview of rejected content. If the set cannot become eligible in time, both receive a no-contest and the allowance is restored once, subject to the feature's abuse policy.

### Judging

After both final sets have reached the service and passed the required eligibility checks, the page shows Judging physiques with the real named stage and the existing Tmax indicator. The model can take more or less time than expected; no fake five-second countdown is displayed.

The product target is a result within five seconds after the last pose submission, including the remaining transfer, checks, model work, and finalization. This is not a measured promise. At five seconds the message becomes Still judging, with no change to the actual verdict or invented progress. At the thirty-second judgement deadline measured from receipt of both final sets, an unfinished or invalid judgement becomes a no-contest.

Leaving the visual waiting screen does not issue another judgement or discard an already accepted service result. The page can show a compact pending-match entry and restore the same match later. It does not imply that an Elo result exists until the service finalizes it. A notification, if separately permitted, is generic and contains no body photo, opponent information, score, or sensitive explanation.

### Results

The final screen opens with Won, Lost, Draw, Forfeit, or No contest as a clear text outcome. An outcome is not conveyed by orange or red alone. Both participants receive the same final result from the service.

For a judged match, the next section shows both weighted totals and the four named category rows. Each row has its unit, meaning, and neutral supporting explanation. Invalid or unobservable evidence never becomes a zero score. A short notice says these are AI judgements of the submitted pose set, not measurements of health or actual muscle mass.

The person's own Physique Elo before, signed change, after, placed tier when available, and provisional progress follow the outcome. The opponent's permitted match-time rating and placement state identify the pairing context; a later public current rating belongs to a separately permitted profile or standings view, not a rewritten historical comparison. The person cannot browse private rating transactions or other private account data. The AI score is not animated into the Elo number and cannot be edited.

A forfeit identifies the actual competitive outcome and allowed rating effect without invented category totals. A no-contest states No Elo change, gives the appropriate private reason, and shows the allowance restoration when confirmed. A draw may change Elo between unequal-rated opponents; No contest and Draw are not interchangeable labels.

Close returns to the same Physique lobby and refreshes its actual rating, allowance, and history. Find another opponent starts a new eligibility check rather than silently queueing or charging another slot. There is no automatic rematch or request channel to an unwilling opponent.

### Selected-image details

View poses is an intentional action inside a valid AI-judged win, loss, or draw result with the required prior consent. Forfeits and no-contests have no opponent-pose gallery. The viewer does not auto-expand after a win or arrive in a notification. Each player's front, side, and back image is clearly labeled and remains attached to the same pose position. Side-by-side comparison collapses into stacked, consistently scaled sections at large text or narrow width.

Only moderated selected stills from that finalized match can appear. The viewer does not expose live footage, rejected attempts, retakes, background recordings, other matches, or arbitrary library photos. It shows that images expire twenty-four hours after finalization.

Each image has Report and Hide controls available before enlargement. Hide immediately replaces that image with a neutral placeholder. A reported or removed image is not unblurred because a person revisits a history row. A deleted or expired image shows its actual reason and cannot be regenerated from a prompt or fetched through a previously copied link.

Any sharing control creates a result card from the sharing person's own permitted identity and competitive result. It does not include the opponent's pose, private fields, or a humiliating comparison caption. There is no public body-score posting action in this feature.

### Reporting, blocking, and disputes

Safety is reachable from the lobby, opponent identity, match overflow, image tile, result explanation, and saved history. Report routes to the contextual item rather than requiring the person to describe where they found it. Clothing guidance explicitly distinguishes permitted nonsexual shirtless adult men from prohibited nudity; an ordinary male torso is not auto-convicted by a report.

The report sheet names the item, offers relevant categories and an optional note, explains the evidence and retention effect, and offers Report and an independent Block option. It never requires the person to enlarge suspected nudity or upload another revealing proof photo. An optional note uses a persistent label, grows with text, and stays above the keyboard without hiding Submit or Cancel.

Submitting displays a real sending state. Only service acknowledgement becomes Report received and opens private case status. Offline or failed submission stays Not sent, with Retry and the immediate local Hide and Block protection still available. Duplicate taps cannot create multiple apparent cases. Closing an unsent form warns only if the person would lose a meaningful draft; closing a sent report does not withdraw it.

A score disagreement uses Request scoring review, not Nudity or Abuse as a shortcut to a free win. The result identifies the twenty-four-hour image-review window. Safety reporting remains available after media expires, with an honest statement that a visual review may no longer have the original image. Human review and account consequences follow [F29-D](../F29-D-safety-and-reporting/DOCKS.md); the page does not display a promised reversal or response until one exists.

Blocking immediately hides the relevant local media and prevents new pairings. Before Go it cancels the pairing without a rating change. After Go it does not by itself end the match or change Elo; leaving uses the explicit confirmed exit action, while a service-established safety or invalid-evidence abort takes no-contest precedence. If a match is already final, blocking alone does not reverse its result. An unblock action lives in the Safety area, does not restore hidden body photos automatically, and does not contact the other person.

## State Matrix

| State | Visible content and actions | Transition and data consequence |
| --- | --- | --- |
| Initial visit | Lobby explanation, Unplaced, Pose guide, Rules, participation entry | No automatic camera, upload, or invented rank |
| Signed out | Existing sign-in or account creation with clear labels | Return to the same intended Physique action after real authentication |
| Restoring session | Account restoration indicator; no previous account's private data | Continue only after authoritative identity is known |
| Adult eligibility missing | Private age declaration and rule explanation | No image capture or analysis until eligible |
| Age-ineligible | Private unavailable notice, Rules, return to other pages | No attempt to guess age from the camera |
| Consent missing or changed | Current provider, data use, image access and retention choices | No new upload until affirmative consent; decline preserves unrelated app use |
| Account suspended | Scope, duration when known, safety appeal action | No search or alternate-account bypass suggestion |
| Lobby refresh | Retained labeled cached metrics and compact loading feedback | No duplicate history or assumed allowance |
| Empty history | No physique duels yet, Pose guide, eligible Find opponent | No sample opponents or pretend results |
| Offline lobby | Last-updated label, readable cached non-sensitive records, Retry | Find opponent unavailable; no local rating award |
| Service or judge unavailable | Specific temporary unavailability and Retry later | No slot charged for an unavailable search |
| Allowance unavailable | Remaining zero, actual next-slot time, explanatory action | No exercise quota substitution or hidden paid retry |
| Camera not requested | Local setup explanation and explicit camera action | System prompt only after action |
| Camera denied or restricted | Correct permission reason and available Settings action | No repeatedly triggered system prompt or forced full Photos access |
| Camera absent or interrupted | Retry or return, privacy-safe preview placeholder | No fake preview or rated prerecorded input |
| Poor framing or light | Concrete named adjustment and non-color cue | Start or capture blocked only for the actual evidence defect |
| Redaction unavailable | No selected upload, recapture or cancel | Never send an unmasked original as fallback |
| Second person detected | Private explanation to recapture alone | No assumption that blurring a bystander solves consent |
| Searching | Real queue stage, own Physique rating, Cancel | Ninety-second expiry and no sample opponent |
| Cancelling search | Cancelling and disabled repeat action | Return after authoritative cancellation or restoration of an existing pairing |
| No opponent | No opponent found, Try again, Return | No rating or allowance loss |
| Opponent found | Two permitted identities, actual physique ratings, Ready | Readiness tied to current camera, consent, and account |
| Countdown | Shared 3, 2, 1 and Go with accessible cues | One allowance consumption at Go, not at every screen transition |
| Capturing | Local preview, named pose, three slots, real deadline, capture/retake controls | At most two retakes per pose within the unchanged capture deadline |
| Selected image checking | Exact private thumbnail and honest selected/accepted distinction | A stale decision cannot approve a replacement image |
| Pose needs retake | Affected slot, private safe reason, remaining attempts | No opponent exposure of rejected media |
| Own set submitted | Locked own set and opponent-stage status | No cherry-picking after learning a score or seeing another body |
| Upload pending or retryable | Actual counts, network state, Retry where valid | Reuse the same match and submission; no extra charge or synthetic result |
| Judging under five seconds | Indeterminate indicator and real stage | No invented percent or promised remaining seconds |
| Judging beyond five seconds | Still judging and safe navigation/recovery action | Same request and same thirty-second final-set deadline |
| Judgement invalid or timed out | No contest, relevant private reason, allowance restoration state | No Elo change; late output cannot resurrect the match |
| Judged win, loss, or draw | Totals, category evidence, neutral explanation, own earned Elo effect | Same final outcome for both participants |
| Valid voluntary forfeit | Forfeit and actual competitive rating effect | No invented physique score or automatic allowance restoration |
| Interrupted or reconnecting | Privacy cover, remaining grace, return/leave choices | Camera stops; no new match and no deadline reset |
| Safety-aborted | Neutral no-contest for opponent and private safety guidance for affected person | No automatic report-driven free win |
| Result restoring after relaunch | Saved match reference and authoritative status | No double judgement, Elo award, or local fallback |
| Pose media hidden, held, removed, expired, or deleted | Correct neutral placeholder and allowed safety actions | No unblur by revisit or stale access link |
| Reporting draft, sending, sent, or failed | Contextual form or actual acknowledgement/error | Local hide is immediate; unsent is never presented as received |
| Scoring review pending or corrected | Original result and current review status; labeled correction if any | No speculative Elo reversal or duplicate adjustment |
| Standings empty or unavailable | Real empty/error view with Retry | No fake ranks, mixing exercise ladders, or assumed placement |
| History page partially loaded | Existing rows, per-page loading/retry at the end | Retain the current scroll position and avoid duplicates |
| Signed out, account switched, or deleted | Cleared private content and appropriate public/entry view | No prior-account media, drafts, cases, or earned records leaking |

## Interaction and Focus Rules

All important controls have concise visible text and accessible names. The existing iOS control sizing is retained, with at least a forty-four-point interaction area for the feature's primary and safety controls. Layout grows with Dynamic Type rather than clamping the largest text sizes to preserve a fixed duel composition.

Each new stage moves accessibility focus to its heading or critical changed instruction. Countdown cues are meaningful without repeating every changing timer value through VoiceOver. The person can inspect a static pose guide before Ready and use an accessible timed capture rather than reaching the screen while holding an unsafe pose.

The app never relies on color, a decorative badge, a shaking image, haptics, or sound alone. Reduced-motion, silent, VoiceOver, Voice Control, Switch Control, and keyboard paths have equivalent actions. Unsupported physical poses do not become a low body score; the person can decline and leave without a false comparative verdict.

On iPhone, pre-Go sheets use the normal close or back behavior. After Go, accidental swipe dismissal of the full-screen capture flow is disabled; an explicit Exit presents Forfeit and leave only when that is the actual consequence. Escape or a desktop close request invokes the same state-aware exit behavior rather than bypassing it. Outside taps do not discard a report draft, withdraw consent, or silently forfeit.

Opening external rules or privacy information must not leave an unnoticed camera running. Backgrounding, a call, permission withdrawal, sign-out, and account deletion stop capture immediately. A privacy cover replaces sensitive media in app-switch snapshots. Returning restores the service state before exposing a live camera or a pending result; media viewers never reopen themselves automatically.

## Responsive and Platform Behavior

The first product surface is native iPhone. Short screens and large text use vertical scrolling and stacked comparison cards, preserving the primary action and exit within safe areas. Existing floating controls and either navigation-menu edge are respected through the app's measured content bounds, not a fixed bottom spacer. The navigation can hide during active capture but remains accessible through explicit exit and restoration behavior.

Lobby metrics wrap into fewer columns as needed. Category labels and reasons can use multiple lines. The report form and account fields remain usable above the keyboard. No body image is stretched nonuniformly, cropped to make a player appear larger, or displayed at a different comparison scale to favor one participant.

Existing iPad and macOS targets remain functional. Where the feature is offered, wider windows use a centered readable column or balanced two-column comparison, keyboard and pointer focus, and the platform's normal sheets. Camera and provider unavailability are honest states, not a crash or a fake competitor. This documentation does not require an unrelated desktop redesign or claim that every camera has been validated.

## Animation Rules

| Interaction | What moves or changes | Timing and interruption | Reduced-motion behavior |
| --- | --- | --- | --- |
| Page selection and expanding header | Existing page/header transition and shared action expansion | Use the current app behavior; keep selected page and scroll state stable | Existing reduced-motion transition |
| Button press and selected state | Existing shared press feedback and visible selection mark | Direct feedback; release never triggers a second action | No added scale or bounce |
| Readiness or framing cue | Text, icon, and outline crossfade; camera geometry stays fixed | Approximately 150 milliseconds, latest real state replaces the prior cue | Same short opacity change or immediate update |
| Pose guide change | Named guide and pose slot crossfade; no moving body scan | Approximately 180 milliseconds after the actual selection changes | Static replacement with readable heading |
| Countdown | One numeral replaces another once each real second | Approximately 150-millisecond opacity transition; interruption cancels the count | Immediate numeral replacement without scale or flashing |
| Transfer and judging feedback | Real transfer progress or existing indeterminate Tmax activity | No artificial minimum wait; pause decoration in background | Static activity indicator plus actual status |
| Final result | Outcome and detail sections fade into their final layout | Approximately 220 milliseconds only after service finalization | Immediate layout or short opacity fade |
| Earned Elo change | Own before-and-after number transitions once | Approximately 450 milliseconds; opening history again does not replay an award | Show final value and signed change immediately |
| Pose image viewer | Native sheet/full-screen viewer and intentional image expansion | Platform transition; close restores the invoking tile's focus | Native reduced-motion transition |
| Report or Hide | Sensitive image becomes a placeholder immediately | No decorative delay before protection; acknowledgement follows actual submission | Immediate protection |
| Case-status or corrected-result update | Updated text, revision label, and relevant metric crossfade | Approximately 180 milliseconds; never show an unconfirmed reversal | Immediate change with an accessible announcement |

These timings are proposed product motion targets, not measured frame-rate evidence or new requirements for a custom renderer. No celebration shakes the opponent, labels their body as inferior, or uses a flashing full-screen effect.

## Files and Ownership

- This DOCKS.md owns the full page and match-flow product behavior.
- TimeMaster/Views/MainTabView.swift and the existing navigation catalog own entry, saved ordering, page history, and profile routing boundaries.
- TimeMaster/Views/Ranked/RankedView.swift and RankedMatchPreparationView.swift are nearby patterns for account entry, safe content bounds, setup, readiness, and explicit privacy; their exercise content and joint-only promises are not replaced.
- TimeMaster/Utilities/Theme.swift and ProfileDesign.swift own the existing palette, shared surfaces, and Inter typography.
- Prospective TimeMaster/Views/Physique/ owns the lobby, entry, capture, match, result, media-viewer, and safety presentation.
- Prospective TimeMaster/Services/Physique/ owns the feature's local capture and authoritative-match presentation boundaries, constrained by F29-B through F29-E.

## Dependencies

[F29-B](../F29-B-ai-judging-and-metrics/DOCKS.md) supplies the exact meaning and validity of every displayed AI metric. [F29-C](../F29-C-physique-rating-and-matchmaking/DOCKS.md) supplies rating, pairing, allowance, standings, and record behavior. [F29-D](../F29-D-safety-and-reporting/DOCKS.md) supplies media acceptance, reports, blocking, and review behavior. [F29-E](../F29-E-privacy-and-service-operation/DOCKS.md) constrains permissions, data access, deadlines, provider use, and deletion.

Real rated entry depends on the shared account/service foundation being reviewed, public HTTPS being authorized and available, an approved judging configuration being accessible, and moderation being operational. A page preview, cached record, or local pose guide is not a competitive fallback.

## Reference

- [Parent F29 specification](../DOCKS.md) defines the feature's shared contract and the boundary between explicit user decisions and proposed defaults.
- [Apple Privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy) informs just-in-time camera access, clear data use, and minimization.
- [Apple Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) informs Dynamic Type, readable contrast, non-color signals, gesture alternatives, focus, and motion alternatives.
- [LarpGPT Battle](https://larpgpt.com/battle) informs the paired sports-comparison idea, not unrestricted video chat, visual copying, or knowledge of its private judge.
- genesis/REFERENCE/APP IMAGE REFERENCE/push up tracker competition.png is a pattern reference for a legible camera-duel HUD, not a direct source of code, mocking language, or Physique scoring.
