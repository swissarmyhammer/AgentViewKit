@testable import AgentViewKit
import Foundation
import Testing

/// The full width of the status line takes a click, so that a right click
/// on its empty part opens the context menu of the header (D193 (f)).
///
/// The unit tests mount no view, so the test reads the type of the body.
/// IntegrationTests (`ThreadHeaderContextMenuHostedTests`) right-clicks the
/// empty part of the line in a window.
@MainActor @Suite struct StatusLineHitShapeTests {
  /// The hit shape is the outermost modifier of the line, around the frame
  /// of the full width and the accessibility modifiers, and not only around
  /// the text of a module. The shape is for clicks only (^y43c2hw).
  static let fullWidthHitShape = "AccessibilityAttachmentModifier>, _ContentShapeKindModifier<Rectangle>>"

  @Test func theFullWidthOfTheLineHasARectangleHitShape() {
    let content = StatusLineContent(
      input: StatusLineInput(cwd: "/Users/me/code/Kit", homeFolder: "/Users/me", sessionTitle: "Kit"),
      definition: StatusLines.defaultDefinition, path: [], rootTitle: nil, select: { _ in })

    #expect(String(describing: type(of: content.body)).contains(Self.fullWidthHitShape))
  }
}
