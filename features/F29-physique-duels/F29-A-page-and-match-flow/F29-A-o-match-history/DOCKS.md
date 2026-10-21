# F29-A-o — Match History

## Purpose and Ownership

Match History is the signed-in participant’s private Physique ledger. It answers three questions without reopening body images: who the person actually played, what the service confirmed, and what happened to their own Physique Elo. Every row belongs to one exact started match. Opening history neither starts a match nor requests camera permission, uploads an image, consumes allowance, or changes a rating.

This is product context and a future native UI design, not an implemented surface, accepted prototype, or claim of human verification. The approved visual direction is native iPhone and native macOS, minimal visible text, tactile state-driven motion, and large vertically ordered players whenever a battle composition appears. Existing numerical competition proposals remain governed by the parent areas; this child does not approve a different rating rule, retention period, or judging model.

This child owns the private list, its compact rows, twenty-row continuation, selected-match summary, freshness and access states, and restoration of list position and focus. The canonical match/result, pose viewer, report form, private case center, badge system, and active-match coordinator remain their existing owners’ responsibilities. History connects to those real destinations with the exact match or case reference; it does not reproduce them as disconnected screens.

## Chosen Composition and Tradeoffs

Use a quiet sports scorebook, not a wall of result cards or a gallery of bodies. One History heading, a small Only you privacy label, and a chronological list establish the hierarchy. Strong Inter opponent labels, aligned signed Elo amounts, restrained outcome symbols, and thin separators make actual records scannable. Orange identifies an actionable selection or shared primary action, not a judgement of someone’s body. A loss has no humiliating red wash, shake, or defeated-player treatment.

On iPhone, a row discloses its text-only summary directly below itself. Only one summary is expanded. On a Mac with room for two readable panes, selecting a row updates a native trailing inspector while the ledger stays in place. At short or constrained Mac sizes, the same summary appears inline instead of forcing tiny columns, a phone-shaped modal, or a larger app-wide minimum. Both presentations use the same information hierarchy and exact-match meaning.

Inline disclosure avoids a push-and-back cycle for checking a date or rating effect. It increases the height of the selected row, so expansion preserves the invoking row’s position and collapses any previously open summary without moving the new selection away. The Mac inspector avoids repeatedly expanding a long desktop list; adapting to inline content is preferable to clipping important text when the window or app navigation leaves too little usable width.

Explicit Load more is the only older-page trigger. It costs one deliberate action per page but avoids invisible fetch loops, a moving keyboard target, and accidental traversal of an entire private record. A deliberate Show latest action obtains a new chronological snapshot. Ordinary reading, disclosures, and older-page loading never return the reader to the top.

There are no search, country, opponent, or outcome filters; alternate sort orders; swipe-to-delete losses; row reordering; public history links; history export; invented rematches; or new analytical charts in this slice.

## Visual Language and Visible Copy

Reuse the existing near-black background, dark elevated surfaces, Inter Black and Regular type hierarchy, shared spacing and separators, and toolbar orange. Use the existing readable-column and action styles rather than a separate history theme. Secondary timestamps remain legible with increased contrast and large text; do not copy existing Dynamic Type clamps or shrink a consequential label to retain a compact row.

The list is one coherent surface, not a stack of oversized crest cards. A small semantic outcome symbol leads each row. The opponent’s permitted historical label is primary. A concise outcome/provenance line and the actual started date and time follow. The viewer’s own rating effect aligns at the trailing edge when space allows, and moves beneath the identity at large text or narrow widths. Text may wrap; outcome, pending status, correction status, and rating scope never disappear into an ellipsis. A long handle can truncate in the collapsed row only when the full permitted label remains available through disclosure and accessibility.

Use History, Only you, Load more, Show latest, Open result, Open match, View case, and Retry as the principal labels. First loading says Loading history. An authoritative empty response says No physique matches yet, with Return to Physique. An offline response without authorized saved content says History unavailable offline, not No matches yet. A new-membership notice says New matches available and offers Show latest. Snapshot expiry says Show latest to continue. End of history says You’re up to date with this history, with no additional load control.

