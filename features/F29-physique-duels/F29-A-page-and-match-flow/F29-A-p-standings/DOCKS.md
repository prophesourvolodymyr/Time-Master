# F29-A-p — Physique Standings

## Purpose and Scope

Standings is a native, identity-and-numbers view of the one Physique ladder. It presents real, placed accounts that explicitly allow public Physique listing, their actual shared positions, current Physique Elo, and permitted public identity and achievements. It is not a body-photo feed, a second judgement, a mixed exercise leaderboard, or a way to discover private players.

This document selects the standings composition and its behavior for iPhone and native macOS. It does not claim an implemented view, an approved service contract, an accepted prototype, or completed human verification. The [F29 parent](../../DOCKS.md), [page flow](../DOCKS.md), and [competition authority](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) retain their ownership.

Standings owns its ledger, own-standing summary, freshness and paging feedback, and navigation to permitted player and privacy surfaces. [Player summary](../F29-A-q-player-summary/DOCKS.md) owns the public player detail. [Privacy and sharing](../F29-A-w-privacy-and-sharing/DOCKS.md) owns the public-listing choice and its actual saving states. [Badges and country](../F29-A-y-badges-and-country/DOCKS.md) and [F29-F](../../F29-F-battle-identity-and-badges/DOCKS.md) own identity editing and badge meaning. Standings does not create competing profile, consent, badge-editor, report, or camera screens.

## Chosen Composition and Tradeoffs

Use a single ranked ledger with a distinct Your standing summary, not a podium, image carousel, or collection of oversized winner cards. A steady leading position lane, readable handle, and aligned current Physique Elo make the actual competition legible. The app's orange is a locator for the person's own account and real selected actions, not a claim that the first visible player is superior in health or appearance.

Every row carries a complete, wrapping public badge rail. Taller rows are an intentional cost of showing all legitimate achievements without a three-badge cap, hidden count, ticker, clipping, or hover-only information. The ledger scrolls instead of shrinking type or substituting dots for earned badges. No avatar or body image is required in the row; this surface deliberately uses no player photograph, including a locally saved profile photo. The existing public-player summary can present only its separately permitted identity content.

A current own-standing summary is more useful and less error-prone than fetching the entire ladder to find the person's row. It is a separate service-confirmed value, not a position computed from loaded rows. There is no jump-to-me endpoint assumption, second Around you ladder, country filter, search field, seasonal tab, paid placement, or rank-change arrow in this scope.

The active battle composition is not embedded in standings. There is no decorative countdown, local camera, pose gallery, body score, or two-person matchup on this screen. Returning to a real battle uses its existing owner: real timer first, both complete owner-grouped identity and badge rails next, then two LARGE VERTICAL player panels, You above Opponent, at every iPhone and Mac width. Standings must not introduce a miniature horizontal battle as an inspector or loading substitute.

## Entry, Hierarchy, and Visible Copy

The Physique lobby opens this view through Standings. A legacy label such as Leaderboard may route here, but the visible and accessible destination is Physique standings. Closing returns to the invoking Physique route and its retained scroll state, not a new queue or the exercise ladder.

The hierarchy is:

- The native navigation or toolbar heading Physique standings, with Back or Close, Refresh, and About standings.
- Your standing: the authenticated person's coherent position or precise placement/listing state, own Physique Elo when earned, applicable tier, complete authorized badge rail, and Public listing access.
- A compact freshness line. As of is followed by the service snapshot time; a fuller date and time is available through About standings. Unknown time is Snapshot time unavailable, never an invented Just now.
- The ledger heading and column meanings: Position, Player, and Physique Elo. A compact phone row also labels its rating so a number cannot be mistaken for an AI body score.
- Any quiet Standings changed notice and its Refresh action, the actual player rows, and the page-end Load more, retry, or End of standings state.

About standings uses the native information presentation. Its short explanation covers descending current Physique Elo, shared ties, explicit listing, five-result placement under F29-C, and privacy omissions. It explains that a gap does not identify a hidden account and that public listing does not publish poses. It links to the existing rules and privacy owners rather than creating another custom rules page.

