# F29-A-b — Account Entry and Protected Return

## Purpose and Ownership

This area owns the Physique account-entry wrapper, the reason an account is needed, and the protected return to the action that requested it. The [page and match-flow parent](../DOCKS.md) owns the journey around it. The [F29 contract](../../DOCKS.md) and the safety and privacy owners determine what a verified account may do.

One Tmax account is used. Physique does not create a second login, password database, account provider, identity-verification claim, or parallel recovery flow. Sign in, Create account, confirmation email, password recovery, password change, account switching, sign-out, legacy exercise-account linking, and account deletion use the existing shared account surfaces and their actual services. Signing in does not accept Physique rules, establish adulthood, authorize image sharing, publish a local profile photo, or award a rating or badge.

This canvas specifies a native iPhone and native macOS account checkpoint. It does not authorize a production mock or an independently released view before the shared account, Physique access, match recovery, and private-cache contracts have been implemented and human-reviewed.

## Chosen Composition and Tradeoffs

The composition is a contextual sleeve around the existing Tmax Account page, not an illustrated login landing page. The shared page keeps its single main title, persistent field labels, actual forms, account-security controls, and native navigation. A compact Physique context block appears at the beginning of that page's existing scrollable content. It is not a second nested scroll view, floating modal inside a modal, new tab, or second navigation title.

The context block has a narrow orange leading accent, a small person-outline symbol, the caption Physique, and one bold current instruction. Its supporting sentence explains only the current decision. Near-black background, the existing dark elevated surface, white primary text, readable secondary text, Inter typography, shared spacing, and the shared action styles match the rest of Tmax. The accent is sports framing, not a verification seal or earned badge. There is no stock athlete, body photograph, medal, public avatar, or invented player in the account form.

The default instruction is Sign in to compete. The supporting sentence is Your Tmax account. Separate Physique Elo. Existing shared account information remains available below it; a short clarification makes clear that signing in alone sends no physique photos and that Physique has separate sharing consent. That clarification does not rewrite the existing exercise promise that camera images stay local in exercise duels.

A full-screen custom gateway would add a decision before the real form and would duplicate authentication errors. An automatic return immediately on any token change could interrupt password recovery or carry an old account's intent into a new account. This design instead presents the real form directly and makes Continue to Physique explicit after identity and access have been resolved. The extra deliberate action is the privacy and navigation tradeoff; it never repeats sign-in or starts matchmaking.

No permanent inspector, second account column, promotional sidebar, or decorative animation loop is needed. Secondary details remain in the existing account sections or their already-owned destinations. A denied or restricted state uses the same checkpoint block, not another unowned screen.

## Visible Copy and Action Hierarchy

| Situation | Context instruction and essential explanation | Main available action |
| --- | --- | --- |
| Account required for entry | Sign in to compete. Your Tmax account. Separate Physique Elo. | The existing Sign in or Create account action in the shared form |
| Private history or detail requested | Sign in to continue. Your Physique history is private. | Existing shared sign-in action |
| Local account restoration | Restoring account… No previous-account content is visible. | Close; no enabled participation action |
| Identity restored, Physique access unresolved | Checking Physique access… | Close; the real activity state, not another sign-in submission |
| Session cannot be renewed | Sign in again. Your session could not be renewed. | Existing shared sign-in action; Forgot password? remains available |
| Authenticated but offline | Physique is offline. Account access could not be checked. | Retry and Close; no misleading expired-session claim |
| Account and requested access resolved | Ready for Physique. The context names the safe destination being resumed. | Continue to Physique, or Continue to lobby when the old destination cannot follow this account |
| Verification email required | Confirm your email. Open the latest account email on this device. | Existing resend or sign-in controls; no Continue while no actual session exists |
| Verified password-reset link | Reset password. Choose a new password before returning. | Existing Save new password action |
| Physique-only restriction | Physique unavailable. The private service-supplied scope and duration follow when known. | View restriction or Appeal through the safety owner's real route; Close remains available |
| Access failure without a known restriction | Can't check Physique access. | Retry; do not label an unexplained failure as a ban |
| Account changes during this checkpoint | Account changed. Continue with this account from the lobby. | Continue to lobby after the new identity and access are resolved |
| Local private-data removal fails | Private data unavailable. Device cleanup could not be completed. | Retry cleanup and account access; no exposure of the old cache |

