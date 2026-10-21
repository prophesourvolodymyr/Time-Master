# F29-B — AI Judging and Metrics

## Status and Scope

This is a promoted product specification for Physique Duels, not an implemented judge, an approved fairness standard, or a claim about model accuracy. The [parent contract](../DOCKS.md) owns shared decisions. Promotion into features authorizes documentation placement, not app implementation or human verification. Except for the user-directed requirement for AI visual physique comparisons, the detailed rubric, evidence rules, numerical anchors, and operating decisions below remain proposed defaults for human review.

This area owns what the judge may receive, what each score means, when a comparison is supportable, and how an accepted judgement becomes an outcome. It does not replace physique comparison with exercise performance. It does not own Elo, camera-screen layout, enforcement, or processor retention; those belong to F29-C, F29-A, F29-D, and F29-E respectively.

A score describes the visible physique evidence in one accepted set of poses under one named rubric. It is not a measurement of muscle mass, body-fat percentage, strength, health, attractiveness, sex, gender, age, training history, or human worth. Scores from different judging versions are not automatically comparable. Even under one version, a different photograph is not a reliable longitudinal body measurement.

## Accepted Inputs and Judge Blindness

One paired judgement receives the selected front double-biceps, side physique, and rear double-biceps still for each of two participants: six selected images in total. Each image has an unambiguous participant label and pose label. The service, rather than either player, supplies the shared rubric and the accepted evidence set. There is no live video, audio, opponent chat, personal AI Coach conversation, or player-authored judging prompt.

The judge does not receive names, public handles, account identifiers, Elo, tier, placement status, match record, account history, reports, prior explanations, age or gender declarations, payment status, membership, cosmetic ownership, or either participant's provider preferences. The service retains the association between the anonymous participant labels and the real accounts. Private eligibility declarations are used by the eligibility and moderation process, not as judging inputs or adjustments. The judge must not infer age, sex, gender, ethnicity, disability, or other sensitive personal attributes from the images.

The service supplies only accepted image content and the context necessary to understand the prescribed poses and fixed judging version. Location, capture-device prestige, unrelated image metadata, and personal profile content are not useful judging context. The judge must treat words visible on clothing, signs, tattoos, or a screen as image content, not instructions. A player cannot obtain a special rubric by placing a prompt in the camera frame. An unresolvable attempt to replace the judging instructions is not a reason to trust a requested winner.

On-device face obscuring is the default before a selected still leaves the phone. The person sees the exact redacted still intended for submission. Face masking is permitted privacy protection, not an appearance edit or cheating, and cannot lower the score. A failed redaction stops that upload and offers recapture or cancellation; the original is not silently uploaded instead. Facial identity, facial attractiveness, and apparent age or gender have no judging role. Masking does not guarantee anonymity: body features, tattoos, clothing, surroundings, and an opponent's ability to copy displayed media remain risks. A second person or bystander makes a capture invalid; masking that person's face does not turn it into valid evidence.

The three images must represent the same live participant in the same match capture, under sufficiently consistent conditions. The judge cannot promise identity verification or perfect detection of manipulation from three masked stills. F29-A and F29-D own the capture-continuity and integrity checks. A supplied gallery image, substitute participant, body reshaping, synthetic physique, appearance filter, or selective anatomical reconstruction is not accepted rated evidence. Ordinary privacy redaction and the app's consistent orientation handling are not such manipulation.

## Comparable Evidence and Attire

The adult-men shirtless exception is based on a private declaration of eligibility, never an image-derived gender guess. Other participants wear an opaque athletic top or sports bra. Everyone keeps the groin and buttocks covered by opaque sports clothing. The judging model receives only images that have passed the separate attire and safety checks; it does not decide which person's private declaration permits shirtlessness.