History rows contain no pose thumbnails, local profile photos, crest wall, or clipped subset of badges. A service-authorized self-declared country flag may accompany a permitted historical handle only when the approved identity contract actually supplies that match-time information. A region name is available to accessibility; absent or unsupported flags have a neutral presentation. Do not reconstruct a historical flag from today’s profile, infer country, or turn it into a filter or score signal.

### Relationship to the battle composition

The compact ledger and its text-only summary are not a miniature battle stage. They have no invented countdown and no two-player image layout. Open match, Open result, or intentional View poses hands off to the shared owner instead of inserting a second matchup into the list or inspector.

Any routed battle composition retains the real timer as its top visual anchor, then complete public identity and badge rails grouped by owner, then two large vertical player panels: You above Opponent at every width, including wide Mac windows. All public battle badges are represented and wrap above the panels; no three-badge cap, hidden additional-count token, clipping, ticker, or badge placed over a body. The shared terminal presentation uses its truthful completed timer/status; reopening history must not restart a final match’s clock or invent a live countdown. History does not replay an award, unlock, score reveal, or badge celebration. Evidence remains aspect-fit and fairly framed, with no face or limb overlays.

## Which Events Become Rows

The service’s accepted Go transition creates a started match eligible for history. Search attempts, search timeouts, preparation, readiness, and cancellation before Go are not fabricated rows. A genuinely started pending match can appear before it has a final outcome, without contributing to rated counts or implying an earned Elo change.

Rows are ordered by actual service-recorded start time, newest first. Equal start times retain the service’s stable tie order. Completion, appeal, correction, local receipt, handle changes, device time-zone changes, and opening a detail do not move an old match to the top. Each match keeps one identity throughout pending, final, and corrected states. Repeated delivery is not another match or another placement result.

The collapsed timestamp is an absolute, locale-formatted date and time, not a constantly changing relative counter. The summary distinguishes Started, Finalized when confirmed, and Corrected when applicable. It exposes the precise recorded time and time zone sufficiently to distinguish similar rows, including daylight-saving transitions. Missing time is Date unavailable; the client never substitutes now. Chronological order follows the service, not the formatted local label.

## Outcome and Own-Rating Meaning

The compact rating column is explicitly scoped to the viewer’s own Physique Elo. It is not the AI total, an exercise rating, the opponent’s private change, or the current account rating copied into every historical row. A true settled zero is readable as 0 Elo; absence is Not available and a pending settlement is Not settled. Neither becomes a guessed zero.

| Record state | Collapsed outcome/provenance | Own-rating presentation and detail |
| --- | --- | --- |
| Valid AI-judged win | Won, with AI judged | The service-settled signed match effect; the original own before/change/after values remain available |
| Valid AI-judged loss | Lost, with AI judged | The actual signed effect, with no punitive styling or invented extra penalty |
| Valid AI-judged draw | Draw, with AI judged | The actual effect, which may be nonzero when ratings were unequal; never substitute No contest |
| Opponent’s eligible voluntary forfeit | Won by forfeit | The ordinary confirmed rated effect; no appearance totals, category bars, or implied judged superiority |
| Viewer’s eligible voluntary forfeit | Forfeited | The ordinary confirmed rated effect; no invented physique scores |
| Confirmed no-contest | No contest | No rating change and no rated-count contribution; detail gives only the viewer-permitted safe reason and actual allowance-restoration status |
| Started but unfinalized | Pending, with the confirmed stage if available | Not settled; retain the last confirmed account rating outside the row, not an optimistic match delta |
| Finality cannot be refreshed | The last confirmed state, explicitly marked Not refreshed | Never relabel an unknown result as a loss, zero-point draw, no-contest, or successful correction |
| Dispute under review | Current confirmed outcome with Under review | Current confirmed effect remains effective; a case is not a reroll or a provisional refund |
| Correction approved but settlement incomplete | Last confirmed outcome with Rating updating after review | Last confirmed values remain labeled; do not mix a corrected winner with an old unlabeled rating effect |
| Settled correction | The current effective outcome with Corrected | Show the service’s effective match contribution and a separately labeled actual Review adjustment; disclose original settlement and correction history rather than compressing unlike events into one unexplained delta |

A corrected no-contest is now unrated, but the later adjustment may have changed the viewer’s current rating. Its row therefore says Unrated for the effective match contribution and separately names the settled Review adjustment. It must not say that the review changed no points merely because the corrected outcome is no-contest. Normal uncorrected no-contests use No rating change.

