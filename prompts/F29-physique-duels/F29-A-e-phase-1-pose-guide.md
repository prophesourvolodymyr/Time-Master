# Phase 1 of F29-A-e — Local Pose Guide for iPhone and Native Mac

## Assigned Model and Execution Mode

Use **openai-codex/gpt-6.1-sol:max**, with **thinking=max**. Max is the reasoning level, not another in-app judge. Do not silently substitute a model or lower the reasoning assignment. If the runner cannot honor the assignment, report the exact dispatch limitation before implementation.

This brief describes a future implementation. The preceding batch was documentation only. It did not authorize app changes, deliver artwork, run a prototype, validate camera behavior, or accept a visual implementation. Begin production code only when the prerequisites below are implemented, connected and human-reviewed, and the user has authorized this implementation slice.

## Features Included

- F29-A-e — Fully local illustrated Pose guide for front double-biceps, safe side physique and rear double-biceps.
- The same guide's native iPhone reference sheet, native macOS reference sheet, and contextual capture-help presentation.
- Original ivory-athlete pose illustrations and matching small selector pictograms; accessible written positioning, framing and safety guidance.
- The real entry, acquisition-stop and return boundaries supplied by the reviewed page and capture owners. Guide selection must never mutate the actual capture pose or competitive state.

This is one guide, not a new practice mode, camera implementation, judging feature, public gallery, safety backend or global visual-system rewrite. Report every meaningful implemented part separately for human verification and update only its actual implementation todos in CYCLES.md.

## Context

F29 requires an animated minimal-text sports UI on native iPhone and native macOS. This child supplies local illustrated positioning help without capture, uploads, practice rivals or scores. The shared battle remains timer first, complete owner-grouped public identity and badge rails second, then two large vertically stacked players, You above Opponent at every width.

## What You Need to Read First

Read the product context completely, then only relevant current source sections. Do not open prospective files below as if they already exist; discover the actual foundation and reuse its names and routing conventions before creating anything.

### Product and project context

- AGENTS.md, already provided in project context; do not rediscover agent/context files.
- features/F29-physique-duels/F29-A-page-and-match-flow/F29-A-e-pose-guide/DOCKS.md — complete local guide behavior, actual copy, native composition, states and motion.
- features/F29-physique-duels/F29-A-page-and-match-flow/DOCKS.md — guide entry, setup, match capture, permission and recovery ownership.
- features/F29-physique-duels/DOCKS.md — shared F29 contract, current child ownership and user-directed changes.
- features/F29-physique-duels/F29-B-ai-judging-and-metrics/DOCKS.md — Accepted Inputs and Judge Blindness; Comparable Evidence and Attire; fixed evidence requirements and permitted variations. Start with lines 11–48, then read any changed relevant definitions.
- features/F29-physique-duels/F29-C-physique-rating-and-matchmaking/DOCKS.md — one account and one active match, capture deadline, retakes, allowance and authoritative finality. Start with lines 79–139.
- features/F29-physique-duels/F29-D-safety-and-reporting/DOCKS.md — attire, ambiguous evidence, safe capture, bystanders and face minimization. Start with lines 9–60.
- features/F29-physique-duels/F29-E-privacy-and-service-operation/DOCKS.md — distinct consent decisions, stage-specific withdrawal, camera lifecycle and explicit return. Start with lines 17–81.
- CYCLES.md — current F29 implementation and human-review records, including the actual shared-foundation prerequisites. At planning time Cycle 39 begins near line 1970; search by its heading because main integration can move lines.
- The F29-F badge/identity context and reviewed capture/lifecycle contracts linked from the current F29 parent. Follow the owner's registered links; do not invent a second badge implementation or assume a prospective pathname exists.

DOCKS.md is plain-language product intent, not proof of implementation or a technical recipe. Follow direct user decisions over older conflicting documentation. Do not add source, pseudo-code, payloads, checkboxes, verification logs or completion claims to any DOCKS.md.

### Existing native source anchors

