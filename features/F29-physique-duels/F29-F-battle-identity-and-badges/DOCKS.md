# F29-F — Battle Identity and Badges

## Purpose and Ownership

This area gives Physique Duels a recognizable competitive identity without claiming that an account, nationality, body, age, or gender has been verified. It owns the launch badge catalog, the meaning of earning and losing each badge, optional self-declared country or region, the medallion family, and the complete owner-grouped battle rails. The visual direction is native iPhone and native macOS, animated sports presentation, concise text, and two large vertical participants beneath the top timer and all public battle badges.

This is product context for future implementation, not an implemented badge service, generated artwork, accepted prototype, or human-verification record. The launch catalog and inherited numerical competition rules are explicit proposals for review. The user's approved visual direction does not silently approve every earlier rating or placement proposal.

The separate [V25 — Badges and country view](../F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md) owns the complete collection/detail surface and the person's country editor. F29-F supplies its authoritative meanings, reusable medallions, status language, and battle entry points; it does not create another collection screen, country-settings destination, or competing badge-detail sheet. [V17 — Player summary](../F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md) owns another person's permitted summary and safety entry. Each route must resolve to its real owning view rather than an inert disclosure.

The [F29 parent](../DOCKS.md), [F29-C competition rules](../F29-C-physique-rating-and-matchmaking/DOCKS.md), and [F29-G shared components](../F29-G-native-ui-components/DOCKS.md) remain the shared boundaries. F29-F does not change Elo arithmetic, settle a duel, infer identity from a photo, introduce a paid advantage, or redesign unrelated Profile badges.

## Chosen Composition and Tradeoffs

The composition is a compact minted-medallion register above a large vertical battle stage, not web pills placed over two faces. The timer is the first visual anchor. The You identity and complete badge group follow, then the Opponent identity and complete badge group. Only after both groups come the large You panel and the large Opponent panel. Player order never changes with rating, outcome, screen width, or a badge unlock.

Both owner groups are stacked even on a wide Mac. Each group's badge cells wrap along its own available width; the two inventories never interleave. This spends more vertical space than a single ribbon or three selected badges, but preserves ownership and makes every public badge visible without a hidden count. The central stage scrolls when necessary. People and readable type are not reduced to fit a fixed screenshot.

Tier and Placed share one octagonal medallion. Achievements use circular medallions with distinct sport glyphs. A current win streak is a plainly labeled record, not another trophy. This separates a changing status from a historical accomplishment and avoids repeating the placement caption on two adjacent ornaments.

Country is a small flag beside the handle, not a medal, national team, or matchmaking filter. Restrained orange, ivory-like white highlights, and dark enamel come from the existing Tmax language. Shape and captions carry meaning; expensive metals, color alone, or decorative checkmarks do not.

No extra ambient loop belongs to the rail. A service-confirmed unlock receives one tactile acknowledgement when it can do so without competing with the result reveal. Keeping the badge wall still during capture preserves attention for the true clock and pose instruction.

## Launch Catalog

Every earned launch badge is included in the permitted battle inventory. There is no equip action, selected-three limit, purchase, claim button, manual award, pinning, or local editing of earned state.

| Badge | Exact qualification | What remains earned | Removal and correction |
| --- | --- | --- | --- |
| First Bell | At least one effective, valid AI-judged Physique win, loss, or draw | The first completed judged comparison qualifies regardless of who won. Provisional judged matches count | Remove only when the effective history contains no qualifying judged result. An eligible forfeit, including a win by opponent forfeit, never qualifies by itself |
| Placed | The current effective Physique placement count reaches five rated results under F29-C | Valid judged wins, losses, draws, and eligible rated forfeit results count toward placement | This is current status, not permanent accreditation. Remove Placed and its current tier if a correction reduces the effective count below five. At one through four show Provisional; at zero show Unplaced |
| Ten Rounds | At least ten effective, valid AI-judged Physique matches | Judged wins, losses, and draws count once each, including provisional judged matches | Remove if a correction leaves fewer than ten qualifying judged results. Forfeits, no-contests, practice, searches, and merely submitted captures never count |
| Three Straight | The effective canonical Physique history contains a run of at least three consecutive rated wins under F29-C | Eligible opponent-forfeit wins count. A later ordinary loss or draw does not erase the historical milestone | Remove only if correction of the effective history leaves no qualifying run anywhere. Never present the medal as proof of the current streak |

No-contests, cancellations before Go, search timeouts, pending outcomes, rejected evidence, duplicate deliveries, local previews, and media-viewing actions award none of these badges. No-contests neither extend nor break a win streak. A rated loss, the person's own eligible forfeit loss, or a draw breaks the current run. Unsettled results have no effect.

The distinctions are intentional. Five eligible rated forfeits can complete placement without earning First Bell or Ten Rounds. Three eligible opponent-forfeit wins can earn Three Straight without earning First Bell. Ten valid judged draws can earn First Bell, Placed, and Ten Rounds without earning Three Straight. A valid judged loss can earn First Bell; the badge must not imply victory.

