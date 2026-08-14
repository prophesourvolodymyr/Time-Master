# F10 — Agent Settings Control

Lets the in-app AI coach inspect a deliberately limited settings snapshot and propose changes to user preferences. Every mutation remains behind the existing in-chat approval card; credentials, API keys, and filesystem paths are never exposed or mutated by the agent.

## What We Build

- `get_settings` tool returns a JSON snapshot of supported, non-sensitive settings: motivation, extra rest, notification preferences, custom workout types, goals, and type schedules.
- `update_settings` tool accepts only whitelisted fields and validates every value before saving it.
- AI requests an explicit user approval before an update is executed, with an intelligible diff in the approval card.
- Settings changes are saved through existing stores/managers and refresh notification scheduling when needed.

## Architecture

```
AIProvider schemas → AIStore approval gate → ToolRouter validation
                                      ├→ UserDefaults-backed preferences
                                      └→ WorkoutStore file-backed configuration
```

## States

| State | Content | Behavior |
|---|---|---|
| read | supported settings snapshot | returned without approval; no secrets included |
| valid update | proposed changed fields | approval card shows old/new values, applies after confirmation |
| rejected update | unsupported key or invalid value | tool returns a precise error; no writes occur |
| declined | user taps Decline | assistant receives a rejection result; state is unchanged |
| unavailable store | configuration cannot load | tool returns error and leaves data untouched |

## Animation Rules

| Animation | duration | trigger |
|---|---:|---|
| approval card insertion/removal | existing spring (0.38 response, 0.82 damping) | pending setting update changes |

## Files

- `TimeMaster/ViewModels/AIProvider.swift` — OpenAI-compatible and Anthropic tool schemas
- `TimeMaster/ViewModels/AIStore.swift` — write classification and approval summary/diff
- `TimeMaster/ViewModels/ToolRouter.swift` — settings snapshot, validation, persistence

## Dependencies

- F06-B — verified tool-call approval flow.
- F07 — settings persistence and notification preferences.

## Reference

- `genesis/REFERENCE/` — no direct reference required.

## Verification

- [ ] `get_settings` omits API keys and returns valid JSON.
- [ ] `update_settings` cannot execute without approval.
- [ ] Valid settings changes persist across relaunch.
- [ ] Invalid keys, types, and out-of-range values leave state unchanged.
- [ ] macOS target compiles.
