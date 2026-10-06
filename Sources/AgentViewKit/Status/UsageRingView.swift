import SwiftUI

/// A ring that fills with a part of a whole, with a text beside it.
///
/// The caller gives the part (`numerator`), the whole (`denominator`) and the
/// caption of the counts, such as `tokens`. The view does not keep a copy of
/// a model value. ``TextStyle`` selects the text beside the ring: the
/// percentage, or the part of the whole with the caption. The help tag and
/// the accessibility hint give the other text.
public struct UsageRingView: View {
  /// The text that shows beside the ring.
  public enum TextStyle: Sendable, Hashable {
    /// The percentage, such as `30%`.
    case short

    /// The part of the whole with the caption, such as
    /// `1,200 of 4,000 tokens`.
    case full
  }

  /// The number of fraction digits of the percentage.
  static let percentFractionDigits = 0

  /// The diameter of the ring, in points.
  static let ringDiameter: CGFloat = 16

  /// The line width of the ring, in points.
  static let ringLineWidth: CGFloat = 2

  /// The fraction where the filled arc of the ring starts.
  static let ringEmptyFraction: Double = 0

  /// The fraction of a full ring.
  static let fullFraction: Double = 1

  /// The number of degrees in a quarter turn.
  static let quarterTurnDegrees: Double = 90

  /// The rotation that puts the start of the filled arc at the top of the
  /// ring. A trimmed circle starts at the right side, so the ring turns back
  /// by a quarter turn.
  static let ringStartAngle = Angle.degrees(-quarterTurnDegrees)

  /// The part of the whole.
  let numerator: Int

  /// The whole.
  let denominator: Int

  /// The caption of the counts, such as `tokens`.
  let caption: String

  /// The text that shows beside the ring.
  let style: TextStyle

  @Environment(\.agentTheme) private var theme

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - numerator: The part of the whole.
  ///   - denominator: The whole.
  ///   - caption: The caption of the counts, such as `tokens`.
  ///   - style: The text that shows beside the ring.
  public init(numerator: Int, denominator: Int, caption: String, style: TextStyle = .short) {
    self.numerator = numerator
    self.denominator = denominator
    self.caption = caption
    self.style = style
  }

  // MARK: - Text

  /// The part of the whole, from `0` to `1`.
  ///
  /// - Parameters:
  ///   - numerator: The part of the whole.
  ///   - denominator: The whole.
  /// - Returns: `numerator` divided by `denominator`, clamped to `0...1`, or
  ///   `0` when `denominator` is `0` or less.
  private static func fraction(numerator: Int, denominator: Int) -> Double {
    guard denominator > 0 else { return ringEmptyFraction }
    return min(max(Double(numerator) / Double(denominator), ringEmptyFraction), fullFraction)
  }

  /// The part of the whole, as a percentage.
  ///
  /// - Parameters:
  ///   - numerator: The part of the whole.
  ///   - denominator: The whole.
  ///   - locale: The locale of the number format.
  /// - Returns: The rounded percentage, such as `30%`.
  public static func percentText(numerator: Int, denominator: Int, locale: Locale = .current) -> String {
    fraction(numerator: numerator, denominator: denominator).formatted(
      .percent.precision(.fractionLength(percentFractionDigits)).locale(locale))
  }

  /// The part of the whole with the caption.
  ///
  /// - Parameters:
  ///   - numerator: The part of the whole.
  ///   - denominator: The whole.
  ///   - caption: The caption of the counts.
  ///   - locale: The locale of the number format.
  /// - Returns: The text, such as `1,200 of 4,000 tokens`.
  public static func detailText(
    numerator: Int, denominator: Int, caption: String, locale: Locale = .current
  ) -> String {
    let part = numerator.formatted(.number.locale(locale))
    let whole = denominator.formatted(.number.locale(locale))
    return String(localized: "\(part) of \(whole) \(caption)")
  }

  // MARK: - Body

  public var body: some View {
    let percent = Self.percentText(numerator: numerator, denominator: denominator)
    let detail = Self.detailText(numerator: numerator, denominator: denominator, caption: caption)
    let shown = style == .short ? percent : detail
    let other = style == .short ? detail : percent
    HStack(spacing: theme.spacing.xs) {
      ring
      Text(shown)
        .monospacedDigit()
    }
    .help(other)
    .accessibilityElement(children: .ignore)
    .accessibilityValue(shown)
    .accessibilityHint(other)
    // An element with no role does not give its value. The trait gives the
    // static text role.
    .accessibilityAddTraits(.isStaticText)
  }

  /// The ring that fills with the part of the whole.
  private var ring: some View {
    let filled = Self.fraction(numerator: numerator, denominator: denominator)
    return ZStack {
      Circle()
        .stroke(.quaternary, lineWidth: Self.ringLineWidth)
      Circle()
        .trim(from: Self.ringEmptyFraction, to: filled)
        .stroke(
          ringColor(for: filled),
          style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round))
        .rotationEffect(Self.ringStartAngle)
    }
    .frame(width: Self.ringDiameter, height: Self.ringDiameter)
  }

  /// The color of the ring: the failure color when the ring is full, and the
  /// running color otherwise.
  ///
  /// - Parameter filled: The part of the ring that is filled.
  /// - Returns: The color.
  private func ringColor(for filled: Double) -> Color {
    filled >= Self.fullFraction ? theme.statusColors.failed : theme.statusColors.running
  }
}
