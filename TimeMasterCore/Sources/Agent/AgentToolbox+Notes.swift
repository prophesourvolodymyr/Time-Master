import Foundation

extension AgentToolbox {
    static let bodyExcerptLimit = 8000
    static let noteImageLimit = 30

    func runNoteTool(_ name: String, _ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput? {
        switch name {
        case "create_note_page": return try createNotePage(args, dryRun: dryRun)
        default: return nil
        }
    }

    /// The Markdown body for `get_page`: all of it, or one piece with `bodyChars`, `truncated` and `nextOffset` to read on.
    func bodyExcerpt(_ body: String, offset: Int) -> [String: Any] {
        guard !body.isEmpty else { return [:] }
        let total = body.count
        let start = min(max(0, offset), total)
        guard start > 0 || total > Self.bodyExcerptLimit else { return ["markdownBody": body] }
        let end = min(total, start + Self.bodyExcerptLimit)
        let from = body.index(body.startIndex, offsetBy: start)
        let to = body.index(from, offsetBy: end - start)
        var out: [String: Any] = ["markdownBody": String(body[from..<to]), "bodyChars": total]
        if end < total {
            out["truncated"] = true
            out["nextOffset"] = end
        }
        return out
    }

    func appendedNoteBody(_ body: String, adding text: String) -> String {
        var trimmed = Substring(body)
        while let last = trimmed.last, last.isNewline || last == " " { trimmed = trimmed.dropLast() }
        return trimmed.isEmpty ? text : String(trimmed) + "\n\n" + text
    }

    func rejectNonNoteFields(_ args: AgentArguments) throws {
        let timing = ["duration", "restAfter", "sets", "restBetweenSets", "prepareTime", "linkURLs", "workoutType"].filter { args.has($0) }
        guard timing.isEmpty else {
            throw AgentToolError("invalid_page", "Notes hold only a title, an icon and Markdown; '\(timing.joined(separator: ", "))' does not apply.", hint: "Put links in the Markdown body.")
        }
    }

    func applyIcon(_ icon: String, to page: inout ExercisePageManifest) throws {
        guard page.pageType == .note else {
            throw AgentToolError("invalid_page", "Only note pages take an icon here.")
        }
        let clean = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        page.iconName = clean.isEmpty ? nil : clean
        page.iconType = clean.isEmpty ? nil : (clean.unicodeScalars.allSatisfy { $0.isASCII } ? .system : .emoji)
    }

    private func noteImageURL(_ path: String) throws -> URL {
        let url = try AgentMedia.validate(path: path)
        guard DatabaseManager.noteImageExtensions.contains(url.pathExtension.lowercased()) else {
            throw AgentToolError("unsupported_media", "Notes show pictures only; '.\(url.pathExtension.lowercased())' cannot go into a note.", hint: "Use jpg, png, heic, gif or webp.")
        }
        return url
    }

    func attachImageToNote(_ page: ExercisePageManifest, _ args: AgentArguments, titlePath: String, dryRun: Bool) throws -> AgentToolOutput {
        let url = try noteImageURL(try args.requiredString("path"))
        if dryRun {
            return AgentToolOutput(value: ["dryRun": true, "wouldAttach": url.lastPathComponent, "to": titlePath, "inline": true])
        }
        let relative = try database.importNoteImage(pageID: page.id, sourceURL: url)
        var updated = page
        updated.markdownBody = appendedNoteBody(page.markdownBody, adding: DatabaseManager.noteImageMarkdown(path: relative, alt: args.string("comment") ?? ""))
        try database.updatePage(id: page.id, manifest: updated, newParentID: page.parentID)
        return AgentToolOutput(
            value: ["id": page.id, "path": titlePath, "attached": "image", "inline": true],
            effects: [.changedMarkdown(pageID: page.id, previous: page.markdownBody)]
        )
    }

    private func createNotePage(_ args: AgentArguments, dryRun: Bool) throws -> AgentToolOutput {
        let index = try AgentPageIndex(database: database)
        let title = try args.requiredString("title")
        let parent = try args.string("parent").map { try index.resolve($0) }
        if let parent {
            switch parent.pageType {
            case nil: break
            case .skill?, .tutorial?:
                throw AgentToolError("invalid_parent", "'\(parent.title)' is a \(index.kind(parent)); notes cannot live inside skills or tutorials.", hint: "Choose a folder with list_pages, or omit parent for the root.")
            case .exercise?, .note?:
                throw AgentToolError("invalid_parent", "'\(parent.title)' is \(parent.pageType == .note ? "a note" : "an exercise page") and cannot contain other pages.", hint: "Choose a folder with list_pages.")
            }
        }
        if let existing = index.children(of: parent?.id).first(where: { AgentValue.fold($0.title) == AgentValue.fold(title) }) {
            switch args.string("ifExists") ?? "error" {
            case "reuse":
                var value = index.summary(existing, withID: true)
                value["reused"] = true
                return AgentToolOutput(value: value)
            case "duplicate":
                break
            default:
                throw AgentToolError("already_exists", "A page titled '\(title)' already exists here.", hint: "Pass ifExists \"reuse\" to get it back unchanged, or \"duplicate\" to create another.", details: ["existingID": existing.id])
            }
        }
        let images = try (args.strings("images") ?? []).map { try noteImageURL($0) }
        guard images.count <= Self.noteImageLimit else {
            throw AgentToolError("media_limit", "A note takes up to \(Self.noteImageLimit) pictures per call.")
        }
        let path = (parent.map { index.titlePath($0.id) + "/" } ?? "") + title
        if dryRun {
            var preview: [String: Any] = ["dryRun": true, "wouldCreate": path]
            if !images.isEmpty { preview["images"] = images.count }
            return AgentToolOutput(value: preview)
        }
        var manifest = ExercisePageManifest(title: title, pageType: .note, markdownBody: args.string("markdownBody") ?? "", parentID: parent?.id)
        if let icon = args.string("icon") { try applyIcon(icon, to: &manifest) }
        try database.createPage(manifest: manifest, parentID: parent?.id)
        do {
            if !images.isEmpty {
                var body = manifest.markdownBody
                for url in images {
                    let relative = try database.importNoteImage(pageID: manifest.id, sourceURL: url)
                    body = appendedNoteBody(body, adding: DatabaseManager.noteImageMarkdown(path: relative))
                }
                var saved = try database.getPage(id: manifest.id)
                saved.markdownBody = body
                try database.updatePage(id: manifest.id, manifest: saved, newParentID: parent?.id)
            }
        } catch {
            try? database.deletePage(id: manifest.id)
            throw error
        }
        var value: [String: Any] = ["id": manifest.id, "path": path]
        if !images.isEmpty { value["images"] = images.count }
        return AgentToolOutput(value: value, effects: [.createdPage(id: manifest.id)])
    }
}