- TimeMaster/Utilities/Theme.swift:1–81,208–228 — existing near-black surfaces, orange actions, card surfaces and shared back controls.
- TimeMaster/Utilities/ProfileDesign.swift:1–38 — Inter typography, existing spacing, touch targets and readable-column convention; read the current relevant definitions if they have changed.
- TimeMaster/Utilities/TimeMasterGlassControls.swift:20–80 — public material availability, opaque Reduce Transparency behavior, and shared press response of about 0.24 seconds with 0.88 damping. Reuse the control convention; do not create a new glass framework.
- TimeMaster/Views/Ranked/RankedComponents.swift:15–108,148–188 — nearby sports controls and earned-Elo identity language only. Do not copy Dynamic Type clamps, small fixed labels or local/cosmetic rating assumptions.
- TimeMaster/Views/Ranked/RankedDuelPlayerView.swift:25–151 — exercise HUD context only. Its provisional exercise score, leading bar, horizontal arrangement and camera initialization are not a physique guide implementation.
- TimeMaster/Models/LocalProfileModels.swift:23–27,99–109 — editable local cosmetic previews are not trusted competitive achievements or identity verification.
- TimeMaster/App/TmaxApp.swift:8–19 — native WindowGroup, normal title bar and existing Mac minimum of 800 by 600.
- TimeMaster/App/TmaxCommands.swift:6–37 — preserve Cmd-N, Cmd-Shift-R, Cmd-comma and Cmd-Option-O. Guide keys must not steal these commands.
- TimeMaster.xcodeproj/project.pbxproj — preserve the native macOS 14 target and iPhone iOS 16 compatibility. Check actual current target membership; do not raise deployment targets to simplify animation or sheets.
- Current real Physique entry, capture, privacy lifecycle and scene-ownership source files, discovered from the reviewed foundation. Read only their relevant sections before connecting the guide. They did not exist as an implemented foundation in this documentation handoff.
- Existing localized-string and asset-catalog conventions discovered from source; do not create a separate localization framework for three poses.

STYLES.md was absent during planning. Use the current source conventions; do not create a global design file to fill that absence.

### Visual references

Inspect these images, not only their filenames:

- genesis/REFERENCE/F29-physique-duels/larpgpt-battle-reference.png — borrow directness and the timer-led hierarchy only. Do not borrow the people, footage, side-by-side players, purple/brown pills or face rights.
- TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png — ivory sculptural athlete, charcoal garments and orange accents as a family reference.
- TimeMaster/Resources/Assets.xcassets/Ranked_standardSquat.imageset/art.png — sport-pictogram optical language, not a substitute pose image.

Existing exercise art does not depict the required three positions and does not establish permission to redistribute a derivative asset. Produce original instructional artwork or use assets whose rights and use are already approved. Never pass a stock photo, screenshot person, generic standing icon or absent-asset placeholder off as the finished guide.

### Relevant installed skills and current Apple guidance

The main documentation owner already selected dimillian/swiftui-ui-patterns through the UI Skills CLI. Reuse that selected context if it is exposed by the implementation runner; do not repeat package setup or install a new UI stack. The documentation worker's separate skill registry did not expose that slug. Do not claim it was read if it remains inaccessible; name the limitation and use the available native source and relevant installed guidance rather than inventing the package's contents.

Read the relevant portions of installed swiftui-pro, swiftui-animation and apple-hig-reference. Focus on accessibility, data ownership, navigation/presentation and bounded state-driven animation. These skills contain examples for newer platforms; their defaults do not override the repository's iOS 16 and native macOS 14 requirements. No private APIs or new third-party dependency is necessary.

Read the current live Apple sections relevant to this composition:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-ios — Best practices: concentrated tasks, rotation, Dynamic Type and reachable secondary actions.
- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos — Best practices: resize, full screen, large displays, keyboard and appropriate density.
- https://developer.apple.com/design/human-interface-guidelines/motion — Best practices and Providing feedback: purposeful, brief, optional and cancellable custom motion.
- https://developer.apple.com/design/human-interface-guidelines/accessibility — Vision, Mobility and Cognitive: text growth, contrast, labels, keyboard, gesture alternatives and reduced automatic motion.

Cite only guidance actually retrieved. The exact pose composition and motion durations are product decisions, not Apple requirements or proof of runtime compliance.

## What Happened Last Session

A coordinated specialist batch specified the local Pose guide and produced this brief. This child selected an illustrated sport plate with three direct pose choices, one large fully framed figure, concise cues and expandable detailed instructions. It specified camera-free browsing and an acquisition-stopped capture-help return path, native layouts and energy/accessibility behavior. The batch changed no Swift, model or service code, produced no new illustrations, ran no app or checks, and did not claim human approval of the shared foundations or a visual prototype.

The latest direct user direction overrides older F29-A language allowing balanced two-column player comparisons or a primarily-iPhone scope. Both platforms are required. A wide Mac may put instructions in an inspector or in columns beside an illustration; the two competing players must remain vertical and large. Public badge rails represent every available public badge, grouped by owner, above both panels, with no hidden +N or cap of three.

## Prerequisites and Review Boundaries