There is one obvious recovery action at a time. Refresh replaces the normal action while refreshing; a failed later page offers Retry loading more beside the retained ledger. Genuine empty content says No public standings yet. A permission-filtered view says No players to show. A network failure says Standings unavailable, not No players yet. Secondary reasons remain readable rather than disappearing behind an unexplained warning icon.

## iPhone Composition

Use the existing near-black background, shared dark surfaces, white primary ink, readable secondary ink, Inter heading/body roles, orange shared actions, and measured safe-area and page-menu clearance. Do not establish a separate sports palette or a glass layer behind every number.

The normal native navigation header holds the title and toolbar actions. Your standing is the first card in the same vertical reading flow as the ledger; it is not an unlimited pinned badge wall. Its position or state is the strongest text, followed by the actual Physique Elo and listing status. A fine orange leading marker and the word You identify the person's own content without depending on color alone. If the own account also occurs in a loaded public page, that row uses the same You identification without removing another player's row or changing page order.

A normal row has a leading position lane, handle with optional declared-country treatment, and a trailing current-rating group. Beneath that first line, the full badge rail wraps within that player's row. A permitted short record can follow in a quiet subordinate line; it is absent when public disclosure does not permit it. The entire row grows with content. Long handles, large positions, and accessibility text reflow the rating beneath the identity instead of clipping, scaling the font down, or forcing horizontal scrolling. The full public handle remains available to assistive technology.

The row's Player details action opens F29-A-q. A separately named Player actions menu offers the permitted report and block routes. A badge's meaning is reachable through player details; its visible symbol and short name are not replaced by an unlabeled decorative mark. No long-press, swipe, or context menu is the only path to an action. Interactive controls are distinct rather than nested inside another button.

Pull to refresh and the toolbar Refresh action have the same meaning. Load more remains a named control; this design does not depend on invisible automatic infinite paging. At the largest Dynamic Type sizes, summary, badges, labels, status, and actions all expand and scroll. Forty-four-point action areas follow the existing iPhone convention. Controls stay clear of the app's measured top or bottom navigation rather than a guessed screen-edge spacer.

## Native macOS Composition

This is native macOS 14 or later, not Catalyst, a web table, or a phone sheet centered on a large canvas. Keep the existing title bar, traffic lights, window management, and normal toolbar. Do not raise the app's eight-hundred-by-six-hundred minimum.

The toolbar contains the title, Refresh, About standings, and the existing route-back action. In the content area, Your standing is a concise horizontal summary when measured width permits; its status, Elo, badges, and Public listing control wrap into a vertical arrangement when needed. The ledger is a native single-selection list with aligned position, player, and Physique Elo headings. Variable-height rows preserve complete badge wrapping; a rigid fixed-height spreadsheet would hide achievements or make pointer and accessibility targets unreliable. These headings do not pretend to be sortable: the competitive order is always current Physique Elo. There is no alternate alphabetical or country sort presented as rank.

At the minimum window size and in a short laptop window, the ledger and summary scroll vertically while the toolbar remains usable. Neither the summary nor its badges consumes the entire fixed viewport. At larger laptop, full-screen, or external-display sizes, comfortable ledger width and a reusable F29-A-q player inspector use available space without stretching small text across the full display. Use the inspector only when both it and the complete ledger have usable measured space; otherwise the same player summary opens in a native sheet. This is supplementary detail, never a side-by-side player matchup.

Clicking a row selects it and, when available, shows the authorized summary in the inspector. Arrow-key selection follows native list conventions when the list owns focus. Return on the focused player row opens or focuses its summary; Space acts only according to the focused semantic control. Neither key is captured globally while someone types in a report or privacy form. An ellipsis menu, native context menu, and keyboard-accessible Player actions give equivalent safety access. Hover adds only quiet feedback; it never reveals the sole badge label, safety action, or explanation.

