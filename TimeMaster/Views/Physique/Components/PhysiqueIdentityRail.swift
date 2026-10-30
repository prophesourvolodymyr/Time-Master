import SwiftUI
import CoreText

struct PhysiqueIdentityRail: View {
    let identity: PhysiqueIdentity
    let ownerLabel: String
    let onBadge: (PhysiqueBadge) -> Void
    let newBadgeIDs: Set<String>

    init(identity: PhysiqueIdentity, ownerLabel: String, newBadgeIDs: Set<String> = [], onBadge: @escaping (PhysiqueBadge) -> Void) {
        self.identity = identity
        self.ownerLabel = ownerLabel
        self.onBadge = onBadge
        self.newBadgeIDs = newBadgeIDs
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.locale) private var locale
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var country: CountryMark?

    private var countryKey: CountryKey {
        CountryKey(code: identity.countryCode ?? "", locale: locale.identifier)
    }

    private var visibleCountry: CountryMark? {
        guard !countryKey.code.isEmpty else { return nil }
        if let country, country.key == countryKey { return country }
        return CountryMark(key: countryKey, name: Self.countryName(code: countryKey.code, locale: locale) ?? "Region unavailable", flag: nil)
    }

    private var orderedBadges: [PhysiqueBadge] {
        identity.badges.enumerated().sorted {
            let first = Self.catalogOrder($0.element.id)
            let second = Self.catalogOrder($1.element.id)
            return first == second ? $0.offset < $1.offset : first < second
        }.map(\.element)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    PhysiqueIdentityStripes()
                        .fill(Theme.toolbarOrange)
                        .frame(width: 18, height: 11)
                        .accessibilityHidden(true)
                    Text(ownerLabel)
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.toolbarOrange)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    Rectangle()
                        .fill(Theme.textPrimary.opacity(contrast == .increased ? 0.5 : 0.16))
                        .frame(minWidth: 8, maxWidth: .infinity)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(identity.displayName)
                            .font(TimeMasterFont.black(24, relativeTo: .title2))
                        if let country = visibleCountry {
                            countryLabel(country)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(identity.displayName)
                            .font(TimeMasterFont.black(24, relativeTo: .title2))
                            .fixedSize(horizontal: false, vertical: true)
                        if let country = visibleCountry {
                            countryLabel(country)
                        }
                    }
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(identityAccessibilityLabel)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 3) {
                if identity.games == 0 {
                    Text("Unplaced")
                        .font(TimeMasterFont.body())
                        .foregroundStyle(secondaryInk)
                } else if identity.games > 0 {
                    if let rating = identity.rating {
                        Text("Physique Elo \(rating.formatted())")
                            .font(TimeMasterFont.rowTitle().monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    } else {
                        Text("Physique Elo unavailable")
                            .font(TimeMasterFont.body())
                            .foregroundStyle(secondaryInk)
                    }
                    if identity.games < 5 {
                        Text(identity.placementLabel)
                            .font(TimeMasterFont.secondary())
                            .foregroundStyle(secondaryInk)
                    }
                } else {
                    Text("Placement unavailable")
                        .font(TimeMasterFont.body())
                        .foregroundStyle(secondaryInk)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)

            if !identity.badges.isEmpty {
                PhysiqueBadgeFlow(
                    singleColumn: dynamicTypeSize.isAccessibilitySize,
                    layoutDirection: layoutDirection
                ) {
                    ForEach(orderedBadges) { badge in
                        Button {
                            onBadge(badge)
                        } label: {
                            PhysiqueRailBadgeLabel(
                                badge: badge,
                                title: badgeTitle(badge),
                                tierUnavailable: badge.id == "placed" && identity.tier?.isEmpty != false,
                                isNew: newBadgeIDs.contains(badge.id)
                            )
                            .accessibilityHidden(true)
                        }
                        .accessibilityLabel(badgeAccessibilityLabel(badge))
                        .accessibilityValue(newBadgeIDs.contains(badge.id) ? "Newly earned in this match" : "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Shows this badge's meaning for \(ownerLabel).")
                        .accessibilityInputLabels([
                            Text("\(ownerLabel) \(badgeTitle(badge))"),
                            Text(badgeTitle(badge))
                        ])
                        .help("\(ownerLabel): \(badgeTitle(badge))")
                        .buttonStyle(PhysiqueBadgeButtonStyle())
                    }
                }
            }

            if let streak = identity.streak, streak > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("—")
                        .foregroundStyle(secondaryInk)
                        .accessibilityHidden(true)
                    Text("Win streak \(streak.formatted())")
                        .foregroundStyle(secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(TimeMasterFont.secondary().monospacedDigit())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(ownerLabel), current Physique win streak")
                .accessibilityValue("\(streak.formatted()) consecutive rated \(streak == 1 ? "win" : "wins")")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .task(id: countryKey) {
            country = Self.makeCountryMark(key: countryKey, locale: locale)
        }
    }

    private var secondaryInk: Color {
        contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary
    }

    private var identityAccessibilityLabel: String {
        let name = "\(ownerLabel), \(identity.displayName)"
        guard let country = visibleCountry else { return name }
        return "\(name), \(country.name), self-declared country or region"
    }

    @ViewBuilder
    private func countryLabel(_ country: CountryMark) -> some View {
        if let flag = country.flag {
            Text(flag)
                .font(.title3)
                .help("\(country.name), self-declared country or region")
        } else {
            Label(country.name, systemImage: "globe")
                .font(TimeMasterFont.secondary())
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func badgeTitle(_ badge: PhysiqueBadge) -> String {
        badge.title.isEmpty ? "Badge name unavailable" : badge.title
    }

    private func badgeAccessibilityLabel(_ badge: PhysiqueBadge) -> String {
        if badge.id == "placed" {
            if let tier = identity.tier, !tier.isEmpty {
                return "\(ownerLabel), Placed badge, current Physique tier \(tier)"
            }
            return "\(ownerLabel), Placed badge, tier unavailable"
        }
        if badge.id == "threeStraight" {
            return "\(ownerLabel), \(badgeTitle(badge)), earned, historical three-win milestone"
        }
        return "\(ownerLabel), \(badgeTitle(badge)), earned"
    }

    private static func catalogOrder(_ id: String) -> Int {
        switch id {
        case "placed": return 0
        case "firstBell": return 1
        case "tenRounds": return 2
        case "threeStraight": return 3
        default: return 4
        }
    }

    private static let supportedCountryCodes = Set(Locale.Region.isoRegions.map(\.identifier))

    private static func countryName(code: String, locale: Locale) -> String? {
        let code = code.uppercased()
        guard code.utf8.count == 2,
              code.utf8.allSatisfy({ (65...90).contains($0) }),
              supportedCountryCodes.contains(code) else { return nil }
        return locale.localizedString(forRegionCode: code)
            ?? Locale(identifier: "en").localizedString(forRegionCode: code)
    }

    private static func makeCountryMark(key: CountryKey, locale: Locale) -> CountryMark? {
        guard !key.code.isEmpty else { return nil }
        let code = key.code.uppercased()
        guard let name = countryName(code: code, locale: locale) else {
            return CountryMark(key: key, name: "Region unavailable", flag: nil)
        }
        let flag = String(String.UnicodeScalarView(code.unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value) }))
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 20, nil)
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: flag, attributes: attributes) as CFAttributedString)
        guard CTLineGetGlyphCount(line) == 1,
              let run = (CTLineGetGlyphRuns(line) as! [CTRun]).first else {
            return CountryMark(key: key, name: name, flag: nil)
        }
        var glyph: CGGlyph = 0
        CTRunGetGlyphs(run, CFRange(location: 0, length: 1), &glyph)
        return CountryMark(key: key, name: name, flag: glyph == 0 ? nil : flag)
    }

    private struct CountryKey: Hashable {
        let code: String
        let locale: String
    }

    private struct CountryMark {
        let key: CountryKey
        let name: String
        let flag: String?
    }
}

