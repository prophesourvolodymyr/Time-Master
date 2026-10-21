# F29-C — Physique Rating and Matchmaking

## Status and Scope

This is a promoted product specification for the independent Physique competition domain, not a claim that ratings, pairing, or service persistence have been implemented or human-verified. The [parent contract](../DOCKS.md) owns shared decisions. Promotion into features concerns documentation placement and does not authorize app implementation. Apart from the user-directed separate physique ladder, the numerical conventions and detailed behaviors below are proposed defaults for review.

This area owns physique-only Elo, placement, pairing, competitive records, standings, and match history. It consumes validated outcomes from F29-B. It does not decide which body wins from photos, turn exercise performance into a physique contest, own capture layout, or replace F29-D's safety and appeal process. F29-E owns identity, service operation, and retention constraints.

## One Independent, Service-Owned Ladder

There is one Physique ladder. It is not split by pose, body part, declared gender, attire, model, device, subscription, or payment status. The service uses one approved judging configuration for both participants in a match. The common-region rubric and its limitations are described in F29-B; private declarations are eligibility information, not rating categories or matchmaking preferences.

Every occurrence of the rating is scoped in visible and accessible language as Physique Elo, Physique tier, or Physique standings. A bare number labeled only Elo or Rank is insufficient in a mixed exercise-and-physique app. This rating is neither a body score nor an overall fitness rating.

Exercise Elo, local profile display levels, AI category scores, workout history, calories, and physique Elo remain separate. No existing push-up, squat, plank, overall local level, or account age is migrated into a starting physique rating. There is no import, manual edit, local reset, paid placement, custom starting value, or client-generated competitive adjustment. Reinstalling or using another device does not restart an account's placement. Editing local profile data or changing a display name does not alter the service-owned record.

The trusted service owns the effective rating, history, placement count, and public position for the authenticated account. Cached values are clearly labeled when stale and cannot settle a match or grant matchmaking eligibility while the authoritative state is unavailable. Personal provider selection and API keys do not select a physique judge or a different ladder.

The proposed ladder has no scheduled seasonal reset, inactivity decay, or purchased protection from rating loss. An eventual change to those product rules needs its own reviewed policy; it cannot be inferred from a model upgrade or silently applied as a local display change.

## Unplaced, Provisional, and Placed

| State | Rating and record presentation | Competitive meaning |
| --- | --- | --- |
| Unplaced, no finalized rated matches | Unplaced; no earned Elo, best Elo, tier, or standings position | The proposed service pairing seed is 1000, but it is not presented as an earned rating |
| One through four finalized rated matches | Current Physique Elo, best earned Physique Elo, actual record, and Provisional with the completed count out of five | The account is still completing the first five rated matches; it has no public placed standing or assigned tier yet |
| Fifth finalized rated match completed | Placement complete, current and best earned Physique Elo, actual record, and the tier supported by the current rating | The account becomes placed and can appear in standings if its public-listing and safety status allow it |
| Placed, later rated matches | Current and best Physique Elo, tier, record, and permitted standing | The established sensitivity applies from the sixth rated match onward |
| Correction removes a prior rated match | The effective placement count and status are revised with a correction notice | A placed account can become provisional or unplaced again; a stale placed badge is not retained as an entitlement |

A valid win, loss, draw, or eligible rated forfeit advances the first-five count. A no-contest, pre-Go cancellation, search timeout, practice action, pending judgement, or duplicated result does not. At each original match start, the service fixes sensitivity from the then-confirmed completed count: the fifth rated match uses the provisional sensitivity and the sixth uses the established sensitivity. A later correction can revise placement and sensitivity for future matches, but does not rewrite the policy used in already valid later matches. This count belongs to Physique only.

Current Elo is the last settled rating after effective rated outcomes and authorized corrections. Best Elo is the highest actually earned settled rating in the effective history, not the hidden initial seed. If the first rated result leaves the player below 1000, the best value starts at that actual post-match value rather than an unearned 1000. Current Elo can fall without lowering an honestly earned best; a correction can revise best when the earlier earning event was invalid or incorrectly settled.

A pending match does not optimistically increase current or best Elo. Closing a result screen, missing an animation, or being offline when a match finalizes does not prevent the earned result from appearing on the next authenticated refresh.