The proposed cross-attire fairness default is deliberately narrower than a bodybuilding stage assessment. The common rubric uses observable shoulder, upper-arm, upper-back, and leg evidence. Front-chest and abdominal appearance or definition are excluded for both participants, including when those regions are visible on a shirtless man. Breast, nipple and areola, groin, genital, and buttock anatomy are never scoring regions. A side or rear pose does not authorize sexualized inspection of a covered region.

This common-region limitation must be visible in the rules. It is not proof that clothed and shirtless comparisons are fair. Human evaluation must establish whether the remaining evidence is adequate across allowed attire. The feature cannot quietly add chest or abdominal points for a shirtless person while describing the competition as coverage-neutral.

| Pose | Required comparable evidence | What is not rewarded or reconstructed |
| --- | --- | --- |
| Front double-biceps | Both shoulder and upper-arm outlines, an interpretable bilateral stance, and the required thigh and calf outlines without material cropping or severe perspective distortion | Chest or abdominal exposure; breast or waist stereotypes; facial expression; inferred muscle beneath an unresolved garment |
| Side physique | A recognizable, safe side presentation with the prescribed arm and leg regions sufficiently visible to interpret their contours and orientation | Sexualized chest presentation; buttock or groin inspection; apparent size created by a close limb or a twisted camera angle |
| Rear double-biceps | Both shoulder and upper-arm outlines, an interpretable upper-back outline, and bilateral leg contours | Buttock anatomy; exposed-back bonuses; hidden upper-back muscle detail invented beneath a top |

All six images must support the same category definitions. The capture guide owns the named orientation, full-region framing, and a comfortable way to enter each pose. A mirrored local preview must not become an unexplained left-right reversal in symmetry scoring. Exact height, weight, or camera distance is not a scoring input, and apparent pixel size is not physical muscle size.

The evidence requirements differ by category, but not by player:

- Muscularity requires interpretable contours across the common shoulder, upper-arm, upper-back, thigh, and calf regions. An outer contour genuinely visible through opaque attire can be described as a contour; it does not reveal the anatomy or surface definition underneath.
- Definition requires a usable direct view of the common upper-arm and calf regions, sufficient to assess the presence or absence of muscle separation. Adequately visible regions with little or no separation support a valid low observation; they are not missing evidence. Fabric seams, shadows, patterns, and clothing folds are not muscle separation. Additional exposed chest, abdomen, or back detail contributes no extra definition points.
- Symmetry and balance require both sides of the relevant upper- and lower-body contours to be interpretable across the front and rear evidence. One favorable side image cannot establish bilateral symmetry on its own.
- Pose presentation requires a recognizable version of each prescribed pose, with the necessary regions visible and no unsafe or sexualized presentation. A still does not establish endurance, prolonged stability, or exercise performance.

A permitted opaque top is not a deduction, and a bare torso is not a bonus. Some otherwise permitted clothing can still obscure required evidence. The remedy is an honest evidence explanation and, while capture remains open, an optional safe recapture in permitted attire. It is never a request to remove required coverage, expose a protected region, tighten clothing over intimate anatomy, or accept a zero for an unseen area. If the fixed evidence requirements remain unmet, the match is a no-contest. The judge must not change the weights, drop a region for only one player, infer covered muscle definition, or compare a different body region instead.

A physical difference, mobility limitation, or comfortable pose variation is not itself a negative attribute. Guidance can accept a variation only when it preserves the same required comparison evidence for both people. If that is not possible, the service must explain insufficient comparable evidence privately rather than manufacture a physique loss or a medical classification. The accessibility and inclusion of these evidence requirements remains a genuine calibration question, not a solved property of the proposal.

## Rubric and Score Meaning

The four category scores are proposed whole-number points from zero to one hundred. The weighted total uses the same zero-to-one-hundred scale. These are rubric-relative subjective observations, not percentages of an ideal body, population percentiles, probabilities, or instrument readings. Both players can receive high scores, low scores, or the same score; the judge must not force a distribution or create a margin because the activity is competitive.

