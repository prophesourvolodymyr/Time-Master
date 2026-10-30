import SwiftUI
import TimeMasterCore

/// Every skill of a board on one line each: name, status, type, group, links. Status, type and group change in place.
struct SkillTableView: View {
    @EnvironmentObject private var store: DatabaseStore
    let pages: [ExercisePage]
    let context: SkillBoardContext

    private let statusWidth: CGFloat = 124
    private let typeWidth: CGFloat = 150
    private let groupWidth: CGFloat = 150
    private let linksWidth: CGFloat = 56

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                if pages.isEmpty {
                    Text("No skills yet")
                        .font(TimeMasterFont.caption())
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                ForEach(pages) { page in
                    row(page)
                }
            }
            .frame(minWidth: 720, maxWidth: SkillsLayout.tableWidth)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            head("Skill").frame(maxWidth: .infinity, alignment: .leading)
            head("Status").frame(width: statusWidth, alignment: .leading)
            head("Type").frame(width: typeWidth, alignment: .leading)
            head("Group").frame(width: groupWidth, alignment: .leading)
            head("Links").frame(width: linksWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1) }
    }

    private func head(_ text: String) -> some View {
        Text(text.uppercased())
            .font(TimeMasterFont.caption())
            .tracking(1)
            .foregroundStyle(Theme.textSecondary)
    }

    private func row(_ page: ExercisePage) -> some View {
        let status = page.manifest.skillStatus ?? .notStarted
        let type = store.skillType(of: page)
        return HStack(spacing: 10) {
            HStack(spacing: 8) {
                SkillPageIconTile(page: page, size: 26)
                SkillEditableTitle(
                    pageID: page.manifest.id,
                    title: page.title,
                    color: Theme.textPrimary.opacity(status.titleOpacity),
                    lineLimit: 1,
                    onOpen: { context.open(page) }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(SkillStatus.boardOrder, id: \.self) { option in
                    Button {
                        SkillErrorCenter.shared.attempt("Change the status") { try store.setSkillStatus(option, for: page.manifest.id) }
                    } label: {
                        Label(option.title, systemImage: status == option ? "checkmark" : option.symbolName)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: status.symbolName).font(.system(size: 12, weight: .semibold))
                    Text(status.title).font(TimeMasterFont.caption())
                }
                .foregroundStyle(status.color)
                .frame(width: statusWidth, height: 32, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.button).keyNavPlainButtonStyle()
            .menuIndicator(.hidden)
            .accessibilityLabel("Status: \(status.title)")

            SkillTypePicker(pageID: page.manifest.id) {
                Group {
                    if let type {
                        SkillTypeChip(type: type, showsChevron: true)
                    } else {
                        SkillAddTypeChip()
                    }
                }
                .frame(width: typeWidth, height: 32, alignment: .leading)
                .contentShape(Rectangle())
            }

            Menu {
                Button {
                    move(page, to: nil)
                } label: {
                    Label("No group", systemImage: store.skillSectionID(of: page) == nil ? "checkmark" : "tray")
                }
                ForEach(context.groups) { group in
                    Button {
                        move(page, to: group.id)
                    } label: {
                        Label(group.title, systemImage: store.skillSectionID(of: page) == group.id ? "checkmark" : "square.grid.2x2")
                    }
                }
            } label: {
                Text(groupTitle(of: page))
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: groupWidth, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button).keyNavPlainButtonStyle()
            .menuIndicator(.hidden)
            .disabled(context.groups.isEmpty)

            Text(page.manifest.linkURLs.isEmpty ? "–" : "\(page.manifest.linkURLs.count)")
                .font(TimeMasterFont.caption())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: linksWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .skillTypeBase(type, cornerRadius: 0)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 1) }
        .contextMenu { SkillPageMenu(page: page, context: context) }
        .keyNavTarget(id: page.manifest.id, role: .primary, shape: .roundedRectangle(cornerRadius: 4)) {
            context.open(page)
        }
    }

    private func groupTitle(of page: ExercisePage) -> String {
        guard let id = store.skillSectionID(of: page),
              let group = context.groups.first(where: { $0.id == id }) else { return "–" }
        return group.title
    }

    private func move(_ page: ExercisePage, to sectionID: String?) {
        SkillErrorCenter.shared.attempt("Move the skill") {
            try store.placeSkillPage(page.manifest.id, sectionID: .some(sectionID))
        }
    }
}
