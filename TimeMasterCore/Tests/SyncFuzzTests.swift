import XCTest
@testable import TimeMasterCore

struct SyncSeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class SyncFuzzTests: SyncPairTestCase {
    private var log: [String] = []

    private func randomEdit(on replica: Replica, using random: inout SyncSeededRandom, step: Int) {
        let db = replica.db
        let who = replica.engine.deviceName
        let pages = replica.pages()
        let ids = pages.keys.sorted()
        func pick() -> String? { ids.isEmpty ? nil : ids[Int.random(in: 0..<ids.count, using: &random)] }
        func name(_ id: String) -> String { String(id.prefix(4)) + "(" + (pages[id]?.title ?? "?") + ")" }
        func containers() -> [String] { ids.filter { pages[$0]?.pageKind == .container } }
        switch Int.random(in: 0..<26, using: &random) {
        case 0:
            let type: PageType? = [PageType.skill, PageType.tutorial, nil, PageType.exercise][step % 4]
            if (try? makePage(replica, "Root \(step)", type: type)) != nil { log.append("\(step) \(who): new root page Root \(step)") }
        case 1, 2:
            if let parent = containers().randomElement(using: &random), (try? makePage(replica, "Page \(step)", parent: parent, type: [PageType.skill, PageType.exercise][step % 2])) != nil {
                log.append("\(step) \(who): new page Page \(step) under \(name(parent))")
            }
        case 3:
            if let id = pick() { try? replica.edit(id) { $0.title = "Renamed \(step)" }; log.append("\(step) \(who): rename \(name(id)) -> Renamed \(step)") }
        case 4:
            if let id = pick(), pages[id]?.pageType == .skill { try? replica.edit(id) { $0.skillStatus = [.notStarted, .learning, .completed][step % 3] }; log.append("\(step) \(who): status \(name(id))") }
        case 5:
            if let id = pick() { try? replica.edit(id) { $0.markdownBody += "\nline \(step)" }; log.append("\(step) \(who): body \(name(id))") }
        case 6:
            if let id = pick(), let parent = containers().randomElement(using: &random), id != parent, (try? db.movePage(id: id, newParentID: parent, newOrder: Int.random(in: 0...3, using: &random))) != nil {
                log.append("\(step) \(who): move \(name(id)) under \(name(parent))")
            }
        case 7:
            if ids.count > 4, let id = pick(), (try? db.deletePage(id: id)) != nil { log.append("\(step) \(who): delete \(name(id))") }
        case 8:
            if let id = pick() { try? replica.edit(id) { $0.linkURLs.append("https://example.com/\(step)") }; log.append("\(step) \(who): link on \(name(id))") }
        case 9:
            if let id = pick(), let page = pages[id], page.childIDs.count > 1 {
                try? db.reorderChildren(parentID: id, childIDs: page.childIDs.reversed())
                log.append("\(step) \(who): reverse children of \(name(id))")
            }
        case 10:
            if let id = pick(), pages[id]?.pageType == .skill, pages[id]?.parentID == nil || true, (try? db.addSkillGroup(to: id, title: "Group \(step)")) != nil {
                log.append("\(step) \(who): group on \(name(id))")
            }
        case 11:
            if let id = pick(), let source = try? writeFile("file \(step)"), (try? db.uploadMediaToPage(pageID: id, sourceURL: source)) != nil {
                log.append("\(step) \(who): attach media to \(name(id))")
            }
        case 12:
            if let id = pick(), let file = pages[id]?.mediaFilenames.first, (try? db.removeMediaFromPage(pageID: id, filename: file)) != nil {
                log.append("\(step) \(who): remove media from \(name(id))")
            }
        case 13:
            if let id = pick(), let folder = try? replica.folder(id) {
                let work = folder.appendingPathComponent("work", isDirectory: true)
                try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                try? Data("work \(step)".utf8).write(to: work.appendingPathComponent("w\(step % 3).txt"))
                log.append("\(step) \(who): work file in \(name(id))")
            }
        case 14:
            if let id = pick(), let folder = try? replica.folder(id) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent("work/w\(step % 3).txt"))
                log.append("\(step) \(who): remove work file in \(name(id))")
            }
        case 15:
            try? db.appendHistoryEntry(historyEntry("Workout \(step)", at: 1_800_000_000 + Double(step) * 40_000))
            log.append("\(step) \(who): history entry")
        case 16:
            if let entries = try? db.readHistory(), let last = entries.last, (try? db.replaceHistory(Array(entries.dropLast()))) != nil {
                log.append("\(step) \(who): delete \(last.workoutName) from history")
            }
        case 17:
            if (try? makeWorkout(replica, name: "Workout \(step)")) != nil { log.append("\(step) \(who): new workout \(step)") }
        case 18:
            if let workouts = try? db.listWorkouts(), var workout = workouts.randomElement(using: &random) {
                if step % 2 == 0 { workout.sections.append(WorkoutSectionManifest(exerciseID: "", name: "Section \(step)", duration: 30)) } else { workout.name = "Workout renamed \(step)" }
                try? db.updateWorkout(id: workout.id, manifest: workout)
                log.append("\(step) \(who): edit workout \(workout.id.prefix(4))")
            }
        case 19:
            if let workouts = try? db.listWorkouts(), let workout = workouts.randomElement(using: &random), (try? db.deleteWorkout(id: workout.id)) != nil {
                log.append("\(step) \(who): delete workout \(workout.id.prefix(4))")
            }
        case 20:
            var config = (try? db.loadConfig()) ?? ConfigManifest()
            config.restDays.append("2026-01-\(String(format: "%02d", step % 28 + 1))")
            if step % 3 == 0 { config.weeklyGoal = step % 7 + 1 }
            try? db.saveConfig(config)
            log.append("\(step) \(who): settings")
        case 21:
            let id = UUID().uuidString
            try? db.fs.ensureDirectory(db.fs.routesDirectory)
            try? Data(#"{"id":"\#(id)","name":"Route \#(step)"}"#.utf8).write(to: db.fs.routesDirectory.appendingPathComponent("\(id).json"))
            log.append("\(step) \(who): new route")
        case 22:
            let url = replica.photos.appendingPathComponent("p\(step % 4).jpg")
            if step % 3 == 0 { try? FileManager.default.removeItem(at: url) } else { try? Data("photo \(step)".utf8).write(to: url) }
            log.append("\(step) \(who): photo p\(step % 4)")
        case 23, 24:
            if let id = pick(), let board = pages[id], board.pageKind == .container, let child = board.childIDs.randomElement(using: &random),
               pages[child]?.pageType == .skill || pages[child]?.pageType == .tutorial {
                let sections = board.orderedSkillBoardSections
                let section = step % 3 == 0 ? nil : sections.randomElement(using: &random)?.id
                let placement = SkillBoardPlacement(pageID: child, status: [.notStarted, .learning, .completed][step % 3], sectionID: section, order: step % 5)
                if (try? db.updateSkillBoard(containerID: id, sections: sections, placements: [placement])) != nil {
                    log.append("\(step) \(who): place \(name(child)) on the board of \(name(id))")
                }
            }
        default:
            let url = replica.fs.mediaDirectory.appendingPathComponent("m\(step % 3).bin")
            if step % 2 == 0 { try? FileManager.default.removeItem(at: url) } else { try? Data("media \(step)".utf8).write(to: url) }
            log.append("\(step) \(who): legacy media m\(step % 3)")
        }
    }

    private func run(seed: UInt64, steps: Int, syncOneIn: Int) async throws -> Bool {
        log = []
        var random = SyncSeededRandom(seed: seed)
        _ = try makePiano(on: mac)
        try await sync()
        func isValid(_ what: String) -> Bool {
            for replica in [mac!, phone!] {
                let found = libraryProblems(replica)
                if !found.isEmpty {
                    XCTFail("seed \(seed) after \(what): \(replica.engine.deviceName) is invalid: \(found)\n" + log.suffix(16).joined(separator: "\n"))
                    return false
                }
            }
            return true
        }
        for step in 0..<steps {
            let replica = Bool.random(using: &random) ? mac! : phone!
            randomEdit(on: replica, using: &random, step: step)
            if Int.random(in: 0..<syncOneIn, using: &random) == 0 {
                let driver = Bool.random(using: &random) ? mac! : phone!
                try await sync(from: driver, with: driver.root == mac.root ? phone : mac)
                log.append("\(step) sync driven by \(driver.engine.deviceName)")
                guard isValid("sync at step \(step)") else { return false }
            } else {
                guard isValid("step \(step)") else { return false }
            }
        }
        try await sync()
        try await sync(from: phone, with: mac)
        try await sync()
        let x = try mac.engine.scan()
        let y = try phone.engine.scan()
        let differing = Set(x.units.map { "\($0.key) \($0.hash)" }).symmetricDifference(y.units.map { "\($0.key) \($0.hash)" })
        if !differing.isEmpty {
            XCTFail("seed \(seed): the devices do not agree on \(differing.sorted().prefix(6))\n" + log.suffix(24).joined(separator: "\n"))
            return false
        }
        XCTAssertEqual(x.config?.hash, y.config?.hash, "seed \(seed): settings differ")
        XCTAssertEqual(x.shards, y.shards, "seed \(seed): history differs")
        return isValid("the final syncs")
    }

    private func runSeeds(_ seeds: ClosedRange<UInt64>, steps: Int, syncOneIn: Int = 5) async throws {
        for seed in seeds {
            guard try await run(seed: seed, steps: steps, syncOneIn: syncOneIn) else { return }
            try tearDownWithError()
            try setUpWithError()
        }
    }

    func testRandomEditsOnTwoDevicesConverge() async throws {
        try await runSeeds(1...20, steps: 50)
    }

    func testRandomEditsMadeWhileApartConverge() async throws {
        try await runSeeds(201...216, steps: 60, syncOneIn: 15)
    }

    func testRandomEditsOnTwoDevicesConvergeLongerRuns() async throws {
        try await runSeeds(101...108, steps: 140)
    }
}
