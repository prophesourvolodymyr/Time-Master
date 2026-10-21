# F29-E — Privacy and Service Operation

## Purpose and Status

This child of [Physique Duels](../DOCKS.md) owns permissions, informed data-sharing choices, capture privacy, access boundaries, data lifetime, deletion, model-provider operation, cost planning, and honest failure states. It is a promoted product specification, not an implementation report or a claim of measured model quality, latency, security, or App Store approval. The parent's explicitly identified user decisions are preserved. The detailed consent behavior, retention schedules, service limits, and numerical scenarios below are proposed defaults for human product, privacy, and operational review.

The competition judges physique from consented images. It does not secretly replace physique with exercise performance, infer health or identity from a body, or require more exposure to obtain a score. Its privacy explanation must be specific to that image-based activity. [F29-D](../F29-D-safety-and-reporting/DOCKS.md) owns attire, content screening, reports, blocks, and safety decisions; [F29-A](../F29-A-page-and-match-flow/DOCKS.md) owns the visible journey; [F29-B](../F29-B-ai-judging-and-metrics/DOCKS.md) and [F29-C](../F29-C-physique-rating-and-matchmaking/DOCKS.md) own judging and authoritative competitive records.

## Keep the Existing Exercise Privacy Promise True

TimeMaster/Views/Ranked/RankedMatchPreparationView.swift currently tells exercise-duel participants that only timestamped joint estimates are sent for scoring, images and video stay on the device, and opponents never see them. Local Practice similarly promises device-local images. Physique Duels must use a distinct image-sharing explanation and capture path. A general app update, camera permission already granted for exercise, or acceptance of exercise rules does not authorize physique image transfer.

Exercise preparation, practice, pose-vector evidence, exercise quotas, and exercise Elo retain their existing meaning. No shared camera component may silently begin uploading exercise frames because Physique is installed. Physique images are not inputs to an existing workout log, calorie estimate, HealthKit record, AI Coach conversation, or a public profile. The physique-only ladder and its independent allowance remain separate from exercise competition.

The participant's AI Coach provider choice, saved personal API keys, or subscription to a general chat product does not select the ranked judge or pay for the service's model calls. Both participants receive the same service-approved judging policy and model version for that match. There is no client-side provider switch, personal prompt, model reroll, or editable earned rating.

## Distinct Permissions and Choices

Camera permission, adult eligibility, accepted rules, legal data-sharing consent, optional public listing, and optional export are different decisions. A system camera alert cannot authorize third-party AI processing or show an opponent the person's body. A privacy policy link is necessary context, not a substitute for an explicit decision at the relevant point.

| Decision | What the person is told and chooses | Refusal or later withdrawal |
| --- | --- | --- |
| Adult eligibility and attire declaration | Private adult eligibility and the applicable attire rule, without age, sex, or gender inference from images | No rated physique capture or opponent-still viewing if ineligible; unrelated available app features remain accessible |
| Physique competition rules | Three matched poses, the common-region physique rubric, separate Elo, real timing, attire, moderation, and valid-forfeit consequences | No physique pairing until accepted; no consent inferred from opening the page |
| System camera permission | The camera supplies local preview and guided still capture for this feature | Explain denied, restricted, or unavailable camera access; no library-image or prerecorded rated substitute |
| Hosted AI and safety processing | The named service and processors receive necessary face-obscured stills and limited judging context for the described purpose, with precise retention and region disclosures | Decline before any upload; withdraw further processing through feature privacy controls without disabling unrelated features |
| Paired-opponent still access | The matched participant may intentionally view approved selected stills only after a valid AI-judged win, loss, or draw, during the twenty-four-hour window; screenshots or external recording cannot be prevented absolutely | Required for this proposed rated mode, but not bundled into unrelated app use. Refusal prevents this mode; withdrawal removes future authorized access to the person's shared stills |
| Public standings listing | An explicit physique-specific choice allows the permitted identity, rating, and placement to appear publicly; no body media or private eligibility declaration is included | An unlisted participant may still earn the same Elo, with no public standings position. Changing this choice is not a rating reset |
| Optional result export | A deliberate system share action exports a previewed card containing only the sharing person's permitted identity and own result | No automatic export, Photos saving, or loss of functionality if declined; cancelling the share does not undo the match |

Hosted AI and paired-opponent sharing use separate, legible affirmative choices even where both are necessary for this particular rated mode. They are not preselected, disguised as navigation, accepted by a countdown, or buried inside a single broad terms checkbox. Explain before Find opponent that refusing required sharing means no rated Physique Duel, not that all Tmax use is forbidden. There is no unannounced private rated variant, device-local fake opponent, or local Elo fallback.

### What informed sharing must disclose

Before the first transfer, and before accepting a materially changed sharing policy, the person can read:

- What is collected: selected stills and any necessary protected candidates after local face obscuring, limited match context, rubric-relative scores, and moderation or report information when relevant.
- Why each recipient needs it: service eligibility and safety, one paired AI judgement, authorized final result and history, limited counterpart still access, and narrowly scoped human case review.
- The operator and named model and moderation processors, their actual permitted purposes, and any relevant cross-border processing or residence arrangements. A general reference to artificial intelligence is insufficient.
- What the opponent can see, when they can see it, and what cannot be made copy-proof once viewed.
- App-controlled twenty-four-hour raw-media expiry, the bounded benign-report exception, legal or urgent-safety exceptions, and separate processor logs, application state, and caching behavior.
- How to decline, withdraw future access, remove images, request account deletion, report content, and reach the operator. App-controlled deletion cannot recall a screenshot or erase a processor's independently applicable legal preservation duty.
- That physique scores are subjective competition judgements, not measurements, diagnoses, identity verification, or accuracy guarantees.

The app records the actual choice and the policy version for the signed-in account and active match without turning private declarations into profile data. Collect only the eligibility detail needed; this specification does not invent full birth-date, sex-marker, government-ID, or face-verification requirements. The scoring model does not need the person's account name, email, birth date, or gender. A safety check can receive the applicable attire rule without receiving a public identity or inferring sex from the image.

### Refusal, withdrawal, and reconsent by stage

