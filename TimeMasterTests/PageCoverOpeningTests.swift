import XCTest
import TimeMasterCore
@testable import TimeMaster

/// What a click on a page's cover in a Database list previews: the clips the popup gets.
final class PageCoverOpeningTests: XCTestCase {
    private let photo = URL(fileURLWithPath: "/library/Squat/front.jpg")
    private let side = URL(fileURLWithPath: "/library/Squat/side.mov")
    private let cues = URL(fileURLWithPath: "/library/Squat/cues.pdf")
    private let slow = URL(fileURLWithPath: "/library/Squat/slow.MP4")

    private func page(
        _ type: PageType?,
        kind: ExercisePageManifest.PageKind = .container,
        media: [URL]
    ) -> ExercisePage {
        ExercisePage(manifest: ExercisePageManifest(title: "Squat", pageKind: kind, pageType: type), mediaURLs: media)
    }

    func testTheViewerShowsAnExercisesVideosInThePagesOrder() {
        let squat = page(.exercise, kind: .leaf, media: [photo, side, cues, slow])
        XCTAssertEqual(PageCoverOpening.clips(of: squat), [side, slow])
        XCTAssertEqual(PageCoverOpening.firstClip(of: squat), side)
    }

    func testSkillsAndTutorialsShowTheirClipsToo() {
        XCTAssertEqual(PageCoverOpening.clips(of: page(.skill, media: [slow])), [slow])
        XCTAssertEqual(PageCoverOpening.clips(of: page(.tutorial, media: [photo, side])), [side])
    }

    func testAContainersCoverOpensTheContainerInsteadOfItsClips() {
        let folder = page(nil, media: [side, slow])
        XCTAssertTrue(PageCoverOpening.clips(of: folder).isEmpty)
        XCTAssertNil(PageCoverOpening.firstClip(of: folder))
    }

    func testAPageWithoutVideosHasNoClipToShow() {
        let stills = page(.exercise, kind: .leaf, media: [photo, cues])
        XCTAssertTrue(PageCoverOpening.clips(of: stills).isEmpty)
        XCTAssertNil(PageCoverOpening.firstClip(of: stills))
    }
}
