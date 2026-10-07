import AppKit
import FoundationModelsACPClient
import SwiftUI

/// A thin vertical rail that shows the entries of the transcript of a
/// `SessionModel` and moves the conversation to an entry (plan.md §9 A).
///
/// The rail shows one tick for each entry of `SessionModel.transcript`, in
/// transcript order, tinted by the case of the entry. A tool call tick shows
/// the status color of `ToolCallEntry.status`. The rail reads the model each
/// time that it draws, so a new entry adds a tick and a status change of a
/// tool call changes the tint of its tick. A translucent band shows the
/// entries in view, from ``ScrollAnchorManager/visibleIDs``.
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
/// actions move one entry. In a debug build, each tick is also an element with
/// the identifier from ``tickIdentifier(for:)``, so that a test can count the
/// ticks. The value of the tick element of a tool call is the wire value of
/// the status that sets the tint.
public struct ThreadMinimapView: View {
  /// The accessibility identifier of the rail.
  public static let railIdentifier = "thread-minimap"

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

  @Environment(\.agentTheme) private var theme

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
    String(localized: "Item \(position + 1) of \(count)")
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
    let tints = entries.map(tint(of:))
    let band = visibleRange(in: keys)
    let current = band?.lowerBound ?? 0
    return ZStack {
      Canvas { context, size in
        Self.draw(tints: tints, band: band, bandColor: theme.accent, in: &context, size: size)
      }
      .accessibilityHidden(true)
      #if DEBUG
        tickElements(entries: entries)
      #endif
      Color.clear
        .accessibilityElement()
        .accessibilityLabel(Text("Thread minimap"))
        .accessibilityValue(Text(Self.positionValue(position: current, count: keys.count)))
        // An element with no role does not give its value. The trait gives
        // the static text role.
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAdjustableAction { direction in
          adjust(direction, from: current, keys: keys)
        }
        .accessibilityIdentifier(Self.railIdentifier)
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
            .accessibilityElement()
            .accessibilityLabel(Text(entry.kindName))
            .accessibilityValue(Text(Self.statusValue(of: entry)))
            // An element with no role does not give its value. The trait
            // gives the static text role.
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(Self.tickIdentifier(for: entry))
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

  /// Draws the viewport band and one tick for each tint.
  ///
  /// - Parameters:
  ///   - tints: The color of each tick, in transcript order.
  ///   - band: The positions of the entries in view, or `nil`.
  ///   - bandColor: The color of the viewport band.
  ///   - context: The graphics context.
  ///   - size: The size of the rail.
  private static func draw(
    tints: [Color], band: ClosedRange<Int>?, bandColor: Color,
    in context: inout GraphicsContext, size: CGSize
  ) {
    guard !tints.isEmpty else { return }
    let slot = size.height / CGFloat(tints.count)
    if let band {
      let top = CGFloat(band.lowerBound) * slot
      let height = CGFloat(band.count) * slot
      let rect = CGRect(x: 0, y: top, width: size.width, height: height)
      context.fill(Path(rect), with: .color(bandColor.opacity(bandOpacity)))
    }
    let tickHeight = max(slot * tickFill, minimumTickHeight)
    for (position, tint) in tints.enumerated() {
      let rect = CGRect(x: 0, y: CGFloat(position) * slot, width: size.width, height: tickHeight)
      context.fill(Path(rect), with: .color(tint))
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

  /// The tick color of `entry`, from the theme.
  ///
  /// The color of a tool call reads `ToolCallEntry.status`, so a status
  /// change draws the rail again.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: The color.
  private func tint(of entry: TranscriptEntry) -> Color {
    let colors = theme.statusColors
    return switch entry {
    case .userMessage: theme.accent
    case .agentMessage: Color.primary
    case .thought, .terminal, .plan: Color.secondary
    case .toolCall(let toolCall): colors.color(for: toolCall.shownStatus)
    case .error: colors.failed
    case .unknown, .compaction:
      Color.secondary.opacity(Self.quietTickOpacity)
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

  func body(content: Content) -> some View {
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
