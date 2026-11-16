import SwiftUI
import TimeMasterCore

/// What is being dragged on the Workouts page, carried as plain text so it needs no custom type.
enum WorkoutListDrag: Equatable {
    case workout(UUID)
    case group(UUID)

    private static let workoutPrefix = "tmax-workout:"
    private static let groupPrefix = "tmax-workout-section:"

    var payload: String {
        switch self {
        case .workout(let id): return Self.workoutPrefix + id.uuidString
        case .group(let id): return Self.groupPrefix + id.uuidString
        }
    }

    init?(_ payload: String) {
        if payload.hasPrefix(Self.workoutPrefix), let id = UUID(uuidString: String(payload.dropFirst(Self.workoutPrefix.count))) {
            self = .workout(id)
        } else if payload.hasPrefix(Self.groupPrefix), let id = UUID(uuidString: String(payload.dropFirst(Self.groupPrefix.count))) {
            self = .group(id)
        } else {
            return nil
        }
    }
}

/// The big title of a section: its icon, name and workout count. Clicking it folds the section.
struct WorkoutGroupHeader: View {
    let title: String
    let icon: String
    let iconType: SkillBoardIconType?
    let count: Int
    let isCollapsed: Bool
    let isDropTarget: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Group {
                        if icon.isEmpty {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Theme.toolbarOrange)
                        } else {
                            SkillIconView(iconName: icon, iconType: iconType ?? .emoji, size: 20)
                        }
                    }
                    .frame(width: 30, height: 30)
                    Text(title)
                        .font(TimeMasterFont.black(24, relativeTo: .title2))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(count)")
                        .font(TimeMasterFont.body(15, relativeTo: .subheadline))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                Rectangle()
                    .fill(isDropTarget ? Theme.toolbarOrange : Color.white.opacity(0.1))
                    .frame(height: isDropTarget ? 2 : 1)
                    .padding(.horizontal, 8)
            }
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.toolbarOrange.opacity(isDropTarget ? 0.1 : 0))
            }
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 14))
        .accessibilityLabel(title)
        .accessibilityValue("\(count) workouts, \(isCollapsed ? "folded" : "open")")
        .accessibilityHint("Shows or hides its workouts. Drag to move the section.")
        .accessibilityAddTraits(.isHeader)
    }
}

/// The place to drop workouts into a section that has none yet.
struct WorkoutGroupDropZone: View {
    let isTargeted: Bool

    var body: some View {
        Text("Drag workouts here")
            .font(TimeMasterFont.body(15, relativeTo: .subheadline))
            .foregroundStyle(isTargeted ? Theme.textPrimary : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.toolbarOrange.opacity(isTargeted ? 0.14 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isTargeted ? Theme.toolbarOrange : Theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 5]))
            }
    }
}

/// The dashed row under the list that starts a new section.
struct NewWorkoutGroupButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New Section", systemImage: "plus")
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
                .contentShape(Rectangle())
        }
        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 16))
        .accessibilityHint("Adds a titled section to hold workouts")
    }
}

/// What the section sheet is for: a new section (optionally taking one workout with it) or an existing one.
struct WorkoutGroupEditorRequest: Identifiable {
    let id = UUID()
    var group: WorkoutGroup?
    var workoutToMove: UUID?
}

/// Name and icon of a section.
struct WorkoutGroupEditorSheet: View {
    let isNew: Bool
    let onSave: (_ title: String, _ icon: String, _ iconType: SkillBoardIconType?) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var iconName: String
    @State private var iconType: SkillBoardIconType
    @FocusState private var titleFocused: Bool

    init(group: WorkoutGroup?, onSave: @escaping (String, String, SkillBoardIconType?) -> Void, onCancel: @escaping () -> Void) {
        isNew = group == nil
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: group?.title ?? "")
        _iconName = State(initialValue: group.map { $0.icon.isEmpty ? "calendar" : $0.icon } ?? "calendar")
        _iconType = State(initialValue: group.map { $0.icon.isEmpty ? .system : ($0.iconType ?? .emoji) } ?? .system)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            TextField("e.g., Week 1", text: $title)
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.textPrimary)
                                .focused($titleFocused)
                                .onSubmit(save)
                                .keyNavTarget(shape: .roundedRectangle(cornerRadius: 12))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            SkillIconPicker(iconName: $iconName, iconType: $iconType)
                        }
                        Button(action: save) {
                            Text(isNew ? "Create Section" : "Save")
                                .font(TimeMasterFont.black(17, relativeTo: .headline))
                                .foregroundStyle(trimmedTitle.isEmpty ? Color.white.opacity(0.3) : .black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(trimmedTitle.isEmpty ? Theme.surface : Color.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .keyNavPlainButtonStyle(shape: .roundedRectangle(cornerRadius: 12))
                        .disabled(trimmedTitle.isEmpty)
                    }
                    .padding(16)
                }
            }
            .timeMasterNavigationTitle(isNew ? "New Section" : "Edit Section")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                AppToolbar.item(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        let icon = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmedTitle, icon, icon.isEmpty ? nil : iconType)
    }
}