### Current tier and current streak

A placed account shows the service-confirmed current Physique tier, not its best-ever tier, predicted tier, exercise tier, or locally calculated tier. The tier remains scoped to Physique. The proposed F29-C boundaries are Iron at 0–799, Bronze at 800–999, Silver at 1000–1399, Gold at 1400–1799, Diamond at 1800–2199, and Champion at 2200–5000. These are inherited competition rules, not a new badge calculation on the client.

The combined medal's caption is the tier name followed by Placed, such as Gold · Placed. Its accessible meaning explicitly includes both the Placed badge and the current Physique tier. If placement is confirmed but tier information cannot be obtained coherently, show Placed with Tier unavailable; never guess the tier from a stale number. An unplaced or provisional account has no tier-shaped placeholder implying a future award.

Current streak appears after the achievement cells as Win streak followed by the confirmed whole count. A confirmed zero is displayed as zero. Missing information says Streak unavailable, not zero. Three Straight can remain beside Win streak 0 because one is a historical milestone and the other is the present record; their details explain this distinction. There is no flame, loss threat, or prompt to continue an unsafe session to protect a streak.

## Trusted Awards, Corrections, and Time Context

### One service-owned account record

The trusted service derives qualification from the effective Physique record and the account's actual identity. It owns the badge set, placement, current tier, canonical streak, award history, and correction status. A client may display an authorized cached snapshot with a freshness label, but cannot infer a new award from an animation, a local match counter, a provider answer, or a locally editable Profile field.

Finalization and authorized correction are the only competitive events that can change qualification. A pending model response, accepted pose, Ready action, report, country save, app reinstall, or public-listing change cannot earn a badge. A match contributes once. Duplicate responses, another window, reconnecting, and another device cannot add another copy of a badge or replay a competitive effect.

Each launch badge has at most one currently earned instance. Qualification records distinguish the qualifying match time from a later service correction or restoration time. If a corrected earlier event ceases to qualify but a later event still supports the badge, the badge remains earned and its provenance changes truthfully; it is not removed and awarded again for ceremony. Only the owner may see permitted links to their own qualifying match or review record. Another player's public badge detail shows its meaning and authorized status, not a private match identifier, opponent list, case, or explanation.

Country and public identity preferences use the authenticated account service. A local country draft is not a saved public change. Editing LocalProfileSnapshot badge previews, cosmetic selections, display levels, or an earned-milestone flag does not alter Physique achievements. There is no migration of those editable previews into competitive authority.

### Effective-history corrections

F29-C's canonical match ordering is used for milestones and streaks, including outcomes finalized while a participant was offline. Corrections affect the reviewed event at its original place in that ordering; they are not appended as a new win at the time of review. Later valid matches keep their actual settled outcomes and rating inputs. Re-evaluating a badge or a streak does not authorize rerating the rest of the league or calling the judge again.

A reviewed loss changed to no-contest can remove a break between otherwise consecutive wins and establish Three Straight. A corrected win changed to a loss can remove the only qualifying run. A valid judged win changed to a valid judged draw still counts toward First Bell and Ten Rounds but changes streak meaning. These consequences follow the corrected effective history, not a blanket rule to remove every medal after any review.

While a correction settles, retain the last coherent permitted snapshot with Updating after review. Do not combine a new placement count with an old placed tier or announce an unconfirmed removal. New rated entry follows F29-C's unsettled-rating restriction. Ordinary badge-detail reading, safe exit, and safety access remain available.

When a correction settles, badge set, placement, current tier, and current streak change together with the associated confirmed record. If a badge is no longer earned, it disappears from the public earned rail. The owner sees Badges updated after review and can open the relevant explanation in V25 and the existing private correction route. Public viewers see the corrected inventory, not an allegation, appeal status, or shaming revoked-medal design.

If a later supported correction restores qualification, restore the single earned instance. Present Badge restored after review to the owner, not a new match victory. A correction that first establishes qualification uses the same sober updated-after-review treatment rather than an original-win ceremony. Merely submitting a dispute does not remove a medal; the current confirmed record remains effective until an authorized decision settles.

### Current identity versus a past match

The reusable battle rail presents current permitted battle identity and is labeled Current identity when embedded in a completed or historical result. Every current tier and streak in that rail comes from the same coherent current snapshot. This area is separate from F29-C's comparison facts: original match-time Physique Elo, placement, scores, and opponent attribution remain explicitly labeled as match-time context and are not overwritten by a current-profile refresh.

Access to a historical match is not permission to retrieve an opponent's current profile. When current identity is not authorized, the host keeps the permitted match-time attribution and states Current identity unavailable instead of filling a current rail from an old badge list. During active pairing, the participation contract supplies the permitted paired identity even when the person is not publicly listed. No newly earned badge is hidden behind a history-only award screen once a current inventory is authorized.