The context instruction is not an additional large heading competing with Tmax Account. State explanations can wrap and grow. Error text is persistent until superseded by a real event or the person leaves; it is not a disappearing toast. Server-provided safe reasons may need more than one line. Concision never removes recovery instructions, restriction scope, active-match consequences, or necessary privacy distinctions.

Only the action relevant to the current step is primary. Before authentication, the shared form owns its primary action. After authentication and any required password recovery are complete, the wrapper owns Continue to Physique. Retry is not a second sign-in request. It rechecks the failed account-access or cleanup operation that the displayed error names.

## Native iPhone Composition

The checkpoint is a normal account sheet in the initiating Physique navigation context, with one native navigation stack and the existing Tmax Account title. It uses a tall presentation with the shared scrollable page rather than a small detent that hides the form. The native Close action stays reachable. There is no custom back gesture, imitation system alert, or battle artwork behind translucent password fields.

The Physique context block precedes the existing shared account content in the same scroll region. The Sign in and Create account selector, Email, Password, optional Display name, actual provider section, recovery controls, errors, and existing security sections keep their shared order and semantics. The wrapper does not replace them with icon-only inputs. Authentication fields keep their actual password-manager content hints, email keyboard, secure entry, paste, selection, and submission behavior.

When returning is permitted, Continue to Physique occupies a measured bottom safe-area action region using the existing primary-action convention. It is not duplicated beside an active Sign in or Save new password button. The action region, keyboard, navigation placement, and any existing floating app controls contribute their real bounds; there is no guessed screen height or fixed keyboard spacer. At very large text sizes its label wraps without reducing the touch target or hiding Close. The form scrolls to the focused field and nearby error above the keyboard. The context block can scroll away; it is not a tall permanently pinned explanation.

Short phones, landscape, and accessibility text use the same vertical structure. The person can scroll through every field and recovery instruction. Content is not scaled down, horizontally clipped, or limited to a smaller accessibility category to make the original sheet height fit. Primary and safety interaction areas retain the existing forty-four-point iPhone convention.

Closing an idle checkpoint cancels the deferred request, not the account itself. Drag dismissal follows the shared account host's actual busy-operation rules. Dismissing a keyboard or a system password-manager presentation is not an instruction to close the checkpoint. External confirmation or reset links return through the existing verified application callback path and update this presentation rather than opening another account sheet on top of it.

## Native macOS Composition

The Mac experience is a native macOS 14-or-later sheet attached to the window that requested account access. It is not Catalyst, a web form, or a phone-sized composition centered in a fake device frame. The normal Tmax title bar, window controls, application menu, and existing commands remain intact.

The sheet uses a single readable account column. Its width follows the shared settings page's readable bounds and the available parent-window space; it does not grow email and password fields across an external display. The compact Physique context block and existing account sections share one vertical scroll area. At the existing 800-by-600 application minimum, the form, errors, recovery instructions, and controls remain reachable by scrolling without increasing the app-wide minimum. At laptop, large, full-screen, and external-display sizes, surrounding space grows rather than adding another account form or a decorative sidebar.

Close uses the native cancellation placement. Once allowed, Continue to Physique uses the native confirmation placement and Mac control density rather than a full-window phone-style button. Return is not assigned as a global default to that navigation action while a field or other semantic control owns input. Live resize reflows the existing content and preserves the focused field, text selection, and useful reading position. It does not recreate the sheet, reset the current authentication operation, or animate every resize measurement. Moving the window between displays does not renew a session or request camera access.

Tab and Shift-Tab follow the visual form order, with visible keyboard focus. The account mode selector, recovery actions, provider availability action, Close, and Continue are keyboard reachable. Native text editing, password-manager insertion, context menus, and clipboard shortcuts remain intact. Existing Command-N, Command-Shift-R, Command-comma, and Command-Option-O retain their app meanings; the account wrapper does not repurpose them. App commands that leave the current context follow the existing modal and match-lifecycle protections rather than creating another active duel.

Multiple Tmax windows share one actual account. Only one shared authentication operation and callback presentation may own a given operation. Opening another checkpoint does not start a second browser authentication session, session refresh, match, allowance reservation, or camera. A nonowning window shows that an account operation is already in progress and does not offer a duplicate submission. It remains dismissible when dismissing that passive presentation cannot cancel the owning operation. Every window clears the old account's private visible state before any new account's content can appear.

