# F29-A-a — Physique Lobby

## Purpose and Decision Boundary

The lobby is the native entry to Physique Duels: a private, service-backed sports record with one clear way to find an opponent. It belongs to [F29-A](../DOCKS.md), under the [F29 product contract](../../DOCKS.md). This document specifies future product behavior; it does not describe an implemented view, accepted prototype, deployed service, or human-verified match.

The selected direction supports both native iPhone and native macOS. Earned identity is icon-led, every legitimate public battle badge is represented, and text is concise without concealing units, consent, restrictions, or recovery. Existing numerical competition policies remain proposals under F29-B through F29-E; this UI specification does not independently approve them.

## Chosen Composition and Tradeoffs

The lobby is an earned-identity scoreboard, not a gallery of bodies. Its main column contains the page heading, the person's permitted identity and complete badge rail, one prominent Physique Elo value, a compact competitive record, useful secondary routes, and recent matches. A stable entry bar contains actual allowance information and the primary action.

This composition is chosen over a large decorative athlete hero because identity, complete badges, and the next action should not compete with an illustration for the first viewport. It is chosen over a dense dashboard because this is preparation for a match, not an analytics workspace. Sport character comes from the shared crest language, strong Inter numerals, orange action, confident spacing, and short tactile state changes, rather than extra metrics, repeated slogans, or animation over a body.

The idle lobby has no timer: no match clock exists yet. It has no pretend opponent panel, camera preview, preloaded opponent portrait, countdown to an invented event, or miniature battle. An allowance's next-slot time is labeled as allowance information, not dressed as the match timer.

A genuine active match changes the entry action to Resume match, or the appropriate state-specific recovery action. Activation enters the existing match owner rather than rendering a competing battle inside the lobby. Wherever that owner displays a battle, the real timer is the top visual anchor, followed by both complete owner-grouped identity and badge rails, followed by two large vertically stacked player panels: You above Opponent. That order is unchanged on wide Mac displays. All evidence is aspect-fit without body cropping, distortion, unequal comparison scale, or labels over faces and limbs. Short space means scrolling, not shrinking people to thumbnails or hiding badges.

## Ownership and Destinations

The lobby owns its composition, own-record presentation, recent-match entry rows, allowance summary, entry-action selection, refresh and restoration behavior, and integration with the existing saved page catalog. It owns the small record-and-allowance detail section described here, not a new analytics destination.

It opens, but does not independently redefine:

- The existing account flow and private account controls.
- F29-A's rules, local Pose guide, eligibility, informed sharing, camera preparation, matchmaking, active match, and result routes.
- F29-C's Physique standings, complete private History, authoritative records, and exact saved match detail.
- F29-D's Safety and support, private cases, blocks, restrictions, and review routes.
- F29-E's Privacy and sharing controls.
- F29-F's shared public identity, optional country or region editor, badge meanings, award/correction handling, and permitted identity details, as registered by the F29 parent.

Existing system alerts, permission prompts, menus, disclosures, and sheets stay native. The lobby does not add a custom permission dialog, new badge economy, third Profile side indicator, alternate result screen, image gallery, account provider, camera owner, or second matchmaking coordinator.

## Main Content Hierarchy

### Heading and account access

The single page heading is Physique. Rules and Account are concise labeled icon actions beside it when space permits. On iPhone, the established expanding/compact page chrome may move the title while retaining the named actions; it never leaves only an unexplained symbol. A small Physique Duels subtitle is optional only when it does not repeat a neighboring title or push essential content down.

Account shows the real account state. Signed out is not represented by a verified-looking seal, an earned local handle, or a borrowed profile level. The lobby can be browsed without opening account entry, requesting permissions, reserving allowance, or starting capture.

### Earned identity block

The block begins with the permitted public avatar or neutral silhouette and the authenticated handle. It uses the shared public-identity presentation, not an automatic upload of the editable local profile photo. The optional country or region marker sits beside the handle, never as a rating advantage or eligibility seal.

Immediately below the handle is the complete wrapping public badge rail. The shared earned-rating crest and one prominent current Physique Elo value follow. The crest is a competitive identifier, not a large portrait frame or evidence image. Its supporting symbol must refer to Physique, not imply that an exercise-variation rating is being displayed. Unplaced and provisional presentations remain explicit.

There is no dramatic body illustration behind this block. A neutral shared silhouette is a legitimate missing-avatar representation, not a fake participant or a claim that new artwork exists. Future licensed or original artwork may support the shared identity family, but it must not become a prerequisite for a functional lobby or be copied from the people in the reference screenshot.

### Compact record

Current Physique Elo appears once in the identity block. Below it, a smaller Best Elo line and a compact Wins, Losses, Draws strip provide the meaningful record. Each value has its short visible label; a string of unexplained numbers or W/L/D letters alone is insufficient. The strip wraps or stacks before labels or numbers are compressed.

