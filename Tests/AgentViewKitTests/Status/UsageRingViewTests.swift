import FoundationModelsACP
import Foundation
import Testing

@testable import AgentViewKit

/// The texts of ``UsageRingView`` and of the cost label of
/// ``ContextUsageView``.
@Suite @MainActor struct UsageRingViewTests {
  /// The locale of the text checks, so that the numbers do not change with
  /// the locale of the test machine.
  static let locale = Locale(identifier: "en_US")

  /// The caption of the token counts.
  static let tokensCaption = "tokens"

  @Test func thePercentTextRoundsThePartInUse() {
    #expect(UsageRingView.percentText(numerator: 1200, denominator: 4000, locale: Self.locale) == "30%")
    #expect(UsageRingView.percentText(numerator: 500, denominator: 1000, locale: Self.locale) == "50%")
  }

  @Test func thePercentTextStopsAtOneHundredPercent() {
    #expect(UsageRingView.percentText(numerator: 1500, denominator: 1000, locale: Self.locale) == "100%")
  }

  @Test func thePercentTextOfAnEmptyWholeOrANegativePartIsZero() {
    #expect(UsageRingView.percentText(numerator: 10, denominator: 0, locale: Self.locale) == "0%")
    #expect(UsageRingView.percentText(numerator: -10, denominator: 1000, locale: Self.locale) == "0%")
  }

  @Test func theDetailTextGivesThePartOfTheWholeWithTheCaption() {
    #expect(
      UsageRingView.detailText(
        numerator: 1200, denominator: 4000, caption: Self.tokensCaption, locale: Self.locale)
        == "1,200 of 4,000 tokens")
  }

  @Test func aRingThatIsNotFullShowsTheUsageSymbol() {
    #expect(UsageRingView.symbolName(numerator: 1200, denominator: 4000) == AgentSymbol.usage)
    #expect(UsageRingView.symbolName(numerator: 10, denominator: 0) == AgentSymbol.usage)
  }

  @Test func aFullRingShowsTheFullSymbol() {
    #expect(UsageRingView.symbolName(numerator: 4000, denominator: 4000) == AgentSymbol.usageFull)
    #expect(UsageRingView.symbolName(numerator: 5000, denominator: 4000) == AgentSymbol.usageFull)
  }

  @Test func theCostTextUsesTheCurrency() {
    #expect(
      ContextUsageView.costText(for: Cost(amount: 1.25, currency: "USD"), locale: Self.locale) == "$1.25")
  }

  @Test func theCostTextOfAUnitThatIsNotACurrencyHasTheAmountAndThenTheUnit() {
    #expect(
      ContextUsageView.costText(for: Cost(amount: 1200.5, currency: "credits"), locale: Self.locale)
        == "1,200.5 credits")
  }
}
