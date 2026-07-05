import SwiftUI

struct WorkoutTypesSettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @StateObject private var goals = GoalsManager.shared
    @State private var showAddSheet = false
    @State private var goalEditType: WorkoutType?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    builtInGrid
                    if !store.customWorkoutTypes.isEmpty {
                        customGrid
                    }
                    createButton
                }
                .padding(16)
            }
        }
        .navigationTitle("Workout Types")
        .sheet(isPresented: $showAddSheet) {
            TypeEditorSheet { name, icon, color in
                store.addCustomType(name: name, iconName: icon, colorHex: color)
                showAddSheet = false
            }
        }
        .sheet(item: $goalEditType) { type in
            TypeGoalSheet(type: type)
        }
    }

    // MARK: - Built-in

    private var builtInGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Built-in")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(WorkoutType.builtIn), id: \.id) { type in
                    typeCard(type)
                }
            }
        }
    }

    // MARK: - Custom

    private var customGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom")
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(store.customWorkoutTypes), id: \.id) { type in
                    typeCard(type)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteCustomType(id: type.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func typeCard(_ type: WorkoutType) -> some View {
        let goal = goals.goal(for: type)
        return Button {
            goalEditType = type
        } label: {
            HStack(spacing: 10) {
                Image(systemName: type.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(type.colorHex == "FFFFFF" ? .black : .white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: type.colorHex))
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if goal > 0 {
                        Text("\(goal)×/week")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if goal == 0 {
                    Text("Set goal")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
            }
            .padding(10)
            .background(Theme.surface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create button

    private var createButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Create New Type")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Type Editor Sheet

private struct TypeEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var colorHex = "FFFFFF"

    private let sfIcons: [String] = [
        "dumbbell.fill", "figure.run", "heart.fill", "flame.fill",
        "figure.mind.and.body", "face.smiling.fill", "figure.cooldown",
        "figure.boxing", "figure.strengthtraining.traditional",
        "figure.step.training", "figure.play", "figure.walk",
        "figure.roll", "figure.jumprope", "figure.climbing",
        "figure.open.water.swim", "figure.indoor.cycle",
        "star.fill", "bolt.fill", "leaf.fill", "sun.max.fill",
        "moon.stars.fill", "snowflake", "water.waves",
    ]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        previewCard
                        nameSection
                        colorSection
                        iconSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onSave(name.trimmingCharacters(in: .whitespaces), selectedIcon, colorHex)
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : .white)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(colorHex == "FFFFFF" ? .black : .white)
                .frame(width: 42, height: 42)
                .background(Color(hex: colorHex))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Type Name" : name)
                    .font(.headline)
                    .foregroundColor(name.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
            TextField("e.g., Boxing", text: $name)
                .padding(14).background(Theme.surface).cornerRadius(10)
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon Color").font(.headline).foregroundColor(Theme.textPrimary)
            IconColorPicker(selectedHex: $colorHex)
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon").font(.headline).foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(sfIcons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(selectedIcon == icon ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? Color.white : Theme.surface)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

// MARK: - Type Goal Sheet

private struct TypeGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    let type: WorkoutType
    @State private var draft: Int

    init(type: WorkoutType) {
        self.type = type
        _draft = State(initialValue: max(GoalsManager.shared.goal(for: type), 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 30) {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: type.colorHex))
                            .frame(width: 80, height: 80)
                            .background(Color(hex: type.colorHex).opacity(0.15))
                            .cornerRadius(20)
                        Text(type.name)
                            .font(.title2.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                    VStack(spacing: 10) {
                        Text("Weekly Goal")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { n in
                                Button { draft = n } label: {
                                    Text("\(n)")
                                        .font(.title3.weight(draft == n ? .bold : .medium))
                                        .foregroundColor(draft == n ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(draft == n ? Color.white : Theme.surface)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        Text(draft == 1 ? "Once a week" : "\(draft) times a week")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Button {
                        GoalsManager.shared.setGoal(draft, for: type)
                        dismiss()
                    } label: {
                        Text("Save Goal")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(32)
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutTypesSettingsView()
            .environmentObject(WorkoutStore())
            .preferredColorScheme(.dark)
    }
}