Live resize preserves selection, reading anchor, and focus where the selected player remains authorized. Reflow is immediate during resizing, not an animated competition between column widths. Moving to an external display preserves logical text sizing; it does not enlarge the ledger into a poster or introduce a second camera owner. The inspector changes to a sheet before content becomes unusably narrow, with the same selected player and a clear return focus.

Escape dismisses the foremost transient menu, popover, or sheet using its owner's draft rules, then closes an open inspector. It does not silently toggle public listing, submit a report, navigate away from an active match, or forfeit. Cmd-W normally closes a standings-only window. If a close or quit request also affects the real active-match owner, the shared coordinator presents the actual stage-specific consequence where the platform permits it. Force quit cannot be prevented and is not evidence of an explicit voluntary forfeit. Preserve Cmd-N, Cmd-Shift-R, Cmd-comma, and Cmd-Option-O; this view does not reassign them.

## Rank, Placement, and Own Standing

The service orders eligible public placed accounts by current Physique Elo. Equal current ratings share their competitive position. Two accounts tied first are followed by position three, not position two. The service's stable ordering within a tie is for reading and paging, not a tie-break advantage. Best Elo, wins, spending, badge count, country, attire, and an editable profile level never break a tie.

A tied row visibly says Shared with its position; VoiceOver says Shared Physique position followed by the number. Shared status comes from the full authoritative ladder, not a comparison of the visible page. It remains shared when the other tied account is on another page or omitted for the viewer. A real zero rating remains zero. Missing rating or position is an unavailable state, not zero, the hidden pairing seed, or the row's ordinal number.

Your standing belongs to the same coherent standings view as its stated snapshot. The person can be placed and listed even when their row is not in the loaded pages. Conversely, a saved Elo or a row-like local profile preview cannot establish placement. No population denominator or percentile is displayed in this design.

| Own state | Visible meaning | Available path |
| --- | --- | --- |
| No effective finalized rated result | Unplaced; no earned Elo, best Elo, tier, or numeric position | Return to Physique and Public listing; no automatic camera or search |
| One through four effective rated results | Provisional with the actual completed count out of five and actual earned Physique Elo | Placement explanation and Public listing; no assigned placed tier or public provisional row |
| Placed and publicly listed | Actual position, Shared when applicable, current Physique Elo, and truthful placed tier | Public listing and permitted own player details; not being in the current page does not remove the summary |
| Placed but listing off | Not publicly listed and actual own earned Physique Elo and tier | Public listing opens the shared privacy surface; there is no guessed private public position |
| Listing on before placement | Unplaced or Provisional remains primary; Public listing on, after placement is secondary | Shared privacy controls; no early publication or reserved rank |
| Listing accepted but position not yet confirmed | Position updating with the confirmed listing state | Refresh; do not place the person into the ledger optimistically |
| Listing or own position cannot be confirmed | Listing unavailable or Position unavailable, identifying which fact is unknown | Retry and shared privacy access; do not interpret unknown as opt-out or no rank |
| Temporarily restricted or banned | A private access/listing explanation and the permitted review route | Safety or case owner; no public allegation and no active public listing while prohibited |
| Dispute pending without a settled correction | Last effective permitted standing; review status remains private | Existing own case/detail route; no speculative rank reversal |
| Correction settling | Rating updating after review; only coherent last-confirmed values with their age, or position unavailable | Refresh and own review detail; never combine a corrected Elo with an old position as though current |
| Correction removes placement | Actual revised Provisional or Unplaced state and a private correction notice | Own review detail and placement explanation; remove invalid placed/tier presentation |
| Restriction lifted | Listed only after current placement, eligibility, and the stored explicit choice allow it | Fresh service-confirmed standing; an appeal decision itself is not a position |

F29-C defines which effective rated outcomes advance the five-result count, including eligible rated forfeits. No-contests, pending judgements, search cancellations, and duplicate deliveries do not advance it. Standings displays this authority; it does not recalculate placement or infer it from the number of history rows on the device.

