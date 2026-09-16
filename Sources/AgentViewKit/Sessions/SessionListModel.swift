import Foundation
import Observation

/// The loaded pages of a ``SessionListView`` (plan.md §9 A).
///
/// The model gets the pages from a ``SessionListProvider``. It keeps the
/// sessions of each loaded page in page order, the cursor of the next page,
/// and the search text that filters the loaded sessions. The search does not
/// get pages from the provider.
@Observable
public final class SessionListModel {
  /// The provider that gives the pages.
  @ObservationIgnored public let provider: any SessionListProvider

  /// The sessions of each loaded page, in page order.
  public private(set) var sessions: [SessionSummary] = []

  /// The cursor of the next page, or `nil` when there is no next page or no
  /// page is loaded.
  public private(set) var nextCursor: String?

  /// Whether the first page is loaded.
  public private(set) var hasLoadedFirstPage = false

  /// Whether a page request is in progress.
  public private(set) var isLoading = false

  /// The message of the last failure, or `nil`.
  public var failureMessage: String?

  /// The search text that filters the loaded sessions.
  public var query = ""

  /// Makes a model with no loaded page.
  ///
  /// - Parameter provider: The provider that gives the pages.
  public init(provider: any SessionListProvider) {
    self.provider = provider
  }

  /// The loaded sessions that match ``query``.
  public var filteredSessions: [SessionSummary] {
    sessions.filter { $0.matches(query) }
  }

  /// Whether the provider has a next page.
  public var hasMore: Bool {
    hasLoadedFirstPage && nextCursor != nil
  }

  /// Gets the first page, when no page is loaded.
  public func loadFirstPage() async {
    guard !hasLoadedFirstPage else { return }
    await load(after: nil)
  }

  /// Gets the next page and adds its sessions after the loaded sessions.
  ///
  /// The function does nothing when there is no next page.
  public func loadMore() async {
    guard hasMore, let nextCursor else { return }
    await load(after: nextCursor)
  }

  /// Removes the loaded pages and gets the first page again.
  public func reload() async {
    guard !isLoading else { return }
    sessions = []
    nextCursor = nil
    hasLoadedFirstPage = false
    await load(after: nil)
  }

  /// Removes one session from the loaded sessions.
  ///
  /// - Parameter id: The identifier of the session to remove.
  public func remove(_ id: SessionID) {
    sessions.removeAll { $0.id == id }
  }

  /// Gets the page after `cursor` and adds its sessions.
  ///
  /// A request that starts while a request is in progress does nothing.
  /// A session that is already loaded is not added again.
  ///
  /// - Parameter cursor: The cursor of the page, or `nil` for the first page.
  private func load(after cursor: String?) async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await provider.page(after: cursor)
      let known = Set(sessions.map(\.id))
      sessions.append(contentsOf: page.sessions.filter { !known.contains($0.id) })
      nextCursor = page.next
      hasLoadedFirstPage = true
      failureMessage = nil
    } catch {
      failureMessage = error.localizedDescription
    }
  }
}
