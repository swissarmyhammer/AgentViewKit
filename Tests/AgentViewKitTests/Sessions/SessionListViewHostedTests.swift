import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// The longest time that a test waits for the view, in seconds.
private let waitSeconds: TimeInterval = 2

/// The cursor that the first page gives.
private let secondPageCursor = "page-2"

/// The number of seconds between the test time and the update time of the
/// first session.
private let firstSessionAge: TimeInterval = 3_600

/// The error of a fake source.
private struct FakeFailure: LocalizedError {
  var errorDescription: String? { "The agent is not available." }
}

/// A session source with two pages that records each cursor.
private final class TwoPageProvider: SessionListProvider {
  /// The sessions of the first page.
  static let firstPage = [
    SessionSummary(
      id: SessionID("s1"), title: "Fix the build", cwd: "/work/app",
      updatedAt: Date(timeIntervalSinceNow: -firstSessionAge)),
    SessionSummary(id: SessionID("s2"), title: nil, cwd: "/work/docs"),
  ]

  /// The sessions of the second page.
  static let secondPage = [
    SessionSummary(id: SessionID("s3"), title: "Write the release notes", cwd: "/work/app")
  ]

  /// The cursor of each request, in request order.
  private(set) var cursors: [String?] = []

  /// Whether each request fails.
  var fails = false

  /// Whether the first page is empty and is the last page.
  var empty = false

  func page(after cursor: String?) async throws -> (sessions: [SessionSummary], next: String?) {
    cursors.append(cursor)
    if fails { throw FakeFailure() }
    if empty { return ([], nil) }
    return cursor == nil ? (Self.firstPage, secondPageCursor) : (Self.secondPage, nil)
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct SessionListViewHostedTests {
  /// The size of a list that shows each row.
  static let listSize = CGSize(width: 480, height: 640)

  /// The identifiers of the rows that show.
  private func rowIdentifiers(_ harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(SessionListView.rowIdentifierPrefix)
    }
  }

  /// Mounts a list and waits for the first page.
  private func mount(
    _ view: SessionListView
  ) async -> HostedViewHarness<SessionListView> {
    let harness = HostedViewHarness(view, size: Self.listSize)
    harness.pump()
    await harness.pump(until: waitSeconds) { !rowIdentifiers(harness).isEmpty }
    return harness
  }

  // MARK: - Paging

  @Test func theFirstPageShowsItsRowsAndLoadMore() async {
    let provider = TwoPageProvider()
    let harness = await mount(SessionListView(provider: provider, onSelect: { _ in }))
    defer { harness.close() }

    #expect(
      Set(rowIdentifiers(harness)) == [
        SessionListView.rowIdentifier(for: SessionID("s1")),
        SessionListView.rowIdentifier(for: SessionID("s2")),
      ])
    #expect(harness.element(identifier: SessionListView.loadMoreIdentifier) != nil)
    #expect(provider.cursors == [nil])
  }

