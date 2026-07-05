# F06-A — Text Selection

Allow selecting specific text in AI Coach messages with hold gesture, instead of only "Copy All".

## What We Build
- Long-press on any message bubble → native text selection handles appear
- User can select a portion of the response, tap "Copy" from the system menu
- "Copy All" remains available as a contextual menu option alongside selection
- Works for both user messages and AI response bubbles
- Follows Telegram/iMessage text selection pattern (hold → select → copy)

## Architecture
- `AICoachView.swift` — replace `.contextMenu` with `.textSelection(.enabled)` on message views
- Ensure message views use `Text` or `SelectableText` (not custom rendering that blocks selection)

## Files
- `TimeMaster/Views/AICoach/AICoachView.swift`

## Verification
- [ ] Long-press on AI message → text selection handles appear
- [ ] Can select partial text, tap "Copy" — selected text copies
- [ ] "Copy All" still available as secondary action
- [ ] User messages also support text selection
- [ ] Selection works in scrolling chat view