Before Go, declining or withdrawing required physique sharing cancels preparation or pairing, stops further transfers, releases a reserved allowance slot, and changes no Elo. Keep a clear route back to the lobby or the rest of the app. Do not repeatedly launch the system permission alert or pressure the person with a streak, countdown, or fake forfeiture warning before a match has started.

After Go, withdrawing processing stops new capture and new transfers immediately. The person is told that a request already accepted by a processor may not be retractable. An intentional exit from an otherwise eligible match follows the parent's explicit confirmed-forfeit rule; a service-established invalid, safety-aborted, or unavailable-service match instead remains no-contest. Withdrawal is not a free-win mechanism, and a person is not forced to keep posing or sharing while asking for privacy help. The confirmation states the actual competitive consequence without withholding the privacy action.

Withdrawing only paired-opponent image access after Go immediately removes future authorized viewing of the person's stills, including from already issued links. It is not itself a forfeit, cancellation, new match type, or rating reversal. Separately authorized AI processing and otherwise valid participation can continue; any final gallery still obeys each image owner's current permission. Before Go, that same missing required sharing choice prevents or cancels entry as described above. No withdrawal action restores access to someone else's images, recalls an external copy, or permits a new unconsented transfer.

After finalization, withdrawal does not reroll a score, replace a valid result, or reset earned Elo. Removing the person's shared images revokes counterpart access and removes ordinary app-controlled media subject to any valid hold. It cannot retrieve copies another person already made. The other participant sees Sharing withdrawn or another accurate unavailable-media placeholder, not a new allegation or a hidden image replacement. Their own lawful result record does not depend on perpetual access to the withdrawn photo.

A person can inspect, change, or withdraw choices in the feature's Privacy and sharing area, with relevant links from capture and result details. Signing out is not a substitute for withdrawal or account deletion. Reconsent applies to future authorized use; it does not automatically restore old removed galleries, reset the original expiry clock, resend historical images, or reopen a completed match.

Declining physique sharing does not revoke exercise consent or block schedules, local training, or unrelated account features. Revoking the operating system's app-wide camera permission can naturally affect other camera-dependent features; this limitation must be stated honestly rather than claiming all camera flows will remain usable. Noncamera features remain available according to their own requirements.

## Camera and Device Privacy Lifecycle

Request system camera permission only when the person deliberately enters camera preparation. The purpose explanation describes guided capture plainly. Do not request it on general app launch. The feature's separately declineable legal sharing choices are not a counterfeit system permission alert. An ordinary system-permission pre-alert, if necessary, follows Apple's current guidance and makes clear that Continue opens the real alert; it does not imitate an Allow button or tell the person which system choice to make.

The local preview is visibly identified as Camera active. System capture indicators remain intact. There is no silent continuous video recording, hidden background camera, or live opponent camera stream. Select only the still evidence needed for the named poses and checks. Capture activity is not concealed behind a loading sheet, safety form, or result screen, and Stop camera remains accessible.

The rated feature needs no microphone, Photos-library read access, location, contacts, or HealthKit permission. Do not open an audio connection, collect background sound, use a library picker as a rated fallback, save captures to Photos automatically, or geolocate someone to judge their body. Optional result-card export uses the system share experience without requiring general Photos access. Granting an unrelated permission is never a condition for taking a physique still. A physique session does not automatically record a workout, calories, movement duration, or HealthKit measurement.

### Face obscuring and background minimization

Face areas are obscured locally by default before every candidate or selected still leaves the capturing device, on iPhone and Mac alike. The exact redacted representation is previewed, so the person understands what the protected service, processors, and permitted counterpart may later receive. A redaction failure stops that transfer and offers recapture or cancellation. Uploading the original because masking timed out or failed is not permitted. The local original is transient processing material, not a separate remotely stored face archive.

Privacy masking is not prohibited image editing. It must not alter the scored body regions or conceal an additional person. A second person or bystander invalidates the capture rather than being repaired by face masking. Encourage a plain private background, removal of identifying objects, and checking mirrors before taking a still. Do not add face recognition, identity embeddings, a face-match step, or photographic age, sex, or gender estimation.

Masking cannot guarantee anonymity. Tattoos, body features, clothing, reflections, the room, and the paired public identity can identify a person. Do not label the image anonymous or promise that every identifying clue has been removed. Remove unnecessary embedded metadata from transmitted stills; the app does not need a precise capture location or a camera's personal metadata to judge physique.

### Stop, background, app switch, and return

Stopping capture, leaving the capture surface, locking the device, receiving an interruption, or moving the app into the background stops camera acquisition immediately. The app-switcher surface obscures the camera, body stills, private report text, and sensitive account details rather than leaving a readable last frame. Decorative animation also pauses. A privacy cover is not a claim that the operating system can prohibit every screenshot or external recording.

Returning does not silently take another still or upload an unreviewed original. If the same match is still eligible, the person sees its real stage and can explicitly resume the permitted capture. The twenty-second reconnect grace does not restart the ninety-second capture deadline, reset retakes, or consume another allowance slot. When valid participation cannot be restored, the service finalizes no-contest under the shared contract rather than awarding a physique win from absence.

If both final pose sets were already received, judging may continue on the trusted service while the app is backgrounded; no further camera activity is needed. Returning fetches the authoritative result. Closing a result does not alter it. If the client is offline, it must distinguish Awaiting confirmed result from a confirmed no-contest rather than inventing local finality. An intentional confirmed forfeit remains different from an involuntary interruption.

## What Data Goes Where