Historical outcome and correction records remain distinguishable under F29-C. A removed badge must never reappear as currently earned because an old screen is reopened or an earlier cached inventory arrives. Country withdrawal, blocking, account deletion, and identity-access revocation override old snapshots immediately. An audit record is not permission to republish a removed flag, handle, avatar, or public achievement collection.

### Removal is not always loss of an achievement

A loss, inactivity, lower current Elo, media expiry, ordinary pose-image deletion, changing a handle, or removing a country does not revoke historical First Bell, Ten Rounds, or Three Straight. Lower Elo changes the current placed tier, not historical milestones. Placed changes only when the effective placement state changes.

Unlisting removes public discovery, not the underlying earned record or paired identity required for participation. A restriction may remove visibility or participation without proving that every older match was invalid. Blocking removes the corresponding discoverable identity and media for the affected viewer, not the other account's rating or legitimate achievements. Account deletion removes associated identifying content under F29-E; any lawful retained record is not a rediscoverable badge profile.

## Medallion Family

### Shared material and hierarchy

Reuse the existing near-black background, dark surface levels, toolbar orange, primary white, readable secondary ink, Inter Black headings, and Inter Regular labels. The medallions suggest dark enamel with a restrained orange metal edge and ivory-like highlight, using the existing palette rather than another global theme. Native shared controls retain their own platform materials; medals themselves are opaque artwork, not miniature glass windows over the camera.

A tier medallion is a softly beveled octagon with a quiet internal field. An achievement medallion is circular with a shallow bottom notch. Both use the same stroke weight, lighting direction, and restrained rim. The notch and silhouette distinguish achievements from the changing tier without relying on color. No check inside a blue rosette, verified-style avatar ring, police or medical insignia, government seal, flag shield, or visual claim of trusted adulthood is permitted.

Cells place the medallion beside a short visible caption on a clear or understated surface. Do not put long names or Elo numerals inside tiny artwork. The combined Placed/tier cell names both meanings, while the owner's rating line separately names Physique Elo. Each cell grows for localized captions and accessibility text. Text can wrap onto additional lines; it is not shrunk, clipped, or limited to an inaccessible miniature font to preserve a row count.

The visual medallion scale follows the app's type and spacing system; interaction targets remain independent of the small illustration. iPhone uses the existing minimum forty-four-point target convention. Mac uses native control density and visible focus rather than surrounding every small symbol with phone-sized chrome. Neither uses absolute screen coordinates or a fixed number of cells per row.

### Original glyph direction

| Element | Chosen glyph and treatment | Meaning boundary |
| --- | --- | --- |
| Iron tier | A single broad horizontal ingot inside the octagon | Current tier, not a body or strength measurement |
| Bronze tier | Two joined rising wedges | Distinct shape, not merely a bronze tint |
| Silver tier | Three separated upright blades with level tops | Readable at small size; no tiny engraved text |
| Gold tier | A four-ray sporting sun around a square center | Not a verification star or approval seal |
| Diamond tier | An outlined angular diamond with a simple central facet | No spinning gemstone or collectible purchase cue |
| Champion tier | Two open upward chevrons over a short base | No crown on a participant's body, no superiority or identity claim |
| First Bell | A compact boxing-bell silhouette with a single clapper | First valid judged round, not a notification control or first win |
| Placed without available tier | A simple five-mark track inside the tier octagon, captioned Placed | Five rated results confirmed; no inferred tier |
| Ten Rounds | Two clearly separated rings around a bold central 10 | Ten valid judged matches; not ten wins or ten daily workouts |
| Three Straight | Three connected rising pennant shapes | Historical three-win milestone; deliberately no live-streak flame |
| Current streak | Plain label and count with a small neutral consecutive-mark symbol if helpful | A record outside the achievement family, including a truthful zero |

These describe original future native artwork. No asset is generated or claimed to exist in this pass. Use original vector geometry or appropriately licensed artwork in future implementation, not copied screenshot badges or the photographed people. Missing decorative artwork must not hide the real name, qualification, or action; all launch glyphs must be finished before the medallion feature is handed off as implemented.

### Detail meaning

Activating an owned medal opens V25 with that exact badge selected; activating an opponent medal opens the same catalog explanation in the authorized read-only player-summary context. The source owner and badge remain explicit. The content includes the short badge name, Earned or the actual unavailable/update state, the complete qualifying rule, historical-versus-current meaning, and any permitted owner-specific earning or correction date.

For Three Straight, the first detail sentence is Earned for a past run of three Physique wins. Current streak is shown separately when known. For Placed, it is Five rated Physique results completed. It explicitly says that placement is not identity verification. First Bell says First valid AI-judged Physique match, win, loss, or draw. Ten Rounds says Ten valid AI-judged Physique matches. Detail wording does not replace concise visible captions on the rail.

