import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// A right click on the plain text of an item shows the context menu of the
/// item (D193 (f)).
///
/// The plain text of the kit is an EditorKit `EditorLabel`. The text view of
/// the label adds no menu of its own: its `menu(for:)` gives the menu of the
/// nearest view above it that has one. So each caller that asks the view for
/// its menu, such as AppKit for a right click, or VoiceOver, gets the item
/// menu.
///
/// The area that the menu covers is under test, so a read hit-tests a point
/// on the text (`HostedViewHarness.contextMenu(at:)`). The read makes a right
/// mouse-down that it never posts, so the window stays off the screen and not
/// key. Each suite whose name ends in `PointerHostedTests` holds such a hit
/// test.
@Suite(.serialized, .hostedSerially) @MainActor struct PlainTextContextMenuPointerHostedTests {
  /// The title of the item menu command of the test.
  static let copyMessage = "Copy Message"

  /// The type name of the text view of an `EditorLabel` (EditorKit
  /// `EditorLabelTextView.swift`).
  static let labelViewTypeName = "EditorLabelTextView"

  /// Mounts a plain text in a view with a context menu, as an item of the
  /// thread has.
  static func mount() -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: CGSize(width: 400, height: 200)) {
      EditorLabel(verbatim: "Some words of a message.")
        .padding()
        .contextMenu { Button(copyMessage) {} }
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The text view of the label under the hosting view.
  static func labelView(in harness: HostedViewHarness<some View>) throws -> NSView {
    try #require(
      harness.hostingView.descendants.first { String(describing: type(of: $0)) == labelViewTypeName })
  }

  @Test func aRightClickOnTheTextShowsTheMenuOfTheItem() throws {
    let harness = Self.mount()
    defer { harness.close() }
    let text = try Self.labelView(in: harness)
    let press = try RightPress.makeEvent(atCenterOf: text)

    let menu = try #require(text.menu(for: press))

    #expect(menu.items.map(\.title) == [Self.copyMessage])
  }

  @Test func theMenuAtTheTextIsTheMenuOfTheItem() throws {
    let harness = Self.mount()
    defer { harness.close() }
    let text = try Self.labelView(in: harness)
    let center = text.convert(NSPoint(x: text.bounds.midX, y: text.bounds.midY), to: nil)

    // The harness, as VoiceOver, asks the view under the point for its menu.
    let menu = try #require(try harness.contextMenu(at: center))

    #expect(menu.items.map(\.title) == [Self.copyMessage])
  }
}
