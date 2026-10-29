import EditorStyle
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

  /// The accessibility identifier of a ``ConversationEmptyState``.
  public static let emptyStateIdentifier = "conversation-empty-state"

  /// The accessibility identifier of the title of a
  /// ``ConversationEmptyState``.
  public static let emptyStateTitleIdentifier = "conversation-empty-state-title"

  /// The scroll identifier of the empty view at the end of the content of the
  /// list. A scroll to the bottom goes to this view (^66has33).
  static let bottomIdentifier = "conversation-bottom"

  /// The default number of items on one page.
  public static let defaultPageSize = 200

  /// The smallest part of a row that must be in view before the list tells
  /// the ``ScrollAnchorManager`` that the row is visible.
  static let visibilityThreshold = 0.01

  /// The SF Symbol name of the load-earlier row.
  static let loadEarlierSymbolName = SharedSymbol.loadEarlier

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
    String(localized: "\(shown) of \(count) items", bundle: .module)
  }
}

extension EnvironmentValues {
  /// The number of items on one page of a ``ConversationView``.
  ///
  /// Set the value with ``SwiftUI/View/conversationPageSize(_:)``.
  @Entry public var conversationPageSize = ConversationLayout.defaultPageSize

  /// Whether a ``ConversationView`` shows its scroll-to-bottom pill over the
  /// bottom of its list.
  ///
  /// An ``AgentThreadView`` sets the value to `false`, and shows the pill in
  /// its floating controls, in one glass container with the composer.
  @Entry var conversationShowsPill = true

  /// Whether a ``ConversationView`` shows its ``StateBanner`` in its own
  /// bottom bar.
  ///
  /// An ``AgentThreadView`` sets the value to `false`, and shows the banner
  /// in its floating controls, in the bottom bar with the composer.
  @Entry var conversationShowsStateBanner = true
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

/// The scrolled list of the transcript of a `SessionModel` (plan.md §3.2,
/// §3.8, §8, §9 A).
///
/// A `ForEach` keyed on `TranscriptEntry.id` makes one ``ItemRow`` for each
/// entry in a lazy stack, so a row keeps its identity when a pending user
/// message gets its `messageId`. The list starts at the bottom, and it
/// follows new entries while the user reads the end. The scroll anchors use
/// the ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of each entry.
/// The view reports the rows in view to a ``ScrollAnchorManager``:
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
/// When the transcript has no entry, the view shows the `emptyState` slot.
/// The default slot is a ``ConversationEmptyState``. Set its Markdown content
/// with ``SwiftUI/View/conversationEmptyState(title:systemImage:markdown:)``.
///
/// In the bottom bar of the view (`.safeAreaBar(edge: .bottom)`),
/// ``StateBanner/init(session:onShowError:)`` shows the `agentState` of the
/// model. The list scrolls under the bar (EditorKit `style.md`,
/// "Scroll under the bars"). The list asks for the soft scroll edge effect at
/// its top and bottom edges, so no window gives the opaque hard band. AppKit
/// makes the effect of an edge as tall as the whole inset of that edge. At
/// the top, the inset holds the toolbar and every bar above the list, so the
/// rows under that stack are washed out, and the fade is gradual only near
/// the top of the list. The user accepted this system look on 2026-10-23
/// (^22wbz12). The Show Error button of the banner scrolls to the last
/// `ErrorEntry` of the transcript. In an ``AgentThreadView``, the
/// banner is in the floating controls of the thread, and the view shows no
/// banner of its own.
///
/// The view sets ``ScrollAnchorManager/onScroll`` of the manager, so that a
/// ``ThreadMinimapView`` with no proxy can scroll the list.
public struct ConversationView<EmptyState: View>: View {
  /// The session model whose transcript the view shows.
  let session: SessionModel

  /// The manager that the host gave, or `nil`.
  let hostAnchors: ScrollAnchorManager?

  /// The view that shows when the transcript has no entry.
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

