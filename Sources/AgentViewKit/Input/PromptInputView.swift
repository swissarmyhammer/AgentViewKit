import FoundationModelsACPClient
import SwiftUI

/// The composer of a thread (plan.md §7, §9 D).
///
/// The view shows a field and an accessory row in one `GlassEffectContainer`
/// (D110 (c)). In the composer slot of an ``AgentThreadView``, the composer
/// makes no container of its own: it is in the one container of the floating
/// controls of the thread, with the scroll-to-bottom pill. The field holds
/// the attachment chips and the editor, and it is on the floating glass of
/// the kit (``SwiftUI/View/agentFloatingGlass(id:)``).
/// The accessory row is below the field and not on that glass, so its glass
/// buttons are not glass on glass. A menu of the editor, for example the
/// completion list of ``EditorKitPromptEditor``, shows above the field on its
/// own floating glass, in the same container. The field glass and the menu
/// glass each have a ``FloatingGlassID`` in the glass namespace of the
/// container, so the menu morphs when it shows and hides (D113 answer 2). The
/// composer adds no animation of its own, so while Reduce Motion is on no
/// glass shape morphs (plan.md §6).
///
/// The editor and the accessory are slots. The short initializer uses
/// ``EditorKitPromptEditor`` and ``DefaultPromptAccessory``:
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
/// advertises `embeddedContext`, else as a resource link. In the composer
/// slot of an ``AgentThreadView``, the thread view gives both models to the
/// composer, and the composer is in the focus scope of the thread. Out of a
/// thread view, give both models to the composer in the environment, and put
/// the composer, the thread view and the ``RequestDeck`` in one
/// ``SwiftUI/View/accessibilityFocusScope()``. The ``RequestDeck``
/// documentation shows the full example.
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
    // The field, the menu of the editor and the accessory are siblings in one
    // container. Only the field and the menu are on glass, so the glass
    // buttons of the accessory are not glass on glass, and the container
    // blends their shapes (D110 (c)). In the floating controls of a thread
    // view, the composer uses the container of the thread.
    FloatingGlassContainer(spacing: theme.spacing.s) {
      VStack(alignment: .leading, spacing: theme.spacing.s) {
        field(context)
        accessory()
      }
    }
    .disabled(isSessionClosed)
    .attachmentDropDestination(attachments)
    .environment(
      \.promptSubmitAction, PromptSubmitAction(isEnabled: canSubmit, action: submitCommand))
    .environment(\.promptText, $text)
  }

  /// The field of the composer: the attachment chips and the editor, on the
  /// floating glass of the kit.
  ///
  /// - Parameter context: The context that the editor gets.
  /// - Returns: The field on its surface.
  private func field(_ context: PromptEditorContext) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      if !attachments.wrappedValue.isEmpty {
        AttachmentChips(attachments: attachments)
      }
      editor(context)
        // A resolved request moves the VoiceOver focus back to the editor
        // (`RequestDeck`).
        .accessibilityFocusTarget(EditorKitPromptEditor.identifier)
        .background {
          if let commandTarget {
            ComposerCommandProbe(
              target: commandTarget, canSubmit: { canSubmit }, submit: submit, load: load)
          }
        }
    }
    .modifier(PromptFieldSurface())
    // The menu of the editor is after the field surface, so it is a sibling
    // glass of the field glass in the container, not glass on glass.
    .overlayPreferenceValue(PromptEditorMenuKey.self, alignment: .topLeading) { menu in
      if let menu {
        PromptEditorMenuLayer(menu: menu)
      }
    }
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

extension PromptInputView where Editor == EditorKitPromptEditor, Accessory == DefaultPromptAccessory {
  /// Makes a composer with the EditorKit editor (``EditorKitPromptEditor``)
  /// and the default accessory row.
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
      editor: { EditorKitPromptEditor(context: $0) },
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

/// The surface of the field of ``PromptInputView``: the attachment chips and
/// the editor (D110 (c)).
///
/// The surface pads the field with the medium spacing of the theme, and puts
/// it on the floating glass of the kit, with the id
/// ``FloatingGlassID/composerField``
/// (``SwiftUI/View/agentFloatingGlass(id:)``). The accessory row of the
/// composer is not on this surface. Thus the glass buttons of the accessory
/// are not glass on glass. The menu of the editor (``PromptEditorMenu``) is
/// not on this surface either. The menu shows and hides next to the field
/// glass, so the field glass has an id, and the change morphs (D113 answer 2).
///
/// The surface is one accessibility container with ``identifier``, so that a
/// hosted test can read its frame. The chips and the editor stay separate
/// accessibility elements in it.
struct PromptFieldSurface: ViewModifier {
  /// The accessibility identifier of the field surface.
  static let identifier = "prompt-field-surface"

  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    content
      .padding(theme.spacing.m)
      .agentFloatingGlass(id: .composerField)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(Self.identifier)
  }
}

