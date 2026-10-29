import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The settings sheet of the ACP tab.
///
/// The sheet shows the ``ConnectionsView`` of the MCP servers of the session
/// model, the ``AgentInfoHeader`` and the ``AgentAuthView`` of the connection
/// model, and the ``ConfigOptionsView`` of the session model in the form
/// style. Each view reads the models directly.
struct ACPSettingsSheet: View {
  /// The accessibility identifier of the Done button.
  static let doneIdentifier = "demo-settings-done"

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

  @Environment(\.dismiss) private var dismiss
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Self.groupSpacing) {
          GroupBox("MCP Servers") {
            // The kit views have no margin of their own: the sheet spaces
            // them with the steps of the style.
            ConnectionsView()
              .environment(\.sessionModel, session)
              .scrollContentMargins(\.tile.margin)
              .frame(minHeight: Self.connectionsHeight)
          }
          GroupBox("Agent") {
            VStack(alignment: .leading) {
              AgentInfoHeader(connection: connection)
                .padding(.horizontal, editorStyle.spacing.m)
                .padding(.vertical, editorStyle.spacing.s)
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
