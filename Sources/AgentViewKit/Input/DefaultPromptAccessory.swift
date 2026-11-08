import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI

/// The default accessory row of ``PromptInputView`` (plan.md §9 D).
///
/// The row shows the ``PermissionModePicker`` of the session model of the
/// environment (``SwiftUI/EnvironmentValues/sessionModel``), the
/// ``SpeechInputButton``, and the submit button. The submit button shows at
/// all times, so that the user can send a second prompt while the agent works.
/// While the user can cancel the work of the session, a Stop button shows
/// beside it.
///
/// No action of the row is prominent. The submit button and the Stop button
/// each use the `.glass` style, while the agent runs and at other times: a
/// prominent style gives the accent tint, and the accent is only for the
/// selection and the focus (the user decision of 2026-10-24, card ^k06v4gt).
///
/// While the agent does not run, a ``SuggestionsView`` above the row shows the
/// prompts of
/// ``SwiftUI/EnvironmentValues/promptSuggestions``. A host that has a list of
/// tools puts a ``ToolToggles`` in its own accessory row.
///
/// Each slot is hidden when its data is absent: the suggestions when the
/// list is empty, and the mic when
/// ``SwiftUI/EnvironmentValues/speechTranscriber`` is `nil`.
///
/// The row reads the session model from
/// ``SwiftUI/EnvironmentValues/sessionModel`` and the submit action from
/// ``SwiftUI/EnvironmentValues/promptSubmitAction``. The submit button keeps
/// the enable rule of that action. The Stop button shows while the one cancel
/// rule of the kit, ``AgentCommandTarget/canCancel(_:)``, is true: while the
/// agent runs, and while the session is idle with a pending request. It sends
/// `session/cancel` with `SessionModel.cancel(meta:)` (plan.md §3.2 "Other
/// requests"). The
/// attachment chips come in their own task. This row has no control for them
/// yet.
public struct DefaultPromptAccessory: View {
  /// The accessibility identifier of the submit button.
  public static let submitIdentifier = "prompt-submit"

  /// The accessibility identifier of the Stop button.
  public static let stopIdentifier = "prompt-stop"

  @Environment(\.sessionModel) private var session
  @Environment(\.promptSubmitAction) private var submit
  @Environment(\.promptSuggestions) private var suggestions
  @Environment(\.editorStyle) private var editorStyle

  /// The report that gets the method of the cancel that the Stop button
  /// starts, or `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

  /// Makes the accessory row.
  public init() {}

  /// Whether the agent runs: the `agentState` of the session model is
  /// `running`.
  private var isRunning: Bool {
    session?.isRunning == true
  }

  /// Whether the user can cancel the work of the session now: the one cancel
  /// rule of the kit, ``AgentCommandTarget/canCancel(_:)``.
  private var canCancel: Bool {
    session.map(AgentCommandTarget.canCancel) ?? false
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      if !isRunning {
        SuggestionsView(suggestions: suggestions)
      }
      HStack(spacing: editorStyle.spacing.s) {
        if let session {
          PermissionModePicker(session: session)
            .labelsHidden()
            .fixedSize()
        }
        Spacer(minLength: editorStyle.spacing.s)
        SpeechInputButton()
        if canCancel {
          stopButton
        }
        submitButton
      }
      // Each button of the accessory is its own glass in the container of
      // the floating controls, not a button on another glass, so it keeps
      // the glass style.
      .editorButtonSurface(.content)
    }
  }

  /// The button that submits the prompt.
  private var submitButton: some View {
    circleActionButton(
      title: String(localized: "Send", bundle: .module), symbol: AgentSymbol.send, identifier: Self.submitIdentifier
    ) {
      submit()
    }
    .disabled(!submit.isEnabled)
  }

  /// The button that cancels the work of the session.
  private var stopButton: some View {
    circleActionButton(
      title: String(localized: "Stop", bundle: .module), symbol: AgentSymbol.stop, identifier: Self.stopIdentifier
    ) {
      session?.startCancel(reporting: reportRequestStart)
    }
  }

  /// A round button of the accessory: an EditorKit `EditorButton` in the
  /// action look, made round by ``SwiftUI/View/circleAction(identifier:)``.
  ///
  /// - Parameters:
  ///   - title: The localized title of the button.
  ///   - symbol: The SF Symbol of the button.
  ///   - identifier: The accessibility identifier of the button, also the id
  ///     of its focus scope.
  ///   - action: What a press does.
  /// - Returns: The button.
  private func circleActionButton(
    title: String, symbol: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    EditorButton(title, systemImage: symbol, look: .action, action: action)
      .circleAction(identifier: identifier)
  }
}

#Preview("Prompt accessory") {
  @Previewable @State var text = AttributedString()
  DefaultPromptAccessory()
    .environment(\.sessionModel, .previewSample)
    .environment(\.promptText, $text)
    .environment(\.promptSubmitAction, PromptSubmitAction(isEnabled: true) {})
    .environment(\.promptSuggestions, PreviewFixtures.suggestions)
}
