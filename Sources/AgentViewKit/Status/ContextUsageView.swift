import SwiftUI

/// The context window use of a thread, with its token counts, cost, and quota
/// (plan.md §9 C, research R16).
///
/// Pass ``AgentThread/usage`` as `usage`. When `usage` is `nil`, the view is
/// empty. The view shows a ring with the part of the context window in use
/// and the percentage. The help tag of the ring shows the tokens in use of
/// the window size and the input, cached, output, and reasoning token counts
/// that the source gives. A cost label shows only when the source gives a
/// cost, and a quota label shows only when the source gives a quota state.
public struct ContextUsageView: View {
  /// The accessibility identifier of the percentage element.
  public static let percentIdentifier = "context-usage-percent"

  /// The accessibility identifier of the cost label.
  public static let costIdentifier = "context-usage-cost"

  /// The accessibility identifier of the quota label.
  public static let quotaIdentifier = "context-usage-quota"

  /// The number of fraction digits of the percentage.
  static let percentFractionDigits = 0

  /// The diameter of the ring, in points.
  static let ringDiameter: CGFloat = 16

  /// The line width of the ring, in points.
  static let ringLineWidth: CGFloat = 2

  /// The fraction where the filled arc of the ring starts.
  static let ringEmptyFraction: CGFloat = 0

  /// The rotation that puts the start of the filled arc at the top of the
  /// ring. A trimmed circle starts at the right side.
  static let ringStartAngle = Angle.degrees(-90)

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

  /// The lines of the help tag of the ring.
  ///
  /// - Parameters:
  ///   - usage: The usage.
  ///   - locale: The locale of the number format.
  /// - Returns: The tokens in use of the window size, then one line for the
  ///   input counts and one line for the output counts when the source gives
  ///   them.
  public static func detailLines(for usage: ContextUsage, locale: Locale = .current) -> [String] {
    func count(_ value: Int) -> String {
      value.formatted(.number.locale(locale))
    }
    var lines = [
      String(localized: "\(count(usage.used)) of \(count(usage.size)) tokens")
    ]
    if let input = usage.input {
      lines.append(
        String(localized: "Input: \(count(input.total)) tokens, \(count(input.cached)) cached"))
    }
    if let output = usage.output {
      lines.append(
        String(
          localized: "Output: \(count(output.total)) tokens, \(count(output.reasoning)) reasoning"))
    }
    return lines
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

  /// The text of the quota label.
  ///
  /// - Parameter quota: The quota state.
  /// - Returns: The name of the quota state.
  public static func quotaText(for quota: ContextUsage.Quota) -> String {
    switch quota {
    case .belowLimit(approaching: false): String(localized: "Within quota")
    case .belowLimit(approaching: true): String(localized: "Near quota limit")
    case .limitReached: String(localized: "Quota limit reached")
    }
  }

  // MARK: - Body

  public var body: some View {
    if let usage {
      let percent = Self.percentText(for: usage)
      let details = Self.detailLines(for: usage)
      HStack(spacing: theme.spacing.s) {
        HStack(spacing: theme.spacing.xs) {
          ring(for: usage)
          Text(percent)
            .monospacedDigit()
        }
        .help(details.joined(separator: "\n"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Context used")
        .accessibilityValue(percent)
        .accessibilityHint(details.joined(separator: ", "))
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
        if let quota = usage.quota {
          Label(Self.quotaText(for: quota), systemImage: quotaSymbol(for: quota))
            .foregroundStyle(quotaColor(for: quota))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(Self.quotaIdentifier)
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

  /// The SF Symbol name of a quota state.
  ///
  /// - Parameter quota: The quota state.
  /// - Returns: The symbol name.
  private func quotaSymbol(for quota: ContextUsage.Quota) -> String {
    switch quota {
    case .belowLimit(approaching: false): "gauge.with.dots.needle.33percent"
    case .belowLimit(approaching: true): "gauge.with.dots.needle.67percent"
    case .limitReached: "gauge.with.dots.needle.100percent"
    }
  }

  /// The color of a quota state.
  ///
  /// - Parameter quota: The quota state.
  /// - Returns: The color.
  private func quotaColor(for quota: ContextUsage.Quota) -> Color {
    switch quota {
    case .belowLimit(approaching: false): theme.statusColors.completed
    case .belowLimit(approaching: true): theme.statusColors.running
    case .limitReached: theme.statusColors.failed
    }
  }
}
