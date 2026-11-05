import EditorInspector
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

// The `Inspectable` conformances of the session, the connection and the MCP
// server models of FoundationModelsACPClient, so a host shows each one in an
// EditorKit `InspectorView`.
//
// Each row is read-only, and each get block reads the model when the row
// draws, so an update of the agent redraws the row. The config options of a
// session are not here: the agent names them for each session, and
// ``ConfigOptionsView`` in its form style shows them. The state of a
// connection and the status of an MCP server are EditorKit's status token
// (`EditorStatus`), which the inspector shows as a read-only `.status` row.
// The working directory of a session is EditorKit's path kind
// (``InspectionPath``). The additional directories of a session are not here
// yet: they are a list of paths, which EditorKit's inspector has no kind for
// (^b9xgnm7).

extension SessionModel: @retroactive Inspectable {
  /// The title, the status, the id and the working directory of the
  /// session, and its use of the context window, its subagents and its
  /// transcript.
  public static var inspection: Inspection<SessionModel> {
    .named(FieldLabel(localized: "Session", bundle: .module), name: { $0.title ?? $0.sessionId.rawValue }) {
      Field(InspectionLabel.title) { $0.title }
      Field(InspectionLabel.status) { $0.status.text }
      Field(FieldLabel(localized: "Id", bundle: .module)) { $0.sessionId.rawValue }
      Field(FieldLabel(localized: "Closed", bundle: .module)) { $0.isClosed }
      InspectionPath.workingDirectory { $0.cwd }
    } more: {
      FieldGroup(FieldLabel(localized: "Agent", bundle: .module)) {
        Field(FieldLabel(localized: "Context Used", bundle: .module)) { $0.usage?.used }
        Field(FieldLabel(localized: "Context Size", bundle: .module)) { $0.usage?.size }
        Field(FieldLabel(localized: "Subagents", bundle: .module)) { $0.children.count }
        Field(FieldLabel(localized: "Entries", bundle: .module)) { $0.transcript.count }
        Field(FieldLabel(localized: "MCP Servers", bundle: .module)) { $0.mcpServers.map(\.name) }
      }
    }
  }
}

extension ConnectionModel: @retroactive Inspectable {
  /// The state of the connection, the agent, and its sessions.
  public static var inspection: Inspection<ConnectionModel> {
    .named(FieldLabel(localized: "Connection", bundle: .module)) {
      Field(FieldLabel(localized: "State", bundle: .module)) { EditorStatus($0.state) }
      Field(FieldLabel(localized: "Agent", bundle: .module)) { $0.initializeResponse?.info.name }
      Field(FieldLabel(localized: "Open Sessions", bundle: .module)) { $0.openSessions.count }
      Field(FieldLabel(localized: "Listed Sessions", bundle: .module)) { $0.sessions.count }
    }
  }
}

extension MCPServerItem: @retroactive Inspectable {
  /// The name, the transport and the status of the server.
  public static var inspection: Inspection<MCPServerItem> {
    Inspection(title: String(localized: "MCP Server", bundle: .module), name: { $0.name }) {
      FieldGroup(FieldLabel(localized: "Server", bundle: .module)) {
        Field(InspectionLabel.name) { $0.name }
        Field(FieldLabel(localized: "Transport", bundle: .module)) { $0.transport.map(ConnectionRow.label(for:)) }
        Field(InspectionLabel.status) { EditorStatus($0.status) }
      }
    }
  }
}
