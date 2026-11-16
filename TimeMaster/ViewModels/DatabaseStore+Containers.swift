import Foundation

extension DatabaseStore {
    /// A container's browse model, shared by every screen until the library changes.
    func containerBrowseModel(for container: ExercisePage) -> ContainerBrowseModel {
        let id = container.manifest.id
        if let known = derived.containerModels[id] { return known }
        let model = ContainerBrowseModel(container: container, roots: rootPages, pages: allPagesFlat)
        derived.containerModels[id] = model
        return model
    }
}
