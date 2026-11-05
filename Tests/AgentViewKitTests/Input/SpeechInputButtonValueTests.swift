import Testing

@testable import AgentViewKit

/// The accessibility value of ``SpeechInputButton`` in each phase (^dj4hchg).
@Suite struct SpeechInputButtonValueTests {
  /// The input level of the tests: half the full level.
  static let halfLevel = 0.5

  @Test func aSessionWithNoLevelYetReadsRecording() {
    #expect(SpeechInputButton.valueText(of: .recording(level: nil)) == "Recording")
  }

  @Test func aSessionWithALevelReadsTheLevelAsAPercentage() {
    #expect(SpeechInputButton.valueText(of: .recording(level: Self.halfLevel)) == "Recording, input level 50%")
  }

  @Test func noSessionReadsNotRecording() {
    #expect(SpeechInputButton.valueText(of: .idle) == "Not recording")
  }

  @Test func aDeniedPermissionReadsNotAllowed() {
    #expect(SpeechInputButton.valueText(of: .denied) == "Not allowed")
  }
}
