import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the list of files that the built-in inspector shows
/// (``InspectorSelection``, card ^4138tmp).
@Suite @MainActor struct InspectorSelectionTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// Three files, in transcript order.
  static let files = (0..<3).map { Attachment(url: URL(filePath: "/tmp/avk-inspector/file-\($0).txt")) }

  @Test func aToggleAddsAFileToTheSelection() {
    let selection = InspectorSelection(attachments: [Self.files[0]])

    selection.toggle(Self.files[2])

    #expect(selection.attachments == [Self.files[0], Self.files[2]])
  }

  @Test func anExtendAddsTheRangeOfTheOrder() {
    let selection = InspectorSelection()
    selection.select(Self.files[0])

    selection.extend(to: Self.files[2], in: Self.files)

    #expect(selection.attachments == Self.files)
  }

  @Test func aClearEmptiesTheSelection() {
    let selection = InspectorSelection(attachments: Self.files)

    selection.clear()

    #expect(selection.attachments.isEmpty)
  }
}
