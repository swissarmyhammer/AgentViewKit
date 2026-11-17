@testable import AgentViewKit
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

/// A right click on the Textual text of an item shows the context menu of
/// the item, not the menu of Textual ("Share…", "Copy") (D193 (f)).
///
/// The app-local monitor (``TextualContextMenu``) sees a press before the
/// window, and the `menu(for:)` of the Textual view gives the item menu to
/// each caller that asks the view, such as VoiceOver.
@Suite(.serialized, .hostedSerially) @MainActor struct TextualContextMenuHostedTests {
  /// The title of the item menu command of the test.
  static let copyMessage = "Copy Message"

  /// Mounts a selectable text in a view with a context menu, as an item of
  /// the thread has.
  static func mount() async -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: CGSize(width: 400, height: 200)) {
      SelectableText("Some words of a message.")
        .padding()
        .contextMenu { Button(copyMessage) {} }
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    // Textual adds its interaction view in an update that SwiftUI queues on
    // the main run loop.
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
    return harness
  }

  /// The Textual interaction view under the hosting view.
  static func interactionView(in harness: HostedViewHarness<some View>) throws -> NSView {
    try #require(
      harness.hostingView.descendants.first {
        String(describing: type(of: $0)) == TextualSelectionProbeView.interactionTypeName
      })
  }

  /// A right press at the center of `view`.
  static func rightPress(on view: NSView, in window: NSWindow) throws -> NSEvent {
    let center = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    return try #require(
      NSEvent.mouseEvent(
        with: .rightMouseDown, location: center, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
  }

  @Test func aRightClickOnTheTextShowsTheMenuOfTheItem() async throws {
    let harness = await Self.mount()
    defer { harness.close() }
    let text = try Self.interactionView(in: harness)
    let press = try Self.rightPress(on: text, in: harness.window)

    let found = try #require(TextualContextMenu.itemMenu(for: press, hit: text))

    #expect(found.menu.items.map(\.title) == [Self.copyMessage])
  }

  @Test func theMenuOfTheTextIsTheMenuOfTheItem() async throws {
    let harness = await Self.mount()
    defer { harness.close() }
    let text = try Self.interactionView(in: harness)
    let center = text.convert(NSPoint(x: text.bounds.midX, y: text.bounds.midY), to: nil)

    // The harness, as VoiceOver, asks the view under the point for its menu
    // with no press through the event monitor.
    let menu = try #require(try harness.contextMenu(at: center))

    #expect(menu.items.map(\.title) == [Self.copyMessage])
  }
}