## Proposed Rating Convention

The intended convention follows the existing Rust service's rating behavior while keeping Physique records and game counts independent: an initial pairing seed of 1000, a sensitivity of 40 for each player's first five finalized rated matches, a sensitivity of 24 thereafter, a 400-point expected-score convention, and whole-number ratings bounded from zero to 5000 inclusive. These are proposed Physique defaults, not evidence that a physique ladder already uses them.

A win is a full successful result, a loss a full unsuccessful result, and a draw a half result for each participant. The rating expectation reflects the two pre-match Physique ratings. Beating a higher-rated participant earns more than beating a lower-rated participant under otherwise equal conditions. Losing to a lower-rated participant costs more than losing to a higher-rated participant. A draw between unequal ratings can increase the lower-rated person's Elo and reduce the higher-rated person's Elo; Draw does not promise zero change.

The final change is rounded to the nearest whole rating point, with an exact half-point rounded away from zero, and the resulting rating stays within the stated bounds. A rating at a bound can have a smaller effective change than its otherwise calculated change. One player can still be provisional while the other is established. Because sensitivities and bounds can differ, their visible changes need not be equal and opposite. The result must show each player's own actual before, change, and after values rather than inventing a balancing transfer.

For orientation, equal 1000-rated provisional participants record 1020 and 980 after a win and loss. Equal established participants would change by twelve points in those same respective directions. Equal-rated participants drawing have no change. These examples explain the proposed convention, not a claim about a completed match or model accuracy.

Only the validated outcome goes into this rating convention. A category score, weighted total, score margin, model confidence claim, amount of exposed skin, or a polished explanation cannot become Elo or multiply its change. Winning by exactly the three-point threshold and winning by a larger supported margin have the same win/loss meaning for otherwise equal rating inputs. A valid forfeit uses the ordinary win/loss convention, not an additional punitive multiplier or invented physique score.

The physique tier names and thresholds use the shared native tier vocabulary:

| Physique tier | Current placed Physique Elo |
| --- | --- |
| Iron | 0–799 |
| Bronze | 800–999 |
| Silver | 1000–1399 |
| Gold | 1400–1799 |
| Diamond | 1800–2199 |
| Champion | 2200–5000 |

Crossing a threshold changes the current Physique tier after authoritative finalization. Best Elo does not lock a higher current tier, a cosmetic badge does not grant one, and the boundary applies at the exact displayed whole-number rating. Unplaced and provisional states are explicit rather than borrowing an exercise tier or presenting a predicted tier as placed standing.

## Record, Streak, and Win-Rate Meaning

| Record item | Included | Excluded or qualifying detail |
| --- | --- | --- |
| Wins | Finalized scored wins and wins from an eligible opponent forfeit | A report, block, provider failure, or abandoned invalid match is not a free win |
| Losses | Finalized scored losses and the person's own eligible confirmed forfeit losses | Invalid evidence and involuntary capture interruption are not disguised losses |
| Draws | Complete valid AI comparisons inside the parent's below-three-point band | A refusal, missing category, timeout, or insufficient evidence is not a draw |
| Rated matches | Wins, losses, and draws, including their forfeit subsets | No-contests and pending matches do not advance rated-match or placement counts |
| Forfeits | The person's own eligible forfeit losses, separately identified as a subset of losses | Forfeits are not added again to the rated-match total; a win by opponent forfeit remains a win and can be labeled as such |
| No-contests | Started matches finalized without a rated outcome | No Elo change, no win/loss/draw, and no placement advancement |
| Current win streak | Consecutive effective rated wins, including wins by forfeit | A rated loss, own rated forfeit, or draw resets it; no-contests neither extend nor break it; pending matches have no effect |
| Win rate | The proportion of finalized rated matches that are wins, shown as a percentage to one decimal place | Draws remain in the denominator; no-contests, pending matches, and cancellations are excluded; no rated matches shows Not available, not a fabricated zero-percent record |

History and details always distinguish a scored victory from Won by forfeit, a scored loss from Forfeited, and a supported draw from No-contest. Total counts remain internally consistent: a forfeit label never creates an extra loss or a second match. Provisional matches are real rated matches once finalized and are included in the record.

