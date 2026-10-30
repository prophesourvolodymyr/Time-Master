import Foundation
import TimeMasterCore

/// Picks an icon for a page from its title, for pages that have no icon of their own ("Card shake" gets a card,
/// "Spanish verbs" a speech bubble). Deliberately small: a keyword table, no model, no network, no scoring beyond
/// "a specific word beats a generic one". The first specific word of the title wins ("Ace cutting" is a card, not
/// scissors); a title that says nothing the table knows gets nothing, and the app falls back to its sparkles.
///
/// Both forms come from the same table: an emoji and an SF Symbol. `Style` is the user's choice (Settings).
enum SkillAutoIcon {
    enum Style: String, CaseIterable {
        case emoji
        case symbol
        case off

        var title: String {
            switch self {
            case .emoji: return "Emoji"
            case .symbol: return "Symbols"
            case .off: return "Off"
            }
        }
    }

    struct Pick: Equatable {
        let name: String
        let type: SkillBoardIconType
    }

    /// The icon for `title` in `style`; nil when the style is off or no word of the title is known.
    static func pick(forTitle title: String, style: Style) -> Pick? {
        guard style != .off, let entry = entry(forTitle: title) else { return nil }
        switch style {
        case .emoji: return Pick(name: entry.emoji, type: .emoji)
        case .symbol: return Pick(name: entry.symbol, type: .system)
        case .off: return nil
        }
    }

    /// The table row that fits `title` best, nil when none does.
    static func entry(forTitle title: String) -> Entry? {
        var best: (entry: Entry, weight: Int)?
        for word in words(in: title) {
            for candidate in stems(of: word) {
                guard let found = index[candidate] else { continue }
                if best == nil || found.weight > best!.weight { best = (found.entry, found.weight) }
                break
            }
        }
        return best?.entry
    }

    struct Entry: Equatable {
        let emoji: String
        let symbol: String
    }

    // MARK: Words

