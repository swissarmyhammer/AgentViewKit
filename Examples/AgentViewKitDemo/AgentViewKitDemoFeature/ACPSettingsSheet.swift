import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The settings sheet of the ACP tab.
///
/// The sheet shows the ``ConnectionsView`` of the ambient
/// ``ConnectionStore``, the ``AgentInfoHeader`` and the ``AgentAuthView`` of
/// the connection model, and the ``ConfigOptionsView`` of the session model in
/// the form style. Each view reads the models directly. The demo app writes
/// no agent connection into a ``ConnectionStore``: the store is for the MCP
/// servers of the agent.
struct ACPSettingsSheet: View {
  /// The accessibility identifier of the Done button.
  static let doneIdentifier = "demo-settings-done"

  /// The accessibility identifier of the text of the agent command.
  static let agentCommandIdentifier = "demo-settings-agent-command"

  /// The minimum height of the connection list.
  static let connectionsHeight: CGFloat = 120

  /// The space between the groups of the sheet.
  static let groupSpacing: CGFloat = 20

  /// The minimum width of the sheet.
  static let minimumWidth: CGFloat = 420

  /// The minimum height of the sheet.
  static let minimumHeight: CGFloat = 480

  /// The connection model of the agent.
  let connection: ConnectionModel

  /// The selected session model.
  let session: SessionModel

  /// The agent program of the launch options.
  let agentCommand: String

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Self.groupSpacing) {
          GroupBox("Connections") {
            ConnectionsView()
              .frame(minHeight: Self.connectionsHeight)
          }
          GroupBox("Agent") {
            VStack(alignment: .leading) {
              AgentInfoHeader(connection: connection)
              LabeledContent("Command", value: agentCommand)
                .accessibilityIdentifier(Self.agentCommandIdentifier)
              AgentAuthView(connection: connection)
            }
          }
          GroupBox("Session") {
            ConfigOptionsView(session: session, style: .form)
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
    .frame(minWidth: Self.minimumWidth, minHeight: Self.minimumHeight)
  }
}
