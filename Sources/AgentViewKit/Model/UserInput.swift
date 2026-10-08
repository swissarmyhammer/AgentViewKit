import Foundation

/// The input that the user sends to the agent (plan.md §3.4).
///
/// The composer sends this value with `SessionModel.prompt(_:meta:)`.
public nonisolated struct UserInput: Sendable, Hashable {
  /// The text of the input.
  public var text: String

  /// The locations of the files that the user attached, in order.
  ///
  /// ACP has no value for a draft with local files. The composer makes the
  /// ACP content blocks of the prompt from these URLs when it sends the
  /// input. ``PromptInputView`` sends the URL of each ``Attachment`` of its
  /// list.
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
