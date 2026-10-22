import SwiftUI

struct PhysiqueResultCelebration: View {
    let outcome: String
    let isJudged: Bool
    var corrected = false
    var revealID: String? = nil
    var animate = false
    var newBadges: [PhysiqueBadge] = []
    @Environment(\.colorSchemeContrast) private var contrast

    private var judgedWin: Bool { outcome == "win" && isJudged && !corrected }
    private var freshJudgedWin: Bool { judgedWin && revealID != nil }
    private var ivory: Color { Color(red: 0.97, green: 0.94, blue: 0.87) }

    private var title: String {
        switch outcome {
        case "win": return "WON"
        case "loss": return "LOST"
        case "draw": return "DRAW"
        case "forfeitWin": return "WON BY\nFORFEIT"
        case "forfeitLoss": return "FORFEITED"
        case "noContest": return "NO\nCONTEST"
        default: return "RESULT\nUNAVAILABLE"
        }
    }

    private var spokenTitle: String {
        switch outcome {
        case "win": return "Won"
        case "loss": return "Lost"
        case "draw": return "Draw"
        case "forfeitWin": return "Won by forfeit"
        case "forfeitLoss": return "Forfeited"
        case "noContest": return "No contest"
        default: return "Result unavailable"
        }
    }

    var body: some View {
        PhysiqueNumericReveal(
            revealID: revealID,
            animate: animate && freshJudgedWin,
            contentID: "\(outcome):\(isJudged):\(corrected)",
            includesRail: true,
            isCelebration: true
        ) { crestProgress, burstProgress in
            VStack(alignment: .leading, spacing: ProfileStyle.inset * 1.25) {
                HStack(alignment: .center, spacing: 10) {
                    Rectangle()
                        .fill(judgedWin ? Theme.toolbarOrange : ivory)
                        .frame(width: 28, height: 3)
                    Text(corrected ? "CORRECTED RESULT" : "FINAL VERDICT")
                        .font(TimeMasterFont.technical())
                        .tracking(1.8)
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: ProfileStyle.inset) {
                        verdictWordmark
                        crest(progress: crestProgress)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: ProfileStyle.spacing) {
                        crest(progress: crestProgress)
                        verdictWordmark
                    }
                }
                if freshJudgedWin {
                    Text("Congratulations.\nYou won this duel.")
                        .font(TimeMasterFont.heading())
                        .foregroundStyle(ivory)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isJudged {
                    Text("Selected pose set · Judged result")
                        .font(TimeMasterFont.secondary())
                        .foregroundStyle(ProfileStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if freshJudgedWin, !newBadges.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NEWLY EARNED")
                            .font(TimeMasterFont.technical())
                            .tracking(1)
                            .foregroundStyle(Theme.toolbarOrange)
                        Text(newBadges.map(\.title).joined(separator: " · "))
                            .font(TimeMasterFont.label())
                            .foregroundStyle(ivory)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, ProfileStyle.spacing)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Theme.toolbarOrange).frame(width: 2)
                    }
                    .offset(y: 7 * (1 - burstProgress))
                    .opacity(0.86 + 0.14 * burstProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ProfileStyle.inset * 1.5)
            .background(alignment: .topTrailing) {
                ZStack(alignment: .topTrailing) {
                    Theme.surface
                    if animate && freshJudgedWin {
                        PhysiqueVerdictBurst(progress: burstProgress)
                            .frame(width: 250, height: 250)
                            .offset(x: 35, y: -15)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                PhysiqueVerdictCourt()
                    .stroke(ivory.opacity(contrast == .increased ? 0.22 : 0.08), lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                Rectangle()
                    .fill(judgedWin ? Theme.toolbarOrange : ivory.opacity(0.6))
                    .frame(width: 72, height: 4)
                    .accessibilityHidden(true)
            }
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(corrected ? "Corrected result. " : "")\(spokenTitle)\(freshJudgedWin ? ". Congratulations, you won this duel." : "")"))
        .accessibilityValue(Text(verbatim: freshJudgedWin && !newBadges.isEmpty ? "Newly earned in this match: \(newBadges.map(\.title).joined(separator: ", "))" : ""))
        .accessibilityAddTraits(.isHeader)
    }

    private var verdictWordmark: some View {
        Text(verbatim: title)
            .font(TimeMasterFont.black(title.count > 6 ? 46 : 78, relativeTo: .largeTitle))
            .tracking(-2)
            .lineSpacing(-4)
            .foregroundStyle(ivory)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func crest(progress: CGFloat) -> some View {
        PhysiqueVerdictCrest(victory: judgedWin, draw: outcome == "draw")
            .scaleEffect(0.86 + 0.14 * progress)
            .offset(y: 10 * (1 - progress))
            .opacity(0.82 + 0.18 * progress)
            .accessibilityHidden(true)
    }
}

private struct PhysiqueVerdictCrest: View {
    let victory: Bool
    let draw: Bool
    private let ivory = Color(red: 0.97, green: 0.94, blue: 0.87)

    var body: some View {
        ZStack {
            PhysiqueVerdictWings()
                .fill(victory ? Theme.toolbarOrange : ivory.opacity(0.35))
            PhysiqueVerdictShield()
                .fill(Theme.background)
                .overlay {
                    PhysiqueVerdictShield()
                        .stroke(victory ? Theme.toolbarOrange : ivory.opacity(0.6), lineWidth: 2)
                }
                .padding(.horizontal, 27)
                .padding(.vertical, 5)
            PhysiqueVerdictShield()
                .stroke(ivory.opacity(0.22), lineWidth: 1)
                .padding(.horizontal, 35)
                .padding(.vertical, 16)
            PhysiqueVerdictGlyph(victory: victory, draw: draw)
                .fill(ivory)
                .frame(width: 58, height: 68)
                .offset(y: 3)
            if victory {
                Rectangle()
                    .fill(Theme.toolbarOrange)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(45))
                    .offset(y: -48)
            }
        }
        .frame(width: 136, height: 150)
        .allowsHitTesting(false)
    }
}

private struct PhysiqueVerdictShield: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.13))
            path.addLine(to: CGPoint(x: rect.width * 0.87, y: rect.height * 0.68))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width * 0.13, y: rect.height * 0.68))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.13))
            path.closeSubpath()
        }
    }
}

