# F29-A-d — Rules and Rubric

## Purpose and Decision Status

Rules is the native, read-only explanation of a Physique Duel: what is compared, what is excluded, what the four scores mean, what people may wear, who may receive stills, and what happens when a match ends without a scored comparison. It is available before participation, from preparation, and from an existing match or result without requiring someone to expose an image.

This document proposes one concrete composition for native iPhone and native macOS. It is product context for future implementation, not an implemented surface, an accepted prototype, an approved fairness standard, or permission to enable ranked uploads. The forty/thirty/twenty/ten weights, three-point draw boundary, common-region evidence policy, timing and retention defaults retain their proposed status under the [F29 parent](../../DOCKS.md). Real participation requires human-approved policy and the actual shared services; the approved visual direction does not approve every numerical proposal.

The [page and match-flow parent](../DOCKS.md) owns routing and the battle stage. [Judging](../../F29-B-ai-judging-and-metrics/DOCKS.md), [competition](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [safety](../../F29-D-safety-and-reporting/DOCKS.md), and [privacy](../../F29-E-privacy-and-service-operation/DOCKS.md) remain the authorities for their meaning. Rules explains those policies; it does not create a second judge, consent system, rating calculation, case center, or media viewer.

## Chosen Composition and Tradeoffs

Use a compact sports rulebook, not a carousel, a dashboard of charts, or a wall of closed accordions. The first meaningful content is a four-row rubric roster. Each row has a recognizable symbol, a full category name, a plainly labeled weight, and one short explanation. The core rules continue below in a deliberate reading order. Scrolling is allowed; required meaning is never hidden behind a chevron, tooltip, hover state, or an external policy link.

The default reading order is:

1. Rules heading, applicable version and status, then “Three poses. One rubric.”
2. “Three stills · 90 seconds total · Up to 2 retakes per pose.” A nearby sentence names front double-biceps, side physique, and rear double-biceps. Pose guide opens the existing local guide.
3. The four rubric rows, followed immediately by the always-visible common-region and subjective-score limitations.
4. Attire and eligibility.
5. Draw, no contest, and forfeit, including their distinct rating and allowance effects.
6. Privacy and sharing, with recipients, image access, retention, copying risk, and withdrawal consequences.
7. Named routes to the existing Privacy and sharing and Safety areas, followed by the version context and any necessary product limitation.

“Three poses. One rubric.” is orientation, not a second display-sized headline. The version is readable metadata, not a competitive badge or a verification seal. There are no sample player scores, illustrative Elo awards, confidence percentages, fake opponents, or before-and-after body photographs.

Four equal-height tiles were rejected because the longest category would either truncate or force oversized empty tiles. A pie chart was rejected because the fixed weights are not match progress or earned points. The roster uses natural row heights, visible numeric weights and shared alignment; it is fast to scan without implying measurement precision. Detailed examples and calibration anchors are optional inline disclosures. The cost is a longer reader, chosen over concealing safety, privacy, or competitive consequences to satisfy a short-copy aesthetic.

## Visual Language and Hierarchy

Use the existing near-black background, dark surfaces, white primary text, readable secondary text, Inter Black headings and Inter Regular body type. Orange identifies navigation, active disclosure and the existing primary-action language. It does not mean a better body, an approved declaration, or a winning category. Existing shared spacing, readable-column limits, surfaces and press feedback apply; this view does not establish another global theme.

The rubric is one grouped surface with four separated rows, not four competing hero cards. A leading symbol has a stable alignment, the category name gets the main reading width, and the trailing value says “40% weight”, “30% weight”, “20% weight”, or “10% weight”. At large text the weight moves below the category name rather than making either illegible. The summary remains visible below the heading line. A labeled disclosure such as “Muscularity details” opens the examples associated with that row. The full category name remains visible even if a shorter word is used in that disclosure label.

Use an available strength-training figure for Visible muscularity, a supported contrast/separation symbol for Definition, opposing horizontal arrows for Symmetry and balance, and a standing figure for Pose presentation. Symbols are mnemonic support, never anatomical evidence or substitutes for text. Use a shirt for Attire, an equal sign for Draw, a neutral minus-in-circle for No contest, a leaving-door symbol for Forfeit, and a shield or lock for Privacy. Avoid a reporting flag as the sole forfeit symbol, because reporting and forfeiting are different actions.

Required text is body text, not tiny footnotes. It wraps without a line-count cap. Weight percentages use stable digit alignment and are announced as portions of the total, not as participant scores. Quiet section separators and one short orange heading keyline provide the sports hierarchy. Do not add body scanning, a rotating trophy, a pulsing badge wall, glass over paragraphs, or a looping rules animation. Materials may be used by existing native chrome; the reading surface remains opaque and readable when Reduce Transparency is enabled.

## The Four Fixed Categories

The category order and names do not change with attire, player identity, disability, exposed anatomy, device, payment, or the available evidence. The following weights are the proposed single-rubric weights. An approved version must show its actual frozen policy; the client cannot quietly publish different weights.

| Category and weight | Always-visible explanation | Deliberate additional detail |
| --- | --- | --- |
| Visible muscularity — 40% weight | “Visible muscular contours across the shared regions; not actual muscle mass.” | Shoulder, upper-arm, upper-back, thigh and calf contours across the three poses, considered relative to the visible frame. A genuine contour through permitted opaque clothing is not a view of hidden muscle. Pixel size, height, body weight, strength, chest or abdominal appearance, sex-based ideals and training claims do not count. |
| Definition — 30% weight | “Supported muscle separation in the upper arms and calves; not body-fat percentage.” | Directly usable upper-arm and calf evidence is required. Fabric seams, folds, lighting-created edges, sweat, oil, tanning, vascularity as a goal and dehydration do not earn points. Additional exposed chest, abdomen or back detail is not extra definition evidence. |
| Symmetry and balance — 20% weight | “Observed left-right and upper-lower muscular balance across the shared evidence.” | The front and rear evidence must support the relevant bilateral contours; one side pose alone is not proof of symmetry. There is no preferred sex-specific shape, waist-to-hip ideal, skeletal proportion, breast or facial symmetry score, or diagnosis of a physical difference. |
| Pose presentation — 10% weight | “Safe, recognizable poses that clearly present the required regions.” | Clear alignment and consistent presentation above the evidence minimum count. Theatricality, seductiveness, facial expression, clothing price, unsafe strain, pose duration and professional camera production do not. An invalid pose is not repaired with presentation points. |

Immediately below the roster, always show “Scores are subjective points from 0 to 100, not measurements of health, strength, attractiveness or human worth.” Explain that the weighted total is also out of 100 and is shown to one decimal place in a judged result. A weight is a share of that total, not a model confidence percentage or a percentile of people.

Each category's optional detail can include the scoring anchors from F29-B, with their five named bands: 0–24, 25–49, 50–74, 75–89 and 90–100 points. The bands are proposed calibration references, not population norms or ideal-body targets. Do not replace those category-specific descriptions with a generic “bad to perfect” scale. Zero can describe a valid low observation when evidence is adequate; an unseen region has no score. One hundred is the top of this rubric, not a biologically perfect person. Both participants may have high, low, or identical scores.

The reader never requests a judgement, uploads an example body, changes a weight, or previews the user's likely score. There are no sliders, selectable judging models or paid ways to alter the rubric.

## Common Regions and Evidence Limits

“Same regions, both players” is an always-open section, directly after the four categories. Its concise first statement is: “Compare shoulders, upper arms, upper-back contours and legs. Chest and abdominal appearance or definition do not count for either player.”

The same section visibly explains:

- Definition uses the required directly visible upper-arm and calf regions; an upper-back contour is not permission to infer surface definition under a top.
- More exposed skin earns no bonus. Permitted clothing earns no deduction. Breast, nipple and areola appearance, groin, genital and buttock anatomy, facial attractiveness, skin color, tattoos and clothing cost are not scoring criteria.
- An obscured required region is not imagined, scored as zero, replaced by a different region, or removed from one player's category weights. An inadequate fixed-rubric comparison ends as insufficient-evidence no contest.
- Adequate evidence showing little separation is different from evidence that cannot show separation. Capture quality is an eligibility check, not a fifth category or a photography bonus.
- Safe pose variations are acceptable only when they preserve the required comparable evidence. A mobility limitation or physical difference is not itself a penalty, a diagnosis or proof of a poor physique. When equivalent evidence is not possible, the service explains insufficiency privately rather than manufacturing a comparative loss.

A short limitation remains visible: “This proposed coverage-neutral rule still needs human calibration; it does not establish equal judging quality across clothing, bodies, skin tones or cameras.” At launch, replace proposal language only after the policy owner has approved the actual reviewed policy; do not promise objective fairness or guaranteed accuracy.

The optional category details may explain ordinary framing, perspective and lighting effects, but must not recommend exposing protected regions, changing body weight, dehydrating, ignoring pain or straining to improve a score. A rules illustration, if later needed, is neutral and appropriately licensed. The supplied reference's people, footage and badges are not app assets.

## Attire and Adult Eligibility

The Attire section is always open and contains the complete practical rule, not an unexplained mature-content badge.

“Adults only: 18 or older, and any stricter applicable local requirement. A privately declared adult man may pose shirtless in a nonsexual fitness context. Other participants wear an opaque athletic top or sports bra. Everyone covers the groin and buttocks with opaque sports clothing.”

Then show “More skin is not more points.” The surrounding text explains that a sports bra and an ordinary permitted male torso are not automatically violations, while sheer clothing, prohibited exposure, sexualized presentation or a wardrobe malfunction do not become permitted because an attire option was selected. Rear poses do not relax coverage. The guide does not ask someone to reveal a protected region or tighten clothing over intimate anatomy.

Adult eligibility and the adult-man attire exception are private declarations owned by the eligibility flow, not public country or achievement badges. The reader does not collect declarations and does not infer age, sex, gender, identity or medical facts from images. No government-ID or face-verification step is invented here.

Capture must show only the consenting participant. A second person invalidates it even if a face can be masked. A helper may position the device outside the frame. Library photographs, recordings, another person's body, synthetic replacements, body reshaping and appearance filters are not rated evidence. The app's required face obscuring is permitted privacy protection, not cheating.

If permitted clothing obscures required evidence, the explanation offers only a safe allowed adjustment or recapture while the original capture time and retake limit permit. It does not demand undressing or award an automatic clothing loss. A rejection can be questioned through the existing safety-review route without sending an exposed original or proving gender with a body image. Rules does not create that review form or promise reversal.

## Outcomes, Leaving and Recovery Rules

The Outcomes section uses distinct, vertically ordered rows. All core meanings are visible without opening an example. The values below remain proposed rules until approved.

| Visible outcome | Required explanation | Rating, evidence and allowance meaning |
| --- | --- | --- |
| Win or loss | “A valid total gap of 3.0 points or more decides the winner.” | Both complete accepted sets support all four categories. Physique Elo follows the service-owned outcome, not the amount of the score gap. No body score is a rating. |
| Draw | “A valid total gap below 3.0 points is a draw.” | A 2.9-point gap is a draw; exactly 3.0 is not. A draw is rated and may change Elo between unequal-rated opponents. It is not a refund, uncertain judgement or promise of no rating change. |
| No contest | “No valid rated comparison. No Elo change.” | Insufficient evidence, a safety or integrity abort, an invalid or unsafe judgement, unavailable service or a missed judging deadline cannot become a guessed win, loss or draw. The consumed Physique slot is restored once when the service confirms the restoration. No-contests do not advance placement or change the competitive streak. |
| Forfeit | “After Go, explicitly confirming Forfeit and leave can record a loss.” | It is a rated forfeit only if the service establishes that the started match is otherwise eligible. The opponent receives the eligible win; no physique scores or claim of bodily superiority are invented. The slot remains spent. A safety-aborted, independently invalid or unavailable-service match has no-contest precedence. |

Above the forfeit row, show the pre-start distinction: “Before Go, Cancel has no Elo cost and releases the reservation.” Go is the service's start, not a local animation. If Cancel reaches the service after Go, the person is told the match has started and offered return or the explicit forfeit confirmation; a late cancel is never silently converted into agreement to a rated loss.

Opening or closing Rules is not Cancel, Forfeit, consent withdrawal, a new queue entry, an allowance charge or an appeal. It never finalizes a match. The reader has no direct Forfeit button; its match host retains the real state-aware exit control.

Always state: “Reporting or blocking is not a verdict.” Before Go, blocking cancels the pair with no Elo change. After Go, it shields relevant media and excludes future pairing; it does not itself leave, settle, reverse a result or manufacture no-contest precedence. A report does not guarantee a win, a refund or a finding against the other participant. Protection and service acknowledgement remain distinct when offline.

A concise timing line explains the real bounds: search lasts at most 90 seconds, the shared start countdown is 3 seconds, capture has one 90-second period, and reconnect grace is at most 20 seconds without extending any original deadline. Up to two retakes per pose remain inside that capture period. A loss of camera or involuntary interruption stops acquisition immediately; if valid participation cannot resume, the service applies the no-contest rule rather than a physique loss for absence.

Judging has no guaranteed five-second countdown. Five seconds is an unmeasured experience target; the proposed hard judgement deadline is 30 seconds after both final pose sets are received. If complete accepted sets already exist, judging can finish while the client is away. Reopening retrieves the same authoritative state. A late response cannot revive a finalized no contest, and reconnecting cannot add another rating event or allowance charge.

Request scoring review opens the existing contextual review route when Rules was opened from a saved result. The current confirmed result remains effective until an authorized correction exists. Review is not a new-model reroll; subjective disagreement or image expiry does not automatically invalidate a result. From a lobby, the matching row says “Scoring review is available in match details” rather than offering a button with no target. Exact Elo policy and record detail remain in their existing competition context, not an additional Rules-owned screen.

## Privacy and Sharing: Required Visible Meaning

The Privacy section is open by default and cannot be collapsed to meet the minimal-text direction. Full details remain in the real Privacy and sharing destination, but the reader itself must expose the following decision-critical meaning.

### Who receives what

The current rules must identify the real operator, the approved judging processor, any moderation processors, their purposes and the applicable processing-region arrangement in readable text. “AI” alone is not a recipient name. These facts come from the applicable approved policy, not the UI-worker model assignment, a guessed OpenAI configuration, the user's AI Coach preferences, or a developer's personal key.

The visible summary explains that selected stills and any necessary protected candidates can go to the authorized service and named processors after separate consent. Every transmitted image is locally face-obscured first, and the participant sees the exact treated capture. Failed redaction stops that transfer; an unmasked original is never a fallback. Masking does not guarantee anonymity because bodies, tattoos, clothing, backgrounds and the paired public identity may remain recognizable.

The live preview stays local. There is no live opponent video, microphone or chat. Before finalization the opponent sees only an authorized public avatar or silhouette and actual stage/count information, never early stills or rejected retakes. Handles, optional self-declared country or region, badges, tiers, Elo, clothing declarations and UI chrome are not judge inputs. Clean redacted evidence is transmitted, not a screenshot containing the battle interface. A local profile photo is not automatically a permitted public avatar.

### Opponent viewing

Only a valid AI-judged win, loss or draw can offer intentional View poses, after moderation, required prior consent and a fresh check of each owner's current access permission. There is no gallery for forfeits or no-contests, even if candidates exist. A result or notification never automatically opens an opponent image. Hide and Report remain available without enlargement through their existing owners.

“Approved stills are ordinarily available for 24 hours after finalization. Someone who can see an image may copy or record it.” Do not claim screenshot prevention or guaranteed anonymity. Expired, deleted, withdrawn, blocked, reported and safety-removed images stay unavailable under their actual access reason; reading Rules cannot renew or restore them.

### Retention and withdrawal

The concise retention explanation distinguishes three things: app-controlled ordinary media expires no later than 24 hours after finalization; a received report or dispute may preserve only necessary lawful evidence for up to 30 days from its original receipt; separately disclosed processor logs, application state, caches and legal or urgent-safety exceptions may have different lifetimes. Duplicates and appeals do not restart a benign report hold, and a report hold is never continued opponent-gallery permission. Unreceived drafts do not preserve media. Unlawful or suspected exploitative content follows restricted legal-safety handling, not an ordinary report attachment.

Actual processor retention terms must be stated for the selected service. If ordinary provider logs may last up to 30 days, or separately stored responses and processing caches have another period, the screen says so accurately instead of claiming that everything disappears everywhere in 24 hours. It does not claim Zero Data Retention, no storage, no possible authorized human review or a processing region that the operator has not actually secured. Proposed launch use does not opt body images into model training, research or marketing; any factual statement about training must match the real processor arrangement.

Rules acceptance, adult declaration, camera permission, hosted-AI processing consent and paired-opponent still access are separate decisions. Reading, scrolling to the end or closing this view accepts none of them. Both sharing choices are separately affirmative and not preselected in their owning flow. Declining prevents this rated mode, not unrelated Tmax use.

Before Go, withdrawal of required sharing cancels preparation or pairing without Elo loss and releases the reservation. After Go, processing withdrawal stops new capture and transfers immediately; already accepted processing may not be retractable. Intentional departure still follows the eligible explicit-forfeit versus no-contest precedence rules. Withdrawing only counterpart-image access after Go removes future viewing immediately but is not itself a forfeit, a cancellation or a rating reversal. After finalization, removing images does not reroll an outcome or erase earned Elo. No action can recall a copy already made outside the app. Account deletion and media-removal requests remain directly reachable in the real privacy area, not replaced with Sign out or Remove page.

If recipient names, applicable retention, policy authenticity or current sharing terms cannot be established, show “Sharing information unavailable” with working Retry and Close. A known rules version may remain readable with that limitation. Do not publish placeholder recipients, mark cached data current without confirmation, or allow new pairing/upload acceptance through this view.

## iPhone Composition and Navigation

Native iPhone uses the existing navigation hierarchy and safe-area clearances. From the lobby or a full preparation page, Rules is a pushed reader with a standard Back control. If the caller is already a consent sheet, push Rules inside that sheet's navigation rather than presenting a second sheet. Reading returns to the exact caller, pending choices and scroll position without accepting anything. A root Rules sheet, where required by the existing host, uses the normal leading Close control, a full-height reading presentation and swipe dismissal; it has no misleading Done or I agree action.

A compact labeled Sections menu in the navigation toolbar jumps to Rubric, Attire, Outcomes or Privacy. It is a scroll aid, not four mutually exclusive tabs: all required sections remain in the same document. The screen opens at the requested section when entered contextually, otherwise at the heading. The category summaries, numbers and instructions wrap; only supplementary examples start collapsed. No horizontal text paging, mandatory gesture, fixed-height paragraph box or Dynamic Type clamp is allowed. Primary and safety interactions follow the existing 44-point minimum hit-area convention.

During an active match, Rules must not cover the timer and safe exit with a modal reader. The match host reveals the same read-only content inline below its two player panels and moves to the requested rules section. The real timer stays the top reachable stage anchor and the host's Exit and Return to match controls remain reachable through its safe action area. “Clock continues · Camera stopped” is visible at entry. The host immediately stops and shields local acquisition when entering deliberate reading; any accepted submission already in progress keeps only its separately authorized service state. Reading does not reset deadlines, cancel accepted evidence or invoke withdrawal.

Returning scrolls to the existing match stage, restores focus to the invoking control, and requires the host's explicit Resume camera action if live acquisition is still relevant and permitted. It does not silently take a still or restart a finished match. Before Go, opening Rules invalidates local readiness when camera participation is no longer valid; the service resolves a countdown race. If Go has already occurred, display the started state and original deadline instead of promising a pre-start cancellation.

Whenever the battle composition is present, retain its exact hierarchy: real timer at the top, complete owner-grouped public identity and badge rails below, then two LARGE vertically stacked player panels with You above Opponent. Every public badge wraps visibly; there is no three-badge cap, hidden +N, clipped rail, ticker or hover-only meaning. Optional manually chosen country or region uses the shared identity rules and is never a judge signal. No badge, label or Rules overlay covers faces, limbs or evidence framing. Panels remain aspect-fit and comparably framed. Short phones and large text scroll the central stage instead of shrinking participants into thumbnails. Rules alone does not invent a battle timer, player image or badge rail as decoration.

## Native macOS Composition and Window Behavior

This is a native macOS 14-and-later surface, not Catalyst, a web page or a widened phone mock. Preserve the app's normal title bar and existing 800 by 600 minimum window; do not raise that minimum to make Rules fit.

From a lobby, a window-attached native sheet presents the same reader at a comfortable reading width within the parent window. The sheet has a Rules title, a native Close action in its footer and a labeled Sections control above the document. Its content scrolls vertically with normal trackpad, mouse-wheel and scrollbar behavior. Text is selectable for reading and copying policy language; category rows are controls only at their disclosure affordance, so selection does not toggle them. The footer and safe dismissal remain reachable in a short window. The sheet affects its own parent window, not every app window. From another preparation sheet, navigate within the existing presentation instead of layering sheets.

In a laptop-sized or large window the leading labels, trailing weights, natural line lengths and native control density keep it a compact rulebook rather than stretching sentences edge to edge. Full-screen and external-display use increase available context, not font scale or category weights. Moving or live-resizing the window preserves the section anchor, expanded details and reading position. At larger accessibility text sizes, the weight moves beneath its category and ordinary vertical scrolling grows; body text never compresses to preserve a grid.

During an active match, a nonmodal trailing inspector can hold the same reader only when the remaining central column supports the large, legible vertical player stage. Otherwise the Rules content becomes the same inline section below the players, including at the 800 by 600 minimum when necessary. The inspector has its own Close Rules action and independent document scrolling; it is not a second account window or a modal capture blocker. Switching between inspector and inline placement is caused by available measured content space, preserves the selected section and detail state, and does not animate the players sideways. Timer and safe actions remain usable while the central stage scrolls.

The battle remains timer, complete badge/identity rails, You panel, Opponent panel at every width, including large and full-screen displays. A wider display may give Rules an inspector, never turn the participants into a side-by-side matchup. Player evidence remains aspect-fit and equally treated, without cropping, stretching or badges over a body. Before finalization the opponent panel still contains only the permitted avatar or silhouette and real progress.

Rules never requests or owns camera permission. Camera/TCC denial, an unavailable built-in camera, and external or Continuity Camera disconnection cannot prevent the reader opening and cannot trigger another system permission prompt. Return to match exposes the host's actual denied, disconnected, reconnecting or expired state with the relevant Open Settings, Retry or safe exit action. A file picker, prerecorded clip or fake preview is never rated recovery. The original deadline and at-most-20-second reconnect grace remain authoritative.

Opening the reader or inspector stops and shields any local acquisition immediately. Inactive, minimized, hidden, backgrounded or closed capture windows do not acquire behind Rules. On return, restore the same service-owned match and require explicit permitted camera resumption rather than automatically streaming again. Rules stays usable as non-sensitive text; private match identity and media in the host are shielded as required. One account retains one active match and one camera owner across windows and devices. A secondary Rules window or reader may show policy but must not start, ready, charge or acquire another session.

Escape closes an active section menu first, otherwise the Rules sheet or inspector, or returns from inline reading. It never forfeits. Command-W closes only the scoped reader presentation where that is the platform's normal close action; closing an owning active-match window invokes the host's actual state-aware consequence confirmation where the platform permits. Quit uses the same active-match policy. Force quit cannot be prevented or treated as a confirmed voluntary forfeit. Dismissing informational Rules alone never needs a destructive confirmation.

## States, Actions and Recovery

| State or event | Visible information and available action | Consequence and recovery |
| --- | --- | --- |
| First ordinary read | Current approved Rules heading, applicable version, full core sections, Sections, Back or Close | No sign-in, camera activation, upload, match start or acceptance merely to read safe rules. |
| Pre-approval preview | “Proposed rules · Rated participation unavailable”, the proposed values and limitation text | No acceptance or upload path pretends these proposals are an approved live policy. |
| Contextual section entry | Requested section heading with the same version metadata accessible above | Jump within the complete reader; returning restores the caller and does not erase its choices. |
| Loading current policy | “Loading current rules”, real activity feedback, Close; an authentic cached version may remain labeled | No guessed version, placeholder weight or empty successful reader. |
| Offline with an authentic cached version | “Saved rules · Current version not confirmed”, saved version/date, readable sections, Retry and Close | Cache is informational. New acceptance and participation require confirmation by the shared service. |
| Offline with no usable version | “Rules unavailable offline”, Retry and Close | No sample policy, fake recipient, spinner with no escape or permissive default. |
| Partial or inconsistent policy | Specific unavailability notice beside the affected section; other known rules remain readable | Missing required terms or a mismatch between category policy and version prevents new participation; Retry refreshes the same intended context. |
| Refresh fails while reading | Existing version and reading position retained; “Could not refresh rules” and Retry | Do not replace readable content with an empty page or imply the old version was reconfirmed. |
| Required rules updated before Go | “Rules updated” and a route to Review current rules | Preserve non-sensitive draft choices; do not mark the new version accepted or silently clear a consent choice into apparent approval. The owning entry flow re-establishes eligibility. |
| Policy changes during a started match | “Rules for this match” with the version frozen for that match | Do not swap weights or consent recipients mid-match. Changed sharing conditions cannot authorize new transfers; F29-E governs any required stop. Future rules are for a future match. |
| Historical result | Match date, “Rules used for this match” and its frozen version | Do not substitute latest weights or imply an expired gallery reopened. Current-policy navigation is separately labeled and does not reroll the result. |
| Historical policy unavailable | The known result/version reference and “Rules details unavailable”, Retry and Close | No reconstruction from a different version or fabricated explanation. |
| Category details opened or closed | Full summary and weight remain; that row's supported examples expand inline | Independent rows may remain open. Collapse only the supplementary detail, not exclusions, consent meaning or outcome consequences. |
| Deep link to a missing section | The applicable reader heading and a concise unavailable-section notice | Keep all normal rules available; no blank screen or arbitrary new destination. |
| Opening from capture or a Ready state | “Clock continues · Camera stopped” when started; truthful pre-start status otherwise | Stop acquisition immediately; the host invalidates readiness when necessary and resolves Go races from real service state. |
| Capture expires or a result finalizes while reading | A quiet, concise actual-stage notice plus Return to match | Do not steal reading focus or auto-open media. Fetch the real result; never extend time, restart or locally settle a match. |
| Camera/TCC denial or device disconnect | Rules remains readable; Return to match names the real recovery destination | Rules does not retry camera permission, switch devices, fake a feed or reset the clock. |
| Declined consent or age-ineligible | Safe rules remain readable with no body imagery; Back or Close works | No pressure countdown or forced photograph; unrelated app use remains available. |
| Privacy recipient or retention facts unavailable | “Sharing information unavailable”, actual known terms, Retry and Close | No acceptance shortcut, unapproved processor substitution or body-image transfer. |
| Link to privacy, safety or pose guidance | A named real destination and preserved Rules return context | Dismiss or navigate within the current host before another modal; never stack sheets or leave hidden acquisition running. |
| Targeted review route no longer permitted | An accurate eligibility/unavailability message with return and permitted support route | Do not submit on the old account, invent a case, or promise missing-media restoration. |
| Sign-out, account switch or deletion | Public current rules may remain; private match context and review targets clear immediately | Another account never inherits history, consent, media access, match identity or drafts. |
| Return after background, minimization or relaunch | Policy or saved match version restored with actual freshness and stage | No camera auto-resume, animation replay backlog, deadline reset, duplicate charge or restored removed media. |

## Focus, Keyboard and Accessibility

The reading order is heading and version, orientation, rubric rows in fixed order, common-region limits, attire, outcomes, privacy and the named destination links. Section headings are navigable VoiceOver headings. Symbols with adjacent equivalent text are decorative to avoid double announcements. Each weight is announced with its category and “percent of total”; category points and weight percentages are never conflated.

The disclosure control has a visible descriptive label and an expanded/collapsed state. Opening does not steal focus from its control; the newly revealed text is next in reading order. If a detail is collapsed while focus is inside it, focus returns to that category's disclosure. A section jump moves reading focus to the requested heading and reveals it clear of any pinned host chrome. If the selected item disappears after a refresh, focus lands on the applicable version notice or reader heading, not the root of an unrelated page.

On iPhone, Back, Close, Sections and destination links work with touch, VoiceOver, Voice Control, Switch Control and an external keyboard. Swipe dismissal of informational Rules is safe because it has no unsaved declaration. System permission and destructive match-exit confirmations retain their own native semantics; a reader close never bypasses them.

On Mac, Tab and Shift-Tab traverse native semantic controls in document order according to keyboard-navigation settings. Return and Space activate only the focused semantic control; neither is globally captured for Ready, Capture, Close or acceptance while selecting or entering text elsewhere. Arrow keys follow native menu and disclosure behavior; trackpad, scrollbars, Page Up, Page Down, Home and End retain conventional document scrolling when appropriate to focus. Pointer hover may emphasize a disclosure or provide redundant help, never reveal essential terms. Native focus rings remain visible against dark surfaces.

Preserve Command-N, Command-Shift-R, Command-comma and Command-Option-O and the normal text-editing commands. Rules adds no conflicting global shortcut. Escape is scoped as described above. Closing returns focus to Rules at the caller, or to the updated match heading if that caller no longer exists.

All text can grow without clipping, truncating category names, losing units or hiding controls beneath toolbars. Use strong enough contrast for required meaning rather than blindly applying a faint secondary style. Increased Contrast and Differentiate Without Color preserve labels, symbols and selection. Reduce Transparency gives opaque reading surfaces. No information depends solely on an orange line, a gesture, animation, sound or haptic.

Rules announces a material version change or a real critical stage transition once, without repeating every match tick. It does not read animated intermediate numbers or continually announce the reader's section while someone scrolls.

## Motion, Interruption and Energy Behavior

Rules has tactile, event-driven movement rather than an ambient loop. Native presentation and dismissal use the platform transition, not a custom imitation of a sheet. The following product timings govern only the local custom feedback; they are not measured performance claims or requirements to override system transitions.

| Trigger | Movement and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Ordinary reader entry | The short heading keyline reveals horizontally once over 260 milliseconds with gentle ease-out. Text and controls are already present and actionable. | Do not animate category weight lengths or stage a delayed sequence of sections. Reduce Motion, low power and elevated thermal state show the line in its final static form. |
| Press on an enabled control | Existing shared press response, spring response 0.24 seconds and damping fraction 0.88 | Release or cancellation restores the current state without another action. Reduce Motion uses the shared non-scale response. |
| Category detail expanded or collapsed | The disclosure triangle rotates over 160 milliseconds; the supplementary area opens or closes over 220 milliseconds with ease-out and a restrained 140-millisecond opacity change. | A second action reverses from the visible position, not from a queued animation. Keep the row's summary/weight stable; preserve the reading anchor. Reduce Motion uses immediate layout and at most 100 milliseconds of opacity. |
| Sections selection | Deliberate document scroll to the requested heading, about 280 milliseconds with ease-in-out; semantic target focus remains correct | Touch, wheel, trackpad or another jump cancels the current travel. Reduce Motion jumps without animated scroll. No automatic travel during passive scrolling. |
| Real policy or availability notice changes | Text and icon replace over 180 milliseconds without rearranging the whole document | Latest confirmed status supersedes the old state; do not queue stale notices. Critical eligibility and privacy changes take effect immediately. Reduced Motion permits at most 100 milliseconds of opacity. |
| Inspector changes to inline reading or back during resize | Preserve reading state and reflow directly; optional local opacity no longer than 140 milliseconds after geometry settles | Do not animate the body panels across the window or fight live resize. Reduce Motion uses immediate placement. |
| Return from reading to the active stage | Existing stage-continuity transition, at most 300 milliseconds, restoring the actual current stage | It does not wait before stopping or resuming privacy protection. No camera acquisition begins merely because the animation finishes. Reduce Motion returns immediately or with short opacity. |

No auto-expansion, confetti, score-counting animation, ambient shimmer, pulsing shield or timer simulation is added to Rules. When a real battle timer remains in the host it keeps stable geometry and the host's approximately 180-millisecond real digit update; Rules does not own another timer. The timer is not announced every second.

Pause decorative work when the reader is offscreen, the app is inactive/backgrounded, or a Mac window is hidden or minimized. Low Power Mode and thermal pressure remove the keyline reveal and unnecessary travel; reading and real service status remain complete. There is no continuous animation task, polling solely for decoration, per-frame network/provider work, image decoding, camera rebuild or global layout invalidation. Safety shielding and camera stopping are immediate and independent of animation completion. Authoritative clocks and already authorized service work do not pause because the reader has stopped drawing.

## Dependencies and Boundaries

The reviewed shared navigation/account foundation, authentic current and per-match policy/version information, real service-owned lifecycle, and existing safety/privacy destinations are prerequisites for the connected implementation. They are not presumed accepted because this child has a detailed visual description. F29-B owns the fixed rubric, evidence adequacy, precision and quality bar. F29-C owns exactly-once outcomes, Elo, placement, allowance and corrections. F29-D owns eligibility, permitted attire, hiding, reporting, blocking and human review. F29-E owns actual processors, region and retention facts, consent changes, camera privacy, deletion and access revocation. F29-F owns trusted public identity, country and all battle badges; Rules must not recreate them from editable local profile previews.

This child owns only the Rules reader, its category-detail rows, section navigation, applicable-version presentation and real navigation back to those owners. Consent choices, alerts, system permissions, camera management, results and case forms remain their existing owners. Public rules can be readable while sign-in or camera is unavailable; that is not a private rated fallback.

The latest user-approved vertical battle and tactile-motion direction overrides earlier F29-A wording that allowed a balanced two-column matchup or only static fades. This child does not silently revise the still-proposed numerical policy, loosen privacy to simplify layout, or claim that adult consent removes the residual App Store objectification risk. The main feature owner integrates shared documentation changes.

## Files and References

- [F29 parent](../../DOCKS.md) and [F29-A page and match flow](../DOCKS.md) — shared product and native stage ownership.
- [F29-B judging](../../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-C competition](../../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety](../../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy](../../F29-E-privacy-and-service-operation/DOCKS.md) — policy meaning and service boundaries.
- [Future implementation brief](../../../../prompts/F29-physique-duels/F29-A-d-phase-1-rules-and-rubric.md) — separate prospective engineering work; this product document contains no implementation tasks.
- [CYCLES.md](../../../../CYCLES.md) — implementation planning and human-review ownership, not an assertion that dependencies are accepted.
- Prospective TimeMaster/Views/Physique/PhysiqueRulesView.swift — the one reader in its native host contexts, not another app shell.
- Prospective TimeMaster/Views/Physique/PhysiqueRubricCategoryRow.swift — the repeated category row and its deliberate explanatory disclosure, with the same four-category meaning.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), and [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift) — existing palette, typography, reading geometry, press and material language.
- [RankedComponents.swift](../../../../TimeMaster/Views/Ranked/RankedComponents.swift) and [RankedDuelPlayerView.swift](../../../../TimeMaster/Views/Ranked/RankedDuelPlayerView.swift) — sports hierarchy and shared controls as patterns, not permission to inherit text clamps, movement scores or live provisional physique scoring.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) and [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) — native window and reserved-command context.
- [Battle reference image](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) — directness and timer-first hierarchy only; not its horizontal players, purple/brown labels, identifiable people, text, footage or asset rights.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), especially Best practices — native input, window flexibility and comfortable information density.
- [Apple HIG: Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls), especially Best practices and Disclosure triangles — essential content stays visible; descriptive disclosure belongs beside optional related detail.
- [Apple HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), especially Best practices and macOS — scoped native presentation, one sheet at a time and a nonmodal alternative when the match must stay usable.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), especially Best practices and Providing feedback — purposeful brief feedback, optional motion and interruption without waiting.
- [Dimillian SwiftUI UI Patterns](https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns) — selected composition, native presentation and narrow state-ownership guidance; no parallel global router or newer-OS-only requirement is implied.