1. The user must authorize this implementation after documentation review. This dormant brief is not authorization from the earlier documentation-only request.
2. The actual F29 page/navigation and capture-state contracts must be implemented, connected and handed to the human, with the required shared-foundation review completed. This includes guide entry, stopping acquisition, safe return, selected-versus-accepted evidence, privacy shielding, clock authority, and one match/camera owner across windows and devices. A compile-only model or mocked host does not meet the boundary.
3. Capture, judge and safety owners must agree on the real three pose identities and required evidence. The guide's Side example allows either comfortable side without a scoring preference; it must map to the shared side-pose contract rather than silently introduce a different required orientation or a left-right image transformation.
4. Active help is connected only to the real service-backed lifecycle. Real consent, local fail-closed face obscuring, authoritative match timing/finality, protected intake and review boundaries remain with their owners. Camera-free reference content is not a fallback ranked mode if those foundations are missing.
5. The real host must expose an explicit stopped-camera state and explicit valid resume. Closing a guide is not implicit permission to resume. No hidden camera can remain live behind a full reading sheet.
6. Original finished pose assets and matching pictograms are deliverables in this slice or supplied by their approved asset owner before acceptance. Do not ship only labels and plan artwork as later work. Do not make paid or external generation calls without separate authorization; original vector artwork is a valid local solution. Preserve licensing notices wherever they are required.
7. Check CYCLES.md for the current human-review state rather than assuming a parent checkbox approves a dependency. If a real prerequisite is absent, state exactly what is missing, finish reachable authorized work, and do not create production mocks, no-op service adapters or an independent guide-specific match model to hide it.

A local fixture may exist only in an explicitly labeled preview using the project's existing preview conventions. Production routes must always use the actual navigation, lifecycle and service data. Preview fixtures do not constitute integration, native smoke proof or an independent release.

## Concrete Design Decisions

### Instructional plate

Use the existing near-black background, dark elevated reading surfaces, orange actions and Inter family. Keep one clear title and one main reading task. The top local status is Illustrations only; do not falsely assert that all app networking stopped or another window's camera is off.

Use Front, Side and Back as direct labeled choices, each with an original small companion pictogram. Keep the selected state recognizable through shape or a mark and accessibility selection, not orange alone. There is no learned/completed checkmark. The ordinal means only 1 of 3 references.

One large aspect-fitted full-body illustration dominates the detail area. Preserve head, hands, elbows and feet within quiet external framing corners and a floor baseline. The full pose name, a short cue and Breathe normally. Stop if uncomfortable. sit outside the illustration. How to pose and Framing & clothing reveal complete secondary information using native disclosures. Do not overlay prose or controls on shoulders, limbs or evidence.

The three-view figure is a neutral adult ivory sculpture with a featureless face, moderate anatomical detail, opaque charcoal sleeveless top, opaque charcoal mid-thigh shorts and small orange accents. All views share scale, proportions, clothing coverage, lighting and baseline. The rear view covers the buttocks. Side is a safe whole-person presentation, not a squeezed side-chest pose or a close-up. No veins, body score, anatomy spotlight, nudity toggle or forced body-type ideal is part of instruction.

Use one pose at a time instead of a three-up poster so arm and leg details remain useful on phones and short windows. Do not add an autoplay pose carousel, rotating body or idle flex loop. The figure shows where to place the limbs, not what the reader must look like. No comparison score or praise for exposing more skin appears.

### Pose instructions

Implement the complete wording and meaning in the DOCKS, with localization rather than duplicating slightly different platform text.

- Front double-biceps: Face forward. Raise your arms comfortably. Comfortable stance, relaxed knees, elbows bent with upper arms toward shoulder height only as comfortable, normal breathing, no forced clench or arch, both arms and both leg contours visible.
- Side physique: Turn side-on. Keep your stance relaxed. Lower arms to turn, move feet and torso together, either comfortable side, bend the near elbow naturally, keep the far upper arm slightly clear if comfortable, and do not clasp and pull, squeeze the chest or twist to exaggerate size.
- Rear double-biceps: Face away. Raise your arms comfortably. Lower arms before turning, regain a stable stance, then raise comfortably; keep the upper-back and both arm/leg contours visible, keep coverage intact and do not twist the neck to inspect the screen. Actual timed capture belongs to the capture owner, not the guide.

Framing guidance includes stable level camera, ordinary even light, whole head/hands/elbows/feet, safe turning space, no identifying background or extra person, and no stepping blindly backwards. Attire text includes the private adult-men shirtless exception, opaque athletic top or sports bra for others, opaque groin/buttock coverage for everyone, no extra-skin bonus, common-region evidence, and no invented anatomy or zero for obscured required evidence. Privacy text distinguishes local reading from real camera/sharing consent, requires locally obscured faces before every actual transfer, fail-closed redaction, exact preview, no bystander exception and no anonymity or copy-prevention guarantee.

### Native iPhone

Before matchmaking, use a native full-height sheet, Pose guide title and visible Done. Standard dismiss gesture is an alternative. Fit a row of three labeled pose choices when possible; at larger text or less width use three complete selectable rows rather than clipping or shrinking. Follow with the complete athlete plate, full heading/cue, safety line and disclosures in a vertical scroll. Done and the title remain reachable. Preserve the existing measured page and navigation-control safe bounds, portrait/landscape behavior and Dynamic Type without font clamps or a fixed screen-height card.

Opening from camera setup stops acquisition and shields the last preview before the sheet is exposed. Done returns to the same setup with capture stopped. Do not request camera permission or automatically search on return.