A native Record disclosure on iPhone reveals rated matches, win rate, own forfeits, and no-contests, with the qualifications below. macOS places the same secondary information in the lobby Details inspector or its compact-window presentation. Current win streak remains the truthfully labeled current-status element supplied by the shared identity rail; a historical Three Straight badge never substitutes for it.

### Secondary routes and recent matches

A small utility row offers Pose guide, Standings, and Safety, each with a recognizable icon and short visible label. The row wraps rather than becoming a horizontally scrolling carousel or hover-only menu. Rules and Account stay in page chrome. Privacy and sharing remains directly reachable through the existing account/safety privacy route, with a plainly named choice rather than a generic settings hunt.

Recent is a real list of up to three most recent started matches, in service order. Its header includes History, leading to the complete private history. A count of fewer than three rows remains fewer than three rows. This limit is for the lobby's recent list only; it is never a badge-slot limit. No public body image, selected-pose thumbnail, score bar, or opponent face from evidence appears here.

### Stable entry bar

The entry bar is visually subordinate to the identity but spatially dependable. It contains a compact Physique matches allowance line, a concise current blocker or recovery status when necessary, and one orange primary action. Normal idle entry is Find opponent with the shared sporting action icon. There is no simultaneous second Start, Match, or rematch button.

The allowance line is immediately adjacent to the action; it is not buried in History. A named allowance information control opens the standard policy disclosure or lobby Details section. Help text does not occupy a permanent wall above the action.

Before the first participation, the short notice says Images shared with AI and your paired opponent after a result. It links to the actual sharing explanation. This notice is not consent and does not replace the recipient, retention, screenshot-risk, and withdrawal disclosures required before transfer. A short Three poses · AI-judged description may accompany the empty state, but must not imply local-only analysis, objective measurement, or immediate opponent access.

## Complete Badge and Country Behavior

F29-F supplies the trusted badge catalog, eligibility, public ordering, accessible descriptions, and event identity. The lobby renders that authoritative public set without a selected-three limit, hidden +N, clipping, an auto-scrolling ticker, a paid expansion, or a hover requirement. Each badge has a recognizable mark and concise visible name. Details remain operable by touch, click, keyboard, VoiceOver, and Switch Control. Whole badge units wrap and grow with their labels.

The launch rail presents current competitive status first: the actual placed tier combined with Placed where applicable, then the current win-streak status when supplied. Earned milestones follow in stable catalog order: First Bell, Ten Rounds, Three Straight. Combining Placed and the current tier is one readable status, not omission of one achievement. A current tier is never assigned before placement. A confirmed zero streak is not an unknown value or a three-win claim; it has a neutral Current streak 0 presentation rather than a positive flame celebration.

First Bell means the first valid AI-judged win, loss, or draw. Ten Rounds counts ten effective valid AI-judged matches. Neither counts forfeits or no-contests. Three Straight is a historical earned milestone for a canonical Physique win streak of at least three, including eligible opponent-forfeit wins under F29-C. It is not labeled as the person's present streak. Placement counts eligible rated forfeits under F29-C, so a player may legitimately be placed before having the First Bell or Ten Rounds milestone. No client calculation makes these distinct badge conditions interchangeable.

An account with no earned milestones simply has no milestone badges; the lobby does not create a row of locked trophies, an empty badge frame, a fake level, or an achievement debt. Unplaced and provisional are competitive states, not awards or verification. Adult/attire declarations, country, absence of reports, paid status, anatomy, gender, and editable local cosmetic badge previews do not become competitive achievement badges.

A successfully refreshed snapshot can add, remove, or revise badges. Only a newly confirmed, not-already-presented award event receives the small unlock treatment. The result owner and lobby must not both celebrate the same event. Returning from History, reopening a window, changing the country, or rereading cached data never re-awards it. Corrections can remove Placed and tier, revise progress and current streak, or remove an invalid earning event. A correction is a quiet Updated after review status with an explanation route, not a punishment animation or a locally retained entitlement.

A trusted, account-scoped cached badge set can remain visible when ordinary refresh fails, but the block is labeled Saved with its last update. It is not presented as current verification. A known revocation, correction, sign-out, account switch, or access removal takes precedence over stale cache; the obsolete badge disappears immediately. If the authoritative badge state has never loaded, show Badges unavailable with a retry or shared-detail route, not No badges earned. Badge-detail failure alone does not prevent starting if the service can separately confirm participation; unsettled competitive eligibility does.

Country or region is manually chosen, optional, and self-declared. When present, its flag emoji is beside the handle and has the accessible region name. With no choice, use a neutral globe in the person's editable identity context, described as Country or region not set, optional. Unsupported flag rendering uses a neutral globe with the selected region's readable name, not an empty square or the wrong flag. The region editor is the shared F29-F control; the lobby does not create another picker. No location prompt, IP/locale default, photograph inference, nationality verification, country matchmaking filter, or scoring input is introduced.

## Record and Value Meaning

The lobby uses the coherent confirmed Physique summary for the signed-in account. Current Elo, best, placement, record, badge status, and any review adjustment must not be assembled from incompatible revisions. Independent sections can fail independently, but missing data is explicit rather than fabricated.

