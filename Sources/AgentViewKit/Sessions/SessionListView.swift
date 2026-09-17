import SwiftUI

/// The list of the sessions of an agent, with cursor paging (plan.md §9 A).
///
/// The view gets the first page from the provider when it shows. Each row
/// shows the title and the relative time of the last activity. A press on a
/// row calls `onSelect` with the session id. When the provider has a next
/// page, the last row is a "Load More" button that gets that page. The
/// search field filters the loaded rows only.
///
/// The host gives the new session action and the delete action as closures.
/// When the host gives no closure, the view shows no button for the action.
/// A delete that does not throw removes the row. A delete that throws shows
/// the error message.
public struct SessionListView: View {
  /// The accessibility identifier of the search field.
  public static let searchIdentifier = "session-list-search"

  /// The accessibility identifier of the "Load More" row.
  public static let loadMoreIdentifier = "session-list-load-more"

  /// The accessibility identifier of the new session button.
  public static let newSessionIdentifier = "session-list-new"

  /// The accessibility identifier of the failure message.
  public static let failureIdentifier = "session-list-failure"

  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "session-list-empty"

  /// The text before the session id in the identifier of a row.
  public static let rowIdentifierPrefix = "session-row-"

  /// The text before the session id in the identifier of a delete button.
  public static let deleteIdentifierPrefix = "session-delete-"

  /// The title of a session that has no title.
  public static let untitledTitle = "Untitled Session"

  /// The space between the title and the time of a row, in points.
  static let rowLineSpacing: CGFloat = 2

  /// The space between the header, the failure message, and the list, in
  /// points.
  static let sectionSpacing: CGFloat = 0

  /// The accessibility identifier of the row of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The identifier, such as `session-row-s1`.
  public static func rowIdentifier(for id: SessionID) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the delete button of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The identifier, such as `session-delete-s1`.
  public static func deleteIdentifier(for id: SessionID) -> String {
    AccessibilityIdentifier.make(prefix: deleteIdentifierPrefix, value: id.rawValue)
  }

  /// The theme that gives the color of the failure message.
  @Environment(\.agentTheme) private var theme

  /// The pages and the search text.
  @State private var model: SessionListModel

  /// The action for a press on a row.
  private let onSelect: (SessionID) -> Void

  /// The new session action, or `nil`.
  private let onNewSession: (() -> Void)?

  /// The delete action, or `nil`.
  private let onDelete: ((SessionID) async throws -> Void)?

  /// Makes a list that gets its pages from `provider`.
  ///
  /// - Parameters:
  ///   - provider: The provider that gives the pages.
  ///   - onSelect: The action for a press on a row.
  ///   - onNewSession: The new session action, or `nil` for no button.
  ///   - onDelete: The delete action, such as an ACP `session/delete`
  ///     request, or `nil` for no button.
  public init(
    provider: any SessionListProvider,
    onSelect: @escaping (SessionID) -> Void,
    onNewSession: (() -> Void)? = nil,
    onDelete: ((SessionID) async throws -> Void)? = nil
  ) {
    self.init(
      model: SessionListModel(provider: provider), onSelect: onSelect,
      onNewSession: onNewSession, onDelete: onDelete)
  }

  /// Makes a list that shows `model`.
  ///
  /// Use this form when the host reads or sets the search text, or loads the
  /// pages again.
  ///
  /// - Parameters:
  ///   - model: The pages and the search text.
  ///   - onSelect: The action for a press on a row.
  ///   - onNewSession: The new session action, or `nil` for no button.
  ///   - onDelete: The delete action, or `nil` for no button.
  public init(
    model: SessionListModel,
    onSelect: @escaping (SessionID) -> Void,
    onNewSession: (() -> Void)? = nil,
    onDelete: ((SessionID) async throws -> Void)? = nil
  ) {
    _model = State(initialValue: model)
    self.onSelect = onSelect
    self.onNewSession = onNewSession
    self.onDelete = onDelete
  }

  public var body: some View {
    VStack(spacing: Self.sectionSpacing) {
      header
      if let message = model.failureMessage {
        Text(message)
          .font(.caption)
          .foregroundStyle(theme.statusColors.failed)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .accessibilityIdentifier(Self.failureIdentifier)
      }
      if model.hasLoadedFirstPage, model.sessions.isEmpty {
        ContentUnavailableView(
          "No Sessions",
          systemImage: "bubble.left.and.bubble.right",
          description: Text("The sessions of the agent show here.")
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Self.emptyIdentifier)
      } else {
        list
      }
    }
    .task { await model.loadFirstPage() }
  }

  /// The search field and the new session button.
  private var header: some View {
    HStack {
      TextField("Search", text: $model.query)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier(Self.searchIdentifier)
      if let onNewSession {
        Button(action: onNewSession) {
          Label("New Session", systemImage: "square.and.pencil")
            .labelStyle(.iconOnly)
        }
        .help("New Session")
        .accessibilityIdentifier(Self.newSessionIdentifier)
      }
    }
    .padding()
  }

  /// The rows and the "Load More" row.
  private var list: some View {
    List {
      ForEach(model.filteredSessions) { session in
        row(for: session)
      }
      if model.hasMore {
        Button("Load More") {
          Task { await model.loadMore() }
        }
        .disabled(model.isLoading)
        .accessibilityIdentifier(Self.loadMoreIdentifier)
      }
    }
  }

  /// The row of one session.
  ///
  /// - Parameter session: The session to show.
  /// - Returns: The select button and, when the host gives a delete action,
  ///   the delete button.
  private func row(for session: SessionSummary) -> some View {
    HStack {
      Button {
        onSelect(session.id)
      } label: {
        VStack(alignment: .leading, spacing: Self.rowLineSpacing) {
          Text(session.title ?? Self.untitledTitle)
            .lineLimit(1)
          if let updatedAt = session.updatedAt {
            Text(updatedAt, format: .relative(presentation: .named))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(Self.rowIdentifier(for: session.id))
      if let onDelete {
        Button(role: .destructive) {
          delete(session.id, with: onDelete)
        } label: {
          Label("Delete", systemImage: "trash")
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .help("Delete")
        .accessibilityIdentifier(Self.deleteIdentifier(for: session.id))
      }
    }
  }

  /// Runs the delete action, then removes the row or shows the failure.
  ///
  /// - Parameters:
  ///   - id: The identifier of the session to delete.
  ///   - action: The delete action of the host.
  private func delete(_ id: SessionID, with action: @escaping (SessionID) async throws -> Void) {
    let model = model
    Task {
      do {
        try await action(id)
        model.remove(id)
      } catch {
        model.failureMessage = error.localizedDescription
      }
    }
  }
}