## Public Listing Handoff

Public listing is a distinct optional choice, off until affirmative Physique-specific permission is confirmed. It is not bundled with camera permission, required AI processing, paired-opponent still access, country selection, a subscription, or navigation to this page. The person's Elo and competitive record have the same meaning while unlisted. Unlisting does not reset a rating, delete a result, or remove the limited identity disclosure required for an actual pairing.

The Public listing control opens F29-A-w at its listing section. Do not add a second toggle, save operation, or custom consent screen inside standings. That section must identify the publicly permitted handle, optional country, current Physique Elo, tier, permitted record/streak, and earned public badges; explicitly exclude pose media and private eligibility declarations; and explain that a saved opt-in cannot publish an unplaced or prohibited account. Dismissing that surface without choosing publication does not opt in.

While the shared change is saving, standings says Updating listing and does not award a position. An unlisting request shields the person's local discoverable row immediately, while remote removal remains Not confirmed until acknowledged. Failed or offline publication is not treated as successful public consent. A privacy action remains reachable when the board itself cannot load. Returning from privacy reconciles the actual choice and current eligible standing rather than copying the appearance of a local switch.

## Identity, Country, Badges, and Public Record

Only the service-approved public identity projection supplied under F29-F appears. The optional country or region is manually selected and intentionally shared, with its flag beside the handle when supported. Missing country uses a neutral region mark and the accessible meaning Country not shared. A known declared region whose flag cannot render uses a neutral symbol and the readable region name in its accessible description and player details. It is never replaced with a guessed national flag. There is no GPS, IP, locale, photographic inference, verified-nationality claim, country filter, or country effect on rating or judging.

Use F29-F's canonical badge vocabulary, shared ordering, and accessible meanings across standings, player summary, and battle rails. Represent every currently permitted earned launch badge: First Bell, Placed, Ten Rounds, and Three Straight when each is actually earned. Placed and the current tier can share one honest presentation rather than duplicate captions. A current streak, including a known zero when published, is distinct from Three Straight's historical milestone. An unknown streak is not zero and a historical badge is not a claim that the streak is still running.

First Bell and Ten Rounds follow F29-F's valid AI-judged-result rules, excluding forfeits and no-contests. Three Straight follows F29-C's effective win-streak rules, including eligible opponent-forfeit wins where applicable. The standings client does not count captures, reconstruct badge eligibility, or promote local cosmetic previews into trusted achievements. Current placed tier is absent for provisional/unplaced accounts, including after a correction.

Confirmed badges remain visible with their owner when their record is authorized. Badge data that is unavailable says Badges unavailable; it is not an empty earned collection, an unearned silhouette award, or a reason to hide an otherwise valid position and rating. Previously confirmed but still permitted data can be identified as stale under the shared policy; a known removal or revoked permission is never retained as a stale entitlement. Corrections remove invalid achievements and revise current status coherently. Loading a public row, reopening a player, or refreshing the board never replays an unlock ceremony for someone else.

A permitted record uses short labeled wins, losses, and draws or the shared record presentation, never unlabeled fractions. Private record information, best Elo, current streak, or other details are not added merely because a placed account exists. The shared listing and identity permissions decide the public subset. Country, badge names, handles, rank, Elo, and UI chrome never enter judging images or context; the board has no image-submission action.

## Stable Browsing, Refresh, and Paging

The initial board and each continuation belong to one service-confirmed snapshot. The proposed page size under F29-C is up to twenty actual authorized rows. A shorter page, including a page with no visible rows and a valid continuation, is not proof that the ladder ended. Do not fill gaps with examples, count hidden identities to make twenty, infer the next rank, or construct another page by offsetting visible positions.

Load more requests the next part of the same snapshot. Existing rows, selection, and reading position remain still. The control shows Loading more while that operation is outstanding; duplicate activations do not append duplicate content. A later-page error appears at that location with Retry loading more, without discarding the loaded board or turning it into a first-page empty state. No compatible new rows means no fake growth. An explicit service end becomes End of standings.

