import FoundationModelsACPClient
import SwiftUI

/// The fixed values and the pure functions of ``ConversationView``.
///
/// A generic view type cannot hold a stored static property, so the values
/// are in this separate type.
public enum ConversationLayout {
  /// The accessibility identifier of the list of rows.
  public static let listIdentifier = "conversation-list"

  /// The accessibility identifier of the row that shows the earlier page.
  public static let loadEarlierIdentifier = "load-earlier-row"

  /// The accessibility identifier of the default empty state.
  public static let emptyStateIdentifier = "conversation-empty-state"

  /// The default number of items on one page.
  public static let defaultPageSize = 200

  /// The smallest part of a row that must be in view before the list tells
  /// the ``ScrollAnchorManager`` that the row is visible.
  static let visibilityThreshold = 0.01

  /// The SF Symbol name of the load-earlier row.
  static let loadEarlierSymbolName = "arrow.up"

  /// The number of items that the list shows.
  ///
  /// - Parameters:
  ///   - count: The number of items in the thread.
  ///   - pageSize: The number of items on one page. A value less than one
  ///     counts as one.
  ///   - pageCount: The number of pages that the list shows. A value less
  ///     than one counts as one.
  /// - Returns: The number of the last items that the list shows, at most
  ///   `count`.
  public static func shownCount(count: Int, pageSize: Int, pageCount: Int) -> Int {
    let (limit, overflow) = max(pageSize, 1).multipliedReportingOverflow(by: max(pageCount, 1))
    return overflow ? max(count, 0) : min(max(count, 0), limit)
  }

  /// The number of pages that the list must show so that the item at
  /// `position` is in the list.
  ///
  /// - Parameters:
  ///   - position: The position of the item in the thread.
  ///   - count: The number of items in the thread.
  ///   - pageSize: The number of items on one page. A value less than one
  ///     counts as one.
  /// - Returns: The smallest page count that shows the item, at least one.
  public static func pageCount(toShow position: Int, count: Int, pageSize: Int) -> Int {
    let fromEnd = max(count - max(position, 0), 1)
    let size = max(pageSize, 1)
    return (fromEnd + size - 1) / size
  }

  /// The accessibility value of the list.
  ///
  /// - Parameters:
  ///   - shown: The number of items that the list shows.
  ///   - count: The number of items in the thread.
  /// - Returns: "N of M items".
  public static func listValue(shown: Int, count: Int) -> String {
    String(localized: "\(shown) of \(count) items")
  }

  /// The identifier of the newest error item that relates to the state of
  /// the thread.
  ///
  /// | State | Related error kinds |
  /// |-------|---------------------|
  /// | `idle(.refusal)` | `refusal` |
  /// | Each other state | None |
  ///
  /// - Parameters:
  ///   - items: The items of the thread, in order.
  ///   - state: The run state of the thread.
  /// - Returns: The identifier of the last related ``ThreadError`` in
  ///   `items`, or `nil` when there is none.
  public static func relatedErrorID(in items: [ThreadItem], state: ThreadState) -> String? {
    guard let matches = errorMatcher(for: state) else { return nil }
    for item in items.reversed() {
      if case .error(let error) = item, matches(error.kind) {
        return error.id
      }
    }
    return nil
  }

  /// The test that tells if an error kind relates to `state`.
  ///
  /// - Parameter state: The run state of the thread.
  /// - Returns: The test, or `nil` when no error kind relates to `state`.
  private static func errorMatcher(for state: ThreadState) -> ((ThreadError.Kind) -> Bool)? {
    switch state {
    case .idle(.refusal):
      { kind in
        if case .refusal = kind { return true }
        return false
      }
    default:
      nil
    }
  }
}

extension EnvironmentValues {
  /// The number of items on one page of a ``ConversationView``.
  ///
  /// Set the value with ``SwiftUI/View/conversationPageSize(_:)``.
  @Entry public var conversationPageSize = ConversationLayout.defaultPageSize
}

extension View {
  /// Sets the number of items on one page of each ``ConversationView`` in
  /// this subtree.
  ///
  /// The conversation shows the last page, and a row at the top that shows
  /// the page before it.
  ///
  /// - Parameter pageSize: The number of items on one page. A value less
  ///   than one counts as one.
  /// - Returns: A view that gives the page size to its subtree.
  public func conversationPageSize(_ pageSize: Int) -> some View {
    environment(\.conversationPageSize, pageSize)
  }
}

