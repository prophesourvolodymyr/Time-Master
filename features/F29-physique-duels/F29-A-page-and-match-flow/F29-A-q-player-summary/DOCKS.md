# F29-A-q — Player Summary

## Purpose and Boundaries

Player summary is a brief, read-only competitive identity surface opened intentionally from a paired player's identity or a permitted Physique standings row. It answers who this account publicly presents as, which public achievements the service permits this viewer to see, what rating applied to this pairing, and what competitive record is public now. Report player and Block player remain directly available without opening a photograph.

This is a product specification for native iPhone and native macOS, not an implemented view, accepted prototype, operational service, or permission to start production work. The [F29 parent](../../DOCKS.md), [page and match flow](../DOCKS.md), and F29-F's shared identity and badge product constrain this surface. Detailed existing numerical policies remain proposals unless separately accepted.

The summary is not a third Profile side, an expanded social profile, a public match-history browser, or a body-photo destination. It adds no follow, messaging, rematch invitation, avatar editor, country picker, share/export button, verification process, or new standalone window. Those controls must not appear as nonworking affordances.

## Chosen Composition and Tradeoffs

Use a sports credential rather than a social profile: a modest permitted avatar or neutral silhouette, a strong handle, complete wrapped achievement rails, and one compact competitive record. There is no full-height portrait or body-shaped score visualization. The avatar is not expandable.

When opened from a pairing, the match-context rating is the first numeric section. A separately labeled current public summary follows only when authorized. This costs an extra scope label, but prevents a present-day rating from being mistaken for the opponent's match-start rating. Opening from standings has only the current public section; it does not manufacture a match context.

On iPhone, use one native large sheet with scrolling content. A small half-height peek is deliberately not the default: it would repeatedly hide badges or crowd the safety actions at large text. On Mac, use a trailing nonmodal inspector when the host and inspector remain readable together; otherwise use the same content as a full-width, in-window expanded section. This avoids blocking the whole match with a desktop modal or compressing two players into tiny thumbnails.

The summary's own composition contains one identity and no battle evidence. Wherever its host's battle composition remains visible, preserve the real timer at the top, both complete owner-grouped identity and badge rails below it, and two large VERTICAL player panels below the rails: You above Opponent at every width. Do not turn the inspector into a third player card or move the players side by side. In short windows, scroll the stage instead of shrinking the people. Timer, safety access, and state-aware exit remain reachable. An idle standings summary has no invented timer or second participant.

## Visual Hierarchy and Copy

Use existing Tmax near-black background, dark elevated surfaces, white primary text, orange action accents, Inter Black headings and Inter Regular supporting text. Shared source conventions own spacing, corner treatment, readable width, materials, and press feedback. This surface introduces no global theme, web-style purple/brown pill system, or 26-only material requirement. Important supporting text must remain readable on its actual background; do not inherit a low-opacity caption merely because an older component uses it.

Content order is consistent on both platforms:

1. Native presentation chrome with the heading Player and Close. During a real active timed match, the top content anchor is the shared clock and stage, followed by Return to match and the parent's explicit exit route. It reads the same authoritative clock as the host, not another independently started timer.
2. Identity: permitted avatar or neutral silhouette, full readable handle, optional self-declared country or region beside the handle, and You only for the signed-in person's own row. No trophy crown, checkmark, Verified caption, inferred demographic, account email, or raw account identifier.
3. The complete permitted public badge rail, grouped under this identity. All badge labels wrap into additional rows; there is no selected-three limit, hidden +N, horizontal marquee, clip, or hover-only explanation.
4. This pairing or At match start, only when the entry actually carries an authorized pairing or match context. Show its Physique Elo or truthful placement state and its actual time context.
5. Current public: permitted current Physique Elo, placement, and the concise allowed competitive record. The freshness label belongs to this section, not to the historical rating above it.
6. A short inline explanation only when requested by a badge or record disclosure. The badge rail itself never collapses behind this explanation.
7. Persistent, separated Report player and Block player controls for another legitimate target. They are secondary safety actions, not an orange primary task or a requirement to finish viewing the summary.

Use concise copy without hiding scope, privacy, consequences, or recovery:

