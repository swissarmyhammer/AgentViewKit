import AppKit
import SwiftUI

/// A thin vertical rail that shows the items of a thread and moves the
/// conversation to an item (plan.md §9 A).
///
/// The rail shows one tick for each item, in thread order, tinted by the item
/// kind. A tool call tick shows the status color of the call. A translucent
/// band shows the items in view, from ``ScrollAnchorManager/visibleIDs``.
///
/// A click or a drag on the rail moves the conversation to the item under the
/// pointer. The rail calls ``ScrollAnchorManager/noteJump(to:)`` and scrolls
/// with the `ScrollViewProxy`. When the rail has no proxy, it sends
/// ``ScrollAnchorTarget/item(_:)`` to ``ScrollAnchorManager/onScroll``.
///
/// The rail shows nothing when the thread has fewer items than
/// `minimumItemCount`. To also hide the rail in a narrow conversation, use
/// ``SwiftUI/View/threadMinimap(thread:anchors:proxy:minimumItemCount:minimumWidth:)``.
///
/// For accessibility, the rail is one adjustable element with the identifier
/// ``railIdentifier`` and the value "Item N of M". The increment and decrement
/// actions move one item. In a debug build, each tick is also an element with
/// the identifier from ``tickIdentifier(for:)``, so that a test can count the
/// ticks.
public struct ThreadMinimapView: View {
  /// The accessibility identifier of the rail.
  public static let railIdentifier = "thread-minimap"

  /// The start of the accessibility identifier of each tick.
  public static let tickIdentifierPrefix = "minimap-tick-"

  /// The default smallest number of items that shows the rail.
  public static let defaultMinimumItemCount = 10

  /// The default smallest width of the conversation that shows the rail, in
  /// points. See
  /// ``SwiftUI/View/threadMinimap(thread:anchors:proxy:minimumItemCount:minimumWidth:)``.
  public static let defaultMinimumWidth: CGFloat = 480

  /// The width of the rail, in points.
  static let railWidth: CGFloat = 12

  /// The smallest height of one tick, in points.
  static let minimumTickHeight: CGFloat = 1

  /// The part of each item slot that the tick fills. The rest is a gap.
  static let tickFill: CGFloat = 0.7

  /// The opacity of the viewport band.
  static let bandOpacity: CGFloat = 0.18

  /// The opacity of the ticks of the item kinds with no strong color.
  static let quietTickOpacity: CGFloat = 0.4

  /// The number of items that the increment and decrement actions move.
  static let adjustStep = 1

  /// The thread to show.
  let thread: AgentThread

  /// The manager that gives the items in view and keeps the anchor.
  let anchors: ScrollAnchorManager

  /// The proxy that scrolls the conversation, or `nil`.
  let proxy: ScrollViewProxy?

  /// The smallest number of items that shows the rail.
  let minimumItemCount: Int

  @Environment(\.agentTheme) private var theme

  /// Makes the rail of a thread.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - anchors: The manager that gives the items in view and keeps the
  ///     anchor.
  ///   - proxy: The proxy that scrolls the conversation. With `nil`, the rail
  ///     sends each scroll to ``ScrollAnchorManager/onScroll``.
  ///   - minimumItemCount: The smallest number of items that shows the rail.
  public init(
    thread: AgentThread,
    anchors: ScrollAnchorManager,
    proxy: ScrollViewProxy? = nil,
    minimumItemCount: Int = ThreadMinimapView.defaultMinimumItemCount
  ) {
    self.thread = thread
    self.anchors = anchors
    self.proxy = proxy
    self.minimumItemCount = minimumItemCount
  }

  /// The accessibility identifier of the tick of `item`.
  ///
  /// - Parameter item: The item.
  /// - Returns: `minimap-tick-<kind>`, where the kind is `system`, `user`,
  ///   `assistant`, `reasoning`, `tool-call`, `structured`, `compaction`,
  ///   `error`, or `unknown`.
  public static func tickIdentifier(for item: ThreadItem) -> String {
    tickIdentifierPrefix + kindName(of: item)
  }

