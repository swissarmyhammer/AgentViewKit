#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import SwiftUI
  import Testing

  @Suite(.serialized) @MainActor struct ThreadMinimapViewHostedTests {
    /// The number of items in each thread of these tests.
    static let itemCount = 20

    /// The number of items in the thread that is too short for the rail.
    static let shortItemCount = 5

    /// The number of item kinds in the sample thread.
    static let sampleKindCount = 4

    /// The position of the first visible item in the value test.
    static let firstVisiblePosition = 4

    /// The number of items that the value test shows.
    static let visibleItemCount = 6

    /// The position of the item at the vertical middle of the rail.
    static let middlePosition = itemCount / 2

    /// A width that is less than the smallest width of the test modifier.
    static let narrowWidth: CGFloat = 300

    /// The smallest width of the conversation in the width tests.
    static let minimumWidth: CGFloat = 400

    /// The longest time that a test waits for a view change, in seconds.
    static let waitTimeout: TimeInterval = 2

    /// The accessibility identifiers of the tick elements, in order.
    ///
    /// - Parameter harness: The harness that shows the rail.
    /// - Returns: The identifiers that start with the tick prefix.
    static func tickIdentifiers<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
      harness.accessibilityElements().compactMap(\.identifier).filter {
        $0.hasPrefix(ThreadMinimapView.tickIdentifierPrefix)
      }
    }

    /// Sends a mouse-down and a mouse-up event at `point` to the window of
    /// `harness`, then pumps the run loop.
    ///
    /// - Parameters:
    ///   - point: The point in the coordinates of the window.
    ///   - harness: The harness that gets the click.
    static func click<Content: View>(at point: NSPoint, in harness: HostedViewHarness<Content>) {
      for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        let event = NSEvent.mouseEvent(
          with: type,
          location: point,
          modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: harness.window.windowNumber,
          context: nil,
          eventNumber: 0,
          clickCount: 1,
          pressure: 1
        )
        if let event {
          harness.window.sendEvent(event)
        }
      }
      harness.pump()
    }

    @Test func eachItemHasOneTickOfItsKind() {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ThreadMinimapView(thread: thread, anchors: anchors))
      defer { harness.close() }
      harness.pump()

      let ticks = Self.tickIdentifiers(in: harness)
      #expect(ticks.count == Self.itemCount)

      let expected = Dictionary(
        thread.items.map { (ThreadMinimapView.tickIdentifier(for: $0), 1) }, uniquingKeysWith: +)
      let actual = Dictionary(ticks.map { ($0, 1) }, uniquingKeysWith: +)
      #expect(actual == expected)
      #expect(actual.count == Self.sampleKindCount)
      #expect(
        actual[ThreadMinimapView.tickIdentifierPrefix + "user"] == Self.itemCount
          / Self.sampleKindCount)
      #expect(
        actual[ThreadMinimapView.tickIdentifierPrefix + "tool-call"] == Self.itemCount
          / Self.sampleKindCount)
    }

    @Test func aClickAtTheMiddleOfTheRailAnchorsTheMiddleItem() async {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ThreadMinimapView(thread: thread, anchors: anchors))
      defer { harness.close() }
      harness.pump()

      let bounds = harness.hostingView.bounds
      let middle = harness.hostingView.convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
      Self.click(at: middle, in: harness)
      await harness.pump(until: Self.waitTimeout) { anchors.anchorID != nil }

      #expect(anchors.anchorID == thread.items[Self.middlePosition].id)
    }

    @Test func theValueTellsTheFirstVisibleItem() async {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let anchors = ScrollAnchorManager()
      let visible = thread.items[
        Self.firstVisiblePosition..<(Self.firstVisiblePosition + Self.visibleItemCount)
      ].map(\.id)
      anchors.noteVisible(ids: visible)
      let harness = HostedViewHarness(ThreadMinimapView(thread: thread, anchors: anchors))
      defer { harness.close() }
      harness.pump()

      let expected = "Item \(Self.firstVisiblePosition + 1) of \(Self.itemCount)"
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ThreadMinimapView.railIdentifier)?.value == expected
      }
      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier)?.value == expected)
    }

    @Test func theIncrementActionAnchorsTheNextItem() async throws {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let anchors = ScrollAnchorManager()
      anchors.noteVisible(ids: [thread.items[Self.firstVisiblePosition].id])
      let harness = HostedViewHarness(ThreadMinimapView(thread: thread, anchors: anchors))
      defer { harness.close() }
      harness.pump()

      try harness.increment(identifier: ThreadMinimapView.railIdentifier)
      await harness.pump(until: Self.waitTimeout) { anchors.anchorID != nil }

      #expect(anchors.anchorID == thread.items[Self.firstVisiblePosition + 1].id)
    }

    @Test func aThreadBelowTheItemCountShowsNoRail() {
      let thread = ThreadFixtures.sampleThread(items: Self.shortItemCount)
      let view = ThreadMinimapView(
        thread: thread, anchors: ScrollAnchorManager(), minimumItemCount: Self.shortItemCount + 1)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) == nil)
      #expect(Self.tickIdentifiers(in: harness).isEmpty)
    }

    @Test func aNarrowConversationShowsNoRail() {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let view = Color.clear
        .threadMinimap(
          thread: thread, anchors: ScrollAnchorManager(), minimumWidth: Self.minimumWidth)
      let harness = HostedViewHarness(
        view,
        size: CGSize(width: Self.narrowWidth, height: HostedViewHarness<Color>.defaultSize.height))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) == nil)
    }

    @Test func aWideConversationShowsTheRail() async {
      let thread = ThreadFixtures.sampleThread(items: Self.itemCount)
      let view = Color.clear
        .threadMinimap(
          thread: thread, anchors: ScrollAnchorManager(), minimumWidth: Self.minimumWidth)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ThreadMinimapView.railIdentifier) != nil
      }
      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) != nil)
    }
  }
#endif