These are competitive records, not workouts. They do not complete a schedule item, create a training-duration entry, award repetitions or calories, or extend an existing exercise or workout streak. An administrative correction revises the effective counts, streak, win rate, current/best rating, and placement coherently rather than leaving contradictory summaries.

## Pairing Eligibility and Search

Find opponent is available only after the parent eligibility checks: authenticated adult access, current rules and sharing consent, available camera and adequate preflight, an available independent physique slot, and a healthy judging service. There is at most one reserved or active physique match per account across devices. A second device resumes the existing service-owned state rather than reserving another match or creating a second local queue position.

Pairing uses the current settled Physique rating, or the 1000 seed for an unplaced account. Provisional status is disclosed honestly; it is not a hidden higher or lower seed derived from exercise performance. An unplaced or provisional player can meet an established player inside the allowed rating range. There is no separate placement-only ladder and no demographic or attire filter.

Only real, eligible accounts can be paired. Same-account pairing is forbidden, including the same account open on another device. A block in either direction excludes the pair before Go. Suspended or otherwise ineligible accounts, accounts already in another active physique match, and unavailable participants cannot be used to make a queue appear populated. Substantiated account abuse follows F29-D; an IP address, device similarity, or appearance guess alone is not presented as proof of account identity or cheating.

### Bounded Skill Expansion

The proposed ninety-second search uses a deliberately bounded rating expansion:

| Elapsed search time | Largest permitted Physique Elo difference |
| --- | --- |
| Before thirty seconds | 100 points |
| At thirty seconds and before sixty seconds | 200 points |
| At sixty seconds and before ninety seconds | 400 points |

A pair must fit both participants' current allowed windows, not just the person who has waited longer. Within an allowed window, the product prefers a closer rating match; waiting time resolves otherwise equivalent eligible choices. No opponent beyond the 400-point cap is forced on someone merely to end a search. At ninety seconds an unpaired search ends with No opponent found, the reservation is released, and Retry starts a new search only when intentionally chosen.

The screen can explain that the rating range is widening, but it cannot invent a nearby-player count, predicted wait, guaranteed opponent, body-photo preview, or apparent match. Search time is an actual service-owned interval, not a looping decorative timer that silently restarts. Current queue health and population have not been measured by this specification.

Pairing displays the opponent's permitted public identity, current match-time Physique rating or Unplaced state, and provisional label where relevant. It does not disclose exercise Elo, age or gender declarations, private account details, history, reports, subscription, or model preferences. The judge remains blind to the rating and identity information shown to players. Both players explicitly become Ready before the synchronized three-second countdown. F29-A owns ready-room timing and exact controls; any failure to start before Go releases the reservation without a rated result.

The service confirms eligibility, mutual block status, settled rating inputs, allowance, and the chosen judging/rating policy before Go. A restriction or unavailable judge prevents a new start instead of admitting the match and later inventing a result. A corrected or unsettled rating is labeled as such and cannot silently become a new pairing seed.

## Allowance, Cancellation, and Interruption Boundaries

The physique allowance is ten started matches per rolling four hours per account across devices. It does not consume or restore any exercise-family allowance, AI Coach balance, or workout entitlement. An available slot is reserved during pairing and becomes consumed only at the authoritative Go transition, after the three-second countdown. Opening rules, viewing standings, checking history, accepting a permission, or merely entering the queue is not a started duel.

| Boundary | Rating and history behavior | Physique allowance behavior |
| --- | --- | --- |
| Cancel during search, Ready, or countdown, accepted before Go | No rated result and no started-match history row | Reservation released; no consumed slot |
| No opponent before the ninety-second search ends | No opponent, winner, or duel is fabricated | Reservation released |
| Go accepted | One real started match exists; result is pending until finalization | One slot consumed, once |
| Capture fails, required evidence is invalid, moderation aborts, or judging service fails | No-contest; no Elo, rated count, or streak change | The consumed slot is restored once |
| Eligible deliberate confirmed Forfeit and leave after Go | Forfeit loss and opponent win, without invented physique scores | Slot remains consumed |
| Involuntary interruption that can be recovered | Same match and original timing resume; no extra match or rating event | No second charge |
| Involuntary interruption that prevents valid participation | No-contest, not an automatic loss | Restore once under the no-contest rule |
| Valid scored result | One win/loss or draw outcome settles the match | Slot remains consumed |
| Closing or reopening a result | No change to the final outcome | No charge or restoration |

