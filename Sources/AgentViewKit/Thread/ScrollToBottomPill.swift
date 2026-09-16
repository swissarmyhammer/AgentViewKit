import SwiftUI

/// A glass button that moves the conversation to its last item (plan.md §8).
///
/// ``ConversationView`` shows the pill while the list is not pinned to the
/// bottom. The title tells the number of items that arrived after the user
/// scrolled up, for example "1 new". With no new item, the title is
/// "Scroll to Bottom".
public struct ScrollToBottomPill: View {
  /// The accessibility identifier of the pill.
  public static let identifier = "scroll-to-bottom-pill"

  /// The SF Symbol name of the pill.
  static let symbolName = "arrow.down"

  /// The number of items that arrived after the list became unpinned.
  let newItemCount: Int

  /// The closure that the pill calls on a tap.
  let action: () -> Void

  @Environment(\.agentTheme) private var theme

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
    guard newItemCount > 0 else { return String(localized: "Scroll to Bottom") }
    return String(localized: "\(newItemCount) new")
  }

  public var body: some View {
    Button(action: action) {
      Label(Self.title(newItemCount: newItemCount), systemImage: Self.symbolName)
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .accessibilityIdentifier(Self.identifier)
  }
}