The account wrapper never needs a camera, so it never requests Mac camera TCC, a microphone, or a file picker. Returning to camera preparation delegates to the camera owner. TCC denied, restricted, absent camera, unavailable external camera, and disconnected Continuity Camera remain that owner's distinct states. Successful sign-in is not successful camera preflight, and a camera problem is not an authentication failure. A denied or disconnected camera cannot be replaced by a photo library or rated file upload.

An inactive, hidden, minimized, or backgrounded window shields sensitive account content and pauses decorative work. The actual shared authentication request may finish under its existing lifecycle rules; it does not automatically queue, return to capture, or reactivate a camera. A system credential or browser authentication interaction is not treated as a voluntary match forfeit. On activation, the wrapper reflects the latest actual identity and access state before restoring sensitive content.

## Entry and Return Destinations

An account request remembers only the narrow intended destination and the initiating navigation context. Private destinations are bound to their actual stable account owner, not an email, handle, local profile name, or displayed badge. The return context contains no body image, password, authentication token, signed media URL, unrestricted external redirect, or copied report evidence.

| Request origin | Successful Continue with the rightful account | Cancellation, different account, or unavailable destination |
| --- | --- | --- |
| Lobby Account action | Return to the same Physique lobby and useful scroll position, refreshed from current permitted data | Remain in the safe lobby; switching resets account-owned content and reading positions |
| Find opponent while signed out | Continue to the next missing preparation requirement; no queue or allowance reservation is created by authentication | Return to the lobby; the person can browse rules and the local pose guide without an account |
| Private history list | Open this account's actual Physique history and restore a same-owner filter and position where still valid | A different account starts its own history cleanly; it does not inherit the previous account's rows or cursor |
| Particular saved match or result | Open the same authorized match's nonmedia detail using current service state | Return to the lobby with Match unavailable when authorization fails; do not disclose the former owner's opponent, outcome, or match date |
| Intentional pose viewer interrupted by authentication loss | Return only to the authorized result detail; View poses must be chosen again after current access, sharing, block, safety, and expiry checks | No automatic gallery restoration, stale thumbnail, copied-link fallback, or image reveal |
| Own report, appeal, or case | Return to the existing safety-owned destination only for the same authorized account and live case reference | Discard the private navigation target on account switch or sign-out; do not open the old owner's case |
| Text-only unsent report draft after an expired session | Restore only the same owner's still-permitted protected draft within its original lifetime; no automatic submission | Sign-out or account switch discards the draft; an expired or discarded draft is not recreated |
| Same account's interrupted active match | Resolve the canonical current match before offering the match owner's Resume action | A changed account cannot resume that match. A terminal match opens its actual nonmedia result, not capture |
| Verified confirmation or recovery link without a live Physique request | Stay in the existing shared account flow; no invented Physique destination | Ordinary shared account completion and dismissal; do not manufacture a return intent |

The intended action is an entry point, not a deferred mutation. Continue never automatically accepts rules, confirms adulthood, grants legal sharing consent, switches on a camera, takes a still, uploads a candidate, enters search, becomes Ready, submits poses, sends a report, or spends a slot. If the next requirement is already satisfied, the real page presents the next deliberate action.

A currently reserved or active match for the verified account takes precedence over a request to start another match. Continue exposes the existing match owner's recovery choice. One account has one canonical active Physique match across windows and devices. The wrapper does not clone a stage into another camera owner or select a fresh peer to make return look seamless.

Closing rather than choosing Continue clears the deferred request and returns to the originating safe surface. A completed sign-in remains a completed sign-in; Close does not sign the person out. If the source is no longer authorized, the safe destination is the Physique lobby. No return request from a closed window navigates a different window automatically. A new request supersedes a discarded one; delayed responses cannot resurrect it.

A return across an app relaunch may retain only a protected, account-bound destination reference supported by the reviewed foundation. If that reference is absent, invalid, or cannot be safely associated, the fallback is the actual lobby or canonical recoverable match entry, never a guessed private detail. Authentication callbacks have one verified owner; the wrapper does not add a second URL parser or infer recovery merely from a link's visible text.

## Actual Authentication and Recovery States

### Restoration is not authorization

First restoration reads the existing secure local account state. It can establish which account was last installed without proving that the service still accepts that session. During Restoring account, no former account's Physique metrics, badges, pose images, history, case text, public identity selection, or drafts are displayed. There is no invented Elo skeleton or anonymous opponent underneath a translucent cover.