  /// The accessibility value of the rail.
  ///
  /// - Parameters:
  ///   - position: The position of the first item in view, from zero.
  ///   - count: The number of items.
  /// - Returns: "Item N of M", where N counts from one.
  static func positionValue(position: Int, count: Int) -> String {
    String(localized: "Item \(position + 1) of \(count)")
  }

  /// The position of the item at `fraction` of the rail height.
  ///
  /// - Parameters:
  ///   - fraction: The distance from the top of the rail, as a part of the
  ///     rail height. The function clamps the value to `0...1`.
  ///   - count: The number of items.
  /// - Returns: The position, in `0..<count`, or `nil` when `count` is not
  ///   more than zero.
  static func position(atFraction fraction: CGFloat, count: Int) -> Int? {
    guard count > 0 else { return nil }
    let clamped = min(max(fraction, 0), 1)
    return min(Int(clamped * CGFloat(count)), count - 1)
  }

  public var body: some View {
    let items = thread.items
    if items.count >= minimumItemCount, !items.isEmpty {
      rail(items: items)
    }
  }

  // MARK: - Rail

  /// The rail of `items`.
  ///
  /// - Parameter items: The items of the thread, not empty.
  /// - Returns: The rail view.
  private func rail(items: [ThreadItem]) -> some View {
    let tints = items.map(tint(of:))
    let band = visibleRange(in: items)
    let current = band?.lowerBound ?? 0
    return ZStack {
      Canvas { context, size in
        Self.draw(tints: tints, band: band, bandColor: theme.accent, in: &context, size: size)
      }
      .accessibilityHidden(true)
      #if DEBUG
        tickElements(items: items)
      #endif
      Color.clear
        .accessibilityElement()
        .accessibilityLabel(Text("Thread minimap"))
        .accessibilityValue(Text(Self.positionValue(position: current, count: items.count)))
        // An element with no role does not give its value. The trait gives
        // the static text role.
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAdjustableAction { direction in
          adjust(direction, from: current, items: items)
        }
        .accessibilityIdentifier(Self.railIdentifier)
      ScrubSurface { fraction in
        scrub(toFraction: fraction, items: items)
      }
      .accessibilityHidden(true)
    }
    .frame(width: Self.railWidth)
    .frame(maxHeight: .infinity)
    .accessibilityElement(children: .contain)
  }

  #if DEBUG
    /// One accessibility element for each tick, so that a test can count the
    /// ticks.
    ///
    /// - Parameter items: The items of the thread.
    /// - Returns: A stack of clear elements, one for each item.
    private func tickElements(items: [ThreadItem]) -> some View {
      VStack(spacing: 0) {
        ForEach(items, id: \.id) { item in
          Color.clear
            .frame(maxHeight: .infinity)
            .accessibilityElement()
            .accessibilityLabel(Text(Self.kindName(of: item)))
            .accessibilityIdentifier(Self.tickIdentifier(for: item))
        }
      }
      .allowsHitTesting(false)
    }
  #endif

  /// Draws the viewport band and one tick for each tint.
  ///
  /// - Parameters:
  ///   - tints: The color of each tick, in thread order.
  ///   - band: The positions of the items in view, or `nil`.
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

  /// Moves the conversation to the item at `fraction` of the rail height.
  ///
  /// - Parameters:
  ///   - fraction: The distance from the top of the rail, as a part of the
  ///     rail height.
  ///   - items: The items of the thread.
  private func scrub(toFraction fraction: CGFloat, items: [ThreadItem]) {
    guard let position = Self.position(atFraction: fraction, count: items.count) else {
      return
    }
    jump(to: items[position].id)
  }

