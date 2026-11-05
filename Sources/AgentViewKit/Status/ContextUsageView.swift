import EditorStyle
import EditorSwiftUI
import EditorTheme
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

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.locale) private var locale
  @Environment(\.placedSecondary) private var placedSecondary

  /// The caption of the token counts of the ring.
  private static var tokensCaption: String { String(localized: "tokens", bundle: .module) }

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - session: The session model whose usage the view shows.
  ///   - style: The text that shows beside the ring.
  public init(session: SessionModel, style: UsageRingView.TextStyle = .short) {
    self.session = session
    self.style = style
  }

  /// The length of an ISO 4217 currency code.
  private static let currencyCodeLength = 3

  /// The text of the cost label.
  ///
  /// - Parameters:
  ///   - cost: The cost.
  ///   - locale: The locale of the number and the currency formats.
  /// - Returns: The amount in its currency, such as `$1.25`. A unit that is not
  ///   a currency code gives the amount and the unit, such as `12 credits`.
  public static func costText(for cost: Cost, locale: Locale = .current) -> String {
    let isCurrencyCode = cost.currency.count == Self.currencyCodeLength && cost.currency.allSatisfy { $0.isASCII && $0.isUppercase }
    guard isCurrencyCode else {
      return String(
        localized: "context-usage.cost-in-unit",
        defaultValue: "\(cost.amount, format: .number.locale(locale)) \(cost.currency)", bundle: .module,
        locale: locale, comment: "The cost of a session in a unit that is not a currency: the amount, then the unit.")
    }
    return cost.amount.formatted(.currency(code: cost.currency).locale(locale))
  }

  public var body: some View {
    if let usage = session.usage {
      HStack(spacing: editorStyle.spacing.s) {
        UsageRingView(
          numerator: usage.used, denominator: usage.size, caption: Self.tokensCaption, style: style)
        .accessibilityLabel(String(localized: "Context used", bundle: .module))
        .accessibilityIdentifier(Self.usageIdentifier)
        if case .value(let cost) = usage.cost {
          Text(Self.costText(for: cost, locale: locale))
            .monospacedDigit()
            .foregroundStyle(placedSecondary)
            .accessibilityIdentifier(Self.costIdentifier)
        }
      }
      .font(editorTheme.font(for: .ui, style: .caption))
    }
  }
}

#Preview("Context usage") {
  ContextUsageView(session: PreviewFixtures.usageSession)
}
