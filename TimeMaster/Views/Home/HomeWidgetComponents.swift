import SwiftUI
#if os(iOS)
import UIKit
#endif

extension HomeWidgetPlatform {
    static var canRecordOutdoor: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

struct HomeWidgetActions {
    var startWorkout: (UUID) -> Void
    var planWorkout: (Date, UUID?) -> Void
    var createWorkout: () -> Void
    var browseWorkouts: () -> Void
    var browseDatabase: () -> Void
    var addSkill: () -> Void
    var removeWidget: () -> Void
}

enum HomeNavigation {
    static func open(_ destination: SlotNavigationDestination) {
        NotificationCenter.default.post(
            name: .openAppPage,
            object: nil,
            userInfo: ["destination": destination.rawValue]
        )
    }

    static func openPage(id: String) {
        NotificationCenter.default.post(name: .openDatabasePage, object: nil, userInfo: ["pageID": id])
    }

    static func openWorkoutDetail(id: UUID) {
        NotificationCenter.default.post(name: .openWorkoutDetail, object: nil, userInfo: ["workoutID": id])
    }
}

extension WidgetArtSpot {
    static func home(_ footprint: HomeWidgetFootprint) -> WidgetArtSpot {
        switch footprint {
        case .compact: .corner
        case .wide: .side
        case .square: .crown
        }
    }

    static func sideRoom(forHeight height: CGFloat) -> CGFloat {
        height * 0.73 + 16
    }
}

extension WidgetArt {
    static func forWorkout(_ option: HomeWorkoutOption) -> WidgetArt {
        forWorkout(type: option.typeName, symbol: option.typeIcon)
    }

    static func forWorkout(_ workout: Workout) -> WidgetArt {
        forWorkout(type: workout.type.name, symbol: workout.type.iconName)
    }
}

struct HomeWidgetChrome<Content: View>: View {
    private let label: String?
    private let tint: WidgetTint
    private let art: WidgetArt?
    private let spot: WidgetArtSpot
    private let content: Content

    init(label: String? = nil, tint: WidgetTint = .graphite, @ViewBuilder content: () -> Content) {
        self.label = label
        self.tint = tint
        art = nil
        spot = .corner
        self.content = content()
    }

    init(label: String? = nil, art: WidgetArt, spot: WidgetArtSpot, @ViewBuilder content: () -> Content) {
        self.label = label
        tint = art.tint
        self.art = art
        self.spot = spot
        self.content = content()
    }

    var body: some View {
        if let art {
            WidgetCard(art: art, spot: spot) { inner }
        } else {
            WidgetCard(tint: tint) { inner }
        }
    }

    private var inner: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label {
                WidgetLabel(text: label)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
    }
}

struct HomeFeatureLayout<Controls: View>: View {
    let footprint: HomeWidgetFootprint
    var label: String?
    let title: String
    var meta: String?
    private let controls: Controls

    init(
        footprint: HomeWidgetFootprint,
        label: String? = nil,
        title: String,
        meta: String? = nil,
        @ViewBuilder controls: () -> Controls
    ) {
        self.footprint = footprint
        self.label = label
        self.title = title
        self.meta = meta
        self.controls = controls()
    }

    var body: some View {
        switch footprint {
        case .compact:
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    WidgetLabel(text: label)
                }
                WidgetTitle(text: title, size: 18, lines: 2)
                Spacer(minLength: 0)
                HStack(spacing: 8) { controls }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .wide:
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 4) {
                    if let label {
                        WidgetLabel(text: label)
                    }
                    WidgetTitle(text: title, size: 24, lines: 2)
                    if let meta {
                        WidgetLabel(text: meta)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) { controls }
                }
                .frame(width: max(0, proxy.size.width - WidgetArtSpot.sideRoom(forHeight: proxy.size.height)), alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        case .square:
            VStack(alignment: .leading, spacing: 6) {
                if let label {
                    WidgetLabel(text: label)
                }
                Spacer(minLength: 0)
                WidgetTitle(text: title, size: 32, lines: 2)
                if let meta {
                    WidgetLabel(text: meta)
                }
                HStack(spacing: 10) { controls }
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct HomePillButton: View {
    let title: String
    let systemImage: String
    var prominent = true
    var fillsWidth = false
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WidgetPillLabel(title: title, systemImage: systemImage, prominent: prominent, fillsWidth: fillsWidth)
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: 22))
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }
}

struct HomeIconButton: View {
    let systemImage: String
    let label: String
    var hint: String?
    var prominent = false
    var diameter: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WidgetPillLabel(title: nil, systemImage: systemImage, prominent: prominent, diameter: diameter)
        }
        .buttonStyle(SkillsPressStyle(cornerRadius: diameter / 2))
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }
}

struct HomeInviteAction {
    var title: String
    var systemImage = "plus"
    var hint: String?
    var run: () -> Void
}

struct HomeInvite: View {
    let footprint: HomeWidgetFootprint
    let headline: String
    var action: HomeInviteAction?

    var body: some View {
        HomeFeatureLayout(footprint: footprint, title: headline) {
            if let action {
                if footprint == .compact {
                    HomeIconButton(systemImage: action.systemImage, label: action.title, hint: action.hint, prominent: true, action: action.run)
                } else {
                    HomePillButton(title: action.title, systemImage: action.systemImage, hint: action.hint, action: action.run)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