If secure restoration yields no session, the real shared sign-in form becomes available. If it yields an identity, Checking Physique access resolves current service authorization, restriction scope, and any canonical match. A successful ordinary refresh stays in this state without asking for a password. An expired access token that can actually refresh is not presented as a sign-out.

No network connection, server unavailability, or secure-storage failure is mislabeled Session expired. Only an actual rejected or unrenewable authentication state asks for Sign in again. If stored credentials cannot be read securely, the checkpoint says Secure sign-in unavailable, offers the foundation's real retry and account access, and keeps the local app usable. It never recommends disabling Keychain, weakening HTTPS, or placing a password in preferences.

### Sign in and account creation

The shared email-and-password form remains the functional baseline. Existing persistent labels, secure fields, email normalization, Next and submission behavior, and password-manager integration are preserved. The wrapper never intercepts secure input, logs typed values, prevents paste, or asks for a second password copy for Physique.

Create account uses the actual shared fields and password policy, including the current twelve-character minimum and account display name. A request that requires email confirmation does not become a signed-in account or a verified competitive identity. The shared screen explains the actual confirmation requirement and offers its real resend action. An email dispatch acknowledgement is not proof of delivery or account existence.

Invalid credentials remain an actual authentication error with the entered email retained for correction. Useful focus returns to the relevant field or error without deleting the entire form or announcing the password. Duplicate submissions and account-mode changes while a real operation is busy follow the existing shared rules. The wrapper does not add a fake timeout, second auth worker, unconditional retry loop, or success delay.

### Available providers only

The existing shared page can check Apple and Google provider availability against its actual account service. F29 neither assumes those providers work nor freezes an available provider into a decorative placeholder. A disabled or unknown provider remains explicitly unavailable under the shared screen's behavior. Only a service-confirmed available provider may start the existing real system authentication session. Cancellation returns to the same form without changing accounts. No new provider, passkey, biometric sign-in, personal model key, or social connection is introduced by this wrapper.

### Confirmation and password recovery

Forgot password? expands the existing request controls, preserving the email field and same-device link instruction. The acknowledgement keeps its nonenumerating meaning: a reset link was requested if an account exists. It does not say the email was found or delivered. The service's actual resend limits and errors remain visible.

A confirmation or recovery callback must pass the existing account flow's verification before the wrapper treats it as successful. A recovery link opens the existing New password and Confirm new password form. Continue to Physique is withheld while password recovery is required, even if the verified callback has established a temporary session. Only the actual completed password update allows a fresh Physique access check and the explicit return action.

An invalid, expired, superseded, already-used, or wrong-device link shows the actual safe error and the existing way to request the latest link or sign in conventionally. It cannot be repaired by parsing a token into a view, skipping password change, displaying an old account's private cache, or creating a dummy account. Repeated delivery of the same callback does not stack sheets, repeat a password update, or send the person to Physique twice.

Leaving password recovery does not falsify its completion or erase its real status. If the person closes before saving, the existing account owner retains whatever recovery requirement is still effective. The deferred Physique request is cancelled. Returning later uses the actual shared account state, not the last displayed success message.

### Same-account reauthentication and account switching

Reauthentication for the same stable account may restore a permitted destination after fresh access checks. Signing in with a different account discards account-owned navigation targets, report drafts, cached images, local competitive snapshots, badge selections, and saved reading positions from the first account. Matching emails, display names, country selections, and local profile photos are not evidence of account identity or permission to merge data.

The existing Sign in again or switch account action remains a shared account action. While switching is attempted, the previous account's private Physique content is shielded before asynchronous work starts. A failed or cancelled switch may return to the original account only when the shared account service actually restores that same identity. Its Physique access and current match are then checked again. Neither the old account nor a guessed new account is optimistically treated as active.

Switching or signing out affects the shared account, including the existing database-sync shutdown and account-owned library boundary. The checkpoint explains that it is not a Physique-only logout. It does not erase local workouts, local Profile, the exercise library, ZIP exports, or unrelated user data to clear the Physique cache. It also does not relabel those resources as belonging to the newly signed-in person.

### Restricted, ineligible, deleted, and unknown access

A verified account with a Physique-only restriction remains signed in. The checkpoint shows the private safe reason, affected capability, duration or review date when actually supplied, and the safety owner's View restriction or Appeal route. A restriction is not an expired password, a public accusation badge, or a reason to suggest creating another account. The generic account controls remain available where permitted, but switching is not advertised as a way around enforcement.

