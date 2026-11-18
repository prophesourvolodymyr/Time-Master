import SwiftUI
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

/// A click on a page's cover in a Database list (a gallery tile, a card's or a row's cover): the page's clips in the
/// viewer over the navigation stack (`PageCoverViewer`, grown out of the cover, the first clip playing, "Open Page" to
/// go on). A page without a clip, a container (its cover opens it) and a stack that hosts no viewer open the page
/// instead, on the part that shows its first clip, playing it there (`MediaAutoplayIntent`).
@MainActor
enum PageCoverOpening {
    /// The clips the viewer shows for `page`: its videos, in the page's order. A container's cover opens the container,
    /// so it has none here.
    nonisolated static func clips(of page: ExercisePage) -> [URL] {
        guard page.isContentPage else { return [] }
        return page.mediaURLs.filter(PageMediaKind.isVideo)
    }

    /// The first of `clips(of:)`, nil when there is none.
    nonisolated static func firstClip(of page: ExercisePage) -> URL? {
        guard page.isContentPage else { return nil }
        return page.mediaURLs.first(where: PageMediaKind.isVideo)
    }

    /// What a click on `page`'s cover does: its clips in the stack's viewer, else the page, playing its first clip.
    static func open(_ page: ExercisePage, in navigationState: DatabaseNavigationState) {
        if let viewer = navigationState.coverViewer, viewer.show(page) { return }
        openPage(page, playing: firstClip(of: page), in: navigationState)
    }

    /// Opens `page` on the part that shows `clip`, playing it there; without a clip the page just opens.
    static func openPage(_ page: ExercisePage, playing clip: URL?, in navigationState: DatabaseNavigationState) {
        if let clip { prepare(page, playing: clip) }
        navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
    }

    /// Asks the page about to open to start `clip` (its first clip when nil), on a tab that shows it (the attachments,
    /// or a skill's dependencies when the clip is one of the things to have first; All shows both).
    static func prepare(_ page: ExercisePage, playing clip: URL? = nil) {
        guard let clip = clip ?? firstClip(of: page) else { return }
        MediaAutoplayIntent.request(clip)
        let isNeededFirst = page.isSkillLike && page.manifest.dependencyMediaFilenames.contains(clip.lastPathComponent)
        let tab: PageTab = isNeededFirst ? .dependencies : .attachments
        let remembered = PageTabMemory.tab(for: page.manifest.id)
        if remembered != .all, remembered != tab {
            PageTabMemory.remember(tab, for: page.manifest.id)
        }
    }
}

/// "Play Clip" for VoiceOver on a card whose page has a clip: the cover inside the card's own button cannot be reached
/// on its own, so the card offers what a click on the cover does (the clip viewer).
struct PageClipAccessibilityAction: ViewModifier {
    let page: ExercisePage
    let open: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if PageCoverOpening.firstClip(of: page) != nil {
            content.accessibilityAction(named: "Play Clip", open)
        } else {
            content
        }
    }
}

/// Makes a page card's cover show the page's clips in the viewer (`PageCoverOpening`; a page without a clip opens): a
/// tap or click on it, the pointing hand and a light-up while the pointer is over it on the Mac, a play glyph on a page
/// with a clip, "Open <title>" for VoiceOver, and its place on screen so the viewer grows out of it.
struct PageCoverTap: ViewModifier {
    let page: ExercisePage
    var cornerRadius: CGFloat = 10
    var glyphSize: CGFloat = 22
    let onOpen: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let hasClip = PageCoverOpening.firstClip(of: page) != nil
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .overlay {
                ZStack {
                    shape.fill(Color.black.opacity(isHovering ? 0.18 : 0))
                    if hasClip {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: glyphSize))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3)
                            .scaleEffect(isHovering && !reduceMotion ? 1.1 : 1)
                    }
                    shape.strokeBorder(Theme.toolbarOrange.opacity(isHovering ? 0.85 : 0), lineWidth: 2)
                }
                .allowsHitTesting(false)
            }
            .contentShape(shape)
            .pageCoverFrame(page)
            .onTapGesture(perform: onOpen)
            .pageCoverPointer($isHovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open \(page.title)")
            .accessibilityHint(hasClip ? "Shows its clips in a viewer" : "Opens the page")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpen() }
    }
}

extension View {
    /// The pointing hand over a page cover on the Mac; `isHovering` follows the pointer.
    @ViewBuilder
    func pageCoverPointer(_ isHovering: Binding<Bool> = .constant(false)) -> some View {
        #if os(macOS)
        modifier(PageCoverPointer(isHovering: isHovering))
        #else
        self
        #endif
    }
}

#if os(macOS)
private struct PageCoverPointer: ViewModifier {
    @Binding var isHovering: Bool
    @State private var pushedCursor = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .pointerStyle(.link)
                .onHover { isHovering = $0 }
        } else {
            content
                .onHover { inside in
                    isHovering = inside
                    if inside, !pushedCursor {
                        NSCursor.pointingHand.push()
                        pushedCursor = true
                    } else if !inside, pushedCursor {
                        NSCursor.pop()
                        pushedCursor = false
                    }
                }
                // Opening the page removes the cover while the pointer is still on it, so no exit arrives.
                .onDisappear {
                    if pushedCursor {
                        NSCursor.pop()
                        pushedCursor = false
                    }
                }
        }
    }
}
#endif