| Situation | Visible copy and meaning |
| --- | --- |
| Normal heading | Player; the real handle is the identity, not a fictional player name |
| Pairing before Go | This pairing; its rating is the service's current pairing snapshot, not a claimed completed match |
| Go confirmed or saved active-match context | At match start, with the actual match date/time where needed to distinguish context |
| Current rating | Current public and Physique Elo; do not use an unlabeled large number |
| No earned rated result | Unplaced; no earned rating, tier, rank, peak, or visible 1,000-point seed |
| Partial placement | Provisional, with the actual completed count out of five where this field is permitted |
| Authoritative empty public record | No rated matches; genuine supplied zero counts remain zero |
| Public record withheld | Record not shared; not No matches or a zero-filled scoreboard |
| No country shared | Neutral globe beside the handle; accessible Country not shared |
| Confirmed empty badge collection | No badges yet; only an authoritative empty collection permits this copy |
| Badge data unavailable | Badges unavailable; retain allowed last-confirmed values only under their actual saved-data policy |
| Correction settling | Rating updating, with last confirmed public values labeled as such; no public allegation or private review reason |
| Unknown block acknowledgement | Hidden here · block not confirmed; do not say Blocked everywhere |
| No longer permitted | Player unavailable; do not distinguish a private account, deletion, restriction, or reverse block by inference |

Long or non-Latin handles wrap, including in the sheet and inspector heading area. They do not push safety controls away or shrink into unreadable text. Preserve the service's moderated display spelling and safe fallback. The trusted account reference, not a mutable handle or a flag, keeps the selected target stable.

## Identity, Country, and Avatar

A legitimate identity is an account identity supplied and authorized by the trusted service. It does not mean verified real-world identity, verified age, or proven ownership of the depicted physique. Public-facing text must not imply those claims.

Country or region is optional and manually self-declared under F29-F. Show the supported flag emoji beside the handle, with the full region name and Self-declared available to accessibility and a short inline explanation. A missing value uses the neutral globe, not a guessed flag. An unsupported emoji uses the same neutral globe and the permitted region name when available; it does not change the declaration. Do not infer country from device locale, IP, GPS, language, appearance, clothing, or a background. There is no country filter, nationality ranking, location permission, or scoring role.

Use an avatar only when the service explicitly permits that public avatar for this viewer and context. A local Profile photograph, pose capture, thumbnail, old avatar URL, camera buffer, or editable local badge preview is not such permission. No image is uploaded merely by entering this summary. If no permitted avatar exists, use shared neutral fitness artwork or a neutral silhouette; if its approved asset is unavailable, the native neutral person symbol is an honest nonphotographic identity treatment, not a generated replacement portrait. The silhouette makes no anatomy, age, gender, or nationality claim.

Avatar loading reserves a modest stable place in the identity row. Failure replaces it with the neutral treatment and does not make the whole summary fail. Do not add an avatar retry/gallery/editor surface or expose an obsolete image after access is revoked. The summary does not create its own persistent image-bearing cache.

## Complete Public Badge Presentation

F29-F owns the badge catalog, eligibility, permission, order, and authoritative awards. This surface consumes those decisions rather than computing achievements from local match rows or importing cosmetic Profile selections.

For this hierarchy, placed status and its truthful current tier occupy one composite item, followed by the truthful current win streak when supplied, then every earned milestone in the shared catalog order. The launch milestone reading order is First Bell, Ten Rounds, Three Straight. F29-F must publish one canonical order used by every consumer; player summary must not introduce a competing order, scarcity tier, or selected-badge preference. The composite Placed/tier item still exposes both meanings to accessibility.

| Public item | Meaning shown on disclosure | Boundary |
| --- | --- | --- |
| First Bell | First effective valid AI-judged win, loss, or draw | A forfeit, no-contest, or pending result does not earn it |
| Placed and current tier | Five effective rated results under F29-C, with the tier supported by the current confirmed rating | Eligible rated forfeits can count for placement; correction back to provisional removes the placed/tier item; it is not verification |
| Ten Rounds | Ten effective valid AI-judged matches | No forfeit, no-contest, cancellation, or pending judgement counts toward this milestone |
| Three Straight | Achieved an effective canonical win streak of at least three | Eligible opponent-forfeit wins can count under F29-C; this is a historical milestone, not a claim that the current streak is three |
| Current win streak | The actual current consecutive effective rated wins under F29-C | Draw, rated loss, or own rated forfeit resets it; no-contests neither extend nor break it; unavailable is not zero |

