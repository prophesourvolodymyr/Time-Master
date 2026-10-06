import SwiftUI
import TimeMasterCore

struct SchedulePlanEditor: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State var plan: WeeklyWorkoutSchedule.Plan
    let week: Date
    @State private var editingEntry: EntryDraft?
    @State private var error: String?
    private let icons = ["square.stack.3d.up.fill", "dumbbell.fill", "figure.run", "leaf.fill", "bolt.fill", "sun.max.fill", "moon.stars.fill", "mountain.2.fill"]

    private struct EntryDraft: Identifiable {
        let id = UUID()
        let day: Int
        let entry: WeeklyWorkoutSchedule.Entry?
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Plan") {
                    TextField("Plan name", text: $plan.name)
                        .accessibilityIdentifier("schedule.plan.name")
                    Picker("Icon", selection: $plan.icon) {
                        ForEach(icons, id: \.self) { icon in
                            Image(systemName: icon).tag(icon)
                        }
                    }
                }
                ForEach(1...7, id: \.self) { day in
                    SwiftUI.Section(Calendar.current.weekdaySymbols[day % 7]) {
                        ForEach(plan.entries.filter { $0.weekday == day }.sorted { ($0.startMinute ?? 1440) < ($1.startMinute ?? 1440) }) { entry in
                            HStack {
                                Button {
                                    editingEntry = EntryDraft(day: day, entry: entry)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(entry.title, systemImage: entry.icon)
                                            .foregroundStyle(.primary)
                                        if let minute = entry.startMinute {
                                            Text(timeLabel(minute, day: day)).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                                Button(role: .destructive) { plan.entries.removeAll { $0.id == entry.id } } label: {
                                    Image(systemName: "minus.circle").padding(10)
                                }
                                .accessibilityLabel("Remove \(entry.title) from Plan")
                            }
                        }
                        Button {
                            editingEntry = EntryDraft(day: day, entry: nil)
                        } label: { Label("Add workout", systemImage: "plus") }
                    }
                }
                SwiftUI.Section {
                    Text("Saving equips this Plan from the selected week onward. Changes never rewrite earlier weeks. Date-only changes stay on their original dates.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(plan.name.isEmpty ? "New Plan" : "Edit Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & use") {
                        plan.name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.changeWeeklySchedule({
                            $0.savePlan(plan)
                            $0.equip(plan, from: week)
                        }) { dismiss() }
                        else { error = store.scheduleError }
                    }
                    .disabled(plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("schedule.plan.save")
                }
            }
            .sheet(item: $editingEntry) { draft in
                ScheduleEntryEditor(date: date(for: draft.day), entry: draft.entry, showsRepeat: false) { entry, _ in
                    plan.entries.removeAll { $0.id == entry.id }
                    plan.entries.append(entry)
                    return true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func date(for day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: week) ?? week
    }

    private func timeLabel(_ minute: Int, day: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date(for: day)) ?? week
        return date.formatted(date: .omitted, time: .shortened)
    }
}