| Data | Intended recipient and purpose | Minimization and display boundary |
| --- | --- | --- |
| Live camera preview and transient original still | Device only for framing, capture, and privacy treatment | No live transfer or continuous video archive; discard unnecessary originals and failed local captures |
| Face-obscured candidates needed for a protected check | Trusted service and any specifically disclosed safety processor | No opponent display; no routine upload of every preview frame; dispose of superseded or unnecessary candidates promptly |
| Accepted six-still pose set | Trusted service and the disclosed image judge for one paired comparison | Three poses per person, neutral participant labels, fixed judging context, no account credentials or general app history |
| Private adult and attire eligibility | Trusted participation and safety controls | Only necessary declarations; never public, never inferred from photographs, and not appearance-score inputs |
| Pair identity, physique rating, readiness, and stage | The authenticated matched participant as needed | No exercise rating, private declarations, raw face, contact details, live video, or chat |
| Validated category scores, totals, outcome, model-policy version, and rating history | The participants' authorized result and history; trusted competition records | Subjective scores labeled accurately; exact opponent private account data is not needed |
| Approved selected stills after a valid AI-judged result | Only the two authenticated participants, intentionally opened under prior consent | No gallery for forfeits or no-contests; twenty-four-hour window, report/hide controls, and current access checks |
| Public standings data | Other users only when the account's explicit public-listing choice permits it | Permitted identity and physique placement, not body images, safety cases, or eligibility declarations |
| Optional country/region and legitimate public battle badges | Permitted paired identity and, only under public-listing consent, the public identity summary | Country is manually selected and self-declared; no GPS, IP, locale, or image inference. No private declarations, location history, or judge access. Local cosmetic previews cannot create earned ownership |
| Reports and appeals | Authorized case reviewers and narrowly necessary legal-safety personnel | Existing content references, safe text, minimum relevant lawful evidence; no opponent access to the case package |
| Service diagnostics and usage totals | Authorized operation of the service | Minimal identifiers, status, timing, and cost information; no raw body images, image-bearing screen replay, secret links, full sensitive prompts, or personal API keys in routine logs |
| Optional exported result card | The destination the person deliberately chooses in the system share flow | Previewed own identity and own result only; no pose media, opponent-private information, or automatic posting |

The app's permitted counterpart gallery is not a public bucket, a spectator feed, or an export feature. Notifications can say that a result or case update is available, but do not embed body thumbnails, private report descriptions, or unconsented opponent details. Screen analytics and crash tooling must not record private capture or report surfaces as image-bearing session replay. Ordinary service diagnostics are not permission to collect a second hidden media archive.

## Authentication, Access, and Secret Boundaries

The existing account and authenticated Rust service are the intended foundation, subject to their own human review and authorized public operation. A signed-in client can act only as its own account, within its actual match and consent state. Access to private results, images, cases, blocks, and deletion status requires the proper account and current authorization. Knowing a match reference or possessing an old copied image link is not permission to view someone else's data.

Counterpart still access requires all of the following at the time of viewing: the person is one of the pair, the result is a valid AI-judged win/loss/draw, both accepted sets passed the required checks, the relevant sharing remains authorized, no block or safety restriction prevents access, and the media has not expired or been removed. A thumbnail, cached view, notification, another device, or previously issued link cannot bypass those conditions. Signing out or switching accounts clears the prior account's private visible cache. A failed access check shows a safe unavailable state, not another account's cached photo.

The service, not the client or model, owns eligibility, accepted evidence, timing, allowance accounting, authoritative finalization, and Elo. Repeated submission, a restored screen, or a modified client cannot create a second outcome or substitute a chosen image archive. The model's numerical response is an input to service validation, not authorization to publish content or change a rating.

Provider credentials stay with the trusted operator's service. Do not place an OpenAI API key in the iOS app, a client-visible setting, a repository, image link, log, report, or support reply. Do not ask participants to paste their personal keys into a ranked flow. Operator access must be limited to the work and account scope required; compromised or unavailable credentials cause a safe service-unavailable state and operator remediation, not disclosure of the secret or a client-side bypass. OpenAI's key-safety guidance explicitly advises routing mobile requests through a backend rather than exposing keys in the mobile app.

Media is protected in transit and at rest under the operator's reviewed security practices. This is not an end-to-end-encryption claim: the authorized service, relevant processors, and narrowly authorized case reviewers must be able to process the evidence for the disclosed purposes. Human access is case-bound, limited, and accountable; a developer or support role does not receive unrestricted browsing of participants' bodies. Report evidence is never a general debugging fixture or training folder.

### Backend is not the same as a GPU server

A trusted backend is required for ranked authority, private access, eligibility, media lifetime, cases, costs, and one final result. A dedicated self-hosted GPU is not a launch requirement when a managed provider performs the image analysis. The existence of an account server does not prove that protected image storage, model access, deletion, or human moderation is already deployed. Public participation requires the actual authorized service and safeguards, not an undocumented developer machine or a client-only result.

## Model Choice, Provider Terms, and Change Consent

GPT-6.1 Sol is the current starting candidate, not a proven physique judge. Its current model documentation lists text and image input, text output, reasoning, and structured-output support. It does not establish competitive fairness, bodybuilding expertise, accuracy, safety clearance, or a fixed response time. A structured answer can still be wrong, unsafe, or unusable. F29-B owns the rubric and quality limitations; the service must withhold rated outcomes when those requirements fail.

One match uses one approved judging policy and model version for both participants. No unnoticed provider substitution occurs after consent or midway through a match. A materially different processor, purpose, retention condition, region arrangement, or sharing recipient requires updated disclosure and affirmative permission before sending new images under that arrangement. If consent is missing, future pairing waits; unrelated app use continues. A model or policy change that does not change the recipient still needs a truthful version label and an explanation of material judging changes, not an unannounced rewrite of old results.

An outage does not authorize forwarding images to a different vendor, using the player's AI Coach configuration, switching to a local competitive judge, or repeatedly rerolling until one answer wins. If the approved path cannot complete safely within the deadline, the match is no-contest. Reconsent cannot retroactively authorize a transfer that already occurred.

### OpenAI training and retention are separate questions

OpenAI's current API data guide says API data is not used to train or improve models unless the customer explicitly opts in. The proposed service does not opt participants' body images or reports into such sharing. This is different from promising no provider storage or no possible authorized human review.

The same guide describes several separate retention surfaces:

