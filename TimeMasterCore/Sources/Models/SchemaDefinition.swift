import Foundation

public struct SchemaDefinition: Codable {
    public var version: String
    public var objects: [String: ObjectSchema]
    public var tools: [ToolSchema]
    public var filesystem: FilesystemSchema

    public init(
        version: String = "1.0.0",
        objects: [String: ObjectSchema] = [:],
        tools: [ToolSchema] = [],
        filesystem: FilesystemSchema = FilesystemSchema()
    ) {
        self.version = version
        self.objects = objects
        self.tools = tools
        self.filesystem = filesystem
    }
}

public struct ObjectSchema: Codable {
    public var description: String
    public var folderPath: String
    public var manifestName: String
    public var required: [String]
    public var properties: [String: PropertySchema]

    public init(
        description: String,
        folderPath: String,
        manifestName: String = "manifest.json",
        required: [String] = [],
        properties: [String: PropertySchema] = [:]
    ) {
        self.description = description
        self.folderPath = folderPath
        self.manifestName = manifestName
        self.required = required
        self.properties = properties
    }
}

public struct PropertySchema: Codable {
    public var type: String
    public var description: String
    public var format: String?
    public var optional: Bool

    public init(
        type: String,
        description: String,
        format: String? = nil,
        optional: Bool = false
    ) {
        self.type = type
        self.description = description
        self.format = format
        self.optional = optional
    }
}

public struct ToolSchema: Codable {
    public var name: String
    public var description: String
    public var write: Bool
    public var parameters: [String: PropertySchema]

    public init(
        name: String,
        description: String,
        write: Bool = false,
        parameters: [String: PropertySchema] = [:]
    ) {
        self.name = name
        self.description = description
        self.write = write
        self.parameters = parameters
    }
}

public struct FilesystemSchema: Codable {
    public var root: String
    public var directories: [String: String]

    public init(
        root: String = "TimeMaster",
        directories: [String: String] = [:]
    ) {
        self.root = root
        self.directories = directories
    }
}
