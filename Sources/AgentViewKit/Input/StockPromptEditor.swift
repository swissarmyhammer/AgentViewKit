import SwiftUI

/// The default editor of ``PromptInputView``: a stock `TextEditor`
/// (plan.md §7, §9 D).
///
/// Return calls ``PromptEditorContext/onSubmit``. Command-Return calls
/// ``PromptEditorContext/onSendNow``. Shift-Return does not submit, so the
/// text editor inserts a newline. Esc calls ``PromptEditorContext/onCancel``
/// while the thread runs a turn. The editor shows the placeholder of the
/// context while the text is empty.
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

  /// The closure that a Return press calls.
  ///
  /// - Parameters:
  ///   - modifiers: The modifier keys of the press.
  ///   - context: The values that the composer gives.
  /// - Returns: `nil` when the press holds Shift, so that the editor inserts a
  ///   newline. ``PromptEditorContext/onSendNow`` when the press holds
  ///   Command. ``PromptEditorContext/onSubmit`` otherwise.
  static func returnAction(
    for modifiers: EventModifiers, in context: PromptEditorContext
  ) -> PromptEditorContext.Submit? {
    if modifiers.contains(.shift) { return nil }
    return modifiers.contains(.command) ? context.onSendNow : context.onSubmit
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
        guard let action = Self.returnAction(for: press.modifiers, in: context) else {
          return .ignored
        }
        action()
        return .handled
      }
      .onKeyPress(.escape, phases: .down) { _ in
        guard let cancel = context.onCancel else { return .ignored }
        cancel()
        return .handled
      }
      .accessibilityLabel(context.placeholder)
      .accessibilityIdentifier(Self.identifier)
  }
}