/// The scrolled list of the items of a thread (plan.md §8, §9 A).
///
/// The view shows one ``ItemRow`` for each item in a lazy stack. It starts at
/// the bottom, and it follows new items while the user reads the end. The
/// view reports the rows in view to a ``ScrollAnchorManager``:
///
/// - While the manager is pinned to the bottom, each new item scrolls the
///   list to the end.
/// - While the manager is not pinned, a ``ScrollToBottomPill`` shows the
///   number of new items. A tap on the pill pins the list and scrolls to the
///   end.
///
/// The view shows only the last page of items, and a "Load Earlier" row at
/// the top that shows one more page. Set the page size with
/// ``SwiftUI/View/conversationPageSize(_:)``.
///
/// When the thread has no item, the view shows the `emptyState` slot.
///
/// Below the list, a ``StateBanner`` tells when the thread needs attention.
/// Its Show Error button scrolls to the newest related error, as
/// ``ConversationLayout/relatedErrorID(in:state:)`` finds it. The error
/// cards read their buttons from ``SwiftUI/EnvironmentValues/errorActions``,
/// so apply ``SwiftUI/View/errorActions(_:)`` to this view or to a view
/// above it.
///
/// The view sets ``ScrollAnchorManager/onScroll`` of the manager, so that a
/// ``ThreadMinimapView`` with no proxy can scroll the list.
///
/// The view also shows the transcript of a `SessionModel` (update.md §4.2,
/// §4.7). A `ForEach` keyed on `TranscriptEntry.id` makes one ``ItemRow`` for
/// each entry, so a row keeps its identity when a pending user message gets
/// its `messageId`. The scroll anchors use the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of each entry.
/// Below the list, ``StateBanner/init(session:onShowError:)`` shows the
/// `agentState` of the model. Its Show Error button scrolls to the last
/// `ErrorEntry` of the transcript.
public struct ConversationView<EmptyState: View>: View {
  /// The model to show.
  let source: ConversationSource

  /// The manager that the host gave, or `nil`.
  let hostAnchors: ScrollAnchorManager?

  /// The view that shows when the thread has no item.
  let emptyState: EmptyState

  /// The manager that the view makes when the host gives none.
  @State private var ownAnchors = ScrollAnchorManager()

  /// The number of pages that the list shows.
  @State private var pageCount = 1

  /// The scroll position of the list.
  @State private var position = ScrollPosition(idType: String.self)

  /// Whether the end of the list was in the tolerance of the manager at the
  /// last scroll geometry change.
  ///
  /// The list reads the value when only the rows in view change. SwiftUI
  /// can report the rows in view before the new geometry. Then the next
  /// geometry change corrects the pin state.
  @State private var isNearBottom = true

  @Environment(\.conversationPageSize) private var pageSize
  @Environment(\.agentTheme) private var theme

  /// Makes the list of a thread with a custom empty state.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - anchors: The manager that keeps the scroll position. With `nil`,
  ///     the view makes its own manager.
  ///   - emptyState: The view that shows when the thread has no item.
  public init(
    thread: AgentThread,
    anchors: ScrollAnchorManager? = nil,
    @ViewBuilder emptyState: () -> EmptyState
  ) {
    self.source = .thread(thread)
    self.hostAnchors = anchors
    self.emptyState = emptyState()
  }

  /// Makes the list of the transcript of a session model with a custom empty
  /// state.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - anchors: The manager that keeps the scroll position. With `nil`,
  ///     the view makes its own manager.
  ///   - emptyState: The view that shows when the transcript has no entry.
  public init(
    session: SessionModel,
    anchors: ScrollAnchorManager? = nil,
    @ViewBuilder emptyState: () -> EmptyState
  ) {
    self.source = .session(session)
    self.hostAnchors = anchors
    self.emptyState = emptyState()
  }

  /// The manager that the view uses.
  private var anchors: ScrollAnchorManager {
    hostAnchors ?? ownAnchors
  }

  public var body: some View {
    VStack(spacing: 0) {
      if source.rowCount == 0 {
        emptyState
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        list
      }
      if let thread = source.thread {
        ConversationBanner(thread: thread, onShowError: showItem)
      }
      if let session = source.session {
        // The banner reads `agentState` in its own body, so a change of the
        // state evaluates only the banner and not the list.
        StateBanner(session: session) { showItem($0.rowKey) }
          .padding(theme.spacing.m)
      }
    }
    .environment(\.agentThread, source.thread)
    .environment(\.sessionModel, source.session)
    .onChange(of: source.lastRowKey) { old, new in
      noteLastItem(old: old, new: new)
    }
    .onChange(of: pageCount) {
      anchors.restoreAnchor()
    }
  }

  // MARK: - List