A supplied zero current streak is neutral Win streak · 0, not a flame, a broken badge, or a taunt. A retained Three Straight milestone can coexist with zero current streak, and its explanation states why. There are no paid competitive advantages, anatomy or gender badges, moderation-goodness badges, absence-of-reports awards, or verification-lookalike shields.

A tap, click, keyboard activation, or accessibility action on a badge reveals its short F29-F explanation immediately below the whole rail. Activating the same badge closes its explanation; selecting another replaces the explanation in place. This is not a new sheet or screen, and never hides the other awards. Dismissing the summary clears the transient explanation selection, not the award.

A fresh service-confirmed unlock inserts the actual award once, with its explanation available immediately. Browsing, reopening, restoring the window, or reading a saved summary never re-awards it. A correction replaces the coherent collection and removes invalid awards or outdated placed/tier status. Never leave an honorary Placed badge after the account becomes provisional. Do not expose another person's private correction reason, case status, reports, or enforcement detail.

A refresh or offline cache is explicitly labeled Saved with its real timestamp when it is no longer current. Missing badge data is not an empty collection. If a permitted future catalog item has an unsupported glyph, use a neutral medallion with its approved public label and explanation. If safe catalog text is unavailable, retain an individually visible unavailable-item treatment rather than silently dropping the award or inventing its meaning. The shared catalog owner resolves unsupported definitions; this view does not create a local achievement rule.

## Match-Time Context Versus Current Public Record

The matched opponent can authorize a pairing identity and match-time rating without being publicly listed. That participation context is not permission to browse the account's current public record, private transactions, or other matches.

Before Go, This pairing uses the actual currently confirmed pairing snapshot. If the service revises it before start, the labeled snapshot changes coherently. After authoritative Go, At match start uses the frozen match rating and placement context. A later win, correction to an earlier match, present-day handle change, current tier change, or leaderboard refresh does not rewrite that start context. If the service supplies a separately identified correction to this specific context, show it as corrected rather than silently replacing history.

Current public is a separate present-day authorized snapshot. Its rating, placement, permitted record, streak, and badges agree with one coherent service revision. Do not combine a new Elo with stale wins, old placed status, or an earlier badge collection while a correction is settling. A last-confirmed snapshot may remain labeled while refreshing only if it is still permitted; denial or revocation is never disguised as an ordinary refresh failure.

When both ratings happen to be equal, keep both scope labels. Do not collapse them into one ambiguous number. When they differ, do not calculate points gained since your match, infer intervening results, show an opponent's private rating change, or animate one number into the other. The summary contains no opponent before/change/after transaction, date-indexed history, average AI score, body measurement, confidence percentage, win prediction, or model-generated biography.

The concise record contains only service-permitted wins, losses, draws, and total rated matches, with an accessible explanation of the units. Visible W, L, and D may be used alongside the numbers when their full names are exposed semantically. Wins include eligible opponent-forfeit wins; losses include own eligible forfeit losses; forfeits are subsets rather than extra matches. Draws count as rated matches. No-contests, searches, cancellations, practice, and pending results do not contribute. There is no public list of the underlying matches, no tappable count leading to one, no invented public no-contest/forfeit breakdown, and no extra peak-rating or win-rate dashboard.

An unplaced account shows Unplaced without the pairing seed. A provisional account shows only the actual authorized earned rating and actual placement progress, not an assigned tier or public provisional rank. A placed current tier is supported by the current confirmed Elo. Public ranking position stays in the standings host; the summary adds no guessed position, change arrow, or tied-rank rule of its own.

If public visibility is withdrawn while the summary is open, remove the current public fields and any no-longer-permitted avatar, country, or badges immediately on that authorization update. In a still-authorized match context, keep only the matching context the service explicitly allows. Do not convert private fields into saved public content. A renamed account remains the same selected service identity; historical display labels remain historical only where lawful and permitted. Deleted or blocked identities never remain rediscoverable through old labels.

## iPhone Composition and Behavior

Support the existing iOS 16 deployment floor. Present one native large sheet using normal platform dismissal and measured safe areas. Use a readable single-column stack, shared insets, and forty-four-point interaction areas for the feature's touch actions. The short identity row is not a hero photograph. All permitted badges wrap above the rating/record sections and remain present at accessibility text sizes. Use vertical scrolling, not fixed screen coordinates, clipped rails, reduced type, or a carousel.

