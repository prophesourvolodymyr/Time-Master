import XCTest
@testable import TimeMasterCore

final class ChecklistMergeTests: XCTestCase {
    private let pageID = "22222222-2222-2222-2222-222222222222"

    private func page(todos: [TodoItem] = [], milestones: [Milestone] = [], media: [String] = []) -> ExercisePageManifest {
        ExercisePageManifest(
            id: pageID, title: "Single leg", pageType: .skill, mediaFilenames: media, todos: todos, milestones: milestones,
            createdAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 2_000)
        )
    }

    private func merge(_ base: ExercisePageManifest?, _ local: ExercisePageManifest, _ remote: ExercisePageManifest, preferRemote: Bool = false) throws -> ExercisePageManifest {
        try SyncManifestMerge.merge(base: base, local: local, remote: remote, preferRemote: preferRemote, localLabel: "Mac", remoteLabel: "iPhone").manifest
    }

    private let created = Date(timeIntervalSince1970: 500)

    func testEntriesAddedOnBothDevicesAreAllKept() throws {
        let base = page(todos: [TodoItem(id: "a", title: "Stance", createdAt: created)])
        var mac = base
        mac.todos.append(TodoItem(id: "m", title: "Mac step", createdAt: created))
        var phone = base
        phone.todos.append(TodoItem(id: "p", title: "Phone step", createdAt: created))
        phone.todos[0].children.append(TodoItem(id: "pc", title: "Phone child", createdAt: created))
        let merged = try merge(base, mac, phone)
        XCTAssertEqual(Set(merged.todos.map(\.id)), ["a", "m", "p"])
        XCTAssertEqual(merged.todos.entry("a")?.children.map(\.id), ["pc"])
    }

    func testCheckingOnOneDeviceAndRenamingOnTheOtherKeepsBoth() throws {
        let base = page(milestones: [Milestone(id: "m", title: "First takedown", createdAt: created)])
        var mac = base
        mac.milestones[0].isDone = true
        mac.milestones[0].doneAt = Date(timeIntervalSince1970: 3_000)
        var phone = base
        phone.milestones[0].title = "First takedown live"
        let merged = try merge(base, mac, phone)
        XCTAssertTrue(merged.milestones[0].isDone)
        XCTAssertEqual(merged.milestones[0].title, "First takedown live")
    }

    func testAnEditBeatsADeletionOfTheSameEntryAsElsewhereInSync() throws {
        let base = page(todos: [TodoItem(id: "a", title: "Stance", createdAt: created), TodoItem(id: "b", title: "Shot", createdAt: created)])
        var mac = base
        mac.todos.removeAll { $0.id == "b" }
        var phone = base
        phone.todos[1].note = "Drop the level first"
        let merged = try merge(base, mac, phone)
        XCTAssertEqual(merged.todos.entry("b")?.note, "Drop the level first", "the existing policy: an edit resurrects what the other side removed")
        var untouched = base
        untouched.title = "Single leg"
        XCTAssertNil(try merge(base, mac, untouched).todos.entry("b"), "a removal with no edit on the other side stays removed")
    }

    func testAMergedCheckedParentWithANewOpenChildIsOpened() throws {
        let base = page(todos: [TodoItem(id: "p", title: "Setups", createdAt: created)])
        var mac = base
        mac.todos[0].isDone = true
        mac.todos[0].doneAt = Date(timeIntervalSince1970: 3_000)
        var phone = base
        phone.todos[0].children = [TodoItem(id: "c", title: "Collar tie", createdAt: created)]
        let merged = try merge(base, mac, phone)
        XCTAssertFalse(merged.todos[0].isDone, "a checked entry never has an open one below it")
    }

    func testASectionAndAPictureTheOtherSideRemovedAreTidied() throws {
        let base = page(todos: [TodoItem(id: "a", title: "A", createdAt: created)], media: ["x.jpg"])
        var mac = base
        mac.mediaFilenames = []
        var phone = base
        phone.todos[0].imageFilenames = ["x.jpg"]
        phone.todos.append(TodoItem(id: "s", title: "Finishes", createdAt: created, isSection: true))
        let merged = try merge(base, mac, phone)
        XCTAssertTrue(merged.todos[0].imageFilenames.isEmpty)
        XCTAssertTrue(merged.todos.entry("s")?.isSection == true)
    }
}

final class ChecklistDeviceSyncTests: SyncPairTestCase {
    func testListsAndTheirPicturesTravelAndDivergentEditsConverge() async throws {
        let page = try makePage(mac, "Single leg")
        let stance = try mac.db.addChecklistEntry(TodoItem(title: "Stance"), to: page.id)
        let milestone = try mac.db.addChecklistEntry(Milestone(title: "First takedown"), to: page.id)
        let cover = try mac.db.attachChecklistPicture(Milestone.self, from: try writeFile("jpeg bytes", named: "cover.jpg"), to: milestone.id, in: page.id, as: .cover)
        try await sync()
        XCTAssertEqual(try phone.db.checklist(TodoItem.self, of: page.id).map(\.title), ["Stance"])
        XCTAssertEqual(try phone.db.checklist(Milestone.self, of: page.id).first?.coverMediaFilename, cover)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try phone.folder(page.id).appendingPathComponent("media/\(cover)").path), "the cover file travels with the page")

        try mac.db.addChecklistEntry(TodoItem(title: "Mac step"), to: page.id)
        try mac.db.setChecklistEntry(TodoItem.self, stance.id, done: true, in: page.id)
        try phone.db.addChecklistEntry(TodoItem(title: "Phone step"), to: page.id)
        try phone.db.updateChecklistEntry(TodoItem.self, stance.id, in: page.id) { $0.title = "Stance and motion" }
        try phone.db.addChecklistSection(Milestone.self, title: "Competition", to: page.id)
        try await sync()

        for replica in [mac!, phone!] {
            let todos = try replica.db.checklist(TodoItem.self, of: page.id)
            XCTAssertEqual(Set(todos.map(\.title)), ["Stance and motion", "Mac step", "Phone step"])
            XCTAssertTrue(todos.entry(stance.id)?.isDone == true)
            XCTAssertEqual(try replica.db.checklist(Milestone.self, of: page.id).filter(\.isSection).map(\.title), ["Competition"])
        }
        try assertInSync()
    }
}
