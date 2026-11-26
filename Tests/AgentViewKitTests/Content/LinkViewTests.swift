import AppKit
import EditorTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

@testable import AgentViewKit

/// The card of a resource link block: EditorKit's `EditorLink`, which opens
/// its URL through the `openURL` action of the environment
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the card in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct LinkViewTests {
  /// The name of the link of each test.
  static let linkName = "Swift Book"

  /// The URI of the link of each test.
  static let linkURI = "https://example.com/swift-book"

  /// The view of the link of each test.
  static var view: LinkView {
    LinkView(link: FoundationModelsACP.ResourceLink(name: linkName, uri: linkURI))
  }

  /// A production change that fails this test: the card is a plain system
  /// `Button` in place of the EditorKit `EditorLink`, so VoiceOver reads a
  /// button and not a link.
  @Test func theCardIsALink() async {
    let role = await ControlProbe.read(LinkView.cardIdentifier, in: Self.view, accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.link.rawValue)
  }
}