An unearned badge may be explained in the owner's V25 collection using its honest Not earned state. Unearned catalog entries do not appear as earned battle medals. Do not reveal another player's private progress toward a locked badge. An already earned medal has no claim, equip, edit, or retry-earning control.

## Complete Top Rail

The stage order is the real phase timer, You identity group, Opponent identity group, large You panel, then large Opponent panel. All badges from both groups are above both player panels, not one group's badges placed halfway down between the two people.

Each owner group contains the role and handle, optional flag, scoped Physique Elo or placement text, then the complete wrapping badge flow. The own role reads You; the paired role reads Opponent. A permitted avatar may accompany the handle but cannot become another large rival portrait that competes with the player panels. A missing avatar uses the neutral authorized silhouette, not an automatically uploaded local photo.

Within each group the stable order is the combined Placed/current-tier medal when actually placed, First Bell, Ten Rounds, Three Straight, and then the separate current-streak record when available. Missing earned items leave no fake empty slots. This order is catalog order rather than rarity, price, unlock recency, or inferred superiority. New badges insert into this order without moving the reader to the start of the stage.

Before any earned rating exists, show Unplaced, not the hidden 1,000 pairing seed. With one through four effective rated results, show actual Physique Elo and Provisional with the count out of five. A confirmed empty inventory says No badges yet. A loading or unavailable inventory never uses that empty message.

Every public badge is represented as a named, operable cell. There is no three-slot cap, hidden +N, collapsed complete inventory, clipped horizontal ribbon, auto-scrolling ticker, hover-only explanation, or badge carousel. Opening V25 discloses rules and provenance, not the existence of badges suppressed from the battle surface. No earned-badge preference can make a partially selected collection look complete.

Rails remain above the players in document order but are not an unbounded pinned wall. Only the actual clock and safe-action area remain reachable while the central content scrolls. Short screens can show part of one large participant at a time; they never solve the height constraint by shrinking both participants into thumbnails. Full content remains reachable through ordinary scrolling and accessible headings.

## Native iPhone Composition

Use the existing page header, safe-area handling, measured menu clearance, and shared control styles. The real timer has the strongest typographic emphasis at the top during a timed phase. Badge groups are visually subordinate through type and surface contrast, not by clipping their content. The active phase's concise instruction and primary action belong to the host stage; F29-F does not add a second dominant Find opponent, Ready, or Capture button.

Each owner heading takes its own available line. Handle and flag stay together where possible; long handles can wrap without losing You or Opponent. The full accessible handle is preserved. Medal cells wrap below. Larger text turns the flow into fewer columns or full-width rows with larger captions. Phone landscape and short devices scroll the same vertical composition. No landscape breakpoint changes the players to a horizontal matchup.

Tapping a medal or the own Identity entry routes to V25 in the host's native sheet or navigation presentation. The sheet can grow and scroll for rules and correction explanations rather than having a fixed compact height. It offers a visible Close or Back control; swipe dismissal is supplementary and cannot accidentally abandon an active match. Closing returns to the invoking medal or owner heading at the same stage position.

During a live match, the host keeps the real clock and exit consequences clear when identity details are opened. If a modal replaces or obscures the capture presentation, capture acquisition stops and private preview content is shielded immediately; opening details is not a pause of the shared deadline or consent to forfeit. Restoring the stage reconciles the same match and resumes capture only through the host's valid intentional recovery path.

## Native macOS Composition and Lifecycle

macOS is a native macOS 14-or-later surface, not Catalyst, an embedded web page, or a magnified phone sheet. Preserve the normal title bar, traffic-light controls, existing window identity, and current eight-hundred-by-six-hundred minimum. F29-F does not raise the app-wide minimum.

At the minimum window size and on laptops, the center stage scrolls vertically beneath the timer and reachable safe actions. Both complete owner groups precede both large vertical panels. The body preview is aspect-fit and remains substantial; badge count is never a reason to reduce the participants to tiny cards. Normal full-screen and external-display widths can offer more wrapping space and comfortable margins, not side-by-side players or two adjacent owner inventories.

On a wide window, a selected identity or badge explanation may use the host's native trailing inspector. The entire badge rail remains in the central stage; the inspector is supplementary, not overflow storage for missing medals. When available space cannot support both a usable vertical stage and readable details, use the same native detail sheet instead of compressing the participants. Preserve the selected badge and focus when this presentation changes during live resize. Text, wrapping, and imagery respond to measured content space, not device-name breakpoints or hardcoded coordinates.

The toolbar uses the host's Identity, Safety, and state-aware exit actions. The country editor remains V25's native form and region picker; F29-F adds no custom picker window, menu-bar collection, or trophy-management panel. Pointer hover can lightly emphasize an actionable cell and show ordinary help, but the caption, action, and rule are also reachable by click and keyboard. There is no pointer-tilt medal or hover-revealed only control.

