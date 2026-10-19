import Foundation

enum CollectibleCategory: String, CaseIterable, Identifiable {
    case avatar, name, badge, entrance

    var id: String { rawValue }
    var title: String {
        switch self {
        case .avatar: return "Icon rings"
        case .name: return "Name styles"
        case .badge: return "Preview badge skins"
        case .entrance: return "Profile styles"
        }
    }
    var symbol: String {
        switch self {
        case .avatar: return "person.crop.circle"
        case .name: return "textformat"
        case .badge: return "shield.lefthalf.filled"
        case .entrance: return "rectangle.portrait.on.rectangle.portrait"
        }
    }
    var subtitle: String {
        switch self {
        case .avatar: return "A little orbit. All yours."
        case .name: return "Put your name in a different light."
        case .badge: return "A cosmetic preview. No verification granted."
        case .entrance: return "Make an entrance."
        }
    }
}

struct CollectibleItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: CollectibleCategory
    let variant: Int
    let season: Int
    let detail: String

    static func selected(_ category: CollectibleCategory, in snapshot: LocalProfileSnapshot) -> Self? {
        guard let id = snapshot.cosmeticSelections[category.rawValue] else { return nil }
        return CollectibleCatalog.items.first { $0.id == id && $0.category == category }
    }
}

enum CollectibleCatalog {
    static let season = 1
    static let seasonName = "First light"
    static let items: [CollectibleItem] = {
        let names = [["Orbit", "Prism", "Solar flare"], ["Silver lining", "Iridescent", "Afterglow"], ["Platinum", "Opal", "Molten"], ["Event horizon", "Refraction", "Sunrise"]]
        let descriptions = [
            "An animated rim around your profile icon. Your own avatar stays at the center, everywhere this local profile is shown.",
            "A moving finish across your display name. Your name stays readable, and the animation becomes a still finish with Reduce Motion.",
            "A cosmetic finish for an explicitly labeled badge preview. Enable a tier preview in Verification to show it on your profile. It never changes statistics, verification, or eligibility.",
            "A short arrival animation for your local profile. It plays once, then gets out of the way."
        ]
        var result: [CollectibleItem] = []
        for (index, category) in CollectibleCategory.allCases.enumerated() {
            for variant in 0..<3 {
                result.append(CollectibleItem(id: "timemaster-\(category.rawValue)-\(variant)", name: names[index][variant], category: category, variant: variant, season: 1, detail: descriptions[index]))
            }
            result.append(CollectibleItem(id: "s0-\(category.rawValue)", name: ["Origin", "Monochrome", "Founder's silver", "Awakening"][index], category: category, variant: 0, season: 0, detail: descriptions[index]))
        }
        return result
    }()

    static func item(_ id: String) -> CollectibleItem? { items.first { $0.id == id } }
}
