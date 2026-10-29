import CoreGraphics
import Foundation

/// Things in Brow the mascot reacts to.
public enum MascotEvent: Sendable {
    case fileShelved, textCopied, screenshotTaken, linkSaved
}

public enum MascotExpression: Equatable, Sendable {
    case idle
    /// Brow raised: the cursor is right next to it.
    case curious
    /// Eyes as "^^": clicked, or a file landed on the shelf.
    case happy
    /// One eye closed: text was copied.
    case wink
    /// Eyes squeezed "> <": a screenshot "flash".
    case squint
    /// Heavy lids, brow down: the cursor has been resting a while.
    case drowsy
    /// Eyes shut: the cursor has been resting longer.
    case asleep
    /// Brow up after the panel opens following a long break.
    case waking
}

/// The mascot's mood. Time is passed in, so tests need no waiting.
public struct MascotState: Equatable, Sendable {
    public static let reactionDuration: TimeInterval = 1
    /// The wake-up scene: asleep while the panel unfolds, then eyes half open, then wide awake.
    public static let wakingDuration: TimeInterval = 1.6
    static let wakeAsleepUntil: TimeInterval = 0.6
    static let wakeDrowsyUntil: TimeInterval = 0.9
    public static let drowsyAfter: TimeInterval = 15
    public static let asleepAfter: TimeInterval = 30
    /// Opening the panel after at least this long closed plays the wake-up.
    public static let wakeAfterAbsence: TimeInterval = 60

    public var isHovered = false
    private var lastActivity: Date
    private var reaction: MascotExpression?
    private var reactionStarts: Date
    private var reactionEnds: Date
    private var closedAt: Date?

    public init(now: Date) {
        lastActivity = now
        reactionStarts = now
        reactionEnds = now
    }

    public mutating func cursorMoved(now: Date) {
        lastActivity = now
    }

    public mutating func clicked(now: Date) {
        react(.happy, for: Self.reactionDuration, now: now)
    }

    public mutating func handle(_ event: MascotEvent, now: Date) {
        switch event {
        case .fileShelved, .linkSaved: react(.happy, for: Self.reactionDuration, now: now)
        case .textCopied: react(.wink, for: Self.reactionDuration, now: now)
        case .screenshotTaken: react(.squint, for: Self.reactionDuration, now: now)
        }
    }

    public mutating func panelOpened(now: Date) {
        lastActivity = now
        if let closedAt, now.timeIntervalSince(closedAt) >= Self.wakeAfterAbsence {
            react(.waking, for: Self.wakingDuration, now: now)
        }
        closedAt = nil
    }

    public mutating func panelClosed(now: Date) {
        closedAt = now
    }

    public func expression(at now: Date) -> MascotExpression {
        if let reaction, now < reactionEnds {
            guard reaction == .waking else { return reaction }
            let elapsed = now.timeIntervalSince(reactionStarts)
            if elapsed < Self.wakeAsleepUntil { return .asleep }
            if elapsed < Self.wakeDrowsyUntil { return .drowsy }
            return .waking
        }
        let resting = now.timeIntervalSince(lastActivity)
        if resting >= Self.asleepAfter { return .asleep }
        if resting >= Self.drowsyAfter { return .drowsy }
        return isHovered ? .curious : .idle
    }

    /// A reaction also counts as activity, so it wakes the mascot up.
    private mutating func react(_ expression: MascotExpression, for duration: TimeInterval, now: Date) {
        reaction = expression
        reactionStarts = now
        reactionEnds = now + duration
        lastActivity = now
    }
}

/// Where the pupils look.
public enum MascotGaze {
    /// Cursor distance at which the eyes are turned all the way.
    public static let fullTurnDistance: CGFloat = 60

    /// Pupil offset toward the cursor in view coordinates (y down), at most `maxOffset` long.
    /// Both points are global AppKit coordinates (y up).
    public static func pupilOffset(mascotCenter: CGPoint, cursor: CGPoint, maxOffset: CGFloat) -> CGSize {
        let dx = cursor.x - mascotCenter.x
        let dy = -(cursor.y - mascotCenter.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 0 else { return .zero }
        let length = maxOffset * min(1, distance / fullTurnDistance)
        return CGSize(width: dx / distance * length, height: dy / distance * length)
    }
}

extension NotchGeometry {
    public static let mascotSize: CGFloat = 24
    /// Gap between the mascot and the notch, so it looks like it peeks out from behind it.
    public static let mascotGap: CGFloat = 6

    /// The mascot's spot in the left "ear" of the expanded panel, in global coordinates.
    public var mascotRect: CGRect {
        let size = Self.mascotSize
        return CGRect(x: notchRect.minX - Self.mascotGap - size,
                      y: notchRect.midY - size / 2,
                      width: size, height: size)
    }
}
