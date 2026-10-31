import AppKit
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A thin vertical rail that shows the entries of the transcript of a
/// `SessionModel` and moves the conversation to an entry (plan.md §9 A).
///
/// The rail shows one tick for each entry of `SessionModel.transcript`, in
/// transcript order, tinted by the case of the entry. A tool call tick shows
/// the status color of `ToolCallEntry.status`, and the shape of the tick also
/// shows the status, so the status does not show with color only. The rail
/// reads the model each time that it draws, so a new entry adds a tick and a
/// status change of a tool call changes the tint and the shape of its tick. A
/// translucent band shows the entries in view, from
/// ``ScrollAnchorManager/visibleIDs``.
///
/// A click or a drag on the rail moves the conversation to the entry under
/// the pointer. The rail calls ``ScrollAnchorManager/noteJump(to:)`` with the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of the entry and
/// scrolls with the `ScrollViewProxy`. When the rail has no proxy, it sends
/// ``ScrollAnchorTarget/item(_:)`` to ``ScrollAnchorManager/onScroll``.
/// ``ConversationView/init(session:anchors:)`` sets that closure.
///
/// The rail shows nothing when the transcript has fewer entries than
/// `minimumItemCount`. To also hide the rail in a narrow conversation, use
/// ``SwiftUI/View/threadMinimap(session:anchors:proxy:minimumItemCount:minimumWidth:)``.
///
/// For accessibility, the rail is one adjustable element with the identifier
/// ``railIdentifier`` and the value "Item N of M". The increment and decrement
/// actions move one entry. A second element, with the identifier
/// ``summaryIdentifier``, gives a summary of the status of the entries, such
/// as "In progress: 1, Completed: 2, and Error: 1". In a debug build, each tick
/// is also an element with the identifier from ``tickIdentifier(for:)``, so
/// that a test can count the ticks. The value of the tick element of a tool
/// call is the wire value of the status that sets the tint.
public struct ThreadMinimapView: View {
  /// The shape of a tick, which shows the status of the entry with no color.
  ///
  /// Each mark fills a part of the slot of its entry, so each mark has a
  /// different shape at each slot height.
  nonisolated enum TickMark: CaseIterable {
    /// The full tick: an entry with no status, or a completed tool call.
    case plain

    /// A tick that fills the trailing half of the rail: a tool call that did
    /// not start or that runs.
    case live

    /// A wedge that points to the conversation: a failed tool call, a tool
    /// call whose result is lost, and an error entry.
    case failure

    /// A thin bar in the middle of the slot: a cancelled tool call.
    case cancelled

    /// The part of the rail width that a live tick fills.
    static let liveWidthFraction: CGFloat = 0.5

    /// The number of equal bands of the tick height for a cancelled tick: a
    /// clear band, the bar, and a clear band.
    static let cancelledBandCount: CGFloat = 3

    /// The shape of the mark in the tick rectangle `rect`.
    ///
    /// - Parameter rect: The rectangle of the tick.
    /// - Returns: The path of the mark, inside `rect`.
    func path(in rect: CGRect) -> Path {
      switch self {
      case .plain:
        return Path(rect)
      case .live:
        let width = rect.width * Self.liveWidthFraction
        return Path(CGRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height))
      case .failure:
        return Path { wedge in
          wedge.move(to: CGPoint(x: rect.maxX, y: rect.minY))
          wedge.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
          wedge.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
          wedge.closeSubpath()
        }
      case .cancelled:
        let band = rect.height / Self.cancelledBandCount
        return Path(rect.insetBy(dx: 0, dy: band))
      }
    }
  }

  /// The color and the shape of one tick.
  struct Tick {
    /// The color of the tick.
    let tint: Color

    /// The shape of the tick.
    let mark: TickMark
  }

  /// The accessibility identifier of the rail.
  public static let railIdentifier = "thread-minimap"

  /// The accessibility identifier of the status summary of the rail.
  public static let summaryIdentifier = "thread-minimap-summary"

  /// The start of the accessibility identifier of each tick.
  public static let tickIdentifierPrefix = "minimap-tick-"

  /// The default smallest number of entries that shows the rail.
  public static let defaultMinimumItemCount = 10

  /// The default smallest width of the conversation that shows the rail, in
  /// points. See
  /// ``SwiftUI/View/threadMinimap(session:anchors:proxy:minimumItemCount:minimumWidth:)``.
  public static let defaultMinimumWidth: CGFloat = 480

  /// The width of the rail, in points.
  static let railWidth: CGFloat = 12

  /// The smallest height of one tick, in points.
  static let minimumTickHeight: CGFloat = 1

  /// The part of each entry slot that the tick fills. The rest is a gap.
  static let tickFill: CGFloat = 0.7

  /// The opacity of the viewport band.
  static let bandOpacity: CGFloat = 0.18

  /// The color of the viewport band: the foreground of the theme, at
  /// ``bandOpacity``.
  ///
  /// The band marks the rows in view, the current item of the rail. It is not
  /// the selection and has no focus, so it does not use the accent of the
  /// theme: the accent is only for the selection and the focus (card
  /// ^y2mrfxt). The band is neutral, as the viewport of the Xcode minimap.
  ///
  /// - Parameter theme: The EditorKit theme.
  /// - Returns: The color.
  static func bandColor(in theme: any EditorTheme.Theme) -> Color {
    theme.editorForeground
  }

  /// The opacity of the ticks of the entry cases with no strong color.
  static let quietTickOpacity: CGFloat = 0.4

  /// The number of entries that the increment and decrement actions move.
  static let adjustStep = 1

  /// The session model whose transcript the rail shows.
  let session: SessionModel

  /// The manager that gives the rows in view and keeps the anchor.
  let anchors: ScrollAnchorManager

  /// The proxy that scrolls the conversation, or `nil`.
  let proxy: ScrollViewProxy?

  /// The smallest number of entries that shows the rail.
  let minimumItemCount: Int

  @Environment(\.editorTheme) private var editorTheme

  /// Makes the rail of the transcript of a session model.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the rail shows.
  ///   - anchors: The manager that gives the rows in view and keeps the
  ///     anchor.
  ///   - proxy: The proxy that scrolls the conversation. With `nil`, the rail
  ///     sends each scroll to ``ScrollAnchorManager/onScroll``.
  ///   - minimumItemCount: The smallest number of entries that shows the rail.
  public init(
    session: SessionModel,
    anchors: ScrollAnchorManager,
    proxy: ScrollViewProxy? = nil,
    minimumItemCount: Int = ThreadMinimapView.defaultMinimumItemCount
  ) {
    self.session = session
    self.anchors = anchors
    self.proxy = proxy
    self.minimumItemCount = minimumItemCount
  }

  /// The accessibility identifier of the tick of `entry`.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: `minimap-tick-<kind>`, where the kind is the name of the case
  ///   of the entry, such as `tool-call` or `agent-message`.
  public static func tickIdentifier(for entry: TranscriptEntry) -> String {
    AccessibilityIdentifier.make(prefix: tickIdentifierPrefix, value: entry.kindName)
  }

  /// The accessibility value of the rail.
  ///
  /// - Parameters:
  ///   - position: The position of the first entry in view, from zero.
  ///   - count: The number of entries.
  /// - Returns: "Item N of M", where N counts from one.
  static func positionValue(position: Int, count: Int) -> String {
    String(localized: "Item \(position + 1) of \(count)", bundle: .module)
  }

  /// The position of the entry at `fraction` of the rail height.
  ///
  /// - Parameters:
  ///   - fraction: The distance from the top of the rail, as a part of the
  ///     rail height. The function clamps the value to `0...1`.
  ///   - count: The number of entries.
  /// - Returns: The position, in `0..<count`, or `nil` when `count` is not
  ///   more than zero.
  static func position(atFraction fraction: CGFloat, count: Int) -> Int? {
    guard count > 0 else { return nil }
    let clamped = min(max(fraction, 0), 1)
    return min(Int(clamped * CGFloat(count)), count - 1)
  }

  public var body: some View {
    let entries = session.transcript
    if entries.count >= minimumItemCount, !entries.isEmpty {
      rail(entries: entries)
    }
  }

  // MARK: - Rail

  /// The rail of `entries`.
  ///
  /// - Parameter entries: The entries of the transcript, not empty.
  /// - Returns: The rail view.
  private func rail(entries: [TranscriptEntry]) -> some View {
    let keys = entries.map(\.rowKey)
    let ticks = entries.map { Tick(tint: Self.tint(of: $0, in: editorTheme), mark: Self.tickMark(of: $0)) }
    let band = visibleRange(in: keys)
    let bandColor = Self.bandColor(in: editorTheme)
    let current = band?.lowerBound ?? 0
    return ZStack {
      Canvas { context, size in
        Self.draw(ticks: ticks, band: band, bandColor: bandColor, in: &context, size: size)
      }
      .accessibilityHidden(true)
      #if DEBUG
        tickElements(entries: entries)
      #endif
      Color.clear
        .valueElement(
          label: Text("Thread status", bundle: .module),
          value: Text(Self.statusSummary(of: entries)),
          identifier: Self.summaryIdentifier)
      Color.clear
        .valueElement(
          label: Text("Thread minimap", bundle: .module),
          value: Text(Self.positionValue(position: current, count: keys.count)),
          identifier: Self.railIdentifier
        )
        .accessibilityAdjustableAction { direction in
          adjust(direction, from: current, keys: keys)
        }
      ScrubSurface { fraction in
        scrub(toFraction: fraction, keys: keys)
      }
      .accessibilityHidden(true)
    }
    .frame(width: Self.railWidth)
    .frame(maxHeight: .infinity)
    .accessibilityElement(children: .contain)
  }

  #if DEBUG
    /// One accessibility element for each tick, so that a test can count the
    /// ticks and read the status of a tool call tick.
    ///
    /// - Parameter entries: The entries of the transcript.
    /// - Returns: A stack of clear elements, one for each entry.
    private func tickElements(entries: [TranscriptEntry]) -> some View {
      VStack(spacing: 0) {
        ForEach(entries, id: \.id) { entry in
          Color.clear
            .frame(maxHeight: .infinity)
            .valueElement(
              label: Text(entry.kindName), value: Text(Self.statusValue(of: entry)),
              identifier: Self.tickIdentifier(for: entry))
        }
      }
      .allowsHitTesting(false)
    }

    /// The value of the tick element of `entry`.
    ///
    /// - Parameter entry: The transcript entry.
    /// - Returns: The wire value of the status of a tool call, and an empty
    ///   text for each other entry.
    private static func statusValue(of entry: TranscriptEntry) -> String {
      guard let toolCall = entry.toolCall else { return "" }
      return toolCall.shownStatus.wireValue
    }
  #endif

  /// Draws the viewport band and each tick, with its color and its shape.
  ///
  /// - Parameters:
  ///   - ticks: The color and the shape of each tick, in transcript order.
  ///   - band: The positions of the entries in view, or `nil`.
  ///   - bandColor: The color of the viewport band.
  ///   - context: The graphics context.
  ///   - size: The size of the rail.
  private static func draw(
    ticks: [Tick], band: ClosedRange<Int>?, bandColor: Color, in context: inout GraphicsContext, size: CGSize
  ) {
    guard !ticks.isEmpty else { return }
    let slot = size.height / CGFloat(ticks.count)
    if let band {
      let top = CGFloat(band.lowerBound) * slot
      let height = CGFloat(band.count) * slot
      let rect = CGRect(x: 0, y: top, width: size.width, height: height)
      context.fill(Path(rect), with: .color(bandColor.opacity(bandOpacity)))
    }
    let tickHeight = max(slot * tickFill, minimumTickHeight)
    for (position, tick) in ticks.enumerated() {
      let rect = CGRect(x: 0, y: CGFloat(position) * slot, width: size.width, height: tickHeight)
      context.fill(tick.mark.path(in: rect), with: .color(tick.tint))
    }
  }

  // MARK: - Actions

  /// Moves the conversation to the entry at `fraction` of the rail height.
  ///
  /// - Parameters:
  ///   - fraction: The distance from the top of the rail, as a part of the
  ///     rail height.
  ///   - keys: The row keys of the entries, in transcript order.
  private func scrub(toFraction fraction: CGFloat, keys: [String]) {
    guard let position = Self.position(atFraction: fraction, count: keys.count) else {
      return
    }
    jump(to: keys[position])
  }

  /// Moves the conversation one entry up or down from `current`.
  ///
  /// - Parameters:
  ///   - direction: The direction of the adjustment.
  ///   - current: The position of the first entry in view.
  ///   - keys: The row keys of the entries, in transcript order.
  private func adjust(
    _ direction: AccessibilityAdjustmentDirection, from current: Int, keys: [String]
  ) {
    let step = direction == .increment ? Self.adjustStep : -Self.adjustStep
    let target = min(max(current + step, 0), keys.count - 1)
    jump(to: keys[target])
  }

  /// Keeps `key` as the anchor and scrolls the conversation to its row.
  ///
  /// - Parameter key: The row key of the entry.
  private func jump(to key: String) {
    guard anchors.anchorID != key else { return }
    anchors.noteJump(to: key)
    if let proxy {
      proxy.scrollTo(key, anchor: .top)
    } else {
      anchors.onScroll(.item(key))
    }
  }

  // MARK: - Entries

  /// The positions of the first and the last row in view.
  ///
  /// - Parameter keys: The row keys of the entries, in transcript order.
  /// - Returns: The range, or `nil` when no row of `keys` is in view.
  private func visibleRange(in keys: [String]) -> ClosedRange<Int>? {
    let visible = Set(anchors.visibleIDs)
    guard !visible.isEmpty,
      let first = keys.firstIndex(where: visible.contains),
      let last = keys.lastIndex(where: visible.contains)
    else { return nil }
    return first...last
  }

  /// The tick shape of a tool call with `status`.
  ///
  /// - Parameter status: The ACP status of the tool call.
  /// - Returns: ``TickMark/live`` for a pending call and a call that runs,
  ///   ``TickMark/failure`` for a failed call and a call whose result is lost
  ///   (``ToolStatusSymbol/lostWireValue``), ``TickMark/cancelled`` for a
  ///   cancelled call, and ``TickMark/plain`` for a completed call or a
  ///   status that the kit does not know.
  nonisolated static func tickMark(for status: FoundationModelsACP.ToolCallStatus) -> TickMark {
    switch status {
    case .pending, .inProgress: .live
    case .failed, .unknown(ToolStatusSymbol.lostWireValue): .failure
    case .cancelled: .cancelled
    case .completed, .unknown: .plain
    }
  }

  /// The tick shape of `entry`.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: The shape of the status of a tool call, ``TickMark/failure``
  ///   for an error entry, and ``TickMark/plain`` for each other entry.
  static func tickMark(of entry: TranscriptEntry) -> TickMark {
    switch entry {
    case .toolCall(let toolCall): tickMark(for: toolCall.shownStatus)
    case .error: .failure
    case .userMessage, .agentMessage, .thought, .terminal, .plan, .unknown, .compaction: .plain
    }
  }

  /// The status summary of `entries`, for the summary element.
  ///
  /// The summary counts the tool calls of each status and the error entries,
  /// in the order of their first entry in the transcript.
  ///
  /// - Parameter entries: The entries of the transcript.
  /// - Returns: The counts, such as "In progress: 1, Completed: 2, and Error:
  ///   1", or "No status" when no entry has a status.
  static func statusSummary(of entries: [TranscriptEntry]) -> String {
    let names = entries.compactMap(statusName(of:))
    guard !names.isEmpty else { return String(localized: "No status", bundle: .module) }
    let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
    let order = names.reduce(into: [String]()) { order, name in
      if !order.contains(name) { order.append(name) }
    }
    return order.map { String(localized: "\($0): \(counts[$0, default: 0])", bundle: .module) }
      .formatted(.list(type: .and))
  }

  /// The name of the status of `entry`, for the status summary.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: The label of the status of a tool call, "Error" for an error
  ///   entry, and `nil` for each other entry.
  private static func statusName(of entry: TranscriptEntry) -> String? {
    switch entry {
    case .toolCall(let toolCall): ToolStatusSymbol.label(for: toolCall.shownStatus)
    case .error: String(localized: "Error", bundle: .module)
    case .userMessage, .agentMessage, .thought, .terminal, .plan, .unknown, .compaction: nil
    }
  }

  /// The tick color of `entry`, from the EditorKit theme.
  ///
  /// The color of a tool call reads `ToolCallEntry.status`, so a status
  /// change draws the rail again.
  ///
  /// No tick uses the accent of the theme: the accent is only for the
  /// selection and the focus (card ^y2mrfxt), and a tick is neither. Thus a
  /// user message tick is the foreground of the theme and an agent message
  /// tick is its secondary foreground.
  ///
  /// - Parameters:
  ///   - entry: The transcript entry.
  ///   - theme: The EditorKit theme.
  /// - Returns: The color.
  static func tint(of entry: TranscriptEntry, in theme: any EditorTheme.Theme) -> Color {
    return switch entry {
    case .userMessage: theme.editorForeground
    case .agentMessage, .thought, .terminal, .plan: theme.secondaryForeground
    case .toolCall(let toolCall): theme.statusColor(for: toolCall.shownStatus)
    case .error: theme.severityError
    case .unknown, .compaction:
      theme.secondaryForeground.opacity(Self.quietTickOpacity)
    }
  }
}