A pending appeal does not lift the current restriction. Expiry of a displayed duration does not locally unlock participation; fresh service authority is required. History, case status, privacy, and deletion routes remain available only to the extent the service actually allows them. A Physique-only action does not disable unrelated features by default; an actual wider account restriction is explained with its true scope.

Adult eligibility, attire declaration, and Physique legal consent remain separate preparation steps. The account wrapper does not collect a birth date, guess age or gender from an image, or manufacture a verified-age badge. If the actual service reports ineligibility, the safe entry flow explains it privately and permits leaving the feature.

A missing public competitive profile, a missing optional country, or an unplaced account is not an authentication failure. The identity and lobby owners resolve those states. Missing or invalid Physique access without an authoritative restriction notice uses Can't check Physique access and Retry; it does not invent a suspension reason from a generic forbidden response.

Account deletion stays in the existing real account flow with F29-E's complete data and active-match semantics. A deleted account has no Continue action. A pending or unconfirmed deletion remains pending or unconfirmed. If remote deletion is confirmed but local credential cleanup fails, private content remains unavailable and the existing sign-out or real cleanup recovery is offered. The wrapper does not report global erasure, recreate a deleted identity from a cached session, or replace account deletion with sign-out.

## Active-Match and Return Boundaries

Account management is not an overlay over a running camera. Opening it from preparation stops capture. If a search, Ready state, or countdown already exists, the match owner's state-aware cancellation resolves it before account management is treated as a harmless return. Before Go, an accepted cancellation releases the reservation and changes no Elo. If Go wins the race, a pre-start Cancel is not silently converted into a forfeit.

After Go, deliberate account management delegates to the existing match exit confirmation. It stops and shields acquisition immediately, then clearly offers Keep match or, only where actually eligible, Forfeit and open account. A service-established invalid, safety-aborted, or unavailable-service match has no-contest precedence. The account wrapper does not decide the winner, call sign-out a body judgement, or hold the privacy cover until a confirmation animation finishes.

An externally initiated sign-out, account deletion, account change in another window, or involuntary session expiry also stops and shields immediately. No missing confirmation is invented afterward. An involuntary auth or process interruption is not automatically a voluntary forfeit. The trusted service resolves the same match under the parent's interruption and finality rules. A voluntary forfeit is claimed only when actually accepted by the service.

If exit or remote sign-out cleanup cannot be confirmed, say so. Local hiding and account privacy actions do not wait for a remote acknowledgement. The next authorized visit resolves the original match; it does not create a second queue or pretend the old match was cancelled. Existing service-owned results may finalize while the account UI is open when accepted evidence is already adequate.

Resume never restarts the original capture clock, the twenty-second reconnect grace, retake counts, the ninety-second search or capture limit, the thirty-second judging deadline, or an allowance charge. Camera reacquisition is explicit and follows fresh permissions and the canonical camera-owner decision. A finalized result returns as a result, not a replay of Ready, capture, a score reveal, or an earned badge.

On macOS, Escape is state-aware. It first lets an active native credential interaction or focused editing context handle its normal cancellation, then dismisses an idle account sheet; it never becomes a global Forfeit key. Command-W closes an idle checkpoint or its ordinary window through native semantics. Closing a real active match or quitting asks about the actual consequence where the platform permits, through the match owner, not a custom window-chrome replacement. Force quit cannot be intercepted or represented as a confirmed voluntary forfeit. iPhone backgrounding, locking, or process termination follows the same distinction.

## Battle Composition at the Return Boundary

The account checkpoint itself is not a battle and has no timer, placeholder rival, badge wall, or miniature two-player preview. During unverified identity or expired authorization, the old battle is replaced by an opaque privacy-safe surface, not left readable behind the sheet. This removal is intentional protection, not a different battle layout.

Whenever an authorized battle composition is present again, the real timer is the top visual anchor. Below it, complete public identity and badge rails are grouped by owner. Below both rails are two large vertical player panels, You above Opponent, on iPhone and at every Mac width. All public battle badges are represented; there is no three-slot cap, hidden additional count, clipped rail, ticker, or hover-only badge explanation. Country remains an optional self-declared flag beside the handle, with an accessible region name and a neutral unavailable-glyph state.

