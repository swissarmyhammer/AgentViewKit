import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The footer of the sources of a response: EditorKit's `EditorDisclosure`,
/// whose header is an EditorKit plain button with the chevron of EditorKit
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the footer in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct SourcesViewDisclosureTests {
  /// A production change that fails this test: the footer is a system
  /// `DisclosureGroup` in place of the EditorKit `EditorDisclosure`, so the
  /// chevron of its header does not take the caption style of the button
  /// tokens of the theme.
  @Test func theHeaderTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let footer = SourcesView(payload: PreviewFixtures.citations, isExpanded: false)

    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(of: SourcesView.identifier, in: footer))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// A production change that fails this test: the identifier of the footer
  /// names no single element, for example because the container of the
  /// `EditorDisclosure` merges into the container of the footer. The footer
  /// is an accessibility container with the identifier `sources`
  /// (`contentContainer(identifier:)`), which keeps the two containers
  /// apart.
  @Test func theIdentifierOfTheFooterNamesItsContainer() async {
    let footer = SourcesView(payload: PreviewFixtures.citations, isExpanded: false)

    let role = await ControlProbe.read(SourcesView.identifier, in: footer, accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.group.rawValue)
  }
}