    /// Lowercase, accent-free words of a title (letters and digits only).
    static func words(in title: String) -> [String] {
        title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// The word itself, then with a plural, "-ing" or "-ed" ending removed ("shuffles" → "shuffle", "dealing" → "deal").
    static func stems(of word: String) -> [String] {
        var result = [word]
        func add(_ value: String) { if value.count >= 3, !result.contains(value) { result.append(value) } }
        if word.hasSuffix("ies") { add(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("es") { add(String(word.dropLast(2))) }
        if word.hasSuffix("s") { add(String(word.dropLast())) }
        if word.hasSuffix("ing") {
            let stem = String(word.dropLast(3))
            add(stem)
            add(stem + "e")
            if let last = stem.last, stem.count >= 2, stem.dropLast().last == last { add(String(stem.dropLast())) }   // running → run
        }
        if word.hasSuffix("ed") {
            let stem = String(word.dropLast(2))
            add(stem)
            add(stem + "e")
        }
        return result
    }

    // MARK: Table

    private struct Row {
        let words: String      // space-separated keywords
        let emoji: String
        let symbol: String
        let weight: Int        // 3 = names the thing, 2 = a clear hint, 1 = a generic word
    }

    private static let index: [String: (entry: Entry, weight: Int)] = {
        var table: [String: (entry: Entry, weight: Int)] = [:]
        for row in rows {
            let entry = Entry(emoji: row.emoji, symbol: row.symbol)
            for word in row.words.split(separator: " ") where table[String(word)] == nil {
                table[String(word)] = (entry, row.weight)
            }
        }
        return table
    }()

    private static let rows: [Row] = [
        // Cards and magic
        Row(words: "card cards deck ace aces joker jack queen king poker bridge solitaire shuffle shuffles riffle deal dealer cut cuts cardistry flourish flourishes palm glide lift", emoji: "🃏", symbol: "suit.spade.fill", weight: 3),
        Row(words: "magic magician trick tricks illusion sleight prestidigitation spell", emoji: "🎩", symbol: "wand.and.stars", weight: 3),
        Row(words: "coin coins penny", emoji: "🪙", symbol: "circle.circle.fill", weight: 3),
        Row(words: "dice die gamble casino", emoji: "🎲", symbol: "dice.fill", weight: 3),
        Row(words: "rope knot knots", emoji: "🪢", symbol: "lasso", weight: 3),
        // Music
        Row(words: "piano keyboard keys chords chord scales", emoji: "🎹", symbol: "pianokeys", weight: 3),
        Row(words: "guitar bass ukulele banjo", emoji: "🎸", symbol: "guitars", weight: 3),
        Row(words: "drum drums drumming percussion beat rhythm", emoji: "🥁", symbol: "metronome", weight: 3),
        Row(words: "violin cello fiddle orchestra", emoji: "🎻", symbol: "music.quarternote.3", weight: 3),
        Row(words: "sax saxophone trumpet flute clarinet brass", emoji: "🎷", symbol: "music.note", weight: 3),
        Row(words: "sing singing vocal vocals voice choir karaoke", emoji: "🎤", symbol: "mic.fill", weight: 3),
        Row(words: "music song songs melody tune album band composition compose", emoji: "🎵", symbol: "music.note", weight: 2),
        Row(words: "dj mixing producer production", emoji: "🎧", symbol: "headphones", weight: 2),
        // Languages and reading
        Row(words: "spanish espanol french german italian japanese chinese korean arabic russian portuguese latin hindi language languages vocabulary grammar verbs verb phrases pronunciation", emoji: "🗣️", symbol: "character.bubble", weight: 3),
        Row(words: "english translate translation words speaking conversation", emoji: "💬", symbol: "bubble.left.and.bubble.right", weight: 2),
        Row(words: "book books reading read novel literature library story stories", emoji: "📚", symbol: "book", weight: 2),
        Row(words: "write writing essay essays poem poetry journal notes blog", emoji: "✍️", symbol: "pencil.and.outline", weight: 2),
        // Games and thinking
        Row(words: "chess openings endgame gambit checkmate", emoji: "♟️", symbol: "puzzlepiece", weight: 3),
        Row(words: "puzzle puzzles sudoku riddle riddles logic", emoji: "🧩", symbol: "puzzlepiece", weight: 3),
        Row(words: "game games gaming gamedev videogame esports", emoji: "🎮", symbol: "gamecontroller", weight: 2),
        Row(words: "memory memorize memorise mnemonic mnemonics recall", emoji: "🧠", symbol: "brain.head.profile", weight: 2),
        Row(words: "idea ideas brainstorm creativity creative inspiration", emoji: "💡", symbol: "lightbulb", weight: 2),
        // Science, maths, code
        Row(words: "math maths mathematics algebra geometry calculus arithmetic statistics probability equation equations", emoji: "➗", symbol: "function", weight: 3),
        Row(words: "physics chemistry atom atoms molecule science quantum", emoji: "⚛️", symbol: "atom", weight: 3),
        Row(words: "biology cell dna genetics anatomy", emoji: "🧬", symbol: "leaf", weight: 3),
        Row(words: "code coding programming program swift python javascript typescript rust java html css sql developer software algorithm algorithms", emoji: "💻", symbol: "chevron.left.forwardslash.chevron.right", weight: 3),
        Row(words: "robot robotics ai machine arduino electronics circuit", emoji: "🤖", symbol: "cpu", weight: 3),
        Row(words: "data analytics chart charts graph graphs finance investing stocks trading", emoji: "📈", symbol: "chart.line.uptrend.xyaxis", weight: 2),
        // Art and media
        Row(words: "draw drawing sketch sketching illustration art painting paint watercolor watercolour", emoji: "🎨", symbol: "paintbrush.pointed", weight: 3),
        Row(words: "photo photography photograph camera lens portrait", emoji: "📷", symbol: "camera", weight: 3),
        Row(words: "video film filming editing movie cinema premiere", emoji: "🎬", symbol: "film", weight: 3),
        Row(words: "design designing typography logo branding figma ui ux", emoji: "✏️", symbol: "pencil.and.ruler", weight: 2),
        Row(words: "acting theatre theater improv drama stage", emoji: "🎭", symbol: "theatermasks", weight: 3),
        Row(words: "dance dancing ballet salsa hiphop choreography", emoji: "💃", symbol: "figure.dance", weight: 3),
        // Body and sport
        Row(words: "boxing box punch punches jab sparring", emoji: "🥊", symbol: "figure.boxing", weight: 3),
        Row(words: "kickboxing kick kicks muay karate taekwondo judo martial", emoji: "🥋", symbol: "figure.kickboxing", weight: 3),
        Row(words: "run running jog jogging marathon sprint cardio", emoji: "🏃", symbol: "figure.run", weight: 3),
        Row(words: "swim swimming pool freestyle backstroke", emoji: "🏊", symbol: "figure.pool.swim", weight: 3),
        Row(words: "yoga stretch stretching flexibility mobility pilates meditation meditate mindfulness", emoji: "🧘", symbol: "figure.mind.and.body", weight: 3),
        Row(words: "gym lifting weights strength squat deadlift bench calisthenics pullup pushup", emoji: "🏋️", symbol: "dumbbell", weight: 3),
        Row(words: "gymnastics handstand flip tumbling acrobatics parkour", emoji: "🤸", symbol: "figure.gymnastics", weight: 3),
        Row(words: "bike biking cycling bicycle", emoji: "🚴", symbol: "bicycle", weight: 3),
        Row(words: "football soccer basketball tennis golf volleyball baseball hockey sport sports", emoji: "⚽", symbol: "sportscourt", weight: 2),
        Row(words: "climb climbing bouldering hiking hike mountain", emoji: "🧗", symbol: "mountain.2", weight: 3),
        Row(words: "skate skateboard skateboarding surf surfing snowboard ski skiing", emoji: "🛹", symbol: "figure.skiing.downhill", weight: 3),
        // Life skills
        Row(words: "cook cooking recipe recipes baking bake kitchen chef cuisine", emoji: "🍳", symbol: "fork.knife", weight: 3),
        Row(words: "coffee barista espresso latte", emoji: "☕️", symbol: "cup.and.saucer", weight: 3),
        Row(words: "garden gardening plants plant farming", emoji: "🌱", symbol: "leaf", weight: 3),
        Row(words: "sew sewing knit knitting crochet embroidery tailoring", emoji: "🧵", symbol: "scissors", weight: 3),
        Row(words: "woodworking carpentry carpenter build building repair fix diy tools", emoji: "🔨", symbol: "hammer", weight: 2),
        Row(words: "drive driving car driver", emoji: "🚗", symbol: "car", weight: 2),
        Row(words: "fly flying pilot aviation", emoji: "✈️", symbol: "airplane", weight: 2),
        Row(words: "travel trip journey", emoji: "🧳", symbol: "suitcase", weight: 1),
        Row(words: "speak speaking speech presentation presenting public pitch pitching", emoji: "🎙️", symbol: "mic", weight: 2),
        Row(words: "business startup marketing sales career management leadership negotiation", emoji: "💼", symbol: "briefcase", weight: 2),
        Row(words: "money budget budgeting savings", emoji: "💰", symbol: "banknote", weight: 2),
        Row(words: "sleep rest recovery", emoji: "😴", symbol: "bed.double", weight: 2),
        Row(words: "health nutrition diet fitness wellness", emoji: "🥗", symbol: "heart", weight: 2),
        // Generic structure words (weak hints)
        Row(words: "basics basic intro introduction fundamentals beginner beginners start", emoji: "🌱", symbol: "leaf", weight: 1),
        Row(words: "advanced master mastery expert pro", emoji: "⭐️", symbol: "star", weight: 1),
        Row(words: "practice drill drills exercise exercises training warmup", emoji: "🎯", symbol: "target", weight: 1),
        Row(words: "theory concept concepts principles", emoji: "🧠", symbol: "brain.head.profile", weight: 1),
        Row(words: "technical technique techniques technology", emoji: "⚙️", symbol: "gearshape", weight: 1),
        Row(words: "performance perform show stage routine", emoji: "🎪", symbol: "sparkles.tv", weight: 1),
        Row(words: "goal goals plan planning roadmap", emoji: "🗺️", symbol: "flag", weight: 1),
    ]
}