Badges wrap above the players. Short windows and large text scroll the central stage instead of shrinking the participants. The timer and safe actions remain reachable; the badge wall need not stay permanently pinned. Evidence is aspect-fit without unequal scale, body cropping, warping, or labels across faces, limbs, or pose framing. Before finalization, the opponent remains an authorized avatar or neutral silhouette and actual stage or count, never live video or an early pose thumbnail. Account emails, private declarations, restriction reasons, and drafts never enter these rails.

F29-F owns the trusted public identity and badges. Editable local cosmetic badge previews do not become verification, earned Physique achievements, or an account-authentication signal. Country, badges, email, handles, Elo, and UI chrome never enter judge images or judging context. Returning to a view cannot automatically publish a local profile photo.

The updated user direction requires native macOS and vertical players even on wide windows. Older parent wording about an iPhone-first surface or a balanced two-column comparison is not an alternative for this return boundary.

## Private-Cache and Late-Response Rules

| Event | Immediate visible and local consequence | Permitted retained context and recovery |
| --- | --- | --- |
| Account restoration not resolved | Opaque account-safe state; no last user's content used as a loading placeholder | Only the secure account foundation may resolve the installed identity |
| Authentication operation begins | Stop capture and affected transfers; shield prior account's private view in every window before work can suspend | Existing owner-bound recovery context is usable only after the same actual identity is restored and authorized |
| Session expires or authorization becomes uncertain | Close galleries; revoke local image access; discard decoded pose images, reusable media links, unnecessary camera buffers, and unsent capture candidates; remove private content from visible and accessibility trees | Minimal protected same-owner match reference and a still-valid text-only report draft may survive under F29-E; they are not visible until authorization returns |
| Sign-out, confirmed account switch, or deletion | Clear the prior owner's private in-memory state, private media and thumbnails, links, drafts, history and pagination caches, allowance and rating snapshots, badge and country drafts, case context, deferred return targets, and credential-form secrets | No previous-owner private state may be shown to the next account. Later discovery of an active match comes from the service, not an exposed old cache |
| Wrong-account, denied, expired, removed, or withdrawn media access | An accurate safe placeholder replaces media immediately | No saved link, decoded image, background window, restored backup, or fresh sign-in can bypass the current access decision |
| Cleanup cannot complete on this device | Keep the old cache inaccessible and report the specific cleanup failure; do not claim removal succeeded | Real Retry cleanup is available. The new account cannot use an old cache while cleanup is unresolved |
| An old request completes after identity or return context changes | It cannot replace the new state, restore old media, open a private destination, send an old draft, or mark the new account ready | Fresh current-account access is required; the superseded operation has no navigation effect |

Clearing the visible cache is not remote deletion, consent withdrawal, an Elo reset, or a guarantee of secure erasure from the operating system. These actions retain their separately owned meanings. Logout can be locally complete while remote activity cleanup remains unconfirmed; copy must distinguish those results. A disk cleanup error does not justify briefly showing the sensitive file while retry runs.

Account-form passwords and new-password confirmations remain ephemeral, never in return context, preferences, analytics, image captures, or logs. Dismissal and actual account change clear form secrets. Keeping a corrected email within the currently open form is allowed; exporting it to the public identity or retaining it as an unscoped global draft is not.

## Focus and Accessibility

The shared native fields remain actual labeled fields. VoiceOver reads the main title, concise Physique purpose, current state, and form in visual order. Decorative accent and redundant symbols are hidden from the accessibility tree. Missing identity or cache content is actually unavailable to accessibility, not merely blurred visually.

On first presentation, accessibility focus goes to the account title or current critical instruction. The wrapper does not steal focus back on every status update. Standard keyboard focus can enter Email when a keyboard sign-in was explicitly requested; ordinary touch presentation does not automatically obscure the purpose text with the keyboard. The shared field owner controls Email to Password to Display name chaining, validation focus, and verified recovery's New password focus. Errors are announced once when actionable; passwords and secure-field contents are never announced as status text.

After access succeeds, announce Ready for Physique once and make Continue reachable without moving someone out of another account-security field they are editing. After Continue, focus goes to the destination's heading or critical real-stage instruction. Close restores the initiating control where it still exists; account switching falls back to the safe lobby heading. A vanished result, case, or history row is not targeted by a stale focus request.

