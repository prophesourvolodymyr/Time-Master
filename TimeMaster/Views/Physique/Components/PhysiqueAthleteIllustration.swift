import SwiftUI

struct PhysiqueAthleteIllustration: View {
    var pose: PhysiquePose = .front
    var isOpponent = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
            let compact = size.height < 160 || size.width < 100

            if !compact, size.width > size.height {
                let reflection = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: size.width, ty: 0)
                var bank = Path()
                bank.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.8))
                bank.addLine(to: CGPoint(x: size.width * 0.2, y: size.height * 0.16))
                bank.addLine(to: CGPoint(x: size.width * 0.29, y: size.height * 0.16))
                bank.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.8))
                bank.closeSubpath()
                bank.addPath(bank.applying(reflection))
                context.fill(bank, with: .color(Color.white.opacity(contrast == .increased ? 0.1 : 0.035)))

                let court = Path(ellipseIn: CGRect(
                    x: size.width * 0.08, y: size.height * 0.78,
                    width: size.width * 0.84, height: size.height * 0.19
                ))
                context.stroke(court, with: .color(Color.white.opacity(contrast == .increased ? 0.35 : 0.12)), lineWidth: 1)

                var lines = Path()
                lines.move(to: CGPoint(x: size.width * 0.1, y: size.height * 0.9))
                lines.addLine(to: CGPoint(x: size.width * 0.9, y: size.height * 0.9))
                lines.move(to: CGPoint(x: size.width * 0.17, y: size.height * 0.2))
                lines.addLine(to: CGPoint(x: size.width * 0.13, y: size.height * 0.37))
                lines.move(to: CGPoint(x: size.width * 0.83, y: size.height * 0.2))
                lines.addLine(to: CGPoint(x: size.width * 0.87, y: size.height * 0.37))
                context.stroke(lines, with: .color(Theme.toolbarOrange.opacity(contrast == .increased ? 0.7 : 0.38)), lineWidth: 1.5)
            }

            let scale = min(size.width / 300, size.height / 430)
            context.translateBy(x: (size.width - 300 * scale) / 2, y: (size.height - 430 * scale) / 2)
            context.scaleBy(x: scale, y: scale)

            let figure: Figure
            switch pose {
            case .front: figure = Artwork.front
            case .side: figure = Artwork.side
            case .rear: figure = Artwork.rear
            }
            let ivory = Color(red: 0.91, green: 0.89, blue: 0.83)
            let outline = Color(red: 0.12, green: 0.13, blue: 0.12)
            let stroke = StrokeStyle(lineWidth: contrast == .increased ? 2.2 : 1.4, lineCap: .round, lineJoin: .round)

            if !compact {
                context.fill(Artwork.ground, with: .color(Color.black.opacity(0.7)))
                context.stroke(Artwork.baseline, with: .color(Theme.toolbarOrange.opacity(0.65)), lineWidth: 1.5)
            }
            context.fill(figure.skin, with: .color(ivory))
            context.stroke(figure.skin, with: .color(outline), style: stroke)
            if !compact {
                context.fill(figure.shade, with: .color(Color(red: 0.65, green: 0.66, blue: 0.62)))
                context.fill(figure.light, with: .color(Color(red: 0.98, green: 0.96, blue: 0.9)))
            }
            context.fill(figure.footwear, with: .color(ivory))
            context.stroke(figure.footwear, with: .color(outline), style: stroke)
            context.fill(figure.soles, with: .color(Color(red: 0.36, green: 0.38, blue: 0.35)))
            context.fill(figure.top, with: .color(Color(red: 0.84, green: 0.84, blue: 0.78)))
            context.stroke(figure.top, with: .color(outline), style: stroke)
            context.fill(figure.panels, with: .color(Color(red: 0.22, green: 0.24, blue: 0.22)))
            context.fill(figure.shorts, with: .color(Color(red: 0.25, green: 0.27, blue: 0.25)))
            context.stroke(figure.shorts, with: .color(ivory.opacity(contrast == .increased ? 0.8 : 0.4)), style: stroke)
            if !compact {
                context.fill(figure.shortPanels, with: .color(Color(red: 0.16, green: 0.18, blue: 0.17)))
                context.stroke(figure.seams, with: .color(Color(red: 0.53, green: 0.55, blue: 0.5)), style: stroke)
            }
            context.fill(figure.foregroundSkin, with: .color(ivory))
            context.stroke(figure.foregroundSkin, with: .color(outline), style: stroke)
            if !compact {
                context.fill(figure.foregroundShade, with: .color(Color(red: 0.65, green: 0.66, blue: 0.62)))
            }
            context.stroke(figure.accents, with: .color(Theme.toolbarOrange), style: StrokeStyle(lineWidth: compact ? 4 : 3, lineCap: .square, lineJoin: .miter))
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(isOpponent ? "Neutral opponent illustration, not live video" : "\(pose.title) pose illustration")
        .accessibilityValue(isOpponent ? "Not a participant photo or physique evidence" : "Full-body posture reference wearing an athletic top and shorts")
    }

    private struct Figure {
        let skin: Path
        let shade: Path
        let light: Path
        let top: Path
        let panels: Path
        let shorts: Path
        let shortPanels: Path
        let footwear: Path
        let soles: Path
        let foregroundSkin: Path
        let foregroundShade: Path
        let seams: Path
        let accents: Path
    }

    private enum Artwork {
        static let reflection = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 300, ty: 0)

        static func paired(_ path: Path) -> Path {
            var pair = path
            pair.addPath(path.applying(reflection))
            return pair
        }

        static let ground = Path(ellipseIn: CGRect(x: 87, y: 407, width: 126, height: 12))

        static let baseline = Path { path in
            path.move(to: CGPoint(x: 57, y: 418))
            path.addLine(to: CGPoint(x: 243, y: 418))
        }

        static let head = Path { path in
            path.move(to: CGPoint(x: 132, y: 34))
            path.addCurve(to: CGPoint(x: 151, y: 21), control1: CGPoint(x: 134, y: 24), control2: CGPoint(x: 142, y: 20))
            path.addCurve(to: CGPoint(x: 169, y: 36), control1: CGPoint(x: 162, y: 21), control2: CGPoint(x: 168, y: 26))
            path.addLine(to: CGPoint(x: 168, y: 54))
            path.addCurve(to: CGPoint(x: 159, y: 70), control1: CGPoint(x: 167, y: 62), control2: CGPoint(x: 164, y: 68))
            path.addLine(to: CGPoint(x: 141, y: 70))
            path.addCurve(to: CGPoint(x: 132, y: 54), control1: CGPoint(x: 136, y: 68), control2: CGPoint(x: 133, y: 62))
            path.closeSubpath()
            path.move(to: CGPoint(x: 140, y: 65))
            path.addLine(to: CGPoint(x: 160, y: 65))
            path.addLine(to: CGPoint(x: 164, y: 89))
            path.addQuadCurve(to: CGPoint(x: 136, y: 89), control: CGPoint(x: 150, y: 99))
            path.closeSubpath()
        }

        static let arm = Path { path in
            path.move(to: CGPoint(x: 116, y: 93))
            path.addCurve(to: CGPoint(x: 88, y: 88), control1: CGPoint(x: 106, y: 86), control2: CGPoint(x: 98, y: 86))
            path.addLine(to: CGPoint(x: 65, y: 98))
            path.addQuadCurve(to: CGPoint(x: 65, y: 78), control: CGPoint(x: 61, y: 91))
            path.addLine(to: CGPoint(x: 73, y: 59))
            path.addLine(to: CGPoint(x: 72, y: 51))
            path.addQuadCurve(to: CGPoint(x: 62, y: 44), control: CGPoint(x: 69, y: 43))
            path.addQuadCurve(to: CGPoint(x: 54, y: 50), control: CGPoint(x: 55, y: 43))
            path.addLine(to: CGPoint(x: 52, y: 65))
            path.addCurve(to: CGPoint(x: 42, y: 103), control1: CGPoint(x: 46, y: 78), control2: CGPoint(x: 42, y: 94))
            path.addQuadCurve(to: CGPoint(x: 48, y: 117), control: CGPoint(x: 40, y: 112))
            path.addQuadCurve(to: CGPoint(x: 68, y: 123), control: CGPoint(x: 56, y: 124))
            path.addCurve(to: CGPoint(x: 109, y: 111), control1: CGPoint(x: 82, y: 122), control2: CGPoint(x: 97, y: 116))
            path.closeSubpath()
        }

        static let leg = Path { path in
            path.move(to: CGPoint(x: 125, y: 244))
            path.addCurve(to: CGPoint(x: 113, y: 295), control1: CGPoint(x: 119, y: 261), control2: CGPoint(x: 112, y: 281))
            path.addLine(to: CGPoint(x: 112, y: 322))
            path.addCurve(to: CGPoint(x: 104, y: 369), control1: CGPoint(x: 106, y: 336), control2: CGPoint(x: 106, y: 354))
            path.addLine(to: CGPoint(x: 101, y: 394))
            path.addLine(to: CGPoint(x: 116, y: 397))
            path.addLine(to: CGPoint(x: 122, y: 374))
            path.addQuadCurve(to: CGPoint(x: 132, y: 326), control: CGPoint(x: 131, y: 347))
            path.addCurve(to: CGPoint(x: 145, y: 258), control1: CGPoint(x: 136, y: 302), control2: CGPoint(x: 143, y: 276))
            path.closeSubpath()
        }

        static let raisedSkin: Path = {
            var path = head
            path.addPath(paired(arm))
            path.addPath(paired(leg))
            return path
        }()

        static let raisedShade: Path = {
            var path = Path { path in
                path.move(to: CGPoint(x: 159, y: 25))
                path.addQuadCurve(to: CGPoint(x: 169, y: 40), control: CGPoint(x: 169, y: 27))
                path.addLine(to: CGPoint(x: 168, y: 55))
                path.addQuadCurve(to: CGPoint(x: 159, y: 70), control: CGPoint(x: 166, y: 66))
                path.addLine(to: CGPoint(x: 160, y: 82))
                path.addLine(to: CGPoint(x: 144, y: 86))
                path.addLine(to: CGPoint(x: 143, y: 73))
                path.addQuadCurve(to: CGPoint(x: 158, y: 59), control: CGPoint(x: 157, y: 70))
                path.closeSubpath()
            }
            let limbs = Path { path in
                path.move(to: CGPoint(x: 45, y: 100))
                path.addQuadCurve(to: CGPoint(x: 61, y: 114), control: CGPoint(x: 46, y: 115))
                path.addLine(to: CGPoint(x: 106, y: 100))
                path.addLine(to: CGPoint(x: 109, y: 111))
                path.addQuadCurve(to: CGPoint(x: 66, y: 122), control: CGPoint(x: 82, y: 124))
                path.addQuadCurve(to: CGPoint(x: 45, y: 116), control: CGPoint(x: 50, y: 124))
                path.closeSubpath()
                path.move(to: CGPoint(x: 133, y: 259))
                path.addLine(to: CGPoint(x: 144, y: 257))
                path.addQuadCurve(to: CGPoint(x: 131, y: 326), control: CGPoint(x: 139, y: 294))
                path.addQuadCurve(to: CGPoint(x: 121, y: 375), control: CGPoint(x: 130, y: 351))
                path.addLine(to: CGPoint(x: 116, y: 395))
                path.addLine(to: CGPoint(x: 109, y: 394))
                path.addLine(to: CGPoint(x: 115, y: 369))
                path.addLine(to: CGPoint(x: 122, y: 326))
                path.addLine(to: CGPoint(x: 123, y: 297))
                path.closeSubpath()
            }
            path.addPath(paired(limbs))
            return path
        }()

        static let raisedLight: Path = {
            var path = Path { path in
                path.move(to: CGPoint(x: 138, y: 33))
                path.addQuadCurve(to: CGPoint(x: 150, y: 25), control: CGPoint(x: 143, y: 24))
                path.addLine(to: CGPoint(x: 146, y: 57))
                path.addQuadCurve(to: CGPoint(x: 137, y: 48), control: CGPoint(x: 138, y: 58))
                path.closeSubpath()
            }
            let limbs = Path { path in
                path.move(to: CGPoint(x: 58, y: 58))
                path.addLine(to: CGPoint(x: 65, y: 55))
                path.addLine(to: CGPoint(x: 57, y: 84))
                path.addLine(to: CGPoint(x: 51, y: 101))
                path.addLine(to: CGPoint(x: 49, y: 95))
                path.closeSubpath()
                path.move(to: CGPoint(x: 75, y: 100))
                path.addQuadCurve(to: CGPoint(x: 102, y: 93), control: CGPoint(x: 92, y: 89))
                path.addLine(to: CGPoint(x: 106, y: 99))
                path.addLine(to: CGPoint(x: 75, y: 109))
                path.closeSubpath()
                path.move(to: CGPoint(x: 120, y: 267))
                path.addLine(to: CGPoint(x: 128, y: 267))
                path.addLine(to: CGPoint(x: 119, y: 305))
                path.addLine(to: CGPoint(x: 116, y: 316))
                path.closeSubpath()
                path.move(to: CGPoint(x: 113, y: 336))
                path.addLine(to: CGPoint(x: 118, y: 329))
                path.addLine(to: CGPoint(x: 112, y: 375))
                path.addLine(to: CGPoint(x: 108, y: 384))
                path.closeSubpath()
            }
            path.addPath(paired(limbs))
            return path
        }()

        static func raisedTop(rear: Bool) -> Path {
            Path { path in
                path.move(to: CGPoint(x: 136, y: 83))
                path.addQuadCurve(to: CGPoint(x: 164, y: 83), control: CGPoint(x: 150, y: rear ? 88 : 105))
                path.addLine(to: CGPoint(x: 188, y: 89))
                path.addLine(to: CGPoint(x: 203, y: 109))
                path.addLine(to: CGPoint(x: 187, y: 123))
                path.addLine(to: CGPoint(x: 179, y: 116))
                path.addLine(to: CGPoint(x: 176, y: 166))
                path.addLine(to: CGPoint(x: 176, y: 209))
                path.addQuadCurve(to: CGPoint(x: 124, y: 209), control: CGPoint(x: 150, y: 218))
                path.addLine(to: CGPoint(x: 124, y: 166))
                path.addLine(to: CGPoint(x: 121, y: 116))
                path.addLine(to: CGPoint(x: 113, y: 123))
                path.addLine(to: CGPoint(x: 97, y: 109))
                path.addLine(to: CGPoint(x: 112, y: 89))
                path.closeSubpath()
            }
        }

        static let frontPanels: Path = {
            let side = Path { path in
                path.move(to: CGPoint(x: 115, y: 92))
                path.addLine(to: CGPoint(x: 126, y: 112))
                path.addLine(to: CGPoint(x: 133, y: 207))
                path.addLine(to: CGPoint(x: 125, y: 209))
                path.addLine(to: CGPoint(x: 124, y: 166))
                path.addLine(to: CGPoint(x: 121, y: 116))
                path.addLine(to: CGPoint(x: 113, y: 123))
                path.addLine(to: CGPoint(x: 104, y: 115))
                path.closeSubpath()
            }
            return paired(side)
        }()

        static let rearPanels: Path = {
            var path = Path { path in
                path.move(to: CGPoint(x: 112, y: 89))
                path.addLine(to: CGPoint(x: 136, y: 83))
                path.addQuadCurve(to: CGPoint(x: 164, y: 83), control: CGPoint(x: 150, y: 88))
                path.addLine(to: CGPoint(x: 188, y: 89))
                path.addLine(to: CGPoint(x: 198, y: 103))
                path.addLine(to: CGPoint(x: 177, y: 110))
                path.addQuadCurve(to: CGPoint(x: 123, y: 110), control: CGPoint(x: 150, y: 120))
                path.addLine(to: CGPoint(x: 102, y: 103))
                path.closeSubpath()
            }
            let side = Path { path in
                path.move(to: CGPoint(x: 121, y: 116))
                path.addLine(to: CGPoint(x: 129, y: 124))
                path.addLine(to: CGPoint(x: 132, y: 207))
                path.addLine(to: CGPoint(x: 125, y: 209))
                path.addLine(to: CGPoint(x: 124, y: 166))
                path.closeSubpath()
            }
            path.addPath(paired(side))
            return path
        }()

        static let raisedShorts = Path { path in
            path.move(to: CGPoint(x: 125, y: 209))
            path.addQuadCurve(to: CGPoint(x: 175, y: 209), control: CGPoint(x: 150, y: 216))
            path.addLine(to: CGPoint(x: 187, y: 260))
            path.addLine(to: CGPoint(x: 165, y: 266))
            path.addLine(to: CGPoint(x: 150, y: 245))
            path.addLine(to: CGPoint(x: 135, y: 266))
            path.addLine(to: CGPoint(x: 113, y: 260))
            path.closeSubpath()
        }

        static let raisedShortPanels: Path = {
            let panel = Path { path in
                path.move(to: CGPoint(x: 125, y: 216))
                path.addLine(to: CGPoint(x: 136, y: 219))
                path.addLine(to: CGPoint(x: 128, y: 263))
                path.addLine(to: CGPoint(x: 114, y: 260))
                path.closeSubpath()
            }
            return paired(panel)
        }()

        static let raisedShoes: Path = {
            let shoe = Path { path in
                path.move(to: CGPoint(x: 101, y: 388))
                path.addLine(to: CGPoint(x: 117, y: 392))
                path.addLine(to: CGPoint(x: 119, y: 405))
                path.addQuadCurve(to: CGPoint(x: 112, y: 414), control: CGPoint(x: 121, y: 414))
                path.addLine(to: CGPoint(x: 82, y: 414))
                path.addQuadCurve(to: CGPoint(x: 80, y: 406), control: CGPoint(x: 77, y: 413))
                path.addLine(to: CGPoint(x: 95, y: 399))
                path.closeSubpath()
            }
            return paired(shoe)
        }()

        static let raisedSoles: Path = {
            let sole = Path { path in
                path.move(to: CGPoint(x: 80, y: 409))
                path.addLine(to: CGPoint(x: 118, y: 409))
                path.addQuadCurve(to: CGPoint(x: 112, y: 415), control: CGPoint(x: 119, y: 414))
                path.addLine(to: CGPoint(x: 82, y: 415))
                path.closeSubpath()
            }
            return paired(sole)
        }()

        static func raisedSeams(rear: Bool) -> Path {
            var path = Path()
            if rear {
                path.move(to: CGPoint(x: 150, y: 116))
                path.addLine(to: CGPoint(x: 150, y: 201))
                path.move(to: CGPoint(x: 134, y: 124))
                path.addLine(to: CGPoint(x: 141, y: 145))
                path.move(to: CGPoint(x: 166, y: 124))
                path.addLine(to: CGPoint(x: 159, y: 145))
            } else {
                path.move(to: CGPoint(x: 137, y: 89))
                path.addQuadCurve(to: CGPoint(x: 163, y: 89), control: CGPoint(x: 150, y: 107))
                path.move(to: CGPoint(x: 132, y: 165))
                path.addLine(to: CGPoint(x: 137, y: 190))
                path.move(to: CGPoint(x: 168, y: 165))
                path.addLine(to: CGPoint(x: 163, y: 190))
            }
            path.move(to: CGPoint(x: 128, y: 203))
            path.addQuadCurve(to: CGPoint(x: 172, y: 203), control: CGPoint(x: 150, y: 209))
            path.move(to: CGPoint(x: 120, y: 256))
            path.addLine(to: CGPoint(x: 132, y: 259))
            path.move(to: CGPoint(x: 168, y: 259))
            path.addLine(to: CGPoint(x: 180, y: 256))
            path.move(to: CGPoint(x: 100, y: 401))
            path.addLine(to: CGPoint(x: 111, y: 403))
            path.move(to: CGPoint(x: 189, y: 403))
            path.addLine(to: CGPoint(x: 200, y: 401))
            return path
        }

        static func raisedAccents(rear: Bool) -> Path {
            Path { path in
                if rear {
                    path.move(to: CGPoint(x: 139, y: 98))
                    path.addLine(to: CGPoint(x: 161, y: 98))
                } else {
                    path.move(to: CGPoint(x: 132, y: 119))
                    path.addLine(to: CGPoint(x: 150, y: 127))
                    path.addLine(to: CGPoint(x: 168, y: 119))
                }
                path.move(to: CGPoint(x: 126, y: 216))
                path.addQuadCurve(to: CGPoint(x: 174, y: 216), control: CGPoint(x: 150, y: 222))
                path.move(to: CGPoint(x: 121, y: 234))
                path.addLine(to: CGPoint(x: 117, y: 250))
                path.move(to: CGPoint(x: 179, y: 234))
                path.addLine(to: CGPoint(x: 183, y: 250))
            }
        }

        static let sideSkin = Path { path in
            path.move(to: CGPoint(x: 147, y: 31))
            path.addCurve(to: CGPoint(x: 171, y: 24), control1: CGPoint(x: 152, y: 20), control2: CGPoint(x: 165, y: 20))
            path.addQuadCurve(to: CGPoint(x: 180, y: 43), control: CGPoint(x: 181, y: 29))
            path.addLine(to: CGPoint(x: 182, y: 55))
            path.addQuadCurve(to: CGPoint(x: 174, y: 70), control: CGPoint(x: 183, y: 67))
            path.addLine(to: CGPoint(x: 173, y: 86))
            path.addLine(to: CGPoint(x: 150, y: 90))
            path.addLine(to: CGPoint(x: 152, y: 68))
            path.addQuadCurve(to: CGPoint(x: 145, y: 52), control: CGPoint(x: 145, y: 62))
            path.closeSubpath()
            path.move(to: CGPoint(x: 142, y: 101))
            path.addQuadCurve(to: CGPoint(x: 132, y: 129), control: CGPoint(x: 132, y: 108))
            path.addLine(to: CGPoint(x: 136, y: 151))
            path.addLine(to: CGPoint(x: 149, y: 172))
            path.addLine(to: CGPoint(x: 158, y: 166))
            path.addLine(to: CGPoint(x: 148, y: 146))
            path.addLine(to: CGPoint(x: 147, y: 125))
            path.addLine(to: CGPoint(x: 156, y: 111))
            path.closeSubpath()
            path.move(to: CGPoint(x: 141, y: 246))
            path.addLine(to: CGPoint(x: 132, y: 292))
            path.addLine(to: CGPoint(x: 119, y: 324))
            path.addLine(to: CGPoint(x: 108, y: 389))
            path.addLine(to: CGPoint(x: 121, y: 394))
            path.addLine(to: CGPoint(x: 139, y: 343))
            path.addLine(to: CGPoint(x: 150, y: 317))
            path.addQuadCurve(to: CGPoint(x: 161, y: 257), control: CGPoint(x: 157, y: 281))
            path.closeSubpath()
            path.move(to: CGPoint(x: 165, y: 248))
            path.addQuadCurve(to: CGPoint(x: 162, y: 321), control: CGPoint(x: 159, y: 294))
            path.addQuadCurve(to: CGPoint(x: 168, y: 365), control: CGPoint(x: 160, y: 343))
            path.addLine(to: CGPoint(x: 169, y: 394))
            path.addLine(to: CGPoint(x: 184, y: 394))
            path.addLine(to: CGPoint(x: 183, y: 365))
            path.addLine(to: CGPoint(x: 179, y: 326))
            path.addQuadCurve(to: CGPoint(x: 185, y: 254), control: CGPoint(x: 187, y: 287))
            path.closeSubpath()
        }

        static let sideShade = Path { path in
            path.move(to: CGPoint(x: 148, y: 31))
            path.addLine(to: CGPoint(x: 156, y: 25))
            path.addLine(to: CGPoint(x: 156, y: 56))
            path.addQuadCurve(to: CGPoint(x: 166, y: 68), control: CGPoint(x: 158, y: 67))
            path.addLine(to: CGPoint(x: 167, y: 84))
            path.addLine(to: CGPoint(x: 151, y: 88))
            path.addLine(to: CGPoint(x: 153, y: 68))
            path.addQuadCurve(to: CGPoint(x: 145, y: 52), control: CGPoint(x: 145, y: 61))
            path.closeSubpath()
            path.move(to: CGPoint(x: 141, y: 246))
            path.addLine(to: CGPoint(x: 161, y: 257))
            path.addLine(to: CGPoint(x: 150, y: 317))
            path.addLine(to: CGPoint(x: 139, y: 343))
            path.addLine(to: CGPoint(x: 121, y: 394))
            path.addLine(to: CGPoint(x: 108, y: 389))
            path.addLine(to: CGPoint(x: 119, y: 324))
            path.addLine(to: CGPoint(x: 132, y: 292))
            path.closeSubpath()
            path.move(to: CGPoint(x: 176, y: 262))
            path.addLine(to: CGPoint(x: 185, y: 254))
            path.addQuadCurve(to: CGPoint(x: 179, y: 326), control: CGPoint(x: 187, y: 287))
            path.addLine(to: CGPoint(x: 183, y: 365))
            path.addLine(to: CGPoint(x: 184, y: 394))
            path.addLine(to: CGPoint(x: 178, y: 394))
            path.addLine(to: CGPoint(x: 175, y: 360))
            path.addLine(to: CGPoint(x: 171, y: 323))
            path.closeSubpath()
        }

        static let sideLight = Path { path in
            path.move(to: CGPoint(x: 163, y: 27))
            path.addQuadCurve(to: CGPoint(x: 175, y: 36), control: CGPoint(x: 173, y: 25))
            path.addLine(to: CGPoint(x: 176, y: 54))
            path.addLine(to: CGPoint(x: 169, y: 59))
            path.addLine(to: CGPoint(x: 162, y: 51))
            path.closeSubpath()
            path.move(to: CGPoint(x: 166, y: 270))
            path.addLine(to: CGPoint(x: 171, y: 267))
            path.addLine(to: CGPoint(x: 167, y: 318))
            path.addLine(to: CGPoint(x: 164, y: 307))
            path.closeSubpath()
            path.move(to: CGPoint(x: 166, y: 335))
            path.addLine(to: CGPoint(x: 170, y: 342))
            path.addLine(to: CGPoint(x: 174, y: 381))
            path.addLine(to: CGPoint(x: 170, y: 378))
            path.closeSubpath()
        }

        static let sideTop = Path { path in
            path.move(to: CGPoint(x: 150, y: 84))
            path.addQuadCurve(to: CGPoint(x: 170, y: 83), control: CGPoint(x: 159, y: 91))
            path.addLine(to: CGPoint(x: 181, y: 96))
            path.addLine(to: CGPoint(x: 185, y: 114))
            path.addLine(to: CGPoint(x: 173, y: 124))
            path.addLine(to: CGPoint(x: 176, y: 150))
            path.addLine(to: CGPoint(x: 176, y: 181))
            path.addLine(to: CGPoint(x: 180, y: 211))
            path.addLine(to: CGPoint(x: 138, y: 213))
            path.addLine(to: CGPoint(x: 141, y: 181))
            path.addLine(to: CGPoint(x: 135, y: 152))
            path.addLine(to: CGPoint(x: 135, y: 110))
            path.addQuadCurve(to: CGPoint(x: 150, y: 84), control: CGPoint(x: 136, y: 93))
            path.closeSubpath()
        }

        static let sidePanels = Path { path in
            path.move(to: CGPoint(x: 145, y: 89))
            path.addLine(to: CGPoint(x: 153, y: 100))
            path.addLine(to: CGPoint(x: 147, y: 151))
            path.addLine(to: CGPoint(x: 151, y: 207))
            path.addLine(to: CGPoint(x: 139, y: 211))
            path.addLine(to: CGPoint(x: 141, y: 181))
            path.addLine(to: CGPoint(x: 135, y: 152))
            path.addLine(to: CGPoint(x: 135, y: 111))
            path.closeSubpath()
            path.move(to: CGPoint(x: 174, y: 92))
            path.addLine(to: CGPoint(x: 181, y: 96))
            path.addLine(to: CGPoint(x: 185, y: 114))
            path.addLine(to: CGPoint(x: 173, y: 124))
            path.addLine(to: CGPoint(x: 166, y: 117))
            path.closeSubpath()
        }

        static let sideArm = Path { path in
            path.move(to: CGPoint(x: 176, y: 117))
            path.addQuadCurve(to: CGPoint(x: 187, y: 134), control: CGPoint(x: 184, y: 121))
            path.addQuadCurve(to: CGPoint(x: 190, y: 151), control: CGPoint(x: 191, y: 142))
            path.addQuadCurve(to: CGPoint(x: 178, y: 166), control: CGPoint(x: 188, y: 160))
            path.addLine(to: CGPoint(x: 160, y: 176))
            path.addLine(to: CGPoint(x: 151, y: 175))
            path.addLine(to: CGPoint(x: 144, y: 168))
            path.addLine(to: CGPoint(x: 149, y: 160))
            path.addLine(to: CGPoint(x: 159, y: 160))
            path.addLine(to: CGPoint(x: 173, y: 150))
            path.addLine(to: CGPoint(x: 171, y: 137))
            path.addLine(to: CGPoint(x: 165, y: 125))
            path.closeSubpath()
        }

        static let sideArmShade = Path { path in
            path.move(to: CGPoint(x: 187, y: 137))
            path.addQuadCurve(to: CGPoint(x: 190, y: 151), control: CGPoint(x: 191, y: 144))
            path.addQuadCurve(to: CGPoint(x: 178, y: 166), control: CGPoint(x: 188, y: 160))
            path.addLine(to: CGPoint(x: 160, y: 176))
            path.addLine(to: CGPoint(x: 151, y: 175))
            path.addLine(to: CGPoint(x: 146, y: 169))
            path.addLine(to: CGPoint(x: 160, y: 169))
            path.addLine(to: CGPoint(x: 180, y: 155))
            path.closeSubpath()
        }

        static let sideShorts = Path { path in
            path.move(to: CGPoint(x: 139, y: 210))
            path.addLine(to: CGPoint(x: 179, y: 209))
            path.addLine(to: CGPoint(x: 188, y: 256))
            path.addLine(to: CGPoint(x: 164, y: 264))
            path.addLine(to: CGPoint(x: 156, y: 245))
            path.addLine(to: CGPoint(x: 146, y: 259))
            path.addLine(to: CGPoint(x: 132, y: 254))
            path.closeSubpath()
        }

        static let sideShortPanels = Path { path in
            path.move(to: CGPoint(x: 140, y: 218))
            path.addLine(to: CGPoint(x: 152, y: 219))
            path.addLine(to: CGPoint(x: 146, y: 257))
            path.addLine(to: CGPoint(x: 133, y: 253))
            path.closeSubpath()
        }

        static let sideFootwear = Path { path in
            path.move(to: CGPoint(x: 108, y: 388))
            path.addLine(to: CGPoint(x: 122, y: 392))
            path.addLine(to: CGPoint(x: 125, y: 400))
            path.addLine(to: CGPoint(x: 143, y: 406))
            path.addQuadCurve(to: CGPoint(x: 145, y: 414), control: CGPoint(x: 149, y: 408))
            path.addLine(to: CGPoint(x: 106, y: 414))
            path.addQuadCurve(to: CGPoint(x: 102, y: 408), control: CGPoint(x: 101, y: 414))
            path.closeSubpath()
            path.move(to: CGPoint(x: 168, y: 388))
            path.addLine(to: CGPoint(x: 184, y: 389))
            path.addLine(to: CGPoint(x: 190, y: 400))
            path.addLine(to: CGPoint(x: 208, y: 405))
            path.addQuadCurve(to: CGPoint(x: 212, y: 414), control: CGPoint(x: 215, y: 408))
            path.addLine(to: CGPoint(x: 169, y: 414))
            path.addQuadCurve(to: CGPoint(x: 165, y: 408), control: CGPoint(x: 164, y: 414))
            path.closeSubpath()
        }

        static let sideSoles = Path { path in
            path.move(to: CGPoint(x: 103, y: 409))
            path.addLine(to: CGPoint(x: 147, y: 409))
            path.addLine(to: CGPoint(x: 145, y: 415))
            path.addLine(to: CGPoint(x: 106, y: 415))
            path.closeSubpath()
            path.move(to: CGPoint(x: 166, y: 409))
            path.addLine(to: CGPoint(x: 214, y: 409))
            path.addLine(to: CGPoint(x: 212, y: 415))
            path.addLine(to: CGPoint(x: 169, y: 415))
            path.closeSubpath()
        }

        static let sideSeams = Path { path in
            path.move(to: CGPoint(x: 153, y: 91))
            path.addLine(to: CGPoint(x: 165, y: 92))
            path.move(to: CGPoint(x: 155, y: 120))
            path.addLine(to: CGPoint(x: 155, y: 153))
            path.move(to: CGPoint(x: 155, y: 181))
            path.addLine(to: CGPoint(x: 158, y: 203))
            path.move(to: CGPoint(x: 143, y: 204))
            path.addLine(to: CGPoint(x: 175, y: 203))
            path.move(to: CGPoint(x: 165, y: 256))
            path.addLine(to: CGPoint(x: 182, y: 251))
            path.move(to: CGPoint(x: 178, y: 400))
            path.addLine(to: CGPoint(x: 192, y: 403))
        }

        static let sideAccents = Path { path in
            path.move(to: CGPoint(x: 151, y: 113))
            path.addLine(to: CGPoint(x: 163, y: 116))
            path.move(to: CGPoint(x: 141, y: 217))
            path.addLine(to: CGPoint(x: 178, y: 216))
            path.move(to: CGPoint(x: 181, y: 234))
            path.addLine(to: CGPoint(x: 184, y: 249))
        }

        static let front = Figure(
            skin: raisedSkin, shade: raisedShade, light: raisedLight,
            top: raisedTop(rear: false), panels: frontPanels,
            shorts: raisedShorts, shortPanels: raisedShortPanels,
            footwear: raisedShoes, soles: raisedSoles,
            foregroundSkin: Path(), foregroundShade: Path(),
            seams: raisedSeams(rear: false), accents: raisedAccents(rear: false)
        )

        static let rear = Figure(
            skin: raisedSkin, shade: raisedShade, light: raisedLight,
            top: raisedTop(rear: true), panels: rearPanels,
            shorts: raisedShorts, shortPanels: raisedShortPanels,
            footwear: raisedShoes, soles: raisedSoles,
            foregroundSkin: Path(), foregroundShade: Path(),
            seams: raisedSeams(rear: true), accents: raisedAccents(rear: true)
        )

        static let side = Figure(
            skin: sideSkin, shade: sideShade, light: sideLight,
            top: sideTop, panels: sidePanels,
            shorts: sideShorts, shortPanels: sideShortPanels,
            footwear: sideFootwear, soles: sideSoles,
            foregroundSkin: sideArm, foregroundShade: sideArmShade,
            seams: sideSeams, accents: sideAccents
        )
    }
}
