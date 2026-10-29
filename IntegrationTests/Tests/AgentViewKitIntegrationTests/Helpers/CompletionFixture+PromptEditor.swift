import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP

@testable import AgentViewKit

extension CompletionFixture {
  /// Makes a fixture over the completion engine that
  /// ``EditorKitPromptEditor`` composes for `commands` and `root`.
  ///
  /// - Parameters:
  ///   - text: The text of the document.
  ///   - commands: The slash commands of the session, or `nil` when the agent
  ///     did not report its commands.
  ///   - root: The file root, or `nil`.
  /// - Returns: The fixture.
  static func editor(_ text: String, commands: [AvailableCommand]?, root: URL?) -> CompletionFixture {
    CompletionFixture(text, engine: PromptEditorSession().engine(commands: commands, root: root, routes: []))
  }
}