The navigation header retains a clearly labeled Close. If the service transitions the originating pairing into a real active timed phase while the sheet is open, show the true timer and stage at the top of the sheet, change the return action to Return to match, and retain an accessible explicit Exit match route to the parent's actual consequence-aware confirmation. A static pairing without a clock says its actual stage; a standings-only summary has no clock. The clock and safe actions must not scroll out of reach with a long badge explanation or record.

Report player and Block player sit in the safe action region, separated and labeled. At very large text they stack and grow; the body scroll area yields room rather than clipping labels. System presentation must not create an extra fake primary action. Returning is the normal way to finish reading.

A swipe dismissal closes only this read-only summary and restores its entry context; it is not consent, Ready, cancellation, capture, or a forfeit. The underlying active-capture surface retains its separate protection against accidental swipe-to-leave. If a report is opened, replace the summary presentation with the shared safety flow rather than stacking sheets. Returning from that flow restores the same authorized summary and safety-control focus unless the target has become unavailable.

Opening a covering summary stops or shields any underlying capture immediately through the shared camera owner. Before Go, a Ready claim cannot remain valid if the camera or permissions no longer satisfy readiness. The shared readiness controller reconciles that fact with the service; a local UI transition does not prove acknowledgement. A Go race restores the actual active state, not a fabricated pre-Go cancellation. No reading action pauses the match clock, grants more retakes, extends grace, or adds a charge. Returning never silently captures a still; explicit valid camera resumption belongs to the host.

Landscape, a short phone, the keyboard in the subsequent report flow, large text, and a call/interruption must not hide Close, return, safety, or exit. This summary itself has no editable field and does not summon a keyboard.

## Native macOS Composition and Behavior

This is an AppKit-native macOS 14-or-later SwiftUI presentation, not Catalyst, a web view, or a stretched phone sheet. Preserve Tmax's ordinary title bar, traffic-light controls, WindowGroup behavior, and existing 800 by 600 minimum. Do not raise the app-wide minimum to solve this component's layout.

When measured space permits a readable host and readable details together, the summary is a trailing nonmodal inspector within the same window. Its header contains Player and Close, its body scrolls independently, and its safety actions remain reachable at the bottom. The host's timer and exit/safety controls stay outside the inspector's scrolling content and remain usable. The inspector is supplementary identity information, not a second column of battle participants.

When the inspector would make either region unreadable, including an 800 by 600 short window with expanded text, use a full-width expanded summary section in the existing content scroller. In a paired host it follows both owner-grouped badge rails and precedes the two large vertical players. In standings it follows the selected row. A persistent host action labeled Hide player details closes it even when the section's own header is scrolled away. Timer and match-safe actions remain outside the scrolling stage. The section does not float over bodies, detach into an unowned window, or require a fixed screen-size breakpoint.

On a laptop, large display, full-screen window, or external display, keep a comfortable readable details width derived from existing shared conventions. Spare width is not permission to enlarge an avatar into a portrait, stretch a few record numbers across the whole screen, or make the players horizontal. Live resize can move the same open summary between inspector and inline placement without changing the selected account, resetting disclosure/scroll state unnecessarily, refetching per resize frame, or reconstructing a camera session. Preserve focus on the same logical control or the corresponding summary heading if its container changes.

Pointer hover gives ordinary affordance and native help where useful. No action or badge explanation is available only by hovering. Wheel and trackpad scrolling affect the region under the pointer. Full Keyboard Access traverses real controls; readouts remain readable to VoiceOver without making every static number a Tab stop.

Preserve Command-N, Command-Shift-R, Command-comma, and Command-Option-O. Add no global Return, Space, letter, or number capture. Return and Space activate only the focused semantic control where normally applicable, and never trigger Block, Ready, capture, or a forfeit while someone is typing in a report. Escape closes an open badge explanation first, otherwise the summary; a topmost confirmation cancels that confirmation, and a meaningful report draft follows the shared unsaved-draft rule. Escape from the summary is not Exit match.

Command-W and Quit act on the real native window/app lifecycle. A genuine active-match departure uses the shared consequence-aware confirmation where the platform permits. Closing only the inspector has no match consequence. Force quit, crashes, power loss, and camera cable removal cannot be prevented or relabeled as confirmed voluntary forfeits.