  /// The scrolled list of the last pages of the rows. The source has at
  /// least one row.
  private var list: some View {
    let count = source.rowCount
    let shownCount = ConversationLayout.shownCount(
      count: count, pageSize: pageSize, pageCount: pageCount)
    let anchors = anchors
    return ScrollView {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        if shownCount < count {
          loadEarlierRow
        }
        LazyVStack(alignment: .leading, spacing: theme.spacing.m) {
          rows(shownCount: shownCount)
        }
        .scrollTargetLayout()
      }
      .padding(theme.rowPadding)
      .lazyResponseParagraphs()
    }
    .accessibilityLabel(Text("Conversation"))
    .accessibilityValue(
      Text(ConversationLayout.listValue(shown: shownCount, count: count))
    )
    .accessibilityIdentifier(ConversationLayout.listIdentifier)
    .defaultScrollAnchor(.bottom, for: .initialOffset)
    .defaultScrollAnchor(.bottom, for: .alignment)
    .modifier(ConversationFollowAnchor(anchors: anchors))
    .scrollPosition($position)
    .onScrollTargetVisibilityChange(
      idType: String.self, threshold: ConversationLayout.visibilityThreshold
    ) { ids in
      noteVisible(ids: ids, isNearBottom: nil)
    }
    .onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentSize.height - geometry.visibleRect.maxY <= anchors.tolerance
    } action: { _, isNearBottom in
      noteVisible(ids: anchors.visibleIDs, isNearBottom: isNearBottom)
    }
    .overlay(alignment: .bottom) {
      ConversationPill(anchors: anchors)
        .padding(theme.spacing.m)
    }
    .onAppear {
      anchors.onScroll = { target in scroll(to: target) }
      anchors.noteLastItemChanged(to: source.lastRowKey)
    }
    .accessibilityReadingScope()
  }

  /// The rows of the last `shownCount` items or entries.
  ///
  /// - Parameter shownCount: The number of rows that the list shows.
  /// - Returns: One row for each shown item or entry.
  @ViewBuilder private func rows(shownCount: Int) -> some View {
    switch source {
    case .thread(let thread):
      threadRows(thread, shownCount: shownCount)
    case .session(let session):
      // The row identity is `TranscriptEntry.id` (update.md §4.7). The
      // scroll target of each row is its text key, because the scroll
      // anchors use text.
      ForEach(session.transcript.suffix(shownCount), id: \.id) { entry in
        readingRow(ItemRow(entry: entry))
          .id(entry.rowKey)
      }
    }
  }

  /// The rows of the last `shownCount` items of a thread.
  ///
  /// - Parameters:
  ///   - thread: The thread.
  ///   - shownCount: The number of rows that the list shows.
  /// - Returns: One row for each shown item.
  private func threadRows(_ thread: AgentThread, shownCount: Int) -> some View {
    ForEach(thread.items.suffix(shownCount), id: \.id) { item in
      readingRow(ItemRow(item: item))
    }
  }

  /// One row, in the linked reading group of the thread.
  ///
  /// VoiceOver reads from one row into the next row
  /// (``ThreadAccessibility/threadGroupID``).
  ///
  /// - Parameter row: The row of an item or of an entry.
  /// - Returns: The row.
  private func readingRow(_ row: ItemRow) -> some View {
    row
      .equatable()
      .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
  }

  /// The row at the top of the list that shows one more page.
  private var loadEarlierRow: some View {
    Button(action: showEarlierPage) {
      Label("Load Earlier", systemImage: ConversationLayout.loadEarlierSymbolName)
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glass)
    .frame(maxWidth: .infinity)
    .accessibilityAddTraits(.causesPageTurn)
    .accessibilityScrollAction { edge in
      if edge == .top {
        showEarlierPage()
      }
    }
    .accessibilityIdentifier(ConversationLayout.loadEarlierIdentifier)
  }

  // MARK: - Actions

  /// Shows one more page, and keeps the first visible row in view.
  private func showEarlierPage() {
    anchors.saveAnchor()
    pageCount += 1
  }

  /// Shows the page of the item with `id`, and scrolls the list to it.
  ///
  /// - Parameter id: The identifier of the item.
  private func showItem(_ id: String) {
    anchors.noteJump(to: id)
    scroll(to: .item(id))
  }

  /// Applies a scroll target of the manager to the list.
  ///
  /// - Parameter target: The target.
  private func scroll(to target: ScrollAnchorTarget) {
    switch target {
    case .bottom:
      guard let lastID = source.lastRowKey else { return }
      position.scrollTo(id: lastID, anchor: .bottom)
    case .item(let id):
      if let itemPosition = source.position(of: id) {
        let needed = ConversationLayout.pageCount(
          toShow: itemPosition, count: source.rowCount, pageSize: pageSize)
        pageCount = max(pageCount, needed)
      }
      position.scrollTo(id: id, anchor: .top)
    }
  }

  /// Tells the manager which rows are in view.
  ///
  /// - Parameters:
  ///   - ids: The identifiers of the rows in view, in any order.
  ///   - isNearBottom: Whether the end of the list is in the tolerance of
  ///     the manager, or `nil` to use the last known value.
  private func noteVisible(ids: [String], isNearBottom: Bool?) {
    if let isNearBottom {
      self.isNearBottom = isNearBottom
    }
    // Each id gets its position one time, and the sort compares the stored
    // positions.
    let sorted = ids.map { (id: $0, position: source.position(of: $0) ?? 0) }
      .sorted { $0.position < $1.position }
      .map(\.id)
    anchors.noteVisible(
      ids: sorted, distanceFromBottom: self.isNearBottom ? 0 : .greatestFiniteMagnitude)
  }

  /// Tells the manager about a change to the last item.
  ///
  /// - Parameters:
  ///   - old: The identifier of the last item before the change.
  ///   - new: The identifier of the last item after the change.
  private func noteLastItem(old: String?, new: String?) {
    guard let new else {
      anchors.noteLastItemChanged(to: nil)
      return
    }
    let keys = source.rowKeys
    // With no old last item, each item is new. An old last item that the
    // thread removed gives no start: the change is not an append.
    let start: Int?
    if let old {
      start = source.position(of: old).map { $0 + 1 }
    } else {
      start = keys.startIndex
    }
    guard let start, start < keys.endIndex else {
      anchors.noteLastItemChanged(to: new)
      return
    }
    anchors.noteAppended(ids: Array(keys[start...]))
  }
}