- Default abuse-monitoring logs may contain prompts, responses, derived classifier information, and other customer content. They are ordinarily retained for up to thirty days, with longer retention where required by law or reasonably necessary for protection from harm.
- Endpoint application state is separate from abuse logs. The Responses service ordinarily has a thirty-day application-state period by default, and the guide describes retention of stored responses for at least thirty days. Other features can have other lifetimes, including storage until deletion. The actual chosen service and storage settings must be disclosed; the app's own twenty-four-hour deletion does not erase this state automatically.
- Prompt caching may retain encrypted model-processing state on provider infrastructure for up to twenty-four hours under the documented conditions. It is not the same thing as the app's opponent gallery or an operator-controlled raw-image copy.
- Modified Abuse Monitoring and Zero Data Retention require provider approval and have endpoint, model, and feature limitations. The operator cannot claim either simply because it intends to delete its own images quickly. Provider-documented private-retention and safety exceptions also mean those labels are not a universal promise of no retention or review.
- Image and file inputs are scanned for potential child sexual abuse material. The provider says flagged images may be retained for manual review even where Zero Data Retention or Modified Abuse Monitoring is enabled. This must not be disguised as an ordinary app report hold or an anonymity guarantee.

The proposed principle is the least-retaining supported processing arrangement appropriate to the task, with unnecessary persistent provider state avoided. Before real participation, the operator must identify the actual endpoint or service, selected model, retention settings and contractual controls, image exceptions, applicable regions, and any stored-file lifetime in the privacy notice. These are disclosure facts about the authorized service, not a deployment recipe. If the operator cannot truthfully state the actual processor behavior, sharing consent is not ready and rated uploads remain unavailable. Do not say that everything is deleted everywhere in twenty-four hours or that disabling one storage option removes abuse logs, caches, legal exceptions, or already copied counterpart media.

Sol's documentation currently describes US and EU data-residency support, including Fast and Ultrafast modes, subject to the data guide's eligibility and processing conditions. Support in documentation is not proof the operator has enabled a region, obtained necessary image-processing approval, or confined every category of service metadata there. The privacy notice must describe actual processing and storage, including lawful cross-border transfers, rather than treating EU support or an EU user as automatic EU-only retention.

### Gemini is not an assumed fallback for a mixed-age app

The current Gemini API Additional Terms require users of the APIs to be eighteen or older and prohibit API clients directed toward or likely to be accessed by people under eighteen. A mixed-age Tmax app cannot assume that gating only this page makes Gemini contractually allowed. Paid access does not remove that client-age restriction. Any proposed future Gemini use requires review of the actual client, access, regions, contractual basis, and privacy choices rather than an automatic fallback switch.

The same terms say not to submit sensitive, confidential, or personal information to Unpaid Services, and describe product-improvement use and possible human review of unpaid-service content, with specified regional differences. Personal physique photographs are not an appropriate free-tier experiment. Paid-service data terms differ, but are not blanket permission to send these images or bypass the age restriction. No fallback or cost comparison in this specification authorizes using Gemini for personal images.

### No hidden training or research

Launch behavior contains no developer training set, fine-tuning collection, marketing-photo reuse, sale of body images, or unannounced research reuse. Human moderation necessary to operate a reported case is disclosed service operation, not permission to build a body dataset. Necessary cost and reliability counts do not authorize storing photos in diagnostics or provider evaluation projects.

Future research, judging calibration involving retained participant images, or model-improvement participation would require a genuinely separate, voluntary, purpose-specific opt-in and any applicable ethics or legal review. Declining would not change ranked access, Elo, allowance, app features, or price. Such a research program is not part of the proposed launch behavior and is not implied by accepting a duel, filing a report, or having an anonymized-looking image. No historical images can be silently repurposed under a later consent screen.

## Fully Local Inference: Possible Technology, Not an Established Competition Mode

Image analysis can technically run entirely on a supported device using an appropriate model. Apple's current Foundation Models documentation describes on-device image understanding, and its image Attachment availability is currently iOS 27 and later. That is not a blanket image-input capability for every older Foundation Models installation or every device; Apple Intelligence hardware and model availability still matter. The framework can also access Private Cloud Compute or server models, so the framework's name alone is not proof that a particular analysis stayed local.

Core ML is another route for genuinely on-device image models and is not the same availability claim as the Foundation Models image Attachment. A suitable packaged or converted model can use device resources without sending the images to a hosted judge. This establishes technical possibility, not that a suitable physique-comparison model has been selected, runs within the target, is fair across supported devices and clothing, or is sufficiently resistant to client tampering for ranked play. GPT-6.1 Sol's hosted API availability is not proof that its model weights can be run locally.

The current proposed rated path is the consented hosted paired judgement. There is no claim that fully local judging is implemented, equivalent in quality, a privacy-preserving competitive fallback, or a selectable second judge within the same match. Even a future local inference path would still need trustworthy competition authority, policy, safety, access, and finalization; local computation alone does not make client-reported Elo valid. A local-only path must not be simulated by displaying invented competitive results during a provider outage.

## App-Controlled Data Lifetime

In this section, raw media means the captured pose-image content, including the face-obscured stills actually transmitted and their thumbnails, crops, or other viewable derivatives. It does not mean that an unmasked original is uploaded. Model scores, result history, private declarations, and case records are different data families and must not be described as images simply to blur their retention.