/// A menu that the editor of ``PromptInputView`` shows above the field, for
/// example the completion list of ``EditorKitPromptEditor``.
///
/// The editor is in the field glass. So the editor gives the menu with no
/// glass, and the composer puts it on its own glass (D110 (c)).
struct PromptEditorMenu {
  /// The bounds of the editor that gives the menu.
  let anchor: Anchor<CGRect>

  /// The horizontal offset of the caret from the leading edge of the editor,
  /// in points. The menu starts there.
  let caretOffset: CGFloat

  /// The width of the content, in points, so that the layer keeps the menu
  /// inside the field.
  let width: CGFloat

  /// The content of the menu, with no glass.
  let content: AnyView
}

/// The preference that carries the menu of the editor to ``PromptInputView``.
struct PromptEditorMenuKey: PreferenceKey {
  static var defaultValue: PromptEditorMenu? { nil }

  /// Keeps the first menu, so that one editor gives the menu.
  ///
  /// - Parameters:
  ///   - value: The menu so far.
  ///   - nextValue: The menu of the next view.
  static func reduce(value: inout PromptEditorMenu?, nextValue: () -> PromptEditorMenu?) {
    value = value ?? nextValue()
  }
}

/// The layer that shows a ``PromptEditorMenu`` above the field of
/// ``PromptInputView``, on the floating glass of the kit, with the id
/// ``FloatingGlassID/editorMenu`` (``SwiftUI/View/agentFloatingGlass(id:)``).
///
/// The menu shows and hides next to the field glass in one container, so the
/// change morphs (D113 answer 2). The layer adds no animation, so no morph
/// runs while Reduce Motion is on.
///
/// The layer fills the field. The leading edge of the menu is at the caret of
/// the editor, and the menu stays inside the field: near the trailing edge it
/// moves back so that its trailing edge is the trailing edge of the field. The
/// bottom edge of the menu is the small spacing of the theme above the top
/// edge of the field. The menu adds no fill of its own: its one surface is
/// the floating glass.
struct PromptEditorMenuLayer: View {
  /// The menu to show.
  let menu: PromptEditorMenu

  @Environment(\.agentTheme) private var theme

  /// The leading edge of the menu in the field.
  ///
  /// - Parameters:
  ///   - caret: The caret, from the leading edge of the field, in points.
  ///   - width: The width of the menu, in points.
  ///   - fieldWidth: The width of the field, in points.
  /// - Returns: The caret, or the leading edge that puts the trailing edge of
  ///   the menu at the trailing edge of the field, whichever is less, and no
  ///   less than the leading edge of the field.
  static func leading(caret: CGFloat, width: CGFloat, fieldWidth: CGFloat) -> CGFloat {
    max(0, min(caret, fieldWidth - width))
  }

  var body: some View {
    GeometryReader { proxy in
      menu.content
        .agentFloatingGlass(id: .editorMenu)
        .padding(
          .leading,
          Self.leading(
            caret: proxy[menu.anchor].minX + menu.caretOffset, width: menu.width,
            fieldWidth: proxy.size.width))
        .padding(.bottom, theme.spacing.s)
        // A frame with no height at the top of the field. The menu is at its
        // bottom, so the menu goes up from the top of the field.
        .frame(width: proxy.size.width, height: 0, alignment: .bottomLeading)
    }
  }
}

#Preview("Composer") {
  @Previewable @State var text = AttributedString()
  @Previewable @State var attachments = PreviewFixtures.attachments
  PromptInputView(text: $text, attachments: $attachments) {}
    .environment(\.sessionModel, .previewSample)
}
