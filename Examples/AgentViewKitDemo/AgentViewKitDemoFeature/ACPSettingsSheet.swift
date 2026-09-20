import AgentViewKit
import SwiftUI

/// The settings sheet of the ACP tab.
///
/// The sheet shows the ``ConnectionsView`` of the ambient
/// ``ConnectionStore``, the ``AgentAuthView`` of the agent, and the
/// ``ConfigOptionsView`` of the thread in the form style.
struct ACPSettingsSheet: View {
  /// The accessibility identifier of the Done button.
  static let doneIdentifier = "demo-settings-done"

  /// The accessibility identifier of the text of the agent command.
  static let agentCommandIdentifier = "demo-settings-agent-command"

  /// The minimum height of the connection list.
  static let connectionsHeight: CGFloat = 120

  /// The ACP session of the tab.
  let session: ACPDemoSession

  /// The agent program of the launch options.
  let agentCommand: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          GroupBox("Connections") {
            ConnectionsView()
              .frame(minHeight: Self.connectionsHeight)
          }
          GroupBox("Agent") {
            VStack(alignment: .leading) {
              LabeledContent("Command", value: agentCommand)
                .accessibilityIdentifier(Self.agentCommandIdentifier)
              AgentAuthView(methods: session.authMethods, isAuthenticated: false, thread: session.thread)
            }
          }
          GroupBox("Session") {
            ConfigOptionsView(options: session.thread.configOptions, style: .form)
          }
        }
        .padding()
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier(Self.doneIdentifier)
        }
      }
    }
    .frame(minWidth: 420, minHeight: 480)
  }
}
