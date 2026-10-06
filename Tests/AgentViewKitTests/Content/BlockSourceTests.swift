import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The shared source of the content block views: a kit value or an ACP
/// value. A view such as ``AudioPlayerView`` keys its task on the source, so
/// equal sources must compare and hash equal, and different sources must
/// compare different.
struct BlockSourceTests {
  /// The source type of a sound block view.
  typealias AudioSource = BlockSource<AgentViewKit.AudioContent, FoundationModelsACP.AudioContent>

  /// The bytes of the sound of the tests.
  static let bytes = Data([0, 1, 2, 3])

  /// The MIME type of the sound of the tests.
  static let mimeType = "audio/wav"

  /// The kit sound of the tests.
  static let record = AgentViewKit.AudioContent(data: bytes, mimeType: mimeType)

  /// The ACP sound of the tests, with the same bytes as base64.
  static let wire = FoundationModelsACP.AudioContent(
    data: bytes.base64EncodedString(), mimeType: MediaType(rawValue: mimeType))

  @Test func twoSourcesOfTheSameACPValueAreEqualAndHaveTheSameHash() {
    let first = AudioSource.wire(Self.wire)
    let second = AudioSource.wire(Self.wire)

    #expect(first == second)
    #expect(first.hashValue == second.hashValue)
  }

  @Test func aKitSourceAndAnACPSourceOfTheSameSoundAreDifferent() {
    #expect(AudioSource.record(Self.record) != AudioSource.wire(Self.wire))
  }
}