Keep Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O unchanged. Return and Space activate only the focused semantic control. Typing a country search, account field, or report must never trigger Capture, Ready, a badge action, or a global Return handler. Escape first closes the current non-destructive detail or handles a meaningful country draft through V25; it does not jump past a sheet into Forfeit. From the active stage, the host's explicit state-aware exit behavior applies.

Cmd-W and quit use the real current-match consequence confirmation where the platform permits. Before Go, cancellation has no rating consequence; after Go, only an otherwise eligible explicit confirmed forfeit creates the rated loss. Final results are not forfeited by closing a window. Force quit cannot be prevented or treated as confirmed voluntary forfeiture.

Identity reading requires no camera permission. TCC denial or restriction, a busy or absent camera, and an external or Continuity-camera disconnect are handled by the owning capture surface while the identity rail retains only permitted account state. A medal, country flag, or old avatar cannot disguise a dead camera as a live preview. There is no rated file-picker or prerecorded substitute. Returning from System Settings or reconnecting hardware does not restart a match or extend its deadline.

Inactive, minimized, backgrounded, locked, or otherwise interrupted capture stops and sensitive content is shielded immediately. Badge decoration stops too. On return, refresh the same authorized match and identity without replaying awards. One account has one active match and camera owner across windows and devices. A second window may show authorized read-only identity but cannot start another capture, consume another allowance slot, or run a second award ceremony.

## Optional Self-Declared Country or Region

Country is an optional account preference, not eligibility evidence. V25 labels the field Country or region and explains Self-declared. Shown beside your handle. Its initial value is Not shared. No country is preselected from IP, GPS, device locale, SIM, billing, a photo, language, or an account address. The launch feature requests no location permission and supplies no country matchmaking or standings filter.

The person can deliberately choose a supported country or region, change it, or choose Not shared. The selection is a native searchable picker with localized readable region names. There is no free-text national claim, document upload, flag verification, flag purchase, or permission to edit another player's country. V25 owns the editing interaction; its changes obey the following shared state meaning.

| Country state | Visible meaning and action | Public consequence |
| --- | --- | --- |
| Never chosen or intentionally removed | Not shared in the owner's editor; no flag or blank flag box in the rail | No inferred replacement and no participation penalty |
| Saved supported region | Flag emoji beside the handle, with the full readable region in details | Public only within authorized identity audiences, not universal discovery |
| Saved region with unsupported flag glyph | Neutral globe and readable region name rather than broken letters or a substitute nation's flag | The self-declared value remains truthful; accessible name is unchanged |
| Region absent from the current picker catalog | Region unavailable with Change or Not shared for the owner | Do not silently remap it to another country or present a guessed flag |
| Unsaved selection | Selected option remains a clearly labeled draft in V25 | Existing confirmed public value remains until acknowledgement |
| Saving | Saving with duplicate submission disabled; safe navigation remains available | Do not announce Saved or broadcast the draft locally as confirmed |
| Save rejected or offline | Country not saved, the practical reason, Retry, and Cancel | Retain the person's unsaved choice for the current authorized editing session; do not silently apply it on a later launch |
| Save outcome unknown after interruption | Checking saved country, then the actual account value or Cannot confirm | Refresh authoritative state before resubmission; do not create conflicting optimistic values |
| Another device changed the value while editing | Country changed on another device, current confirmed value, and the preserved local choice | No silent overwrite; the person can use the confirmed value or explicitly save their new choice |
| Removal requested but not confirmed | Remove the flag from the requesting device's visible surfaces immediately and say Removal not confirmed if necessary | Do not promise removal on other devices or public surfaces before service acknowledgement |
| Account changed, signed out, or deleted | Close the old editor and clear its visible draft and identity | No previous account's flag or badges flash in the next session |

The flag's accessible name includes the localized region and Self-declared country or region. A flag emoji is not read as the only label. Where text expansion or right-to-left layout changes the line, maintain the association with the correct handle without embedding it in the handle string or making its position a sole ownership cue.

Country does not enter a badge predicate, rubric, Elo calculation, skill band, moderation-goodness claim, or pose evidence. The person may participate without sharing it. Removal is a privacy preference, not cancellation of an achievement or an implicit match forfeit. A current removal or loss of authorization prevents historical surfaces from republishing the old flag.

## State, Action, and Recovery Contract