Go is a service-owned boundary, not the client's visual countdown reaching zero. If a cancellation reaches the service after Go, the app must show that the match has started and offer rejoining or the explicit confirmed forfeit action; it must not silently reinterpret a pre-start Cancel as consent to a rated loss. Repeated taps, reconnects, or a second device cannot spend or restore the same slot twice.

The shared capture period is ninety seconds, with the three required poses and at most two retakes per pose. A connection interruption stops capture immediately. The proposed reconnect grace is twenty seconds, but never extends the original capture or judging deadline. Resuming continues the same accepted evidence and remaining time. If the required participation cannot be restored in time, the match becomes a no-contest. Repeated abandonment may justify a separate abuse restriction; it is not evidence that an unseen physique deserved to lose.

When both complete pose sets have already been accepted, judging may finalize while a client is offline; absence from the result screen is not itself a reason to discard adequate evidence. The result deadline remains thirty seconds after both final sets are received. F29-A and F29-E own honest reconnect and result-retrieval presentation. A late provider response cannot replace a timeout no-contest.

After Go, Block hides the other person's permitted media and prevents future pairing. It is not a Cancel, a model verdict, or an automatic free win. A safety-aborted, invalid, or unavailable-service match takes precedence over a forfeit. An otherwise eligible explicit forfeit is a distinct deliberate action. If both people attempt to forfeit, the first eligible confirmed forfeit accepted by the authoritative service settles that outcome; the second request cannot settle it again. If a valid rated outcome cannot be established, the result is a no-contest rather than an invented simultaneous-forfeit draw.

Restoration removes the affected started match's allowance charge only once; it is not a banked bonus slot with a fresh four-hour lifetime. If the original charge has already aged out of the rolling window, restoration creates no additional credit. A later correction to no-contest follows the same rule. A previously restored charge is not restored twice or silently recharged later. The page shows the current server-confirmed availability and next slot time, not a guessed local countdown presented as authority.

## Authoritative Finality

One match has one original final competitive outcome. The trusted service owns the association among the accepted evidence, eligibility, frozen judging configuration, rating policy, final outcome, effective rating changes, records, and allowance consequence. A result is not final merely because the model returned text or the phone displayed a local score.

Each participant's rating inputs are the authoritative pre-match values under the fixed rating policy. A finalized outcome updates both players' records consistently. The app never displays a completed reward based on a result that has not settled. If finalization cannot be confirmed, it shows Result pending or Unable to refresh result with the last confirmed rating, not a speculative win or zero-point result.

Repeated submissions, duplicate provider responses, service recovery, foreground refreshes, result-screen revisits, and notifications all retrieve or complete the same authoritative result. They cannot add a second game, apply a second Elo change, advance placement twice, restore the allowance twice, or create two conflicting winners. If a result finalized while the person was offline, returning fetches that existing result rather than starting another match. A finalized no-contest remains a no-contest when a late model response arrives.

A terminal result and its rating effect are stable against ordinary client actions. Authorized post-result corrections are separately identified review events, not a second original finalization, a provider reroll, or a player-editable history entry.

## Outcome Disputes, Corrections, and Audit Meaning

A score/outcome dispute is distinct from reporting unsafe content and from appealing an account restriction. F29-D owns intake, human review, confidentiality, and enforcement. Submitting a report, blocking the opponent, disagreeing with a score, or opening an appeal does not by itself change Elo, hide a loss from the rated denominator, grant the reporter a win, or refund a valid voluntary forfeit.

The current confirmed outcome remains effective while review is pending. Match details can say Under review and show the person's private case state, without publishing the allegation or implying the opponent has been found at fault. A pending appeal does not automatically remove an otherwise eligible public standing; a separate safety restriction may do so.

Proposed authorized corrections are limited to supported invalidity or an evidenced settlement error. Examples include an accepted capture later confirmed ineligible, participant labels mapped incorrectly, the original valid category totals interpreted incorrectly at the fixed draw boundary, or a duplicated rating effect. A substantiated invalid match normally becomes a corrected no-contest, not an automatic reporter victory. A deterministic error can be corrected from the original accepted scores and policy; reviewers must not fabricate new physique scores to make a replacement winner possible.