Return and Space act only through the currently focused semantic field or control. There are no global key handlers that submit from another field, trigger Continue while typing, capture a pose, or accept a forfeit. Escape and outside-click behavior follow the current native presentation and match state. Native paste, password-manager insertion, text selection, and keyboard correction remain available.

All actions are usable through Voice Control, Switch Control, keyboard, and pointer without hover, a swipe, precise dragging, color recognition, or haptic perception. Country and badge semantics come from their owner; a screen-reader badge label never claims identity verification. Large text wraps instructions and errors. Increased Contrast and Reduce Transparency use readable opaque surfaces and visible native focus. Necessary error text is not rendered in the theme's low-opacity decorative caption treatment when that would impair legibility.

## Motion, Interruption, and Energy

Account motion is tactile feedback to actual state, not a second sports celebration. The ordinary system sheet transition is retained, and the existing shared press feedback supplies the physical feel. No camera shader, scanning beam, rotating athlete, badge pulse, confetti, or continuous background loop accompanies sign-in.

| Trigger | Visible motion and timing | Interruption and reduced behavior |
| --- | --- | --- |
| Native sheet opens or closes | Use the platform's ordinary presentation; no additional card flight or matched-body zoom | Native reduced-motion behavior; dismissal never waits for custom decoration |
| Enabled shared action is pressed | Existing shared press spring, response 0.24 and damping fraction 0.88; existing small press scale, not a second nested spring | Release or disabled state replaces the press immediately; Reduce Motion removes added scale |
| Actual restoration, access, or authentication stage changes | Context icon and state text crossfade over 180 milliseconds; surrounding context height may settle over 280 milliseconds without moving the fields offscreen | Newer state replaces the current transition, with no queued sequence or minimum wait; reduced mode uses immediate layout and at most a 100-millisecond opacity change |
| Real identity and requested-access checks succeed | A small checkmark replaces the context person/status icon and settles from at most 1.04 scale within 180 milliseconds; Continue becomes available at once, within the same context transition | Plays once for that resolved checkpoint, not on every body update, history reopen, or window activation; reduced mode displays the static checkmark |
| Actual failure becomes actionable | Error symbol and readable text appear over 160 milliseconds, with no shake or red full-screen flash | A newer error or success replaces it; focus and Retry do not wait for the fade |
| Real request is in flight | Existing shared indeterminate activity treatment only while that request remains pending; no fake percentage or invented remaining seconds | Stop on completion, cancellation, supersession, or offscreen state. Under reduced motion, low power, or thermal constraint use static status text rather than an extra decorative loop |
| Continue returns to an authorized destination | Non-sensitive context/header continuity settles over approximately 280 milliseconds while the destination is already usable | No animated travel of body images or old account data; match timing and safe actions never wait for a transition |
| Identity invalidates, sign-out begins, permission is lost, or cache access is removed | Sensitive content is removed immediately, with no crossfade through the former account | Cancel every pending reveal first. Reduced mode is equally immediate |
| Window resizes or keyboard changes usable space | Native layout responds to measured geometry and maintains the focused field | No repeating spring on geometry measurements; reduced and low-energy modes preserve the same information |

At most one focal account event runs at a time. The wrapper adds no ambient layer. Native authentication presentations keep their own system motion and are not wrapped in another custom scale effect. Accessibility announces stage milestones, not spinner frames, clock ticks, or interpolated values.

Offscreen, background, inactive, and minimized surfaces stop decorative work immediately. Returning does not replay a success cue or redo a completed sign-in. Low Power Mode and serious thermal constraints remove nonessential scaling and use short or immediate status updates. There is no per-frame networking, token refresh, disk cleanup, image decoding, camera construction, font measurement, or global layout invalidation. A button or animation completion is never the authority for whether identity, access, cleanup, a forfeit, or a result succeeded.

## Dependencies and Review Boundaries

The existing shared cloud account, secure credential storage, verified callback handling, account-isolated database sync, native navigation, and shared control conventions are the foundations. Their existence in source is not a substitute for the implementation and human-review boundaries recorded in [CYCLES.md](../../../../CYCLES.md).

The real Physique foundation must expose current account access, actual restriction scope, canonical match recovery, immediate account-change invalidation, private-cache access removal, and one active account/match/camera owner. Without those capabilities this wrapper cannot be made complete by adding a new sign-in page or substituting a mocked access result. The independent documentation assignment does not waive those dependencies for future code work.

