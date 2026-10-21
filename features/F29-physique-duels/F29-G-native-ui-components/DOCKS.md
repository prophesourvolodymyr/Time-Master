# F29-G — Native UI Components and Motion

## Purpose and User Direction

This area owns the shared visual and interaction components that make Physique Duels feel like one animated native product on iPhone and macOS. It is product context, not an implemented component library or a performance report. The user explicitly requested deeply considered components, a top timer, large vertically stacked players, all user battle badges above the players, minimal text, animated icons and backgrounds, and expressive result counters. Native Mac is a required surface, not deferred polish.

The [parent feature](../DOCKS.md) owns competition and privacy boundaries. [F29-A](../F29-A-page-and-match-flow/DOCKS.md) owns screen composition and its twenty-five view contexts. [F29-F](../F29-F-battle-identity-and-badges/DOCKS.md) owns identity, countries, earned badges, and the complete badge rail. The timing and visual treatments below are selected design requirements for implementation review, not measured frame-rate or accessibility results.

## Component Ownership

| Component | Detailed product context | Scope |
| --- | --- | --- |
| Phase clock and countdown | [F29-G-a](F29-G-a-match-timer/DOCKS.md) | The visible top clock, authoritative deadlines, digit changes, self-timer distinction, and resumption |
| Large player panels and pose icons | [F29-G-b](F29-G-b-player-panels-and-pose-icons/DOCKS.md) | Vertical participant presentation, camera or avatar states, safe evidence framing, and original pose illustrations |
| Battle atmosphere | [F29-G-c](F29-G-c-battle-background/DOCKS.md) | State-responsive dark sports background, quiet depth, restrained ambient movement, and energy behavior |
| Score counters and result choreography | [F29-G-d](F29-G-d-score-counters/DOCKS.md) | Validated scores, totals, signed Elo changes, immediate final meaning, and once-only reveal |
| Native Mac presentation shell | [F29-G-e](F29-G-e-macos-shell/DOCKS.md) | Window and toolbar composition, resizing, commands, focus, cameras, privacy, and multiple windows |
| Country and complete badge presentation | [F29-F](../F29-F-battle-identity-and-badges/DOCKS.md) | Truthful public identity, all legitimate badges, medallion styling, and unlock/removal feedback |

Each new custom view has its own design owner and implementation brief. System alerts, permission prompts, native pickers, and established app controls are reused rather than recreated as needless custom components. A newly discovered custom screen or component must receive an explicit owner and requirements before it is added; it cannot be hidden in an unrelated worker's scope.

## One Visual Language

Use the existing near-black background, two dark elevated surface levels, white and readable secondary ink, toolbar orange, Inter Black emphasis, Inter Regular body text, native glass controls with public availability fallbacks, and the existing orange-and-ivory sports illustration family. The app's public shared material and press treatments are the foundation. Do not establish another app-wide theme, purple web-card skin, unrelated neon palette, or private-framework dependency.

Give visual hierarchy to the current task rather than surrounding every number with an explanatory paragraph. A typical stage contains one short heading or phase label, one immediately useful instruction, meaningful player imagery, and one primary action. Concise visible labels remain for consequential actions. Full recipient, retention, safety, evidence, and forfeit explanations remain reachable and complete; minimal text is not permission to make consent or an error ambiguous.

The supplied LarpGPT screenshot is a hierarchy reference: an obvious timer, directly readable players, compact identities, and accessible exit/report controls. Its side-by-side players, web badges, colors, photographs, footage, and labels are not product assets or a license to reuse those people. Original neutral pose art must fit the app's existing ivory-athlete family and explain safe positioning rather than idealize or sexualize a body.

## Battle Composition on Both Platforms

The match timer is the top visual anchor. Below it, each participant has an explicitly owner-grouped identity and badge rail. Every public battle badge is represented above the player panels. The person's large panel is above the opponent's large panel. This vertical order never changes because a Mac window becomes wide, a player wins, a timer crosses a threshold, or the app resumes.

