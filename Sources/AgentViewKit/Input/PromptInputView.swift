import FoundationModelsACPClient
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
/// The composer has a list of attachments. While the list is not empty, an
/// ``AttachmentChips`` row shows above the editor. A dropped file, a dropped
/// image, and a pasted image go into the list
/// (``SwiftUI/View/attachmentDropDestination(_:)``). A submit sends the
/// files of the list, then the files that the text links to, each file one
/// time, and clears the list. When the host gives no `attachments` binding,
/// the composer keeps the list itself.
///
/// While the thread of the `agentThread` environment value runs a turn, a
/// submit adds the text to the ``SwiftUI/EnvironmentValues/promptQueue``, or
/// does nothing when there is no queue. When the turn ends, the view sends
/// the first queued item. A cancelled turn holds the queue. Command-Return
/// sends the text at once ("send now"). Esc stops the turn and keeps the
/// queue.
///
/// When the environment has a session model
/// (``SwiftUI/EnvironmentValues/sessionModel``), the composer uses it in
/// place of the thread and the thread actions (update.md §4.2 "Prompt
/// helper", §4.7 "Composer"). A submit sends `session/prompt` with
/// `SessionModel.prompt(_:meta:)`. The model shows the user message at once
/// with the send state `pending`, so the composer adds no row of its own.
/// Esc and the Stop button send `session/cancel` with
/// `SessionModel.cancel(meta:)`. The turn runs while `agentState` is
/// `running`. A submit also goes to the queue while a sent prompt has not
/// returned, and the view sends the next queued item only after the current
/// prompt returns and the agent does not run. Give the model to the composer
/// with `.environment(\.sessionModel, model)`:
///
/// ```swift
/// VStack {
///   AgentThreadView(session: model, actions: actions)
///   PromptInputView(text: $draft) {}
/// }
/// .environment(\.sessionModel, model)
/// ```
///
/// In an agent command scope (``SwiftUI/View/agentCommandScope(thread:)``),
/// a submit runs ``AgentCommandVerb/send`` and Esc runs
/// ``AgentCommandVerb/cancel``. The scope can then submit the composer and
/// focus its editor (``AgentCommandVerb/focusComposer``).
public struct PromptInputView<Editor: View, Accessory: View>: View {
  /// The text of the prompt.
  @Binding var text: AttributedString

  /// The attachments of the host, or `nil` when the composer keeps them.
  let hostAttachments: Binding<[Attachment]>?

  /// The attachments while the host gives no binding.
  @State private var ownAttachments: [Attachment] = []

  /// The host closure that runs after each submit.
  let onSubmit: PromptEditorContext.Submit

  /// The builder of the editor.
  let editor: (PromptEditorContext) -> Editor

  /// The builder of the accessory row.
  let accessory: () -> Accessory

  /// The number of prompts that the composer sent through the session model
  /// and that did not return yet.
  @State private var promptsInFlight = 0

  /// The turn verbs of the session model or of the thread actions.
  @EnvironmentComposerTurn private var turn
  @Environment(\.promptQueue) private var queue
  @Environment(\.agentTheme) private var theme
  @Environment(\.agentCommandTarget) private var commandTarget

