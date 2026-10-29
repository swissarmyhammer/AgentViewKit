import EditorStyle
import SwiftUI

/// The content margin of the scroll views in a subtree, from one value of
/// the style of the theme (^rgsq3k4).
///
/// A kit list, such as the `AgentRowList` of AgentViewKit, has no padding around
/// its rows: the layout that holds the list gives that space. The modifier
/// reads the value at `step` from `\.editorStyle`, so a theme or a host that
/// sets the style changes the margin, and gives it to the scroll content
/// (`.contentMargins(_:for: .scrollContent)`). A scroll view in the content
/// of another scroll view keeps its own margins.
public struct ScrollContentMargins: ViewModifier {
  /// The value of the style that gives the margin, such as `\.tile.margin`.
  let step: KeyPath<EditorStyle, CGFloat>

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the margin of the scroll content.
  ///
  /// - Parameter step: The value of the style that gives the margin.
  public init(_ step: KeyPath<EditorStyle, CGFloat>) {
    self.step = step
  }

  /// Gives the margin of `step` to the scroll content of `content`.
  ///
  /// - Parameter content: The view whose scroll views get the margin.
  /// - Returns: The view with the margin of its scroll content.
  public func body(content: Content) -> some View {
    content.contentMargins(editorStyle[keyPath: step], for: .scrollContent)
  }
}

extension View {
  /// Insets the content of the scroll views of this view by one value of the
  /// style of the theme (``ScrollContentMargins``), such as the tile margin
  /// around the rows of a list:
  ///
  /// ```swift
  /// AgentRowList(items, id: \.name, scope: scope) { item in Text(item.name) }
  ///   .scrollContentMargins(\.tile.margin)
  /// ```
  ///
  /// - Parameter step: The value of `EditorStyle` that gives the margin.
  /// - Returns: The view with the margin of its scroll content.
  public func scrollContentMargins(_ step: KeyPath<EditorStyle, CGFloat>) -> some View {
    modifier(ScrollContentMargins(step))
  }
}