| State | Rail and details | Available action and safe outcome |
| --- | --- | --- |
| Signed out or restoring account | No old private identity; ordinary account-loading or signed-out text | Use existing authentication. Do not open another account's cached collection |
| Searching with no real pair | Own confirmed group only; host's honest search status | Cancel search or open own identity. No invented opponent rail |
| Newly paired identity loading | Real permitted handle or neutral Opponent identity, Loading badges where needed | Keep safe exit and report access. Do not display fabricated medals to fill space |
| Fresh empty collection | Unplaced or actual provisional state, No badges yet, actual known streak | Own V25 can explain the catalog; no claim button or paid shortcut |
| Fully available collection | Every earned badge in stable order, current tier only when placed, separate current streak | Each cell opens its exact read-only meaning; own country remains separately editable |
| Badge data loading with a permitted prior snapshot | Complete last confirmed inventory, Updating and its available freshness time | No disappearance implying revocation and no optimistic new award |
| Offline with permitted cached state | Last confirmed identity with Offline and last-updated context | Read cached meanings; Retry when useful. No new rated entry or public country save is confirmed locally |
| Offline or failed load without an authorized snapshot | Badges unavailable, not No badges yet | Retry the affected identity. Match recovery remains the host's real service flow |
| Mixed or incomplete competitive refresh | Last coherent snapshot or Updating identity if none remains | Await or retry the coherent state; no new tier beside an old placement count |
| Known badge with detail unavailable | Keep its confirmed name and earned state; Details unavailable in the owning detail view | Retry details or Close. Do not unearn the badge or show another owner's provenance |
| Ready, countdown, capture, uploading, or judging | The last confirmed inventory, actual phase, no speculative medal | Host timing and safe actions continue. Accepted poses or a likely outcome do not advance awards |
| Confirmed valid judged win, loss, or draw | Apply the complete confirmed current inventory and status | A newly qualified own badge can acknowledge once. Final outcome and actions are usable immediately |
| Eligible rated forfeit | Placement and streak may change under the catalog; judged-round count does not | No First Bell or Ten Rounds credit for the forfeit, no invented physique score or gallery |
| No-contest | No new badge contribution, no current-streak change caused by this match | Show host's actual no-contest reason and confirmed allowance consequence, not a consolation award |
| Review pending | Existing effective earned state; private case status only in its proper context | No speculative removal, verified-innocent badge, or public allegation |
| Correction settling | Updating after review and coherent last confirmed state | Read details or safe exit; no new pairing with unsettled rating |
| Correction removes or restores qualification | Updated inventory with the owner's sober change notice | Open permitted explanation; no duplicate award, humiliation, or private case disclosure to opponents |
| Block pending or effective | Shield related identity/media locally and show Blocked player without flag or public collection | Safety remains reachable. Pending service protection is labeled honestly; block after Go is not automatic forfeit |
| Opponent deleted or identity access unavailable | Unavailable player, neutral silhouette, no current profile action or stale identifying badges | Preserve only authorized own outcome and nonidentifying facts; no rediscovery through a medal link |
| Camera unavailable or disconnected | Real identity can remain readable, but player content is a camera-unavailable state | Host offers useful Settings, Retry, or exit. Identity cannot authorize a substitute input |
| Background, minimized, or another controlling window | Private content shielded and decorative work stopped | Restore the same service state; no additional charge, deadline reset, or replayed unlock |

An empty catalog, an inaccessible current identity, an unknown record, a revoked earned state, and a missing picture are different facts. Use their actual status rather than one generic blank medal or endless spinner. The safe background and meaningful non-image labels remain usable when artwork or images cannot be displayed.

## Accessibility, Focus, and Minimal Copy

The owner groups are accessible headings. The reading sequence follows the visual hierarchy: phase clock and reachable safe actions, You identity and every named badge, Opponent identity and every named badge, then the vertical participant panels. Heading navigation lets a person reach the player stage without reading every medal on every visit; it does not collapse or conceal medals from the surface.

Each medal is one semantic button with owner, badge name, actual earned/current status, and a useful action hint. Decorative facets and duplicated caption text are not separate accessibility stops. Suitable full names include You, First Bell, earned; Opponent, Ten Rounds, earned; and You, Placed badge, current Physique tier Gold. Three Straight explicitly adds Historical three-win milestone. Current streak reads Current Physique win streak, zero consecutive rated wins when that is the real value. Stale or updating state is announced once at the owner group and remains inspectable.

Provide stable Voice Control names matching visible captions, disambiguated by owner when needed. Full Keyboard Access, Switch Control, and VoiceOver can activate every medal and country action. On Mac, Tab navigation follows owner grouping and catalog order; system keyboard navigation reaches native sheet, inspector, picker, Retry, and Close controls. Focus rings are visible against the opaque dark surfaces. No action depends on a long press, drag, hover, or color.

Opening details places focus on the selected badge's heading, not a decorative enlarged medal. Returning restores the invoking cell. If a correction removes that cell, return to its owner heading rather than the top of the app or an unrelated badge. If an identity loses authorization, close its sensitive detail and focus the safe unavailable heading. A background refresh never steals focus from a country draft, report, or Capture control.

Allow long and localized handles, mixed-direction text, full country names, and large Dynamic Type. Captions wrap and surfaces grow. Do not copy nearby Ranked Dynamic Type clamps or minimum-scale rules. Increased Contrast strengthens outlines and text. Reduce Transparency uses opaque readable controls and surfaces. Medallion shape, text, and status remain understandable in monochrome.

