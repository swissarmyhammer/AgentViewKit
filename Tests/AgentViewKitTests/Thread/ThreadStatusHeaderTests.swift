import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The whole glass of the header of a thread takes a click, so that a right
/// click on the inset of the status line in its glass opens the context
/// menu of the host path (D193 (f), ^2sg9taf).
///
/// The unit tests mount no view, so the test reads the type of the body.
/// IntegrationTests (`ThreadHeaderContextMenuHostedTests`) right-clicks the
/// empty part of the header in a window.
@MainActor @Suite struct ThreadStatusHeaderTests {
  /// The hit shape wraps the padded line, which is the shape of the glass,
  /// and not only the line inside the inset.
  static let paddedHitShape = "_PaddingLayout>, _ContentShapeModifier<ConcentricRectangle>>"

  /// A production change that fails this test: the hit shape is on the line
  /// only, so a click on the inset of the line goes through the glass.
  @Test func theInsetOfTheLineInItsGlassHasTheHitShapeOfTheGlass() {
    let header = ThreadStatusHeader(
      session: .preview(), connection: .preview(), sessionTitle: "Kit", contextMenuPath: nil,
      select: { _ in })

    #expect(String(describing: type(of: header.body)).contains(Self.paddedHitShape))
  }
}
