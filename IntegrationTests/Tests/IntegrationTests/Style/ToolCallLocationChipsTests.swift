import AgentViewKitStyle
import SwiftUI
import Testing

/// Checks the location chips of a tool call through their public API: the
/// texts of a location, and the style of each chip.
@Suite @MainActor struct ToolCallLocationChipsTests {
  /// The path of the sample file.
  static let path = "/Users/sample/Sources/main.swift"

  /// The line of the sample location.
  static let line = 12

  /// A location with a line.
  static let lineLocation = ToolCallLocationChips.Location(path: path, line: line, identifier: "location-0")

  /// A location with no line.
  static let fileLocation = ToolCallLocationChips.Location(path: path, line: nil, identifier: "location-1")

  /// A style that records the identifier of each location it styles.
  struct RecordingStyle: ToolCallLocationChipStyle {
    /// The record of the styled locations.
    let record: StyleRecord<String>

    func makeBody(configuration: ToolCallLocationChipConfiguration) -> some View {
      record.values.append(configuration.location.identifier)
      return configuration.chip
    }
  }

  @Test func aLocationTextWithALineJoinsThePathAndTheLine() {
    #expect(ToolCallLocationChips.Location.text(path: Self.path, line: Self.line) == "\(Self.path):\(Self.line)")
  }

  @Test func aLocationTextWithNoLineIsThePath() {
    #expect(ToolCallLocationChips.Location.text(path: Self.path, line: nil) == Self.path)
  }

  @Test func theShortTextIsTheFileNameWithTheLine() {
    #expect(Self.lineLocation.shortText == "main.swift:\(Self.line)")
    #expect(Self.fileLocation.shortText == "main.swift")
  }

  @Test func theFullTextIsThePathWithTheLine() {
    #expect(Self.lineLocation.fullText == "\(Self.path):\(Self.line)")
  }

  @Test func theIdentityOfALocationIsTheIdentifierOfItsChip() {
    #expect(Self.lineLocation.id == "location-0")
  }

  @Test func eachChipTakesTheStyleOfTheEnvironment() {
    let record = StyleRecord<String>()

    StyleViewHost.layOut(
      ToolCallLocationChips(locations: [Self.lineLocation, Self.fileLocation])
        .toolCallLocationChipStyle(RecordingStyle(record: record)))

    #expect(Set(record.values) == ["location-0", "location-1"])
  }

  @Test func theDefaultStyleShowsEachChip() {
    let one = StyleViewHost.fittingSize(of: ToolCallLocationChips(locations: [Self.lineLocation]))
    let two = StyleViewHost.fittingSize(of: ToolCallLocationChips(locations: [Self.lineLocation, Self.fileLocation]))

    #expect(two.width > one.width)
  }
}