| Data family | Proposed lifetime and access consequence |
| --- | --- |
| Live preview, failed local captures, and transient unmasked original | Device-local only, discarded when no longer needed for the current preview, masking, or chosen capture; stop and clear unnecessary buffers on exit or interruption |
| Superseded candidates and unnecessary retakes | Dispose of promptly once no longer required for the current protected check; not a permanent archive of attempts and never an opponent gallery |
| Selected pose images and ordinary viewable derivatives | No later than twenty-four hours after authoritative match finalization, whether the terminal state is judged, forfeit, or no-contest; earlier deletion or access withdrawal takes precedence where appropriate |
| Rejected or orphaned service upload with no usable final record | Dispose of as soon as unnecessary and no later than twenty-four hours after receipt absent a specific lawful exception; a missing finalization must not create indefinite storage |
| Necessary existing lawful evidence for a benign submitted report or dispute | At most thirty days after the originating report is received, and less when no longer needed. Duplicates, additional comments, appeals, and review delays do not restart the clock |
| Text-only unsent report draft | Protected on the current signed-in device for at most twenty-four hours, or until discard or sign-out if earlier; no body-photo cache or report hold is created |
| Score, outcome, Elo, version, and minimal match-history records | Available while the account and lawful history purpose remain; do not require keeping images. Account deletion removes associated personal data except a properly justified legal retention need |
| Optional country/region and battle-badge ownership | Country remains editable or removable at any time and is not archived as location history; legitimate badge facts follow the effective competition record. Clear identifying presentation on deletion under the same account and counterpart-history limits; retain only separately justified minimal record facts |
| Ordinary case metadata and correspondence | Purpose-limited case handling, with a proposed maximum of ninety days after closure for routine personal case records. Minimal enforcement information may remain for the active restriction and up to ninety days afterward where lawful and necessary, rather than retaining the media |
| App-controlled media in local caches or disaster-recovery copies | The same media expiry and revocation rules apply. Raw pose media is excluded from ordinary long-lived backups; a backup must not silently extend the twenty-four-hour image promise |
| Protected nonmedia backups after deletion | Proposed maximum thirty-day expiry, inaccessible through the product during that interval; deletion decisions must be applied before any restored service exposes records |
| Specific legal or urgent-safety preservation | Only the required information, protected access, a documented basis and scope, and review or release according to the applicable duty; not a routine unlimited report exception |
| Processor copies, abuse logs, application state, and model caching | The actual separately disclosed provider arrangements and exceptions, not an invented extension of the app-controlled schedule |

The twenty-four-hour gallery window starts at service finalization, not at first viewing, the next app launch, or the latest device download. Opening, hiding, blocking, exporting a result card, receiving a notification, or starting an appeal does not renew it. The expiry is account- and match-consistent across devices. A lawful report hold permits only restricted case review, not continued opponent viewing after ordinary expiry. Forfeits and no-contests have no counterpart gallery even during ordinary app-controlled retention.

A report filed while media still exists may preserve only the minimum relevant lawful evidence. If media has already expired or was lawfully deleted, report intake can use remaining match or text context but cannot restore it from a hidden archive, another participant's cache, or a provider solely to manufacture evidence. Neither a draft report nor a support message that has not been received by the authorized service promises preservation.

Unlawful or suspected exploitative material is not retained or distributed as an ordinary thirty-day report attachment. Follow F29-D's restricted legal-safety handling, remove normal participant access, and never ask a person to download, forward, screenshot, or reupload it. A valid legal preservation duty can limit deletion, but must not become an unexplained hold on every image or account. Routine evidence and unlawful-content handling are separate.

### Access expiry is not just a visual timer

At expiry, deletion, safety removal, block, or sharing withdrawal, the app and service prevent further ordinary authorized access. A copied link, stale thumbnail, another signed-in device, or restored backup must not reexpose unavailable media. Local image-bearing caches are cleared or made unavailable under the same rules. Do not show an image and merely place an Expired badge on top of it.

The result instead contains a specific placeholder while preserving whatever nonmedia outcome is still authorized. Media expired, Removed for safety, Sharing withdrawn, Hidden by you, and Blocked player describe different conditions. None is a prompt to generate or request a replacement photo. Where another person already made an external copy, the app explains its limits and provides a privacy or misuse-report route; it does not promise remote deletion of that copy.

## Deletion and Other Privacy Requests

The feature offers a direct way to remove the person's ordinary shared pose images and withdraw future sharing, without requiring deletion of the whole account. Explain that this removes media access, not an earned rating or an already valid competitive outcome. Hiding an opponent image is a different viewing choice. An unlisted profile is a different public-discovery choice. Merely removing Physique from the page catalog does not delete its records or alter its consent.

Because the app supports accounts, full account deletion must also be easy to initiate inside the app. It is not merely Sign out, pause, deactivate, remove a tab, or send support an email. A reasonable confirmation or reauthentication can use the existing account mechanism without inventing a new identity-document requirement. The explanation covers what will be removed, active-match effects, applicable lawful holds, the expected completion time, and any relevant separate billing cancellation. Deletion must not require the person to keep an unwanted active capture running or wait for an opponent's consent.

A proposed ordinary target is to complete app-controlled account deletion within seven calendar days after a confirmed request, sooner where possible and subject to any shorter applicable legal deadline. Ordinary raw-image expiry remains earlier and is not stretched to seven days. This is a planning target, not measured performance. State actual progress and revised expectations if a request legitimately needs longer. Protected nonmedia backup expiry and separately applicable processor retention are disclosed rather than being described as instant global erasure.

| Privacy request state | Consumer-facing consequence |
| --- | --- |
| Review before confirming | Clear scope, media and account consequences, active-match notice, and a conventional cancel action |
| Not sent or offline | Stop local capture and shield local media if requested, but label the service request Unsent or Not confirmed. Provide retry; do not claim remote deletion is complete |
| Received | A confirmed receipt and status link. Stop new affected transfers and revoke ordinary image access as authorized |
| In progress | Explain which ordinary work remains and the expected completion point without a fake percentage |
| Partially held | Identify the permitted categories and reason for a lawful limited hold as far as disclosure allows; continue deleting unrelated data rather than holding the entire account |
| Completed in active systems | Confirm removal, revoked sessions and media access, and any separately disclosed bounded backup or processor residual period |
| Cannot confirm or service unavailable | Preserve the request context safely, provide retry and operator contact, and show the actual last confirmed status |

Before Go, an acknowledged deletion or withdrawal cancels pairing without Elo change and releases the reservation. After Go, intentional confirmed departure is a valid forfeit only if the match remains otherwise eligible; a service-established safety, invalid-evidence, or service failure is no-contest. Requesting privacy help alone is not an automatic score appeal or a reason to delay deletion. A final result does not change simply because its media expires.

Account deletion removes associated personal images, identifying profile content, and other account data not lawfully required to remain. Remove the account from public standings and prevent new pairing and old private-session access. A counterpart may retain the minimum lawful nonidentifying match facts required to explain their own competition record, using a neutral Deleted account or Unavailable player label. Do not assume that a renamed or pseudonymous account record is legally anonymous, retain all of the deleted person's text indefinitely, or promise preservation of identifiable history merely because Elo exists. Any necessary retention basis and limits require the operator's review and truthful disclosure.

