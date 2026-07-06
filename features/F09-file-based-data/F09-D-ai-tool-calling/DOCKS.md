# F09-D — AI Tool Calling

Enables the in-app AI Coach to query and modify the exercise database, build workouts, and access analytics — all through a structured function-calling loop. The AI emits tool calls; the app executes them via `TimeMasterCore`; results flow back into the conversation.

## What We Build

1. **Tool schema registration** — define tool schemas (name, description, parameters) in `AIProvider`
2. **Function-calling loop** — AI emits tool call → app executes → result inserted into context → AI responds
3. **Knowledge injection** — on session start: read `Knowledge/*.md` + inject exercise type summary
4. **Session context** — always available without tool calls:
   - Total exercise count by type
   - Recent workout history (last 7 days)
   - Current streak
   - Active training schedule
5. **Tool execution layer** — routes tool calls through `TimeMasterCore.DatabaseManager`
6. **Result formatting** — converts structured results into natural context for the AI

## Tool Definitions (registered in system prompt)

| Tool | Parameters | Returns | Description |
|---|---|---|---|
| `search_exercises` | query: string, type?: string | Exercise[] | Fuzzy search by name, description, type |
| `get_exercise` | id: string | Exercise (full) | Return manifest + guide.md + links |
| `list_folders` | parentID?: string | Folder[] | List folders (progressions, categories) |
| `create_exercise` | name, type?, duration?, parentID? | Exercise | Create new exercise folder + manifest |
| `create_folder` | name, parentID? | Folder | Create a progression/category folder |
| `get_recent_workouts` | days?: number | Workout[] | Recent completed workouts |
| `build_workout` | name, type?, sections[] | Workout | Build a workout from exercise IDs |
| `get_analytics` | type?: string, days?: number | Stats | Workout count, streak, volume, missed days |
| `add_media_note` | exerciseID, note: string | void | Append a note to exercise's guide.md |
| `suggest_workout` | intent: string, duration?: number | Workout | AI suggests a workout from exercises (AI-only, no tool execution needed) |

## Architecture

```
AICoachView
  ↓ user message
AIStore (conversation)
  ↓ system prompt + context + message
AIProvider.chat(conversation) → streaming response
  ↓ parse response
  ├── text chunk → display in chat bubble
  ├── tool_call detected → pause streaming
  │     ↓
  │   ToolRouter.execute(name, args)
  │     ↓ TimeMasterCore.DatabaseManager
  │     ↓ result JSON
  │   Insert as "tool result" message into conversation
  │     ↓
  │   Continue AIProvider.chat(updated conversation)
  │     ↓
  │   Final text response
  └── done
```

## Session Startup Context (injected without tool calls)

```json
{
  "knowledge": "<concatenated content of Knowledge/*.md>",
  "database": {
    "totalExercises": 42,
    "byType": { "Strength": 15, "HIIT": 8, "Yoga": 12, "Cardio": 7 },
    "folders": ["Upper Body", "Lower Body", "Core", "Cardio"]
  },
  "recentActivity": {
    "last7Days": 3,
    "currentStreak": 2,
    "lastWorkout": "Full Body Blast (yesterday, 25 min)"
  },
  "schedule": {
    "trainingDays": ["Mon", "Wed", "Fri"],
    "durationMonths": 3
  }
}
```

## States
| State | Behavior |
|---|---|
| No tools available | AI functions as before (text-only chat) |
| Knowledge folder empty | Default fitness knowledge only |
| Tool call success | Result inserted, AI continues naturally |
| Tool call failure | Error inserted as context, AI explains to user |
| Max tool calls (5) | AI must respond without further calls |

## Files
- `TimeMaster/ViewModels/AIProvider.swift` — tool schema definitions, function-calling loop
- `TimeMaster/ViewModels/AIStore.swift` — conversation management with tool results
- `TimeMaster/ViewModels/ToolRouter.swift` — (new) routes tool calls to TimeMasterCore
- `TimeMaster/Views/AICoach/AICoachView.swift` — UI updates for tool call states
- `TimeMasterCore/Sources/AISystemPromptBuilder.swift` — builds session context

## Dependencies
- F06 — AI Coach (existing chat interface, provider system)
- F09-A — TimeMasterCore (all database operations)
- F09-B — Knowledge Layer (injected into system prompt)

## Verification
- [ ] AI can search exercises and return relevant results
- [ ] AI can create a new exercise from user description
- [ ] Tool call failure shows error in chat, doesn't crash
- [ ] Max 5 tool calls enforced, AI responds after
- [ ] Session context includes correct exercise counts
- [ ] Knowledge files injected at session start
- [ ] Streaming pauses correctly during tool execution, resumes after
