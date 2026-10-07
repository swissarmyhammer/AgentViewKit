import FoundationModelsACPClient
import SwiftUI

/// The default accessory row of ``PromptInputView`` (plan.md §9 D).
///
/// The row shows the ``PermissionModePicker`` of the session model of the
/// environment (``SwiftUI/EnvironmentValues/sessionModel``), the
/// ``SpeechInputButton``, and the submit button in the `.glassProminent`
/// style. While the agent runs a turn, a Stop button replaces the submit
/// button. While the agent does not run a turn, a ``SuggestionsView`` above
/// the row shows the prompts of
/// ``SwiftUI/EnvironmentValues/promptSuggestions``. A host that has a list of
/// tools puts a ``ToolToggles`` in its own accessory row.
///
/// Each slot is hidden when its data is absent: the suggestions when the
/// list is empty, and the mic when
/// ``SwiftUI/EnvironmentValues/speechTranscriber`` is `nil`.
///
/// The row reads the session model from
/// ``SwiftUI/EnvironmentValues/sessionModel`` and the submit action from
/// ``SwiftUI/EnvironmentValues/promptSubmitAction``. The Stop button shows
/// while the `agentState` of the session model is `running`, and it sends
/// `session/cancel` with `SessionModel.cancel(meta:)` (update.md §4.2 "Other
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
  @Environment(\.agentTheme) private var theme

  /// Makes the accessory row.
  public init() {}

  /// Whether the agent runs a turn: the `agentState` of the session model
  /// is `running`.
  private var isRunning: Bool {
    session?.isRunning == true
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      if !isRunning {
        SuggestionsView(suggestions: suggestions)
      }
      HStack(spacing: theme.spacing.s) {
        if let session {
          PermissionModePicker(session: session)
            .labelsHidden()
            .fixedSize()
        }
        Spacer(minLength: theme.spacing.s)
        SpeechInputButton()
        if isRunning {
          stopButton
        } else {
          submitButton
        }
      }
    }
  }

  /// The button that submits the prompt.
  private var submitButton: some View {
    Button {
      submit()
    } label: {
      Label(String(localized: "Send"), systemImage: "arrow.up")
        .labelStyle(.iconOnly)
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .disabled(!submit.isEnabled)
    .help(String(localized: "Send the prompt"))
    .accessibilityIdentifier(Self.submitIdentifier)
  }

  /// The button that stops the current turn.
  private var stopButton: some View {
    Button {
      session?.startCancel()
    } label: {
      Label(String(localized: "Stop"), systemImage: "stop.fill")
        .labelStyle(.iconOnly)
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .help(String(localized: "Stop the current turn"))
    .accessibilityIdentifier(Self.stopIdentifier)
  }
}
