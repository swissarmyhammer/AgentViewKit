import EditorTestSupport
import Foundation
import Testing

@testable import AgentViewKit

/// The selection decision of the action row of a message: the selection mode
/// of the kit equals the mode that the decision records.
///
/// The hosted tests of the action row are in `MessageActionsHostedTests` of
/// the IntegrationTests package.
@Suite struct MessageActionsSourceScanTests {
  /// The decision that records the selection mode.
  static let decisionPath = "Docs/decisions/text-selection.md"

  /// The prefix of the line that states the selection mode.
  static let modePrefix = "mode:"

  // MARK: - Selection

  @Test func theSelectionModeEqualsTheDecision() throws {
    let text = try PackageFiles().text(of: Self.decisionPath)
    let lines = text.split(separator: "\n").filter { $0.hasPrefix(Self.modePrefix) }
    #expect(lines.count == 1, "The file must have exactly one \(Self.modePrefix) line.")
    let line = try #require(lines.first)
    let mode = line.dropFirst(Self.modePrefix.count)
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "`"))

    #expect(MessageActions.selectionMode.rawValue == mode)
  }
}
