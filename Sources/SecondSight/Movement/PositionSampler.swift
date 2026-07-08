import CoreGraphics

/// Picks where the clock goes next. Pure — screen rect in, origin out.
enum PositionSampler {
    /// Returns a bottom-left origin for a `clockSize` panel placed randomly inside
    /// `visibleFrame`, inset on all sides, and (when possible) at least
    /// `minDistanceFraction` of the screen width away from `previous`.
    /// Falls back to the farthest candidate found when the distance constraint
    /// is unsatisfiable (small screens), and to the inset origin when the clock
    /// doesn't fit at all.
    static func samplePosition(
        in visibleFrame: CGRect,
        clockSize: CGSize,
        previous: CGPoint?,
        inset: CGFloat = 24,
        minDistanceFraction: CGFloat = 0.2,
        using rng: inout some RandomNumberGenerator
    ) -> CGPoint {
        let usable = visibleFrame.insetBy(dx: inset, dy: inset)
        let fallback = CGPoint(x: visibleFrame.minX + inset, y: visibleFrame.minY + inset)
        // insetBy returns CGRect.null (infinite coords) when the frame is
        // smaller than 2×inset in either axis — check before using it.
        guard !usable.isNull else { return fallback }
        let maxX = usable.maxX - clockSize.width
        let maxY = usable.maxY - clockSize.height
        guard maxX >= usable.minX, maxY >= usable.minY else { return fallback }

        let minDistance = visibleFrame.width * minDistanceFraction
        var farthest = CGPoint(x: usable.minX, y: usable.minY)
        var farthestDistance: CGFloat = -1

        for _ in 0..<64 {
            let candidate = CGPoint(
                x: CGFloat.random(in: usable.minX...maxX, using: &rng),
                y: CGFloat.random(in: usable.minY...maxY, using: &rng)
            )
            guard let previous else { return candidate }
            let distance = hypot(candidate.x - previous.x, candidate.y - previous.y)
            if distance >= minDistance { return candidate }
            if distance > farthestDistance {
                farthest = candidate
                farthestDistance = distance
            }
        }
        return farthest
    }
}