| Value or status | Required meaning and presentation |
| --- | --- |
| No settled rated results | Unplaced. No earned current Elo, best Elo, tier, or public place. The pairing seed of 1000 is never shown as an award. Pending or no-contest history can still exist. |
| One through four effective rated results | Actual current and best earned Physique Elo with Provisional and the completed count out of five. No assigned tier or fabricated public rank. |
| Placed | Actual current Physique Elo and supported current tier. Public listing is a separate choice; an unlisted player can be placed without having a public position. |
| Best Elo | Highest actually earned, effective settled Physique Elo. It is not the hidden starting seed, an exercise best, or an immutable maximum after a correction invalidates the earning event. |
| Wins, losses, draws | Effective final rated record. Eligible forfeits are subsets of wins/losses, not extra matches. A no-contest and pending result do not inflate the record. |
| Rated matches | Wins plus losses plus draws, including eligible forfeit subsets once. It is not starts, searches, or the number of images. |
| Win rate | F29-C's percentage of rated matches that are wins, to one decimal place. Draws remain in the denominator. No rated matches says Not available, not 0%. |
| Own forfeits | A clearly labeled subset of losses. It is not added to losses again. |
| No-contests | Started unscored matches, separately named. No fake loss, draw, body score, or placement advancement. |
| Current streak | Consecutive effective rated wins under F29-C. Draws and rated losses reset it; no-contests do not extend or break it. It is unrelated to workout streaks. |
| Unknown | A dash paired with Loading, Unavailable, or Saved as applicable. An unknown record never becomes a real zero. |
| Review settling | Rating updating after review, with last confirmed values labeled as such. New rated entry is unavailable until the service confirms a coherent settled summary. |

The expanded record explains forfeit and no-contest inclusion in plain language. It may link to the actual result or History, but does not create a separate leaderboard, cosmetic level, or graph of guessed historical values. AI totals, confidence, body-fat percentage, muscle mass, health, calories, repetitions, and workout completion are absent from this lobby's metrics.

## Real Allowance and Entry Authority

The current proposed policy is ten started Physique matches in a rolling four-hour window, separate from exercise allowances. Display the actual remaining count and next-slot time supplied by the participation service. A capacity supplied by the service must agree with the reviewed policy; the client must not silently cap a different service value or invent an unlimited entitlement.

At full availability, show the actual count with Physique matches. When some slots are used and a next-slot time is known, show Next slot followed by that real local time. The full date and time-zone meaning is available accessibly and in the allowance details. With zero available, say No matches available and show the known next-slot time. If that time is unknown, say Availability unavailable rather than manufacturing a countdown.

The allowance is not restored locally when a displayed clock reaches a predicted time. The service must confirm the newly available slot before rated entry. Relative time may update unobtrusively while visible, no more finely than needed for a minute-level allowance label. A locale or time-zone change changes formatting, not the underlying grant. There is no every-second lobby countdown or per-frame allowance polling.

Opening the lobby, Rules, Pose guide, History, Standings, Safety, badge details, or privacy controls consumes no slot. Tapping Find opponent is an entry intent, not the Go boundary. The service reserves a slot during pairing and consumes it only once at authoritative Go. Cancel before Go releases the reservation. An eligible forfeit remains consumed; a service-confirmed no-contest restoration applies once. The lobby shows only confirmed consequences and never a speculative refund animation.

One account has at most one reserved or active match across windows and devices. Restoring that state takes precedence over a new entry intent. Multiple taps, multiple Mac windows, relaunch, a stale result, a navigation deep link, or an unavailable cancellation must not create a second queue position or charge. An unresolved active-match check disables new rated entry with Checking active match, but leaves ordinary browsing usable.

## State and Action Matrix

The most consequential current state controls the entry bar: account identity must be known before private data; an existing match must be resolved before a new one; restrictions, unsettled rating, and participation availability must be truthful. A camera or consent requirement can lead to setup; it does not authorize search. Distinct errors stay distinct even when several independently unavailable sections coexist.