During active capture, Pose help expands the same reference after both large vertically ordered player panels in the stage scroll. It is not a full-screen cover hiding a running match. The top real timer and safe actions remain reachable. Show Camera paused. Timer continues. Keep the complete owner-grouped public badge rails above the two players; they may scroll with the stage rather than pin into an unusable wall. A deliberate help opening can bring the help heading into view. Return to capture restores the actual stage and leaves acquisition stopped pending explicit owner validation and resume.

### Native macOS

Use native macOS 14 or later, normal title bar, current app commands and the existing 800 by 600 minimum. No Catalyst or web wrapper, no new guide document window, no app-wide minimum increase and no dependence on 26-only visual APIs.

Before matchmaking, open a window-attached native sheet. With sufficient measured room, use a short leading list of pose choices, a large illustration in the central detail area and a readable trailing instruction column. At short/narrow space or enlarged text, use fitted selectors and a single vertically scrolling detail column. This is one illustrated person and its instructions, not a horizontal battle. Preserve selection, expanded sections, focus and reading anchor through live resize, full screen, display scaling and moving between laptop or external displays.

In an active battle, the guide may use the existing supplementary inspector only when enough stage width remains for large portrait participants. Otherwise use the after-players stage section. Never duplicate instructional accessibility elements in both locations. The timer stays topmost; all public badges stay above the players; You stays above Opponent at every width. The central stage scrolls without taking away timer or safety/exit access. Hover is supplemental; standard labels, focus and click/keyboard actions remain complete.

Local reading must work with TCC not requested, denied or restricted, no camera, camera busy, external camera removed or Continuity disconnected. The guide never requests permission or substitutes a file picker. On return, show the actual capture owner's camera recovery, no fake preview or silent rated-camera switch.

Each window can hold its own nonpersonal guide selection, but a secondary app window cannot acquire another camera, create a match or charge, mark Ready, or take over an active session. Inactive, minimized and background scenes stop decorative work; acquisition and sensitive host pixels are stopped/shielded immediately. Restore the real host state before any explicit camera resume. Cmd-W and quit use the active host's real consequences where confirmable. Force quit is not a confirmed voluntary forfeit and cannot be prevented.

## What to Build

### 1. A real fixed local reference

Supply the three actual original illustrations, matching pictograms, full pose titles, short cues, meaningful main-image descriptions, complete detailed steps, and full framing/clothing/privacy text. Bundle them so reading requires no sign-in, model, service, camera or network. Do not download a remote body image, decode personal captures, add a telemetry pipeline or infer a body state.

Keep only harmless presentation state: selected reference pose and disclosure/reading state in the current visit/window. First unqualified entry is Front; a named pose entry selects that pose; reopening in the same visit restores the last reference unless a named entry overrides it; relaunch defaults to Front. This is not persistent learned progress or a competitive preference.

Use the actual shared pose identities where appropriate rather than declaring a conflicting capture pose enum. Keep instructional content separate from personal evidence and service state. Follow existing localization and assets patterns, with no unnecessary general-purpose guide framework.

### 2. Native entry and complete navigation

Connect the existing lobby/rules/preparation Pose guide actions to the real reference sheet. Permit safe reading while signed out, offline, unplaced, camera-denied, allowance-empty or service-unavailable. Return to the actual origin with source focus; never auto-open setup, accept consent, queue, spend a slot or log an activity merely from browsing.

Opening from preparation stops that owned acquisition and shields private pixels synchronously with the host's existing privacy boundary. The guide must not create its own camera service. The full guide is not offered over searching, Ready or start countdown; those keep their brief owner-provided reminders. Do not leave an unseen ready state or Go beneath a full guide sheet.

### 3. Contextual capture help, not an alternate match

Connect Pose help only through the reviewed capture owner. Initially read the actual pose. Stop acquisition immediately, show the real paused preview treatment, and retain selected images, accepted counts, retake counts, original match and deadline. Browsing Front/Side/Back is independent of the actual pose slot. Authorized already-started transfers and checks may continue; do not falsely label the entire app offline or transfer-free.

Keep the real battle hierarchy untouched. Never add a provisional appearance score, hidden badge cap, early opponent still, substitute example rival, body crop, horizontal matchup or guide figure inside judging evidence. Return to capture closes help, reveals the real affected pose and state, and requires explicit valid owner resume to acquire again.

Handle check rejections, permission loss, camera disconnect, cross-window ownership loss, privacy withdrawal, account switch, background return, deadline expiry and terminal service events with the actual shared lifecycle. Help must not keep an expired session alive or delay privacy protection. It must never turn an interrupted read into a local forfeit or no-contest decision.

### 4. Responsive focus and assistive interaction