  /// The row key of the item of the last scroll to an item, until the list
  /// reports the row in view, or `nil`.
  ///
  /// A scroll to an item far from the rows that the lazy stack laid out
  /// places the row from the estimated heights of the rows before it. The
  /// estimate can be wrong by tens of points, and the row then stops under
  /// the top bar of the thread (^zg9tysk). The first report that holds the
  /// row comes after the stack laid the row out, so the list scrolls to the
  /// row again then (``settleItemScroll(visible:)``).
  @State private var unsettledItemID: String?

  @Environment(\.conversationPageSize) private var pageSize
  @Environment(\.editorStyle) private var editorStyle

  /// Whether the list shows its own scroll-to-bottom pill
  /// (``SwiftUI/EnvironmentValues/conversationShowsPill``).
  @Environment(\.conversationShowsPill) private var showsPill

  /// Whether the view shows its own state banner
  /// (``SwiftUI/EnvironmentValues/conversationShowsStateBanner``).
  @Environment(\.conversationShowsStateBanner) private var showsStateBanner

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
    self.session = session
    self.hostAnchors = anchors
    self.emptyState = emptyState()
  }

  /// The manager that the view uses.
  private var anchors: ScrollAnchorManager {
    hostAnchors ?? ownAnchors
  }

  /// The row key of the last entry, or `nil` when the transcript is empty.
  private var lastRowKey: String? {
    session.transcript.last?.rowKey
  }

  public var body: some View {
    Group {
      if session.transcript.isEmpty {
        emptyState
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        list
      }
    }
    .safeAreaBar(edge: .bottom) {
      // The banner reads `agentState` in its own body, so a change of the
      // state evaluates only the banner and not the list.
      if showsStateBanner {
        StateBanner(session: session) { showItem($0.rowKey) }
          .padding(editorStyle.tile.margin)
      }
    }
    .environment(\.sessionModel, session)
    .onChange(of: lastRowKey) { old, new in
      noteLastItem(old: old, new: new)
    }
    .onChange(of: pageCount) {
      anchors.restoreAnchor()
    }
  }

  // MARK: - List

