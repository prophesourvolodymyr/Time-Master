#if canImport(FoundationModels)
import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
struct OnDeviceTool: Tool {
    typealias Arguments = GeneratedContent
    typealias Output = String

    let name: String
    let description: String
    let parameters: GenerationSchema
    let run: @Sendable (String, String) async throws -> String

    func call(arguments: GeneratedContent) async throws -> String {
        try await run(name, arguments.jsonString)
    }
}

@available(iOS 26.0, macOS 26.0, *)
enum OnDeviceSchema {
    static func tool(for tool: AgentTool, parameters allowed: [String], run: @escaping @Sendable (String, String) async throws -> String) throws -> OnDeviceTool {
        let schema = tool.coachSchema
        let known = schema["properties"] as? [String: [String: Any]] ?? [:]
        let root = object(
            name: tool.name,
            properties: known.filter { allowed.contains($0.key) },
            required: (schema["required"] as? [String] ?? []).filter { allowed.contains($0) }
        )
        return OnDeviceTool(
            name: tool.name,
            description: brief(tool.summary, limit: 110) ?? tool.name,
            parameters: try GenerationSchema(root: root, dependencies: []),
            run: run
        )
    }

    private static func object(name: String, properties: [String: [String: Any]], required: [String]) -> DynamicGenerationSchema {
        let members = properties.keys.sorted().map { key -> DynamicGenerationSchema.Property in
            let spec = properties[key] ?? [:]
            return DynamicGenerationSchema.Property(
                name: key,
                description: brief(spec["description"] as? String, limit: 60),
                schema: node(name: "\(name)_\(key)", spec: spec),
                isOptional: !required.contains(key)
            )
        }
        return DynamicGenerationSchema(name: name, properties: members)
    }

    private static func node(name: String, spec: [String: Any]) -> DynamicGenerationSchema {
        switch spec["type"] as? String {
        case "integer":
            return DynamicGenerationSchema(type: Int.self)
        case "number":
            return DynamicGenerationSchema(type: Double.self)
        case "boolean":
            return DynamicGenerationSchema(type: Bool.self)
        case "array":
            let item = spec["items"] as? [String: Any] ?? ["type": "string"]
            return DynamicGenerationSchema(arrayOf: node(name: "\(name)_item", spec: item))
        case "object":
            let properties = spec["properties"] as? [String: [String: Any]] ?? [:]
            return object(name: name, properties: properties, required: spec["required"] as? [String] ?? [])
        default:
            if let choices = spec["enum"] as? [String], !choices.isEmpty {
                return DynamicGenerationSchema(name: name, anyOf: choices)
            }
            return DynamicGenerationSchema(type: String.self)
        }
    }

    static func brief(_ text: String?, limit: Int) -> String? {
        guard let text else { return nil }
        let first = text.components(separatedBy: ". ").first ?? text
        let flat = first.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !flat.isEmpty else { return nil }
        return flat.count > limit ? String(flat.prefix(limit)).trimmingCharacters(in: .whitespaces) : flat
    }
}
#endif
