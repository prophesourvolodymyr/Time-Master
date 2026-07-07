import Foundation

public struct WorkoutType: Codable, Equatable, Hashable {
    public var id: String
    public var name: String
    public var iconName: String
    public var colorHex: String

    public static let strength = WorkoutType(id: "Strength", name: "Strength", iconName: "dumbbell.fill", colorHex: "FF9500")
    public static let stretch  = WorkoutType(id: "Stretch", name: "Stretch", iconName: "figure.cooldown", colorHex: "34C759")
    public static let cardio   = WorkoutType(id: "Cardio", name: "Cardio", iconName: "heart.fill", colorHex: "FF3B30")
    public static let hiit     = WorkoutType(id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55")
    public static let yoga     = WorkoutType(id: "Yoga", name: "Yoga", iconName: "figure.mind.and.body", colorHex: "AF52DE")
    public static let face     = WorkoutType(id: "Face", name: "Face", iconName: "face.smiling.fill", colorHex: "FFCC00")
    public static let other    = WorkoutType(id: "Other", name: "Other", iconName: "star.fill", colorHex: "007AFF")

    public static var builtIn: [WorkoutType] { [strength, stretch, cardio, hiit, yoga, face, other] }
    public static func all(custom: [WorkoutType] = []) -> [WorkoutType] { builtIn + custom }

    public init(id: String, name: String, iconName: String, colorHex: String = "FFFFFF") {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }
}
