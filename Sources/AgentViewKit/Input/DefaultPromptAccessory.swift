import SwiftUI

/// The default accessory row of ``PromptInputView`` (plan.md §9 D).
///
/// The row shows the ``PermissionModePicker`` of the thread and the submit
/// button in the `.glassProminent` style. While the thread runs a turn, a
/// Stop button replaces the submit button and calls
/// ``AgentThreadActions/cancel()``.
///
/// The row reads the thread from ``SwiftUI/EnvironmentValues/agentThread``,
/// the actions from ``SwiftUI/EnvironmentValues/threadActions``, and the
/// submit action from ``SwiftUI/EnvironmentValues/promptSubmitAction``. The
/// attachment chips, the suggestions, the mic, and the tool toggles come in
/// their own tasks. This row has no controls for them yet.
public struct DefaultPromptAccessory: View {
  /// The accessibility identifier of the submit button.
  public static let submitIdentifier = "prompt-submit"

  /// The accessibility identifier of the Stop button.
  public static let stopIdentifier = "prompt-stop"

  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions
  @Environment(\.promptSubmitAction) private var submit
  @Environment(\.agentTheme) private var theme

  /// Makes the accessory row.
  public init() {}

  public var body: some View {
    HStack(spacing: theme.spacing.s) {
      PermissionModePicker(options: thread?.configOptions ?? [])
        .labelsHidden()
        .fixedSize()
      Spacer(minLength: theme.spacing.s)
      if thread?.state == .running {
        stopButton
      } else {
        submitButton
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
      let actions = actions
      Task { await actions.cancel() }
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
