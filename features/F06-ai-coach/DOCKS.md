# F06 — AI Coach

Multi-provider AI chat assistant for exercise naming, workout suggestions, and coaching advice.

## Sub-Features
- [x] **F06-A** — Text Selection (hold to select partial text, not just copy all)
- [ ] **F06-B** — AI Database Creation via tool-calling (depends on F09-D)

## ⚠️ F09 Migration Note
F06-B is superseded by F09-D (AI Tool Calling). The AI will create/query exercises through structured function calls via TimeMasterCore, not by writing files directly. Knowledge injection from F09-B replaces hardcoded system prompts.

## What We Build
- AICoachView: chat interface with message bubbles, reply/copy/attach actions
- AISettingsView: provider selection, API key entry, model picker
- AIProvider: protocol + provider registry (25 providers across 7 groups)
- AIStore: conversation management, message persistence
- ExerciseNamingService: AI-powered exercise name suggestions from photos
- ExerciseAISettingsView: AI naming toggle + provider config
- KeychainHelper: secure API key storage

## Architecture
```
Views/AICoach/
├── AICoachView.swift           — Chat UI with message list, input bar, streaming
└── AISettingsView.swift        — Provider picker, API key, model

ViewModels/
├── AIProvider.swift            — Protocol: OpenAI, Anthropic, Gemini, OpenRouter, Groq, xAI, Mistral, Cerebras, Together, Custom
└── AIStore.swift               — Conversation store, message history

Utilities/
├── ExerciseNamingService.swift — Photo → AI → exercise name
└── KeychainHelper.swift        — Secure API key storage

Views/Settings/
└── ExerciseAISettingsView.swift — AI naming settings
```

## States
| State | View | Behavior |
|-------|------|----------|
| no provider | AICoachView | "Configure an AI provider" prompt, links to settings |
| no API key | AISettingsView | Empty key field with placeholder |
| ready | AICoachView | Chat input active, "Send" button enabled |
| loading | AICoachView | Typing indicator, message streaming |
| error | AICoachView | Error bubble with retry button |
| empty | AICoachView | Welcome message, suggested prompts |

## Provider Groups
1. OpenAI (GPT-4o, GPT-4o-mini, GPT-4-turbo, GPT-3.5-turbo)
2. Anthropic (Claude 3 Opus, Sonnet, Haiku, Claude 3.5 Sonnet)
3. Google (Gemini Pro, Gemini Flash)
4. OpenRouter (aggregator — any model)
5. Groq (Llama 3, Mixtral on fast inference)
6. xAI (Grok)
7. Mistral / Cerebras / Together / Custom (user-defined endpoint)

## Files
- `TimeMaster/Views/AICoach/AICoachView.swift`
- `TimeMaster/Views/AICoach/AISettingsView.swift`
- `TimeMaster/ViewModels/AIProvider.swift`
- `TimeMaster/ViewModels/AIStore.swift`
- `TimeMaster/Utilities/ExerciseNamingService.swift`
- `TimeMaster/Utilities/KeychainHelper.swift`
- `TimeMaster/Views/Settings/ExerciseAISettingsView.swift`

## Dependencies
- F01 — Core Data Layer (Theme, KeychainHelper)

## Verification
- [x] Provider list shows all 25 providers across 7 groups
- [x] API key saves/loads from Keychain securely
- [x] Messages send and stream response from selected provider
- [x] Reply, copy, and attach actions work on messages
- [x] Exercise naming generates suggestions from photo input
- [x] Error handling shows retry-able error bubbles
- [x] Verified on iPhone 16 Pro Simulator / iOS 18.6: full build pass, 0 errors
