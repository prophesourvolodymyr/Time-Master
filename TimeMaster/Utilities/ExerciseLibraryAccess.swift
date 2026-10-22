import Foundation

final class ExerciseLibraryAccess: @unchecked Sendable {
    struct Token: Sendable {
        fileprivate let generation: UInt64?
    }

    enum AccessError: LocalizedError {
        case accountChanged

        var errorDescription: String? {
            "Your exercise library changed before this save finished. Return to the library and try again."
        }
    }

    static let shared = ExerciseLibraryAccess()
    private let condition = NSCondition()
    private var generation: UInt64 = 0
    private var activeOperations = 0
    private var accountChanges = 0

    func capture() -> Token {
        condition.lock()
        defer { condition.unlock() }
        return Token(generation: accountChanges == 0 ? generation : nil)
    }

    func isCurrent(_ token: Token) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        return token.generation == generation && accountChanges == 0
    }

    func perform<T>(token: Token, operation: () throws -> T) throws -> T {
        condition.lock()
        guard token.generation == generation, accountChanges == 0 else {
            condition.unlock()
            throw AccessError.accountChanged
        }
        activeOperations += 1
        condition.unlock()
        defer { finishOperation() }
        return try operation()
    }

    func beginAccountChange() async {
        guard startAccountChange() else { return }
        await Task.detached(priority: .userInitiated) { self.waitForActiveOperations() }.value
    }

    func endAccountChange() {
        condition.lock()
        defer { condition.unlock() }
        precondition(accountChanges > 0)
        accountChanges -= 1
    }

    private func startAccountChange() -> Bool {
        condition.lock()
        defer { condition.unlock() }
        generation &+= 1
        accountChanges += 1
        return activeOperations > 0
    }

    private func finishOperation() {
        condition.lock()
        defer { condition.unlock() }
        activeOperations -= 1
        if activeOperations == 0 { condition.broadcast() }
    }

    private func waitForActiveOperations() {
        condition.lock()
        defer { condition.unlock() }
        while activeOperations > 0 { condition.wait() }
    }
}