Use semantic native controls, distinct pose labels, selected traits, descriptive main art and decorative-only repeated icons. Support VoiceOver, Voice Control, Switch Control, Full Keyboard Access, text enlargement, Increase Contrast and Differentiate Without Color. Preserve iPhone's existing 44-point action convention; use native Mac density and visible focus, not mandatory phone-sized toolbars on desktop.

Initial accessible focus goes to the guide heading/current reference. Explicit selection announces the new heading/cue once while keyboard focus stays with the selector. Expanded detail follows its disclosure. Close restores the invoking action; a real terminal host state takes focus at its own outcome/recovery heading. Do not announce each timer tick or duplicate the host's status announcements.

Tab and Shift-Tab use platform navigation settings; focused native pose selection can use normal arrow keys. Return and Space activate only the focused semantic control, never a global capture/submit/Ready action while typing or reading. Escape closes only the active guide sheet or help presentation first and does not cascade into match exit. Preserve all existing app shortcuts and apply the host's departure behavior if another command changes activity.

### 5. Bounded, interruptible animation and energy behavior

Use shared press feedback where the project's custom control style applies; do not double-animate native controls. On an actual new pose selection, selection ink settles in about 180 milliseconds; heading and cue change coherently within about 180 milliseconds; the incoming full figure crossfades and settles from 98 percent to full scale about the stable floor baseline within 280 milliseconds, with little or no overshoot. Frame geometry does not move. Never morph anatomy, rotate a body in depth or scan body regions. The same-pose selection does not replay.

Native disclosures reveal or collapse in about 200 milliseconds. Active-help stage continuity uses about 280 milliseconds; explicit reveal to a help heading is at most about 200 milliseconds. Root timer and safe controls do not travel. Controls remain usable throughout. New selection replaces the in-flight visual state immediately and resolves to the latest choice; do not queue old poses or delayed announcements.

Reduce Motion removes scale, travel and sliding selection markers, using immediate changes or opacity of no more than about 100 milliseconds. Reduce Transparency uses opaque readable surfaces. No idle ambient, flex, breathing loop, animated body highlights, flashing or unsolicited audio/haptics belongs in the guide. Low Power Mode and serious/critical thermal conditions remove decorative settling. Offscreen, background, inactive or minimized guide content does no decorative animation; return shows current content directly without catching up.

Keep image decoding, text measurement, file I/O, service work and camera session operations outside per-frame visual work. Do not tie the guide's entire layout or asset loading to each match clock update. Avoid a camera rebuild during selection, disclosure or live resize. Native transitions never gate camera stop, privacy shielding or authoritative state changes.

### 6. Real recovery, not production placeholders

Use the complete state matrix in the DOCKS. In particular, offline reading needs no network spinner or retry; denied camera does not prevent the guide; unexpected bundled-art failure shows Illustration unavailable plus complete instructions and usable choices/Done, not an endless spinner or no-op Retry. That exceptional recovery is not acceptance of shipping missing artwork.

After interruption or a guide-related window change, restore the current real host state before private content or explicit capture resume. Never regenerate personal media, restore a deleted gallery, infer a service outcome or restart the 90-second capture, 20-second grace or authoritative judging deadline. Guide dismissal is not a voluntary match exit, new allowance event or automatic camera resume.

## Prospective Files to Create or Modify

Confirm the current reviewed foundation first. If an existing properly owned equivalent already exists, extend it rather than adding duplicate models or aliases. These are proposed creation locations, not already-present code to open or a mandate for separate one-line wrappers.

### Local guide-owned source

- Create or reuse TimeMaster/Views/Physique/PhysiquePoseGuideView.swift — one reference with native standalone and contextual help presentations, selectors, cues, disclosures and focus/return handling.
- Create or reuse TimeMaster/Views/Physique/PhysiquePoseIllustrationView.swift — whole-person instructional plate, accessible description, external frame marks and bounded pose-change visual state; no camera or personal-media responsibility.
- Create or reuse TimeMaster/Models/PhysiquePoseGuideContent.swift — local instructional catalog and text for the actual three shared poses, without competitive state, network calls or a parallel pose/camera model.
- Use the existing localization resources or current string-catalog convention for all guide labels, cues, instructions and image descriptions. Discover their exact current paths before editing.

### Finished original assets in the existing catalog

Use the feature owner's current naming convention if it already establishes equivalents; otherwise these concrete names follow the existing family pattern:

- TimeMaster/Resources/Assets.xcassets/PhysiquePose_frontDoubleBiceps.imageset/ — original front illustration and real catalog metadata.
- TimeMaster/Resources/Assets.xcassets/PhysiquePose_sidePhysique.imageset/ — original safe whole-person side illustration and metadata.
- TimeMaster/Resources/Assets.xcassets/PhysiquePose_rearDoubleBiceps.imageset/ — original covered rear illustration and metadata.
- TimeMaster/Resources/Assets.xcassets/PhysiquePoseIcon_frontDoubleBiceps.imageset/ — matching original simplified front pictogram.
- TimeMaster/Resources/Assets.xcassets/PhysiquePoseIcon_sidePhysique.imageset/ — matching side pictogram.
- TimeMaster/Resources/Assets.xcassets/PhysiquePoseIcon_rearDoubleBiceps.imageset/ — matching rear pictogram.

