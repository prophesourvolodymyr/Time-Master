import Foundation

enum MenuBarQuotes {
    static func quote(seed: Int) -> TmaxQuote {
        let all = TmaxQuotes.all
        let index = ((seed % all.count) + all.count) % all.count
        return all[index]
    }

    static func daily(_ date: Date = Date(), calendar: Calendar = .current) -> TmaxQuote {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = (parts.year ?? 0) * 372 + (parts.month ?? 0) * 31 + (parts.day ?? 0)
        return quote(seed: seed)
    }
}