  /// Moves the conversation one item up or down from `current`.
  ///
  /// - Parameters:
  ///   - direction: The direction of the adjustment.
  ///   - current: The position of the first item in view.
  ///   - items: The items of the thread.
  private func adjust(
    _ direction: AccessibilityAdjustmentDirection, from current: Int, items: [ThreadItem]
  ) {
    let step = direction == .increment ? Self.adjustStep : -Self.adjustStep
    let target = min(max(current + step, 0), items.count - 1)
    jump(to: items[target].id)
  }

  /// Keeps `id` as the anchor and scrolls the conversation to it.
  ///
  /// - Parameter id: The identifier of the item.
  private func jump(to id: String) {
    guard anchors.anchorID != id else { return }
    anchors.noteJump(to: id)
    if let proxy {
      proxy.scrollTo(id, anchor: .top)
    } else {
      anchors.onScroll(.item(id))
    }
  }

  // MARK: - Items

  /// The positions of the first and the last item in view.
  ///
  /// - Parameter items: The items of the thread.
  /// - Returns: The range, or `nil` when no item of `items` is in view.
  private func visibleRange(in items: [ThreadItem]) -> ClosedRange<Int>? {
    let visible = Set(anchors.visibleIDs)
    guard !visible.isEmpty,
      let first = items.firstIndex(where: { visible.contains($0.id) }),
      let last = items.lastIndex(where: { visible.contains($0.id) })
    else { return nil }
    return first...last
  }

  /// The name of the kind of `item`.
  ///
  /// - Parameter item: The item.
  /// - Returns: The kind name that ``tickIdentifier(for:)`` uses.
  private static func kindName(of item: ThreadItem) -> String {
    switch item {
    case .system: "system"
    case .userMessage: "user"
    case .assistantMessage: "assistant"
    case .reasoning: "reasoning"
    case .toolCall: "tool-call"
    case .structured: "structured"
    case .compaction: "compaction"
    case .error: "error"
    case .unknown: "unknown"
    }
  }

  /// The tick color of `item`, from the theme.
  ///
  /// - Parameter item: The item.
  /// - Returns: The color.
  private func tint(of item: ThreadItem) -> Color {
    let colors = theme.statusColors
    return switch item {
    case .userMessage: theme.accent
    case .assistantMessage: Color.primary
    case .reasoning: Color.secondary
    case .toolCall(let record): colors.color(for: record.status)
    case .error: colors.failed
    case .system, .structured, .compaction, .unknown:
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
  /// The thread to show.
  let thread: AgentThread

  /// The manager that gives the items in view and keeps the anchor.
  let anchors: ScrollAnchorManager

  /// The proxy that scrolls the conversation, or `nil`.
  let proxy: ScrollViewProxy?

  /// The smallest number of items that shows the rail.
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
            thread: thread, anchors: anchors, proxy: proxy, minimumItemCount: minimumItemCount)
        }
      }
  }
}

extension View {
  /// Shows a ``ThreadMinimapView`` on the trailing edge of this view.
  ///
  /// The rail is hidden when the thread has fewer items than
  /// `minimumItemCount`, and when this view is narrower than `minimumWidth`.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - anchors: The manager that gives the items in view and keeps the
  ///     anchor.
  ///   - proxy: The proxy that scrolls the conversation.
  ///   - minimumItemCount: The smallest number of items that shows the rail.
  ///   - minimumWidth: The smallest width of this view that shows the rail,
  ///     in points.
  /// - Returns: The view with the rail.
  public func threadMinimap(
    thread: AgentThread,
    anchors: ScrollAnchorManager,
    proxy: ScrollViewProxy? = nil,
    minimumItemCount: Int = ThreadMinimapView.defaultMinimumItemCount,
    minimumWidth: CGFloat = ThreadMinimapView.defaultMinimumWidth
  ) -> some View {
    modifier(
      ThreadMinimapModifier(
        thread: thread, anchors: anchors, proxy: proxy,
        minimumItemCount: minimumItemCount, minimumWidth: minimumWidth))
  }
}
