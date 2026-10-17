import FoundationModelsACPClient
import SwiftUI

/// The default accessory row of ``PromptInputView`` (plan.md §9 D).
///
/// The row shows the ``PermissionModePicker`` of the session model of the
/// environment (``SwiftUI/EnvironmentValues/sessionModel``), the
/// ``SpeechInputButton``, and the submit button in the `.glassProminent`
/// style. The submit button shows at all times, so that the user can send a
/// second prompt while the agent works. While the user can cancel the work of
/// the session, a Stop button shows beside it. While the agent does not run,
/// a ``SuggestionsView`` above the row shows the prompts of
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
  @Environment(\.agentTheme) private var theme

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
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .disabled(!submit.isEnabled)
    .help(String(localized: "Send the prompt", bundle: .module))
    .accessibilityIdentifier(Self.submitIdentifier)
  }

  /// The button that cancels the work of the session.
  private var stopButton: some View {
    Button {
      session?.startCancel(reporting: reportRequestStart)
    } label: {
      Label(String(localized: "Stop", bundle: .module), systemImage: SharedSymbol.stop)
        .labelStyle(.iconOnly)
        .fontWeight(theme.symbolWeight)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .help(String(localized: "Stop the work of the agent", bundle: .module))
    .accessibilityIdentifier(Self.stopIdentifier)
  }
}
