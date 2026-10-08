import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The context window use of a session, with its cost (plan.md §3.2
/// "Last-value state").
///
/// The view reads `SessionModel.usage`, the last `usage_update` of the
/// agent, in its body. It keeps no copy of the usage. When `usage` is `nil`,
/// the view is empty. The view shows a ``UsageRingView`` with the tokens in
/// use of the window size. A cost label shows only when the agent sends a
/// cost.
public struct ContextUsageView: View {
  /// The accessibility identifier of the usage element.
  public static let usageIdentifier = "context-usage"

  /// The accessibility identifier of the cost label.
  public static let costIdentifier = "context-usage-cost"

  /// The session model whose usage the view shows.
  let session: SessionModel

  /// The text that shows beside the ring.
  let style: UsageRingView.TextStyle

  @Environment(\.agentTheme) private var theme

  /// The caption of the token counts of the ring.
  private static var tokensCaption: String { String(localized: "tokens") }

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - session: The session model whose usage the view shows.
  ///   - style: The text that shows beside the ring.
  public init(session: SessionModel, style: UsageRingView.TextStyle = .short) {
    self.session = session
    self.style = style
  }

  /// The text of the cost label.
  ///
  /// - Parameters:
  ///   - cost: The cost.
  ///   - locale: The locale of the currency format.
  /// - Returns: The amount in its currency, such as `$1.25`.
  public static func costText(for cost: Cost, locale: Locale = .current) -> String {
    cost.amount.formatted(.currency(code: cost.currency).locale(locale))
  }

  public var body: some View {
    if let usage = session.usage {
      HStack(spacing: theme.spacing.s) {
        UsageRingView(
          numerator: usage.used, denominator: usage.size, caption: Self.tokensCaption, style: style)
        .accessibilityLabel("Context used")
        .accessibilityIdentifier(Self.usageIdentifier)
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
}
