// PageShell.swift
//
// A page drawn before it exists: its background, its title where the real title sits and grey blocks shaped like the
// page's content, under one moving light. A shell costs a few shapes, so the bar can scrub through every page, the
// wheel can preview them and a swipe can drag one in at once, while the real page is built in the shadow behind it.

import SwiftUI

struct PageShell: View {
    let destination: SlotNavigationDestination

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .top) {
                background
                skeleton(width: width)
                    .foregroundStyle(Self.block)
                    .overlay {
                        if !reduceMotion {
                            PageShellShimmer()
                                .mask { skeleton(width: width) }
                        }
                    }
                    .padding(.top, proxy.safeAreaInsets.top > 0 ? 0 : 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(destination.title), loading")
    }

    private static let block = Color.white.opacity(0.075)

    @ViewBuilder
    private var background: some View {
        switch destination {
        case .analytics, .database, .physique, .profile, .ranked, .schedule, .skills, .workouts:
            ZStack {
                Theme.background.ignoresSafeArea()
                TmaxGlowBackground(still: true)
            }
        case .map:
            ZStack {
                Color(hex: "11161C").ignoresSafeArea()
                PageShellMapGrid().ignoresSafeArea()
            }
        default:
            Theme.background.ignoresSafeArea()
        }
    }

    private func skeleton(width: CGFloat) -> some View {
        let content = max(0, width - 40)
        return VStack(alignment: .leading, spacing: 18) {
            if destination != .map, destination != .profile {
                header(content: content)
            }
            body(for: destination, content: content)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .frame(width: width, alignment: .leading)
    }

    private func header(content: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TimeMasterPageTitle(destination == .database ? "Exercise Database" : destination.title, size: 39, relativeTo: .title)
                .foregroundStyle(Theme.textPrimary.opacity(0.92))
                .lineLimit(1)
                .frame(height: 46, alignment: .leading)
            if Self.expandedControlPages.contains(destination) {
                let size = min(108, (content - 20) / 3)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .frame(width: size, height: size)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private static let expandedControlPages: Set<SlotNavigationDestination> = [.home, .workouts, .database, .schedule, .skills]

    @ViewBuilder
    private func body(for destination: SlotNavigationDestination, content: CGFloat) -> some View {
        switch destination {
        case .home:
            VStack(alignment: .leading, spacing: 14) {
                line(width: content * 0.55, height: 18)
                HStack(spacing: 12) {
                    card(height: 150)
                    card(height: 150)
                }
                HStack(spacing: 12) {
                    card(height: 110)
                    card(height: 110)
                }
                card(height: 96)
            }
        case .workouts:
            VStack(alignment: .leading, spacing: 14) {
                chips(count: 4)
                ForEach(0..<5, id: \.self) { _ in row(thumbnail: 64, height: 84) }
            }
        case .database:
            VStack(alignment: .leading, spacing: 12) {
                chips(count: 3)
                ForEach(0..<7, id: \.self) { _ in row(thumbnail: 48, height: 62) }
            }
        case .skills:
            VStack(alignment: .leading, spacing: 14) {
                chips(count: 4)
                line(width: 150, height: 20)
                grid(columns: 2, rows: 2, height: 132, content: content)
                line(width: 120, height: 20)
                grid(columns: 2, rows: 1, height: 132, content: content)
            }
        case .schedule:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle().frame(width: 38, height: 38).frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<4, id: \.self) { _ in card(height: 76) }
            }
        case .analytics:
            VStack(alignment: .leading, spacing: 14) {
                chips(count: 3)
                card(height: 220)
                HStack(spacing: 12) {
                    card(height: 104)
                    card(height: 104)
                }
                card(height: 140)
            }
        case .coach:
            VStack(alignment: .leading, spacing: 16) {
                bubble(width: content * 0.62, height: 64, leading: true)
                bubble(width: content * 0.48, height: 44, leading: false)
                bubble(width: content * 0.74, height: 92, leading: true)
                Spacer(minLength: 40)
                Capsule().frame(height: 50)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        case .profile:
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 28, style: .continuous).frame(height: 168)
                HStack(spacing: 14) {
                    Circle().frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 8) {
                        line(width: 160, height: 22)
                        line(width: 110, height: 14)
                    }
                }
                chips(count: 4)
                ForEach(0..<3, id: \.self) { _ in card(height: 84) }
            }
        case .ranked, .physique:
            VStack(alignment: .leading, spacing: 14) {
                card(height: 210)
                HStack(spacing: 12) {
                    card(height: 92)
                    card(height: 92)
                }
                ForEach(0..<3, id: \.self) { _ in row(thumbnail: 52, height: 68) }
            }
        case .settings:
            VStack(alignment: .leading, spacing: 18) {
                ForEach(0..<3, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        line(width: 110, height: 14)
                        card(height: section == 0 ? 152 : 104)
                    }
                }
            }
        case .map:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .frame(height: 210)
                    .padding(.bottom, 24)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .frame(width: max(0, width), height: height)
    }

    private func card(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }

    private func chips(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule().frame(width: index == 0 ? 64 : 84, height: 34)
            }
        }
    }

    private func row(thumbnail: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .frame(width: thumbnail, height: thumbnail)
            VStack(alignment: .leading, spacing: 8) {
                line(width: 170, height: 15)
                line(width: 100, height: 11)
            }
            Spacer(minLength: 0)
        }
        .frame(height: height)
    }

    private func grid(columns: Int, rows: Int, height: CGFloat, content: CGFloat) -> some View {
        let spacing: CGFloat = 12
        let side = (content - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .frame(width: max(0, side), height: height)
                    }
                }
            }
        }
    }

    private func bubble(width: CGFloat, height: CGFloat, leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }
}

/// A soft band of light sweeping across the shell's blocks.
private struct PageShellShimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.09), location: 0.5),
                    .init(color: .white.opacity(0), location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: width * 0.7)
            .offset(x: phase * width * 1.35)
            .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { phase = 1.1 }
        }
    }
}

private struct PageShellMapGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 46
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height * 0.18, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y - size.width * 0.12))
                y += step
            }
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
        }
    }
}
