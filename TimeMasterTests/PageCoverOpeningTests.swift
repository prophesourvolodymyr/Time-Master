import XCTest
import TimeMasterCore
@testable import TimeMaster

/// What a click on a page's cover in a Database list shows: the clips the viewer gets, and where it grows from.
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

    func testTheViewerGrowsOutOfACoverInTheStacksCoordinates() {
        let frames = PageCoverFrames()
        let stack = CGRect(x: 100, y: 50, width: 800, height: 600)
        frames.set(CGRect(x: 140, y: 250, width: 200, height: 250), for: "squat")
        XCTAssertEqual(frames.rect(for: "squat", in: stack), CGRect(x: 40, y: 200, width: 200, height: 250))
        XCTAssertNil(frames.rect(for: "lunge", in: stack), "a page whose cover never showed")
        frames.set(CGRect(x: 100, y: 900, width: 200, height: 250), for: "lunge")
        XCTAssertNil(frames.rect(for: "lunge", in: stack), "a cover scrolled out of the stack")
        XCTAssertNil(frames.rect(for: "squat", in: .zero), "a stack not laid out yet")
    }

    func testACoverForgetsItsPlaceOnlyWhenNoOtherCardOfThePageReportedSince() {
        let frames = PageCoverFrames()
        let stack = CGRect(x: 0, y: 0, width: 800, height: 600)
        let row = CGRect(x: 10, y: 10, width: 56, height: 56)
        let tile = CGRect(x: 300, y: 100, width: 200, height: 250)
        frames.set(row, for: "squat")
        frames.set(tile, for: "squat")
        frames.remove("squat", at: row)
        XCTAssertEqual(frames.rect(for: "squat", in: stack), tile)
        frames.remove("squat", at: tile)
        XCTAssertNil(frames.rect(for: "squat", in: stack))
    }
}