Privacy filtering can produce No visible players in this section while continuation is still possible. Keep Load more available. If the authoritative response establishes that the viewer has no discoverable rows, say No players to show, with the general explanation that privacy and safety settings can omit players. Do not expose the omitted names, number, direction of block, or enforcement reasons. Only a confirmed globally empty eligible public ladder says No public standings yet.

Ordinary result updates do not reorder a board someone is reading. A quiet Standings changed notice offers Refresh. Pulling to refresh or invoking Refresh intentionally obtains a coherent newer board; it is not a request to rerank locally. Keep the old permitted snapshot with its freshness label until replacement succeeds. If the current reading anchor survives in the refreshed first page, preserve it. Otherwise the explicit refresh returns to the ledger heading and announces Updated standings, showing top. Do not fetch an entire ladder to reconstruct a deep anchor or silently move someone before they request refresh.

A snapshot that has expired cannot accept a page from a newer view. Explain Standings changed; refresh to continue and retain only still-permitted content. Incompatible or unavailable continuation is a recovery state, not an excuse to sort and merge different positions locally. A fresh own-standing summary, page rows, and correction state must not be mixed into a false single current view.

Safety and privacy revocations are the exception to waiting for refresh. A block in either direction, unlisting, deletion, or loss of disclosure permission removes the corresponding identity and profile action as soon as the authoritative change is known, even when an ordinary update banner is pending. Do not wait for an exit animation. Do not replace the removed person with a named Blocked player row, a counted hidden slot, or another player's invented position.

Remaining positions still refer to the full eligible public ladder represented by the service snapshot. Viewer-specific omissions never compress that ladder. Global eligibility changes can legitimately change positions in the next coherent service view; that is different from the client renumbering the visible rows to close a hole.

## States and Recovery

| State | Surface and actions | Recovery and invariant |
| --- | --- | --- |
| Account restoring | Named account restoration state; no previous account's Your standing | Restore real identity first; no cached private claim |
| Signed out | Sign in and a nonbody explanation; Close remains available | Use the existing account route and return to standings; no guest ladder or previous-account cache |
| First page loading | Loading standings with the shared activity feedback; own state only when independently confirmed | No fake row silhouettes that contain ranks, handles, badges, or ratings |
| Fresh board | Actual authorized rows, snapshot time, Your standing, Refresh, and Load more when present | No fabricated count or live-position promise |
| Refreshing | Existing permitted snapshot, freshness, and Refreshing | Replace coherently on success; do not blank a useful board or duplicate a request |
| First-page service failure | Standings unavailable, concise reason, Retry, and shared privacy/safety access | Not an empty ladder claim; own data can fail independently |
| Later-page failure | Existing rows and reading position plus Retry loading more at the end | Retry the missing continuation, not a new incompatible snapshot |
| Globally empty | No public standings yet and Back to Physique | No seeded leaders, fake opponent, or implied rank one |
| Viewer-filtered empty | No players to show and general privacy explanation | No list of hidden identities or invitation to bypass a block |
| Empty visible section with continuation | No visible players in this section and Load more | Fewer than twenty visible rows does not mean end |
| End reached | End of standings after actual service end | No looping pages or invented lower ranks |
| Snapshot expired | Standings changed; refresh to continue | Keep only permitted old content; no cross-snapshot merge |
| New ordinary result | Quiet Standings changed notice | Update only through coherent refresh; no racing rows |
| Own position not in loaded page | The real position remains in Your standing | Do not deduce Not ranked from absence in the page |
| Own placement/listing unknown | Explicit unavailable fact and Retry | Not Unplaced, zero, or opted out by assumption |
| Badge projection unavailable | Actual rank/Elo remain if allowed; Badges unavailable | No invented badges, verification substitute, or local award computation |
| Profile access no longer permitted | Remove its navigation action or close the summary to Player unavailable | Recheck current permission, not a stale public-profile link |
| Known block, deletion, unlisting, or visibility removal | Corresponding row disappears immediately; safe focus repair | Other rows retain canonical positions; no public reason label |
| Report opening, sending, or failed | Existing F29-A-s owns actual contextual intake and receipt state | No screenshot/body attachment or claim of receipt before acknowledgement |
| Block requested offline or unconfirmed | Immediate local omission and Block not confirmed in the shared safety flow | No claim of cross-device exclusion yet; no rating or result effect |
| Offline | Standings unavailable offline, Retry, and only an authorized saved own summary labeled with its age | Do not persist or expose a discoverable public-player board offline; preserve a safe reading anchor for reconnection |
| Service access lost or authorization unknown | Shield identities no longer authorized, keep safe recovery and own allowed state | An old snapshot is not perpetual permission |
| Camera denied, missing, or disconnected | Board remains usable when browsing is authorized | No TCC request, camera setup detour, fake feed, or rated file-picker substitute |
| Allowance exhausted, AI consent declined, or judge unavailable | No new match action here; authorized existing standings still work | Viewing nonbody standings consumes no slot and performs no analysis |
| Account suspended, deleted, or switched | Apply current account access, clear old private state, remove prohibited own listing | No data, selection, report target, or continuation crosses accounts |
| Inactive, minimized, or background | Stop optional updates and decoration; shield own private status and sensitive sheets | Reconcile identity, visibility, and the same service state on return |

