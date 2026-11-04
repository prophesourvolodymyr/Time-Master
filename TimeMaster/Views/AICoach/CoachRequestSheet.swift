import SwiftUI
import TimeMasterCore

struct CoachRequestSheet: View {
    let request: EverAgentUIRequest

    @State private var selections: [String: Set<String>] = [:]
    @State private var customText: [String: String] = [:]
    @State private var text = ""

    private struct Question {
        struct Option {
            let label: String
            let detail: String?
        }

        let id: String
        let prompt: String
        let options: [Option]
        let multi: Bool
    }

    private var questions: [Question] {
        request.payload["questions"].arrayValue.compactMap { item in
            guard let id = item["id"].stringValue else { return nil }
            let options = item["options"].arrayValue.compactMap { option -> Question.Option? in
                guard let label = option["label"].stringValue ?? option.stringValue else { return nil }
                return Question.Option(label: label, detail: option["description"].stringValue)
            }
            return Question(id: id, prompt: item["question"].text, options: options, multi: item["multi"].boolValue)
        }
    }

    private var choices: [String] {
        request.raw["options"].arrayValue.compactMap { $0["label"].stringValue ?? $0.stringValue }
    }

    private var message: String? {
        request.payload["message"].stringValue ?? request.message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(request.title.isEmpty ? "Your coach is asking" : request.title)
                .font(TimeMasterFont.black(20, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .padding(20)
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 500, minHeight: 260)
        #endif
        .background(Theme.background)
        .onAppear { text = request.raw["value"].stringValue ?? "" }
        .interactiveDismissDisabled(false)
    }

    @ViewBuilder
    private var content: some View {
        switch request.kind {
        case "question":
            ForEach(questions, id: \.id) { question in
                questionView(question)
            }
        case "confirm":
            Text(message ?? "Allow this?")
                .font(TimeMasterFont.body())
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case "select":
            ForEach(choices, id: \.self) { choice in
                Button(choice) { send(["value": .string(choice)]) }
                    .buttonStyle(TimeMasterActionButtonStyle())
            }
        case "input", "editor":
            TextEditor(text: $text)
                .font(TimeMasterFont.body())
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .modifier(TimeMasterCardSurface(cornerRadius: 12, flat: true))
        default:
            Text("This request cannot be shown in Tmax yet. You can cancel it and ask your coach again.")
                .font(TimeMasterFont.body())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func questionView(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.prompt)
                .font(TimeMasterFont.black(15, relativeTo: .subheadline))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(question.options, id: \.label) { option in
                Button {
                    toggle(option.label, in: question)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected(option.label, in: question) ? (question.multi ? "checkmark.square.fill" : "largecircle.fill.circle") : (question.multi ? "square" : "circle"))
                            .foregroundStyle(Theme.toolbarOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(TimeMasterFont.body(14, relativeTo: .subheadline))
                                .foregroundStyle(Theme.textPrimary)
                            if let detail = option.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(TimeMasterFont.caption())
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            TextField("Something else", text: customBinding(for: question))
                .textFieldStyle(.roundedBorder)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { cancel() }
                .buttonStyle(TimeMasterActionButtonStyle())
            switch request.kind {
            case "question":
                Button("Send answer") { submitQuestions() }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
                    .disabled(!questionsAnswered)
            case "confirm":
                Button("Don't allow") { send(["approved": false]) }
                    .buttonStyle(TimeMasterActionButtonStyle())
                Button("Allow") { send(["approved": true]) }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
            case "input", "editor":
                Button("Send") { send(["text": .string(text)]) }
                    .buttonStyle(TimeMasterActionButtonStyle(prominent: true))
            default:
                EmptyView()
            }
        }
    }

    private var questionsAnswered: Bool {
        let all = questions
        guard !all.isEmpty else { return false }
        return all.allSatisfy { question in
            !(selections[question.id] ?? []).isEmpty || !(customText[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func selected(_ label: String, in question: Question) -> Bool {
        (selections[question.id] ?? []).contains(label)
    }

    private func toggle(_ label: String, in question: Question) {
        var current = selections[question.id] ?? []
        if question.multi {
            if current.contains(label) { current.remove(label) } else { current.insert(label) }
        } else {
            current = [label]
            customText[question.id] = ""
        }
        selections[question.id] = current
    }

    private func customBinding(for question: Question) -> Binding<String> {
        Binding(
            get: { customText[question.id] ?? "" },
            set: { value in
                customText[question.id] = value
                if !question.multi, !value.isEmpty { selections[question.id] = [] }
            }
        )
    }

    private func submitQuestions() {
        let results: [JSONValue] = questions.map { question in
            let chosen = question.options.map(\.label).filter { (selections[question.id] ?? []).contains($0) }
            var item: [String: JSONValue] = ["id": .string(question.id), "selectedOptions": .array(chosen.map { .string($0) })]
            let custom = (customText[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !custom.isEmpty { item["customInput"] = .string(custom) }
            return .object(item)
        }
        send(["kind": "submit", "results": .array(results)])
    }

    private func send(_ result: JSONValue) {
        Task { await EverAgentCoachEngine.shared.answer(result) }
    }

    private func cancel() {
        Task { await EverAgentCoachEngine.shared.answer(.null, cancelled: true) }
    }
}