  /// The scrolled list of the last pages of the rows. The transcript has at
  /// least one entry.
  private var list: some View {
    let count = session.transcript.count
    let shownCount = ConversationLayout.shownCount(
      count: count, pageSize: pageSize, pageCount: pageCount)
    let anchors = anchors
    return ScrollView {
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: editorStyle.tile.margin) {
          if shownCount < count {
            loadEarlierRow
          }
          LazyVStack(alignment: .leading, spacing: editorStyle.tile.margin) {
            rows(shownCount: shownCount)
          }
          .scrollTargetLayout()
        }
        // The list keeps the inset of its rows in its content, and gives no
        // content margin (^rgsq3k4): SwiftUI gives a content margin to the
        // AppKit scroll view as `contentInsets`, and the content insets of
        // the list are the heights of the bars above and below it
        // (ThreadBarInsetHostedTests).
        .padding(editorStyle.rowPadding)
        // The target of a scroll to the bottom near the end of the content
        // (`scrollToBottom()`).
        Color.clear
          .frame(height: 0)
          .id(ConversationLayout.bottomIdentifier)
      }
    }
    .accessibilityLabel(Text("Conversation", bundle: .module))
    .accessibilityValue(
      Text(ConversationLayout.listValue(shown: shownCount, count: count))
    )
    .accessibilityIdentifier(ConversationLayout.listIdentifier)
    // The soft edge, and never the hard one. With `.automatic`, AppKit picks
    // the effect from the window. TestudoApp measured the hard effect in the
    // detail column of its split view: an opaque band that hides the rows
    // under its bars (^ph0m0hf). The soft effect is as tall as the whole top
    // inset, so it still washes out the rows under a tall stack of bars and
    // fades only near the top of the list. The user accepted that system
    // look on 2026-10-23 (^22wbz12).
    .scrollEdgeEffectStyle(.soft, for: .vertical)
    .defaultScrollAnchor(.bottom, for: .initialOffset)
    .defaultScrollAnchor(.bottom, for: .alignment)
    .modifier(ConversationFollowAnchor(anchors: anchors))
    .scrollPosition($position)
    .onScrollTargetVisibilityChange(
      idType: String.self, threshold: ConversationLayout.visibilityThreshold
    ) { ids in
      settleItemScroll(visible: ids)
      noteVisible(ids: ids, isNearBottom: nil)
    }
    .onScrollPhaseChange { _, phase in
      // A scroll of the user ends the wait for the row of an item scroll.
      if phase.isScrolling, phase != .animating {
        unsettledItemID = nil
      }
    }
    .onScrollGeometryChange(for: Bool.self) { geometry in
      geometry.contentSize.height - geometry.visibleRect.maxY <= anchors.tolerance
    } action: { _, isNearBottom in
      noteVisible(ids: anchors.visibleIDs, isNearBottom: isNearBottom)
    }
    .overlay(alignment: .bottom) {
      // In an `AgentThreadView`, the pill is in the floating controls of the
      // thread, with the composer.
      if showsPill {
        ConversationPill(anchors: anchors)
          .padding(editorStyle.spacing.m)
      }
    }
    .onAppear {
      anchors.onScroll = { target in scroll(to: target) }
      anchors.noteLastItemChanged(to: lastRowKey)
    }
    .accessibilityReadingScope()
  }

  /// The rows of the last `shownCount` entries.
  ///
  /// The row identity is `TranscriptEntry.id` (plan.md §3.8). The scroll
  /// target of each row is its text key, because the scroll anchors use
  /// text. The text key is ``ItemRow/id``, the same value that the
  /// accessibility identifier of the row holds, so a test can read the
  /// scroll target of a row from the accessibility tree.
  ///
  /// - Parameter shownCount: The number of rows that the list shows.
  /// - Returns: One row for each shown entry.
  private func rows(shownCount: Int) -> some View {
    ForEach(session.transcript.suffix(shownCount), id: \.id) { entry in
      let row = ItemRow(entry: entry)
      readingRow(row)
        .id(row.id)
    }
  }

  /// One row, in the linked reading group of the thread.
  ///
  /// VoiceOver reads from one row into the next row
  /// (``ThreadAccessibility/threadGroupID``).
  ///
  /// - Parameter row: The row of an entry.
  /// - Returns: The row.
  private func readingRow(_ row: ItemRow) -> some View {
    row
      .equatable()
      .accessibilityReadingGroup(ThreadAccessibility.threadGroupID)
  }

  /// The row at the top of the list that shows one more page.
  private var loadEarlierRow: some View {
    Button(action: showEarlierPage) {
      Label(
        String(localized: "Load Earlier", bundle: .module),
        systemImage: ConversationLayout.loadEarlierSymbolName
      )
        .fontWeight(editorStyle.symbolWeight)
    }
    .buttonStyle(.bordered)
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
  /// A scroll to the bottom goes to the end of the content, and not to the
  /// identifier of the last row. The end of the content honors the bottom
  /// inset of a bar over the list, such as the floating controls of an
  /// ``AgentThreadView``. A scroll to the last row by its identifier places
  /// the row from the estimated heights of the lazy stack. When the rows get
  /// their real heights in the same layout pass, that scroll can stop with
  /// the last rows under the bar (^92k32m0). See ``scrollToBottom()``.
  ///
  /// A scroll to an item puts the top of its row at the top edge of the
  /// part of the list in view, below the top bar. The first scroll places
  /// the row from estimated heights, so the list scrolls to the row again
  /// when it first reports the row in view (``unsettledItemID``).
  ///
  /// - Parameter target: The target.
  private func scroll(to target: ScrollAnchorTarget) {
    switch target {
    case .bottom:
      unsettledItemID = nil
      scrollToBottom()
    case .item(let id):
      if let itemPosition = session.transcript.position(ofRowKey: id) {
        let needed = ConversationLayout.pageCount(
          toShow: itemPosition, count: session.transcript.count, pageSize: pageSize)
        pageCount = max(pageCount, needed)
      }
      unsettledItemID = id
      position.scrollTo(id: id, anchor: .top)
    }
  }

  /// Scrolls to the item of the last scroll to an item again, when `ids`
  /// holds its row for the first time after that scroll.
  ///
  /// The row is laid out when the list reports it in view, so this second
  /// scroll reads the real frame of the row and puts the row below the top
  /// bar. The list then waits for no other report.
  ///
  /// - Parameter ids: The identifiers of the rows in view, in any order.
  private func settleItemScroll(visible ids: [String]) {
    guard let id = unsettledItemID, ids.contains(id) else { return }
    unsettledItemID = nil
    position.scrollTo(id: id, anchor: .top)
  }

  /// Scrolls the list to the end of its content.
  ///
  /// Near the end, such as for an append while the list follows the bottom,
  /// the list goes to the empty view with
  /// ``ConversationLayout/bottomIdentifier``. The rows near the end are laid
  /// out, so the position of that view is exact.
  ///
  /// Far from the end, such as for a press on the pill, the rows between have
  /// only estimated heights, and a scroll to the view can stop short of the
  /// end. The list then goes to the bottom edge of its content. The scroll
  /// position keeps that edge until the next scroll, and SwiftUI applies a
  /// kept edge again in later layout passes, from the frame of the scroll
  /// target layout: past the end of the content by the bottom inset. The
  /// list reports no row in view for such a pass, the report unpins the
  /// manager, and the lazy stack can keep no row. Thus the scroll of each
  /// append near the end goes to the view and replaces a kept edge
  /// (^66has33).
  private func scrollToBottom() {
    guard lastRowKey != nil else { return }
    if isNearBottom {
      position.scrollTo(id: ConversationLayout.bottomIdentifier, anchor: .bottom)
    } else {
      position.scrollTo(edge: .bottom)
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
    let transcript = session.transcript
    let sorted = ids.map { (id: $0, position: transcript.position(ofRowKey: $0) ?? 0) }
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
    let keys = session.transcript.map(\.rowKey)
    // With no old last item, each item is new. An old last item that the
    // thread removed gives no start: the change is not an append.
    let start: Int?
    if let old {
      start = session.transcript.position(ofRowKey: old).map { $0 + 1 }
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

/// The default empty state of a ``ConversationView``: a
/// ``ConversationEmptyState`` with the large spacing step of the style as the
/// margin of its scroll content.
public typealias DefaultConversationEmptyState = ModifiedContent<ConversationEmptyState, ScrollContentMargins>

extension ConversationView where EmptyState == DefaultConversationEmptyState {
  /// Makes the list of the transcript of a session model with the default
  /// empty state.
  ///
  /// The empty state has no margin of its own (^rgsq3k4), so the default
  /// slot gives it the large spacing step of the style. A custom empty state
  /// gets the margin that its host gives.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the view shows.
  ///   - anchors: The manager that keeps the scroll position. With `nil`,
  ///     the view makes its own manager.
  public init(session: SessionModel, anchors: ScrollAnchorManager? = nil) {
    self.init(session: session, anchors: anchors) {
      ConversationEmptyState().modifier(ScrollContentMargins(\.spacing.l))
    }
  }
}

/// The scroll-to-bottom pill of a conversation.
///
/// The pill is a separate view, so that a change to the pin state evaluates
/// only this view and not the list. A ``ConversationView`` shows it over the
/// bottom of its list. An ``AgentThreadView`` shows it in its floating
/// controls.
struct ConversationPill: View {
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

#Preview("Conversation") {
  ConversationView(session: .previewSample)
}

#Preview("Empty conversation") {
  ConversationView(session: .preview())
}
