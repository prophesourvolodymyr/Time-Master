# F07-B — Notification Pipeline

Human-toned motivational and reminder notifications. No robotic "Time to work out." Messages feel personal, warm, and encouraging.

## What We Build

### Notification Types
- **Workout reminders:** "Hey — your arms called. They want you back. 💪" Based on workout schedule from F07-C.
- **Streak motivation:** "7 days on fire 🔥 One more and you beat your record." Triggered near streak milestones.
- **Missed day nudge:** "No sweat. Tomorrow's a fresh day. We'll be here. 🙂" When user misses a scheduled workout.
- **Achievement:** "You just hit 50 workouts. That's not nothing — that's consistency. 🏆"
- **Rest day affirmation:** "Rest is training too. Enjoy it. 🛌" On scheduled rest days.
- **Custom reminder:** User can set a one-time reminder with custom message.

### Tone Rules
- No exclamation marks unless truly exciting
- Casual, conversational — like a coach texting you
- Lowercase where natural
- Emoji used sparingly (1 max per message)
- Never guilt-trip — always encouraging
- Use user's name if available

### Scheduling
- Workout reminders: 15 min before scheduled time
- Streak: after workout completion, if milestone reached
- Missed day: 1 hour after scheduled time passes with no workout
- Achievement: immediately after milestone workout
- Rest day: morning of rest day
- Notification permissions requested with a friendly onboarding prompt

## Architecture
```
Utilities/
└── NotificationManager.swift       — expand: scheduling, content templates, tone engine

Views/Settings/
└── WorkoutRemindersView.swift      — existing, expand with notification preferences
```

## Files
- `TimeMaster/Utilities/NotificationManager.swift` (modify)
- `TimeMaster/Views/Settings/WorkoutRemindersView.swift` (modify)

## Verification
- [ ] Workout reminder fires at scheduled time with human tone
- [ ] Streak motivation fires at milestones (7, 14, 30, 50, 100)
- [ ] Missed day nudge fires, no guilt language
- [ ] Achievement notification fires at 10, 25, 50, 100 workouts
- [ ] Rest day affirmation fires on scheduled rest days
- [ ] All messages follow tone rules (casual, encouraging, no spam)
- [ ] Notification permissions requested with friendly prompt
- [ ] compiles without errors
