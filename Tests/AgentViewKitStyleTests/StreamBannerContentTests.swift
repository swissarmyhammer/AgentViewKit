import AgentViewKitStyle
import SwiftUI
import Testing

/// Checks the pure mapping from the state of a stream and a reload to what a
/// banner tells.
@Suite @MainActor struct StreamBannerContentTests {
  /// The explanation that the kit gives for missed updates.
  static let missed = "The board can lack changes."

  /// The error of the tests.
  static let error = "The server went away"

  /// Makes the content of `stream` and `phase`, with the explanations of the
  /// kit.
  ///
  /// - Parameters:
  ///   - stream: The state of the stream.
  ///   - phase: The state of the reload.
  /// - Returns: The content, or `nil` for no banner.
  static func content(_ stream: StreamBannerContent.Stream, _ phase: ReloadPhase = .idle) -> StreamBannerContent? {
    StreamBannerContent(
      stream: stream, reloadPhase: phase, missedUpdatesExplanation: missed,
      streamErrorExplanation: { "Lost: \($0)" })
  }

  @Test func aCurrentStreamShowsNoBanner() {
    #expect(Self.content(.current) == nil)
  }

  @Test func aFailedReloadOfACurrentStreamShowsNoBanner() {
    #expect(Self.content(.current, .failed(Self.error)) == nil)
  }

  @Test func aCleanEndIsAWarning() throws {
    let content = try #require(Self.content(.endedClean))

    #expect(content.kind == .missedUpdates)
    #expect(content.title == "Updates are missing")
    #expect(content.explanation == Self.missed)
    #expect(content.severity == .warning)
    #expect(content.symbolName == SharedSymbol.warning)
  }

  @Test func anEndWithAnErrorIsAFailure() throws {
    let content = try #require(Self.content(.endedWithError(Self.error)))

    #expect(content.kind == .streamFailed)
    #expect(content.title == "The updates stopped with an error")
    #expect(content.explanation == "Lost: \(Self.error)")
    #expect(content.severity == .failure)
    #expect(content.symbolName == SharedSymbol.error)
  }

  @Test func aFailedReloadIsAFailure() throws {
    let content = try #require(Self.content(.endedClean, .failed(Self.error)))

    #expect(content.kind == .reloadFailed)
    #expect(content.title == "Updates are still missing")
    #expect(content.explanation == "The reload failed: \(Self.error)")
    #expect(content.severity == .failure)
    #expect(content.symbolName == SharedSymbol.error)
  }

  @Test func aFailedReloadWinsOverTheErrorOfTheStream() throws {
    let content = try #require(Self.content(.endedWithError("Other"), .failed(Self.error)))

    #expect(content.kind == .reloadFailed)
  }

  @Test func aReloadThatRunsKeepsTheTextOfTheStream() {
    #expect(Self.content(.endedClean, .reloading) == Self.content(.endedClean))
  }

  @Test func theMessageCarriesTheContentAndTheIdentifier() throws {
    let content = try #require(Self.content(.endedClean))

    let message = content.message(identifier: "banner-text")

    #expect(
      message
        == StatusBar.Message(
          title: content.title, explanation: content.explanation, symbolName: content.symbolName,
          identifier: "banner-text", severity: content.severity))
  }
}

/// Checks the phase of a reload, with no view.
@Suite @MainActor struct ReloadPhaseTests {
  /// The error of a reload that fails.
  struct ReloadFailure: Error {}

  @Test func anIdlePhaseCanReload() {
    #expect(ReloadPhase.idle.canReload(isLoading: false))
  }

  @Test func aFailedPhaseCanReload() {
    #expect(ReloadPhase.failed("x").canReload(isLoading: false))
  }

  @Test func aReloadThatRunsCannotReload() {
    #expect(!ReloadPhase.reloading.canReload(isLoading: false))
  }

  @Test func aLoadingModelCannotReload() {
    #expect(!ReloadPhase.idle.canReload(isLoading: true))
  }

  @Test func aReloadThatEndsGoesBackToIdle() async {
    let outcome = await ReloadPhase.outcome {}

    #expect(outcome == .idle)
  }

  @Test func aReloadThatThrowsFailsWithTheDescriptionOfItsError() async {
    let outcome = await ReloadPhase.outcome { throw ReloadFailure() }

    #expect(outcome == .failed(ReloadFailure().localizedDescription))
  }

  @Test func aCancelledReloadIsNoFailure() async {
    let outcome = await ReloadPhase.outcome { throw CancellationError() }

    #expect(outcome == .idle)
  }
}

/// Checks the Reload button of a bar.
@Suite @MainActor struct StatusBarReloadTests {
  @Test func theReloadActionHasTheReloadSymbol() {
    #expect(StatusBar.Action.reload(identifier: "r", isEnabled: true) {}.systemImage == SharedSymbol.reload)
  }

  @Test func theReloadActionHasOneTitle() {
    #expect(StatusBar.Action.reload(identifier: "r", isEnabled: true) {}.title == "Reload")
  }

  @Test func theReloadActionHasAHint() {
    #expect(StatusBar.Action.reload(identifier: "r", isEnabled: true) {}.hint?.isEmpty == false)
  }

  @Test func theReloadActionKeepsItsIdentifier() {
    #expect(StatusBar.Action.reload(identifier: "r", isEnabled: true) {}.identifier == "r")
  }

  @Test func theReloadActionIsOffWhenTheHostSaysSo() {
    #expect(!StatusBar.Action.reload(identifier: "r", isEnabled: false) {}.isEnabled)
  }

  @Test func aThrownErrorLandsInThePhaseOfTheHost() {
    var phase = ReloadPhase.idle
    let binding = Binding(get: { phase }, set: { phase = $0 })
    let action = StatusBar.Action.reload(identifier: "r", isEnabled: true, phase: binding) {
      throw ReloadPhaseTests.ReloadFailure()
    }

    action.perform()

    #expect(phase == .failed(ReloadPhaseTests.ReloadFailure().localizedDescription))
  }

  @Test func aReloadThatSuspendsIsInItsPhaseUntilItEnds() async {
    var phase = ReloadPhase.idle
    let binding = Binding(get: { phase }, set: { phase = $0 })
    let (gate, opening) = AsyncStream.makeStream(of: Void.self)
    let action = StatusBar.Action.reload(identifier: "r", isEnabled: true, phase: binding) {
      for await _ in gate {}
    }

    action.perform()

    #expect(phase == .reloading)
    opening.finish()
    while phase == .reloading { await Task.yield() }
    #expect(phase == .idle)
  }

  @Test func aPressRunsTheClosureUpToItsFirstSuspensionInTheSameStep() {
    var started = false
    let action = StatusBar.Action.reload(identifier: "r", isEnabled: true) { started = true }

    action.perform()

    #expect(started)
  }
}