Subjective disagreement alone does not authorize a new model run, a newer rubric, an Astra tie-breaker, or an unrecorded manual rating adjustment. Ordinary expiry of pose images is not itself proof that a valid historical match was invalid. When retained evidence cannot support a requested conclusion, review must state that limitation rather than inventing a winner or treating missing evidence as exoneration. Human review cannot promise that every older score can be independently reconstructed after permitted media deletion.

A correction has its own review identity, date, private reason category, original and corrected outcome, and the changed competitive consequences. The affected person sees what changed and why, within safety and privacy limits. The original result remains distinguishable in the authorized audit history; it is not silently erased, and the corrected current view is not left alongside a contradictory uncanceled rating award.

### Scope and Timing of a Correction

The proposed correction is bounded to the reviewed match and its two participants. The service reverses or replaces that match's actual rating effect through a separately identified adjustment to each participant's current confirmed rating. The original recorded rating inputs and policy determine the justified correction; reviewers cannot choose an arbitrary point award. Whole-point bounds still apply, and the person sees the actual settled adjustment if a bound limits it. The same reviewed correction cannot be applied twice.

Later valid matches keep their original evidence, scores, winner or draw, rating inputs, sensitivity, settled rating effects, match time, and judging version. Their opponents are not retroactively rerated because an earlier match was reviewed. This deliberately preserves the ratings actually used when those later matches were played rather than claiming to reconstruct a counterfactual league history. The correction record distinguishes the reviewed match's original settlement from the adjustment made now; it does not silently rewrite intervening snapshots.

The reviewed result's effective win/loss/draw or no-contest status, placement contribution, record counts, streaks, current tier, and allowance consequence are corrected coherently. Best Elo excludes an earning event invalidated by the review, while retaining later genuinely settled valid achievements; a valid corrected award can establish a new best when it settles. Removing an earlier rated match can make an account provisional or unplaced again and changes future placement sensitivity. It does not retrospectively change the sensitivity of valid matches already completed.

While the two affected accounts' correction is settling, their summary says Rating updating after review and retains the labeled last confirmed values; they cannot start a new rated match with an unsettled seed. Unaffected accounts and standings do not require a league-wide replay or blanket pause. An unsuccessful refresh leaves the correction pending rather than exposing mixed totals or erasing the case. Once settled, the revised current rating, record, and standing appear together, and the affected participants can read the adjustment and reason. F29-E owns audit retention and recovery; this policy does not require permanent pose-image storage.

## Standings and Public Visibility

Standings contain only real placed Physique accounts eligible for public listing. The proposed default requires an explicit Physique public-listing choice before publishing a person's identity and rating in this board. Unlisted or private participants can still earn the same service-owned rating and record, but the page says Not publicly listed rather than inventing a public position. Unplaced and provisional participants see their actual placement state, not a rank among fabricated provisional entries. Paired-opponent identity and match-time rating remain disclosed under the participation rules even when someone is not listed publicly.

The list is ordered by current Physique Elo, not AI body score, best historical Elo, wins, spending, workout streak, or preferred attire. Equal current ratings share the same competitive position. If two people share first place, the next person is third. A stable order among equally rated rows makes paging usable but is not a hidden tie-break advantage. Best Elo does not break the tie or become the current rank.

A public row contains only permitted public identity, shared standing, current Physique Elo, current Physique tier, and clearly labeled competitive record information permitted by the listing choice. It never contains physique pose thumbnails, private match galleries, age or gender declarations, reports, enforcement details, exact location, or medical interpretations. A profile avatar is not permission to publish a submitted body image. Public profile access continues to respect the account's existing visibility rules.

Deleted accounts, accounts no longer publicly listed, and banned accounts do not remain as discoverable active leaderboard entries. A ban alone does not automatically invalidate every earlier match or create free wins for former opponents. Existing valid records remain effective unless a supported correction says otherwise. A successful restriction appeal can restore listing only after eligibility, placement, and the public-listing choice are confirmed; it does not invent a place during the appeal.

A block in either direction removes the corresponding person's discoverable row and profile action from the viewer's board. Displayed positions still refer to the full eligible public standings, not a personally renumbered ladder. The page can explain that safety settings hide some players; gaps are not filled with invented rows. The service does not reveal another person's identity merely because it is needed to make twenty visible rows.