The summary never requests or owns camera/TCC permission. Denied, restricted, absent, busy, or disconnected cameras leave permitted public reading and reporting usable. A USB or Continuity Camera disconnection remains an honest host interruption, not a prompt to upload a file. If summary or safety UI obscures capture, stop or shield acquisition immediately; no hidden preview continues behind it. Inactivity, minimization, backgrounding, or screen locking stops acquisition and decorative work immediately. Returning restores the same service match and original deadlines before an explicit permitted camera resume.

A second window or another device may inspect only authorized information. It does not become a second camera owner, duplicate queue, match, judgement, or allowance reservation. Keep the real one-account/one-active-match owner and its recovery semantics.

## Actions, Reporting, Blocking, and Recovery

### Open, refresh, and close

Opening selects an existing authorized account/context and retrieves only the permitted summary. The first load has a named Loading player state and restrained native activity feedback, not fictional identity, rank, badges, or record. A permitted match snapshot may remain visible under its correct scope while a separate current-public fetch loads. A failed refresh preserves still-authorized last-confirmed content with its true saved timestamp; Retry retrieves the same target, not a new match or a judge reroll. Keep the reader's place and focus.

Close or Return to match restores the invoking pairing identity or standings row. If that row was removed or the pairing changed, restore focus to the safe match heading or nearest surviving real standings row and announce the change once. Do not move focus to an unrelated account that slid into the same row position.

### Report player

This is a contextual account/identity report, carrying only the legitimate target and an actually available match reference. It does not need a new screenshot or body-image attachment. Relevant username, impersonation, privacy, harassment, and conduct concerns go to the shared F29-D flow; image-specific concerns and scoring disputes keep their own existing routes. The summary does not add an image viewer or a false nudity-evidence requirement.

Use the shared report owner for category validation, optional note, evidence/retention disclosure, sending, receipt uncertainty, duplicate handling, private case access, support, and safe draft recovery. Sending disables only duplicate submission. Only an actual acknowledgement permits Report received. Offline remains Not sent, and an uncertain response remains Not confirmed until reconciled. A protected text-only draft is bounded by F29-D/E's twenty-four-hour, discard, and sign-out rules; it is not an evidence hold. Never add another person's report state or a goodness badge to their summary.

### Block player

Report and Block are independent. Block first presents the shared state-aware confirmation with Cancel and Block player, naming the actual consequence:

| Actual context | Consequence explained before confirmation | Visible result |
| --- | --- | --- |
| Standings, no current pairing with this target | Hide this player from discovery and prevent future pairings once confirmed; no rating effect | Shield identity/related media locally immediately after confirmation; remove its discoverable row; do not renumber other standings |
| Paired before authoritative Go | Cancel this pairing, release its reservation, and change no Elo | Show cancellation/block progress honestly; return to the lobby only after reconciling the service's actual pairing state |
| After Go, before finalization | Hide relevant media and exclude future pairings; this does not leave, settle, or rerate the active match | Keep Return to match and the separate real exit action; use neutral player placeholders |
| Final result becomes available while inspecting | Preserve the actual result; blocking removes paired-gallery access but does not reverse Elo | Retain permitted own result context in its owner; do not offer an opponent gallery here |
| Offline or acknowledgement uncertain | Hidden on this device now; other devices and future pairing protection are not yet confirmed | Show block pending/not confirmed, allow explicit retry or reconciliation, and prevent a new pairing under unresolved block state |

If Go or finality changes while the confirmation is open, update its consequence before accepting a destructive action. A button originally described as pre-Go cancellation cannot silently become consent to Forfeit and leave. Block itself is never that forfeit. A service-established safety, evidence, or provider no-contest retains precedence under F29-C/D/E; opening a report or blocking alone does not establish it.

Protection and removal of now-forbidden identity/media occur before animation. Once blocked, the current summary becomes a neutral Blocked player or pending-local-protection state with Close, permitted retry, and an existing contextual report route where lawful. Do not leave the old avatar, flag, badges, or public record visible behind a Blocked overlay. Do not provide an inline unblock toggle; the shared Safety area owns explicit unblocking and must not automatically restore galleries or contact.

## Complete State Contract

