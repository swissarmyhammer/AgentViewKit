import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The block of an unknown item: EditorKit's `EditorDisclosure`, whose header
/// is an EditorKit plain button (Docs/decisions/focus-audit.md, "Raw
/// controls").
///
/// Each test lays out the block in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct JSONDisclosureTests {
  /// The title of the block of each test.
  static let title = "Review summary"

  /// The id and the accessibility identifier of the block of each test.
  static let identifier = "json-disclosure-test"

  /// A production change that fails this test: the block is a system
  /// `DisclosureGroup` in place of the EditorKit `EditorDisclosure`, so its
  /// header does not take the caption style of the button tokens of the
  /// theme.
  @Test func theHeaderTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let block = JSONDisclosure(
      id: Self.identifier, title: Self.title, json: "{}", identifier: Self.identifier, isExpanded: false)

    let frames = try #require(await ControlProbe.framesWithLargeButtonCaptions(of: Self.identifier, in: block))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// A production change that fails this test: the identifier of the block
  /// names an element with no label, such as the container of an
  /// `EditorDisclosure`, in place of the header of the block. A host, such as
  /// a thread, finds the block by its identifier and reads its title, for
  /// example the content type of an unknown plan.
  @Test func theIdentifierOfTheBlockNamesTheHeaderWithTheTitle() async {
    let block = JSONDisclosure(
      id: Self.identifier, title: Self.title, json: "{}", identifier: Self.identifier, isExpanded: false)

    let label = await ControlProbe.read(Self.identifier, in: block, accessibilityLabel(of:))

    #expect(label == Self.title)
  }

  /// A production change that fails this test: the identifier of the block
  /// names an element that is not the disclosure header, so a press on the
  /// identifier does not open the block.
  @Test func theIdentifierOfTheBlockNamesTheDisclosureHeader() async {
    let block = JSONDisclosure(
      id: Self.identifier, title: Self.title, json: "{}", identifier: Self.identifier, isExpanded: false)

    let role = await ControlProbe.read(Self.identifier, in: block, accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.disclosureTriangle.rawValue)
  }
}
