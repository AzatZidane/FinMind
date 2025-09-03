import CoreGraphics

extension Double    { var clampedFinite: Double  { isFinite ? self : 0 } }
extension CGFloat   { var clampedFinite: CGFloat { isFinite ? self : 0 } }

@inline(__always)
func safeRatio(numerator: Double, denominator: Double) -> Double {
    guard denominator != 0,
          numerator.isFinite, denominator.isFinite else { return 0 }
    let r = numerator / denominator
    return r.isFinite ? r : 0
}