| Category | Fixed proposed weight | Included observations | Excluded signals |
| --- | --- | --- | --- |
| Visible muscularity | 40 percent | Apparent muscular development in the required common contours, considered across the three poses and relative to the participant's visible frame | Pixel size, height, body weight, inferred muscle mass, hidden anatomy, front-chest or abdominal appearance, sex-based ideals, strength, exertion, equipment, or training claims |
| Definition | 30 percent | Clearly supported visible muscle separation in the required common upper-arm and calf regions | Estimated body-fat percentage, health, vascularity as a goal, tanning, oil, sweat, dehydration, lighting-created edges, fabric detail, or extra skin exposure |
| Symmetry and balance | 20 percent | Apparent left-right muscular balance and coherent development across the required upper- and lower-body regions | A preferred sex-specific silhouette, breast symmetry, waist-to-hip ideals, facial symmetry, skeletal height or limb-length ideals, and diagnosis of a physical difference |
| Pose presentation | 10 percent | Safe recognizable pose alignment, clear placement of the required regions, and consistent presentation across the selected stills above the minimum evidence floor | Seductiveness, facial confidence, smiles, clothing price, professional posing theatrics, dangerous strain, pose duration, or camera production quality |

### Proposed Scoring Anchors

The following anchors describe a shared reference scale for human calibration. They are not established population norms. Zero is a possible valid low observation, not the value for a missing image or an unobservable category. One hundred is the top of this proposed reference rubric, not a biologically perfect body. Insufficient evidence has no numerical score.

| Score band | Visible muscularity | Definition | Symmetry and balance | Pose presentation |
| --- | --- | --- | --- | --- |
| 0–24 | Little distinct muscular contour is visible in the required regions despite adequate evidence | Little stable muscle separation is visible in the required surface regions despite adequate evidence | Pronounced observable imbalance across the required comparable muscular contours | The poses remain recognizable and adequate, but positioning is inconsistent and only minimally presents the required regions |
| 25–49 | Some muscular contour is visible, but development is limited or uneven across the common regions | Some supported separation is present, but it is limited or inconsistent across the required regions | Several clear imbalances are visible, alongside some balanced regions | The required poses are achieved, with repeated alignment or placement limitations that remain above the evidence floor |
| 50–74 | Clearly developed muscular contours are visible across much of the required evidence | Clear separation is visible across much of the required surface evidence | The required regions are generally balanced, with identifiable but limited differences | Clear, safe positioning consistently presents most required regions, with minor pose-alignment limitations |
| 75–89 | Pronounced muscular contours are consistently supported across the required regions | Pronounced separation is consistently supported across the required surface regions | The required muscular contours show strong bilateral and upper-lower balance | The three poses are consistently aligned and clearly present the required regions without unsafe strain |
| 90–100 | Exceptional apparent development across the required regions relative to the calibrated reference set | Exceptional visible separation across the required surface regions relative to the calibrated reference set | Exceptional observed muscular balance across the required evidence, without requiring a stereotyped body shape | Exceptionally clear and consistent execution of the prescribed safe presentation, not theatricality or greater exposure |

Capture adequacy is a gate, not a fifth category. A technically excellent phone, professional background, studio lighting, or higher-resolution image earns no points. A blurred, cropped, overexposed, dark, obstructed, or materially distorted image must be recaptured or rejected when it prevents the required observations. It must not receive an invented low physique score. Presentation points cannot compensate for an invalid pose or missing evidence.

## Totals, Display Precision, and the Winner Boundary

The fixed weights remain forty, thirty, twenty, and ten percent in every rated comparison under this rubric version. The accepted whole-point category scores support a total shown to one decimal place. No extra hidden model precision is allowed to create an outcome that contradicts the accepted scores. Individual contributions must not be separately rounded into a different total.

