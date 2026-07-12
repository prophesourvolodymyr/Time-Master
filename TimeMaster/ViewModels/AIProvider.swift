import Foundation

// MARK: - AIProvider

/// Describes a known AI provider: endpoint, auth style, and known model list.
/// Mirrors how OpenCode's models.dev registry works, but as a static Swift type.
struct AIProvider: Identifiable, Equatable {

    enum AuthStyle: Equatable {
        /// Authorization: Bearer <key>  — all OpenAI-compatible providers
        case bearer
        /// x-api-key: <key> + anthropic-version header  — Anthropic Messages API
        case xApiKey
    }

    let id: String
    let name: String
    /// API base already including version prefix (e.g. /v1).
    /// Chat: append /chat/completions (bearer) or /messages (xApiKey).
    /// Models: append /models.
    let baseURL: String
    let authStyle: AuthStyle
    /// Whether GET {baseURL}/models returns a standard { data:[{id}] } list.
    let supportsModelsList: Bool
    /// Hardcoded fallback shown before a live fetch or when fetch is unsupported.
    let knownModels: [String]
    let apiKeyHint: String
    let iconName: String    // SF Symbol
    /// Section label used in the provider picker sheet.
    let group: String
}

// MARK: - Provider Registry

extension AIProvider {

    // MARK: OpenCode

