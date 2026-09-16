import SwiftUI

/// The default editor of ``PromptInputView``: a stock `TextEditor`
/// (plan.md §7, §9 D).
///
/// Return calls ``PromptEditorContext/onSubmit``. Shift-Return does not
/// submit, so the text editor inserts a newline. The editor shows the
/// placeholder of the context while the text is empty.
public struct StockPromptEditor: View {
  /// The accessibility identifier of the editor.
  public static let identifier = "prompt-editor"

  /// The smallest height of the editor, in points.
  static let minimumHeight: CGFloat = 36

  /// The largest height of the editor, in points. Longer text scrolls.
  static let maximumHeight: CGFloat = 200

  /// The values that the composer gives.
  let context: PromptEditorContext

  @Environment(\.agentTheme) private var theme

  /// Makes the editor.
  ///
  /// - Parameter context: The values that the composer gives.
  public init(context: PromptEditorContext) {
    self.context = context
  }

  /// Whether a key press submits the prompt.
  ///
  /// - Parameter modifiers: The modifier keys of the press.
  /// - Returns: `false` when the press holds Shift, so that the editor
  ///   inserts a newline, and `true` otherwise.
  static func submits(with modifiers: EventModifiers) -> Bool {
    !modifiers.contains(.shift)
  }

  public var body: some View {
    TextEditor(text: context.text)
      .font(theme.proseFont)
      .scrollContentBackground(.hidden)
      .frame(minHeight: Self.minimumHeight, maxHeight: Self.maximumHeight)
      .fixedSize(horizontal: false, vertical: true)
      .overlay(alignment: .topLeading) {
        if context.text.wrappedValue.characters.isEmpty {
          Text(context.placeholder)
            .font(theme.proseFont)
            .foregroundStyle(.tertiary)
            .padding(.leading, theme.spacing.xs)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }
      .onKeyPress(.return, phases: .down) { press in
        guard Self.submits(with: press.modifiers) else { return .ignored }
        context.onSubmit()
        return .handled
      }
      .accessibilityLabel(context.placeholder)
      .accessibilityIdentifier(Self.identifier)
  }
}