A corrected row may be taller than an ordinary row. Keeping the effective outcome and the separately labeled latest review adjustment is more important than forcing both into a single short number. If there are several authorized corrections, the compact row identifies the latest settled review and the summary exposes the permitted chronological correction history. It does not locally sum or reconstruct a supposedly original rating path. Bounds can limit an actual adjustment; display what the service settled.

The original before-and-after snapshot remains the historical settlement, not a rewritten pair of numbers pretending the correction happened at match time. The correction section gives its own date, permitted reason, original and effective outcome, actual current-rating adjustment, and confirmed settlement state. Later valid matches keep their actual original evidence, outcomes, rating inputs, effects, time, and judging version. Corrections do not rerate unrelated opponents or manufacture a counterfactual ladder.

## iPhone Composition and Interaction

History opens in the existing native navigation hierarchy from the Physique lobby’s History action. Recent-match and authorized saved-match entry points identify the same match; they do not open the first record by array position. The normal back action returns to the same lobby and navigation state. Safe areas, floating navigation clearance, and the keyboard are measured through the existing app conventions rather than fixed screen offsets.

The header contains History and the Only you label. Show latest is a conventional toolbar action. If a service update announces new match membership, the notice sits above the list without pushing the current reading position away. The native scroll surface uses the app’s existing readable width and touch conventions. Controls have at least the existing forty-four-point interaction area, including row disclosure and safety access. Landscape, short screens, and accessibility text use vertical scrolling, not a compressed side-by-side matchup.

Tap the row’s semantic disclosure control to expand its summary. It stays selected, exposes its expanded state to assistive technology, and remains in the same screen position where practical. A second activation collapses it. Selecting another row closes the old summary and opens the new one without jumping the newly selected row away. The summary has no nested tap area competing with its individual action buttons.

Loading the exact detail is separate from loading history pages. The row remains visible while its summary says Loading match. A failure replaces only that summary region with Match details unavailable and Retry; other rows, paging, Back, and permitted safety access remain usable. A different row can be selected immediately. A late response for the previous selection cannot fill the new summary.

Open result presents the canonical saved result for this exact final match. Open match restores this exact pending match at its authoritative stage; a participant whose poses are already accepted does not see a new capture instruction. Closing the result, pose viewer, or contextual safety flow returns to the same selected row, expansion, and list anchor. A gallery never reopens automatically on return.

Pull-to-refresh, if retained by the existing navigation surface, is a deliberate Show latest operation at the top of the list and has the same reset semantics as the toolbar action. There is no hidden refresh gesture that silently replaces older pages while the person is reading them.

## Native macOS Composition and Window Behavior

This is a native macOS 14-or-later surface in the existing Tmax WindowGroup, not Catalyst, a web ledger, or a stretched phone. Preserve the normal title bar, app navigation, standard window controls, and the current 800-by-600 minimum. No target raise or macOS 26-only dependency is required.

The window toolbar provides History context, Show latest, and a labeled Details inspector toggle. A desktop single-selection list uses native pointer, selection, focus, and scrolling behavior. A selected row is visually distinct from keyboard focus, with no hover-only action reveal. It is not an editable spreadsheet: chronology is fixed, and the headings do not pretend to provide unsupported sorting.

At the minimum window size or when app chrome and enlarged text leave insufficient readable width, the ledger occupies the available column and the selected summary expands inline. The Details toggle shows or hides that summary. On a typical laptop window with sufficient usable space, Details opens a native trailing inspector with its own vertical scrolling. A larger, full-screen, or external-display window gives the ledger more comfortable aligned date and rating space and a readable inspector; it does not spread players across horizontal columns or turn text into enormous cards. Pane proportions follow available measured content, not screen coordinates or a new app-wide minimum.

The inspector has a Match details heading, a clear close control, the selected match’s date, and the same summary content as iPhone. Selecting another row updates the inspector without opening another window, scrolling the ledger to the top, or stealing keyboard focus into the inspector. When a new match is selected, its inspector begins at its own summary heading; returning to a previously selected match within the same authorized visit restores its summary position. An inspector is supplementary to the selected record, not an independent copy of a private result floating above unrelated windows.