No discoverable public-player standings cache is persisted for offline browsing by this view. This intentionally gives up an offline public board rather than imply that a saved row guarantees current listing or block permission. The authorized same-account own summary can remain as an explicitly stale private record. On reconnection, restore the reading anchor only if its player is still permitted in the coherent returned view; never flash concealed names during reconciliation.

## Reports, Blocks, and Privacy Omissions

Player actions opens the existing report composer with the correct permitted account target and safe standings context. Username, impersonation, or conduct reports do not require opening a body image, downloading an avatar, or attaching a screenshot. Standings does not offer a scoring dispute against a public position; disputes belong to the person's own actual match and review owner. Report and Block remain independent actions.

Report receipt alone does not remove a valid public rating, grant Elo, accuse the player, or reveal the case to them. If the shared report flow also offers a local concealment choice, only that protective effect occurs immediately; the sent/unsent distinction remains visible. Blocking immediately removes discoverability locally and asks the service for the real exclusion. A pending block is not advertised as globally complete. Unblock lives in the safety owner and does not auto-select the player or reopen a gallery.

If the blocked player is also the real active opponent in another owning surface, F29-D's match rules still apply. Before Go, the shared coordinator cancels the pairing without Elo change. After Go, block shields and excludes future pairings but does not automatically leave, forfeit, rerate, or create a no-contest. A confirmed state-aware exit and service-established invalid/safety outcomes retain their separate meanings.

## Focus and Accessibility

The initial focus target is Physique standings. Normal loading and page arrivals do not repeatedly steal it. VoiceOver reads each player as public identity and optional declared region, actual shared Physique position, current Physique Elo, tier, complete public badges, and permitted record. It does not read a flag as verified nationality, repeat a decorative icon's filename, or announce rank from row order.

Expose badge names and actual meanings without requiring hover. Player details provides the full explanation and any permitted freshness context. Group decorative portions of a badge with its meaningful label so a row does not become dozens of duplicate focus stops. Player details and Player actions remain separate named controls. You, Shared, Provisional, Not publicly listed, stale, unavailable, and under-review own states are text or semantic values, not color-only cues.

After Load more, retain focus at the paging control and announce More players loaded once. The reader can move into the added rows deliberately. If the control disappears at the true end, move focus to the adjacent end state rather than the first row. A refresh announces completion once, not every changed rank. If a focused or selected row is removed for privacy, move to the next permitted row, the preceding permitted row, or the ledger heading when none remains; announce Player no longer available without revealing a hidden reason.

