import XCTest
@testable import TimeMaster

@MainActor
final class SlotNavigationLayoutStoreTests: XCTestCase {
    private var suites: [String] = []

    private func makeDefaults() -> UserDefaults {
        let name = "tm-nav-test-\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suites { UserDefaults.standard.removePersistentDomain(forName: name) }
        suites.removeAll()
        super.tearDown()
    }

    private var newDefault: [SlotNavigationDestination] {
        SlotNavigationDestination.defaultOrder.filter(\.isAvailable)
    }

    func testTheShippedDefaultPutsWorkoutsLeftOfHomeThenDatabaseAndSchedule() {
        let order = SlotNavigationDestination.defaultOrder
        let home = order.firstIndex(of: .home)!
        XCTAssertEqual(order[home - 1], .workouts)
        XCTAssertEqual(order[home + 1], .database)
        XCTAssertEqual(order[home + 2], .schedule)
        XCTAssertEqual(Set(order), Set(SlotNavigationDestination.allCases))
    }

    func testAFreshInstallGetsTheNewDefault() {
        let store = SlotNavigationLayoutStore(defaults: makeDefaults())
        XCTAssertEqual(store.order, newDefault)
    }

    func testADeviceStillOnAPreviousDefaultMovesToTheNewOne() {
        for previous in SlotNavigationLayoutStore.previousDefaultOrders {
            for saved in [previous, previous.filter { $0 != .physique }] {
                let defaults = makeDefaults()
                defaults.set(saved.map(\.rawValue), forKey: "tm.navigation.order.v1")
                for key in ["scheduleSettingsAdded", "rankedAdded"] { defaults.set(true, forKey: "tm.navigation.\(key)") }
                defaults.set(true, forKey: "tm.navigation.macLibraryNearHome.v1")
                let store = SlotNavigationLayoutStore(defaults: defaults)
                let expected = newDefault.filter { saved.contains($0) }
                XCTAssertEqual(store.order, expected)
                XCTAssertEqual(SlotNavigationLayoutStore(defaults: defaults).order, expected)
            }
        }
    }

    func testACustomisedOrderIsLeftAlone() {
        let defaults = makeDefaults()
        let custom: [SlotNavigationDestination] = [.home, .coach, .workouts, .database, .schedule, .settings, .ranked, .map, .profile, .physique, .analytics]
        defaults.set(custom.map(\.rawValue), forKey: "tm.navigation.order.v1")
        for key in ["scheduleSettingsAdded", "rankedAdded"] { defaults.set(true, forKey: "tm.navigation.\(key)") }
        defaults.set(true, forKey: "tm.navigation.macLibraryNearHome.v1")
        let store = SlotNavigationLayoutStore(defaults: defaults)
        XCTAssertEqual(store.order, custom.filter(\.isAvailable))
    }

    func testTheMigrationRunsOnlyOnce() {
        let defaults = makeDefaults()
        let previous = SlotNavigationLayoutStore.previousDefaultOrders[0]
        defaults.set(previous.map(\.rawValue), forKey: "tm.navigation.order.v1")
        for key in ["scheduleSettingsAdded", "rankedAdded"] { defaults.set(true, forKey: "tm.navigation.\(key)") }
        defaults.set(true, forKey: "tm.navigation.macLibraryNearHome.v1")
        _ = SlotNavigationLayoutStore(defaults: defaults)
        defaults.set(previous.map(\.rawValue), forKey: "tm.navigation.order.v1")
        XCTAssertEqual(SlotNavigationLayoutStore(defaults: defaults).order, previous.filter(\.isAvailable))
    }
}