The panels occupy the useful stage area rather than becoming tiny avatars beside a dashboard of text. Local camera evidence is fitted without distorting, cropping required anatomy, or shifting the capture region during an animation. Opponent capture-time presentation is an authorized avatar or neutral figure with real readiness and accepted-pose progress, not a live stranger stream or an early opponent still. Framing and status chrome sit outside important evidence regions.

Badge rows wrap without a hidden count or a three-badge selection cap. Owner grouping remains clear when they occupy multiple lines. At large text or in a short Mac window, the central stage can scroll rather than shrink the participants to unreadable thumbnails. The active timer and safe actions stay reachable. Top-of-stage badge placement does not require an unlimited permanently pinned badge wall that leaves no room for either player.

Wide Mac layouts may use a secondary inspector for rules or result details, but the actual player pair stays vertical. The app's title bar, window controls, measured navigation clearance, and bottom or top page-menu preference remain intact. The existing Mac minimum of eight hundred by six hundred is supported; a feature must not raise the whole app's minimum to rescue a rigid composition.

The running clock belongs to active match phases. It is not transplanted onto unrelated account, privacy, or support pages as decorative pressure. Once a match is final, the clock cannot keep counting as though capture were active. A terminal phase label or actual service-supplied timing can occupy the corresponding header context; no invented elapsed time or artificial result countdown is introduced.

## Shared Motion Vocabulary

Motion makes actual changes tangible: a real pairing settles into the two panels, an explicit Ready changes its mark, the start countdown arrives on real seconds, an accepted pose confirms once, a final outcome resolves, and a confirmed rating or badge update is acknowledged. It must not create a false lead, fabricated analysis stage, paid advantage, or humiliation.

| Event | Selected motion direction | Timing and interruption | Equivalent without motion |
| --- | --- | --- | --- |
| Press or activation | Reuse the shared tactile press feedback and release | Existing press spring; only a real activation invokes an action | Immediate pressed/selected appearance without scale |
| Small status or icon change | A short replacement, stroke, or opacity response within stable geometry | Roughly 140–200 milliseconds; newest real state wins | Immediate replacement or brief opacity |
| Stage continuity | Keep stable player ownership and transition the stage's meaningful content | Roughly 260–320 milliseconds; input remains available | Immediate stable layout |
| Start countdown | One clear numeral per real second with a small settled emphasis | No more than approximately 1.08 scale, settling within 220 milliseconds; cancel on lost start eligibility | Replace numeral immediately, with equivalent text and optional cue |
| Running timer digit | A crisp in-place numeric change without moving the header's bounds | Approximately 180 milliseconds; no delay of the true deadline | Static current digits |
| Pose selection or acceptance | Confirm the exact affected slot once, without a body scan | Short event feedback within the small-status range; replacement invalidates old acceptance | Clear selected/checking/accepted text and symbol |
| Ambient battle depth | One low-contrast atmospheric layer around opaque media wells, never movement or relighting of camera evidence | Approximately twelve-second breathing only in eligible waiting/judging states; static throughout camera acquisition to avoid illumination changes, and paused when inactive or energy-constrained | Static dark sports background |
| Authoritative result | Outcome available immediately; supporting elements resolve in one coherent reveal | All result motion settles within 900 milliseconds total, without a forced minimum wait | Immediate final outcome and values |
| Accepted score total | Reveal the already confirmed final glyphs and a bounded supporting accent; do not count from an invented zero or show random interim body scores | Approximately 650 milliseconds, synchronized rather than four serial delays | Final number, unit, and meaning immediately |
| Own earned Elo | One signed change and crest response, distinct from appearance points | Approximately 450 milliseconds within the total result window; no replay award | Final rating and signed change |
| Earned badge | One local acknowledgement of a confirmed unlock or status change | Brief emphasis after the actual service update, never a continuous badge loop | Static new badge with readable meaning |
| Hide, block, revocation, camera stop | Protection takes effect immediately | Never waits for a decorative transition | The same immediate protection |