The scope is labeled Physique, and the snapshot time is available. A player's own current position is a separate service-confirmed value when eligible; not appearing in the currently loaded page is not evidence that the person has no rank. No opponent count, rank, change arrow, or historical comparison is invented when the service cannot provide it.

## Private Match History and Detail

The participant's history is service-owned, most recent started match first, with actual match time, permitted opponent identity, outcome label, own effective rating change, and any pending, forfeit, no-contest, or correction marker. A pending started match may appear as Pending, without contributing to rated statistics. Search attempts and pre-Go cancellations are not fictitious duels or scored history rows.

A valid scored detail contains both accepted category breakdowns and totals, total gap, winner or draw, a neutral explanation, the judging version, the person's own before/change/after Physique Elo, and the applicable rating-policy context. The opponent's permitted match-time Physique rating and placement state identify the pairing context without exposing the opponent's private history. Old rows retain historical opponent labels where permitted; changing a present-day handle must not misattribute who played the match. Current public profile navigation remains governed by today's visibility and safety status.

A forfeit detail states who forfeited in the viewer's perspective, its ordinary rated effect, and the absence of physique scores. A no-contest detail states that no Elo or rated count changed, its safe reason category, and whether allowance restoration occurred. No-contest details do not display zero-filled category meters or a draw medal.

Only valid AI-judged win/loss/draw details can offer the intentional paired-opponent gallery after accepted evidence and prior mutual consent. Forfeits and no-contests have no opponent-pose gallery even if candidate stills were captured. The ordinary gallery window is twenty-four hours after finalization. Expired, removed, reported, hidden, or blocked images have the appropriate placeholder and are not reconstructed. Reporting or hiding remains possible without enlarging a still. F29-D and F29-E own access removal and any narrowly retained report evidence; history does not imply permanent photo storage.

A deleted or unavailable opponent appears as Unavailable player with no broken avatar or active profile link. A blocked opponent appears as Blocked player and the gallery is hidden. A restricted opponent is not publicly labeled with an allegation or ban reason. Own outcome, effective rating, judging-version context, and permitted correction history remain readable subject to the retention and account-deletion policy. Account deletion must not leave a rediscoverable identity in another participant's history merely to preserve a named record.

## Loading, Empty, Offline, and Review States

The proposed page size is twenty actual rows for either standings or history. Loading fewer rows does not authorize filling the space with samples. Load more is an accessible action; automated paging, if used by the native surface, must preserve that alternative. Pagination retains a stable service snapshot so equal ratings or concurrent new matches do not cause duplicate rows, skipped history, or moving focus. A refresh intentionally obtains a newer view. A quiet New results available or Standings updated action avoids rearranging the list while someone is reading it.