The outcome uses the accepted weighted totals, not shortened card text, animated intermediate digits, or the model's prose. An absolute total gap below three points is a valid draw; a gap of three points or more produces a winner. A gap of 2.9 is a draw. A gap of exactly 3.0 is not a draw. Details show both one-decimal totals and the one-decimal gap so that the boundary is understandable. A compact display may omit a redundant decimal only if the complete detail remains available and no result is determined from that abbreviated display.

A numerical category score is not Elo. A large winning margin does not award additional rating, and a draw does not imply unchanged Elo when the participants have unequal ratings. F29-C owns those consequences. The fixed total is not converted into a new profile level, workout completion, calorie estimate, or HealthKit measurement.

## Accepted Judgements and Non-Scored Outcomes

A successful judgement requires all six accepted images, all four categories for each participant, adequate evidence for each required category, valid score ranges and precision, a consistent total, and a safe explanation grounded in the accepted regions. The service owns the final outcome; a provider's free-text winner cannot override the score boundary.

| Outcome or failure | Meaning | Scores and competitive consequence |
| --- | --- | --- |
| Valid win or loss | Both complete sets support the fixed rubric, and their total gap is at least three points | Both accepted breakdowns are available; F29-C applies the win and loss |
| Valid draw | Both complete sets support the fixed rubric, and their total gap is below three points | Both accepted breakdowns are available; F29-C applies a rated draw |
| Insufficient evidence | A required pose or category cannot support a fair comparison for either person | No-contest, no invented category zeros, no winner, no Elo change, and the shared allowance-restoration rule applies |
| Moderation or integrity failure | Accepted evidence cannot satisfy the safety or capture-integrity contract | No-contest rather than a physique judgement; details and any enforcement follow F29-D |
| Refusal, missing category, malformed judgement, contradiction, or unsafe explanation | The judge has not supplied a valid complete judgement | No successful rated verdict; the result is a no-contest rather than a guessed winner or a favorable model reroll |
| Service failure or missed judging deadline | No valid judgement is available within the shared deadline | No-contest, even if a late response subsequently arrives |
| Eligible explicit forfeit | A participant deliberately confirms leaving a started, otherwise eligible match | A rated forfeit under F29-C, with no invented physique scores or explanation of bodily superiority |

A draw is a supported close comparison, not an escape hatch for uncertainty or refusal. A no-contest is an unscored match, not a draw or a hidden loss. A valid early forfeit does not require a fabricated complete pose set; absence caused solely by that confirmed forfeit is different from an independently invalid capture. Safety, invalid evidence, or unavailable-service conditions take precedence over a forfeit when the match is not otherwise eligible for a rated outcome. Involuntary disconnection is not itself an AI finding that the other physique was better.

Only a valid AI-judged win, loss, or draw with accepted evidence and prior mutual consent can make the paired-opponent still gallery available. A forfeit or no-contest has no opponent-pose gallery, even if some candidate images were captured. Approved galleries require an intentional action after finalization and expire under the parent's twenty-four-hour window; the score record does not depend on permanent image storage.

The service checks that the returned descriptions refer to the correct anonymous participant and pose, use only permitted observations, and agree with the accepted categories and total. Swapped participants, a winner inconsistent with the totals, a claim about an invisible body region, mutually incompatible descriptions, or an unsupported sensitive inference make the judgement invalid. The product must not silently repair a substantive contradiction by choosing the most convenient field. A provider's claim to be certain does not make a contradiction safe.

The five-second final-submission-to-displayed-result interval is an unmeasured experience target. At five seconds the app says that judging is still running; it does not claim a completion percentage or fabricate analysis stages. The deadline is thirty seconds after both final selected sets are received. A late or duplicated response cannot award a second result. A result-screen Retry retrieves the same service-owned state; it is not another vote. F29-E owns any strictly operational request recovery within the original deadline and policy, not a search for a preferable judgement.

## Explanations and Confidence