The default rail copy is limited to owner, handle, optional flag, scoped rating or placement, badge names, current streak, and a freshness or error line only when relevant. Details hold rules and provenance. Do not hide self-declaration, correction meaning, failed-save recovery, safety access, or active-match exit consequences to meet a word limit.

## Motion, Interruption, and Energy

| Trigger | Chosen movement | Timing and interruption | Reduced or constrained behavior |
| --- | --- | --- | --- |
| Press on a medal or identity action | Shared tactile press, not a spinning coin | Reuse response 0.24 seconds and damping fraction 0.88; release or cancellation returns to rest and never repeats the action | No scale with Reduce Motion; retain clear pressed appearance |
| Pointer hover or keyboard focus | A quiet outline or surface emphasis | About 140 milliseconds; immediate visible focus, no travel or delayed action | Static focus/hover emphasis; no hover-only content |
| Initial confirmed inventory arrival | Captions and medallions become visible together | 160-millisecond opacity transition; no award bounce for loading existing data | Immediate appearance or a short opacity change |
| Real pairing or host phase transition | Owner groups keep their order as the stage settles | About 280 milliseconds, within the shared 260–320-millisecond continuity range; no medal travels through a body panel | Stable layout with immediate or brief opacity replacement |
| First observation of a newly earned own badge in the active result session | One medal settles from roughly 0.96 scale through at most 1.04 to rest, with one restrained rim emphasis | Settle within 520 milliseconds; name, status, outcome, and actions are available at the start. If several badges unlock, only the first in catalog order uses the focal emphasis; the others appear in the same update | Static earned medals and one readable announcement; no scale or rim motion |
| Result reveal already owns the focal event | Newly earned medals appear without a competing celebration | Use at most the 160-millisecond opacity change within the shared total result window of 900 milliseconds; do not append a second ceremony after score and Elo | Same immediate final inventory |
| Settled current tier or streak change | Replace the relevant glyph/caption or number in place | About 180 milliseconds; final meaning is immediately accessible. No rank roulette, count through false intermediate streaks, or promotion inferred before settlement | Immediate final tier and count |
| Settled correction, removal, or restoration | Updated text and earned inventory replace prior state without celebratory travel | About 180 milliseconds for ordinary opacity; revoked earned status stops being actionable immediately. Newer revision cancels the old animation | Immediate update and one correction announcement |
| Country save confirmed | Replace the flag/name in the owner's line | 160-millisecond opacity transition after acknowledgement; do not morph one national flag into another | Immediate truthful value |
| Country removal, block, deletion, consent or identity-access withdrawal | Clear the affected identifying or sensitive content | Immediate, before decorative dismissal; never leave the old flag or image under a fading overlay | The same immediate protection |
| Detail opening or closing | Native sheet, navigation, or inspector transition | Platform behavior; all content and Close remain usable. Resize preserves selected detail and cancels obsolete travel | Native reduced-motion behavior, no custom zoom into a medal |

A badge unlock requires a confirmed award event and a continuously relevant visible session, not mere first rendering of an existing item. Reopening history, refreshing, switching tabs, restoring offline state, reinstalling, changing windows, or receiving the same event again shows the earned state without replaying the ceremony. An offscreen event is not queued into a future batch of animations. Announce a batch of actual earned names once, coordinated with the host's result announcement, not every interpolated visual step.

The rail has no repeating pulse, glint, shimmer, ticker, rotating medal, parallax, breathing wall, or skeleton trophy animation. The host may use its single quiet ambient layer; F29-F does not add another. At most one focal event is active across the visible stage. Countdown, timer digits, accepted poses, score reveal, and Elo motion remain with their F29-G owners; badges do not schedule or reset them.

Pause decorative work when the rail is offscreen, the app or window is inactive, the window is minimized, or the surface is hidden. Low Power Mode and thermal constraints use static medallions and minimal opacity feedback. A mid-animation setting or lifecycle change settles immediately to the latest confirmed state and discards queued decoration. Authoritative clocks continue. Camera stop, safety protection, navigation, and correction authority never wait for an animation completion.

No animation frame or timer tick may trigger identity refreshes, provider work, file reads, body-image decoding, font measurement, camera reconstruction, or global page layout invalidation. Stable badge identity and native layout preserve focus and ownership across wrapping and data updates. There is no requirement for a custom GPU renderer or a claim of measured frame rate.

## Privacy and Non-Goals

The service-authorized public identity is not proof of a real-world identity. Country is self-declared. Placed is a competitive state. No medal asserts verified adulthood, nationality, gender, shirtless eligibility, real physique, health, absence of reports, innocence, trustworthy behavior, or judging accuracy.

Do not add anatomy, gender, body-fat, skin-exposure, unsafe exertion, dieting, daily-dehydration, purchased rating, moderator-goodness, or absence-of-reports achievements. There is no incentive to expose more skin, bypass face masking, continue through pain, or play while unsafe. The catalog has no paid competitive benefit and never changes allowance, score, Elo sensitivity, or matchmaking.