| State | Visible lobby and primary action | Recovery and allowed behavior |
| --- | --- | --- |
| First opening, account unknown | Physique heading, safe public explanation, labeled session restoration feedback. No previous account record, invented Unplaced state, or sample rows. Entry says Checking account and is unavailable. | Rules, local Pose guide, and Safety/support remain usable. A failed restoration resolves to an explicit sign-in or retry state, not an endless spinner. |
| Signed out | Neutral identity, Sign in for Physique Elo, no private recent matches or cached earned badges. Find opponent opens the existing account flow. | Account can also open directly. Successful sign-in returns to this lobby and preserves the intended entry context without starting search or camera by itself. Cancellation returns unchanged. |
| Authenticated, summary first loading | Own authorized handle can appear; rating, badges, allowance, and recent sections identify what is still loading. No sample values. | The primary action waits only for the account/active-match/participation checks required to proceed. History failure alone is not an eligibility failure. |
| Authenticated unplaced, history empty | Unplaced, no tier or earned Elo, confirmed zero record where actually known, No physique matches yet. Find opponent is available for entry when checks allow it. | Pose guide and Rules explain the three poses. No starter reward or fake first opponent fills the space. |
| Unplaced with pending/no-contest history | Unplaced plus the real recent rows. A pending active match changes entry to its restoration action. | No-contests do not create Elo or placement; pending results are not losses and do not advance badges. |
| Provisional | Actual earned current/best Elo, truthful record, Provisional with progress out of five. All legitimately earned milestone badges remain visible. | Find opponent follows the same eligibility gates as placed entry. No fabricated provisional public rank. |
| Placed, listed or unlisted | Current Elo, supported tier/Placed state, complete badges and real record. | Standings respects the listing choice. No public position is invented for an unlisted account or inferred from the currently loaded rows. |
| Missing/changed rules or sharing choice | The ordinary lobby stays usable. Find opponent opens the specific shared eligibility/consent step with an adjacent concise requirement label. | No queue reservation, camera start, or transfer until the required deliberate choices. Decline returns to the lobby and unrelated app use. |
| Adult-ineligible or participation restricted | Private status such as Physique unavailable, not a public identity badge. Rated entry is unavailable; View restriction or the relevant real review action is the one primary recovery action when available. | Rules, allowed History, support, privacy, and the rest of Tmax remain reachable. No image proof, alternate-account suggestion, or inferred age/gender. |
| Camera never requested | No camera activation or system prompt in the lobby. Find opponent routes through deliberate preparation. | Camera permission is requested by the camera owner after its own explicit setup action, not during lobby refresh. |
| Known camera/TCC denied, restricted, absent, or busy | Camera needed or the concrete reason appears near entry. Find opponent can open the actual setup/recovery surface; it cannot join a queue directly. | Settings or Retry is offered only where useful by the camera owner. No repeated permission alert, fake preview, file picker, or Photos-library substitute for rated capture. |
| Allowance confirmed zero | No matches available and the actual next-slot time when supplied. Find opponent remains visibly unavailable; allowance details is a named explanatory action, not a second start button. | Browse normally. A newly eligible time causes a service recheck, not a locally granted slot or auto-entry. No payment, exercise quota, or personal API-key bypass. |
| Allowance or active-match status unknown | Checking availability or Unable to check availability, with no assumed remaining count. New rated entry unavailable. | Retry explicitly rechecks authoritative participation state. A saved count is labeled saved, never used as fresh permission. |
| Refresh with existing data | Last confirmed allowed identity and records remain stable; a small refresh indicator names the affected section. | New data replaces the relevant coherent snapshot. Refresh does not reorder a row under focus, replay awards, or clear good content just because a section failed. |
| Offline with permitted account-scoped cache | Saved plus last update accompanies cached non-media records. No opponent photos are exposed. Find opponent unavailable; the recovery action is Retry. | Read allowed saved text and local guidance. Reconnect checks the same account and existing match before enabling entry; never queue an offline start for later. |
| Offline without permitted cache | Unable to load Physique record or history, not an empty-record claim. Retry is available. | Rules, local guide, published support, and other available app pages remain reachable. |
| Participation/judging service unavailable | Matches unavailable with the actual safe reason. Existing records may remain readable if their service is available. Rated entry unavailable; Retry checks availability. | No fabricated ETA, five-second promise, local judge, bot, alternate model, or charge for unavailable entry. A failed history refresh alone must not be mislabeled as judge outage. |
| Recent matches empty or failed independently | Genuine empty says No physique matches yet. Failure says Unable to load recent matches with Retry recent matches; existing rows remain when permitted. | A successful participation check can still allow Find opponent. Opening History uses its real independent load/error state, not a fake replacement list. |
| Search/reservation already exists | Match in progress with Resume match, or the exact service-owned search/recovery label. | Resume the existing search/match owner. Do not silently cancel it or reserve another slot. Cancellation uncertainty remains unresolved until confirmed. |
| Capture can resume | Resume match with the real stage; no lobby camera starts in the background. | The match owner revalidates the same match and offers explicit capture resumption, within unchanged deadlines and retakes. No fresh start or charge. |
| Another Mac window owns the active session | Active in another window with Show active window as the primary action. | Focus the owning window using native window behavior. No second camera or session. If that window closed, reconcile authority before offering resume; do not claim to focus a nonexistent window. |
| Active on another device | Match active on another device with the real shared recovery action or Check status. | The reviewed single-owner recovery contract decides whether this device may resume. No new local takeover, eviction, camera start, or second charge is invented by the lobby. |
| Both sets submitted, result pending | Result pending with View match. The row remains pending, without provisional appearance scores. | Open the same judging/restoration surface. Server judgement can finish while away; new entry waits for authoritative finality. |
| Finalized while away or after a result closes | The confirmed summary, allowance, badge set, and matching recent row refresh together where coupled. A concise Result ready route can open that exact result. | Do not auto-open a gallery, steal focus, rerun judgement, or replay an already-presented award. Find opponent becomes a new deliberate eligibility check only after prior state is terminal. |
| Rating correction settling | Rating updating after review, last confirmed values clearly marked, no mixed badge/tier/record revision. Rated entry unavailable. | View review opens the existing private context. Once confirmed, coherent corrected data replaces the old values without an implied second match. |
| Correction settled | Updated after review with the real revised record and badge/placement state. | The explanation route remains available. A removed earned event does not survive in a stale crest or claim. |
| Opponent blocked/deleted/unavailable in recent list | Blocked player or Unavailable player and a neutral identity marker. No active profile link or allegation. | Own permitted outcome and Elo effect remain accessible. Match details enforce present media authorization; the lobby does not reexpose identity or stills from cache. |
| Sign-out, account switch, or account deletion | Prior account's private rows, allowance, badge set, record details, and pending private routes clear immediately. | Resolve active-match consequences through the existing account/match contract; camera privacy stops are immediate. The next account loads its own state and never inherits a pending queue intent. |

