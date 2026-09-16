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
/// `onSubmit`. A submit does nothing while the text is blank.
///
/// While the thread of the `agentThread` environment value runs a turn, a
/// submit adds the text to the ``SwiftUI/EnvironmentValues/promptQueue``, or
/// does nothing when there is no queue. When the turn ends, the view sends
/// the first queued item. A cancelled turn holds the queue. Command-Return
/// sends the text at once ("send now"). Esc stops the turn and keeps the
/// queue.
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
  @Environment(\.promptQueue) private var queue
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

  /// Whether the thread runs a turn.
  private var isRunning: Bool {
    thread?.state == .running
  }

  /// Whether a submit sends or queues the text now.
  private var canSubmit: Bool {
    (!isRunning || queue != nil) && Self.message(from: text) != nil
  }

  public var body: some View {
    let context = PromptEditorContext(
      text: $text, placeholder: Self.placeholder, onSubmit: submit,
      onSendNow: sendNow, onCancel: isRunning ? cancel : nil,
      commands: thread?.availableCommands ?? [])
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      editor(context)
      accessory()
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .environment(\.promptSubmitAction, PromptSubmitAction(isEnabled: canSubmit, action: submit))
    .onChange(of: thread?.state) { _, state in
      guard let state, let input = queue?.dequeueNext(after: state) else { return }
      send(input)
    }
  }

  /// Sends the text, or adds it to the queue while the thread runs a turn.
  /// Then clears the text and calls the host closure.
  private func submit() {
    guard canSubmit, let input = takeInput() else { return }
    if isRunning, let queue {
      queue.enqueue(input)
    } else {
      send(input)
    }
    onSubmit()
  }

  /// Sends the text at once, also while the thread runs a turn. Then clears
  /// the text and calls the host closure.
  private func sendNow() {
    guard let input = takeInput() else { return }
    send(input)
    onSubmit()
  }

  /// Stops the current turn. The text and the queue do not change.
  private func cancel() {
    let actions = actions
    Task { await actions.cancel() }
  }

  /// The files that the text links to, for the attachments of a submit.
  ///
  /// An editor marks a file reference, such as an `@file` chip of
  /// ``EditorKitPromptEditor``, with a `link` attribute that holds a file URL.
  ///
  /// - Parameter text: The text of the prompt.
  /// - Returns: Each linked file URL one time, in text order.
  static func attachments(in text: AttributedString) -> [URL] {
    var seen: Set<URL> = []
    return text.runs.compactMap(\.link).filter { $0.isFileURL && seen.insert($0).inserted }
  }

  /// Clears the text and returns it as an input.
  ///
  /// - Returns: The input, or `nil` when the text is blank. A blank text does
  ///   not change.
  private func takeInput() -> UserInput? {
    guard let message = Self.message(from: text) else { return nil }
    let attachments = Self.attachments(in: text)
    text = AttributedString()
    return UserInput(text: message, attachments: attachments)
  }

  /// Sends an input through the thread actions.
  ///
  /// - Parameter input: The input to send.
  private func send(_ input: UserInput) {
    let actions = actions
    Task { await actions.send(input) }
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