  /// Makes a composer with a custom editor and a custom accessory row.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - attachments: The files to send with the next prompt, or `nil` to
  ///     let the composer keep them.
  ///   - onSubmit: The host closure that runs after each submit.
  ///   - editor: The builder of the editor. It gets the context of the
  ///     composer.
  ///   - accessory: The builder of the accessory row. The row reads the
  ///     submit action from ``SwiftUI/EnvironmentValues/promptSubmitAction``.
  public init(
    text: Binding<AttributedString>,
    attachments: Binding<[Attachment]>? = nil,
    onSubmit: @escaping PromptEditorContext.Submit,
    @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor,
    @ViewBuilder accessory: @escaping () -> Accessory
  ) {
    _text = text
    hostAttachments = attachments
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

  /// The attachments of the host, or the attachments that the composer keeps.
  private var attachments: Binding<[Attachment]> {
    hostAttachments
      ?? Binding(get: { ownAttachments }, set: { ownAttachments = $0 })
  }

  /// Whether the agent runs a turn.
  private var isRunning: Bool {
    turn.isRunning
  }

  /// Whether a submit goes to the queue: the agent runs a turn, or a prompt
  /// that the composer sent through the session model did not return yet.
  private var isBusy: Bool {
    isRunning || promptsInFlight > 0
  }

  /// Whether a submit sends or queues the text now.
  private var canSubmit: Bool {
    (!isBusy || queue != nil) && Self.message(from: text) != nil
  }

  public var body: some View {
    let context = PromptEditorContext(
      text: $text, placeholder: Self.placeholder, onSubmit: submitCommand,
      onSendNow: sendNow, onCancel: isRunning ? cancelCommand : nil,
      commands: turn.thread?.availableCommands ?? [])
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      if !attachments.wrappedValue.isEmpty {
        AttachmentChips(attachments: attachments)
      }
      editor(context)
        // A resolved request moves the VoiceOver focus back to the editor
        // (`PendingRequestsHost.focusTarget(old:new:)`).
        .accessibilityFocusTarget(StockPromptEditor.identifier)
        .background {
          if let commandTarget {
            ComposerCommandProbe(
              target: commandTarget, canSubmit: { canSubmit }, submit: submit, load: load)
          }
        }
      accessory()
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .attachmentDropDestination(attachments)
    .environment(
      \.promptSubmitAction, PromptSubmitAction(isEnabled: canSubmit, action: submitCommand))
    .environment(\.promptText, $text)
    .onChange(of: turn.thread?.state) { _, state in threadStateDidChange(state) }
    .onChange(of: turn.session?.agentState) { sendNextQueuedPrompt() }
  }

  /// Sends the first queued item when the thread finished its turn. A
  /// composer over a session model reads the agent state of the model, and
  /// not the thread.
  ///
  /// - Parameter state: The new state of the thread, or `nil`.
  private func threadStateDidChange(_ state: ThreadState?) {
    guard turn.session == nil, let state, let input = queue?.dequeueNext(after: state) else { return }
    send(input)
  }

  /// Sends the first queued item of a composer over a session model, when no
  /// sent prompt waits for its return and the agent state lets the queue go
  /// on (``PromptQueue/dequeueNext(afterAgentState:)``).
  private func sendNextQueuedPrompt() {
    guard let session = turn.session, promptsInFlight == 0,
      let input = queue?.dequeueNext(afterAgentState: session.agentState)
    else { return }
    send(input)
  }

  /// Counts a returned prompt of the session model, then sends the next
  /// queued item.
  private func promptDidReturn() {
    promptsInFlight -= 1
    sendNextQueuedPrompt()
  }

  /// Submits the text through ``AgentCommandVerb/send`` of the command scope,
  /// or directly when the composer is in no scope.
  private func submitCommand() {
    guard commandTarget?.perform(.send) != true else { return }
    submit()
  }

  /// Stops the turn through ``AgentCommandVerb/cancel`` of the command
  /// scope, or directly when the composer is in no scope.
  private func cancelCommand() {
    guard commandTarget?.perform(.cancel) != true else { return }
    cancel()
  }

  /// Sends the text, or adds it to the queue while the thread runs a turn.
  /// Then clears the text and calls the host closure.
  private func submit() {
    guard canSubmit, let input = takeInput() else { return }
    if isBusy, let queue {
      queue.enqueue(input)
    } else {
      send(input)
    }
    onSubmit()
  }

  /// Replaces the text of the prompt. The attachment list does not change.
  ///
  /// - Parameter message: The new text.
  private func load(_ message: String) {
    text = AttributedString(message)
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
    turn.startCancel()
  }

  /// The files of a submit: the attachment list, then the files that the
  /// text links to.
  ///
  /// An editor marks a file reference, such as an `@file` chip of
  /// ``EditorKitPromptEditor``, with a `link` attribute that holds a file URL.
  ///
  /// - Parameters:
  ///   - attachments: The attachment list of the composer.
  ///   - text: The text of the prompt.
  /// - Returns: Each file URL one time, in list order and then in text order.
  static func attachmentURLs(_ attachments: [Attachment], in text: AttributedString) -> [URL] {
    var seen: Set<URL> = []
    let linked = text.runs.compactMap(\.link).filter(\.isFileURL)
    return (attachments.map(\.url) + linked).filter { seen.insert($0).inserted }
  }

  /// Clears the text and the attachment list, and returns them as an input.
  ///
  /// - Returns: The input, or `nil` when the text is blank. A blank text and
  ///   its attachment list do not change.
  private func takeInput() -> UserInput? {
    guard let message = Self.message(from: text) else { return nil }
    let urls = Self.attachmentURLs(attachments.wrappedValue, in: text)
    text = AttributedString()
    attachments.wrappedValue = []
    return UserInput(text: message, attachments: urls)
  }

  /// Sends an input through the session model, or through the thread
  /// actions when the environment has no session model.
  ///
  /// A prompt of the session model counts as in flight until it returns.
  ///
  /// - Parameter input: The input to send.
  private func send(_ input: UserInput) {
    guard turn.session != nil else {
      turn.actions?.startSend(input)
      return
    }
    promptsInFlight += 1
    turn.startPrompt(with: input, then: promptDidReturn)
  }
}

extension PromptInputView where Editor == StockPromptEditor, Accessory == DefaultPromptAccessory {
  /// Makes a composer with the stock editor and the default accessory row.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - attachments: The files to send with the next prompt, or `nil` to
  ///     let the composer keep them.
  ///   - onSubmit: The host closure that runs after each submit.
  public init(
    text: Binding<AttributedString>,
    attachments: Binding<[Attachment]>? = nil,
    onSubmit: @escaping PromptEditorContext.Submit
  ) {
    self.init(
      text: text, attachments: attachments, onSubmit: onSubmit,
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
  ///   - attachments: The files to send with the next prompt, or `nil` to
  ///     let the composer keep them.
  ///   - onSubmit: The host closure that runs after each submit.
  ///   - editor: The builder of the editor. It gets the context of the
  ///     composer.
  public init(
    text: Binding<AttributedString>,
    attachments: Binding<[Attachment]>? = nil,
    onSubmit: @escaping PromptEditorContext.Submit,
    @ViewBuilder editor: @escaping (PromptEditorContext) -> Editor
  ) {
    self.init(
      text: text, attachments: attachments, onSubmit: onSubmit, editor: editor,
      accessory: { DefaultPromptAccessory() })
  }
}