The result leads with the sport outcome and rubric, not a judgement of the person's worth. Explanations use short, neutral observations about the selected evidence, such as clearer supported upper-arm separation or more balanced observed contours under this rubric. They must identify relevant categories without sexualizing, humiliating, diagnosing, or prescribing body change. They do not infer diet, medication, steroid use, health, body-fat percentage, age, gender, or training discipline. They do not tell a participant to lose weight, dehydrate, expose more skin, or ignore pain.

A valid draw can say that the totals fall within the three-point draw band. A valid forfeit says that the match ended by forfeit, not that the missing poses scored poorly. A no-contest states the applicable private evidence, safety, or service reason without revealing another person's declaration or report. It cannot say that both bodies were equal when no valid comparison occurred.

The displayed explanation is a concise result summary, not private model reasoning or a chain of thought. Both participants receive the same substantive comparison with their own perspective labeled consistently. Translation cannot change the numbers, category meaning, winner, or tie band. Unsafe generated text is reportable independently of any image report.

No model confidence value is presented as a calibrated correctness percentage, a win probability, or an accuracy badge. Internal expressions such as sufficient evidence, uncertain interpretation, or refusal do not establish calibration. Evidence sufficiency is a required eligibility decision, not a hidden score multiplier or a substitute for evaluation. The product makes no claim that an accepted answer is objectively correct merely because it is well-structured.

## Camera, Lighting, and Human Calibration

Perspective, focal length, framing, shadows, exposure, compression, tattoos, skin tone, clothing coverage, and body type can change apparent contours or separation. The capture guide aims for comparable, usable conditions rather than professional photography. The judge must not reward a large foreground limb, dramatic side lighting, a tan, image sharpness beyond adequacy, or a clean background. If conditions are materially incomparable and cannot be resolved within capture, the proper result is insufficient evidence, not an invented adjustment to one person's body score.

Before rated use, a consented adult evaluation set and trained human reviewers must examine whether the proposed anchors and common regions support repeatable respectful comparisons. Human comparisons are also subjective. Reviewers need a shared rubric, appropriately diverse examples, independent observations, and a way to record disagreement or inadequate evidence rather than pressure to name a winner. A single person's aesthetic preference is not ground truth. Human review must not require the collection or disclosure of private age or gender declarations to the judging model.

Evaluation must include close cases near the draw boundary; repeated evaluations of unchanged accepted evidence; participant-order reversal; the three-pose requirement; opaque tops and sports bras alongside permitted male shirtlessness; darker and lighter skin tones; varied body types; tattoos; ordinary camera devices; imperfect but acceptable lighting; safe pose adaptations; and genuinely inadequate evidence. It must examine category stability, outcome agreement with the human rubric, contradictory descriptions, unsupported anatomy, refusal behavior, and whether capture or coverage differences systematically change outcomes. Aggregate agreement alone cannot hide a poor result for a particular allowed attire or capture condition.

These are required evaluation questions, not observed successful checks. Human reviewers must set and approve the ranked quality bar, subgroup safeguards, and acceptable instability before a production judge is chosen. This promoted specification does not invent a measured pass rate. If the quality bar cannot be met without scoring prohibited anatomy, rewarding exposure, or replacing the activity with exercise performance, rated Physique Duels must remain unavailable rather than conceal that limitation.

## Model Choice and Judging-Version Freeze

The current official [GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol) lists text and image input, text output, structured output support, and no fine-tuning support. It does not support audio or video input as a judging modality. Those capabilities make Sol a candidate for the six-still comparison; they do not establish physique-judging quality, calibrated confidence, moderation suitability, or a guaranteed response time. Structured output support helps establish a readable contract, not factual correctness. A feature plan must not depend on fine-tuning this model when the current model page says that it is unsupported.