The expert child contexts may specify the complete interruption details, but may not create competing global timing systems. A correction is a labeled new review event, not another original win ceremony. Reopening history, navigating back, reconnecting, switching windows, or receiving duplicate data cannot replay an award or restart an authoritative clock.

## Truthful Numbers and State

The component receives the actual stage and confirmed values. A timer derives its meaning from the match phase, not the screenshot's sample number. Search, shared start countdown, capture, the optional local capture self-timer, reconnect grace, and unbounded-looking judgement activity are distinct concepts. The self-timer never replaces or extends the shared capture deadline. No countdown promises when the AI will finish.

A capture has three named poses, at most two retakes per pose, and the unchanged shared ninety-second deadline. Search is bounded to ninety seconds. The start countdown is three seconds. Reconnect grace is twenty seconds without extending the original deadlines. The judgement deadline remains thirty seconds after both final sets are received. The five-second experience target is unmeasured and only changes the honesty of the waiting message, not the winner or clock authority.

Whole-point category scores, one-decimal weighted totals and gaps, and whole signed Elo changes have different units and validation. Their animations cannot turn a temporary interpolated value into a winner, mislabel a low score as missing evidence, or convert body points into Elo. The accepted final values and outcome are available to accessibility immediately. Invalid, missing, refused, or no-contest data has an absent-score explanation, never an animated zero.

## States

| Shared state | Visual and interaction consequence |
| --- | --- |
| Fresh and eligible | Real current identity and stage, correct clock and meaningful actions |
| Loading | Preserve only permitted confirmed content; no fake player, badge, tier, score, or progress |
| Empty or unplaced | Deliberate empty identity/record state, no earned seed or placed crest |
| Provisional | Actual earned rating and completed placement count, no assigned placed tier |
| Searching | Own identity and honest activity; no fabricated opponent |
| Paired or ready | Stable vertical pair with actual readiness; no opponent camera |
| Start countdown | True service-established start, explicit safe cancellation before Go |
| Capturing | Local safe preview, opponent stage/accepted count, actual pose and remaining time |
| Checking or retake needed | Exact affected candidate and real acceptance state, no premature success |
| Submitted or judging | No continuing exertion requirement, no invented body scores or analysis percentage |
| Valid judged result | Immediate outcome and validated values, once-only supporting motion |
| Forfeit | Actual ordinary competitive consequence, no invented physique comparison |
| No-contest | Honest private reason, no Elo change and actual allowance status, no opponent gallery |
| Reconnecting or stale | Same match and real remaining time, freshness visible, no reset or local verdict |
| Correction settling | Last confirmed values labeled; no speculative reversal or duplicate award |
| Media hidden, expired, revoked, removed, or blocked | Accurate protected placeholder, no old cache or alternative-link reveal |
| Camera or provider unavailable | Real unavailable state and useful safe recovery, not a fake feed or local rank |
| Inactive, minimized, or background | Acquisition stops and private surfaces shield; decorative work pauses |
| Reduced motion or transparency | Equivalent meaning and reachable controls with static motion or opaque surfaces |
| Energy constrained | Quiet static or reduced decorative treatment; timing and authoritative state remain correct |

## Accessibility and Input

Use native semantic controls, meaningful labels, visible keyboard focus, ordinary focus order, and independent text or symbols for color-coded states. Dynamic Type grows the composition; do not copy existing clamps simply because a nearby exercise HUD uses them. A badge's accessible name states owner and actual meaning. A country flag has a readable self-declared region name rather than a bare emoji announcement. An unavailable or hidden image does not retain an intimate description.

Timer and counter changes do not continuously interrupt VoiceOver. Announce meaningful phase changes, important time milestones, completion, and errors once. Score interpolation is decorative; assistive technologies receive the accepted final value. Sound and haptics are optional reinforcement, not required to understand a deadline, take a still, or leave. Safety and camera-stop actions do not wait for any animation or accessibility announcement.

