import Foundation
import TimeMasterCore

/// The writes of the skill board that the general skill writes do not cover: a sub-skill made already wearing a status
/// (a filtered list or a board column), a page placed beside another, a page moved inside another.
extension DatabaseStore {
    /// Creates a skill page on a board (a page id or a group id), in `sectionID` when the board is a page, at the end
    /// of its group, with `status`. Returns the new page's id.
    @discardableResult
    func createBoardSkill(title: String, on boardID: String, sectionID: String?, status: SkillStatus) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw FileSystemHelper.Error.writeFailed("A skill needs a name.") }
        let parentID: String
        if SkillGroupID.split(boardID) == nil, let sectionID {
            parentID = SkillGroupID.make(containerID: boardID, sectionID: sectionID)
        } else {
            parentID = boardID
        }
        var manifest = ExercisePageManifest(title: clean, pageType: .skill)
        manifest.skillStatus = status
        return try skillWrite { database in
            if SkillGroupID.split(parentID) == nil {
                manifest.skillBoardOrder = try database.nextSkillBoardOrder(containerID: parentID, sectionID: nil)
            }
            try database.createPage(manifest: manifest, parentID: parentID)
            return manifest.id
        }
    }

    /// Puts a page of a board right before or after `targetID`, in group `sectionID` (nil = outside every group).
    func placeSkillPage(_ pageID: String, beside targetID: String, after: Bool, sectionID: String?) throws {
        guard let moved = page(manifestID: pageID), let boardID = moved.manifest.parentID else {
            throw FileSystemHelper.Error.notFound(pageID)
        }
        var before: String? = targetID
        if after {
            let ids = skillPages(onBoard: boardID, sectionID: sectionID).map(\.manifest.id).filter { $0 != pageID }
            if let index = ids.firstIndex(of: targetID), index + 1 < ids.count {
                before = ids[index + 1]
            } else {
                before = nil
            }
        }
        try placeSkillPage(pageID, sectionID: .some(sectionID), before: before)
    }

    /// Moves a page inside `targetID`: it becomes the target's last child and, when it is a skill or a tutorial, the
    /// last of the skills outside every group on the target's board.
    func moveSkillPage(_ pageID: String, into targetID: String) throws {
        guard pageID != targetID, let moved = page(manifestID: pageID), let target = page(manifestID: targetID) else {
            throw FileSystemHelper.Error.notFound(pageID)
        }
        let status = moved.manifest.skillStatus ?? .notStarted
        let sections = target.manifest.orderedSkillBoardSections
        let position = target.manifest.childIDs.count
        try skillWrite { database in
            let order = try database.nextSkillBoardOrder(containerID: targetID, sectionID: nil)
            try database.movePage(id: pageID, newParentID: targetID, newOrder: position)
            if moved.isSkillLike {
                try database.updateSkillBoard(
                    containerID: targetID,
                    sections: sections,
                    placements: [SkillBoardPlacement(pageID: pageID, status: status, sectionID: nil, order: order)]
                )
            }
        }
    }
}
