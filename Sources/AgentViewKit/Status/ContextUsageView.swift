import SwiftUI

/// The context window use of a thread, with its cost (plan.md §9 C, research
/// R16).
///
/// Pass ``AgentThread/usage`` as `usage`. When `usage` is `nil`, the view is
/// empty. The view shows a ring with the part of the context window in use
/// and the percentage. The help tag of the ring shows the tokens in use of
/// the window size. A cost label shows only when the source gives a cost.
public struct ContextUsageView: View {
  /// The accessibility identifier of the percentage element.
  public static let percentIdentifier = "context-usage-percent"

  /// The accessibility identifier of the cost label.
  public static let costIdentifier = "context-usage-cost"

  /// The number of fraction digits of the percentage.
  static let percentFractionDigits = 0

  /// The diameter of the ring, in points.
  static let ringDiameter: CGFloat = 16

  /// The line width of the ring, in points.
  static let ringLineWidth: CGFloat = 2

  /// The fraction where the filled arc of the ring starts.
  static let ringEmptyFraction: CGFloat = 0

  /// The number of degrees in a quarter turn.
  static let quarterTurnDegrees: Double = 90

  /// The rotation that puts the start of the filled arc at the top of the
  /// ring. A trimmed circle starts at the right side, so the ring turns back
  /// by a quarter turn.
  static let ringStartAngle = Angle.degrees(-quarterTurnDegrees)

  /// The fraction of a full context window.
  static let fullFraction: Double = 1

  /// The usage to show, or `nil`.
  let usage: ContextUsage?

  @Environment(\.agentTheme) private var theme

  /// Makes the view.
  ///
  /// - Parameter usage: The usage to show, such as ``AgentThread/usage``.
  public init(usage: ContextUsage?) {
    self.usage = usage
  }

  // MARK: - Text

  /// The part of the context window in use, as a percentage.
  ///
  /// - Parameters:
  ///   - usage: The usage.
  ///   - locale: The locale of the number format.
  /// - Returns: The rounded percentage of ``ContextUsage/fraction``, such as
  ///   `50%`.
  public static func percentText(for usage: ContextUsage, locale: Locale = .current) -> String {
    usage.fraction.formatted(
      .percent.precision(.fractionLength(percentFractionDigits)).locale(locale))
  }

  /// The text of the help tag of the ring.
  ///
  /// - Parameters:
  ///   - usage: The usage.
  ///   - locale: The locale of the number format.
  /// - Returns: The tokens in use of the window size, such as
  ///   `1,200 of 4,000 tokens`.
  public static func detailText(for usage: ContextUsage, locale: Locale = .current) -> String {
    let used = usage.used.formatted(.number.locale(locale))
    let size = usage.size.formatted(.number.locale(locale))
    return String(localized: "\(used) of \(size) tokens")
  }

  /// The text of the cost label.
  ///
  /// - Parameters:
  ///   - cost: The cost.
  ///   - locale: The locale of the currency format.
  /// - Returns: The amount in its currency, such as `$1.25`.
  public static func costText(for cost: ContextUsage.Cost, locale: Locale = .current) -> String {
    cost.amount.formatted(.currency(code: cost.currency).locale(locale))
  }

  // MARK: - Body

  public var body: some View {
    if let usage {
      let percent = Self.percentText(for: usage)
      let detail = Self.detailText(for: usage)
      HStack(spacing: theme.spacing.s) {
        HStack(spacing: theme.spacing.xs) {
          ring(for: usage)
          Text(percent)
            .monospacedDigit()
        }
        .help(detail)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Context used")
        .accessibilityValue(percent)
        .accessibilityHint(detail)
        // An element with no role does not give its value. The trait gives the
        // static text role.
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier(Self.percentIdentifier)
        if let cost = usage.cost {
          Text(Self.costText(for: cost))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(Self.costIdentifier)
        }
      }
      .font(.caption)
    }
  }

  /// The ring that fills with the part of the window in use.
  ///
  /// - Parameter usage: The usage.
  /// - Returns: The ring view.
  private func ring(for usage: ContextUsage) -> some View {
    ZStack {
      Circle()
        .stroke(.quaternary, lineWidth: Self.ringLineWidth)
      Circle()
        .trim(from: Self.ringEmptyFraction, to: usage.fraction)
        .stroke(
          ringColor(for: usage),
          style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round))
        .rotationEffect(Self.ringStartAngle)
    }
    .frame(width: Self.ringDiameter, height: Self.ringDiameter)
  }

  /// The color of the ring: the failure color when the window is full, and
  /// the running color otherwise.
  ///
  /// - Parameter usage: The usage.
  /// - Returns: The color.
  private func ringColor(for usage: ContextUsage) -> Color {
    usage.fraction >= Self.fullFraction ? theme.statusColors.failed : theme.statusColors.running
  }
}
