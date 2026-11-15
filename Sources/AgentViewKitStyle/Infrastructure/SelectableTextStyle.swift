import SwiftUI

/// A style that shows a plain text that the user can select.
///
/// The views of this target show a selectable text with a SwiftUI `Text`
/// and `.textSelection(.enabled)` by default. A view kit with one selection
/// for a thread sets a style, so that the text takes part in that selection
/// (AgentViewKit `Docs/decisions/text-selection.md`). For example,
/// ``StatusTitleLayout`` shows its explanation with the style.
public protocol SelectableTextStyle {
  /// The view of the text.
  associatedtype Body: View

  /// Makes the view of a selectable text.
  ///
  /// - Parameter text: The text.
  /// - Returns: The view of the text.
  @MainActor @ViewBuilder func makeBody(text: String) -> Body
}

extension EnvironmentValues {
  /// The style of each selectable text in this view, or `nil` for a SwiftUI
  /// `Text` with `.textSelection(.enabled)`.
  @Entry var selectableTextStyle: ErasedStyle<String>? = nil
}

extension View {
  /// Sets the style of each selectable text of this target in this view.
  ///
  /// - Parameter style: The style of the text.
  /// - Returns: A view whose selectable texts show with `style`.
  public func selectableTextStyle<Style: SelectableTextStyle>(_ style: Style) -> some View {
    environment(\.selectableTextStyle, ErasedStyle(style.makeBody(text:)))
  }
}

/// A plain text that the user can select, in the
/// ``SelectableTextStyle`` of the environment.
struct StyledSelectableText: View {
  /// The text.
  let text: String

  @Environment(\.selectableTextStyle) private var style

  var body: some View {
    if let style {
      style.makeBody(configuration: text)
    } else {
      Text(text)
        .textSelection(.enabled)
    }
  }
}
