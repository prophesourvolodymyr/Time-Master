import SwiftUI

struct HomeWidgetPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var widgetStore: HomeWidgetStore

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(HomeWidgetCategory.allCases) { category in
                            let widgets = widgetStore.availableKinds.filter { $0.category == category }
                            if !widgets.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(category.title)
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    LazyVGrid(
                                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                                        spacing: 10
                                    ) {
                                        ForEach(widgets) { kind in
                                            widgetButton(kind)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Widget")
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func widgetButton(_ kind: HomeWidgetKind) -> some View {
        let canAdd = widgetStore.canAdd(kind)
        return Button {
            widgetStore.add(kind)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: kind.systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if !canAdd {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
                footprintPreview(kind.defaultFootprint)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(canAdd ? 0.08 : 0.16), lineWidth: 1)
            )
            .opacity(canAdd ? 1 : 0.56)
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
        .accessibilityLabel(canAdd ? "Add \(kind.title) widget" : "\(kind.title) already added")
    }

    private func footprintPreview(_ footprint: HomeWidgetFootprint) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.16))
                .frame(width: footprint == .compact ? 42 : 78, height: footprint.rowSpan == 1 ? 22 : 36)
            if footprint == .large {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 78, height: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
