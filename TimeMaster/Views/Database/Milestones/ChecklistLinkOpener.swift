import SwiftUI
import TimeMasterCore

/// Opens what a link chip points at with the app's existing routes: a workout's detail (or its start), a page in the
/// Database stack, a file of the page in its viewer, a web address in the browser.
@MainActor
enum ChecklistLinkOpener {
    static func open(
        _ target: ChecklistLinkTarget,
        navigation: DatabaseNavigationState,
        openURL: OpenURLAction,
        openMedia: (URL) -> Void
    ) {
        switch target {
        case .workout(let workout):
            NotificationCenter.default.post(name: .openWorkoutDetail, object: nil, userInfo: ["workoutID": workout.id])
        case .page(let material):
            if let owner = SkillGroupID.split(material.id) {
                navigation.path.append(DatabaseSkillGroupRoute(containerID: owner.containerID, sectionID: owner.sectionID))
            } else {
                navigation.path.append(DatabasePageRoute(pageID: material.id))
            }
        case .media(_, let url):
            openMedia(url)
        case .web(let url):
            openURL(url)
        case .missingWorkout, .missingPage, .missingMedia, .unreadable:
            break
        }
    }

    /// Starts a workout through the app's start flow (the same one `timemaster://start` uses).
    static func start(_ workout: Workout) {
        NotificationCenter.default.post(name: .launchWorkout, object: nil, userInfo: ["workoutID": workout.id])
    }
}

extension Notification.Name {
    /// Opens a database page (`userInfo["pageID"]`, a page or group id) in the Database tab.
    static let openDatabasePage = Notification.Name("com.timemaster.openDatabasePage")
}