Closing player detail restores its invoking row when still allowed. Closing privacy returns to Public listing; its real confirmed state is read once. Closing About standings restores its toolbar control. Safety drafts follow their own persistence and dismissal rules. Selection changes and updates do not automatically focus a report's destructive action or a privacy publication action.

Support Dynamic Type, increased text size on Mac, increased contrast, Differentiate Without Color, VoiceOver, Voice Control, Switch Control, and Full Keyboard Access. Long text and right-to-left content preserve semantic order and readable handles. Numeric grouping uses locale conventions without changing whole-point rating meaning. Secondary labels remain readable on dark surfaces and in opaque reduced-transparency presentations. Haptics and sound are not necessary to load a page, understand placement, change privacy, or report a player.

## Motion, Interruption, and Energy

The ledger is quiet while idle. Its tactile character comes from shared press feedback, native navigation and selection, and a single restrained own-position locator, not a perpetual winner glow or animated badge wall.

| Trigger | Selected motion | Timing and interruption | Reduced-motion equivalent |
| --- | --- | --- | --- |
| Real control press | Existing shared press treatment on that control, not the whole ledger | Existing spring response 0.24 and damping 0.88; cancellation never activates the action | Immediate pressed ink/opacity, no scale |
| First authorized own summary or an explicitly refreshed confirmed own standing | The thin orange own-marker draws into its settled extent; final position and Elo are already readable | About 280 milliseconds, ease-out, once per meaningful visible update; no replay for view recycling, window changes, or duplicate data | Static marker and final values immediately |
| Row selection or pointer focus | Subtle surface/outline change within the same row bounds | About 160 milliseconds; current focus wins, no row scale or travel | Immediate selected/focused state |
| Initial authorized rows or compatible added page | Brief content opacity settling; previously loaded rows stay still | About 180 milliseconds, no stagger, no minimum wait; input and page navigation work immediately | Immediate content or short opacity |
| Ordinary update notice | Small status-icon/notice appearance without shifting the reader's row | About 160 milliseconds on actual update knowledge; no timer-driven pulse | Static notice |
| Explicit refresh replacement | Values and compatible content settle in their final locations | About 180 milliseconds; no animated reordering, rank roll, or traversal of intermediate positions | Immediate final snapshot |
| Authorized badge content change | Shared badge feedback only for the exact confirmed change; no remote-player unlock ceremony | Small-state range, about 180 milliseconds; invalidation/removal takes priority | Static truthful rail |
| Sheet, popover, or inspector | Native platform transition and shared stage-continuity language | User can dismiss or continue interacting without waiting for custom choreography | Platform reduced-motion behavior |
| Block, withdrawal, deletion, or access removal | Conceal immediately and repair focus | No exit-animation delay and no disappearance flourish | Identical immediate protection |
| Live window resize | Content reflows without a custom spring | Follow current geometry; cancel nonessential locator motion rather than animate every measurement | Identical stable reflow |

No rank number counts through invented intermediate places. No podium rise, loser shake, slot-machine rating, flashing streak, endlessly pulsing badge, moving country flag, or scrolling ticker is used. Confirmed final values are always available to accessibility immediately. Corrections are labeled corrections, not another win ceremony. Standings never re-awards points or badges on reopen.

Pause optional refresh subscriptions and decorative work when offscreen, inactive, minimized, or backgrounded. Resume with one coherent authorization/freshness reconciliation rather than replaying missed animations. Low Power Mode or serious thermal pressure removes the own-marker draw and nonessential transitions before reducing legibility or safety; ordinary native scrolling and control semantics remain. There is no continuous ambient loop or per-second relative-age timer on this nonbattle page. Reduce Transparency uses opaque shared surfaces.

No per-frame network requests, file work, image decoding, font measurement, sorting, or whole-page refresh belongs to these effects. Availability-gated public transitions and materials retain iOS 16 and macOS 14 behavior; newer symbol or numeric effects cannot justify raising deployment targets.

## Window and Camera Lifecycle Boundaries

