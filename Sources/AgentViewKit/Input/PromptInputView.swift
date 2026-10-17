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
/// The composer reads the session model of the environment
/// (``SwiftUI/EnvironmentValues/sessionModel``) and calls its methods
/// directly (plan.md §3.2 "Prompt helper", §3.8 "Composer"). A submit sends
/// the text as `session/prompt` with `SessionModel.prompt(_:meta:)`, clears
/// the text, and then calls `onSubmit`. A submit does nothing while the text
/// is blank, or while the environment has no session model.
///
/// The composer has a list of attachments. While the list is not empty, an
/// ``AttachmentChips`` row shows above the editor. A dropped file, a dropped
/// image, and a pasted image go into the list
/// (``SwiftUI/View/attachmentDropDestination(_:)``). A submit sends the
/// files of the list, then the files that the text links to, each file one
/// time, and clears the list. When the host gives no `attachments` binding,
/// the composer keeps the list itself.
///
/// Each submit sends the text at once, also while the agent runs and while
/// an earlier prompt is open. The composer keeps no queue and does not wait
/// for the end of the work of a prompt. In ACP v2 the agent accepts a
/// `session/prompt` at once, and the agent decides how to handle a message
/// that comes while it runs. Command-Return also submits
/// the text. Esc cancels the work of the session while the agent runs,
/// while it requires action, and while it is idle with a pending permission
/// request or a pending elicitation. Esc uses the same rule as
/// ``AgentCommandVerb/cancel``.
///
/// The model shows the user message at once
/// with the send state `pending`, so the composer adds no row of its own.
/// Esc and the Stop button send `session/cancel` with
/// `SessionModel.cancel(meta:)`. The composer reads `agentState` and the
/// pending requests only for Esc and to show the Stop control. The editor
/// gets `SessionModel.availableCommands` as ``PromptEditorContext/commands``.
/// With no session model, the editor gets `nil`: no command menu. While
/// `SessionModel.isClosed` is true, the composer is disabled and a submit
/// sends nothing (plan.md §3.8 "Closed thread"). The composer reads
/// `isClosed` directly and keeps no copy.
///
/// The blocks of a prompt and the attachment chips follow the prompt
/// capabilities of the connection model of the environment
/// (``SwiftUI/EnvironmentValues/connectionModel``). The composer reads
/// `ConnectionModel.agentCapabilities` at the time of each submit and each
/// draw, and keeps no copy. An image goes out only when the agent advertises
/// `image`; else its chip shows the "not accepted" mark and the prompt does
/// not carry it. A file goes out as an embedded resource when the agent
/// advertises `embeddedContext`, else as a resource link. Give both models to
/// the composer in the environment, and put the composer, the thread view and
/// the ``RequestDeck`` in one ``SwiftUI/View/accessibilityFocusScope()``. The
/// ``RequestDeck`` documentation shows the full example.
///
/// In an agent command scope (``SwiftUI/View/agentCommandScope(session:)``),
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

  @Environment(\.sessionModel) private var session
  @Environment(\.connectionModel) private var connection
  @Environment(\.agentTheme) private var theme
  @Environment(\.agentCommandTarget) private var commandTarget
  @Environment(\.promptSubmitReport) private var reportSubmit

  /// The report that gets the method of the cancel that the composer starts
  /// with no command scope, or `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

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
    String(localized: "Message the agent", bundle: .module)
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

  /// Tells if Esc in the editor cancels the work of `session`.
  ///
  /// Esc reads the one cancel rule of the kit,
  /// ``AgentCommandTarget/canCancel(_:)``, which is also the rule of
  /// ``AgentCommandVerb/cancel``.
  ///
  /// - Parameter session: The session model of the environment, or `nil`.
  /// - Returns: `true` when the editor gets an Esc action. `false` when
  ///   there is no session model.
  static func cancelsOnEscape(in session: SessionModel?) -> Bool {
    session.map { AgentCommandTarget.canCancel($0) } ?? false
  }

  /// The attachments of the host, or the attachments that the composer keeps.
  private var attachments: Binding<[Attachment]> {
    hostAttachments
      ?? Binding(get: { ownAttachments }, set: { ownAttachments = $0 })
  }

  /// Whether a submit sends the text now: the text is not blank, and the
  /// environment has a session model that is not closed.
  private var canSubmit: Bool {
    Self.message(from: text) != nil && session?.isClosed == false
  }

  /// Whether the session model of the environment is closed, so the composer
  /// sends nothing (plan.md §3.8 "Closed thread"). The value reads
  /// `SessionModel.isClosed` directly.
  private var isSessionClosed: Bool {
    session?.isClosed == true
  }

  public var body: some View {
    let context = PromptEditorContext(
      text: $text, placeholder: Self.placeholder, onSubmit: submitCommand,
      onCancel: Self.cancelsOnEscape(in: session) ? cancelCommand : nil,
      commands: session?.availableCommands)
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      if !attachments.wrappedValue.isEmpty {
        AttachmentChips(attachments: attachments)
      }
      editor(context)
        // A resolved request moves the VoiceOver focus back to the editor
        // (`RequestDeck`).
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
    .disabled(isSessionClosed)
    .attachmentDropDestination(attachments)
    .environment(
      \.promptSubmitAction, PromptSubmitAction(isEnabled: canSubmit, action: submitCommand))
    .environment(\.promptText, $text)
  }

  /// Submits the text through ``AgentCommandVerb/send`` of the command scope,
  /// or directly when the composer is in no scope.
  private func submitCommand() {
    guard commandTarget?.perform(.send) != true else { return }
    submit()
  }

  /// Cancels the work of the session through ``AgentCommandVerb/cancel`` of
  /// the command scope, or directly when the composer is in no scope.
  private func cancelCommand() {
    guard commandTarget?.perform(.cancel) != true else { return }
    cancel()
  }

  /// Sends the text at once, also while the agent runs. Then clears
  /// the text and calls the host closure.
  ///
  /// The prompt blocks follow the prompt capabilities of the connection
  /// model, read at the time of the submit. The composer reports the outcome
  /// through ``SwiftUI/EnvironmentValues/promptSubmitReport``.
  private func submit() {
    guard canSubmit, let session, let input = takeInput() else {
      reportSubmit?(.notSent)
      return
    }
    session.startPrompt(with: input, accepting: connection?.promptCapabilities)
    reportSubmit?(.sent)
    onSubmit()
  }

  /// Replaces the text of the prompt. The attachment list does not change.
  ///
  /// - Parameter message: The new text.
  private func load(_ message: String) {
    text = AttributedString(message)
  }

  /// Cancels the work of the session with `SessionModel.cancel(meta:)`. The
  /// text does not change.
  private func cancel() {
    session?.startCancel(reporting: reportRequestStart)
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