Handles, flags, avatars, badges, ratings, current streaks, and all UI chrome remain out of judge inputs. Every transmitted candidate and still uses the clean locally face-obscured capture, never a screenshot of the battle interface. Redaction failure stops transmission. Bystanders remain invalid even when masked. The own live preview remains local; opponent capture-time content remains an authorized avatar or silhouette and actual stage/count, never live video, early stills, chat, or microphone.

Badge details never open pose media. Only an intentional View poses action in a valid finalized AI-judged win, loss, or draw can expose currently authorized moderated stills under F29-D and F29-E. Forfeit and no-contest have no gallery. Ordinary expiry is twenty-four hours; identity or badge access never extends it. Report and Hide remain available without enlarging content. Block after Go shields and excludes future pairs but is not automatic leaving or rerating.

Preserve the existing Profile two-side shape. A named Physique entry may use the existing route, but there is no third side indicator, mixed exercise/physique badge, automatic avatar publication, or app-wide cosmetic rewrite. Generated or purchased decoration is not an earned record.

## Files and Dependencies

These locations describe ownership and prospective integration surfaces, not existing implementation claims.

- [This product context](DOCKS.md) owns catalog, identity, medal, rail, and correction meaning.
- [Dedicated F29-F future implementation brief](../../../prompts/F29-physique-duels/F29-F-phase-1-battle-identity-and-badges.md) owns the bounded connected implementation assignment.
- [V25 — Badges and country](../F29-A-page-and-match-flow/F29-A-y-badges-and-country/DOCKS.md) owns collection, selected-badge explanation, and country editing; [V17 — Player summary](../F29-A-page-and-match-flow/F29-A-q-player-summary/DOCKS.md) owns the permitted opponent context.
- [F29-A match journey](../F29-A-page-and-match-flow/DOCKS.md) owns ready-room, battle, waiting, result, and history hosts. Each composes the complete rail without changing temporal or privacy meaning.
- [F29-G components](../F29-G-native-ui-components/DOCKS.md) owns the shared clock, player panels, atmosphere, result choreography, and native Mac shell. Badge placement does not fork those components.
- Prospective native badge and identity components belong under TimeMaster/Views/Physique/; account-bound representation and retrieval belong with the existing physique models and authenticated services rather than LocalProfileSnapshot.
- The existing ranked_server service and persistence organization is the authority integration surface for the Physique record, badge qualification and corrections, optional country, visibility, and deletion. F29-F cannot ship a client-derived substitute when these contracts are absent.
- [Theme](../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign](../../../TimeMaster/Utilities/ProfileDesign.swift), and [shared glass controls](../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own the reused native visual language. No STYLES.md or parallel global theme is introduced.
- [Ranked components](../../../TimeMaster/Views/Ranked/RankedComponents.swift) supply action and earned-crest language, not a requirement to copy text clamps or exercise scoring. [Local profile models](../../../TimeMaster/Models/LocalProfileModels.swift) identify the editable cosmetics that are not competitive authority.
- [TmaxApp](../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands](../../../TimeMaster/App/TmaxCommands.swift) own native window and command conventions. Target compatibility remains iPhone iOS 16 and native macOS 14 or later under the existing project configuration.

Real authentication, canonical outcome and correction records, coherent placement/streak authority, permitted identity access, country persistence, safety restrictions, and deletion behavior must be implemented and human-reviewed before production UI is connected. F29-B supplies valid judged-outcome meaning; F29-C supplies competition chronology and corrections; F29-D supplies safety visibility; F29-E supplies account access and retention. The separate V25 and battle hosts must have actual destinations before their rail actions are presented as working. The documentation areas are independent writing assignments, not independently shippable competitive features.

## References and Compatibility Decisions

- [Supplied battle reference](../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): borrow the obvious timer and direct identity hierarchy, not side-by-side players, purple/brown pills, text, faces, or footage.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices: flexible windows, full-screen support, usable density, keyboard/pointer input, and native commands support the scrolling vertical stage with supplementary details rather than a stretched phone composition.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback: purposeful, brief, optional, interruptible feedback supports the one-time medal acknowledgement and static accessible equivalent.
- Installed SwiftUI Pro accessibility and design guidance informs semantic controls, scalable type, and stable focus. Installed SwiftUI Animation guidance informs scoped state changes and cancellation. Their newest-OS examples do not authorize raising the existing deployment targets or depending on newer-only animation and glass APIs without public fallbacks.
- The owner-selected dimillian/swiftui-ui-patterns context remains the UI-pattern direction; use the existing project architecture and the relevant installed native guidance, not a parallel UI framework.

The user-directed vertical pair, all-badge rails, native Mac requirement, and tactile event motion supersede older iPhone-first, optional two-column, or fade-only wording wherever it remains in inherited context. No screenshot reference overrides privacy, authoritative state, current permissions, or the prohibition on using UI chrome as judge evidence.
