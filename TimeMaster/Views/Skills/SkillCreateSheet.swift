import SwiftUI
import TimeMasterCore

/// "New skill": a name and Return is enough; the kind, icon, status, folder and a reason are optional.
struct SkillCreateSheet: View {
    /// Runs with the new page's id once it is saved, before the sheet closes.
    let onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DatabaseStore

    @State private var title = ""
    @State private var pageType: PageType = .skill
    @State private var choosesIcon = false
    @State private var iconName = "star.fill"
    @State private var iconType: SkillBoardIconType = .system
    @State private var status: SkillStatus = .learning
    @State private var folderID: String?
    @State private var folders: [FolderChoice] = []
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var libraryToken = ExerciseLibraryAccess.shared.capture()
    @FocusState private var titleFocused: Bool

    init(onCreated: @escaping (String) -> Void) {
        self.onCreated = onCreated
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var noun: String { pageType == .tutorial ? "tutorial" : "skill" }

    /// The page as it will be saved (a fresh id on every read).
    private var draftManifest: ExercisePageManifest {
        let icon = choosesIcon ? iconName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return ExercisePageManifest(
            title: trimmedTitle,
            pageType: pageType,
            iconName: icon.isEmpty ? nil : icon,
            iconType: icon.isEmpty ? nil : iconType,
            markdownBody: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            skillStatus: status,
            parentID: folderID
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleField
                    labeled("Kind") { kindPicker }
                    labeled("Icon") { iconSection }
                    labeled("Status") { statusPicker }
                    labeled("Folder") { folderPicker }
                    labeled("Why I'm learning this") { reasonField }
                }
                .padding(20)
                .frame(maxWidth: ProfileStyle.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .timeMasterNavigationTitle("New \(noun)")
            #if os(iOS)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(TimeMasterToolbarTextButtonStyle())
                }
                AppToolbar.item(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .alert(
            "Couldn’t make the \(noun)",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 560, idealHeight: 680)
        #endif
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            titleFocused = true
        }
        .onReceive(store.$allPagesFlat) { pages in
            folders = SkillLibrary(pages: pages).skillFolders().map { FolderChoice(id: $0.page.manifest.id, path: $0.path) }
            if let folderID, !folders.contains(where: { $0.id == folderID }) {
                self.folderID = nil
            }
        }
    }

    private var titleField: some View {
        TextField(pageType == .tutorial ? "What will it teach?" : "What do you want to learn?", text: $title)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.display())
            .foregroundStyle(Theme.textPrimary)
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { create() }
            .padding(.vertical, 8)
            .accessibilityLabel(pageType == .tutorial ? "Tutorial name" : "Skill name")
    }

    private var kindPicker: some View {
        HStack(spacing: 8) {
            choice("Skill", systemImage: "flag.checkered", isSelected: pageType == .skill) { pageType = .skill }
            choice("Tutorial", systemImage: "book.closed", isSelected: pageType == .tutorial) { pageType = .tutorial }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SkillPageIconTile(page: ExercisePage(manifest: draftManifest), size: 40)
                    .frame(width: 56, height: 56)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.separator, lineWidth: 1)
                    }
                    .accessibilityHidden(true)
                choice("Automatic", isSelected: !choosesIcon) { choosesIcon = false }
                choice("Choose", isSelected: choosesIcon) { choosesIcon = true }
            }
            if choosesIcon {
                SkillIconPicker(iconName: $iconName, iconType: $iconType)
            } else {
                Text("Picked from the name. A picture can be set on the \(noun)'s page.")
                    .font(TimeMasterFont.caption())
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var statusPicker: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(SkillSortOption.statusOrder, id: \.self) { option in
                choice(option.title, systemImage: option.symbolName, isSelected: status == option) { status = option }
            }
        }
    }

    private var folderPicker: some View {
        let current = folders.first { $0.id == folderID }
        let currentTitle = current?.path ?? "Top level"
        return Menu {
            Button {
                folderID = nil
            } label: {
                Label("Top level", systemImage: current == nil ? "checkmark" : "books.vertical")
            }
            if !folders.isEmpty {
                Divider()
            }
            ForEach(folders) { folder in
                Button {
                    folderID = folder.id
                } label: {
                    Label(folder.path, systemImage: folder.id == current?.id ? "checkmark" : "folder")
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: current == nil ? "books.vertical.fill" : "folder.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.toolbarOrange)
                Text(currentTitle)
                    .font(TimeMasterFont.body(16))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .menuIndicator(.hidden)
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Folder")
        .accessibilityValue(currentTitle)
    }

    private var reasonField: some View {
        TextField("Optional, a line for future you", text: $reason, axis: .vertical)
            .textFieldStyle(.plain)
            .font(TimeMasterFont.body(16))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(2...5)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
            .modifier(TimeMasterCardSurface(cornerRadius: 14, flat: true))
            .accessibilityLabel("Why I'm learning this")
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(TimeMasterFont.black(12, relativeTo: .caption))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func choice(_ title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !isSelected else { return }
            action()
            EverHaptic.selection()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TimeMasterSelectionButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func create() {
        guard !trimmedTitle.isEmpty else { return }
        var manifest = draftManifest
        let parentID = folderID
        do {
            try ExerciseLibraryAccess.shared.perform(token: libraryToken) {
                if let parentID {
                    manifest.skillBoardOrder = try DatabaseManager.shared.nextSkillBoardOrder(containerID: parentID, sectionID: nil)
                }
                try store.createPage(manifest: manifest, parentID: parentID)
            }
            EverHaptic.success()
            onCreated(manifest.id)
            dismiss()
        } catch {
            EverHaptic.warning()
            errorMessage = error.localizedDescription
        }
    }
}

/// A folder the new skill can go in, with its path for the picker.
private struct FolderChoice: Identifiable {
    let id: String
    let path: String
}