Live resize can move between inspector and inline presentation when both panes cease to fit. The match selection, expanded disclosures, ledger anchor, and logical focused control survive. If the focused inspector control relocates inline, focus follows its equivalent rather than disappearing. Short windows scroll the stage or summary, not the title bar and safe navigation controls. The inline and inspector versions are never simultaneously exposed as duplicate accessibility content.

Keyboard Up and Down operate the focused native list selection. Tab and Shift-Tab move to the inspector, disclosure content, Show latest, paging, and contextual actions in logical order. Return and Space activate only the focused semantic control; they are not global shortcuts that open a result or start a match while a report note is being typed. In inline mode, native disclosure keyboard behavior exposes and collapses details. Escape first belongs to a presented sheet or meaningful draft confirmation, then closes the selected details/inspector, and only then invokes ordinary history back behavior. A background update does not change this hierarchy.

Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O. Do not repurpose them for history, refresh, rematch, or report. A standard native context menu may duplicate Open result, available safety actions, or copying a safe match reference, but none is available only through right-click or hover.

History has no camera or microphone owner and never prompts for TCC, starts Continuity Camera, or substitutes a file picker. Denied, restricted, absent, busy, disconnected external, and disconnected Continuity cameras do not prevent authorized historical reading or review. Open match delegates the actual recovery to the one shared active-match owner. History cannot restart capture, extend a deadline, consume another slot, or claim a disconnect is a deliberate forfeit.

Multiple windows may read authorized history, but account identity, access revocation, effective outcomes, and corrections remain shared truths. Secondary windows do not create a second active match, camera session, or charge. Inactive, minimized, backgrounded, or locked windows immediately shield private content and stop decorative work. Return establishes the account and current access state before revealing private details or media. It restores the reading context, not an automatically opened gallery or camera.

Command-W and quit close archival reading without changing a completed result. If the shared account has a real active-match consequence, the shared coordinator presents the truthful state-aware confirmation where the platform permits; history must not intercept it with an unconditional Forfeit. An ordinary involuntary interruption or force quit cannot be prevented, cannot be guaranteed a confirmation, and is not itself a confirmed voluntary forfeit.

## Selected-Match Summary

The summary is a compact text record, not another full result screen. Its reading order is:

1. The effective outcome, provenance, and permitted opponent label, with Pending, Under review, Corrected, or Rating updating after review when applicable.
2. Started and, when confirmed, Finalized times. Expanded timing shows the exact time zone and any later correction dates separately.
3. Own Physique Elo at original settlement: before, signed change, and after. Unplaced or unavailable history is named honestly. Match-time opponent Physique rating and placement appear only when authorized; no opponent private transaction history is exposed.
4. For a valid judged result, the accepted one-decimal totals, one-decimal total gap, judging version, and a short reminder that these are subjective pose-set judgements, not body measurements. Full categories and neutral explanations remain in the canonical Open result destination; this summary does not invent or rejudge them.
5. For a forfeit or no-contest, the actual perspective-specific outcome, the absence of physique scores, the viewer-safe reason when allowed, and allowance restoration only when the service confirms it. An unknown restoration says Not confirmed, not Restored.
6. Any review and correction section, including the distinction between original settlement, effective outcome, and actual later adjustment. An existing private case links to View case. Closed, inconclusive, or unchanged reviews do not imply an award.
7. One main contextual action: Open result for a final record or Open match for an actual pending match. A separately discoverable Safety action offers the relevant account/match concern, unsafe explanation report, or scoring dispute through the shared owner. A selectable safe match reference supports ordinary support without exposing signed media links or credentials.

No profile, report, block, appeal, export, or media button is a no-op. Actions appear only when their real owner and target exist. When a current restriction removes an action, show the honest reason and the permitted help route rather than a decorative disabled control without explanation. A private result that cannot be accessed is not replaced with another loaded match.

An Unavailable player label replaces a deleted or no-longer-authorized identity. A Blocked player label replaces a blocked identity, disables profile discovery, and shields the gallery. A restricted opponent is not labeled with an allegation, moderation count, or private sanction. Permitted own outcome and rating facts remain readable. Today's public-profile authorization governs any profile route; a historical handle alone is not permission to rediscover a deleted account.

