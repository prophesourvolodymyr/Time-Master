import SwiftUI

struct WorkoutTypesSettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                builtInSection
                Divider().background(Theme.separator).padding(.horizontal, 16)
                customSection
            }
        }
        .navigationTitle("Workout Types")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus").foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TypeEditorSheet(onSave: { name, icon in
                store.addCustomType(name: name, iconName: icon)
                showAddSheet = false
            })
        }
    }

    private var builtInSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Built-in Types")
            let types = WorkoutType.builtIn
            ForEach(Array(types), id: \.id) { type in
                typeRow(type, isBuiltIn: true)
                if type.id != types.last?.id {
                    Divider().background(Theme.separator).padding(.leading, 58)
                }
            }
        }
        .padding(16)
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Custom Types")
            if store.customWorkoutTypes.isEmpty {
                Text("No custom types yet.")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                let types = Array(store.customWorkoutTypes)
                ForEach(types, id: \.id) { type in
                    HStack {
                        typeRow(type, isBuiltIn: false)
                        Spacer()
                        Button(role: .destructive) {
                            store.deleteCustomType(id: type.id)
                        } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                    }
                    .padding(.trailing, 8)
                    if type.id != types.last?.id {
                        Divider().background(Theme.separator).padding(.leading, 58)
                    }
                }
            }
        }
        .padding(16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom, 8)
    }

    private func typeRow(_ type: WorkoutType, isBuiltIn: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.name).font(.body).foregroundColor(.white)
                Text("icon: \(type.iconName)")
                    .font(.caption).foregroundColor(Theme.textSecondary)
            }
            if isBuiltIn {
                Text("built-in")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Type Editor Sheet

private struct TypeEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "star.fill"

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
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name").font(.headline).foregroundColor(Theme.textPrimary)
                            TextField("e.g., Boxing", text: $name)
                                .padding(14).background(Theme.surface).cornerRadius(10)
                                .foregroundColor(Theme.textPrimary)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon").font(.headline).foregroundColor(Theme.textPrimary)
                            HStack(spacing: 8) {
                                Image(systemName: selectedIcon)
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(14)
                                Text(selectedIcon)
                                    .font(.caption.monospaced())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(sfIcons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIcon == icon ? .black : .white)
                                            .frame(width: 44, height: 44)
                                            .background(selectedIcon == icon ? Color.white : Theme.surface)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Workout Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onSave(trimmed, selectedIcon)
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : .white)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
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
