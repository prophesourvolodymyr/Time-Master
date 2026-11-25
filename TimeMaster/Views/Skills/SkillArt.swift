import Foundation

enum SkillArt {
    static let assetPrefix = "skillart_"

    static let available: Set<String> = loadIndex()

    static func slug(forTitle title: String) -> String {
        var parts: [String] = []
        var current = ""
        for scalar in title.lowercased().unicodeScalars {
            if scalar.isASCII, (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9") {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts.joined(separator: "-")
    }

    static func assetName(forTitle title: String) -> String? {
        assetName(forTitle: title, available: available)
    }

    static func assetName(forTitle title: String, available: Set<String>) -> String? {
        let slug = slug(forTitle: title)
        return !slug.isEmpty && available.contains(slug) ? assetPrefix + slug : nil
    }

    static func assetName(for page: ExercisePage) -> String? {
        page.isSkillLike ? assetName(forTitle: page.title) : nil
    }

    private static func loadIndex() -> Set<String> {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "skillart_index", withExtension: "json", subdirectory: "SkillArt")
                ?? bundle.url(forResource: "skillart_index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let slugs = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(slugs)
    }
}