/// A clear AppKit surface that reports each click and drag on the rail.
///
/// The surface is an AppKit view and not a SwiftUI gesture. AppKit sends
/// each mouse event from the window straight to the view, so the view also
/// works with an event that a test makes.
private struct ScrubSurface: NSViewRepresentable {
  /// The function that gets the pointer position, as a part of the height
  /// from the top.
  let onScrub: (CGFloat) -> Void

  func makeNSView(context: Context) -> ScrubSurfaceView {
    let view = ScrubSurfaceView()
    view.onScrub = onScrub
    return view
  }

  func updateNSView(_ view: ScrubSurfaceView, context: Context) {
    view.onScrub = onScrub
  }
}

/// The AppKit view of ``ScrubSurface``.
private final class ScrubSurfaceView: NSView {
  /// The function that gets the pointer position, as a part of the height
  /// from the top.
  var onScrub: ((CGFloat) -> Void)?

  /// The origin is at the top, so that the position counts from the top.
  override var isFlipped: Bool { true }

  /// A click on the rail of a window that is not the key window also moves
  /// the conversation.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    report(event)
  }

  override func mouseDragged(with event: NSEvent) {
    report(event)
  }

  /// The rail element gives the accessibility of the rail.
  override func isAccessibilityElement() -> Bool { false }

  /// Sends the position of `event` to ``onScrub``.
  ///
  /// - Parameter event: The mouse event.
  private func report(_ event: NSEvent) {
    guard bounds.height > 0 else { return }
    let point = convert(event.locationInWindow, from: nil)
    onScrub?(point.y / bounds.height)
  }
}

