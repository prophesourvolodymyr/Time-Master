# F29-A-t — Private Case Center

## Purpose and Boundary

The case center is the signed-in person's private record of their own received reports, their own appeals and outcome disputes, and restriction notices addressed to them. A received report means a report that this person submitted and the service acknowledged; it does not mean access to allegations submitted about them by somebody else. An affected person receives their own authorized decision notice, not the reporter's complaint, identity, or evidence package.

This area owns the private case list, selection, paging, receipt-to-record routing, and list-to-detail host on iPhone and native macOS. [F29-A-u](../F29-A-u-case-detail/DOCKS.md) alone owns the case document and safe correspondence; [F29-A-v](../F29-A-v-review-composer/DOCKS.md) alone owns new appeal/dispute composition. This list composes those existing destinations rather than creating another detail, reply sheet, or appeal form. It owns no moderation console, public case feed, opponent messaging, privacy-request manager, or competitive result screen.

The specification defines intended product behavior. It does not establish that a case service, staff operation, screen, camera integration, or accepted prototype exists. [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns review policy and permissible disclosure; [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns access, correspondence retention, deletion, and contact accountability. The service remains the only authority for receipt, status, available actions, enforcement, and corrections.

## Chosen Design and Tradeoffs

Use a private docket: a native list of concise textual records, leading to a factual decision and correspondence document. It borrows the sports interface's direct hierarchy, confident Inter heading, near-black ground, and one orange action, without turning allegations into competitive achievements.

The first list section is Needs you, present only when the service actually requests a supported next step. The second is Cases, containing all other currently available records. Within each section, the latest authoritative activity appears first. A restriction does not become an urgent task merely because an appeal is possible. Closed records remain reachable in the same list while retained and authorized; there is no decorative completed-task dashboard.

A compact type symbol, clear type title, real status, and date are more useful here than avatars, evidence thumbnails, colored severity scores, or a multicolumn administrative table. Sensitive detail stays one deliberate selection away. Native selection and disclosure carry the interaction; no custom swipe drawer or long-press discovery is required.

Selecting a record opens the canonical F29-A-u decision and correspondence document. Its current-state header, permitted action, and safe activity are the selected destination's contract, not a second case-detail implementation owned here. Plain asynchronous operator correspondence remains distinct from chat or an implied real-time support conversation.

The case center itself has no battle timer, player portraits, public badge wall, or pose images when opened from the lobby. Those would confuse case review with a new competition and unnecessarily expose another person. A real active-match context is treated separately below; a case-status age is never displayed as a sporting countdown.

## Entry and Account Access

Cases is reachable from Physique's Safety and support area, a service-confirmed report receipt, the person's own restriction or rejection notice, an appeal receipt, and a generic case-update notification. A contextual entry opens the exact authorized case. Normal entry opens the list without selecting another person's record or automatically showing the most sensitive correspondence.

Opening Cases does not request camera, microphone, Photos, location, notification permission, image-sharing consent, payment, or an adult-verification photograph. A participation restriction or declined physique consent must not remove account safety and contact access. A case reference identifies a record; it is not permission to read it.

A notification says only Case update available. It carries no allegation, decision category, opponent identity, report excerpt, image, sanction, or score. Following it requires the appropriate account and a current access check. Until authorization succeeds, no case title or existence-specific error appears. Returning through authentication preserves the intended destination only for the same authorized account.

A restricted session may retain explicit case-only access if the service allows it. If ordinary authentication is unavailable or a restriction prevents private case retrieval, published operator contact remains reachable without playing a match or creating a replacement account. Contact does not bypass authorization or reveal a case before the operator can establish the appropriate access.

## Visual Language

Reuse the existing background 0A0A0A, surfaces 141414 and 1C1C1C, white primary text, readable secondary text, shared separators, orange FF6A00 actions, Inter Black headings, and Inter Regular body. Use existing spacing, readable-column, focus, card, and button conventions; there is no new global palette, font system, or glass wrapper.

The one screen heading is Cases. The introductory line is Private reports, appeals, and decisions. It is visible at entry and need not repeat above every detail. A plain document symbol distinguishes a report, a return-arrow document an appeal, and a shield notice a restriction. A symbol is always paired with words and is not a verified-identity badge.

Orange denotes the selected action and restrained selection emphasis, not guilt, urgency, punishment, or a successful complaint. Native destructive treatment is reserved for a genuine destructive choice such as discarding a draft. No red-versus-green verdict wall, celebratory confetti, punitive shake, ranking crest, cleared-account badge, moderation-goodness badge, or report count appears in public identity.

Rows contain the type and a short safe contextual title, the current authorized status, and the last case-activity date. Examples of contextual titles are Safety report, Scoring review, and Participation restriction. Where needed, a match date or named pose disambiguates records without displaying a body or allegation excerpt. Full status and date wrap rather than being reduced to unreadable text. A long reference can be abbreviated in the row because its complete, selectable form is available in detail and accessibility output.

No raw report prose, staff-message preview, private eligibility declaration, other participant's avatar, evidence thumbnail, severity estimate, or precise sanction against somebody else belongs in a row. A genuine zero is not used to fill an unknown case count; a partial list does not claim a complete total.

## Native iPhone Composition

Use the existing navigation destination and a native list on iOS 16 and later. The top navigation area contains Back when appropriate, Cases, and labeled access to Contact support. Refresh is available through the native list gesture and an accessible explicit action, so it is not gesture-only. The list respects the actual app navigation safe areas and uses the shared insets rather than a fixed bottom spacer.

Needs you and Cases are vertically grouped native sections. Rows are full-width semantic navigation controls with a disclosure indicator, not an information button masquerading as navigation. The whole row is an adequate touch target using the existing forty-four-point convention. Status may move below the title and date may occupy another line at larger type; no horizontal scrolling or capped Dynamic Type is used.

Selecting a row pushes the canonical [Case detail](../F29-A-u-case-detail/DOCKS.md) in the same navigation stack. That owner supplies the document, exact case reference, permitted response, status, activity, and focus behavior. This list passes the authorized case association and preserves the originating row and scroll position.

Appeal and scoring-review actions reached from the selected document use [Review composer](../F29-A-v-review-composer/DOCKS.md), not a case-center-owned editor. Safe additional information stays within Case detail's inline response. There is no second reply sheet, new attachment route, or alternative case form in this slice. Back returns to this list's previous position without resubmission or changed authority.

## Native macOS Composition

macOS 14 and later is a first-class native target, not Catalyst, a web page, or a stretched iPhone sheet. Open Cases within the existing Tmax window and retain its normal title bar. At the existing 800 by 600 minimum and standard text size, use a native resizable two-column list/detail composition. The leading case list uses the smaller portion; the selected readable document uses the larger portion. Column sizing follows measured content and system split-view behavior, not fixed display coordinates.

The leading column retains Cases, the two sections, textual statuses, and native persistent selection. The detail has its own readable heading and toolbar actions for Refresh and Contact support. With no selection, the detail says Select a case and explains that it contains only this account's private records; it does not automatically open a report or imitate a loading error.

A laptop window keeps the action header and supporting document comfortably readable. A short window scrolls the document rather than reducing text size or hiding the next action beneath a fixed footer. The native toolbar remains reachable. If enlarged text or the person's chosen column widths cannot support both panes, the standard sidebar toggle and list-to-detail navigation provide an intentional collapsed layout with a clear Cases return control. Selection and draft ownership survive that change.

Larger, full-screen, and external-display windows keep the document at the shared readable-column width rather than stretching correspondence across the monitor. Extra width provides breathing room and a wider case list where useful, not a third moderation column, side-by-side players, more evidence, or a second composer. Live resizing preserves the selected case, scroll anchor, meaningful text, and keyboard focus. It never reloads a case, resubmits a reply, or changes case authority merely because the geometry changed.

Use native toolbar items, selection, separators, menus, text selection, focus rings, and standard sheets for reply and consequential confirmations. An inspector is unnecessary: small metadata remains a disclosure inside the document, so there is no competing third pane. A pointer hover can give ordinary control feedback but cannot be the only way to discover a timestamp, reason, appeal, contact action, or the full case reference. Context menus may duplicate visible Copy case reference and Open case actions, not hide essential behavior.

Multiple windows may display authorized cases for the same account. They reconcile the same service-owned record; two simultaneous sends cannot become two apparently received copies of one reply. A case-only window never acquires a camera, reserves a match, incurs an allowance charge, or becomes another capture owner. Account switch, sign-out, deletion, and access revocation affect every visible case window, not only the frontmost one.

## When Opened During a Match

Opening the case center from an active match uses the shared Safety presentation, not a detached second match or an unsolicited switch out of the match. Before leaving a camera surface, camera acquisition stops immediately and sensitive content is shielded. Opening a case is not a forfeit, a pause of the service clock, or an extension of the capture, reconnect, or judging deadlines.

The shared active-match status area keeps the real timer and Return to match reachable outside the scrolling case document. A concise line explains Camera stopped; match clock continues when that is the actual state. It does not introduce an artificial case deadline. A safety sheet obscures the stage rather than recreating two tiny participants inside a case row. On return, the app checks the same service-owned match before any explicit permitted camera resume; no preview or still automatically restarts.

Where the underlying battle composition is actually visible, its ordering remains the real timer first, complete public identity and badge rails grouped by owner second, and two LARGE VERTICAL participant panels third, You above Opponent, on both platforms at every width. All public badges wrap above the panels without a three-slot cap, hidden +N, clipped rails, hover-only detail, overlay on bodies, or a scrolling ticker. Short windows and large text scroll the stage rather than shrinking participants. Media is aspect-fit without body cropping or distortion. The case center never replaces these rails with a restriction badge or publishes case state there.

If the match ends while a person reads or writes, the shared status changes to the authoritative ended state and offers the ordinary result route. It does not force navigation, reopen pose media, erase safe text, or replay an award. Returning uses the same match and one account-wide match/camera owner across windows and devices, without a second allowance charge.

Cases itself never needs camera access. iPhone permission denial, macOS camera TCC denial or restriction, an absent external camera, and a Continuity Camera disconnect cannot block case reading, safe correspondence, or support. A return to capture uses the existing truthful permission or device recovery, not a file-picker substitute, fake preview, new timer, or repeated system-permission prompt.

## List, Identity, and Time Semantics

Only service-acknowledged records belong in the case list. Editing, Unsent, Sending, and receipt-unknown report drafts remain in their contextual intake surface. A received case may contain a correspondence draft, but that draft does not alter the case's confirmed status or activity time. A contextual receipt-unknown entry first reconciles the original request; it must not fabricate a case row to make navigation succeed.

A report, related restriction, and appeal retain their distinct service identities and clear type labels. Where the service presents them as a single case family, one primary list row opens that family and its linked decision or appeal. Where separate records are returned, each is labeled and linked; the UI does not merge unrelated records or count the same reply, duplicate receipt, or page twice. It never creates a local new case merely because a person refreshed, reopened a notification, or appealed.

The list sorts by actual most-recent case activity, not local fetch time, notification delivery, first viewing, or an invented unread time. A refresh preserves selection and the visible scroll anchor. A newly arrived case or reordered record must not move a focused row out from under a pointer or force the reader to the top. There is no automatic jump into new correspondence.

Distinguish three times: Received is the service receipt; Updated is the latest actual case event; Last checked is when this device last successfully refreshed authorized state. Detail activity uses service event dates. An unavailable event date says Time unavailable rather than using the current clock. The same event is never assigned a new date on another device.

List dates are locale-aware and concise. The detail exposes the full calendar date, time, and time zone in readable selectable text and accessibility output, without hover. Relative wording is supplemental, not the only record of a decision or deadline. Device clock uncertainty must not turn an event into a guessed future or past decision.

A next-response expectation appears only when provided by the actual operation, with its relevant time zone and staffing context. F29-D's proposed targets are not guaranteed completion times, a progress bar, or evidence a reviewer is online. A real response deadline says what action is requested and the stated consequence if missed. No deadline or consequence is invented. Passing a displayed end time does not locally end a restriction or authorize pairing; it prompts a status check and retains Last confirmed wording until the service answers.

## Status Meaning

| Confirmed state | Concise presentation and available behavior | Meaning that must not be implied |
| --- | --- | --- |
| Received | Received, receipt time, View details and Contact support | An automated receipt is not human attention or a finding |
| Queued | Queued, real update time, current published expectation if supplied | No queue position, review percentage, or immediate-response promise |
| In review | In review and any actual staff update | No typing indicator, continuous monitoring, or predetermined decision |
| More safe information requested | Reply requested in a row; full request and Reply in detail | No demand to reupload body evidence or prove age or gender with a photograph |
| Action taken | Action taken with the reporter's permitted non-graphic summary | No precise sanction, private declaration, or full moderation record of the other person |
| No violation found | No violation found with the safe decision summary | No public exoneration badge, shaming of a good-faith reporter, or judgement about every past action |
| Inconclusive | Inconclusive with the actual evidence limitation and remaining route | Missing or expired evidence is not proof of misconduct or innocence |
| Withdrawn | Withdrawn after confirmation, with the stated remaining handling where lawful | Withdrawal is not erasure, revoked lawful preservation, or an automatic score reversal |
| Closed | Closed and the actual closure reason and time available to this account | Closure alone does not mean a concern was upheld, denied, or erased |
| Appeal received or in review | Appeal received or Appeal in review, linked original decision, current restriction scope | An appeal does not suspend a restriction, reroll a judge, or restore media |
| Appeal upheld | Decision upheld, safe reason, remaining allowed contact | The UI must identify that the original decision was upheld, not imply the appellant won |
| Appeal revised | Decision revised and the actual changed consequence | No local competitive adjustment or automatic gallery restoration |
| Restriction notice | Own rule category, affected capabilities, effective time, duration or No end date provided, and allowed appeal | No fabricated permanent ban, inferred identity, public allegation, or automatic app-wide restriction |
| Restriction ended or removed | The service-confirmed changed access and any remaining limits | A local clock, dismissed notice, or successful send is not restoration authority |

Unknown or newly introduced service states receive a neutral Status unavailable presentation and support access until their meaning is understood. They must not default to Closed, No violation found, or an empty list. Status is conveyed in text and semantics, never color alone.

## Selected Detail and Support Handoff

The selected document belongs exclusively to [F29-A-u](../F29-A-u-case-detail/DOCKS.md). It supplies current status, safe decision and correspondence, actual dates, own restriction consequences, bounded response drafts, request uncertainty, authorized withdrawal, and reviewed correction context. The list does not implement or duplicate those fields as a second detail view. Its status summaries must remain consistent with that same service-owned case revision.

Selecting a real case routes to its canonical detail. A received appeal opens that existing authorized record; requesting a new permitted safety appeal or outcome dispute routes through [F29-A-v](../F29-A-v-review-composer/DOCKS.md). The list never creates an appeal identifier, response form, media attachment, local case closure, or replacement rating. If access or the target changes, preserve safe list context and let the detail owner show the current authorized recovery.

The Mac list/detail host embeds the same canonical Case detail in its trailing content area, not a third inspector or another document implementation. The iPhone route pushes that same detail. Both preserve account identity, selected case, reading/focus return, and active-match safety context. Missing reviewed detail/review destinations are real integration prerequisites, not reasons to ship dead rows or copy their behavior into the list.

Contact support uses the operator's actual reviewed and published channel. The person sees the recipient or official destination and chooses whether to include their own minimal case reference and safe text. A system mail or external HTTPS handoff is used only if that real channel is offered. The person reviews what leaves the app; no hidden correspondence, opponent information, body evidence, authentication token, or unsafe attachment is prefilled. Canceling a handoff sends nothing from the app. Opening a mail composer is not Support received.

The published contact method and staffing information are available even when sign-in, case retrieval, or normal intake fails, including offline when an authentic bundled or previously verified published copy is available. Never invent an address or silently replace a missing contact with a no-op button. Lack of a functioning reviewed contact channel is a service-readiness failure before public participation. A temporarily unreachable contact destination has an honest failure and an explicit retry or copyable published destination.

For urgent danger, the contact area says the app is not an emergency service and points to appropriate local emergency or specialist help without guessing location, requesting an image, or telling the person to confront the other participant. Exact guidance follows the operator's real reviewed publication, not an invented staffed promise.

## Loading, Failure, and Recovery States

| State | What is visible | Actions and recovery |
| --- | --- | --- |
| Restoring account | Neutral Cases heading and ordinary activity feedback, no prior-account list or detail | Finish real authentication or use published contact |
| Signed out | Sign in to view your cases, Sign in, Contact support, and ordinary return | No case titles, counts, existence clues, or previous account's text |
| First authorized load | Brief actual loading feedback in an otherwise empty list area | Contact and Back remain available; no sample case rows or fake progress |
| Confirmed empty | No cases, with Reports you send and decisions affecting you appear here | Contact support and return; no camera or Find opponent prompt |
| List loaded | Own confirmed records and truthful update dates | Select, refresh, contact, and load older available records |
| Refreshing | Retained authorized safe summaries, small real activity indication | Selection and scroll remain; no duplicate rows or blank-state flash |
| Older-page loading | Existing records plus activity at the list end | No complete-count claim or reorder to the top |
| Older-page failure | Existing records and a local Couldn't load older cases message | Retry that page; the failure is not No more cases |
| Empty result cannot be confirmed | Couldn't load cases, not No cases | Retry, contact, and return |
| Offline with allowed cached summary | Offline, Last checked time, and only protected same-account minimal summaries | Reconnect/Retry; no suggestion cached status is current or restriction has ended |
| Offline detail | Last confirmed safe status and dates if permitted; correspondence body unavailable | Online refresh or contact; existing bounded safe draft stays unconfirmed |
| Stale status | Last confirmed wording and the actual successful-check time | Refresh; no invented freshness interval or current-human-review claim |
| Individual detail failure | Selected row remains; Couldn't refresh this case in detail | Retry this case without discarding the whole list; contact remains |
| Session expired | Sensitive content is covered before the reauthentication route appears | Same-account authorization before restoration; no account-switch leakage |
| Access denied or unknown reference | Case unavailable with no unauthorized title, person, count, or existence detail | Back, appropriate account recovery, or published contact; no alternate-link bypass |
| Record no longer retained | Authorized neutral unavailable notice; actual retention reason only if safe and supplied | Return to list or contact; no reconstruction from old notifications or backups |
| Account restricted, case access allowed | Own scope and duration, allowed appeal/correspondence, unrelated permitted app routes | No new pairing or privilege bypass; safe contact always remains |
| Restriction end time passed, refresh unavailable | Last confirmed restriction and Checking current access | Retry/contact; no locally unlocked capture, standings, or pairing |
| Appeal or intake service unavailable | Confirmed case stays unchanged; action-specific unavailable message | Retry permitted intake or contact, without another fake receipt |
| Reply editing or not sent | Labeled protected safe draft, no received timestamp | Edit, explicit Send when possible, discard, or close under draft rules |
| Reply submitting | Sending, repeat Send disabled, other safe controls available | Closing does not label it received or silently cancel a request that may have arrived |
| Reply receipt unknown | Not confirmed and the preserved original submission context | Check status, then resolve/retry that submission once; no automatic new message |
| Reply received | One confirmed entry with real receipt time | Continue reading; no disappearing toast as the only receipt |
| Case changed or closed during editing | Latest authorized case state and an explanation of allowed next action | Preserve permitted text; reconcile before sending; do not reopen locally |
| Other participant deleted or unavailable | Neutral unavailable-player context where legally retained and permitted; own case state remains factual | No old handle/avatar restored, no implied innocence or guilt, and no automatic case closure |
| This account deletion completed | Private list, detail, drafts, and old sessions unavailable | Published contact for lawful requests; no recreated account history or automatically browsable retained legal file |
| Ordinary media expired, removed, or held | Case remains text-only with truthful evidence-availability limits when supplied | Review/contact may continue; no pose reconstruction, gallery extension, or unlawful attachment request |
| App inactive, minimized, locked, or backgrounded | Immediate neutral privacy cover over private text and sensitive account content | Stop decoration/acquisition; restore only after appropriate account/state reconciliation |

A stale transport failure can retain an authorized minimal summary; an authorization failure cannot. Offline summaries contain only the minimum own case type, reference, status, and dates needed for recovery, never free-text allegations, correspondence, protected declarations, evidence, or signed media links. They are unavailable outside the corresponding protected account session and cleared on sign-out, switch, deletion, or known revocation. Case correspondence is not made into a general offline archive.

## Keyboard, Focus, and Accessibility

Native iPhone touch, VoiceOver, Voice Control, Switch Control, hardware keyboard, and large-text paths expose the same list, decisions, dates, and actions. The row accessibility label combines type, safe context, confirmed status, and date, not a hidden report excerpt. The reference is read in full on request. Status, disclosure state, errors, and selection are semantic and not color-only.

Opening a detail moves accessibility focus to its heading and status. A requested response places its instruction next in reading order, without immediately activating the keyboard. A reply sheet initially focuses its heading for assistive orientation and makes the labeled field deliberately reachable. On dismissal, focus returns to Reply or a safe replacement if the action is no longer allowed. Back from detail restores the selected row; case removal moves focus to the unavailable notice and then the list's appropriate neighbor, not another person's detail.

Background refresh updates a status without stealing text insertion, selection, reading focus, or scroll. Announce a meaningful case change once, such as Reply received or Decision updated, not every spinner cycle, elapsed minute, event date, or interpolated animation value. A critical access revocation covers content immediately and then announces unavailability. A consequential decision is persistent content, never a timed toast.

Mac keyboard navigation uses native list arrows, selection, Tab/Shift-Tab, visible focus rings, text selection, copy/paste, and standard accessibility navigation. Return or Space performs only the focused semantic control's native action. In the multiline reply, Return inserts a line break; there is no global submit or capture handler. Pointer and keyboard focus remain independent of hover.

Escape first closes a transient menu or ordinary sheet when safe. A meaningful draft invokes the native keep-editing/discard choice rather than losing text. Escape in the main split view does not withdraw, delete, forfeit, or sign out. Cmd-W closes a case-only window normally unless it would lose a meaningful unsaved draft; Cmd-Q follows the platform's appropriate draft handling. With a real active match, the shared match coordinator explains and confirms the actual voluntary-exit consequence where the OS permits; case navigation is not allowed to bypass it. Force quit cannot be intercepted as a guaranteed confirmation and is not automatically a voluntary forfeit.

Preserve Cmd-N for New Workout, Cmd-Shift-R for Start Workout, Cmd-comma for Settings, and Cmd-Option-O for the existing database action. The case center does not repurpose them as New case, Refresh, Reply, or a second match. It introduces no app-wide key handler.

Text reflows in both panes and disclosures with the user's type and accessibility settings. Dates, status, reason, duration, instructions, recipients, and consequences cannot be clipped to satisfy minimal-copy styling. Increased contrast strengthens separators and focus treatment; Reduce Transparency gives opaque readable surfaces and privacy covers. No material blurs readable correspondence against a moving camera behind it. The app does not claim to prevent screenshots or external recording.

## Animation and Energy Behavior

Motion is tactile feedback and continuity, not a signal of guilt, a moderation reward, or evidence of human progress. There is no ambient loop on the private case surface. Native navigation and sheets retain platform timing and gesture continuity. Additional movement is local and interruptible.

| Trigger | Visible behavior and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Press or release an enabled action | Existing shared press spring, response 0.24 and damping fraction 0.88 | Release/drag-out cancels ordinary activation; Reduce Motion removes scale and keeps native emphasis |
| Select a case on Mac | Native selection changes immediately; a restrained emphasis resolves within about 140 milliseconds | Latest selection wins; no sequence of stale detail reveals; no extra selection animation with Reduce Motion |
| Open or close a detail | Native push/back on iPhone and native split selection on Mac | Input stays live; no custom matched-body zoom or forced wait; native reduced-motion behavior |
| Expand correspondence or Activity | Disclosure content grows in place with a non-bouncy approximately 280-millisecond ease-out, preserving the reader's anchor | Repeated disclosure reverses toward the current choice, without replaying a queue; Reduce Motion uses immediate layout and at most 100-millisecond opacity |
| Receive an authorized status change | Status text and symbol settle in place over approximately 180 milliseconds with stable surrounding geometry | The true status is semantically available immediately; a later update replaces the earlier one; Reduce Motion is immediate or at most 100-millisecond opacity |
| Confirm a reply receipt | The existing sending marker resolves into the received entry with a small native check emphasis and approximately 180-millisecond layout/opacity settle | Receipt and time are available immediately; no confetti, success bounce, scroll jump, or animation on history reopen |
| Insert a new case or additional page | A brief approximately 160-millisecond insertion/fade, without staggered cascades or large travel | Preserve visible anchor and focus; Reduce Motion inserts immediately |
| Refresh or send genuinely running | Native indeterminate activity only while the request is actually pending | No fake minimum wait, percentage, rotating badge wall, or transition-driven request; static Working text is sufficient when animation is reduced |
| Revoke access, change account, hide content, stop camera, or deactivate | Immediate opaque privacy replacement and immediate camera stop where relevant | No animation delay or revealing crossfade; any later safe acknowledgement may use a short fade |

At most one local focal transition runs at once. A service response never waits for decoration before enabling Back, Reply, Contact, or Return to match. Reopening a closed case or refreshing a correction does not replay a celebration, award a badge, animate Elo, or draw a punitive symbol.

Stop decorative work when the surface is offscreen, the app is inactive/backgrounded, the window is minimized, or privacy shielding applies. Low Power Mode and serious thermal constraints use static selections, immediate disclosure layout, and short opacity changes rather than optional spring or symbol emphasis. No per-frame service reads, clock-to-layout invalidation, image decoding, text measurement, or provider calls are justified by this screen. Refresh and time formatting follow actual lifecycle or user activity, not a display-frame loop. Authoritative match clocks continue independently of this quiet presentation.

## Privacy, Evidence, and Competitive Invariants

Case access is private and current-account-only on the service as well as the client. Guessing a case reference, following a notification, possessing a copied link, using a second window, or restoring a cache cannot grant access. No public allegation, report count, sanction badge, reported-player profile link, retaliatory contact, or shareable complaint card is introduced.

A case never includes a participant-facing review-evidence gallery. A lawful hold grants only authorized review access, not renewed opponent viewing. Ordinary pose media expires twenty-four hours after finalization. The proposed benign-report evidence limit is at most thirty days from the originating report's receipt, without renewal by duplicate, correspondence, appeal, or staff delay. Late reports do not recreate expired images. Suspected unlawful or exploitative material uses the restricted specialist path and is never requested as a support attachment.

Ordinary personal case metadata and correspondence follow F29-E's purpose-limited proposed maximum of ninety days after closure. Necessary minimal enforcement data may follow the active restriction and the separately bounded lawful period afterward. These are not promises that all legal records disappear instantly or that every old case is kept. Deletion and justified preservation remain distinct, scoped, and honestly disclosed. The case center must not become an indefinite archive by retaining copies locally.

Private text, correspondence, case screenshots, evidence, access links, and account declarations are excluded from public identity, notifications, result exports, judge context, ordinary analytics, image-bearing replay, and routine diagnostic logs. A copied case reference is a deliberate own-reference action, not an export of someone else's personal information.

Submitting or withdrawing a report, blocking, appealing, closing a notice, or opening Cases never changes Elo, grants a win, erases a valid loss, renews media access, restores an allowance, or changes a judge version. Only authorized correction and restriction decisions change their respective real records. The ordinary result remains authoritative during review, and eligible forfeit/no-contest precedence remains the parent contract's responsibility.

## Dependencies and Product Conflicts

[The F29-A page flow](../DOCKS.md) supplies route restoration, the Safety presentation, active-match timer and exit handling, and the established contextual report/appeal entry. [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) supplies private receipt and review policy, own decision notices, safe text, withdrawals, appeals, and actual human operation. [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) supplies protected account access, privacy shielding, retention/deletion, and the real published contact channel. [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) supplies any authoritative competitive correction. [F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) constrains explanations and forbids using case text or identity as judging context.

Implementation requires human-reviewed shared account, private-case, request-reconciliation, authorized-action, retention, contact, and native-routing foundations. A view cannot ship independently with sample cases, guessed permission, a fake reply service, a claimed human reviewer, or a support button that does nothing. Restricted-account authorization and the published fallback contact must exist as real operational contracts, not be inferred from a general sign-in endpoint.

Both native platforms and vertically ordered players are required. Older F29-A prose permitting a wide two-column player comparison or treating desktop as a secondary adaptation is superseded for this surface by the user's newer direction. A native two-column case list/detail is not a two-column matchup. This child does not approve every older proposed policy number, change the competition, or establish human acceptance of shared foundations.

## Files and References

Product context and future work:

- This document owns F29-A-t's product decisions and contains no implementation completion record.
- [Future case-center implementation brief](../../../../prompts/F29-physique-duels/F29-A-t-phase-1-case-center.md) owns the separate prospective engineering handoff.
- Prospective TimeMaster/Views/Physique/PhysiqueCaseCenterView.swift owns the private list and native selection host. The separately owned F29-A-u Case detail and F29-A-v Review composer are consumed destinations, not files this slice creates or rewrites.
- The actual shared TimeMaster/Services/Physique/ and TimeMaster/Models/PhysiqueDuelModels.swift foundations own authenticated case facts and request authority when implemented. Existing safety routes should be reused rather than made into competing forms.
- [CYCLES.md](../../../../CYCLES.md) owns implementation planning and human-review tracking; this document records no passed checks or approval.

Existing source conventions:

- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), lines 1–81 and 208–228: existing near-black palette, shared action and back controls.
- [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), lines 1–38: scalable Inter faces, shared spacing, touch convention, and readable column.
- [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift), lines 20–80: supported material fallbacks, Reduce Transparency, and the shared press spring.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift), lines 15–108 and 148–188: nearby action and earned-Elo visual language; its type clamps and exercise crests are not case-center behavior.
- [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift), lines 25–151: exercise HUD context only, not permission for provisional physique scores or a case timer.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift), lines 8–19, and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift), lines 6–37: existing native window minimum, normal title bar, and preserved commands.
- [LocalProfileModels.swift](../../../../TimeMaster/Models/LocalProfileModels.swift), lines 23–27 and 99–109: editable cosmetic badge previews are not competitive identity, verification, or case clearance.
- [Project configuration](../../../../TimeMaster.xcodeproj/project.pbxproj): preserve iPhone iOS 16 and native macOS 14 compatibility without a target raise or dependence on 26-only APIs.

Design references:

- [Supplied battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png): direct hierarchy and visible action placement are patterns only. Its side-by-side players, faces, footage, web pills, text, and visual assets are not copied or licensed by this specification.
- [Apple HIG: Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), Best practices, Content, and Platform considerations: succinct textual rows, clear detail navigation, appropriate selection feedback, and platform-appropriate list composition.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices: resizable windows, comfortable density, native high-precision input, and keyboard/menu integration.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback: purposeful brief optional feedback that does not block interaction.
- [Dimillian SwiftUI UI Patterns](https://github.com/dimillian/Skills/blob/main/swiftui-ui-patterns/SKILL.md), and its [List](https://github.com/dimillian/Skills/blob/main/swiftui-ui-patterns/references/list.md) and [Split views](https://github.com/dimillian/Skills/blob/main/swiftui-ui-patterns/references/split-views.md) references: native stable list identity and standard selection-driven split navigation are the appropriate patterns here, without a custom independent secondary-column framework.