| State | Match history | Standings |
| --- | --- | --- |
| Initial loading | A named loading state; no sample matches, scores, or optimistic rating | A named loading state; no fake leaders, count, or rank |
| Refresh with existing content | Last confirmed rows remain, labeled with freshness where necessary | Last confirmed snapshot remains clearly identified until replacement |
| Empty | No physique matches yet and an eligible path back to the lobby; pre-Go searches are not inserted to fill it | No eligible public Physique standings yet; no seeded accounts or synthetic competition |
| Unplaced | No earned rating or best; actual pending/no-contest history can still exist | Unplaced and placement guidance, not a numeric position |
| Provisional | Actual rated rows and progress toward five | Not placed yet; no invented public provisional rank |
| Unlisted or private | Own history remains private and usable | Not publicly listed; public-listing controls do not erase earned Elo |
| Offline with a permitted cache | Saved result rows are labeled as not refreshed; no new competitive action is settled locally | Saved board is labeled stale; no live-position claim or inferred rank change |
| Offline without a cache | Unable to load history with Retry; never No matches yet | Unable to load standings with Retry; never an empty ladder claim |
| First-page service error | A retryable error distinct from a genuine empty account | A retryable error distinct from no eligible players |
| Later-page loading or failure | Existing rows and reading position stay; retry only the missing page | Existing snapshot stays; no fake continuation or silent restart |
| End of list | A clear end state; no endlessly repeating rows | A clear end state; no invented lower-ranked players |
| Snapshot expired or materially changed | Explain that a refresh is needed and preserve a stable reading position where possible | Refresh the coherent standing view rather than merge incompatible positions |
| Account changed or signed out | Previous account's private cache is not shown as the new account's history; Sign in is available | No private own-position claim survives the account change; account access governs available public browsing |
| Camera denied, allowance exhausted, or judge unavailable | Existing history and review access remain usable | Existing standings remain viewable when the account can browse; these are not new rating losses |
| Own account suspended or banned | Private restriction and permitted review/history access are clear; no new pairing | No active public listing while prohibited; no public accusation label |
| Restriction appeal pending | Private case state and the currently effective record; no promised reinstatement | The effective restriction remains until an authorized decision; no phantom return to a position |
| Outcome dispute pending | Current confirmed outcome plus Under review; no free reroll or provisional reversal | The effective settled rating remains unless a separate restriction applies |
| Restriction appeal upheld | A private decision identifies restored access and any remaining conditions; valid match history is not rewritten solely because the restriction changed | Listing returns only when placement, current eligibility, and the person's public-listing choice allow it |
| Appeal denied or case closed without a correction | The private decision and allowed next action are clear; the effective record and any restriction remain unchanged | No rating boost, hidden-loss removal, or automatic reinstatement |
| Review unable to establish an outcome error | The evidence limitation and case status are stated without inventing scores or a verdict | The last confirmed rating remains effective unless separately restricted or authoritatively corrected |
| Outcome correction approved | The decision identifies the original outcome, supported correction, and pending or settled competitive consequences | The revised standing appears only with the coherent corrected rating view |
| Correction settling | Last confirmed values labeled Rating updating after review; no mixed totals | A coherent labeled snapshot or temporary own-position unavailability, not a guessed corrected place |
| Deleted, blocked, or unavailable opponent | Safe identity and media placeholders; own permitted record survives | The corresponding discoverable row is absent without renumbering competitive positions |
| Media expired or removed | Textual result and allowed dispute status remain; explicit media placeholder | No gallery or physique image existed on the board to begin with |

The list surface must distinguish genuinely empty, hidden by privacy, loading, offline, unavailable, and removed. A zero, dash, blank row, or endless spinner must not stand in for all these meanings. Error recovery retrieves authoritative data; it never calculates a replacement opponent, rank, or Elo on the phone.

## Interactions, Accessibility, and Motion

Rating summaries lead to physique-specific context, not a mixed-ranking page that silently swaps units. A standings row opens only permitted profile information; a history row opens that participant's private match detail. Refresh, Load more, Close, report, block, and appeal entry points are named controls rather than swipe-only or icon-only actions. F29-A owns the exact navigation and focus behavior, while F29-D owns safety confirmation and case screens.

The existing Profile shape is preserved. Do not add a third side indicator, crowd the existing two-side chrome, replace the exercise-rating destination, or combine physique and exercise Elo. A clearly labeled Physique entry or link can open the separate rating detail through the existing profile/navigation pattern. The current exercise badge remains what it already means. Cosmetics, local profile previews, and verification styling cannot be mistaken for Physique placement or competitive authority.

VoiceOver reads the scope, identity or safe placeholder, position, current rating, tier, provisional status, and outcome in a logical sequence. A change is spoken as gained, lost, or unchanged points rather than relying on color or a plus/minus glyph alone. Tied positions are announced as shared. Current, best, stale, under review, corrected, and not publicly listed are distinct accessible values, not tiny badges that only a sighted reader can discover.

Dynamic Type can expand a row without truncating the rating scope or outcome. Numeric alignment does not take priority over large readable labels. Text and icons supplement tier color, winning streaks, losses, and correction notices. Full Keyboard Access, Switch Control, and conventional focus navigation must reach paging and safety controls. Loading feedback does not repeatedly steal focus, and an arriving page or correction is announced once without reading the entire ladder aloud. Important result and review text does not auto-dismiss on a timer.

A confirmed own-rating change may animate once after authoritative settlement, with before and after values also available immediately as text. No celebratory points animate while a result or correction is pending. Returning to a saved result does not award or animate the same points again. Standings refreshes do not race rows past the reader, use a slot-machine rank reveal, or imply a measured rise from absent data.