On Mac, pointer hover may supplement focus feedback but never reveal the only action or explanation. Return and Space activate the focused control, not a global camera shortcut while someone types into a form. Escape, window close, and quit are phase-aware; a dialog cannot silently forfeit or reset the match. Existing app commands remain intact. Unsupported shortcuts are not advertised as working.

## Native Mac Window and Camera Lifecycle

Mac is a native macOS target, not Catalyst or an embedded website. Use normal window chrome, toolbars, sheets, popovers, menu commands, and readable inspectors. Support the current minimum, ordinary laptop sizes, larger/full-screen windows, live resize, and external displays. Resizing preserves stage, player order, camera ownership, focus, selected evidence, and deadlines.

Only one interaction owns an account's active capture. A second window can restore authorized state but cannot silently acquire another camera, create another match, or consume another slot. Switching the controlling surface must be explicit and state-aware. Inactive, minimized, backgrounded, locked, or interrupted capture stops immediately and uses a privacy cover. Returning reconciles the same authoritative match before any intentional camera resume.

Camera permission and availability are genuine Mac states. Handle TCC denial/restriction, busy or absent hardware, external-camera changes, and a disconnected Continuity camera. Do not substitute a recording, file picker, or fake preview for a rated camera. A forced termination cannot be prevented or represented as an explicit confirmed voluntary forfeit. If evidence was already accepted, the service may complete judging without an active window; late client delivery is not a second verdict.

## Performance and Availability Boundaries

Prefer a small number of stable reusable components and native rendering paths. Do not recreate camera sessions, decode body images, perform network requests, read files, measure fonts, or rebuild a whole page on every animation frame or timer tick. Decorative layers do not own the competition clock. Backgrounds are not animated screenshots of the camera and do not apply skin, anatomy, smoothing, reshaping, or score-enhancing filters.

Pause decorative work when offscreen or inactive. Low-power or thermal pressure reduces atmosphere before essential clarity or capture safety is compromised. A sixty-frame-per-second or high-refresh result is a future measurement question, not a claim in this specification. No custom GPU renderer is required merely to make the screen feel animated.

Retain existing deployment compatibility, including iOS 16 and native macOS 14. Modern numeric transitions, symbol effects, and glass use public availability checks and coherent fallbacks. A newer-system effect is not a reason to raise targets or leave older supported devices visually broken.

## Files, Dependencies, and References

This product context and its children own shared native behavior. Prospective feature components belong under TimeMaster/Views/Physique/ and its component organization; their exact technical structure must reuse the existing app architecture. The same shared presentation sources must be connected to both native app targets. Existing navigation, profile shape, account identity, exercise competition, and shared style APIs are not replaced.

F29-G consumes the stage and evidence rules from F29-A, valid metric meaning from F29-B, competition authority from F29-C, safety actions from F29-D, privacy and lifetime from F29-E, and legitimate identity from F29-F. The component design documents are independent writing areas under this shared contract. They are not independently shippable competitive features, and production integration still requires the real reviewed foundations.

- [F29 parent](../DOCKS.md) and [F29-A view inventory](../F29-A-page-and-match-flow/DOCKS.md).
- [F29-B judging](../F29-B-ai-judging-and-metrics/DOCKS.md), [F29-C competition](../F29-C-physique-rating-and-matchmaking/DOCKS.md), [F29-D safety](../F29-D-safety-and-reporting/DOCKS.md), and [F29-E privacy](../F29-E-privacy-and-service-operation/DOCKS.md).
- [Supplied LarpGPT battle screenshot](../../../genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png), an interaction and hierarchy reference, not direct code or asset reuse.
- [Apple HIG: Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), including flexible windows, keyboard/pointer input, menu access, and platform expectations.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), including purposeful brief feedback, optional motion, cancellation, and energy/platform considerations.
- [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) and [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy).