Report withdrawal, a pending scoring appeal, and operator convenience are not blanket reasons to refuse account deletion. A necessary legal or safety hold is tightly scoped, separated from ordinary participant access, and released when its basis ends. A deletion request can be completed for unheld data while a limited lawful record remains. An appeal does not restart an image hold, and a restored backup cannot resurrect deleted user content. Provider deletion and data-rights requests follow the actual processor arrangement without promising that the operator can undo mandatory provider safety preservation or another participant's screenshot.

## Public Privacy Information and Business Accountability

The operator's accessible in-app and App Store privacy policy must identify the responsible entity and contact, actual purposes and recipients, data families, eligibility declarations, lawful basis and relevant consent choices, sharing and copy risks, actual processor regions and retention, human-review access, deletion and withdrawal, and report or legal holds. The published support channel must reflect the actual staffed operation. A privacy label or a system camera purpose string is not a replacement for that policy or feature-specific consent.

App Privacy disclosures must reflect the actual collection, linkage, and purpose for the whole app and its partners. Photos or videos, account identifiers, gameplay content, applicable fitness or sensitive information, customer-support content, usage information, and diagnostics need assessment against Apple's definitions as actually collected. Do not categorically call every body photo biometric data, or claim no sensitive information can exist; assess what is actually processed and declared. These body images are linked to a ranked account even after face masking. Optional public listing does not make the private collection anonymous. The fact that a feature is adult-gated, optional, or uses a provider instead of storing a local server file does not automatically make its ongoing image collection optional to disclose.

The proposed launch purpose is feature operation and necessary safety, not advertising, data brokerage, cross-app tracking, body-based targeting, or user-profile reconstruction. Do not sell or repurpose physique photos or protected declarations, and do not add tracking consent as a prerequisite for duels. Update privacy disclosures when actual processor or collection practices change. Human policy and privacy review must cover the real business and processor arrangements rather than relying on this specification as a certification of legal compliance.

No paid physique plan, credit product, or full operating budget is established here. If digital access is later sold, the actual pricing and applicable store-payment and disclosure requirements need separate review. Reporting, blocking, withdrawal, deletion, and appeal access are not conditional on buying model tokens, subscribing, or supplying a personal provider key.

## Quota, Service Readiness, and Provider Outages

The parent's proposed account-wide allowance is ten started physique duels per rolling four hours, independent of exercise allowances, devices, public-listing status, and AI Coach use. Reserve one slot while pairing, consume it at Go, release it on pre-Go cancellation, and restore it once for service-failed, invalid, or moderation-aborted no-contest. A deliberate confirmed valid forfeit consumes the slot. The UI shows the actual remaining allowance and next available slot or labels the status unavailable; it does not reset the window at midnight or invent a local allowance after sign-out.

Account allowance is not provider quota. An operator's exhausted budget, unavailable model credentials, rate limit, provider outage, required moderation outage, or unavailable human safety operation is a service-readiness problem, not proof that a participant ran out of physique matches. If known before pairing, disable Find opponent with a specific safe explanation and retry or availability information when known. Do not reserve a user's slot indefinitely or collect images while the required approved service is known to be unavailable.

An affected started match resolves under the fixed deadline and no-contest rules, with no Elo and a single allowance restoration where applicable. Explain restored or pending allowance honestly; retries and multiple devices do not restore it several times. Service health can be unknown without asserting that the provider is offline. Do not disclose API keys, account balances, internal endpoints, or another person's data in consumer errors. Do not silently downgrade the evidence standard, forward the photos to an unconsented processor, or present a device-generated placeholder as a ranked judgement.

## Result Timing and Finality

The five-second final-pose-to-displayed-result goal is an unmeasured end-to-end UX target. It includes the relevant upload, service intake, safety checks, model queuing and reasoning, validation, finalization, and delivery—not just the first text token. If the other participant has not finished or an upload is not yet received, say Waiting for opponent or Uploading according to real state rather than claiming the judge is analyzing a complete pair.

At five seconds without a displayed result, give an honest slow status describing the actual remaining stage. Do not promise completion in the next second, display a fabricated analysis percentage, stream an unvalidated winner, or animate an unearned Elo award. A fast model tier, low token count, or first token arriving quickly does not establish a completed verdict, much less guaranteed subsecond result latency.

The proposed hard judgement deadline is thirty seconds after the service has received both final pose sets. It includes the work required to establish a valid final judgement; it does not begin thirty seconds after the provider eventually starts. If a valid complete result is unfinished or invalid at that deadline, the service records no-contest, no Elo change, and the applicable single allowance restoration. Partial or refused output, a missing category, invalid arithmetic, contradictory winner, unsafe explanation, or required safety service failure is not a successful result.

The service finalizes a match once. A late provider response cannot replace a no-contest, turn a forfeit into an image-judged result, or rate the match again. Repeated client requests, reconnection, and reopening history return the same authoritative state. A result finalized within the deadline can still reach an offline client later; late delivery to that device is different from a provider response that missed service finalization. The offline client neither invents a timeout result nor overwrites the true one when it reconnects. Authorized reviewed corrections are the separate transparent process owned by F29-C, not a background reroll.

Other proposed shared timing remains unchanged: search up to ninety seconds, a three-second countdown, ninety seconds for three poses with at most two retakes per pose, and a twenty-second reconnect grace that extends none of the existing deadlines. Report forms, consent screens, backgrounding, block confirmation, and processor retries do not create extra capture time.

## Illustrative Model-Cost Scenario

This is a planning example for one whole two-person duel with one paired judgement, not measured usage, a fixed model invoice, a per-player price, or the feature's total operating cost. The assumed billable usage is eight thousand input tokens in total, including all image billing and judging instructions, plus five hundred total billed output tokens including reasoning. Five hundred is a hypothetical billing assumption, not a demonstrated sufficient reasoning budget, guaranteed response length, or safe output cap. Sol supports reasoning; its current model documentation does not support disabling reasoning through the none or minimal effort settings.