## Entry, Saved Navigation, and Return Behavior

Physique is a stable, separately named destination in the existing page catalog on iPhone and Mac. A fresh installation may include it beside Ranked. An existing saved layout is not overwritten: Physique is offered through Add page, already-added items retain the catalog's ordinary state, and the saved selected destination, order, and top/bottom placement remain intact. Adding it does not reinsert a previously removed Ranked page, reset existing preference keys, or execute the older Ranked auto-insertion pattern for this new feature.

An explicit route from an existing permitted app entry can use the app's normal page-opening behavior; opening a Physique result does not authorize adding unrelated pages or resetting the bar. Removing Physique from the catalog does not revoke image sharing, delete records, cancel a match, or conceal the privacy controls elsewhere in the account/safety flow.

Returning from Rules, Pose guide, an account step, History, badge details, standings, safety, or a saved result restores the lobby's reading position and the invoking control's focus where still present. The lobby does not restart its entrance animation or move the primary action unexpectedly. An account change or removal of the focused item is an exception: return focus to the page heading or appropriate available recovery action, never a stale private target.

Find opponent resolves prerequisites in the established entry flow: actual account, private adult eligibility, current rules/sharing, available camera and adequate preflight, service allowance, and judging availability. Earlier consent never substitutes for later availability checks. Successful sign-in, returning from Settings, changing country, accepting a badge detail, or a network reconnect does not itself launch a queue. The person must deliberately continue the shared preparation flow. If an existing match is discovered during that process, open its genuine recovery state instead of creating another match.

Opening a recent row requests that exact authorized saved match. A pending row goes to its current match/restoration state. A final row opens its actual result detail. An unavailable saved reference produces the existing safe unavailable-detail state with Return and permitted support; it is not silently replaced by a newer match. Authentication expiry can require the existing account flow before private detail is shown, without leaking cached opponent information.

## Recent Row Content and Behavior

Each row leads with a small outcome symbol plus Won, Lost, Draw, Won by forfeit, Forfeited, No contest, or Pending. Color is secondary. The permitted opponent label and actual match date/time follow, with the person's own signed effective Physique Elo change at the trailing edge when settled. The narrow layout moves the change below the outcome rather than truncating the outcome or inventing an abbreviation.

A no-contest says No rating change, not +0 and not Draw. A pending match says Pending, not zero Elo. A real rated zero change remains a genuine numeric zero and is not confused with either. A forfeit row never displays AI category totals. An authorized corrected result carries a concise Corrected marker and opens the original/correction context under the existing result owner. Under review is a private state where supplied, not a public allegation or a predicted reversal.

Rows are stable by actual match identity. A confirmed newly available result can expose a quiet New results available action rather than inserting a new row under a reading pointer or VoiceOver focus. Activating it refreshes the recent snapshot and preserves a sensible anchor; returning from the person's just-closed result refreshes that known row without fabricating another row. There is no infinite scroll inside this three-row preview; History owns pagination and accessible Load more.

Whole-row activation is a semantic button/link, not a precision gesture. No essential action is swipe-only or hidden behind hover. Report and block remain in the destination's contextual safety controls; the lobby Safety action is available without opening or enlarging any image. Opening a row never automatically opens View poses. Expired media, blocked players, withdrawn sharing, forfeits, and no-contests retain the shared safe access rules.

## iPhone Composition

Use the app's near-black background, shared dark surfaces, Inter Black headings/numerals, Inter Regular supporting copy, and toolbar orange. Reuse existing spacing and rounded-control language. The identity and record are a continuous scoreboard composition with restrained separators, not a stack of unrelated pill cards. Readable secondary text follows the shared readable secondary style, not a low-opacity decorative label.

The page fills the measured safe content region between existing navigation/chrome. Header, identity, complete badge rail, record, utility row, and recent list share one vertical scroll context. The entry bar sits in the actual safe area with measured clearance for the existing top/bottom navigation and any app-owned floating controls. No screen-coordinate overlay, guessed bottom spacer, or app-wide navigation redesign is part of this view.

