import EditorCommandsUI
import EditorStyle
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
    }
  }

  /// The button that submits the prompt.
  private var submitButton: some View {
    Button {
      submit()
    } label: {
      Label(String(localized: "Send", bundle: .module), systemImage: SharedSymbol.send)
        .labelStyle(.iconOnly)
        .fontWeight(editorStyle.symbolWeight)
    }
    .buttonStyle(.glass)
    .glassForegroundStyle()
    .buttonBorderShape(.circle)
    .disabled(!submit.isEnabled)
    .help(String(localized: "Send the prompt", bundle: .module))
    .accessibilityIdentifier(Self.submitIdentifier)
    .agentControlScope(Self.submitIdentifier)
  }

  /// The button that cancels the work of the session.
  private var stopButton: some View {
    Button {
      session?.startCancel(reporting: reportRequestStart)
    } label: {
      Label(String(localized: "Stop", bundle: .module), systemImage: SharedSymbol.stop)
        .labelStyle(.iconOnly)
        .fontWeight(editorStyle.symbolWeight)
    }
    .buttonStyle(.glass)
    .glassForegroundStyle()
    .buttonBorderShape(.circle)
    .help(String(localized: "Stop the work of the agent", bundle: .module))
    .accessibilityIdentifier(Self.stopIdentifier)
    .agentControlScope(Self.stopIdentifier)
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
