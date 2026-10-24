import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// A ring that fills with a part of a whole, with a text beside it.
///
/// The caller gives the part (`numerator`), the whole (`denominator`) and the
/// caption of the counts, such as `tokens`. The view does not keep a copy of
/// a model value. ``TextStyle`` selects the text beside the ring: the
/// percentage, or the part of the whole with the caption. The help tag and
/// the accessibility hint give the other text.
///
/// The ring is an SF Symbol with a variable value, so it scales with the
/// font of the view, as the text does. A full ring shows a different symbol
/// in the failed status color of the EditorKit theme, so the full state does
/// not show with the color only. The accessibility label of the view is
/// ``labelText``. A caller can set a more specific label.
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

  /// The fraction of an empty ring.
  static let emptyFraction: Double = 0

  /// The fraction of a full ring.
  static let fullFraction: Double = 1

  /// The part of the whole.
  let numerator: Int

  /// The whole.
  let denominator: Int

  /// The caption of the counts, such as `tokens`.
  let caption: String

  /// The text that shows beside the ring.
  let style: TextStyle

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

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
    guard denominator > 0 else { return emptyFraction }
    return min(max(Double(numerator) / Double(denominator), emptyFraction), fullFraction)
  }

  /// Tells whether a part fills the whole ring.
  ///
  /// - Parameter filled: The part of the ring that is filled, from `0` to
  ///   `1`.
  /// - Returns: `true` when the ring is full.
  private static func isFull(_ filled: Double) -> Bool {
    filled >= fullFraction
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
    return String(localized: "\(part) of \(whole) \(caption)", bundle: .module)
  }

  /// The accessibility label of the view: the name of the value, before the
  /// value and the hint.
  static var labelText: String { String(localized: "Usage", bundle: .module) }

  /// The SF Symbol name of the ring for a part of a whole.
  ///
  /// - Parameters:
  ///   - numerator: The part of the whole.
  ///   - denominator: The whole.
  /// - Returns: ``SharedSymbol/usageFull`` when the part fills the whole,
  ///   and ``SharedSymbol/usage`` otherwise.
  static func symbolName(numerator: Int, denominator: Int) -> String {
    let filled = fraction(numerator: numerator, denominator: denominator)
    return isFull(filled) ? SharedSymbol.usageFull : SharedSymbol.usage
  }

  // MARK: - Body

  public var body: some View {
    let percent = Self.percentText(numerator: numerator, denominator: denominator)
    let detail = Self.detailText(numerator: numerator, denominator: denominator, caption: caption)
    let shown = style == .short ? percent : detail
    let other = style == .short ? detail : percent
    HStack(spacing: editorStyle.spacing.xs) {
      ring
      Text(shown)
        .monospacedDigit()
    }
    .help(other)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.labelText)
    .accessibilityValue(shown)
    .accessibilityHint(other)
    // An element with no role does not give its value. The trait gives the
    // static text role.
    .accessibilityAddTraits(.isStaticText)
  }

  /// The ring that fills with the part of the whole: an SF Symbol whose
  /// variable value draws the ring up to the part. The symbol scales with
  /// the font of the view.
  private var ring: some View {
    let filled = Self.fraction(numerator: numerator, denominator: denominator)
    return Image(
      systemName: Self.symbolName(numerator: numerator, denominator: denominator), variableValue: filled
    )
    .symbolVariableValueMode(.draw)
    .foregroundStyle(ringColor(for: filled))
    .fontWeight(editorStyle.symbolWeight)
  }

  /// The color of the ring: the failed status role of the EditorKit theme when
  /// the ring is full, and the running status role otherwise.
  ///
  /// - Parameter filled: The part of the ring that is filled.
  /// - Returns: The color.
  private func ringColor(for filled: Double) -> Color {
    Self.isFull(filled) ? editorTheme.statusFailed : editorTheme.statusRunning
  }
}

#Preview("Usage ring") {
  let usage = PreviewFixtures.usage
  UsageRingView(numerator: usage.used, denominator: usage.size, caption: "Context")
}
