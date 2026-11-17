import SwiftUI
import TimeMasterCore
#if os(macOS)
import AppKit
#endif

/// Opening a page from its cover in a Database list: the page opens on the part that shows its first clip and plays it
/// there (`MediaAutoplayIntent`); a page without a clip just opens.
@MainActor
enum PageCoverOpening {
    /// The page's first video, nil when it has none.
    nonisolated static func firstClip(of page: ExercisePage) -> URL? {
        page.mediaURLs.first(where: PageMediaKind.isVideo)
    }

    /// Opens `page`, playing its first clip.
    static func open(_ page: ExercisePage, in navigationState: DatabaseNavigationState) {
        prepare(page)
        navigationState.path.append(DatabasePageRoute(pageID: page.manifest.id))
    }

    /// Asks the page about to open to start its first clip, on a tab that shows it (the attachments, or a skill's
    /// dependencies when the clip is one of the things to have first; All shows both).
    static func prepare(_ page: ExercisePage) {
        guard let clip = firstClip(of: page) else { return }
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
/// on its own, so the card offers what a tap on the cover does.
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

/// Makes a page card's cover open the page and play its first clip: a tap or click on it, the pointing hand and a
/// light-up while the pointer is over it on the Mac, a play glyph on a page with a clip, and "Open <title>" for
/// VoiceOver.
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
            .onTapGesture(perform: onOpen)
            .pageCoverPointer($isHovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Open \(page.title)")
            .accessibilityHint(hasClip ? "Opens the page and plays its first clip" : "Opens the page")
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
