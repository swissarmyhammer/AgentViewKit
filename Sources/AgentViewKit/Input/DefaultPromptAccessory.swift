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
/// Only one action of the row is prominent at a time (D110 (c)). While the
/// agent runs, the Stop button uses the `.glassProminent` style and the submit
/// button uses the `.glass` style. At other times, the submit button is the
/// prominent action, and the Stop button, if it shows, uses the `.glass`
/// style.
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
  @Environment(\.agentTheme) private var theme

  /// The report that gets the method of the cancel that the Stop button
  /// starts, or `nil`.
  @Environment(\.requestStartReport) private var reportRequestStart

  /// Makes the accessory row.
  public init() {}

  /// An action of the row that can be the one prominent action.
  enum Action: Equatable {
    /// The submit button, which sends the prompt.
    case send

    /// The Stop button, which cancels the work of the session.
    case stop
  }

  /// The glass button style of an ``Action``.
  enum ActionStyle: Equatable {
    /// The `.glass` style, for an action that is not prominent.
    case glass

    /// The `.glassProminent` style, for the one prominent action.
    case glassProminent
  }

  /// Whether the agent runs: the `agentState` of `session` is `running`.
  ///
  /// - Parameter session: The session model, or `nil`.
  /// - Returns: `true` while the agent of `session` runs.
  static func isRunning(_ session: SessionModel?) -> Bool {
    session?.isRunning == true
  }

  /// The style of `action` for `session` (D110 (c)).
  ///
  /// Only one action is prominent at a time: Stop while the agent runs, and
  /// Send at other times. The other action uses the `.glass` style.
  ///
  /// - Parameters:
  ///   - action: The action of the button.
  ///   - session: The session model of the row, or `nil`.
  /// - Returns: The glass button style of the button.
  static func style(of action: Action, for session: SessionModel?) -> ActionStyle {
    let prominent: Action = isRunning(session) ? .stop : .send
    return action == prominent ? .glassProminent : .glass
  }

  /// Whether the agent runs: the `agentState` of the session model is
  /// `running`.
  private var isRunning: Bool {
    Self.isRunning(session)
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
    .actionStyle(Self.style(of: .send, for: session))
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
    .actionStyle(Self.style(of: .stop, for: session))
    .buttonBorderShape(.circle)
    .help(String(localized: "Stop the work of the agent", bundle: .module))
    .accessibilityIdentifier(Self.stopIdentifier)
  }
}

extension View {
  /// Gives the button in this view the glass button style `style`.
  ///
  /// - Parameter style: The style that ``DefaultPromptAccessory/style(of:for:)``
  ///   selects.
  /// - Returns: The view with the button style.
  @ViewBuilder fileprivate func actionStyle(_ style: DefaultPromptAccessory.ActionStyle) -> some View {
    switch style {
    case .glass:
      self.buttonStyle(.glass)
    case .glassProminent:
      self.buttonStyle(.glassProminent)
    }
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
