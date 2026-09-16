import SwiftUI

/// The values that ``PromptInputView`` gives to its editor (plan.md §7).
///
/// The stock editor and each custom editor get the same context. An editor
/// shows ``text``, shows ``placeholder`` while the text is empty, and calls
/// ``onSubmit`` when the user submits the prompt. Command-Return calls
/// ``onSendNow``, and Esc calls ``onCancel``. A completion source reads
/// ``commands``.
public struct PromptEditorContext {
  /// A closure that submits the prompt.
  public typealias Submit = @MainActor () -> Void

  /// The text of the prompt.
  public let text: Binding<AttributedString>

  /// The text that the editor shows while the prompt is empty.
  public let placeholder: String

  /// The closure that submits the prompt.
  ///
  /// The closure sends the text to the agent and clears the text. While the
  /// thread runs a turn, the closure adds the text to the
  /// ``SwiftUI/EnvironmentValues/promptQueue``, or does nothing when there is
  /// no queue. It does nothing while the text is blank.
  public let onSubmit: Submit

  /// The closure that sends the prompt at once, also while the thread runs a
  /// turn ("send now").
  ///
  /// The closure sends the text to the agent and clears the text. It does
  /// nothing while the text is blank.
  public let onSendNow: Submit

  /// The closure that stops the current turn, or `nil` while the thread does
  /// not run a turn.
  ///
  /// The closure calls ``AgentThreadActions/cancel()``. The text and the
  /// queue do not change.
  public let onCancel: Submit?

  /// The slash commands of the thread, for the slash completion source.
  public let commands: [SlashCommand]

  /// Makes an editor context.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - placeholder: The text that the editor shows while the prompt is
  ///     empty.
  ///   - onSubmit: The closure that submits the prompt.
  ///   - onSendNow: The closure that sends the prompt at once. The default
  ///     is `onSubmit`.
  ///   - onCancel: The closure that stops the current turn, or `nil` while
  ///     the thread does not run a turn.
  ///   - commands: The slash commands of the thread.
  public init(
    text: Binding<AttributedString>,
    placeholder: String,
    onSubmit: @escaping Submit,
    onSendNow: Submit? = nil,
    onCancel: Submit? = nil,
    commands: [SlashCommand] = []
  ) {
    self.text = text
    self.placeholder = placeholder
    self.onSubmit = onSubmit
    self.onSendNow = onSendNow ?? onSubmit
    self.onCancel = onCancel
    self.commands = commands
  }
}

/// The submit action of the nearest ``PromptInputView``.
///
/// ``PromptInputView`` puts this value in the environment of its editor and
/// its accessory. A custom accessory reads it from
/// ``SwiftUI/EnvironmentValues/promptSubmitAction`` and calls it as a
/// function, as ``DefaultPromptAccessory`` does.
public struct PromptSubmitAction {
  /// Whether a call submits the prompt. The value is `false` while the text
  /// is blank, and while the thread runs a turn with no
  /// ``SwiftUI/EnvironmentValues/promptQueue``.
  public let isEnabled: Bool

  /// The closure that submits the prompt.
  private let action: PromptEditorContext.Submit

  /// Makes a submit action.
  ///
  /// - Parameters:
  ///   - isEnabled: Whether a call submits the prompt.
  ///   - action: The closure that submits the prompt.
  public init(isEnabled: Bool, action: @escaping PromptEditorContext.Submit) {
    self.isEnabled = isEnabled
    self.action = action
  }

  /// Submits the prompt when ``isEnabled`` is `true`.
  public func callAsFunction() {
    guard isEnabled else { return }
    action()
  }
}

extension EnvironmentValues {
  /// The submit action of the nearest ``PromptInputView``.
  ///
  /// The default is disabled and does nothing.
  @Entry public var promptSubmitAction = PromptSubmitAction(isEnabled: false) {}
}