/// Shows ``ThreadMinimapView`` on the trailing edge of a conversation that is
/// wide enough.
private struct ThreadMinimapModifier: ViewModifier {
  /// The session model whose transcript the rail shows.
  let session: SessionModel

  /// The manager that gives the rows in view and keeps the anchor.
  let anchors: ScrollAnchorManager

  /// The proxy that scrolls the conversation, or `nil`.
  let proxy: ScrollViewProxy?

  /// The smallest number of entries that shows the rail.
  let minimumItemCount: Int

  /// The smallest width of the conversation that shows the rail, in points.
  let minimumWidth: CGFloat

  /// The width of the conversation, in points, from the last layout.
  @State private var width: CGFloat = 0

  // `Self.Content` names the content of the modifier, and not the content
  // type of FoundationModelsACP.
  func body(content: Self.Content) -> some View {
    content
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { newWidth in
        width = newWidth
      }
      .overlay(alignment: .trailing) {
        if width >= minimumWidth {
          ThreadMinimapView(
            session: session, anchors: anchors, proxy: proxy, minimumItemCount: minimumItemCount)
        }
      }
  }
}

extension View {
  /// Shows a ``ThreadMinimapView`` on the trailing edge of this view.
  ///
  /// The rail is hidden when the transcript has fewer entries than
  /// `minimumItemCount`, and when this view is narrower than `minimumWidth`.
  ///
  /// - Parameters:
  ///   - session: The session model whose transcript the rail shows.
  ///   - anchors: The manager that gives the rows in view and keeps the
  ///     anchor.
  ///   - proxy: The proxy that scrolls the conversation.
  ///   - minimumItemCount: The smallest number of entries that shows the rail.
  ///   - minimumWidth: The smallest width of this view that shows the rail,
  ///     in points.
  /// - Returns: The view with the rail.
  public func threadMinimap(
    session: SessionModel,
    anchors: ScrollAnchorManager,
    proxy: ScrollViewProxy? = nil,
    minimumItemCount: Int = ThreadMinimapView.defaultMinimumItemCount,
    minimumWidth: CGFloat = ThreadMinimapView.defaultMinimumWidth
  ) -> some View {
    modifier(
      ThreadMinimapModifier(
        session: session, anchors: anchors, proxy: proxy,
        minimumItemCount: minimumItemCount, minimumWidth: minimumWidth))
  }
}

#Preview("Minimap") {
  ThreadMinimapView(session: .previewSample, anchors: ScrollAnchorManager(), minimumItemCount: 1)
}