Standings does not start or retain camera acquisition. On Mac, TCC denial/restriction, absent or busy hardware, external-camera removal, and Continuity-camera disconnection do not stop authorized board browsing or trigger a permission prompt. There is no camera preview, production mock, or file-picker capture alternative here.

Opening a secondary standings window does not create a match, reserve or consume a slot, acquire a second camera, or silently transfer the one active-match owner. If an active capture is interrupted by its owning window becoming inactive, minimized, backgrounded, or disconnected, the shared coordinator stops acquisition and shields immediately. Standings does not override that behavior, extend its deadline, or call an involuntary interruption a voluntary forfeit. Returning to the match restores the same real stage and clock before any permitted camera resume.

Protect own private placement/restriction information, report drafts, and privacy sheets in app-switch and inactive sensitive-surface presentations. A restored window first reconciles its account and current visibility; a stale selected player must not flash before being removed. A finalizing match in another surface can create an ordinary standings-update notice, but never a local result or a second Elo effect.

## Dependencies, Files, and References

Real implementation requires the reviewed F29-C service to supply canonical ranks and ties, coherent own standing and placement, stable snapshot paging, current visibility omissions, and honest unavailable/end states. F29-E supplies authenticated account and public-listing authority. F29-D supplies block protection and actual report intake. F29-F supplies public identity, optional region, and authoritative badge projection. F29-A-q, F29-A-w, and the shared safety owners must be implemented and handed to the human for review before this view claims connected navigation. A named future document or a preview is not proof that those prerequisites exist.

Prospective view-owned files belong under TimeMaster/Views/Physique/ for the standings view and variable-height standing row. Reuse the existing reviewed Physique presentation/service foundation for paging and account-scoped state; do not establish another network client, authentication store, global theme, badge engine, public cache, or ranking algorithm. Existing app routing and target membership are touched only to connect this surface on both native targets. Exact technical file organization follows the implemented foundation, not a source-code recipe in this product document.

- [F29-A page flow](../DOCKS.md), [F29 parent](../../DOCKS.md), and [shared native components](../../F29-G-native-ui-components/DOCKS.md).
- [F29-C competition and standings](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety](../../F29-D-safety-and-reporting/DOCKS.md), [F29-E privacy](../../F29-E-privacy-and-service-operation/DOCKS.md), and [F29-B judge blindness](../../F29-B-ai-judging-and-metrics/DOCKS.md).
- [F29-F battle identity and badges](../../F29-F-battle-identity-and-badges/DOCKS.md), [player summary](../F29-A-q-player-summary/DOCKS.md), [privacy and sharing](../F29-A-w-privacy-and-sharing/DOCKS.md), [badges and country](../F29-A-y-badges-and-country/DOCKS.md), [safety hub](../F29-A-r-safety-hub/DOCKS.md), and [report composer](../F29-A-s-report-composer/DOCKS.md).
- [Theme and shared controls](../../../../TimeMaster/Utilities/Theme.swift), [type and spacing](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [public material/press fallbacks](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) supply existing visual conventions.
- [Ranked components](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supply sports-action and earned-rating language, not permission to copy Dynamic Type clamps, infer Physique tiers from exercise ratings, or use editable cosmetic badges as achievements.
- [Native window](../../../../TimeMaster/App/TmaxApp.swift), [existing commands](../../../../TimeMaster/App/TmaxCommands.swift), and [local cosmetic models](../../../../TimeMaster/Models/LocalProfileModels.swift) define platform and trust boundaries.
- [Supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) informs hierarchy and directness only. Its side-by-side layout, photographs, web colors, and labels are not copied or licensed assets.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially flexible windows, larger displays, keyboard and pointer input, and native system integration.
- [Apple HIG: Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), especially readable row content, meaningful selection, descriptive headings, and platform-appropriate density. A standings ledger deliberately does not add alternate sorting that would change its competitive meaning.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially purposeful brief feedback, optional motion, and cancellation. The own-marker treatment is this product's choice, not an Apple-prescribed sports animation.
