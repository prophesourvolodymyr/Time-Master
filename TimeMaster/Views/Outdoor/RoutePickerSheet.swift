#if os(iOS)
import SwiftUI

struct RoutePickerSheet: View {
    @ObservedObject var store: OutdoorActivityStore
    var onSelect: (PlannedRoute?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button("None / Free recording") {
                    onSelect(nil)
                    dismiss()
                }
                if store.plannedRoutes.isEmpty {
                    Text("No saved routes yet. (Import GPX or create from pages later)")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.plannedRoutes) { route in
                        Button(route.title) {
                            onSelect(route)
                            dismiss()
                        }
                    }
                }
                Button("Import GPX (stub)") {
                    // later: present importer that creates PlannedRoute
                    onSelect(nil)
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Choose Route")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
#endif