| State | Visible presentation | Action and recovery |
| --- | --- | --- |
| First load without permitted content | Loading player, native activity, Close, and legitimate safety access if a target is already known | Retry after a real failure; no sample identity or zero-filled record |
| Allowed match context, public fetch loading | Correctly scoped pairing/start snapshot; current public section says Loading | Match context is not relabeled current; return and safety remain usable |
| Fresh listed placed account | Permitted identity/country, all public awards, placed/tier item, current Elo, allowed W/L/D and rated total | Badge explanation, Report, Block, Close |
| Unplaced account | Unplaced, actual permitted empty record if known, no tier/rank/seed | No prompt to verify or buy placement |
| Provisional account | Actual earned Elo and permitted count out of five; no assigned tier or provisional rank | Same read and safety actions; no locally incremented progress |
| Confirmed no public badges | No badges yet, not locked badge slots | No challenge, purchase, or unsafe exertion CTA |
| Badge service/catalog partly unavailable | Correct saved/unavailable labels for affected items; all known permitted awards remain represented | Retry the real summary; no invented award meaning or hidden +N |
| Public record or current profile not shared | Record not shared or Current public unavailable; retain only authorized pairing context | No private history link, inferred zero, or demand to change privacy |
| Refreshing still-authorized data | Retain one coherent last-confirmed public snapshot with freshness and quiet activity | No destructive replacement with loading placeholders; Close still works |
| Offline with a permitted saved text summary | Saved with its real timestamp; no live rating/rank claim | Retry; local protection remains possible; cache policy still applies |
| Offline with no permitted saved content | Could not load player, Offline, Retry and Close | Do not say unlisted, empty, or deleted without authority |
| First-load service error or access failure | Specific safe unavailable/error state, Retry where meaningful | Do not fall back to unrelated local Profile or another account's cache |
| Fresh correction settling | Rating updating and coherent last-confirmed permitted fields | No award animation, public accusation, mixed counts, or guessed corrected tier |
| Correction settled | Coherent current record/badge collection; historical start context remains correctly scoped | Remove invalid achievements immediately and announce a meaningful update once |
| Avatar missing/fails | Neutral identity treatment and normal permitted text | No local photograph upload or body capture fallback |
| Country missing/unsupported | Neutral globe, truthful accessible text and permitted region name when available | No guessing, mandatory picker, or scoring change |
| Handle changes while open | Same target account with current allowed label; separately permitted match label stays scoped | No former-handle directory, identity switch, or focus jump |
| Subject becomes unlisted or inaccessible | Remove revoked current identity fields; neutral unavailable state or only authorized match context | Close and existing permitted safety route; no reason inferred from the denial |
| Target deleted, reverse-blocked, or restricted | Player unavailable without publishing why | No stale avatar/handle link or rediscovery through history |
| Own account selected from standings | You and own permitted public summary | Omit Report player and Block player rather than adding disabled self-actions; no profile editor |
| Signed out/session expired | Clear account-bound content, Sign in where required, Close, published support as allowed | Resume the intended summary only after real account/access checks |
| Account switched | No previous account's summary permissions, saved context, drafts, or block receipts | Resolve afresh for the new viewer; never show a transient old-account frame |
| Report editing/sending/received/failed | Shared safety flow replaces the summary presentation | Preserve valid text and honest receipt status; return to the permitted target/fallback with focus |
| Block confirmation cancelled | Existing authorized summary unchanged | No block request, no match cancellation, no forfeit |
| Block pending or failed | Local shielding plus Not confirmed and permitted Retry | No cross-device success claim or new matching under unresolved exclusion |
| Block confirmed | Neutral blocked state and corresponding host row/media removed | Close and permitted reporting; no automatic leave/rerating or local unblock |
| Countdown/Go arrives during inspection | Actual top stage/clock and Return to match; revalidated safety consequences | No additional countdown, silent dismissal, camera capture, or timer reset |
| Finality arrives during inspection/report | Quiet actual match-status change; current public data refreshes only when settled and authorized | Do not steal focus or discard report text to play a result celebration |
| Camera denied or disconnected | Permitted summary remains readable; actual host camera status stays honest | Close/return to shared Settings/Retry/Resume or no-contest recovery; no rated file picker |
| App inactive, minimized, locked, or backgrounded | Immediate shared privacy cover for sensitive host context; no hidden acquisition or decoration | On return reconcile same match/access, then explicitly resume valid capture if needed |
| No longer active or timed | Remove the active clock only after actual state reconciliation; show current context | Never show a stopped-at-zero timer as proof of a local outcome |

A missing permission or field is different from an authoritative zero. Partial content must never splice snapshots or use local competitive estimates to fill gaps. Public browsing does not require camera consent or an available judge; actual account and public-visibility access rules still govern it.