## Twenty-Row Stable Paging and Refresh

A page requests twenty actual service-owned started-match records. A short authorized page is never padded with samples. The service determines continuation and end-of-list; the client cannot infer the end solely from a short visible page or manufacture a cursor from a displayed row count.

The first page establishes one stable account-owned membership snapshot and chronological order. Load more continues that same snapshot. Equal timestamps, a concurrent newly started match, a finalization, or a correction must not duplicate or skip a record. One pending request cannot be multiplied by repeated taps. A retry reuses the missing continuation rather than fetching a new head page and merging unrelated snapshots.

Membership and ordering remain stable while confirmed revisions to an already loaded match can change its status in place. A pending row becomes final under the same match identity. A coherent settled correction updates that row and its selected summary together without moving it to the top. Older page delivery cannot roll back a known newer correction. Account, access, block, deletion, and media-protection changes take effect immediately; snapshot stability is never a privacy freeze. The shared service contract must support these guarantees before implementation is independently usable.

New started matches outside the current snapshot produce a quiet New matches available notice, not automatic insertion above the reader. Show latest is the explicit choice to replace the current pages with the latest first twenty and return to the top. Its label and accessible description explain that action. A successful Show latest clears the old continuation; a failed one leaves the prior rows, selected summary, and position intact, with Not refreshed and Retry. It never glues a new first page to an old cursor.

Load more adds records below the existing final row. The previous last row remains the visual reading anchor instead of jumping to the new footer. Touch and pointer reading do not receive an automatic scroll. When keyboard or assistive-technology users explicitly request the page, focus can advance once to the first newly available row, with one concise count announcement; it does not leap to the relocated footer or repeatedly announce every row. Paging failure keeps Retry at the failed boundary. A final response removes continuation and shows the calm end label.

An expired snapshot replaces Load more with Show latest to continue. Existing authorized records remain readable as the previous snapshot until a deliberate successful replacement. No silent offset restart, duplicated page, or guessed missing rows repairs expiry. A selected match reference remains the return target if that same match is authorized in the replacement; if it is not in the new first page, selection closes and the explicit latest view receives focus without pretending the match ceased to exist.

## State and Recovery Contract

| State | Visible behavior | Actions and recovery |
| --- | --- | --- |
| Account restoring or changing | Private content is shielded; Checking account replaces all prior-account rows | Wait for the shared account boundary; do not reveal remembered history based on a saved selection |
| Signed out or expired session | Sign in to view history; no prior identity, row, cursor, case, or detail survives visibly | Existing account flow; return to the intended authorized history after real sign-in |
| First request | Loading history, with the existing activity indicator and no sample rows | Back remains available; no minimum artificial delay |
| Confirmed empty | No physique matches yet | Return to Physique; no camera or queue starts automatically |
| Loaded | Actual compact rows, freshness, disclosure, and real continuation | Read, disclose, open exact match, use allowed safety actions |
| Show latest running | Last confirmed rows remain with refresh activity | Reading and close remain usable; duplicate refresh is disabled |
| New membership available | Quiet notice above the list, without reordering or taking focus | Show latest deliberately resets to the newest snapshot |
| Later page running | Existing rows remain; only the page boundary indicates loading | No duplicate request; other rows and Back stay usable |
| Later page failed | Inline error and Retry at the same boundary | Retry that continuation; do not replace the list or lose selection |
| Snapshot expired | Previous snapshot is labeled; continuation is unavailable | Show latest to continue; no silent merge |
| Confirmed end | Calm end-of-history label | No repeating load operation or fake older match |
| Offline with permitted same-account nonmedia records | Saved results, Not refreshed, last confirmed fetch time; opponent identity is neutralized | Read permitted text and retry on connection; no media access or competitive settlement from cache |
| Offline without permitted records | History unavailable offline | Retry or return; not a genuine-empty claim |
| Service not configured or history access temporarily unavailable | A service-specific unavailability message | Retry when meaningful and use allowed help; no exercise-history substitute |
| Camera denied, no camera, disconnected camera, exhausted allowance, or judge unavailable | Authorized historical records remain usable | These are not history errors or new losses; new participation remains the active-flow owner’s concern |
| Exact detail loading or failed | The selected row remains; its own summary names loading or failure | Retry this match or choose another; late responses cannot overwrite the new selection |
| Known pending match | Actual current stage or Pending, with Not settled | Open match restores that exact service state; no new session or local timeout verdict |
| Final judged record | Won, Lost, or Draw with AI judged and own actual effect | Open the canonical result; no replayed award |
| Final eligible forfeit | Won by forfeit or Forfeited, own actual effect, no body scores | Open the non-scored result and permitted dispute route |
| Final no-contest | No contest, No rating change, safe reason and confirmed allowance consequence | Open the non-scored result; no draw medal or opponent poses |
| Under review | Current effective outcome and private review status | View case or permitted dispute action; no promised reversal |
| Correction settling | Rating updating after review and labeled last confirmed values | Read context or refresh; no mixed rating/outcome or new rated seed |
| Correction settled | Effective outcome, Corrected, separately labeled actual adjustment and audit context | Open the current canonical result or private case; no re-award or unrelated rerating |
| Review closed without change or inconclusive | The actual private decision and current effective record | View case; explain evidence limits without invented scores |
| Blocked, deleted, or unavailable opponent | Blocked player or Unavailable player and no active identity discovery | Preserve permitted own facts and safety/help access; no allegation or hidden profile bypass |
| Media hidden, reported, withdrawn, removed, expired, or inaccessible | Summary stays text-only; canonical viewer has a reason-specific placeholder | Report/hide remains available without enlargement where permitted; no cache resurrection |
| Own account restricted | Private scope notice and only permitted history/review access | Existing safety appeal or help route; no queue bypass |
| Record access withdrawn or own deletion confirmed | Remove affected private rows and selected details immediately | Truthful request/status or account entry; no backup restoration into another session |
| Window inactive, app backgrounded, device locked, or minimized | Immediate opaque privacy cover and paused decoration | Return verifies identity and access before restoring authorized text context |

