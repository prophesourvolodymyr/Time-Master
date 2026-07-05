import SwiftUI

struct WorkoutTypesSettingsView: View {
    @EnvironmentObject var store: WorkoutStore
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    builtInGrid
                    if !store.customWorkoutTypes.isEmpty || showAddSheet {
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
        HStack(spacing: 10) {
            Image(systemName: type.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(type.colorHex == "FFFFFF" ? .black : .white)
                .frame(width: 38, height: 38)
                .background(Color(hex: type.colorHex))
                .cornerRadius(10)
            Text(type.name)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.surface)
        .cornerRadius(12)
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

#Preview {
    NavigationStack {
        WorkoutTypesSettingsView()
            .environmentObject(WorkoutStore())
            .preferredColorScheme(.dark)
    }
}
