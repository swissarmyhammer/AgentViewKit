import EditorInspector
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

// The inspections of the session, the connection and the MCP server models
// of FoundationModelsACPClient, so a host shows each one in an EditorKit
// `InspectorView`.
//
// The session is an ``InspectableClientModel``: the inspector shows it
// through an ``InspectedClientModel``, whose id is the raw session id, such
// as `sess_1`, in place of the debug description of its `SessionId`. The
// connection has no id, so EditorKit names it by its position,
// `connection-1`; the id of an MCP server is its name, a `String`.
//
// Each row is read-only, and each get block reads the model when the row
// draws, so an update of the agent redraws the row. The config options of a
// session are not here: the agent names them for each session, and
// ``ConfigOptionsView`` in its form style shows them. The state of a
// connection and the status of an MCP server are EditorKit's status token
// (`EditorStatus`), which the inspector shows as a read-only `.status` row.
// The working directory of a session is EditorKit's path kind, and its
// additional directories are its paths kind, a path chip for each folder
// (``InspectionPath``).

extension SessionModel: InspectableClientModel {
  /// The object id of the session: its raw session id, such as `sess_1`.
  public var inspectorObjectID: String { sessionId.rawValue }

  /// The title, the status, the id, the working directory and the
  /// additional directories of the session, and its use of the context
  /// window, its subagents and its transcript.
  ///
  /// The Additional Directories row shows a path chip for each folder, in
  /// the order of the session, and a dash for a session with none.
  public static var inspection: Inspection<InspectedClientModel<SessionModel>> {
    .named(
      FieldLabel(localized: "Session", bundle: .module), id: ClientInspectionID.session,
      name: { $0.model.title ?? $0.model.sessionId.rawValue }
    ) {
      Field(InspectionLabel.title) { $0.model.title }
      Field(InspectionLabel.status) { $0.model.status.text }
      Field(FieldLabel(localized: "Id", bundle: .module)) { $0.model.sessionId.rawValue }
      Field(FieldLabel(localized: "Closed", bundle: .module)) { $0.model.isClosed }
      InspectionPath.workingDirectory { $0.model.cwd }
      Field(FieldLabel(localized: "Additional Directories", bundle: .module)) { session in
        session.model.additionalDirectories.map { InspectionPath.folder($0) }
      }
    } more: {
      FieldGroup(FieldLabel(localized: "Agent", bundle: .module)) {
        Field(FieldLabel(localized: "Context Used", bundle: .module)) { $0.model.usage?.used }
        Field(FieldLabel(localized: "Context Size", bundle: .module)) { $0.model.usage?.size }
        Field(FieldLabel(localized: "Subagents", bundle: .module)) { $0.model.children.count }
        Field(FieldLabel(localized: "Entries", bundle: .module)) { $0.model.transcript.count }
        Field(FieldLabel(localized: "MCP Servers", bundle: .module)) { $0.model.mcpServers.map(\.name) }
      }
    }
  }
}

extension ConnectionModel: @retroactive Inspectable {
  /// The state of the connection, the agent, and its sessions.
  public static var inspection: Inspection<ConnectionModel> {
    .named(FieldLabel(localized: "Connection", bundle: .module), id: ClientInspectionID.connection) {
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
    Inspection(
      id: ClientInspectionID.mcpServer, title: String(localized: "MCP Server", bundle: .module), name: { $0.name }
    ) {
      FieldGroup(FieldLabel(localized: "Server", bundle: .module)) {
        Field(InspectionLabel.name) { $0.name }
        Field(FieldLabel(localized: "Transport", bundle: .module)) { $0.transport.map(ConnectionRow.label(for:)) }
        Field(InspectionLabel.status) { EditorStatus($0.status) }
      }
    }
  }
}