## Accessibility and Focus

On opening, move VoiceOver focus to Player and the identity/scope heading, not Block. Read identity, optional self-declared country, badge rail, match context, current-public scope/freshness, record, and safety actions in that order. A supported flag has its region name, not only its emoji spelling. Decorative silhouette detail is not an anatomical description.

Every badge is an individually named semantic control with its earned/status meaning and an expanded/collapsed explanation state. Explain historical Three Straight separately from Current win streak. Do not force a reader to focus every decorative badge layer. Static metrics expose full units and labels: Physique Elo, wins, losses, draws, rated matches, provisional progress, and saved time. Unknown, zero, withheld, and updating have distinct accessible values.

Opening an inline badge explanation leaves focus on that badge and exposes its explanation next in reading order. A correction does not repeatedly pull focus back to the header. If the focused badge or identity is removed, move focus to the replacement explanation or neutral summary heading and announce the material change once. Hiding/blocking never leaves focus on an invisible old avatar or button.

Announce meaningful milestones and confirmed actions once, not every timer second, spinner loop, unchanged refresh, or intermediate animated value. Let the shared match owner own countdown/critical-deadline announcements so an open summary does not double-speak them. A clock remains inspectable as a current value.

Support the largest Dynamic Type sizes on iPhone and readable enlarged text on Mac without type clamps, one-line badge truncation, minimum-scale-factor tricks, or horizontal scrolling. Maintain visible keyboard focus, sufficient text/control contrast, and opaque readable surfaces for Reduce Transparency and increased contrast. Outcome, provisional status, saved state, and protection never rely on orange, a flag, flame, haptic, or animation alone. Voice Control and Switch Control can operate all actions without a precise swipe, long press, or hover. Sound/haptics are optional reinforcement, not required to inspect or report.

## Motion, Interruption, and Energy

This is tactile supporting motion, not a second battle celebration. The summary adds no ambient loop; an already-visible host may retain at most its one quiet shared ambient layer. There is at most one focal event at a time. No spinning crest, pulsing badge wall, slot-machine record, body scan, winner suggestion, punishment shake, or endless shimmer.

| Trigger | Proposed motion | Timing, interruption, and reduced behavior |
| --- | --- | --- |
| Press a shared action or badge | Existing shared tactile press response; no custom elastic card lift | Shared spring response 0.24 and damping 0.88; release/cancel is interruptible, only semantic activation acts; Reduce Motion removes scale |
| Open/close iPhone summary or native safety presentation | Ordinary native sheet motion in its expected direction | Follow system timing and Reduce Motion; do not add a second delayed content entrance or block interaction until completion |
| Open/close Mac inspector or inline section | Short continuity expansion/reveal with content already available | Custom continuity target 280 milliseconds, ease-out and no bounce; reverse from current presentation on dismissal; Reduce Motion uses immediate layout or at most 120-millisecond opacity |
| Select or dismiss badge explanation | Explanation replaces/fades; whole rail stays in place | 180 milliseconds, ease-out; newer selection replaces the prior transition, never queues it; Reduce Motion uses immediate text or short opacity |
| Fresh permitted identity/avatar arrives | Neutral identity treatment changes without moving the record | 160-millisecond opacity after safe content is available; revocation removes content immediately, never crossfades a forbidden image; Reduce Motion may use immediate replacement |
| Real timer tick while timed context exists | Stable monospaced digits update using the host's clock | Approximately 180 milliseconds on a real second; no spring growth, fake countdown, drift, or independent timer; Reduce Motion shows static current digits |
| Confirmed public values or badge collection updates | Brief neutral update of the affected values/items | 180 milliseconds; final semantic values are immediate, no Elo count-up or repeat unlock celebration; consolidate one coherent revision and latest update wins |
| Enter/leave pending or failed state | Status icon and concise text change, without whole-panel travel | 160 milliseconds, no artificial minimum spinner duration; closing does not wait; Reduce Motion is static/short opacity |
| Block, access revocation, sign-out, or privacy shield | Forbidden content is removed before any other visual work | Immediate, including during another transition; no revealing crossfade, acknowledgement delay, or queued animation |
| Resize, move to external display, return from inactivity | Reflow the same logical content and reconcile current state | No celebratory entrance/replay; no per-frame fetch, avatar decode, provider call, font measurement, or camera reconstruction |

