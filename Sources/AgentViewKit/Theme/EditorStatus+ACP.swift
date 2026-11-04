import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

// The EditorKit status token of each ACP and client status that the kit
// shows (^0cqh945).
//
// EditorKit's `EditorStatus` holds the symbol, the tone, the label, the
// detail and the liveness of a status, `EditorStatusLabel` draws it, and the
// `.status` kind of EditorInspector shows it in an inspector row. EditorKit
// links no ACP package, so the kit maps each ACP and client status to its
// `EditorStatus` here, one time, and each view and each inspection of the
// kit shows that value. A status that EditorKit names, such as a tool call
// that completed, takes EditorKit's symbol and label. A status that
// EditorKit does not name, such as the state of an MCP server, names its
// symbol, tone and label here. A status that the kit does not know is
// EditorKit's unknown status, with its wire value as the detail.

nonisolated extension EditorStatus {
  /// The status of a tool call with the ACP status `status`.
  ///
  /// A pending call is live too, as a running call is: it waits to run, so
  /// its symbol shows the live effect.
  ///
  /// - Parameter status: The ACP progress of the call. The custom status
  ///   ``ToolStatusSymbol/lostWireValue`` gives the lost status, and each
  ///   other unknown status gives the unknown status with its wire value.
  init(_ status: FoundationModelsACP.ToolCallStatus) {
    let work = EditorSymbol.Status(status)
    let base = EditorStatus(work, detail: work == .unknown ? status.wireValue : nil)
    self = base.live(work == .pending || work == .inProgress)
  }

  /// The status of a plan entry with the ACP status `status`.
  ///
  /// - Parameter status: The ACP status of the entry. A status that the kit
  ///   does not know gives the unknown status with its wire value.
  init(_ status: FoundationModelsACP.PlanEntryStatus) {
    if case .unknown(let wireValue) = status {
      self.init(.unknown, detail: wireValue)
    } else {
      self.init(EditorSymbol.Status(status))
    }
  }

  /// The status of a context compaction with `status`.
  ///
  /// - Parameter status: The status of the compaction. A compaction with no
  ///   `compaction_update` yet shows the unknown symbol and says so, and a
  ///   status that the kit does not know gives the unknown status with its
  ///   wire value.
  init(_ status: CompactionStatus) {
    switch status {
    case SessionEntry.Compaction.unreportedStatus:
      self.init(symbol: .status(.unknown), label: String(localized: "No status yet", bundle: .module))
    case .unknown(let wireValue):
      self.init(.unknown, detail: wireValue)
    case .inProgress, .completed, .failed, .cancelled:
      self.init(EditorSymbol.Status(status))
    }
  }

  /// The send state of a user message: the symbol of its EditorKit status,
  /// and a label that tells the send.
  ///
  /// - Parameter state: The send state of a `UserMessageEntry`.
  init(_ state: SendState) {
    self.init(symbol: .status(.init(state)), label: Self.label(of: state))
  }

  /// The status of an MCP server, from the client model. Each status has a
  /// different symbol, so the status does not show with color only. The
  /// reason of a failed server is the detail.
  ///
  /// - Parameter status: The status of the server.
  init(_ status: MCPServerStatus) {
    switch status {
    case .notReported:
      self.init(
        systemName: EditorSymbol.status(.unknown).systemImage, tone: .pending,
        label: String(localized: "Not reported", bundle: .module))
    case .connecting: self = .connecting
    case .connected: self = .connected
    case .failed(let reason): self = .connectionFailed(detail: reason)
    case .closed:
      self.init(
        systemName: SharedSymbol.disconnected, tone: .cancelled, label: String(localized: "Closed", bundle: .module))
    }
  }

  /// The state of the connection to an agent. The error of a failed
  /// connection is the detail.
  ///
  /// - Parameter state: The state of a `ConnectionModel`.
  init(_ state: ConnectionState) {
    switch state {
    case .disconnected:
      self.init(
        systemName: SharedSymbol.disconnected, tone: .cancelled,
        label: String(localized: "Disconnected", bundle: .module))
    case .connecting: self = .connecting
    case .connected: self = .connected
    case .failed(let error): self = .connectionFailed(detail: error.localizedDescription)
    }
  }

  /// The label and the detail in one text, for a place that speaks or shows
  /// a status as one string, such as the accessibility label of a row.
  ///
  /// - Returns: `<label>: <detail>`, or the label for a status with no
  ///   detail.
  var summary: String {
    guard let detail else { return label }
    return String(localized: "\(label): \(detail)", bundle: .module)
  }

  // MARK: - Shared statuses

  /// A connection, or a server, that is being made. It is live.
  private static var connecting: EditorStatus {
    EditorStatus(
      symbol: .status(.inProgress), label: String(localized: "Connecting", bundle: .module), isLive: true)
  }

  /// A connection, or a server, that is open.
  private static var connected: EditorStatus {
    EditorStatus(symbol: .status(.completed), label: String(localized: "Connected", bundle: .module))
  }

  /// A connection, or a server, that failed.
  ///
  /// - Parameter detail: Why the connection failed, or `nil` when no reason
  ///   is known.
  /// - Returns: The error symbol in the failed tone, with EditorKit's label
  ///   of a failure.
  private static func connectionFailed(detail: String?) -> EditorStatus {
    EditorStatus(
      systemName: SharedSymbol.error, tone: .failed, label: EditorStatus(EditorSymbol.Status.failed).label, detail: detail)
  }

  // MARK: - Helpers

  /// Makes the status of a symbol of EditorKit's symbol atom.
  ///
  /// - Parameters:
  ///   - symbol: The symbol, which gives the name and the tone.
  ///   - label: The label the user reads.
  ///   - isLive: Whether the status goes on.
  private init(symbol: EditorSymbol, label: String, isLive: Bool = false) {
    self.init(systemName: symbol.systemImage, tone: symbol.tone, label: label, isLive: isLive)
  }

  /// This status with `isLive` as its liveness.
  ///
  /// - Parameter isLive: Whether the status goes on.
  /// - Returns: The status, with the same symbol, tone, label and detail.
  private func live(_ isLive: Bool) -> EditorStatus {
    EditorStatus(systemName: systemImage, tone: tone, label: label, detail: detail, isLive: isLive)
  }

  /// The label of a send state.
  ///
  /// - Parameter state: The send state.
  /// - Returns: "Sending", "Sent", or "Not sent".
  private static func label(of state: SendState) -> String {
    switch state {
    case .pending: String(localized: "Sending", bundle: .module)
    case .sent: String(localized: "Sent", bundle: .module)
    case .failed: String(localized: "Not sent", bundle: .module)
    }
  }
}
