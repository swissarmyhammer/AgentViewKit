import EditorSwiftUI
import SwiftUI

/// The one text selection of a thread (Docs/decisions/text-selection.md).
///
/// A thread has many text areas: each Markdown text of an answer, and each
/// code block, command output and JSON value, is a read-only EditorKit
/// `EditorView`, and each plain text is an EditorKit `EditorLabel`. Each
/// text area keeps a selection model of its own. Without this coordinator, a selection in one area stays when
/// the user selects text in a different area, so the thread shows more than
/// one selection.
///
/// Each text area is an owner. When the user starts a selection in an area,
/// the area claims the selection. The claim clears the selection of the
/// previous owner. A claim from the current owner does nothing.
///
/// The coordinator conforms to the EditorKit `TextSelectionRegion`, so that
/// each `EditorView` and each `EditorLabel` in the environment takes part
/// with no other change.
@MainActor
final class ThreadTextSelection: TextSelectionRegion {
  /// The area that holds the selection now, or `nil`.
  ///
  /// The reference is weak: an area that goes away has no selection to
  /// clear.
  private weak var owner: AnyObject?

  /// The function that clears the selection of ``owner``.
  private var clearOwner: (@MainActor () -> Void)?

  /// Gives the selection to `owner`, and clears the selection of the
  /// previous owner.
  ///
  /// - Parameters:
  ///   - owner: The area that now holds the selection.
  ///   - clear: The function that clears the selection of `owner`, when a
  ///     different area claims the selection later.
  func claim(_ owner: AnyObject, clear: @escaping @MainActor () -> Void) {
    if self.owner === owner {
      clearOwner = clear
      return
    }
    let previous = self.owner == nil ? nil : clearOwner
    self.owner = owner
    clearOwner = clear
    previous?()
  }

  /// Forgets `owner` when it holds the selection. The function does not
  /// clear the selection of `owner`.
  ///
  /// - Parameter owner: The area that goes away.
  func release(_ owner: AnyObject) {
    guard self.owner === owner else { return }
    self.owner = nil
    clearOwner = nil
  }
}

extension View {
  /// Gives the text areas below the view one selection
  /// (``ThreadTextSelection``), when the environment has no selection
  /// region yet.
  ///
  /// ``AgentThreadView`` and ``ConversationView`` apply this, so that a
  /// conversation in a thread view and a conversation that a host shows
  /// alone each have one selection.
  func threadTextSelection() -> some View {
    modifier(ThreadTextSelectionScope())
  }
}

/// Puts a ``ThreadTextSelection`` in the environment when the environment
/// has no selection region.
private struct ThreadTextSelectionScope: ViewModifier {
  @Environment(\.textSelectionRegion) private var outer
  @State private var own = ThreadTextSelection()

  func body(content: Content) -> some View {
    content
      .textSelectionRegion(outer ?? own)
  }
}
