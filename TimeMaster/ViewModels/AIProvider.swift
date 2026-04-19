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
}

// MARK: - Provider Registry

extension AIProvider {

    static let openai = AIProvider(
        id:                 "openai",
        name:               "OpenAI",
        baseURL:            "https://api.openai.com/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["gpt-4o", "gpt-4o-mini", "o1", "o1-mini", "o3-mini", "gpt-4-turbo"],
        apiKeyHint:         "sk-…",
        iconName:           "brain.head.profile"
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
        iconName:           "a.circle.fill"
    )

    static let gemini = AIProvider(
        id:                 "gemini",
        name:               "Google Gemini",
        // Google exposes an OpenAI-compatible shim at this path
        baseURL:            "https://generativelanguage.googleapis.com/v1beta/openai",
        authStyle:          .bearer,
        supportsModelsList: false,  // shim doesn't implement /models
        knownModels:        ["gemini-2.0-flash", "gemini-2.0-flash-lite",
                             "gemini-1.5-pro", "gemini-1.5-flash"],
        apiKeyHint:         "AIza…",
        iconName:           "sparkles"
    )

    static let openrouter = AIProvider(
        id:                 "openrouter",
        name:               "OpenRouter",
        baseURL:            "https://openrouter.ai/api/v1",
        authStyle:          .bearer,
        supportsModelsList: true,   // returns 100s of models from all providers
        knownModels:        ["openai/gpt-4o", "anthropic/claude-sonnet-4-5",
                             "google/gemini-2.0-flash-001", "meta-llama/llama-3.3-70b-instruct"],
        apiKeyHint:         "sk-or-…",
        iconName:           "arrow.triangle.branch"
    )

    static let groq = AIProvider(
        id:                 "groq",
        name:               "Groq",
        baseURL:            "https://api.groq.com/openai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "gemma2-9b-it"],
        apiKeyHint:         "gsk_…",
        iconName:           "bolt.fill"
    )

    static let xai = AIProvider(
        id:                 "xai",
        name:               "xAI (Grok)",
        baseURL:            "https://api.x.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["grok-3", "grok-3-mini", "grok-2", "grok-2-mini"],
        apiKeyHint:         "xai-…",
        iconName:           "x.circle.fill"
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
        iconName:           "wind"
    )

    static let cerebras = AIProvider(
        id:                 "cerebras",
        name:               "Cerebras",
        baseURL:            "https://api.cerebras.ai/v1",
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        ["llama3.1-8b", "llama3.1-70b", "llama-4-scout-17b-16e-instruct"],
        apiKeyHint:         "csk-…",
        iconName:           "cpu.fill"
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
        iconName:           "person.3.fill"
    )

    /// Generic fallback for Ollama, LM Studio, or any custom OpenAI-compat endpoint.
    static let custom = AIProvider(
        id:                 "custom",
        name:               "Custom / Ollama",
        baseURL:            "",     // user supplies the full base URL
        authStyle:          .bearer,
        supportsModelsList: true,
        knownModels:        [],
        apiKeyHint:         "optional",
        iconName:           "wrench.and.screwdriver.fill"
    )

    static let all: [AIProvider] = [
        openai, anthropic, gemini, openrouter, groq, xai, mistral, cerebras, together, custom
    ]

    // MARK: - Auto-detect provider from API-key prefix

    /// Returns the most likely provider for the given API key prefix.
    /// Mirrors OpenCode's env-var→provider mapping logic.
    static func detect(apiKey: String) -> AIProvider? {
        // Order matters: more-specific prefixes before generic "sk-"
        if apiKey.hasPrefix("sk-ant-")  { return anthropic   }
        if apiKey.hasPrefix("sk-or-")   { return openrouter  }
        if apiKey.hasPrefix("sk-proj-") { return openai      }
        if apiKey.hasPrefix("sk-")      { return openai      }
        if apiKey.hasPrefix("xai-")     { return xai         }
        if apiKey.hasPrefix("gsk_")     { return groq        }
        if apiKey.hasPrefix("AIza")     { return gemini      }
        if apiKey.hasPrefix("csk-")     { return cerebras    }
        return nil
    }
}
