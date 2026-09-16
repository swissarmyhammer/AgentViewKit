import SwiftUI

/// The composer of a thread (plan.md §7, §9 D).
///
/// The view shows an editor and an accessory row in a Liquid Glass bar. The
/// editor and the accessory are slots. The short initializer uses
/// ``StockPromptEditor`` and ``DefaultPromptAccessory``:
///
/// ```swift
/// PromptInputView(text: $draft) { scrollToBottom() }
/// ```
///
/// A submit sends the text to ``AgentThreadActions/send(_:)`` of the
/// `threadActions` environment value, clears the text, and then calls
/// `onSubmit`. A submit does nothing while the text is blank or while the
/// thread of the `agentThread` environment value runs a turn.
public struct PromptInputView<Editor: View, Accessory: View>: View {
  /// The text of the prompt.
  @Binding var text: AttributedString

  /// The host closure that runs after each submit.
  let onSubmit: PromptEditorContext.Submit

  /// The builder of the editor.
  let editor: (PromptEditorContext) -> Editor

  /// The builder of the accessory row.
  let accessory: () -> Accessory

  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions
  @Environment(\.agentTheme) private var theme

  /// Makes a composer with a custom editor and a custom accessory row.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - onSubmit: The host closure that runs after each submit.
  ///   - editor: The builder of the editor. It gets the context of the
  ///     composer.
  ///   - accessory: The builder of the accessory row. The row reads the
  ///     submit action from ``SwiftUI/EnvironmentValues/promptSubmitAction``.
  public init(
    text: Binding<AttributedString>,
    onSubmit: @escaping PromptEditorContext.Submit,
    @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    _text = text
    self.onSubmit = onSubmit
    self.editor = editor
    self.accessory = accessory
  }

  /// The text that the editor shows while the prompt is empty.
  static var placeholder: String {
    String(localized: "Message the agent")
  }

  /// The text that a submit sends, or `nil` when the text is blank.
  ///
  /// - Parameter text: The text of the prompt.
  /// - Returns: The plain text, or `nil` when it has only white space.
  static func message(from text: AttributedString) -> String? {
    let message = String(text.characters)
    let isBlank = message.allSatisfy(\.isWhitespace)
    return isBlank ? nil : message
  }

  /// Whether a submit sends the text now.
  private var canSubmit: Bool {
    thread?.state != .running && Self.message(from: text) != nil
  }

  public var body: some View {
    let context = PromptEditorContext(
      text: $text, placeholder: Self.placeholder, onSubmit: submit,
      commands: thread?.availableCommands ?? [])
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      editor(context)
      accessory()
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .environment(\.promptSubmitAction, PromptSubmitAction(isEnabled: canSubmit, action: submit))
  }

  /// Sends the text, clears it, and calls the host closure.
  private func submit() {
    guard canSubmit, let message = Self.message(from: text) else { return }
    text = AttributedString()
    let actions = actions
    Task { await actions.send(UserInput(text: message)) }
    onSubmit()
  }
}

extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory {
  /// Makes a composer with the stock editor and the default accessory row.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - onSubmit: The host closure that runs after each submit.
  public init(text: Binding<AttributedString>, onSubmit: @escaping PromptEditorContext.Submit) {
    self.init(
      text: text, onSubmit: onSubmit,
      editor: { StockPromptEditor(context: $0) },
      accessory: { DefaultPromptAccessory() })
  }
}

extension PromptInputView where Accessory == DefaultPromptAccessory {
  /// Makes a composer with a custom editor and the default accessory row.
  ///
  /// Use the `editor:` label. A trailing closure with no label binds to
  /// `onSubmit`.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - onSubmit: The host closure that runs after each submit.
  ///   - editor: The builder of the editor. It gets the context of the
  ///     composer.
  public init(
    text: Binding<AttributedString>,
    onSubmit: @escaping PromptEditorContext.Submit,
    @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor
  ) {
    self.init(
      text: text, onSubmit: onSubmit, editor: editor,
      accessory: { DefaultPromptAccessory() })
  }
}
