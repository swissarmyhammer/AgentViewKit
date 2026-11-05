import EditorStyle
import EditorSwiftUI
import SwiftUI

/// A glass button that moves the conversation to its last item (plan.md §8):
/// an EditorKit `EditorButton` in the action look.
///
/// ``ConversationView`` shows the pill while the list is not pinned to the
/// bottom. The title tells the number of items that arrived after the user
/// scrolled up, for example "1 new". With no new item, the title is
/// "Scroll to Bottom".
///
/// The pill shows and hides above the composer, in the glass container of
/// the floating controls. Its glass has the id ``FloatingGlassID/scrollPill``
/// (`.floatingGlassID(_:)`), so the change morphs (D113 answer 2). The pill is
/// its own glass in that container, not a button on another glass, so it
/// declares the content surface and keeps the glass style
/// (`.editorButtonSurface(_:)`).
public struct ScrollToBottomPill: View {
  /// The accessibility identifier of the pill.
  public static let identifier = "scroll-to-bottom-pill"

  /// The SF Symbol name of the pill.
  static let symbolName = AgentSymbol.scrollToBottom

  /// The number of items that arrived after the list became unpinned.
  let newItemCount: Int

  /// The closure that the pill calls on a tap.
  let action: () -> Void

  /// Makes a pill.
  ///
  /// - Parameters:
  ///   - newItemCount: The number of items that arrived after the list
  ///     became unpinned, such as
  ///     ``ScrollAnchorManager/newItemsSinceUnpinned``.
  ///   - action: The closure that the pill calls on a tap.
  public init(newItemCount: Int, action: @escaping () -> Void) {
    self.newItemCount = newItemCount
    self.action = action
  }

  /// The title of the pill.
  ///
  /// - Parameter newItemCount: The number of new items.
  /// - Returns: "N new" when `newItemCount` is more than zero, otherwise
  ///   "Scroll to Bottom".
  public static func title(newItemCount: Int) -> String {
    guard newItemCount > 0 else { return String(localized: "Scroll to Bottom", bundle: .module) }
    return String(localized: "\(newItemCount) new", bundle: .module)
  }

  public var body: some View {
    EditorButton(Self.title(newItemCount: newItemCount), systemImage: Self.symbolName, look: .action, action: action)
    .editorButtonSurface(.content)
    .buttonBorderShape(.capsule)
    .floatingGlassID(FloatingGlassID.scrollPill)
    .accessibilityIdentifier(Self.identifier)
    .agentControlScope(Self.identifier)
  }
}

#Preview("Scroll to bottom") {
  let newItemCount = 3
  ScrollToBottomPill(newItemCount: newItemCount) {}
}
