import EditorCommands
import EditorCommandsUI
import SwiftUI

/// The focus scope of one ``CodeBlockView`` of an answer (task ^4g2xbx1).
///
/// The modifier adds the segment `agentCodeBlock:<id>/<index>` to the path
/// of the enclosing scope, which is the scope of the message
/// (``AgentScopeKind/codeBlock(responseID:index:)``). The scope gives the
/// code of the block to the context of the commands
/// (`CommandContext.codeBlockCode`), so Copy Code Block copies it
/// (``AgentCommandVerb/copyCodeBlock``). The scope attaches the EditorKit
/// context menu of its path. The editor of the block has
/// `.editorTextMenu(.ancestor)`, so a right click on the code shows that
/// menu: the verbs of the message, and Copy Code Block. The palette shows
/// Copy Code Block while the focus is in the block. The Copy button of the
/// block copies the same code.
///
/// With no enclosing agent command scope, the modifier does not change the
/// view.
struct AgentCodeBlockScope: ViewModifier {
  /// The segment of the block.
  let segment: FocusSegment

  /// The code of the block, with no fence line.
  let code: String

  @Environment(\.agentCommandSystem) private var system

  func body(content: Content) -> some View {
    if let system {
      let code = code
      content
        .commandContextMenu(system, unavailable: .agentItem)
        .commandScope(segment: segment) { $0.codeBlockCode = code }
    } else {
      content
    }
  }
}

extension View {
  /// Puts this ``CodeBlockView`` of an answer in the scope of its block,
  /// with the context menu of that scope.
  ///
  /// - Parameters:
  ///   - segment: The segment of the block
  ///     (``AgentScopeKind/codeBlock(responseID:index:)``).
  ///   - code: The code of the block, with no fence line.
  /// - Returns: The view in the scope.
  func agentCodeBlockScope(_ segment: FocusSegment, code: String) -> some View {
    modifier(AgentCodeBlockScope(segment: segment, code: code))
  }
}
