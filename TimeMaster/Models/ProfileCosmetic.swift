import Foundation

enum ProfileCosmeticCategory: String, CaseIterable, Identifiable {
    case avatar, name, badge, entrance

    var id: String { rawValue }
    var title: String {
        switch self {
        case .avatar: return "Avatar rings"
        case .name: return "Name finishes"
        case .badge: return "Preview badge skins"
        case .entrance: return "Profile styles"
        }
    }
    var symbol: String {
        switch self {
        case .avatar: return "person.crop.circle"
        case .name: return "textformat"
        case .badge: return "shield.lefthalf.filled"
        case .entrance: return "rectangle.landscape"
        }
    }
    var detail: String {
        switch self {
        case .avatar: return "A frame around your actual profile photo. Your avatar stays yours."
        case .name: return "A readable finish for your display name. It changes appearance only."
        case .badge: return "A finish for an explicitly labeled badge preview. It grants no verification or eligibility. Enable a tier preview in Verification to show it on your profile."
        case .entrance: return "A static decorative treatment for your profile banner. Your photo stays underneath."
        }
    }
}

struct ProfileCosmetic: Identifiable, Hashable {
    let id: String
    let title: String
    let category: ProfileCosmeticCategory
    let variant: Int

    static let catalog: [Self] = {
        let names = [
            ["Time orbit", "Split second", "Solar pace"],
            ["Silver lining", "White heat", "Afterglow"],
            ["Brushed", "Outline", "Ember"],
            ["Time horizon", "Track lines", "Daybreak"]
        ]
        return ProfileCosmeticCategory.allCases.enumerated().flatMap { index, category in
            (0..<3).map { variant in
                Self(id: "timemaster-\(category.rawValue)-\(variant)", title: names[index][variant], category: category, variant: variant)
            }
        }
    }()

    static func selected(_ category: ProfileCosmeticCategory, in snapshot: LocalProfileSnapshot) -> Self? {
        guard let id = snapshot.cosmeticSelections[category.rawValue] else { return nil }
        return catalog.first { $0.id == id && $0.category == category }
    }
}