## Privacy, Cache, and Service Authority

Only the participant’s authenticated account can read this ledger and its private match details. A known match reference, public handle, public standing, copied link, old window restoration, or locally remembered selection does not grant access. Public listing is independent of private history: an unlisted participant can retain their own valid records without exposing them to other users.

The visible history, selected summary, service snapshot, continuation, freshness state, and request results are account-bound. Sign-out, account switch, session invalidation, and confirmed deletion remove the old account’s visible content before any new account work begins. In-flight old responses and restored windows cannot repopulate it. Private errors and case context are cleared with the same boundary, not only body images.

A permitted protected nonmedia cache belongs to the same authenticated account and service environment and contains only the minimal authorized result facts. Authentication restoration must finish before it is shown. An expired, signed-out, or unknown session gets the account state, not a cached ledger. Offline cached rows suppress opponent handles, flags, avatars, badge identity, profile links, private case details, and unsafe explanations; the remaining match dates, own outcomes, own rating facts, and versions are labeled Saved results and Not refreshed. This deliberately trades offline identity lookup for reduced stale-identity exposure. Cached content cannot authorize a current profile, media view, case action, or new rated match.

The list and inline/inspector summary never fetch, prewarm, decode, persist, or restore pose thumbnails. The canonical viewer requires an intentional action, a valid AI-judged win/loss/draw, accepted moderated evidence, current participant access and sharing authorization, no blocking or safety restriction, and unexpired media. Forfeit and no-contest records have no counterpart gallery. Ordinary access expires twenty-four hours after finalization, not after first viewing or latest download. A report hold is restricted case access, not a gallery extension. Old signed links, another device, copied thumbnails, reconsent, or backups cannot restore unavailable media.

Safety hiding and local shielding take effect immediately, including offline, while the shared safety owner labels remote confirmation truthfully. A report draft is not a submitted report or preservation receipt. A pending block is not confirmed cross-device exclusion. Blocking after Go does not alone finalize or leave the match; explicit eligible forfeiture remains distinct from safety-, evidence-, or service-established no-contest. Closing a history record changes none of these outcomes.

All ratings, finality, placement effects, allowance consequences, timestamps, judging versions, review states, and corrections come from the trusted service. History never sends identity chrome, flags, badges, or a UI screenshot to the judge; it never calls a personal provider or derives a replacement verdict. No confidence percentage, body-fat estimate, unsafe anatomy description, medical inference, or fabricated metric fills absent detail.