Prefer original resolution-independent masters or appropriately sized real renditions supported by both targets. Preserve whole-body bounds and the baseline across the three plates. Do not generate frames on every UI update or recolor arbitrary person photographs. Preserve required asset licenses in the project's existing notice mechanism when applicable.

### Real integration surfaces

- Modify only the actual future Physique lobby, existing rules/preparation and capture host files needed to connect guide entry, stopped acquisition, contextual help and explicit return. Discover and name the exact files in the implementation plan before editing. This brief does not authorize rewriting their match logic.
- Modify the existing target/resource membership configuration only if required by the actual project; preserve iOS/macOS target versions and native Mac membership.
- Update only relevant F29-A-e implementation todos in CYCLES.md after the connected work and focused checks. Do not check off unrelated F29 service or judge work.
- Update this feature's product documentation only for a directly approved decision or after human acceptance of a changed behavior; never put verification evidence or implementation recipes in DOCKS.md.

Do not modify unrelated app source, existing exercise scoring/privacy, Profile's two-side shape, F29-F badge semantics, backend schemas, judge prompts, quota policy, AGENTS.md, reusable protocols, global theme definitions or app-wide commands just to make the guide easier. If a necessary integration contract is absent or conflicts with a real invariant, resolve it with the owner through the actual parent rather than adding a compatibility shim or fake service.

## Observable Acceptance — Both Native Platforms

The implementation is ready for human review only when these consumer-visible behaviors are connected. No compile-only scaffold, no-op button, missing-art production fallback or picture-only preview satisfies them.

### Local reference behavior

1. The real Pose guide action opens the actual guide with all three finished illustrations and readable instructions without a sign-in, camera permission, network or judging service request.
2. Front, Side and Back each select the matching complete figure, correct full heading/cue and meaningful description. The latest rapid selection wins; selecting the current pose does not replay feedback. The 1 of 3 ordinal never becomes accepted-capture progress.
3. How to pose and Framing & clothing expose every instruction and consent/safety boundary in the product context. Required information is not hidden behind an unlabeled icon, a hover or a gesture-only action.
4. Opening, browsing, expanding and closing do not create a camera session, selected still, image upload, practice opponent, service result, rating event, badge, workout, queue position or allowance charge.
5. Done, the normal pre-match dismiss gesture and Escape return to the actual source and restore focus, without starting a search or resuming a camera.
6. A real offline launch can still show all three complete references. Camera denial and no hardware do not block reading. Unexpected asset failure has honest instructional recovery but cannot be the normal delivered artwork state.

### iPhone layout and interaction

1. Native sheet, title and Done work on supported iPhones in portrait and landscape, at short usable heights and the largest supported Dynamic Type. No text clamp, clipped choice, fixed bottom spacer or body crop is used to force one-screen fit.
2. At large type, the three choices become complete accessible rows and detail scrolls vertically. The whole illustrated head, hands, elbows and feet remain visible within the figure's bounds.
3. Touch, VoiceOver, Voice Control, Switch Control and hardware-keyboard equivalents expose the same choices, detail and exit. Selection and focus are not color-only, and motion is not needed to understand a pose.
4. From real preparation, the camera stops and private pixels are shielded before the reading sheet appears. Returning keeps it stopped until an explicit valid setup resume.
5. During real capture, help remains inside the stage after the two large vertical players, not over the whole battle. Real top timer and safe actions are reachable, all public badges remain represented above both players, and no body evidence is obscured by help or badges.

### Native Mac layout and interaction

1. Native macOS app and attached sheet work at the existing 800 by 600 app minimum, a normal laptop window, large full screen and a scaled external display. No target/minimum raise or web/Catalyst surface is introduced.
2. Roomy guide layouts use a source-style pose list and readable illustration/instruction area; constrained layouts become a vertical detail scroll. Live resizing and display movement retain the selected pose, expanded sections and logical focus without distorting art.
3. A real battle always stays timer, full badge/identity rails, You panel then Opponent panel. A supplementary help inspector is used only when it leaves both portrait panels large; otherwise help is after both in the stage scroll. Wide windows never create side-by-side participants.
4. Pointer and keyboard focus are distinct; hover is optional. Tab/Shift-Tab and focused-control arrow/Return/Space behavior work without stealing typing or global capture. Escape closes only guide/help first. Cmd-N, Cmd-Shift-R, Cmd-comma and Cmd-Option-O retain their existing meanings.
5. Cmd-W/quit use the actual active host consequence where the platform permits confirmation; closing harmless reference content has no match effect. Force quit is not presented or recorded as an explicit confirmed forfeit.
6. TCC denial, missing hardware, external/Continuity disconnection, inactive/minimized return and a secondary app window produce honest local reading and host recovery. No automatic camera takeover, rated file picker, fake feed, second match or extra charge occurs.

