import CoreGraphics

/// Spacing tokens, expressed in rem so the whole scale can be retuned from `rem`.
/// 1rem = 20pt (the Figma design is drawn at 16pt; `scale` is the enlargement applied on top).
/// Prefer these over literal paddings and stack spacings; leave 1–3pt optical nudges
/// (hairlines, icon alignment) as literals.
enum ChocoSpace {
    /// Size of the Figma design's rem, in points.
    static let designRem: CGFloat = 16
    static let rem: CGFloat = 20
    /// Enlargement of every size measured in Figma. `u(_:)`, `ChocoTheme.font(_:)` and the icon views apply it.
    static let scale: CGFloat = rem / designRem

    static let xxs: CGFloat = 0.125 * rem // 2.5
    static let xs: CGFloat = 0.25 * rem   // 5
    static let sm: CGFloat = 0.5 * rem    // 10
    static let md: CGFloat = 0.75 * rem   // 15
    static let lg: CGFloat = 1 * rem      // 20
    static let xl: CGFloat = 1.5 * rem    // 30
    static let xxl: CGFloat = 2 * rem     // 40

    /// Converts a rem multiple to points for sizes that are not spacing (widths, heights).
    static func rem(_ value: CGFloat) -> CGFloat { value * rem }

    /// Converts a size measured in the Figma design (frames, paddings, stack spacings) to points,
    /// rounded to whole points so edges stay crisp.
    static func u(_ value: CGFloat) -> CGFloat { (value * scale).rounded() }
}