OpenAI's [model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection#when-to-consider-gpt-61-sol) recommends comparing Sol and Astra on the actual task. Astra is an evaluation comparison, not an automatic second judge, tie-breaker, refusal override, or appeal reroll. Routine matches use one approved paired judgement, not a costly majority vote. The production choice should be the least costly stable candidate and reasoning setting that actually meets the agreed evidence, fairness, safety, consistency, and experience requirements. A more expensive model is not assumed correct, and a cheaper model is not chosen solely from a token-price estimate. No paid model evaluation or player-image upload is implied by this document.

A judging version identifies the rubric and anchors, common evidence regions, fixed weights, score precision, draw band, accepted explanation policy, requested provider model identifier, and relevant judging settings. The service fixes this configuration for both participants before Go and uses one paired request under that policy. It remains fixed for that match through the judging deadline. Changes apply to future matches under a newly named version; they cannot be introduced halfway through a capture, silently applied to only one participant, or used to rejudge old results for a more favorable outcome. An unavailable configured judge means no-contest rather than substitution with an unapproved model.

The current Sol page lists the model identifier gpt-6.1-sol but does not advertise a separate dated immutable snapshot. A requested alias is not proof of immutable provider weights. The result and audit record identify the requested alias and any provider-returned model identity honestly, without promising a provider release guarantee that the current documentation does not establish. The shared freeze is the service-owned configuration and paired evaluation, not a claim to control the provider's internal weights. Material provider changes require reviewed future judging versions and renewed quality evaluation; they do not authorize rerolling historical matches. An immutable snapshot contract is not an additional launch prerequisite beyond the actual human quality, safety, and fairness validation.

A safety or outcome appeal does not call a newer model until the desired player wins. F29-D owns the review process, and F29-C owns separately authorized, audited corrections of an invalid or incorrectly finalized result. Historical explanations retain their original judging-version context even after the ordinary images expire.

## User States, Interactions, and Accessibility

| State | Information and available interaction |
| --- | --- |
| Rules and rubric | Plain-language categories, weights, common-region limitation, attire rules, image-sharing consent, score meaning, draw boundary, and model limitations are available before participation |
| Local evidence guidance | The named pose and specific framing or lighting issue are described in text; an optional safe recapture is offered while the shared deadline and retake allowance permit it |
| Redaction or evidence failure | The image is not silently submitted; the person sees a concrete private reason and recapture or cancellation when available |
| Submission pending | Only actual accepted-image progress is shown; no score or opponent image is implied before finalization |
| Judging | An indeterminate state explains the wait; after five seconds the continued wait is acknowledged without a false percentage |
| Valid scored result | Outcome, both permitted category breakdowns and totals, total gap, neutral explanation, judging version, and the separate own-rating consequence are readable |
| Forfeit or no-contest | The actual reason replaces the absent score breakdown; no empty score meter suggests a zero and no illustration implies bodily inferiority |
| Details temporarily offline | Previously confirmed non-media result data may remain labeled as saved; Retry fetches the authoritative result rather than rerunning the judge |
| Explanation reported or result under dispute | Safety access and private review status remain available; the current confirmed outcome is not presented as already reversed |
| Media hidden, removed, or expired | An explicit placeholder remains beside the retained textual result; there is no reconstruction of missing evidence |

Scores must be readable as numbers and category names, not only colored bars, body silhouettes, or radial graphics. Weights are labeled as rubric weights, and scores as points out of one hundred rather than ambiguous confidence percentages. VoiceOver can read the participant label, category, score, weight, total, gap, outcome, and judging version in a logical order. A user can reach rubric details, explanation reporting, and Close without a precision gesture or time-limited tooltip. Dynamic Type, sufficient contrast, readable opaque surfaces under Reduce Transparency, and text accompanying status color follow the existing native patterns.

Judging explanations and evidence guidance must not depend on seeing the image; useful pose and error labels are available to assistive technologies. Such accessibility labels must not become unsolicited intimate descriptions or demographic guesses. An image is never auto-opened or read aloud as an intimate anatomical inventory. F29-A owns screen focus and safe capture announcements; F29-D owns image controls and report interactions.

