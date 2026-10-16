import FoundationModelsACP
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
  /// The closure sends the text to the agent at once, also while the agent
  /// runs and while an earlier prompt is open, and clears the text. It does
  /// nothing while the text is blank.
  public let onSubmit: Submit

  /// The closure that sends the prompt at once ("send now").
  ///
  /// The closure sends the text to the agent and clears the text. It does
  /// nothing while the text is blank. ``PromptInputView`` gives the same
  /// closure as ``onSubmit``, because each submit sends at once.
  public let onSendNow: Submit

  /// The closure that cancels the work of the session, or `nil` while the
  /// user cannot cancel.
  ///
  /// ``PromptInputView`` gives the closure while the agent runs, while it
  /// requires action, and while it is idle with a pending permission request
  /// or a pending elicitation: the same rule as ``AgentCommandVerb/cancel``.
  /// The closure calls `SessionModel.cancel(meta:)` of the session model of
  /// the environment. The text does not change.
  public let onCancel: Submit?

  /// The slash commands of the session, for the slash completion source.
  ///
  /// The value is `SessionModel.availableCommands`. `nil` tells that the
  /// agent did not report its commands, and `[]` tells that the agent
  /// reported no command (``SlashCommandSource``).
  public let commands: [AvailableCommand]?

  /// Makes an editor context.
  ///
  /// - Parameters:
  ///   - text: The text of the prompt.
  ///   - placeholder: The text that the editor shows while the prompt is
  ///     empty.
  ///   - onSubmit: The closure that submits the prompt.
  ///   - onSendNow: The closure that sends the prompt at once. The default
  ///     is `onSubmit`.
  ///   - onCancel: The closure that cancels the work of the session, or
  ///     `nil` while the user cannot cancel.
  ///   - commands: The slash commands of the session, or `nil` when the
  ///     agent did not report its commands.
  public init(
    text: Binding<AttributedString>,
    placeholder: String,
    onSubmit: @escaping Submit,
    onSendNow: Submit? = nil,
    onCancel: Submit? = nil,
    commands: [AvailableCommand]? = nil
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
  /// is blank.
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

  /// The text of the nearest ``PromptInputView``: the same binding as
  /// ``PromptEditorContext/text``.
  ///
  /// ``PromptInputView`` puts this value in the environment of its editor and
  /// its accessory. ``SuggestionsView`` and ``SpeechInputButton`` write the
  /// composer text through it. The value is `nil` outside a composer.
  @Entry public var promptText: Binding<AttributedString>? = nil

  /// The follow-up prompts that ``DefaultPromptAccessory`` shows in a
  /// ``SuggestionsView``.
  ///
  /// The default is empty, and an empty list hides the view. Set the value
  /// with ``SwiftUI/View/promptSuggestions(_:)``.
  @Entry public var promptSuggestions: [String] = []
}

/// What the composer did with one submit or one Shift-Return press.
///
/// The composer reports each outcome through
/// ``SwiftUI/EnvironmentValues/promptSubmitReport``. A test reads the report
/// to learn that the composer handled a key, and that it started no prompt.
enum PromptSubmitOutcome: Equatable {
  /// The composer started a prompt.
  case sent

  /// The composer started no prompt, for example because the text is blank.
  case notSent

  /// The press held Shift, so the editor inserted a newline and the composer
  /// did not submit.
  case newline
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets each ``PromptSubmitOutcome`` of the
  /// nearest ``PromptInputView`` and its ``StockPromptEditor``, or `nil`.
  ///
  /// The composer calls the report in the same step as the submit decision.
  @Entry var promptSubmitReport: ObservationReport<PromptSubmitOutcome>? = nil
}

extension View {
  /// Sets the follow-up prompts that ``DefaultPromptAccessory`` shows for
  /// this view and each view in it.
  ///
  /// Give the prompts for the empty state, or the follow-ups after the agent
  /// stops.
  ///
  /// - Parameter suggestions: The prompts to show. An empty list hides the
  ///   ``SuggestionsView``.
  /// - Returns: A view that gives `suggestions` to its subtree.
  public func promptSuggestions(_ suggestions: [String]) -> some View {
    environment(\.promptSuggestions, suggestions)
  }
}