### Active-state authority, privacy and energy

1. Opening capture help stops acquisition without resetting the current pose, selected/accepted counts, retakes or original service deadline. A different reference selection cannot replace the actual capture slot.
2. Return reflects the latest real affected pose, rejection, interruption or terminal outcome. It leaves acquisition stopped pending explicit validated resume; no old help animation can cover finality or privacy protection.
3. Existing authorized uploads may complete, but guide actions create none. No guide art, country, badge, identity or UI screenshot enters the clean, locally face-obscured judging evidence. The opponent remains only permitted identity/silhouette and actual stage/count before finality; this guide never opens a counterpart body gallery.
4. Reduce Motion removes scale/travel/slide and gives the same information; Reduce Transparency uses readable opaque surfaces. Large text, Increase Contrast and Differentiate Without Color remain usable.
5. Background, lock, inactive, minimized, offscreen, Low Power Mode and thermal changes stop decorative work promptly. Real clocks continue under their owner. No hidden frame loop, repeated image decoding, full-scene clock invalidation or camera rebuild accompanies a guide selection or resize.

## Focused Actual Native Smoke and Accessibility Scenarios

Do not execute any of these in the documentation-only batch. In the future implementation, discover the project's actual run/build path and perform the smallest relevant checks after connection. Launch the changed native surfaces; tests or builds alone are not proof. Do not fabricate observed output, camera behavior, permission results or approval. Use authorized test accounts/services and consenting adults for any physical capture path, not a production mock or unauthorized public match.

### Exercise the real local reference

- Launch the native iPhone app in an available simulator or device, open the actual lobby guide, change Front to Side to Back rapidly, reselect Back, expand both detail sections, rotate, enlarge text and close. Observe correct art/copy coherence, no camera prompt or capture indicator from guide entry, no state-changing action and the restored source focus. Repeat signed out and offline; observe complete bundled content rather than a network loader.
- Launch the actual native Mac target, open the same real guide, resize the host from its 800 by 600 minimum through a laptop size to a large/full-screen or external-display arrangement. Observe native sheet/titlebar behavior, source-list versus stacked adaptation, complete figure bounds, stable selection and focus. Use a real external display when available; otherwise name that physical-display limit rather than claiming it was checked.
- Navigate each guide by keyboard. Exercise focus rings, Tab/Shift-Tab, focused choice navigation, Return/Space and Escape, with unrelated text input focused elsewhere when checking for key capture. Observe that existing app shortcuts retain meaning and no guide key starts capture or matchmaking.

### Exercise the real acquisition and match return boundary

- In the authorized real preparation flow, show the live local camera, deliberately open the guide, and observe acquisition stop/privacy shielding before the sheet. Dismiss it, verify the real stopped state, then explicitly resume through the actual owner. Do not infer this from a mocked callback or source inspection.
- With an authorized real in-progress capture, open Pose help, note the original deadline/retakes/actual pose, browse a different reference, and return. Observe that the clock continues, counts and pose authority are unchanged, two large players stay vertical with all public badges above, safe actions stay reachable, and camera resume requires a valid explicit action.
- While help is open, exercise one available real permission/interruption path and one authoritative state transition through the established test environment. Examples are camera disconnect and deadline expiry or an actual rejected pose. Observe correct host recovery and no stale preview, clock reset, second match, invented outcome or automatic acquisition. Do not extend the match or fabricate a service result just to make the scenario convenient.
- On native Mac, minimize/deactivate and return, open a second normal app window with the same account, and test the established external/Continuity camera path if hardware is available. Observe no second owner or charge and actual recovery on return. A force-quit scenario must retain involuntary-interruption semantics, not claim a confirmable voluntary exit.

### Exercise accessibility and motion/energy limits

- Inspect both native accessibility trees with the available platform tools, then use VoiceOver through all pose choices, descriptions, disclosures and exit. Observe one meaningful description per figure, full selected names, correct focus restoration and no duplicated inspector content or repeated timer announcements.
- Use iPhone maximum supported Dynamic Type and Mac text enlargement/zoom, Increase Contrast, Differentiate Without Color and Reduce Transparency. Observe complete labels, readable controls, no clipped disclosures or body crop, and an opaque readable surface when requested.
- Toggle Reduce Motion during a selection and while help is open. Observe immediate/current correct content with at most short opacity feedback, no remaining scale, travel or queued replay. Repeat with Low Power Mode where supported and with inactive/offscreen presentation. Use the project's available lightweight performance/energy observation tools for evidence of stopped decorative work; do not add thermal stress machinery, telemetry or a benchmark project.

