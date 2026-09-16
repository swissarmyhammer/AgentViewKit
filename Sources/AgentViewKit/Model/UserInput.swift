import Foundation

/// The input that the user sends to the agent (plan.md §3.4).
///
/// `AgentThreadActions.send(_:)` takes this value.
public nonisolated struct UserInput: Sendable, Hashable {
  /// The text of the input.
  public var text: String

  /// The files that the user attached, in order.
  ///
  /// The attachments task changes this type to the `Attachment` value type.
  public var attachments: [URL]

  /// Makes a user input.
  ///
  /// - Parameters:
  ///   - text: The text of the input.
  ///   - attachments: The files that the user attached, in order.
  public init(text: String, attachments: [URL] = []) {
    self.text = text
    self.attachments = attachments
  }
}
