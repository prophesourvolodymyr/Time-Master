import SwiftUI
import TimeMasterCore

struct SchedulePlansSheet: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let week: Date
    @State private var editingPlan: WeeklyWorkoutSchedule.Plan?
    @State private var deletingPlan: WeeklyWorkoutSchedule.Plan?

    private var selection: WeeklyWorkoutSchedule.Selection? { store.weeklySchedule.selection(for: week) }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    ForEach(store.weeklySchedule.plans) { plan in
                        HStack {
                            Button {
                                if store.changeWeeklySchedule({ $0.equip(plan, from: week) }) { dismiss() }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: plan.icon).font(.title2).foregroundStyle(.white)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.name).font(.headline).foregroundStyle(.white)
                                        Text("\(plan.entries.count) workouts · \(Set(plan.entries.map(\.weekday)).count) days")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selection?.plan?.id == plan.id { Image(systemName: "checkmark").foregroundStyle(.white) }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Menu {
                                Button("Edit Plan", systemImage: "pencil") { editingPlan = plan }
                                Button("Delete Plan", systemImage: "trash", role: .destructive) { deletingPlan = plan }
                            } label: {
                                Image(systemName: "ellipsis").padding(12)
                            }
                            .accessibilityLabel("Options for \(plan.name)")
                        }
                    }
                    Button {
                        editingPlan = WeeklyWorkoutSchedule.Plan(name: "")
                    } label: { Label("New Plan", systemImage: "plus.circle.fill") }
                    .accessibilityIdentifier("schedule.plan.new")
                } header: { Text("Your Plans") }
                footer: {
                    Text("Choose a Plan for the week of \(week.formatted(date: .abbreviated, time: .omitted)). It repeats until a different Plan or Vacation is selected. Past weeks keep their saved workouts.")
                }
                SwiftUI.Section {
                    Button {
                        if store.changeWeeklySchedule({ $0.equip(nil, from: week) }) { dismiss() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "beach.umbrella.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vacation").font(.headline)
                                Text("Empty weeks. Your streak stays frozen.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selection?.isVacation == true { Image(systemName: "checkmark") }
                        }.padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("schedule.vacation")
                } footer: { Text("Vacation applies to the whole selected week and continues until you choose a Plan. Saved workouts and completion records are not deleted.") }
                if let error = store.scheduleError {
                    SwiftUI.Section { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Plans")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editingPlan) { plan in
                SchedulePlanEditor(plan: plan, week: week)
            }
            .alert("Delete Plan?", isPresented: Binding(get: { deletingPlan != nil }, set: { if !$0 { deletingPlan = nil } })) {
                Button("Delete", role: .destructive) {
                    guard let deletingPlan else { return }
                    store.changeWeeklySchedule { $0.plans.removeAll { $0.id == deletingPlan.id } }
                    self.deletingPlan = nil
                }
                Button("Cancel", role: .cancel) { deletingPlan = nil }
            } message: {
                Text("The saved Plan will be removed from this chooser. Weeks already using it keep their workouts and history.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