The action and allowance grow to their labels. Existing primary/safety interaction targets are at least forty-four points. With larger Dynamic Type or short/landscape space, the badge rail and record gain rows, the utility row wraps, and the central content scrolls; text and real badges are not clamped or collapsed. The primary action remains reachable while content scrolls. Supplementary allowance policy and record definitions stay in the native disclosure rather than enlarging a permanently pinned explanation wall.

Rules, account, and shared supporting routes use their ordinary native sheet or push behavior. Dismissal before any match entry has no competitive consequence. A consent or report draft follows its own meaningful-loss confirmation. The lobby never opens camera permission during a passive sheet dismissal. The native keyboard on a shared account/safety form must not cover its controls or make the lobby's entry bar appear above the form as a competing start action.

## Native macOS Composition

This is a native macOS 14-and-later window surface, not Catalyst, an embedded browser, or a touch-size phone sheet stretched to the window. The existing normal title bar, window controls, resizability, and app minimum of 800 by 600 remain unchanged.

The toolbar names the destination and offers Rules, Account, and Details as semantic native toolbar controls. It does not duplicate a giant phone header inside the title bar. The main scoreboard uses the existing readable-column convention, centered in available content with intentional side space. Recent matches use a native-density ledger below it. On laptop, full-screen, and large/external displays, more useful content and optional details are visible; avatars and Elo do not inflate to fill the display. The entry bar stays aligned to the main column rather than becoming a window-wide touch slab.

Details is an optional trailing native inspector containing the same secondary Record fields, allowance policy, and data-freshness context available through iPhone disclosures. It is a detail presentation of this lobby, not a separate destination, public profile, match, or safety screen. All essential record values, complete public badges, real allowance, and entry action stay in the main column when the inspector is closed.

At 800 by 600 or whenever measured space cannot accommodate a readable main column plus inspector, Details opens the same secondary content in a normal native sheet. Live resizing never forces the scoreboard into a crushed column. If an open inspector can no longer fit, it collapses back to its named toolbar control without automatically presenting a sheet or moving focus into a new modal. Reopening Details explicitly chooses the compact presentation. No always-on overlay obscures the title bar or entry action. Resizing preserves the main reading position, row identity, and active match intent.

Scrolling uses trackpad, wheel, keyboard, and native scrollbars. Hover can add a restrained highlight and help text to an already recognizable control; it cannot reveal the only name, badge meaning, or safety action. Native focus outlines remain visible. Country and badge details use their shared anchored popover or sheet presentation, not a new imitation tooltip window. Closing such information restores focus to its invoking control.

The lobby never acquires a camera, prompts TCC, chooses a device, or starts a Continuity Camera session. Its preparation route must still handle the actual Mac TCC denied/restricted state, no camera, another app using the camera, external-camera disconnect, and Continuity disconnect without a fake preview or rated file upload. A restored match observes one camera/match owner across Mac windows and devices. A secondary lobby window uses Show active window, Check status, or the existing authorized recovery action, never another camera reservation.

Ordinary lobby Cmd-W closes that window without a forfeit confirmation, because browsing has no rated consequence. If it is also the window hosting an active match, the match owner intercepts a close/quit request where the platform permits and explains the real pre-Go cancellation or post-Go eligible-forfeit consequence. Force quit is an involuntary interruption, cannot be reliably prevented or confirmed, and is not reported as a voluntary forfeit. Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O keep their current app meanings; this view does not capture them for matchmaking.

Inactive, minimized, hidden, backgrounded, or closed lobby windows stop decorative work and unnecessary refresh activity. Any owned capture is immediately stopped/shielded by its shared owner, without waiting for a lobby animation. Returning fetches the same authorized state and never restarts the service's clocks, retakes, queue, or allowance charge. Moving the window to an external display or changing scaling changes only layout, not camera selection, evidence framing, public identity, or service authority.

## Focus, Keyboard, and Accessibility

The reading order is page heading, Rules/Account, own identity, optional country, complete badge rail in stable order, current Physique Elo and placement, compact record and disclosure, utility routes, recent rows/History, then allowance and the primary action. The pinned primary remains directly discoverable and does not appear twice in the accessibility tree. macOS toolbar and optional inspector follow normal platform navigation rather than a fake canvas traversal.

Every icon action has a semantic name and a discoverable visible label in its ordinary context. Country exposes its region name and optional/self-declared meaning in details. The accessible identity describes a competition record, not verified adulthood or verified nationality. Rating, counts, placement fraction, allowance, dates, outcome, and signed Elo change have full accessible meanings and units. Decorative crest strokes, neutral background art, and redundant icons are hidden from accessibility rather than repeated as separate stops.

Tab and Shift-Tab move through enabled native controls in visual order. Return or Space activates only the focused semantic control, according to the native control's behavior. There is no global Return-to-find-opponent handler, shortcut that activates while typing, or Space listener that fights scrolling. iPhone hardware-keyboard, Voice Control, and Switch Control can reach the same actions without swipes or precise taps.

