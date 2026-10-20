import Foundation

struct TmaxQuote: Identifiable, Equatable {
    let id: String
    let text: String
    let author: String
    var source: String? = nil
}

enum TmaxQuotes {
    private static let originalNotes = [
        "You do not have to feel ready to take one kind step toward yourself.",
        "A small session is still a promise kept.",
        "Build a body you can live in, not one you have to fight.",
        "Some days, strength is showing up. Other days, it is letting yourself rest.",
        "Your starting point is not a verdict. It is a place to begin.",
        "The quiet work counts, even when nobody sees it.",
        "Progress can be a steadier breath, a better night, or one more honest try.",
        "You are allowed to begin again without punishing yourself for stopping.",
        "Train for the life you want to have outside the gym.",
        "Give consistency a smaller door to walk through.",
        "One good repetition deserves your full attention.",
        "A walk can be a way of coming back to yourself.",
        "You can be proud of the effort before you can see the result.",
        "Rest is part of the plan, not a departure from it.",
        "The strongest habit is the one you can return to.",
        "You do not need to win today. You need a next step you can trust.",
        "Let the person you are today start the work, not the person you wish you were.",
        "Make room for the days when doing less is doing enough.",
        "The work becomes yours each time you choose it again.",
        "There is courage in being a beginner where others can see you.",
        "Move with care. Your body is listening.",
        "Not every improvement needs a number.",
        "You are more than your fastest time and your heaviest lift.",
        "A patient pace is still a pace forward.",
        "The next ten minutes can be different from the last ten.",
        "Keep the promise small enough to keep on a difficult day.",
        "Make your next repetition thoughtful, not perfect.",
        "A missed day does not erase the days you showed up.",
        "Your body deserves respect before it changes.",
        "Come back gently. Staying is easier when starting does not hurt.",
        "Let your training support your life, not shrink it.",
        "You can take your goals seriously and still be kind to yourself.",
        "The finish line matters. So does the person who reaches it.",
        "Strength is built with attention as well as effort.",
        "Go slowly enough to notice what is getting easier.",
        "There is no shame in choosing the version you can do well.",
        "A shorter workout can still make a long day feel lighter.",
        "You are practicing returning, not proving you never struggle.",
        "Leave a little energy for wanting to come back tomorrow.",
        "A calm beginning is a strong beginning.",
        "Let recovery be something you choose, not something you have to earn.",
        "The best comparison is the one that helps you take care of yourself.",
        "Make effort a conversation with your body, not an argument.",
        "You can change the plan without giving up the purpose.",
        "The slow miles have a place in your story too.",
        "You are building more than a streak. You are building trust.",
        "Listen closely enough to tell a challenge from a warning.",
        "Training is not a debt you owe for eating or resting.",
        "Your effort is real even when the session looks ordinary.",
        "It is enough to make the next choice a caring one.",
        "Give the basics time to become part of you.",
        "The strength you are looking for may begin with asking for help.",
        "You do not need a perfect week to have a meaningful one.",
        "Let one steady breath bring you back to this repetition.",
        "The route does not have to be impressive to take you somewhere good.",
        "You can be grateful for your body and still want to grow stronger.",
        "Today is a chance to practice, not a test of your worth.",
        "Take the progress you can carry, and come back for the rest.",
        "A sustainable effort is an effort with a future.",
        "You are allowed to enjoy becoming stronger.",
        "A little movement can make space for a little hope.",
        "Choose the pace that lets you keep noticing the world.",
        "Your future self needs your care more than your criticism.",
        "Begin with what you have. Build from where you are."
    ]

    static let all: [TmaxQuote] = originalNotes.enumerated().map {
        TmaxQuote(id: "tmax-\($0.offset + 1)", text: $0.element, author: "Tmax · Training notes")
    } + [
        TmaxQuote(id: "epictetus-12", text: "Begin therefore with little things.", author: "Epictetus", source: "The Enchiridion, XII · Thomas W. Higginson translation · https://www.gutenberg.org/ebooks/45109"),
        TmaxQuote(id: "epictetus-29", text: "In every affair consider what precedes and what follows, and then undertake it.", author: "Epictetus", source: "The Enchiridion, XXIX · Thomas W. Higginson translation · https://www.gutenberg.org/ebooks/45109"),
        TmaxQuote(id: "epictetus-14", text: "Exercise, therefore, what is in your power.", author: "Epictetus", source: "The Enchiridion, XIV · Thomas W. Higginson translation · https://www.gutenberg.org/ebooks/45109"),
        TmaxQuote(id: "epictetus-48", text: "He employs his energies moderately in all directions.", author: "Epictetus", source: "The Enchiridion, XLVIII · Thomas W. Higginson translation · https://www.gutenberg.org/ebooks/45109")
    ]

    static func next(after previousID: String? = nil, defaults: UserDefaults = .standard) -> TmaxQuote {
        let previous = previousID ?? defaults.string(forKey: "tmax.loading.lastQuote")
        let previousIndex = all.firstIndex { $0.id == previous }
        var index = Int.random(in: 0..<(all.count - (previousIndex == nil ? 0 : 1)))
        if let previousIndex, index >= previousIndex { index += 1 }
        let quote = all[index]
        defaults.set(quote.id, forKey: "tmax.loading.lastQuote")
        return quote
    }
}