## Animation Behavior

Judging uses the shared indeterminate activity treatment, not a fake scanning beam, fluctuating confidence gauge, or invented percentage. A completed score appears only after authoritative finalization. Any score reveal is restrained and does not delay access to the final values, explanation, safety controls, or rating details. Returning to the same result does not replay a fresh judgement or award animation.

Reduce Motion removes count-up, scale, travel, and repeating decorative motion; the final values remain immediately readable. Color, sound, and haptics are supplementary, never the only way to distinguish a draw, loss, no-contest, or warning. Reporting hides unsafe content immediately rather than waiting for a transition. Camera and decorative activity stop on backgrounding while service deadlines continue.

## File Ownership and Dependencies

These are existing integration surfaces or prospective feature-owned locations, not a claim that the feature exists:

- This DOCKS.md owns the F29-B input, rubric, evidence, and judgement meaning. The parent owns shared policy, and F29-A owns the capture and result screens.
- Prospective TimeMaster/Models/PhysiqueDuelModels.swift owns the native representation of version-labeled scores, evidence states, outcomes, and absent-score reasons.
- Prospective TimeMaster/Services/Physique/ owns communication of accepted capture and authoritative judging state, not local competitive adjudication.
- Prospective TimeMaster/Views/Physique/ owns rubric presentation, pose guidance, accessible result details, and explanation reporting entry points.
- ranked_server/src/ and ranked_server/schema.sql are the intended service integration surfaces for accepted evidence, judging policy, version identity, validation, and finality. F29-C owns their rating and record consequences.
- TimeMaster/Views/Ranked/RankedMatchPreparationView.swift currently promises that exercise-duel images remain on-device and opponents never see them. This feature's separate image-sharing path must preserve that existing exercise promise.

F29-B depends on consented, adequately framed capture from F29-A; the attire, integrity, moderation, reporting, and appeal constraints in F29-D; and the provider access, deadline, protected-media handling, deletion, and retention constraints in F29-E. F29-C must receive a validated outcome, not an untrusted model score or free-text winner. The existing account service and its pending human reviews are prerequisites, not an implied authorization to operate a public judge.

## Genuine Product Uncertainties

The cross-attire common-region rubric, anchor examples, draw band, pose adaptations, and subgroup quality bar need human calibration. It is not yet established that allowed tops preserve enough evidence for this fixed comparison, or that a candidate model can distinguish real muscle separation from lighting and fabric consistently enough for ranked use. Narrowing common evidence does not remove the broader subjectivity or objectification risk of a physique ladder.

The actual stable Sol release identity, selected reasoning setting, quality and cost tradeoff against Astra, and end-to-end timing remain production evaluation decisions. The five-second target has not been measured, and provider support for images and structured outputs is not evidence that any of these requirements have passed. No App Store approval likelihood follows from a successful model evaluation.

## References

- [F29 parent contract](../DOCKS.md), including the shared match lifecycle and proposed numerical rules.
- [F29-A page and match flow](../F29-A-page-and-match-flow/DOCKS.md), [F29-C rating and matchmaking](../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety and reporting](../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy and service operation](../F29-E-privacy-and-service-operation/DOCKS.md).
- [OpenAI GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol): the current source for supported image input, structured outputs, unavailable fine-tuning, and the advertised model identifier; not a physique evaluation result.
- [OpenAI model-selection guidance](https://developers.openai.com/api/docs/guides/model-selection#when-to-consider-gpt-61-sol): task-specific Sol-versus-Astra evaluation and quality, latency, and cost tradeoffs.
- [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): current guidance for perceivable states, larger text, assistive interaction, and reduced motion; not evidence of an implemented accessibility audit.
- [Apple HIG — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy): resource minimization, transparency, and on-device processing where possible; not a guarantee about any processor's retention.