Escape dismisses the top permitted information popover/sheet first. It does not silently discard a meaningful draft, revoke sharing, start a match, clear an account, or forfeit. With no presented information, Escape has no lobby matchmaking effect. Once an active match is opened, its state-aware exit contract replaces ordinary lobby behavior.

Initial focus goes to Physique, not a disabled button or a presumed award. Returning focus goes to the invoking control or a stable nearby replacement. Refresh normally preserves focus. A restriction or lost eligibility can announce one concise status and expose the real recovery control without repeatedly stealing focus. Announce a newly confirmed result, correction, or badge once; do not read each changing allowance minute, render frame, refresh tick, or number interpolation. No intimate body description, gender inference, sound, haptic, or color-only meaning is used.

Dynamic Type, increased contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion preserve all information. Country names, badge labels, outcome labels, and signed changes can wrap. Do not inherit the existing Ranked view's Dynamic Type upper clamp, single-line metric compression, or minimum-scale behavior. No real badge, recovery action, or consent disclosure is removed to make a fixed screenshot fit.

## Motion and Interruption Rules

The lobby is tactile but not continuously busy. It deliberately has no indefinite idle animation, scanning body, rotating badge wall, numeric slot machine, or simulated queue activity. Shared press feedback, a small earned-event spring, and responsive disclosure/navigation continuity provide motion with a real cause. Result score and Elo award choreography belong to the result owner, not this page.

| Trigger | Visible behavior | Timing and interruption | Reduced-motion and energy behavior |
| --- | --- | --- | --- |
| Press/release on an enabled shared control | Existing small compression and opacity feedback, returning directly to rest. | Use the existing shared response 0.24, damping 0.88 press spring. Cancellation cancels the action; repeated presses cannot duplicate entry. | No scale when Reduce Motion is enabled; keep native focus/pressed distinction. No work runs after release. |
| Entry checking, blocker change, or refresh status resolved | The status symbol and short text replace in place; main identity geometry does not jump. | About 160 milliseconds of opacity/contained change. The newest real state interrupts immediately; no artificial minimum loading time. | Immediate replacement or short opacity. Privacy removal, account clearing, and disabled eligibility take effect immediately. |
| Confirmed summary value changes | Current/best numbers and record labels change in stable geometry. Final accessible values are present immediately. | About 180 milliseconds. No count-up from the hidden seed, no guessed intermediate Elo, no result replay. A newer coherent snapshot replaces an unfinished visual change. | Immediate final values or short opacity. Updates occur on actual state changes, not a display-link loop. |
| First presentation of a genuine unseen earned badge | Only that new badge settles from a small scale, at most about 1.06, into its final rail position. Existing badges do not bounce. | Complete within about 320 milliseconds. Multiple newly confirmed badges use one grouped settle, not serial celebrations. A newer correction/removal cancels immediately. | Static insertion or at most a 140-millisecond fade. Offscreen awards do not queue a replay for later scrolling. |
| Correction or badge revocation | Obsolete presentation is removed and the real corrected state takes its place, with the Updated after review explanation available. | Logical removal is immediate; any remaining layout settles within about 180 milliseconds. Never animate a false entitlement until completion. | Immediate corrected layout or short opacity. No shake, red-flash penalty, or sound of defeat. |
| Record disclosure or Details activation | Native disclosure expansion or native inspector/sheet reveals the secondary section. No hero flies across the page. | Approximately 220 milliseconds for an in-place disclosure where custom timing is applicable; native presentations keep system timing. Interruption preserves the actual expanded/closed state. | Static layout/short opacity for owned disclosure; system reduced-motion presentation for native containers. |
| Deliberate route to setup, resume, History, or saved result | Shared stage/navigation continuity leads from the invoking control without moving individual badge objects between independent screens. | Native route behavior or the shared 260–320-millisecond stage transition. Destination controls and safety are available immediately; navigating back cancels visual continuity without another entry request. | Native reduced-motion navigation or short fade. No camera, network, or permission work waits for an animation completion. |
| New recent results available | One quiet labeled update action appears; the list does not auto-scroll or shove focus. | About 160 milliseconds. Applying the update changes only real rows; leaving cancels decorative work. | Static action. No pulse or recurring notification loop. |

Backgrounding, inactivity, minimization, navigation away, Low Power Mode, or serious thermal constraints removes decorative motion and unnecessary refresh work. The lobby has no 12-second ambient layer to keep alive. Shared active-match clocks continue independently; service deadlines never pause because the page is inactive. No per-frame service calls, account reads, sorting, font measurement, image decoding, or global layout invalidation is justified by these effects. Reduce Transparency uses opaque readable surfaces without adding a new global theme or requiring newer glass APIs.

## Privacy and Safety Invariants

The lobby is not a media-entry surface. Passive entry does not activate the camera, microphone, photo library, location, Contacts, or HealthKit; it does not upload a profile portrait, body still, or background frame. Country, badges, handle, rating, record, and UI chrome never become judge inputs or get baked into evidence. Capture sends the clean locally face-obscured representation, never a screenshot of this interface.