private struct PhysiqueVerdictWings: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<4 {
                let row = CGFloat(index)
                let x = rect.width * (0.02 + row * 0.025)
                let y = rect.height * (0.24 + row * 0.105)
                let inner = rect.width * (0.30 + row * 0.025)
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: inner, y: y + rect.height * 0.10))
                path.addLine(to: CGPoint(x: inner, y: y + rect.height * 0.16))
                path.addLine(to: CGPoint(x: x + rect.width * 0.025, y: y + rect.height * 0.065))
                path.closeSubpath()
                path.move(to: CGPoint(x: rect.width - x, y: y))
                path.addLine(to: CGPoint(x: rect.width - inner, y: y + rect.height * 0.10))
                path.addLine(to: CGPoint(x: rect.width - inner, y: y + rect.height * 0.16))
                path.addLine(to: CGPoint(x: rect.width - x - rect.width * 0.025, y: y + rect.height * 0.065))
                path.closeSubpath()
            }
        }
    }
}

private struct PhysiqueVerdictGlyph: Shape {
    let victory: Bool
    let draw: Bool

    func path(in rect: CGRect) -> Path {
        Path { path in
            if victory {
                path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.15))
                path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.15))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.59))
                path.addLine(to: CGPoint(x: rect.width * 0.66, y: rect.height * 0.15))
                path.addLine(to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.15))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.94))
                path.closeSubpath()
            } else if draw {
                path.addRect(CGRect(x: rect.width * 0.14, y: rect.height * 0.30, width: rect.width * 0.72, height: rect.height * 0.13))
                path.addRect(CGRect(x: rect.width * 0.14, y: rect.height * 0.57, width: rect.width * 0.72, height: rect.height * 0.13))
            } else {
                path.move(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.22))
                path.addLine(to: CGPoint(x: rect.width * 0.51, y: rect.height * 0.22))
                path.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.78))
                path.addLine(to: CGPoint(x: rect.width * 0.49, y: rect.height * 0.78))
                path.closeSubpath()
            }
        }
    }
}

private struct PhysiqueVerdictCourt: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.8, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height))
            path.move(to: CGPoint(x: rect.width * 0.96, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.height))
            path.move(to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.78))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.78))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.86))
            path.addLine(to: CGPoint(x: rect.width * 0.53, y: rect.height * 0.86))
        }
    }
}

private struct PhysiqueVerdictBurst: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                let angle = Double(index) * .pi / 8 - .pi / 2
                let distance = CGFloat(70 + (index % 4) * 12)
                Rectangle()
                    .fill(index.isMultiple(of: 3) ? Color(red: 0.97, green: 0.94, blue: 0.87) : Theme.toolbarOrange)
                    .frame(width: index.isMultiple(of: 2) ? 4 : 7, height: index.isMultiple(of: 3) ? 14 : 8)
                    .rotationEffect(.radians(angle + Double(progress) * 1.2))
                    .offset(x: CGFloat(cos(angle)) * distance * progress, y: CGFloat(sin(angle)) * distance * progress)
                    .scaleEffect(0.7 + 0.3 * progress)
                    .opacity(Double(1 - progress))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