extension ConversationView where EmptyState == ConversationEmptyState {
  /// Makes the list of a thread with the default empty state.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - anchors: The manager that keeps the scroll position. With `nil`,
  ///     the view makes its own manager.
  public init(thread: AgentThread, anchors: ScrollAnchorManager? = nil) {
    self.init(thread: thread, anchors: anchors) { ConversationEmptyState() }
  }

  /// Makes the list of the transcript of a session model with the default
  /// empty state.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - anchors: The manager that keeps the scroll position. With `nil`,
  ///     the view makes its own manager.
  public init(session: SessionModel, anchors: ScrollAnchorManager? = nil) {
    self.init(session: session, anchors: anchors) { ConversationEmptyState() }
  }
}

/// The default empty state of a ``ConversationView``.
public struct ConversationEmptyState: View {
  /// Makes the default empty state.
  public init() {}

  public var body: some View {
    ContentUnavailableView(
      "No Messages",
      systemImage: "bubble.left.and.bubble.right",
      description: Text("Send a message to start the conversation.")
    )
    .accessibilityIdentifier(ConversationLayout.emptyStateIdentifier)
  }
}

/// The scroll-to-bottom pill of a conversation.
///
/// The pill is a separate view, so that a change to the pin state evaluates
/// only this view and not the list.
private struct ConversationPill: View {
  /// The manager of the conversation.
  let anchors: ScrollAnchorManager

  var body: some View {
    if !anchors.isPinnedToBottom {
      ScrollToBottomPill(newItemCount: anchors.newItemsSinceUnpinned) {
        anchors.pinToBottom()
      }
    }
  }
}

/// Keeps the end of the list in view when the size of the content changes,
/// only while the list follows the bottom.
///
/// A row that grows, such as a streamed message, keeps the end in view while
/// the manager is pinned to the bottom. After a jump to a row, the manager
/// keeps that row as its anchor, and a size change does not move the list
/// back to the bottom. The modifier reads the manager in its own body, so a
/// change to the pin state does not evaluate the list.
private struct ConversationFollowAnchor: ViewModifier {
  /// The manager of the conversation.
  let anchors: ScrollAnchorManager

  func body(content: Content) -> some View {
    let follows = anchors.isPinnedToBottom && anchors.anchorID == nil
    content.defaultScrollAnchor(follows ? .bottom : nil, for: .sizeChanges)
  }
}

/// The state banner of a conversation.
///
/// The banner is a separate view, so that a change to the thread state
/// evaluates only this view and not the list.
private struct ConversationBanner: View {
  /// The thread of the conversation.
  let thread: AgentThread

  /// The closure that scrolls the conversation to an error.
  let onShowError: (String) -> Void

  @Environment(\.agentTheme) private var theme

  var body: some View {
    let state = thread.state
    if StateBanner.message(for: state) != nil {
      StateBanner(
        state: state,
        errorID: ConversationLayout.relatedErrorID(in: thread.items, state: state),
        onShowError: onShowError
      )
      .padding(theme.spacing.m)
    }
  }
}
