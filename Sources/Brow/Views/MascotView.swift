import BrowCore
import SwiftUI

/// The little Brow: the app icon come alive. Its black "brow" and two eyes carry
/// every expression; the eyes follow the cursor and it blinks and breathes.
struct MascotView: View {
    let model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var jumps = 0

    private static let size = NotchGeometry.mascotSize
    private static let gazeSpring = Animation.spring(duration: 0.25, bounce: 0)
    private static let moodSpring = Animation.spring(duration: 0.35, bounce: 0.15)

    var body: some View {
        let reduceMotion = reduceMotion   // captured for the Sendable keyframe closure
        return TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let now = context.date
            let expression = model.mascot.expression(at: now)
            face(expression, blinking: Self.isBlinking(at: now), gaze: gaze)
                .scaleEffect(reduceMotion ? 1 : Self.breath(at: now))
                .overlay(alignment: .topTrailing) {
                    if expression == .asleep { sleepZ(at: now) }
                }
                .onChange(of: expression) { _, new in
                    if new == .happy { jumps += 1 }
                }
        }
        .frame(width: Self.size, height: Self.size)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: jumps) { content, lift in
            content.offset(y: reduceMotion ? 0 : lift)
        } keyframes: { _ in
            SpringKeyframe(-5, duration: 0.15, spring: .snappy)
            SpringKeyframe(0, duration: 0.4, spring: .bouncy)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.mascotClicked() }
    }

    private var gaze: CGSize {
        guard let geometry = model.panel?.geometry else { return .zero }
        let rect = geometry.mascotRect
        return MascotGaze.pupilOffset(mascotCenter: CGPoint(x: rect.midX, y: rect.midY),
                                      cursor: model.cursor, maxOffset: 1.6)
    }

    private func face(_ expression: MascotExpression, blinking: Bool, gaze: CGSize) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 7)
                .fill(LinearGradient(colors: [Color(white: 0.98), Color(red: 0.85, green: 0.86, blue: 0.9)],
                                     startPoint: .top, endPoint: .bottom))
            UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
                .fill(.black)
                .frame(width: 14, height: Self.browHeight(expression))
                .animation(Self.moodSpring, value: expression)
            HStack(spacing: 3.5) {
                eye(expression, blinking: blinking, isRight: false)
                eye(expression, blinking: blinking, isRight: true)
            }
            .offset(gazeAllowed(expression) ? gaze : .zero)
            .animation(Self.gazeSpring, value: gaze)
            .padding(.top, 11)
        }
        .frame(width: Self.size, height: Self.size)
    }

    @ViewBuilder private func eye(_ expression: MascotExpression, blinking: Bool, isRight: Bool) -> some View {
        switch expression {
        case .happy:
            EyeArc(up: true).stroke(.black, style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).frame(width: 4, height: 4)
        case .squint:
            EyeChevron(pointsRight: !isRight).stroke(.black, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 4, height: 4)
        case .wink where isRight:
            EyeArc(up: false).stroke(.black, style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).frame(width: 4, height: 4)
        case .asleep:
            Capsule().fill(.black).frame(width: 4, height: 1.4).padding(.vertical, 1.5)
        default:
            Ellipse().fill(.black)
                .frame(width: expression == .curious || expression == .waking ? 4 : 3.6,
                       height: expression == .curious || expression == .waking ? 5 : 4.4)
                .scaleEffect(y: blinking ? 0.15 : (expression == .drowsy ? 0.45 : 1), anchor: .center)
                .animation(.easeOut(duration: 0.06), value: blinking)
                .animation(Self.moodSpring, value: expression)
        }
    }

    private func sleepZ(at now: Date) -> some View {
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
        return Text("z")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(1 - phase))
            .offset(x: 7, y: reduceMotion ? -6 : -4 - 6 * phase)
    }

    private func gazeAllowed(_ expression: MascotExpression) -> Bool {
        expression != .asleep && expression != .squint
    }

    /// Hanging length of the brow: shorter reads as raised, longer as lowered over the eyes.
    private static func browHeight(_ expression: MascotExpression) -> CGFloat {
        switch expression {
        case .curious, .waking: 3.5
        case .happy: 5
        case .idle, .wink: 6
        case .squint: 7.5
        case .drowsy: 8.5
        case .asleep: 9
        }
    }

    /// Two out-of-step cycles give irregular blinks without randomness.
    private static func isBlinking(at date: Date) -> Bool {
        let t = date.timeIntervalSinceReferenceDate
        return t.truncatingRemainder(dividingBy: 4.3) < 0.12 || (t + 1.7).truncatingRemainder(dividingBy: 6.1) < 0.12
    }

    /// A 3% swell every 3.5 s.
    private static func breath(at date: Date) -> CGFloat {
        1 + 0.03 * CGFloat(sin(date.timeIntervalSinceReferenceDate * 2 * .pi / 3.5))
    }
}

/// "^" (up) or "‿"-like closed eye (down).
private struct EyeArc: Shape {
    let up: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if up {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - 1))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY + 1))
        }
        return path
    }
}

/// ">" or "<" for a squeezed eye.
private struct EyeChevron: Shape {
    let pointsRight: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let (outer, tip) = pointsRight ? (rect.minX, rect.maxX) : (rect.maxX, rect.minX)
        path.move(to: CGPoint(x: outer, y: rect.minY))
        path.addLine(to: CGPoint(x: tip, y: rect.midY))
        path.addLine(to: CGPoint(x: outer, y: rect.maxY))
        return path
    }
}