At the currently documented Standard Sol rates of two US dollars per million input tokens and ten US dollars per million output tokens, the illustrative input costs 0.016 US dollars and output costs 0.005 US dollars. The whole paired judgement is therefore 0.021 US dollars. The current model documentation lists Fast at twice Standard pricing and Ultrafast at six times Standard pricing. Those are cost multipliers, not two-times or six-times speed guarantees.

| Identical hypothetical usage | One whole duel | 1,000 duels | 10,000 duels | 100,000 duels |
| --- | ---: | ---: | ---: | ---: |
| Standard | US$0.021 | US$21 | US$210 | US$2,100 |
| Fast, two-times Standard price | US$0.042 | US$42 | US$420 | US$4,200 |
| Ultrafast, six-times Standard price | US$0.126 | US$126 | US$1,260 | US$12,600 |

These figures assume the same one-call paired workload, no cache discount or cache-write charge, and no regional premium. Real image billing changes with the actual input and provider rules; reasoning, output length, and retries can change total tokens. Prices and tier availability can change. Fast's documentation describes shared Standard/Fast rate limits and potential downgrade under traffic ramp conditions; Ultrafast has separate limits. Neither guide guarantees this app's complete latency, fairness, or safety behavior.

Excluded costs include separate moderation and safety checks, invalid or repeated attempts, retries or duplicated provider work after uncertainty, hosting, authentication, database and media storage, bandwidth, backups, observability, customer support, human moderation and appeals, legal-safety operation, security work, taxes, and payment fees. No overall monthly or launch operating budget is supportable without real duel volume, the full processing workload, regional choices, staffing, and the authorized provider agreement. Cheap illustrative inference is not evidence that safe operation or a five-second verdict is proven.

## Operational and Privacy Failure States

| State | What the person sees and can do | Required consequence |
| --- | --- | --- |
| Service healthy and choices current | Normal preparation with current rules, allowance, and sharing summary | Only real eligible accounts can enter pairing |
| Sharing consent missing, withdrawn, or materially outdated | The specific missing choice with Read details, accept, or decline and leave | No new affected upload or pairing; unrelated features remain available |
| Age-ineligible or restricted | A private explanation, safety/support access, and return to the rest of the app | No photographic eligibility test or opponent-still access |
| Signed out or session expired | Sign in or recover the existing account; protected content is unavailable | No anonymous body upload, leaked prior-account cache, or invented match outcome |
| Camera not yet requested | Contextual explanation and action opening the system choice | No capture before actual permission |
| Camera denied or restricted | Settings when appropriate, a restrained explanation, and leave; Retry only when it can work | No repeated manipulative alerts or Photos/prerecorded rated substitute |
| Camera unavailable, busy, interrupted, or unsafe to continue | The real resource issue and safe stop/retry | Stop capture immediately; preserve only the eligible same match within real deadlines |
| Face redaction cannot complete | A privacy-specific capture failure with recapture or cancel | Do not transmit the original or describe masking as completed |
| Bystander, exposure, or required evidence rejected | Pose-specific safe reason, remaining permitted retake opportunity, and review access | No opponent display; unresolved invalid evidence is no-contest |
| Offline before Go | Offline status and retry or cancel | No local pairing; release or reconcile an existing reservation with the service |
| Upload interrupted or receipt unknown | Actual received-pose state, Not confirmed where needed, and retry for the same match | No silent second upload set, second match charge, or local verdict; do not extend capture time |
| Reconnecting after involuntary interruption | Same match and real remaining time within the twenty-second grace | No extra allowance consumption, reset timer, or additional retakes |
| App backgrounded during judging | Private app-switcher cover; on return, retrieve the real state | No background camera or unconsented new transfer; already accepted judging may finish |
| Account allowance exhausted | Actual next-slot information and the separate exercise boundary | No fabricated reset or use of exercise allowance |
| Provider or operator quota, credentials, cost control, or model access unavailable | Service currently unavailable, with retry or known return information | No borrowing personal keys, provider switch, local fake result, or rating from an unfinished call |
| Moderation or required privacy protection unavailable | Explain that safe participation is temporarily unavailable | Prevent new pairing or safely no-contest an affected active match; no fail-open display |
| Still processing at five seconds | Honest stage-based slow status with safe navigation | No fake percentage, guaranteed countdown, streamed verdict, or provisional Elo |
| Invalid/refused/unsafe output or thirty-second judgement deadline reached | Specific restrained no-contest reason and confirmed allowance consequence | No Elo, no invented scores, no forfeit/no-contest opponent gallery |
| Server state unavailable after a client timeout | Awaiting confirmed outcome, with retry and safe exit | Do not guess win, loss, draw, restored slot, or no-contest; reconcile the existing match when available |
| Late provider output after finalization | The existing final record remains | No second finalization or automatic rerating |
| Image hidden, reported, blocked, removed, withdrawn, or expired | A reason-specific placeholder and remaining permitted report or privacy actions | No cached or alternate-link bypass, regeneration, or implied scoring correction |
| Private record access denied | Safe unavailable state and appropriate account recovery or support | No data from another account and no confirmation of sensitive records to an unauthorized person |
| Report or appeal intake unavailable | Hide locally, keep only the bounded safe text draft, retry, and published contact or urgent-safety guidance | No false receipt, indefinite image retention, or requirement to attach unsafe media |
| Withdrawal or deletion service temporarily unreachable | Stop affected local capture and transfers, shield local media, show Unsent or Not confirmed, and offer retry | Do not promise remote revocation or erasure before acknowledgement; no new pairing under unresolved required privacy state |
| Deletion received, limited hold, or completed | Private truthful status and explanation of remaining lawful scope and periods | Revoke ordinary access, delete unheld data, and prevent restoration from old links or backups |

The service's inability to protect access, honor the stated retention, or provide required safety operation is a readiness failure, not permission to continue collecting while an issue is hidden. Existing history can remain readable to the extent authorized, with stale information labeled; report contacts and unrelated app functionality should not disappear with the judging service.

## Accessibility, Feedback, and Animation