Reduce Motion uses static final values or restrained opacity changes instead of number rolling, scale, spring travel, or repeated decorative motion. Reduce Transparency preserves readable opaque rows. Haptics and sound are optional reinforcement, not the only indication of an outcome or deadline. Losses, forfeits, and no-contests do not shake or humiliate an opponent's name or image.

## File Ownership and Dependencies

These are current integration surfaces or prospective feature-owned locations, not an implementation recipe:

- This DOCKS.md owns the separate physique competition, rating, pairing, record, standings, history, and correction semantics. The parent owns shared lifecycle decisions.
- ranked_server/src/rules.rs currently defines the existing exercise Elo convention, including first-five sensitivities, whole-point change rounding, and zero-to-5000 bounds. ranked_server/src/store.rs currently supplies a 1000 initial rating in that existing domain. Those facts inform the proposal but do not create physique records or authorize migration.
- ranked_server/src/ and ranked_server/schema.sql are the trusted-service and persistence integration surfaces for distinct physique ratings, queue ownership, finality, record chronology, standings, and authorized correction audit history.
- Prospective TimeMaster/Models/PhysiqueDuelModels.swift owns native representation of physique placement, versioned outcomes, rating snapshots, records, and unavailable states.
- Prospective TimeMaster/Services/Physique/ owns authenticated retrieval of authoritative matchmaking, records, standings, and history, not editable local competitive state.
- Prospective TimeMaster/Views/Physique/ owns the physique-specific lobby summaries, standings, history, result detail, and accessible state presentation specified with F29-A.
- TimeMaster/Views/Profile/ProfileView.swift and TimeMaster/Views/Profile/ImportedProfileChrome.swift own the existing two-side profile shape and exercise rating entry. Physique adds a clearly scoped destination without a third side badge or replacement of that exercise behavior.
- TimeMaster/Views/Ranked/ and TimeMaster/Services/Ranked/ supply existing identity and interaction patterns; their exercise ladders, quotas, histories, and joint-only media promise keep their current meaning.

F29-C depends on F29-B's validated score/outcome boundary, F29-A's real lifecycle and explicit Go/forfeit controls, F29-D's eligibility, blocks, moderation, reports and appeal decisions, and F29-E's authenticated service, availability, privacy, deletion, and operational recovery. A reachable UI without persistent authoritative rating and finality is not a competitive feature. Pending reviews of the existing account and service foundations remain pending; this specification does not bypass them.

## Genuine Product Uncertainties

The 100/200/400-point search bands, ninety-second queue, first-five placement behavior, rating sensitivities, public-listing experience, and common-region judging quality need human review and real population evaluation. They are explicit proposed rules, not measured match quality, wait time, fairness, or retention results. A small population may make the bounded search return no opponent; the honest product response is an empty queue, not a bot, fake rival, hidden unbounded skill gap, or fabricated leaderboard.

The real human review operation and acceptable time for settling audited corrections must be established with F29-D and F29-E. No appeal success rate, review deadline, automatic reimbursement promise, or permanent media archive is claimed here. Bounded corrections preserve later valid settlements rather than promising a perfectly reconstructed alternative rating history; that tradeoff is explicit for human review. Subjective physique Elo and the broader App Store objectification risk remain product questions even if the rating arithmetic is conventional.

## References

- [F29 parent contract](../DOCKS.md), especially the separate competition domain, timing, allowance, no-contest precedence, and media boundaries.
- [F29-A page and match flow](../F29-A-page-and-match-flow/DOCKS.md), [F29-B AI judging and metrics](../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-D safety and reporting](../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy and service operation](../F29-E-privacy-and-service-operation/DOCKS.md).
- ranked_server/src/rules.rs, existing Elo convention at lines 788–798, and ranked_server/src/store.rs, existing default rating at lines 240–247: source context for the proposed reuse of rating conventions, not an existing physique ladder.
- TimeMaster/Views/Profile/ProfileView.swift and TimeMaster/Views/Profile/ImportedProfileChrome.swift: the existing profile rating and two-side indicator boundary.
- [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): current guidance for perceivable metrics, larger text, accessible controls, assistive navigation, and reduced motion; not a completed app audit.
- [Apple HIG — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy): data minimization, clear use disclosures, and respecting personal visibility choices; not an assertion of App Store approval.
