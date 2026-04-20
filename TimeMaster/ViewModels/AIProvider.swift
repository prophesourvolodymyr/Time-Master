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