Reuse existing native Tmax sheets, readable typography, labels, and action hierarchy. Privacy choices need explicit recipient and consequence text, large-text reflow, visible decline and return paths where applicable, and separate focusable actions for reading details and making a choice. Do not use a prechecked switch, tiny legal footnote, color-only status, or camera animation as evidence that consent was given.

VoiceOver and other assistive technologies can identify Camera active, Upload not confirmed, Sharing withdrawn, Media expired, report receipts, and deletion state without reading unsafe image descriptions or private text into a notification. Announce a meaningful change once without continually speaking an indeterminate spinner or every reconnect tick. Errors preserve valid text and move focus only when necessary for the person's current task. Return focus to the relevant safe control after a permission explanation, sheet, or image placeholder replaces content. Keyboard, Switch Control, Voice Control, and ordinary taps can reach privacy and safety actions without a precise gesture or long press.

Permission, retention, and deletion information remains available long enough to read; a toast is not the only record of a consequential decision. Optional haptics reinforce rather than replace visible status. Reduce Transparency uses opaque legible surfaces, including the privacy cover. Reduce Motion removes scaling, travel, and decorative repetition; concise status crossfades and ordinary native sheet behavior are enough. A camera stop, mask failure, access revocation, or unsafe-content hide takes effect immediately and never waits for an animation to finish. No loading or result animation asserts service progress or a rating award that has not been confirmed.

Native iPhone and macOS are equally required by the new [view contexts](../F29-A-page-and-match-flow/DOCKS.md) and [shared component family](../F29-G-native-ui-components/DOCKS.md). On Mac, inactive, minimized, locked, backgrounded, or interrupted capture stops and shields sensitive surfaces before decorative motion; restored windows reconcile the existing match instead of starting another session. One account cannot silently own two capture windows. Country, badges, names, timer, and score chrome are never burned into the clean face-obscured images sent for judging.

## File Ownership and Dependencies

- This DOCKS.md owns F29 permissions, privacy boundaries, data lifetime, provider facts, service failure consequences, and planning-cost assumptions. [The parent](../DOCKS.md) owns shared product decisions and timing.
- F29-A owns permission entry points, capture lifecycle, redacted previews, app-switch protection, result galleries, privacy controls, and accessible navigation. F29-D owns attire, contextual screening, reporting, restricted evidence, blocks, and human review. F29-B owns the accepted image contract and valid judgement. F29-C owns account-wide allowance accounting, pairing exclusions, authoritative finality, and competition-record corrections.
- Prospective TimeMaster/Views/Physique/, TimeMaster/Services/Physique/, and TimeMaster/Models/PhysiqueDuelModels.swift are the feature-owned native presentation, image-sharing, and state surfaces. They must not turn shared exercise-camera code into a hidden image uploader.
- TimeMaster/Views/Ranked/RankedMatchPreparationView.swift owns the existing visible joint-only exercise privacy explanation. Existing TimeMaster/Services/Ranked/, account/session behavior, and the authenticated Rust service provide integration patterns, not automatic approval of new image processing.
- ranked_server/src/ and ranked_server/schema.sql are the existing trusted authority and persistence surfaces for distinct physique records, protected media access, consent, cases, allowance, and finalization. Provider credentials and authorized case access belong to trusted operation, never to a public mobile setting.
- Existing account/profile surfaces own global account deletion and public identity boundaries. Physique-specific image removal, listing, and consent must remain distinguishable from global deletion, sign-out, and page removal.
- features/DOCKS.md registers the promoted product specification; CYCLES.md owns implementation and human-review status. Neither documentation placement nor an available model account proves production readiness.

Dependencies include an authorized persistent HTTPS service, real authenticated access, protected media and cache lifetime, reviewed consent and privacy notices, actual provider access with understood terms and retention, reliable finalization, and a staffed safety operation with published contact information. The other F29 areas constrain the same journey. Existing F28 outdoor work, route permission, HealthKit, microphone capture, and AI Coach key selection are not prerequisites for physique judging.

## Direct Primary Sources

Provider capabilities, prices, and terms below were consulted for the product context as of 21 October 2026 and must be rechecked when the actual service arrangement changes. They are not app runtime measurements or certifications.

- [OpenAI: Data controls in the platform](https://developers.openai.com/api/docs/guides/your-data), for training opt-in, abuse logs, application state, retention controls, prompt caching, image safety exceptions, and residency limits.
- [OpenAI: Best practices for API key safety](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety), especially the prohibition on exposing keys in mobile clients and the backend boundary.
- [GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol), for image input, text output, reasoning and structured-output support, current token rates, and Fast/Ultrafast price multipliers; not evidence of physique-judging quality.
- [OpenAI: Fast mode](https://developers.openai.com/api/docs/guides/fast-mode), for processing behavior, availability and rate-limit qualifications; not an end-to-end app latency guarantee.
- [OpenAI: Ultrafast mode](https://developers.openai.com/api/docs/guides/ultrafast-mode), for availability, separate limits, and processing qualifications; not a six-times speed guarantee.
- [Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms), especially API-client age restrictions, sensitive information in Unpaid Services, and separate paid-service data terms.
- [Apple: Foundation Models](https://developer.apple.com/documentation/foundationmodels), for on-device and cloud model distinctions and supported-device requirements.
- [Apple: Foundation Models Attachment](https://developer.apple.com/documentation/foundationmodels/attachment), for current iOS 27-and-later image-attachment availability, not a claim about older OS image support.
- [Apple: Core ML](https://developer.apple.com/documentation/coreml), for another on-device image-inference route, not proof of a validated competition judge.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), especially 1.2, 1.6, 2.5.14, 5.1.1, 5.1.2, and the fitness-data protections in 5.1.3.
- [Apple: App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/), for actual data collection, linkage, partners, purposes, and disclosure responsibilities.
- [Apple: Offering account deletion in your app](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/), for in-app initiation, associated-data deletion, reasonable confirmation, and truthful completion or legal-retention information.
- [Apple HIG: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), for contextual permissions, minimization, transparency, and system-alert distinctions.
- [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), for legible, perceivable, adaptable controls and restrained motion.
