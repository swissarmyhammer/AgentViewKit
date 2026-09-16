import Foundation

/// The identifier of a ``Checkpoint``.
public typealias CheckpointID = Identifier<Checkpoint>

/// One restore point of a thread (plan.md §9 E, research R13).
///
/// `Docs/decisions/checkpoints.md` records the fields. A source makes one
/// checkpoint after each completed turn and sends the full list with
/// ``ThreadChange/setCheckpoints(_:)``. ``CheckpointView`` shows the list as
/// a slider.
public nonisolated struct Checkpoint: Sendable, Hashable, Codable, Identifiable {
  /// The identifier of the restore point. For the Router, this is the id of
  /// the child session that the fork made.
  public let id: CheckpointID

  /// The zero-based index of the completed turn that the restore point
  /// follows.
  public let turnIndex: Int

  /// The host clock when the source made the restore point.
  public let createdAt: Date

  /// A short text for the slider stop, such as the start of the user prompt
  /// of the turn.
  public let label: String

  /// `true` when a restore can put the files of the working directory back.
  public let canRestoreCode: Bool

  /// `true` when a restore can put the conversation back.
  public let canRestoreConversation: Bool

  /// Makes a checkpoint with explicit restore flags.
  ///
  /// A source uses ``init(id:turnIndex:createdAt:label:capabilities:)``, so
  /// that the flags come from its ``CheckpointCapabilities``.
  ///
  /// - Parameters:
  ///   - id: The identifier of the restore point.
  ///   - turnIndex: The zero-based index of the turn that the point follows.
  ///   - createdAt: The host clock when the source made the point.
  ///   - label: The text of the slider stop.
  ///   - canRestoreCode: `true` when a restore can put the files back.
  ///   - canRestoreConversation: `true` when a restore can put the
  ///     conversation back.
  public init(
    id: CheckpointID,
    turnIndex: Int,
    createdAt: Date,
    label: String,
    canRestoreCode: Bool,
    canRestoreConversation: Bool
  ) {
    self.id = id
    self.turnIndex = turnIndex
    self.createdAt = createdAt
    self.label = label
    self.canRestoreCode = canRestoreCode
    self.canRestoreConversation = canRestoreConversation
  }

  /// Makes a checkpoint with the restore flags of a source.
  ///
  /// - Parameters:
  ///   - id: The identifier of the restore point.
  ///   - turnIndex: The zero-based index of the turn that the point follows.
  ///   - createdAt: The host clock when the source made the point.
  ///   - label: The text of the slider stop.
  ///   - capabilities: The capabilities of the source. They set
  ///     ``canRestoreCode`` and ``canRestoreConversation``.
  public init(
    id: CheckpointID,
    turnIndex: Int,
    createdAt: Date,
    label: String,
    capabilities: CheckpointCapabilities
  ) {
    self.init(
      id: id,
      turnIndex: turnIndex,
      createdAt: createdAt,
      label: label,
      canRestoreCode: capabilities.restoresCode,
      canRestoreConversation: capabilities.restoresConversation)
  }
}