## Focus, Accessibility, and Input

History is a labeled destination with an initial heading and a concise privacy description. A collapsed row exposes the permitted identity, absolute started time, outcome provenance, own Physique Elo effect, and pending/review/correction state as one understandable summary. Its disclosure has a real expanded/collapsed value. Detail actions remain separate semantic controls rather than inaccessible gestures on a combined container.

On iPhone, disclosure focus stays on the invoking row and the next accessible item enters its details. Closing the summary or a presented owner-controlled surface restores the same row or the nearest still-authorized safe control if it was removed. Loading success does not take focus away from another row selected in the meantime. On Mac, row selection and inspector navigation are distinct; automatic inspector updates do not redirect typing or keyboard focus.

Dynamic Type and supported Mac text scaling can grow rows, reasons, dates, action labels, and correction sections without horizontal scrolling or smaller outcome text. Localized expansion and right-to-left layout preserve meaning; You still precedes Opponent in any routed vertical battle. Signed values have accessible increase/decrease/unchanged meanings and a Physique Elo unit. Color, icon, sound, and motion are redundant with text. Country emoji is not read as an unexplained code, and decorative outcome artwork does not duplicate the spoken summary.

VoiceOver, Voice Control, Full Keyboard Access, Switch Control, pointer, and ordinary touch can reach disclosure, paging, retry, Show latest, close, exact-match navigation, and safety. Do not rely on swipe actions, hover, a long press, or tiny status glyphs. Announce a requested page arrival, failure, finality change, or settled correction once with safe concise context. Do not announce every loading frame, timer tick in another view, row, or intermediate animated number. Consequential information remains readable in the selected record, not only a timed toast.

## Animation and Interruption Rules

History feels tactile through selection, disclosure, and actual state continuity, not ambient spectacle. It has no decorative idle loop, shimmering fake matches, row-entry cascade, body scanning, flashing, score-counter rerun, or badge-wall pulse. Native navigation, scrolling, sheets, and focus feedback remain native.

| Trigger | Visible motion | Timing and interruption |
| --- | --- | --- |
| Press a custom history action | Existing shared press feedback, without a second history-specific bounce | Reuse the shared spring response of 0.24 seconds and damping fraction of 0.88; cancellation or disabled state does not invoke the action |
| Pointer or keyboard selects a Mac row | Native selection and a restrained accent/opacity change; no card scale | About 160 milliseconds; the latest real selection replaces the prior state immediately |
| Expand or collapse an inline summary | The summary unfolds within the list while its row remains the anchor; content opacity follows the reveal | About 280 milliseconds with smooth, critically restrained settling; reversal continues from the current presentation, with no queued expansions or interaction lock |
| Show or hide the native inspector | Native pane continuity, with the ledger anchor retained | Use the platform transition; do not add a second sliding layer or artificial wait |
| Change selected inspector match | Text-only details crossfade while stable inspector chrome remains | About 180 milliseconds; loading and selection are tied to the newest exact target, and no outgoing detail flashes as incoming data |
| Receive a requested older page | New rows appear together below the anchored boundary | About 160 milliseconds of opacity, no stagger, travel, forced footer scroll, or delayed interaction |
| Receive pending finality or a settled correction for an existing row | Outcome, provenance, and own-effect text update coherently in place | About 180–200 milliseconds; final accessible values are immediate, with no celebratory score/Elo roll or earned-badge replay |
| Show a new-membership or recoverable-error notice | Concise notice crossfades without reordering records | About 180 milliseconds; dismiss or retry is usable immediately |
| Sign out, switch account, revoke access, hide sensitive content, background, or lock | Private content is replaced by its safe state or opaque privacy cover | Immediate; never wait for an animation, pending network request, or disclosure completion |

Reduce Motion removes scale, spring travel, unfolding displacement, and cross-pane travel. It uses immediate layouts and, where helpful, opacity no longer than about 120 milliseconds. Information, focus destination, and available actions are identical. Reduce Transparency uses readable opaque surfaces and an opaque privacy cover; no text or private row is readable through it. Increased contrast preserves selection and separators without relying on a faint glow.

