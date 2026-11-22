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

/// The Tiers view of a skill: every page in the library that trains it, in rows from S (the best way to train it) down to
/// D. A cover opens the clip in the quick preview with the other exercises of the view to step through; a page's menu
/// moves it to another tier, opens it or takes it off the skill. "Add exercise" and the plus of a row link any page of
/// the library at that tier.
struct SkillTierBoardView: View {
    let skillID: String

    @EnvironmentObject private var store: DatabaseStore
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var navigationState: DatabaseNavigationState
    @State private var pickerTier: SkillTier?

    var body: some View {
        let trainers = store.trainers(of: skillID)
        VStack(alignment: .leading, spacing: SkillMetrics.s3) {
            HStack(spacing: SkillMetrics.s2) {
                Text(summary(trainers.count))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Button { pickerTier = .c } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                        .lineLimit(1)
                }
                .buttonStyle(TimeMasterActionButtonStyle(prominent: true, horizontalPadding: SkillMetrics.s4))
            }
            ForEach(SkillTier.allCases, id: \.self) { tier in
                row(tier, trainers.filter { $0.tier == tier })
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

    private func summary(_ count: Int) -> String {
        switch count {
        case 0: "No exercise trains this skill yet. Add one, or ask the assistant to fill the tiers from your library."
        case 1: "1 exercise trains this skill"
        default: "\(count) exercises train this skill"
        }
    }

    private func row(_ tier: SkillTier, _ items: [SkillTrainer]) -> some View {
        let color = SkillTierStyle.color(tier)
        let shape = RoundedRectangle(cornerRadius: SkillMetrics.fieldRadius, style: .continuous)
        return HStack(alignment: .top, spacing: SkillMetrics.s3) {
            Text(tier.title)
                .font(TimeMasterFont.black(24, relativeTo: .title2))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
                .accessibilityLabel("Tier \(tier.title)")
            Group {
                if items.isEmpty {
                    Text("Nothing here yet")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(minHeight: 52, alignment: .center)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 112, maximum: 168), spacing: 10, alignment: .top)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(items) { tile($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(SkillMetrics.s3)
        .background(shape.fill(color.opacity(0.07)))
        .overlay { shape.strokeBorder(color.opacity(0.25), lineWidth: 1).allowsHitTesting(false) }
    }

    private func tile(_ item: SkillTrainer) -> some View {
        let page = item.page
        return VStack(alignment: .leading, spacing: 6) {
            AsyncCoverImage(
                url: page.coverImageURL,
                fallbackIcon: PageKindStyle.symbol(page),
                height: 84,
                contentMode: .fill,
                overlayGradient: false
            )
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .modifier(PageCoverTap(page: page, cornerRadius: 12, glyphSize: 26) {
                PageCoverOpening.open(page, in: navigationState)
            })
            .overlay(alignment: .topTrailing) {
                Menu { tileMenu(item) } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.black.opacity(0.55))
                        .padding(4)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .accessibilityLabel("Actions for \(page.title)")
            }
            Text(page.title)
                .font(TimeMasterFont.caption())
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .contextMenu { tileMenu(item) }
    }

    @ViewBuilder
    private func tileMenu(_ item: SkillTrainer) -> some View {
        Menu {
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
