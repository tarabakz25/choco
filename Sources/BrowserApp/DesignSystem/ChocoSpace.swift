import CoreGraphics

/// Spacing tokens, expressed in rem so the whole scale can be retuned from `rem`.
/// 1rem = 16pt. Prefer these over literal paddings and stack spacings; leave 1–3pt
/// optical nudges (hairlines, icon alignment) as literals.
enum ChocoSpace {
    static let rem: CGFloat = 16

    static let xxs: CGFloat = 0.125 * rem // 2
    static let xs: CGFloat = 0.25 * rem   // 4
    static let sm: CGFloat = 0.5 * rem    // 8
    static let md: CGFloat = 0.75 * rem   // 12
    static let lg: CGFloat = 1 * rem      // 16
    static let xl: CGFloat = 1.5 * rem    // 24
    static let xxl: CGFloat = 2 * rem     // 32

    /// Converts a rem multiple to points for sizes that are not spacing (widths, heights).
    static func rem(_ value: CGFloat) -> CGFloat { value * rem }
}
