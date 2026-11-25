import SwiftUI
import TimeMasterCore

struct SkillTrainer: Identifiable {
    let page: ExercisePage
    let tier: SkillTier

    var id: String { page.manifest.id }
}

enum SkillTierStyle {
    static func color(_ tier: SkillTier) -> Color {
        switch tier {
        case .s: Color(hex: "FF5A5F")
        case .a: Color(hex: "FF9F43")
        case .b: Color(hex: "FFD93D")
        case .c: Color(hex: "5FD38D")
        case .d: Color(hex: "5AA9FF")
        }
    }
}

struct SkillTierBoardView: View {
    let skillID: String
    var embedded = false

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @State private var pickerTier: SkillTier?
    @State private var expanded: Set<SkillTier> = []

    private static let columnWidth: CGFloat = 264
    private static let collapsedCount = 6

    var body: some View {
        let trainers = store.trainers(of: skillID)
        Group {
            if embedded && trainers.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: SkillMetrics.s3) {
                    header(trainers.count)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: SkillMetrics.s3) {
                            ForEach(SkillTier.allCases, id: \.self) { tier in
                                column(tier, trainers.filter { $0.tier == tier })
                            }
                        }
                    }
                }
                .sheet(isPresented: Binding(get: { pickerTier != nil }, set: { if !$0 { pickerTier = nil } })) {
                    DatabasePageBrowserSheet(
                        workout: Workout(name: "Tiers"),
                        onAdd: { page, _, _, _, _, _, _ in
                            guard page.manifest.id != skillID else { return }
                            let tier = pickerTier ?? .c
                            SkillErrorCenter.shared.attempt("Add the exercise") {
                                try store.setTraining(page.manifest.id, skill: skillID, tier: tier)
                            }
                            pickerTier = nil
                        },
                        onAddBundle: { _, _, _, _, _, _, _ in }
                    )
                    .environmentObject(store)
                    .environmentObject(workoutStore)
                    .keyNavHost()
                }
            }
        }
    }

    @ViewBuilder
    private func header(_ count: Int) -> some View {
        if embedded {
            HStack(spacing: SkillMetrics.s2) {
                SkillSectionHeading(symbol: "rosette", title: "Trained by", count: count)
                addButton
            }
        } else {
            HStack(spacing: SkillMetrics.s2) {
                Text(summary(count))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                addButton
            }
        }
    }

    private var addButton: some View {
        Button { pickerTier = .c } label: {
            Label("Add exercise", systemImage: "plus")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .lineLimit(1)
        }
        .buttonStyle(TimeMasterActionButtonStyle(prominent: true, horizontalPadding: SkillMetrics.s4))
    }

    private func summary(_ count: Int) -> String {
        switch count {
        case 0: "No exercise trains this skill yet. Add one, or ask the assistant to fill the tiers from your library."
        case 1: "1 exercise trains this skill"
        default: "\(count) exercises train this skill"
        }
    }

    private func column(_ tier: SkillTier, _ items: [SkillTrainer]) -> some View {
        let color = SkillTierStyle.color(tier)
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius + 4, style: .continuous)
        let isExpanded = expanded.contains(tier)
        let shown = isExpanded ? items : Array(items.prefix(Self.collapsedCount))
        return VStack(alignment: .leading, spacing: SkillMetrics.s2) {
            HStack(spacing: SkillMetrics.s2) {
                Text(tier.title)
                    .font(TimeMasterFont.black(18, relativeTo: .title3))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(color))
                    .accessibilityLabel("Tier \(tier.title)")
                Text("\(items.count)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Button { pickerTier = tier } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(color.opacity(0.14)))
                        .contentShape(Circle().inset(by: -6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add an exercise to tier \(tier.title)")
            }
            if items.isEmpty {
                Text("Nothing here yet")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, SkillMetrics.s2)
            }
            LazyVStack(spacing: SkillMetrics.s2) {
                ForEach(shown) { card($0) }
            }
            if items.count > Self.collapsedCount {
                Button {
                    if isExpanded { expanded.remove(tier) } else { expanded.insert(tier) }
                } label: {
                    Text(isExpanded ? "Show less" : "Show \(items.count - Self.collapsedCount) more")
                        .font(TimeMasterFont.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, minHeight: SkillMetrics.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SkillMetrics.s2)
        .frame(width: Self.columnWidth, alignment: .topLeading)
        .background(shape.fill(color.opacity(0.07)))
        .overlay { shape.strokeBorder(color.opacity(0.25), lineWidth: 1).allowsHitTesting(false) }
    }

    private func card(_ item: SkillTrainer) -> some View {
        let page = item.page
        return VStack(alignment: .leading, spacing: 0) {
            SkillGalleryCover(page: page) { PageCoverOpening.open(page, in: navigationState) }
            HStack(alignment: .top, spacing: SkillMetrics.s2) {
                Text(page.title)
                    .font(TimeMasterFont.rowTitle())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { PageCoverOpening.openPage(page, playing: nil, in: navigationState) }
                    .tmaxPointer()
                TmaxMenu { tileMenu(item) } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.textSecondary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .accessibilityLabel("Actions for \(page.title)")
            }
            .padding(SkillMetrics.s3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TimeMasterCardSurface(cornerRadius: SkillMetrics.fieldRadius, accent: Theme.toolbarOrange, flat: true))
        .contextMenu { tileMenu(item) }
    }

    @ViewBuilder
    private func tileMenu(_ item: SkillTrainer) -> some View {
        TmaxSubmenu {
            ForEach(SkillTier.allCases, id: \.self) { tier in
                Button { set(item.page, tier) } label: {
                    Label("Tier \(tier.title)", systemImage: tier == item.tier ? "checkmark" : "")
                }
            }
        } label: {
            Label("Tier", systemImage: "rosette")
        }
        Button {
            PageCoverOpening.openPage(item.page, playing: nil, in: navigationState)
        } label: {
            Label("Open Page", systemImage: "arrow.up.forward.square")
        }
        Divider()
        Button(role: .destructive) { set(item.page, nil) } label: {
            Label("Take off this skill", systemImage: "minus.circle")
        }
    }

    private func set(_ page: ExercisePage, _ tier: SkillTier?) {
        SkillErrorCenter.shared.attempt("Set the tier") {
            try store.setTraining(page.manifest.id, skill: skillID, tier: tier)
        }
    }
}
