import AgentViewKit
import Foundation
import Testing

/// Tests of the ``Checkpoint`` model and of `ThreadChange.setCheckpoints`.
@Suite @MainActor struct CheckpointTests {
  /// The time of each test checkpoint.
  static let createdAt = Date(timeIntervalSince1970: 1_000)

  /// A checkpoint for the turn with the index.
  static func checkpoint(turn: Int) -> Checkpoint {
    Checkpoint(
      id: CheckpointID("c\(turn)"),
      turnIndex: turn,
      createdAt: createdAt,
      label: "Turn \(turn)",
      capabilities: .router)
  }

  @Test func theCapabilitiesSetTheRestoreFlags() {
    for capabilities in CheckpointCapabilities.all {
      let checkpoint = Checkpoint(
        id: CheckpointID("c"), turnIndex: 0, createdAt: Self.createdAt, label: "Turn",
        capabilities: capabilities)
      #expect(checkpoint.canRestoreCode == capabilities.restoresCode)
      #expect(checkpoint.canRestoreConversation == capabilities.restoresConversation)
    }
  }

  @Test func theRouterCheckpointRestoresTheConversationOnly() {
    let checkpoint = Self.checkpoint(turn: 0)
    #expect(!checkpoint.canRestoreCode)
    #expect(checkpoint.canRestoreConversation)
  }

  @Test func setCheckpointsReplacesTheCheckpoints() {
    let thread = AgentThread()
    #expect(thread.checkpoints.isEmpty)

    thread.apply(.setCheckpoints([Self.checkpoint(turn: 0), Self.checkpoint(turn: 1)]))
    #expect(thread.checkpoints.map(\.turnIndex) == [0, 1])

    thread.apply(.setCheckpoints([Self.checkpoint(turn: 2)]))
    #expect(thread.checkpoints == [Self.checkpoint(turn: 2)])
  }

  @Test func clearRemovesTheCheckpoints() {
    let thread = AgentThread()
    thread.apply(.setCheckpoints([Self.checkpoint(turn: 0)]))

    thread.apply(.clear)

    #expect(thread.checkpoints.isEmpty)
  }

  @Test func theJSONFormKeepsEachField() throws {
    let checkpoint = Self.checkpoint(turn: 3)
    let data = try JSONEncoder().encode(checkpoint)
    #expect(try JSONDecoder().decode(Checkpoint.self, from: data) == checkpoint)
  }
}