The list has no ticking relative timestamps or per-row timers. The shared active-match owner alone drives actual clocks and real pending observations; history does not add a polling loop that repeatedly reloads the head page and invalidates older pages. Offscreen, backgrounded, minimized, and inactive history stops decorative work and unnecessary view-owned observation. Low Power Mode or thermal constraint removes optional transition motion and unnecessary image work; there are no history pose images to prefetch. Essential service state and privacy expiry remain authoritative and are never delayed for energy savings. Resize and animation perform no provider work, per-frame network or disk I/O, image decoding, global layout invalidation, or repeated font measurement.

## Dependencies and Review Boundary

- [F29-A page and match flow](../DOCKS.md) owns entry, canonical match/result routing, state-aware leaving, the active-match coordinator, and return navigation. Its older side-by-side and iPhone-first fallback wording does not override the approved native Mac and always-vertical battle direction in this child.
- [F29-B AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns accepted scores, units, draw meaning, safe explanations, and judging versions. History never rejudges.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns private started-match history, twenty-row stable snapshots, rating effects, placement, forfeit/no-contest distinctions, and bounded audited corrections.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) owns report, hide, block, case, and dispute destinations and their actual receipts and safe reasons.
- [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) owns account authorization, protected cache boundaries, revocation, media lifetime, deletion, and service readiness.
- F29-F owns trusted public identity, optional self-declared country, and earned badges. Local cosmetic previews are not authoritative history or battle achievements.

The shared account/navigation foundation, real private-history and exact-match service contracts, coherent correction revisions, authorized cache policy, and canonical result/safety destinations must be implemented and human-reviewed before this view is connected for real use. A documentation placement, preview fixture, or existing exercise-history implementation does not satisfy that boundary. Missing authority is surfaced honestly, not filled by a production mock, local Elo, placeholder row, or dead button.

## Files and References

These are ownership locations and context, not claims that new app files exist.

- This DOCKS.md owns match-history product behavior. Its separate future implementation brief is [F29-A-o phase 1](../../../../prompts/F29-physique-duels/F29-A-o-phase-1-match-history.md).
- Prospective TimeMaster/Views/Physique/PhysiqueMatchHistoryView.swift owns the ledger, adaptive native composition, selection, and paging presentation. A small history-row and selected-summary file may separate their distinct view identities without building a generic framework.
- The reviewed Physique account/history service and TimeMaster/Models/PhysiqueDuelModels.swift own authorized records and their meanings. History consumes those foundations rather than editing competitive state locally.
- [RankedMatchHistoryView.swift](../../../../TimeMaster/Views/Ranked/RankedMatchHistoryView.swift) supplies nearby native history conventions, not Physique score defaults, a practice toggle, permission to merge incompatible pages, or a polling design to copy.
- [RankedAccountStore.swift](../../../../TimeMaster/Services/Ranked/RankedAccountStore.swift) and [RankedAPI.swift](../../../../TimeMaster/Services/Ranked/RankedAPI.swift) establish account-change clearing and authenticated-request patterns. Their exercise endpoints are not Physique endpoints.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own palette, scalable typography, spacing, native-material fallback, and press feedback.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) establish the existing Mac window and command boundaries.
- [The supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) informs direct timer/identity/player hierarchy only. Its horizontal players, purple/brown web pills, faces, footage, and labels are not app assets or this history layout.
- [Apple HIG: Lists and tables — Best practices, Content, and macOS](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) informs succinct rows, selection feedback, and readable detail disclosure. Fixed chronology here is a product choice, not a claim that Apple requires unsortable tables.
- [Apple HIG: Panels — inspector functionality](https://developer.apple.com/design/human-interface-guidelines/panels) informs selection-following supplementary detail; this design chooses an in-window trailing pane rather than a floating HUD.
- [Apple HIG: Designing for macOS — Best practices](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) informs resizable native windows, comfortable density, keyboard/pointer access, and reduced modality.
- [Apple HIG: Motion — Best practices and Providing feedback](https://developer.apple.com/design/human-interface-guidelines/motion) informs brief, purposeful, interruptible feedback and equivalent nonmotion information. The exact history timings above are design decisions, not Apple-specified durations.