  @Test func loadMoreAddsTheSecondPageAndGoesAway() async throws {
    let provider = TwoPageProvider()
    let harness = await mount(SessionListView(provider: provider, onSelect: { _ in }))
    defer { harness.close() }

    try harness.press(identifier: SessionListView.loadMoreIdentifier)
    await harness.pump(until: waitSeconds) { rowIdentifiers(harness).count == 3 }

    #expect(
      Set(rowIdentifiers(harness)) == [
        SessionListView.rowIdentifier(for: SessionID("s1")),
        SessionListView.rowIdentifier(for: SessionID("s2")),
        SessionListView.rowIdentifier(for: SessionID("s3")),
      ])
    #expect(harness.element(identifier: SessionListView.loadMoreIdentifier) == nil)
    #expect(provider.cursors == [nil, secondPageCursor])
  }

  @Test func eachRowShowsTheTitleOrTheUntitledTitle() async {
    let harness = await mount(SessionListView(provider: TwoPageProvider(), onSelect: { _ in }))
    defer { harness.close() }

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains("Fix the build") })
    #expect(labels.contains { $0.contains(SessionListView.untitledTitle) })
  }

  // MARK: - Selection

  @Test func aRowPressCallsOnSelectWithTheID() async throws {
    var selected: [SessionID] = []
    let harness = await mount(
      SessionListView(provider: TwoPageProvider(), onSelect: { selected.append($0) }))
    defer { harness.close() }

    try harness.press(identifier: SessionListView.rowIdentifier(for: SessionID("s2")))

    #expect(selected == [SessionID("s2")])
  }

  // MARK: - Search

  @Test func theSearchTextFiltersTheLoadedRows() async {
    let provider = TwoPageProvider()
    let model = SessionListModel(provider: provider)
    let harness = await mount(SessionListView(model: model, onSelect: { _ in }))
    defer { harness.close() }
    #expect(harness.element(identifier: SessionListView.searchIdentifier) != nil)

    model.query = "BUILD"
    await harness.pump(until: waitSeconds) { rowIdentifiers(harness).count == 1 }

    #expect(rowIdentifiers(harness) == [SessionListView.rowIdentifier(for: SessionID("s1"))])
    #expect(provider.cursors == [nil])
  }

  @Test func theSearchTextMatchesTheDirectory() {
    let session = TwoPageProvider.firstPage[1]
    #expect(session.matches("docs"))
    #expect(session.matches("  "))
    #expect(!session.matches("build"))
  }

  // MARK: - Actions

  @Test func theNewSessionButtonCallsTheAction() async throws {
    var count = 0
    let harness = await mount(
      SessionListView(provider: TwoPageProvider(), onSelect: { _ in }, onNewSession: { count += 1 }))
    defer { harness.close() }

    try harness.press(identifier: SessionListView.newSessionIdentifier)

    #expect(count == 1)
  }

  @Test func aListWithNoActionsShowsNoActionButtons() async {
    let harness = await mount(SessionListView(provider: TwoPageProvider(), onSelect: { _ in }))
    defer { harness.close() }

    #expect(harness.element(identifier: SessionListView.newSessionIdentifier) == nil)
    #expect(harness.element(identifier: SessionListView.deleteIdentifier(for: SessionID("s1"))) == nil)
  }

  @Test func aDeleteCallsTheActionAndRemovesTheRow() async throws {
    var deleted: [SessionID] = []
    let harness = await mount(
      SessionListView(
        provider: TwoPageProvider(), onSelect: { _ in }, onDelete: { deleted.append($0) }))
    defer { harness.close() }

    try harness.press(identifier: SessionListView.deleteIdentifier(for: SessionID("s1")))
    await harness.pump(until: waitSeconds) { rowIdentifiers(harness).count == 1 }

    #expect(deleted == [SessionID("s1")])
    #expect(rowIdentifiers(harness) == [SessionListView.rowIdentifier(for: SessionID("s2"))])
  }

  @Test func aFailedDeleteKeepsTheRowAndShowsTheMessage() async throws {
    let harness = await mount(
      SessionListView(
        provider: TwoPageProvider(), onSelect: { _ in }, onDelete: { _ in throw FakeFailure() }))
    defer { harness.close() }

    try harness.press(identifier: SessionListView.deleteIdentifier(for: SessionID("s1")))
    await harness.pump(until: waitSeconds) {
      harness.element(identifier: SessionListView.failureIdentifier) != nil
    }

    #expect(
      harness.element(identifier: SessionListView.failureIdentifier)?.label
        == FakeFailure().errorDescription)
    #expect(rowIdentifiers(harness).count == 2)
  }

  // MARK: - States

  @Test func aSourceWithNoSessionsShowsTheEmptyState() async {
    let provider = TwoPageProvider()
    provider.empty = true
    let harness = HostedViewHarness(
      SessionListView(provider: provider, onSelect: { _ in }), size: Self.listSize)
    defer { harness.close() }

    await harness.pump(until: waitSeconds) {
      harness.element(identifier: SessionListView.emptyIdentifier) != nil
    }

    #expect(harness.element(identifier: SessionListView.emptyIdentifier) != nil)
    #expect(harness.element(identifier: SessionListView.loadMoreIdentifier) == nil)
  }

  @Test func aFailedFirstPageShowsTheMessage() async {
    let provider = TwoPageProvider()
    provider.fails = true
    let harness = HostedViewHarness(
      SessionListView(provider: provider, onSelect: { _ in }), size: Self.listSize)
    defer { harness.close() }

    await harness.pump(until: waitSeconds) {
      harness.element(identifier: SessionListView.failureIdentifier) != nil
    }

    #expect(harness.element(identifier: SessionListView.failureIdentifier) != nil)
    #expect(rowIdentifiers(harness).isEmpty)
  }

  // MARK: - Model

  @Test func reloadGetsTheFirstPageAgain() async {
    let provider = TwoPageProvider()
    let model = SessionListModel(provider: provider)

    await model.loadFirstPage()
    await model.loadMore()
    await model.loadMore()
    await model.reload()

    #expect(provider.cursors == [nil, secondPageCursor, nil])
    #expect(model.sessions == TwoPageProvider.firstPage)
    #expect(model.hasMore)
  }

  @Test func loadFirstPageRunsOnce() async {
    let provider = TwoPageProvider()
    let model = SessionListModel(provider: provider)

    await model.loadFirstPage()
    await model.loadFirstPage()

    #expect(provider.cursors == [nil])
    #expect(model.failureMessage == nil)
  }
}
