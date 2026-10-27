import CoreGraphics

/// Spacing tokens, expressed in rem so the whole scale can be retuned from `rem`.
/// 1rem = 16pt, as in the Figma `Spacing (rem)` variables (DESIGN.md §4); sizes are used as points unscaled.
/// Prefer these over literal paddings and stack spacings; leave 1–3pt optical nudges
/// (hairlines, icon alignment) as literals.
enum ChocoSpace {
    /// Size of the Figma design's rem, in points.
    static let designRem: CGFloat = 16
    static let rem: CGFloat = 16
    /// Enlargement of every size measured in Figma (1 = as designed). `u(_:)` and the icon views apply it.
    static let scale: CGFloat = rem / designRem

    static let xxs: CGFloat = 0.125 * rem // 2
    static let xs: CGFloat = 0.25 * rem   // 4
    static let sm: CGFloat = 0.5 * rem    // 8
    static let md: CGFloat = 0.75 * rem   // 12
    static let lg: CGFloat = 1 * rem      // 16
    static let xl: CGFloat = 1.5 * rem    // 24
    static let xxl: CGFloat = 2 * rem     // 32

    /// Converts a rem multiple to points for sizes that are not spacing (widths, heights).
    static func rem(_ value: CGFloat) -> CGFloat { value * rem }

    /// Converts a size measured in the Figma design (frames, paddings, stack spacings) to points,
    /// rounded to whole points so edges stay crisp.
    static func u(_ value: CGFloat) -> CGFloat { (value * scale).rounded() }
}