Pause offscreen decorative work, inactive/minimized/background animation, and unnecessary refresh activity. Low Power Mode or thermal pressure removes optional interpolation and transitions; authoritative clocks and safe actions continue with correct information. Network fetch, image loading, sorting, and service work do not run per animation frame. Browsing a player makes no judge/provider call. Privacy stop, content revocation, and camera ownership changes never wait for motion. Reopening a summary is not an earned-event trigger.

## Dependencies and Review Boundaries

- [F29-A page and match flow](../DOCKS.md) owns the pairing/standings entry hosts, shared presentation ownership, camera visibility/readiness, top clock, active-match exit, and restoring the correct parent state.
- [F29-B AI judging and metrics](../../F29-B-ai-judging-and-metrics/DOCKS.md) keeps identity, country, Elo, badges, and all UI chrome out of judge inputs. Only clean, locally face-obscured accepted capture follows its real evidence path; a screenshot of this UI is never judge evidence.
- [F29-C rating and matchmaking](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns match-time snapshots, current ratings, placement, counts/streak meaning, public listing, exactly-once effects, corrections, and exclusion from future pairing.
- [F29-D safety and reporting](../../F29-D-safety-and-reporting/DOCKS.md) owns report/block confirmations, acknowledgement and draft states, immediate protection, cases, moderation, and safe support.
- [F29-E privacy and service operation](../../F29-E-privacy-and-service-operation/DOCKS.md) owns authentication, current authorization, cache/access lifetime, camera lifecycle, retention, deletion, and account switching.
- F29-F owns canonical permitted identity, optional self-declared country, avatar authority, badge definitions/order, awards, and removals. Its canonical context belongs in the shared F29 ownership map; this child does not create a parallel catalog or fill a missing service foundation.
- Existing native account, navigation, shared controls, one-active-match ownership, public summary permission, and safety contracts must be implemented and human-reviewed before this view's production implementation begins. UI-only fixtures do not satisfy those prerequisites. Pending foundation review remains pending.

The older F29-A allowance for balanced two-column comparisons does not override the later user direction: every co-present battle remains vertical on iPhone and Mac. This child defines supplementary summary placement, not an unrelated rewrite of the parent battle, Profile, or standings product.

## Files and Ownership

These are product ownership surfaces and prospective implementation locations, not existing implementation claims or a source-code recipe. Prospective source paths below name future ownership without pretending that a source file already exists.

- [This DOCKS.md](DOCKS.md) owns player-summary composition, scope distinctions, interactions, state presentation, and accessibility.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-q-phase-1-player-summary.md) owns the separate future coding assignment and observable acceptance.
- Prospective `TimeMaster/Views/Physique/PhysiquePlayerSummaryView.swift` owns the one shared summary presentation; that proposed file must be reconciled with the actual feature tree before implementation.
- The actual pairing and standings hosts under [TimeMaster/Views/](../../../../TimeMaster/Views/) own entry, adaptive placement, return focus, and the visible vertical battle/clock. Their future filenames are not asserted here.
- The shared Physique models/services owned by F29-C/E/F own authoritative public-summary data and its permissions; this surface has no local rating/achievement authority.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) own existing colors, typography, measured style conventions, material fallbacks, and press behavior.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) supplies nearby native action and earned-Elo visual language, not permission to reuse exercise identity, fake display levels, or text-size clamps.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) own native Mac window/command behavior. [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift) contains local cosmetic state, not trusted badge or avatar publication authority.

## References

- [Battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): borrow the dominant top clock, immediate participant recognition, and direct safety access. Do not copy its side-by-side players, labels over people, purple/brown pills, footage, faces, or implied publishing rights.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices: native window resize/full-screen, keyboard/pointer work, and less unnecessary modality inform the inspector choice.
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), especially Best practices and iOS/macOS platform considerations: use a scoped phone sheet, clear dismissal, one sheet at a time, and nonmodal supplementary Mac information. The chosen large initial phone presentation is a product decision to preserve badges and readable safety actions.
- [Apple HIG — Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Providing feedback: brief, purposeful, cancellable feedback informs the supporting transitions, with equivalent static information. These references are design guidance, not proof of application behavior or App Store approval.
- Installed swiftui-pro accessibility/navigation/performance guidance and swiftui-animation guidance inform future native work, subject to the project's actual iOS 16 and macOS 14 availability rather than those skills' newer-app defaults.