private struct PhysiqueIdentityStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<3 {
            let x = rect.minX + CGFloat(index) * rect.width * 0.32
            path.move(to: CGPoint(x: x + rect.width * 0.14, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.width * 0.32, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.width * 0.18, y: rect.maxY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct PhysiqueRailBadgeLabel: View {
    let badge: PhysiqueBadge
    let title: String
    let tierUnavailable: Bool
    let isNew: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
        layout {
            PhysiqueBadgeMedallion(badge: badge, isNew: isNew)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                if isNew {
                    Text("New")
                        .font(TimeMasterFont.black(12, relativeTo: .caption))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.toolbarOrange)
                }
                if tierUnavailable {
                    Text("Tier unavailable")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(contrast == .increased ? Theme.textPrimary : ProfileStyle.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
    }
}

private struct PhysiqueBadgeFlow: Layout {
    let singleColumn: Bool
    let layoutDirection: LayoutDirection
    private let spacing: CGFloat = 8

    struct Cache {
        var idealSizes: [CGSize]
        var sizes: [CGSize] = []
        var origins: [CGPoint] = []
        var width: CGFloat?
        var singleColumn = false
        var height: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(idealSizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.idealSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.width = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        arrange(width: proposal.width, subviews: subviews, cache: &cache)
        return CGSize(width: cache.width ?? 0, height: cache.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        arrange(width: bounds.width, subviews: subviews, cache: &cache)
        for index in subviews.indices {
            let origin = cache.origins[index]
            let size = cache.sizes[index]
            let x = layoutDirection == .rightToLeft
                ? bounds.maxX - origin.x - size.width
                : bounds.minX + origin.x
            subviews[index].place(
                at: CGPoint(x: x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func arrange(width proposedWidth: CGFloat?, subviews: Subviews, cache: inout Cache) {
        let intrinsicWidth = cache.idealSizes.reduce(0) { $0 + $1.width }
            + spacing * CGFloat(max(0, subviews.count - 1))
        let width = max(0, proposedWidth.flatMap { $0.isFinite ? $0 : nil } ?? intrinsicWidth)
        guard cache.width != width || cache.singleColumn != singleColumn else { return }
        cache.width = width
        cache.singleColumn = singleColumn
        cache.sizes.removeAll(keepingCapacity: true)
        cache.origins.removeAll(keepingCapacity: true)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for index in subviews.indices {
            let itemWidth = singleColumn ? width : min(width, cache.idealSizes[index].width)
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            let size = CGSize(width: min(width, measured.width), height: measured.height)
            if x > 0 && (singleColumn || x + size.width > width) {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            cache.origins.append(CGPoint(x: x, y: y))
            cache.sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        cache.height = y + rowHeight
    }
}

private struct PhysiqueBadgeButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        let shape = PhysiqueBadgeHitArea()
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .padding(.leading, 2)
            .padding(.trailing, ProfileStyle.spacing)
            .padding(.vertical, 4)
            #if os(macOS)
            .frame(minWidth: 32, minHeight: 32, alignment: .leading)
            #else
            .frame(minWidth: ProfileStyle.touchTarget, minHeight: ProfileStyle.touchTarget, alignment: .leading)
            #endif
            .background(shape.fill(configuration.isPressed || isFocused ? Theme.surface2 : .clear))
            .overlay {
                shape.strokeBorder(
                    isFocused ? Theme.toolbarOrange : Theme.textPrimary.opacity(contrast == .increased ? 0.5 : 0),
                    lineWidth: isFocused ? 2 : 1
                )
                .allowsHitTesting(false)
            }
            .contentShape(shape)
            .modifier(TimeMasterActionFeedback(isPressed: configuration.isPressed))
            .keyNavButtonSurface(.roundedRectangle(cornerRadius: 4))
    }
}

private struct PhysiqueBadgeHitArea: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> Self {
        var shape = self
        shape.insetAmount += amount
        return shape
    }

    func path(in rect: CGRect) -> Path {
        let field = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard field.width > 0, field.height > 0 else { return Path() }
        let cut = min(8, min(field.width, field.height) * 0.2)
        var path = Path()
        path.move(to: CGPoint(x: field.minX, y: field.minY))
        path.addLine(to: CGPoint(x: field.maxX - cut, y: field.minY))
        path.addLine(to: CGPoint(x: field.maxX, y: field.minY + cut))
        path.addLine(to: CGPoint(x: field.maxX, y: field.maxY))
        path.addLine(to: CGPoint(x: field.minX + cut, y: field.maxY))
        path.addLine(to: CGPoint(x: field.minX, y: field.maxY - cut))
        path.closeSubpath()
        return path
    }
}