Name precisely which native run, interaction and setting were actually exercised. A simulator can prove local guide navigation and layout; it does not prove physical acquisition shutdown, TCC/external-camera behavior, real two-account service finality, external-display scaling or thermal behavior. If hardware or authorized service access is unavailable, complete all reachable native work and state the exact unexercised boundary and attempts. Do not claim end-to-end active-camera acceptance from a compiling preview. No screenshot/recording package or exhaustive unrelated validation is required.

Permanent tests are optional unless requested or a discovered uncertain boundary merits regression coverage. If added, follow existing conventions and test a plausible consumer-visible defect such as an actual lifecycle transition or authority boundary, not copied strings, view wiring, asset counts, nonempty collections, mock forwarding, source text or incidental defaults. Use throwaway smoke scripts only where an actual native run is unavailable, remove them afterward, and state the visual/hardware limit. Do not add unrun tests as a completion substitute.

## Human Verification Handoff — Required

List each implemented part separately: local three-pose content, original illustration/icon family, iPhone presentation, native Mac presentation, real camera-stop and capture-help return integration, focus/accessibility, responsive layout, motion and energy behavior. List every changed source/resource/configuration/planning file separately or enumerate members of a clearly named asset directory; do not hide unrelated edits in a broad folder label.

For each meaningful part, state what changed and that it is ready for human verification, not human-verified. Ask the user to review the code changes and both native surfaces. Include only actually exercised checks and interactions, clearly label unobserved inferences, and state any missing physical-camera/service/display proof or unresolved prerequisite plainly. Distinguish implementation complete from human acceptance.

Keep implementation todos only in CYCLES.md. After the user accepts resulting behavior, update the smallest relevant DOCKS.md with the accepted plain-language product decision. Do not add screenshots, logs, tests-passed claims, task checklists or a completion-evidence section to product context.

## Mandatory Agent Rules

1. Single owner: implement this slice yourself. No nested agents or delegation to review the repository. Coordinate ownership with the actual parent contracts; do not edit another worker's feature to invent a shortcut.
2. User direction wins. Native iPhone and native Mac, timer first, every public badge above two large vertical players and animated minimal-text sports presentation are required. Do not revert to older side-by-side wording or reduce one platform to a stretched phone.
3. Use real data and real foundations. No fabricated peers, ratings, scores, acceptance states, avatars, queued matches, permission success, camera feed or provider outcome. No production mock, no-op button, placeholder artwork, fake fallback or guide-owned backend. Clearly labeled preview fixtures are never production substitutes.
4. Preserve privacy and authority. No camera, still, upload, scoring, consent or competitive effect comes from browsing. Actual candidates remain locally face-obscured and clean of UI chrome. Existing exercise privacy, real consent, one-owner lifecycle, original deadlines and service finality remain intact.
5. Research independently. Read relevant installed native skills and current source, respect the deployment floor, and reuse existing shared controls/presentation patterns. Do not add wrappers, a global theme or a new framework merely to mirror a guide-specific abstraction.
6. Complete the connected authorized slice. Run focused checks and actual native smoke where runtime exists, fix clear reproducible failures, update only relevant implementation todos in CYCLES.md, and provide the complete human-review handoff. A compile or staged view alone is not the deliverable.
7. Scoped commit and push apply to the later implementation session, not the prior documentation-only worker. After completed coherent edits, inspect through normal tool results, commit the owned changes with a clear message, and push to origin/main before yielding. Do not stage another worker's unrelated edits, force-push, rewrite history or fabricate publication success. Report an exact real commit/push blocker if one remains.
8. Do not rewrite shared protocols, AGENTS.md, app-wide commands, exercise policy, Profile shape, badge catalog, judging configuration or service policy as incidental guide work. Only necessary owned callers and resources belong in the slice. Missing real contracts must be resolved honestly, not shimmed.
9. Documentation stays honest. Checkboxes record implementation only in CYCLES.md; a human review is not implied. No code, payloads, implementation recipes, tests/logs or verification evidence in DOCKS.md. Update product decisions after acceptance or direct approval, not to make unfinished work look complete.
10. Do not generate a pointless next prompt. Finish reachable remaining guide work in this slice. A next prompt is appropriate only for a genuinely separate authorized implementation scope, never just checking, obvious fixes, artwork still owed, a commit or a push. State any real external prerequisite without presenting it as completed work.

## When You Finish

Return the implemented items and changed files separately, exercised native checks and honest limits, CYCLES implementation updates, scoped commit/push result, and an explicit request for human review of both iPhone and native Mac. State whether a next prompt was needed; do not invent further scope or claim approval.

## Scope Decision Before Finish

- Completed: the actually connected local reference, real assets, native presentations, owned integration and exercised checks.
- Remaining: only real unmet acceptance or external prerequisites, with their precise owner and attempted resolution; never disguise a missing component as future polish.
- Decision: no next prompt for a complete guide slice; otherwise name the exact external blocker or separately authorized substantial scope without claiming this guide is accepted.