    static let opencodeZen = AIProvider(
        id:                 "opencode",
        name:               "OpenCode Zen",
        baseURL:            "https://opencode.ai/zen/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["anthropic/claude-sonnet-4-5", "openai/gpt-4o",
                             "google/gemini-2.0-flash"],
        apiKeyHint:         "opencode-…",
        iconName:           "atom",
        group:              "OpenCode"
    )

    static let opencodeGo = AIProvider(
        id:                 "opencode-go",
        name:               "OpenCode Go",
        baseURL:            "https://opencode.ai/zen/go/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["anthropic/claude-sonnet-4-5", "openai/gpt-4o"],
        apiKeyHint:         "opencode-…",
        iconName:           "hare.fill",
        group:              "OpenCode"
    )

    // MARK: AI Labs

    static let openai = AIProvider(
        id:                 "openai",
        name:               "OpenAI",
        baseURL:            "https://api.openai.com/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["gpt-4o", "gpt-4o-mini", "o1", "o1-mini", "o3-mini", "gpt-4-turbo"],
        apiKeyHint:         "sk-…",
        iconName:           "brain.head.profile",
        group:              "AI Labs"
    )

    static let anthropic = AIProvider(
        id:                 "anthropic",
        name:               "Anthropic",
        baseURL:            "https://api.anthropic.com/v1",
        authStyle:          .xApiKey,
        supportsModelsList: true,
        knownModels:        ["claude-opus-4-5", "claude-sonnet-4-5", "claude-haiku-4-5",
                             "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"],
        apiKeyHint:         "sk-ant-…",
        iconName:           "a.circle.fill",
        group:              "AI Labs"
    )

    static let gemini = AIProvider(
        id:                 "gemini",
        name:               "Google Gemini",
        baseURL:            "https://generativelanguage.googleapis.com/v1beta/openai",
        authStyle:          .bearer,
        supportsModelsList: false,
        knownModels:        ["gemini-2.0-flash", "gemini-2.0-flash-lite",
                             "gemini-1.5-pro", "gemini-1.5-flash"],
        apiKeyHint:         "AIza…",
        iconName:           "sparkles",
        group:              "AI Labs"
    )

    static let xai = AIProvider(
        id:                 "xai",
        name:               "xAI (Grok)",
        baseURL:            "https://api.x.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["grok-3", "grok-3-mini", "grok-2", "grok-2-mini"],
        apiKeyHint:         "xai-…",
        iconName:           "x.circle.fill",
        group:              "AI Labs"
    )

    static let mistral = AIProvider(
        id:                 "mistral",
        name:               "Mistral AI",
        baseURL:            "https://api.mistral.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["mistral-large-latest", "mistral-medium-latest",
                             "mistral-small-latest", "codestral-latest"],
        apiKeyHint:         "…",
        iconName:           "wind",
        group:              "AI Labs"
    )

    static let cohere = AIProvider(
        id:                 "cohere",
        name:               "Cohere",
        baseURL:            "https://api.cohere.ai/compatibility/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["command-r-plus", "command-r", "command-light"],
        apiKeyHint:         "…",
        iconName:           "circle.hexagongrid.fill",
        group:              "AI Labs"
    )

    // MARK: Fast Inference

    static let groq = AIProvider(
        id:                 "groq",
        name:               "Groq",
        baseURL:            "https://api.groq.com/openai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "gemma2-9b-it"],
        apiKeyHint:         "gsk_…",
        iconName:           "bolt.fill",
        group:              "Fast Inference"
    )

    static let cerebras = AIProvider(
        id:                 "cerebras",
        name:               "Cerebras",
        baseURL:            "https://api.cerebras.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["llama3.1-8b", "llama3.1-70b", "llama-4-scout-17b-16e-instruct"],
        apiKeyHint:         "csk-…",
        iconName:           "cpu.fill",
        group:              "Fast Inference"
    )

    static let deepseek = AIProvider(
        id:                 "deepseek",
        name:               "DeepSeek",
        baseURL:            "https://api.deepseek.com/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["deepseek-chat", "deepseek-reasoner"],
        apiKeyHint:         "sk-…",
        iconName:           "eye.fill",
        group:              "Fast Inference"
    )

    static let together = AIProvider(
        id:                 "together",
        name:               "Together AI",
        baseURL:            "https://api.together.xyz/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta-llama/Llama-3.3-70B-Instruct-Turbo",
                             "mistralai/Mixtral-8x22B-Instruct-v0.1"],
        apiKeyHint:         "…",
        iconName:           "person.3.fill",
        group:              "Fast Inference"
    )

    static let fireworks = AIProvider(
        id:                 "fireworks-ai",
        name:               "Fireworks AI",
        baseURL:            "https://api.fireworks.ai/inference/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["accounts/fireworks/models/llama-v3p3-70b-instruct",
                             "accounts/fireworks/models/mixtral-8x22b-instruct"],
        apiKeyHint:         "fw_…",
        iconName:           "flame.fill",
        group:              "Fast Inference"
    )

    static let deepinfra = AIProvider(
        id:                 "deepinfra",
        name:               "DeepInfra",
        baseURL:            "https://api.deepinfra.com/v1/openai",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta-llama/Llama-3.3-70B-Instruct",
                             "mistralai/Mixtral-8x22B-Instruct-v0.1"],
        apiKeyHint:         "…",
        iconName:           "server.rack",
        group:              "Fast Inference"
    )

    // MARK: Routers

    static let openrouter = AIProvider(
        id:                 "openrouter",
        name:               "OpenRouter",
        baseURL:            "https://openrouter.ai/api/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["openai/gpt-4o", "anthropic/claude-sonnet-4-5",
                             "google/gemini-2.0-flash-001", "meta-llama/llama-3.3-70b-instruct"],
        apiKeyHint:         "sk-or-…",
        iconName:           "arrow.triangle.branch",
        group:              "Routers"
    )

    static let huggingface = AIProvider(
        id:                 "huggingface",
        name:               "HuggingFace",
        baseURL:            "https://router.huggingface.co/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta-llama/Llama-3.3-70B-Instruct",
                             "mistralai/Mistral-7B-Instruct-v0.3"],
        apiKeyHint:         "hf_…",
        iconName:           "face.smiling.fill",
        group:              "Routers"
    )

    static let novita = AIProvider(
        id:                 "novita-ai",
        name:               "Novita AI",
        baseURL:            "https://api.novita.ai/openai",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta-llama/llama-3.1-70b-instruct",
                             "mistralai/mistral-7b-instruct"],
        apiKeyHint:         "…",
        iconName:           "arrow.2.circlepath.circle.fill",
        group:              "Routers"
    )

    // MARK: Search & Tools

    static let perplexity = AIProvider(
        id:                 "perplexity",
        name:               "Perplexity",
        baseURL:            "https://api.perplexity.ai",
        authStyle:          .bearer,
        supportsModelsList: false,
        knownModels:        ["llama-3.1-sonar-large-128k-online",
                             "llama-3.1-sonar-small-128k-online",
                             "llama-3.1-sonar-huge-128k-online"],
        apiKeyHint:         "pplx-…",
        iconName:           "magnifyingglass.circle.fill",
        group:              "Search & Tools"
    )

    static let moonshot = AIProvider(
        id:                 "moonshotai",
        name:               "Moonshot (Kimi)",
        baseURL:            "https://api.moonshot.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
        apiKeyHint:         "sk-…",
        iconName:           "moon.fill",
        group:              "Search & Tools"
    )

    // MARK: Cloud Platforms

    static let githubModels = AIProvider(
        id:                 "github-models",
        name:               "GitHub Models",
        baseURL:            "https://models.github.ai/inference",
        authStyle:          .bearer,
        supportsModelsList: false,
        knownModels:        ["openai/gpt-4o", "meta/llama-3.3-70b-instruct",
                             "mistral-ai/mistral-large-2411"],
        apiKeyHint:         "ghp_… or github_pat_…",
        iconName:           "chevron.left.forwardslash.chevron.right",
        group:              "Cloud Platforms"
    )

    static let nvidia = AIProvider(
        id:                 "nvidia",
        name:               "NVIDIA NIM",
        baseURL:            "https://integrate.api.nvidia.com/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta/llama-3.3-70b-instruct",
                             "nvidia/llama-3.1-nemotron-70b-instruct"],
        apiKeyHint:         "nvapi-…",
        iconName:           "gamecontroller.fill",
        group:              "Cloud Platforms"
    )

    static let friendli = AIProvider(
        id:                 "friendli",
        name:               "Friendli AI",
        baseURL:            "https://api.friendli.ai/serverless/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["meta-llama-3.3-70b-instruct", "mixtral-8x7b-instruct-v0-1"],
        apiKeyHint:         "flp_…",
        iconName:           "person.wave.2.fill",
        group:              "Cloud Platforms"
    )

    static let scaleway = AIProvider(
        id:                 "scaleway",
        name:               "Scaleway AI",
        baseURL:            "https://api.scaleway.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["llama-3.3-70b-instruct", "mistral-nemo-instruct-2407"],
        apiKeyHint:         "…",
        iconName:           "cloud.fill",
        group:              "Cloud Platforms"
    )

    // MARK: Local

    static let lmstudio = AIProvider(
        id:                 "lmstudio",
        name:               "LM Studio",
        baseURL:            "http://127.0.0.1:1234/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        [],
        apiKeyHint:         "optional",
        iconName:           "desktopcomputer",
        group:              "Local"
    )

    /// Generic fallback for Ollama, LM Studio, or any custom OpenAI-compat endpoint.
    static let custom = AIProvider(
        id:                 "custom",
        name:               "Custom / Ollama",
        baseURL:            "",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        [],
        apiKeyHint:         "optional",
        iconName:           "wrench.and.screwdriver.fill",
        group:              "Local"
    )

    // MARK: - Registry

    static let all: [AIProvider] = [
        // OpenCode
        opencodeZen, opencodeGo,
        // AI Labs
        openai, anthropic, gemini, xai, mistral, cohere,
        // Fast Inference
        groq, cerebras, deepseek, together, fireworks, deepinfra,
        // Routers
        openrouter, huggingface, novita,
        // Search & Tools
        perplexity, moonshot,
        // Cloud Platforms
        githubModels, nvidia, friendli, scaleway,
        // Local
        lmstudio, custom
    ]

    /// Providers grouped by their `group` label, preserving insertion order.
    static var grouped: [(group: String, providers: [AIProvider])] {
        var groupOrder: [String] = []
        var groupMap: [String: [AIProvider]] = [:]
        for p in all {
            if groupMap[p.group] == nil {
                groupOrder.append(p.group)
                groupMap[p.group] = []
            }
            groupMap[p.group]!.append(p)
        }
        return groupOrder.map { (group: $0, providers: groupMap[$0]!) }
    }

    // MARK: - Auto-detect provider from API-key prefix

    // MARK: - Tool Schemas

    static var toolDefinitions: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "search_exercises",
                    "description": "Search the exercise database by name, type, or keyword. Returns matching exercises with ID, name, type, and duration.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": ["type": "string", "description": "Search query (name or keyword)"],
                            "type": ["type": "string", "description": "Filter by workout type: Strength, Stretch, Cardio, HIIT, Yoga, Face, Other"],
                        ],
                        "required": ["query"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_exercise",
                    "description": "Get full details for a specific exercise by its ID, including guide content and links.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string", "description": "Exercise ID (UUID)"],
                            "parentID": ["type": "string", "description": "Parent folder path if exercise is nested"],
                        ],
                        "required": ["id"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "list_folders",
                    "description": "List sub-folders in the Exercises Database (progressions, categories).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "parentID": ["type": "string", "description": "Parent folder path (optional, root if omitted)"],
                        ],
                        "required": [],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_exercise",
                    "description": "Create a new exercise in the database. Generates an ID and saves the manifest with guide.md.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Exercise name"],
                            "type": ["type": "string", "description": "Workout type: Strength, Stretch, Cardio, HIIT, Yoga, Face, Other"],
                            "duration": ["type": "integer", "description": "Duration in seconds (default 30)"],
                            "restAfter": ["type": "integer", "description": "Rest after exercise in seconds (default 10)"],
                            "parentID": ["type": "string", "description": "Parent folder to place exercise in"],
                            "details": ["type": "string", "description": "Exercise description/instructions"],
                            "sets": ["type": "integer", "description": "Default number of sets"],
                            "mediaFilenames": ["type": "array", "items": ["type": "string"], "description": "Media filenames to attach"],
                            "linkURLs": ["type": "array", "items": ["type": "string"], "description": "External link URLs"],
                        ],
                        "required": ["name"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_folder",
                    "description": "Create a new folder in the Exercises Database (progression, category, or grouping).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Folder name"],
                            "parentID": ["type": "string", "description": "Parent folder path (optional)"],
                        ],
                        "required": ["name"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_recent_workouts",
                    "description": "Get recently completed workout entries from history.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "days": ["type": "integer", "description": "Number of days to look back (default 7)"],
                        ],
                        "required": [],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "build_workout",
                    "description": "Build a workout plan from exercise IDs. Creates a new workout manifest with sections.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string", "description": "Workout name"],
                            "type": ["type": "string", "description": "Workout type: Strength, Stretch, Cardio, HIIT, Yoga, Face, Other"],
                            "restBetweenSections": ["type": "integer", "description": "Rest between sections in seconds (default 30)"],
                            "sections": [
                                "type": "array",
                                "description": "Array of section objects with exerciseID, name, duration, sets, restBetweenSets, prepareTime",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "exerciseID": ["type": "string", "description": "ID of the exercise"],
                                        "name": ["type": "string", "description": "Section name"],
                                        "duration": ["type": "integer", "description": "Duration in seconds"],
                                        "sets": ["type": "integer", "description": "Number of sets"],
                                        "restBetweenSets": ["type": "integer", "description": "Rest between sets in seconds"],
                                        "prepareTime": ["type": "integer", "description": "Prepare time in seconds"],
                                    ],
                                    "required": ["exerciseID"],
                                ],
                            ],
                        ],
                        "required": ["name"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_stats",
                    "description": "Get overall workout statistics: total workouts, current streak, best streak, and total duration. No parameters needed.",
                    "parameters": [
                        "type": "object",
                        "properties": [:],
                        "required": [],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_analytics",
                    "description": "Get workout statistics: count, current streak, best streak, and total duration.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "type": ["type": "string", "description": "Filter by workout type (optional)"],
                            "days": ["type": "integer", "description": "Number of days to look back (optional, all time if omitted)"],
                        ],
                        "required": [],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "add_media_note",
                    "description": "Append a note to an exercise's guide.md file. Useful for adding observations, form tips, or progress notes.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "exerciseID": ["type": "string", "description": "ID of the exercise"],
                            "note": ["type": "string", "description": "Note content to append"],
                        ],
                        "required": ["exerciseID", "note"],
                    ],
                ],
            ],
        ]
    }

    /// Anthropic-format tool definitions (slightly different schema format).
    static var anthropicToolDefinitions: [[String: Any]] {
        [
            [
                "name": "search_exercises",
                "description": "Search the exercise database by name, type, or keyword. Returns matching exercises with ID, name, type, and duration.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query (name or keyword)"],
                        "type": ["type": "string", "description": "Filter by workout type: Strength, Stretch, Cardio, HIIT, Yoga, Face, Other"],
                    ],
                    "required": ["query"],
                ],
            ],
            [
                "name": "get_exercise",
                "description": "Get full details for a specific exercise by its ID, including guide content and links.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string", "description": "Exercise ID (UUID)"],
                        "parentID": ["type": "string", "description": "Parent folder path if exercise is nested"],
                    ],
                    "required": ["id"],
                ],
            ],
            [
                "name": "list_folders",
                "description": "List sub-folders in the Exercises Database (progressions, categories).",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "parentID": ["type": "string", "description": "Parent folder path (optional, root if omitted)"],
                    ],
                    "required": [],
                ],
            ],
            [
                "name": "create_exercise",
                "description": "Create a new exercise in the database. Generates an ID and saves the manifest with guide.md.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Exercise name"],
                        "type": ["type": "string", "description": "Workout type: Strength, Stretch, Cardio, HIIT, Yoga, Face, Other"],
                        "duration": ["type": "integer", "description": "Duration in seconds (default 30)"],
                        "restAfter": ["type": "integer", "description": "Rest after exercise in seconds (default 10)"],
                        "parentID": ["type": "string", "description": "Parent folder to place exercise in"],
                        "details": ["type": "string", "description": "Exercise description/instructions"],
                        "sets": ["type": "integer", "description": "Default number of sets"],
                        "mediaFilenames": ["type": "array", "items": ["type": "string"], "description": "Media filenames to attach"],
                        "linkURLs": ["type": "array", "items": ["type": "string"], "description": "External link URLs"],
                    ],
                    "required": ["name"],
                ],
            ],
            [
                "name": "create_folder",
                "description": "Create a new folder in the Exercises Database (progression, category, or grouping).",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Folder name"],
                        "parentID": ["type": "string", "description": "Parent folder path (optional)"],
                    ],
                    "required": ["name"],
                ],
            ],
            [
                "name": "get_recent_workouts",
                "description": "Get recently completed workout entries from history.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "days": ["type": "integer", "description": "Number of days to look back (default 7)"],
                    ],
                    "required": [],
                ],
            ],
            [
                "name": "build_workout",
                "description": "Build a workout plan from exercise IDs. Creates a new workout manifest with sections.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string", "description": "Workout name"],
                        "type": ["type": "string", "description": "Workout type"],
                        "restBetweenSections": ["type": "integer", "description": "Rest between sections in seconds (default 30)"],
                        "sections": [
                            "type": "array",
                            "description": "Array of section objects",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "exerciseID": ["type": "string", "description": "ID of the exercise"],
                                    "name": ["type": "string", "description": "Section name"],
                                    "duration": ["type": "integer", "description": "Duration in seconds"],
                                    "sets": ["type": "integer", "description": "Number of sets"],
                                    "restBetweenSets": ["type": "integer", "description": "Rest between sets in seconds"],
                                    "prepareTime": ["type": "integer", "description": "Prepare time in seconds"],
                                ],
                                "required": ["exerciseID"],
                            ],
                        ],
                    ],
                    "required": ["name"],
                ],
            ],
            [
                "name": "get_stats",
                "description": "Get overall workout statistics: total workouts, current streak, best streak, and total duration. No parameters needed.",
                "input_schema": [
                    "type": "object",
                    "properties": [:],
                    "required": [],
                ],
            ],
            [
                "name": "get_analytics",
                "description": "Get workout statistics: count, current streak, best streak, and total duration.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "type": ["type": "string", "description": "Filter by workout type (optional)"],
                        "days": ["type": "integer", "description": "Number of days to look back (optional, all time if omitted)"],
                    ],
                    "required": [],
                ],
            ],
            [
                "name": "add_media_note",
                "description": "Append a note to an exercise's guide.md file.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "exerciseID": ["type": "string", "description": "ID of the exercise"],
                        "note": ["type": "string", "description": "Note content to append"],
                    ],
                    "required": ["exerciseID", "note"],
                ],
            ],
        ]
    }

    /// Returns the most likely provider for the given API key prefix.
    static func detect(apiKey: String) -> AIProvider? {
        if apiKey.hasPrefix("sk-ant-")      { return anthropic    }
        if apiKey.hasPrefix("sk-or-")       { return openrouter   }
        if apiKey.hasPrefix("sk-proj-")     { return openai       }
        if apiKey.hasPrefix("sk-")          { return openai       }
        if apiKey.hasPrefix("xai-")         { return xai          }
        if apiKey.hasPrefix("gsk_")         { return groq         }
        if apiKey.hasPrefix("AIza")         { return gemini       }
        if apiKey.hasPrefix("csk-")         { return cerebras     }
        if apiKey.hasPrefix("pplx-")        { return perplexity   }
        if apiKey.hasPrefix("hf_")          { return huggingface  }
        if apiKey.hasPrefix("nvapi-")       { return nvidia       }
        if apiKey.hasPrefix("github_pat_")  { return githubModels }
        if apiKey.hasPrefix("ghp_")         { return githubModels }
        if apiKey.hasPrefix("fw_")          { return fireworks    }
        if apiKey.hasPrefix("flp_")         { return friendli     }
        return nil
    }
}