The adult/attire declarations remain private and are never deduced from a photograph. A local editable badge preview is not a trusted achievement or identity verification. No unsafe diet/exertion challenge, anatomy/gender trophy, report-count badge, or absence-of-enforcement claim is introduced.

Recent matches remain private account data. A lobby screenshot/export feature is not added. Notifications do not embed the opponent, a pose, a score, or a sensitive case. Cached text is scoped to the authenticated account and current permission; sign-out/account switch clears private surfaces, private route state, and any inherited entry intent. Background/app-switch privacy covers protect sensitive account details and any other active feature media without promising that external recording is impossible.

History entry does not grant counterpart media access. Only an intentional View poses inside a valid AI-judged win/loss/draw with current authorization can show the approved stills; forfeits and no-contests have none, and ordinary expiry remains twenty-four hours after finalization. Reporting/hiding does not require enlargement. Block after Go immediately shields and excludes future pairs, but is not itself leaving, a rerating, or an automatic no-contest. The lobby never overrides F29-D/E service authority for these outcomes.

## Dependencies and Files

These are product ownership and prospective integration locations, not implementation claims.

- [F29 parent](../../DOCKS.md) and [F29-A](../DOCKS.md) own the common match lifecycle, native stage composition, page shell, and supporting routes.
- [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns the meaning and limitations of AI judgements; it does not supply a lobby body score.
- [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns coherent physique-only rating, placement, records, allowance, active-match authority, standings, history, and corrections.
- [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns eligibility, restrictions, permitted support, blocks, reporting, and review.
- [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns permission, identity/access scoping, sharing, privacy lifecycle, deletion, and service availability.
- F29-F and the shared native UI work registered by the F29 parent supply the reviewed identity/badge components and common visual language. Their absence is not permission to invent a local badge service or temporary production renderer.
- Existing account, saved navigation, authorized service, and shared F29 participation/route contracts must be implemented and human-reviewed before this lobby becomes a connected competitive surface. A separate lobby preview is not an independently shippable feature or a production fallback.
- Prospective TimeMaster/Views/Physique/PhysiqueLobbyView.swift owns this lobby's root composition, state selection, and existing-route entry.
- Prospective TimeMaster/Views/Physique/PhysiqueLobbyComponents.swift owns only the feature-local record, recent-list, entry-bar, and lobby-detail composition that is not already provided by reviewed shared views. Public identity/badge rendering and native framework controls stay with their existing owners.
- [MainTabView.swift](../../../../TimeMaster/Views/MainTabView.swift) and [SlotNavigationItem.swift](../../../../TimeMaster/Views/Navigation/SlotNavigationItem.swift) are the current page routing and saved catalog integration surfaces. Make the smallest approved Physique registration change without changing unrelated destinations or saved-layout semantics.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own shared surfaces, typography, and tactile controls. No parallel global theme or private glass API is introduced.
- The [future implementation brief](../../../../prompts/F29-physique-duels/F29-A-a-phase-1-lobby.md) owns prospective engineering scope and focused native review scenarios. Implementation planning belongs to CYCLES.md, not this document.

## Precedence and Explicit Differences From Older Context

The newer user-directed two-platform UI contract takes precedence over F29-A's earlier first-iPhone emphasis and optional balanced two-column comparison. No battle in this flow becomes side-by-side on Mac or iPhone. The idle lobby is intentionally not a battle and therefore invents neither an opponent nor a timer to resemble the screenshot.

The earlier metric list is expressed without duplicating current Elo: current is in earned identity, best and record are adjacent, and secondary definitions are disclosed. The reference screenshot's hierarchy and directness are useful; its purple/brown web pills, overlaid labels, side-by-side participants, people, captions, and implied footage rights are not copied. The complete badge set and optional self-declared country come from the newer shared identity contract, not editable local profile cosmetics.

This direction keeps the current iPhone iOS 16 and native macOS 14 compatibility boundaries. Examples in installed skills that assume iOS/macOS 26 are not authorization to raise targets or require those APIs. Exact service APIs, public moderation operation, model quality, and App Store suitability are not established by a product document. The lobby must expose genuine unavailable states rather than present an unreviewed foundation as ready.

## References

- [Supplied battle screenshot](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): hierarchy/directness reference only, not licensed participant assets or the chosen layout.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift): nearby shared action/earned-crest language, not its Dynamic Type clamps or compressed metric recipe.
- [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift): existing exercise HUD context, not permission for live provisional Physique scores.
- [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift): local cosmetic badge previews are not trusted competitive identity.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift): native Mac window and existing command boundaries.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), particularly Best practices: resizable multiwindow work, comfortable density, menu/keyboard integration, and native input inform the toolbar, inspector, and window behavior here.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), particularly Best practices and Providing feedback: purposeful, brief, optional, cancellable motion informs the event-driven lobby and its static reduced-motion equivalents.
