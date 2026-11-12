import SwiftUI

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let drift: CGFloat
    let delay: Double
    let duration: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let initialRotation: Double
    let finalRotation: Double

    static func random(screenWidth: CGFloat) -> ConfettiParticle {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .white,
            Color(red: 1, green: 0.4, blue: 0.7)
        ]
        let shapeType = Int.random(in: 0...2)
        let w: CGFloat
        let h: CGFloat
        let cr: CGFloat
        switch shapeType {
        case 0:  w = CGFloat.random(in: 8...14);  h = CGFloat.random(in: 6...10);  cr = 2
        case 1:  let s = CGFloat.random(in: 6...10); w = s; h = s; cr = s / 2
        default: w = CGFloat.random(in: 10...16); h = CGFloat.random(in: 2...4);   cr = 1
        }
        return ConfettiParticle(
            startX:          CGFloat.random(in: 0...screenWidth),
            drift:            CGFloat.random(in: -80...80),
            delay:            Double.random(in: 0...1.5),
            duration:         Double.random(in: 2.5...4.0),
            color:            colors.randomElement()!,
            width:            w,
            height:           h,
            cornerRadius:     cr,
            initialRotation:  Double.random(in: 0...360),
            finalRotation:    Double.random(in: 360...1080)
        )
    }
}

private struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat

    @State private var y: CGFloat = -50
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: particle.cornerRadius)
            .fill(particle.color)
            .frame(width: particle.width, height: particle.height)
            .rotationEffect(.degrees(rotation))
            .position(x: particle.startX + xDrift, y: y)
            .opacity(opacity)
            .onAppear {
                rotation = particle.initialRotation
                withAnimation(
                    Animation.easeIn(duration: particle.duration)
                        .delay(particle.delay)
                ) {
                    y      = screenHeight + 50
                    xDrift = particle.drift
                    rotation = particle.finalRotation
                }
                withAnimation(
                    Animation.linear(duration: 0.5)
                        .delay(particle.delay + particle.duration - 0.5)
                ) {
                    opacity = 0
                }
            }
    }
}

struct PlayerConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { p in
                ConfettiPieceView(particle: p, screenHeight: geo.size.height)
            }
            .onAppear {
                particles = (0..<120).map { _ in
                    ConfettiParticle.random(screenWidth: geo.size.width)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
