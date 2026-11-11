import SwiftUI

/// The head of the To-do and Milestones sections: a progress ring, the title, a badge with what is still open, a
/// small done count, the options menu and the add button.
struct ChecklistSectionHeader<MenuItems: View>: View {
    let symbol: String
    let title: String
    let done: Int
    let total: Int
    let addLabel: String
    let onAdd: () -> Void
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        let open = total - done
        HStack(spacing: 10) {
            ChecklistProgressRing(fraction: total == 0 ? 0 : Double(done) / Double(total), symbol: symbol)
            Text(title)
                .font(TimeMasterFont.sectionTitle())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if open > 0 {
                Text("\(open)")
                    .font(TimeMasterFont.black(12, relativeTo: .caption))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.toolbarOrange, in: Capsule())
                    .accessibilityLabel("\(open) open")
            }
            if total > 0 {
                Text("\(done)/\(total)")
                    .font(TimeMasterFont.technical())
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("\(done) of \(total) done")
            }
            Spacer(minLength: 0)
            Menu {
                menuItems()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .keyNavPlainButtonStyle()
            .fixedSize()
            .accessibilityLabel("\(title) options")
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(Theme.toolbarOrange, in: Circle())
            }
            .keyNavPlainButtonStyle(shape: .circle)
            .help(addLabel)
            .accessibilityLabel(addLabel)
        }
    }
}
