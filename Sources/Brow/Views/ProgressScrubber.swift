import SwiftUI

/// Playback progress drawn by hand. The system slider takes its colours from the
/// Mac's appearance and macOS version, and on the black panel its track vanished
/// in Light mode; this one looks the same everywhere.
struct ProgressScrubber: View {
    let position: TimeInterval
    let duration: TimeInterval
    /// The position under the pointer while dragging; `ended` is true when the drag ends.
    let onScrub: (_ position: TimeInterval, _ ended: Bool) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovering = false
    @State private var isDragging = false

    /// VoiceOver steps by 10 seconds.
    private static let accessibilityStep: TimeInterval = 10

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let fraction = duration > 0 ? min(max(position / duration, 0), 1) : 0
            let knob: CGFloat = isHovering || isDragging ? 10 : 8
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(contrast == .increased ? 0.45 : 0.25))
                    .frame(height: 3)
                Capsule()
                    .fill(.white)
                    .frame(width: width * fraction, height: 3)
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .offset(x: (width - knob) * fraction)
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        onScrub(seconds(at: value.location.x, width: width), false)
                    }
                    .onEnded { value in
                        isDragging = false
                        onScrub(seconds(at: value.location.x, width: width), true)
                    }
            )
        }
        .frame(height: 14)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering || isDragging)
        .accessibilityElement()
        .accessibilityLabel("Позиция воспроизведения")
        .accessibilityValue("\(MusicView.format(position)) из \(MusicView.format(duration))")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? Self.accessibilityStep : -Self.accessibilityStep
            onScrub(min(max(position + step, 0), duration), true)
        }
    }

    private func seconds(at x: CGFloat, width: CGFloat) -> TimeInterval {
        Double(min(max(x / width, 0), 1)) * duration
    }
}