[F29-B](../../F29-B-ai-judging-and-metrics/DOCKS.md) owns judge blindness and score meaning. [F29-C](../../F29-C-physique-rating-and-matchmaking/DOCKS.md) owns real match reservation, allowance, timing, and finality. [F29-D](../../F29-D-safety-and-reporting/DOCKS.md) owns eligibility, restrictions, appeals, and permitted safety routes. [F29-E](../../F29-E-privacy-and-service-operation/DOCKS.md) owns authentication access, private media, consent, drafts, retention, withdrawal, and deletion. F29-F owns trusted public identity, country, and badges; this wrapper consumes no local cosmetic substitute.

This area does not own a new consent page, adult-declaration form, camera-preparation view, match-exit screen, gallery, case center, or account provider. Native alerts and the existing shared account controls are reused rather than catalogued as new custom views.

## Files and Integration Surfaces

- [This product canvas](DOCKS.md) owns account-entry and return behavior; the [future implementation brief](../../../../prompts/F29-physique-duels/F29-A-b-phase-1-account-entry.md) separates engineering work from product context.
- Prospective TimeMaster/Views/Physique/PhysiqueAccountEntryView.swift owns the thin native context and return presentation, not authentication logic.
- [CloudAccountSettingsView.swift](../../../../TimeMaster/Views/Settings/ImportedSettings/CloudAccountSettingsView.swift) owns the existing real account forms and security destinations. A narrow optional Physique context must leave Settings and exercise Ranked callers unchanged.
- [RankedAccountView.swift](../../../../TimeMaster/Views/Ranked/RankedAccountView.swift) is the existing native account-host pattern; its exercise semantics are not renamed as Physique.
- [CloudAccountStore.swift](../../../../TimeMaster/Services/Cloud/CloudAccountStore.swift) owns the shared account lifecycle and operation outcomes. The feature must participate in its real identity-change boundary rather than infer identity from a label.
- [CloudAuthClient.swift](../../../../TimeMasterCore/Sources/CloudAuthClient.swift) owns secure restoration, session refresh, and verified account callbacks. The wrapper does not reimplement them.
- The reviewed Physique page/presentation and account-scoped state under TimeMaster/Views/Physique/ and TimeMaster/Services/Physique/ own the live return destination, private-cache boundary, match state, and camera handoff. Their actual source ownership must be settled by the shared foundation before implementation.
- [TmaxApp.swift](../../../../TimeMaster/App/TmaxApp.swift) owns the native window and existing recovery presentation boundary; [TmaxCommands.swift](../../../../TimeMaster/App/TmaxCommands.swift) owns the preserved Mac commands.
- [Theme.swift](../../../../TimeMaster/Utilities/Theme.swift), [ProfileDesign.swift](../../../../TimeMaster/Utilities/ProfileDesign.swift), [TimeMasterGlassControls.swift](../../../../TimeMaster/Utilities/TimeMasterGlassControls.swift), and [shared settings components](../../../../TimeMaster/Utilities/EverStore/Components.swift) own existing styling, readable layout, and action feedback. There is no parallel global theme.

## References and Design Basis

- [Supplied battle reference](../../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png) is a hierarchy reference: its prominent timer and direct participant identity inform return continuity. Its side-by-side players, overlays across people, purple/brown pills, faces, footage, and assets are not imported.
- [Apple HIG: Managing accounts](https://developer.apple.com/design/human-interface-guidelines/managing-accounts), especially Best practices and Deleting accounts, supports explaining why sign-in is needed, delaying it until an account-required action, showing only available authentication methods, and preserving actual deletion access. The chosen extra Continue action is a product privacy decision, not an Apple requirement.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), Best practices, informs readable Mac density, resizable windows, native input, and existing commands rather than a stretched phone presentation.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), Best practices and Providing feedback, informs brief, purposeful, cancellable, optional feedback. Account authorization never depends on seeing an animation.
- [Dimillian SwiftUI UI Patterns](https://github.com/Dimillian/Skills/tree/main/swiftui-ui-patterns), particularly Sheets, Deep links, and Focus handling, is an architecture pattern reference, not direct copied app code. Existing project account and routing ownership takes priority over introducing another global router.
- The installed SwiftUI Pro, SwiftUI Animation, and Apple HIG Reference skills inform native state ownership, deployment-compatible APIs, focus, optional motion, and accessibility. This design preserves the existing iPhone compatibility and native macOS 14 target rather than requiring newer animation or glass APIs.
