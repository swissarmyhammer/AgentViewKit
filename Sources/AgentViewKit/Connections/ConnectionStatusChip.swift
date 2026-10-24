import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import SwiftUI

/// A status symbol and a label that show the `MCPServerStatus` of an MCP
/// server (plan.md §12).
///
/// The chip shows the status of the client model directly. The kit keeps no
/// status of its own. Each status has a different symbol, so the status does
/// not show with color only. The chip is one accessibility element. Its label
/// is the name of the status. For `failed(reason:)` with a reason, its value
/// is the reason, and the reason is also the help tag.
public struct ConnectionStatusChip: View {
  /// The start of the accessibility identifier of each chip.
  public static let identifierPrefix = "connection-chip-"

  /// The status to show.
  let status: MCPServerStatus

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes a chip.
  ///
  /// - Parameter status: The status of the server, from the client model.
  public init(status: MCPServerStatus) {
    self.status = status
  }

  /// The accessibility identifier of a chip that shows `status`.
  ///
  /// The reason of a failed status is not in the identifier.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: `connection-chip-<status>`, such as
  ///   `connection-chip-not-reported`.
  public static func identifier(for status: MCPServerStatus) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: identifierName(for: status))
  }

  /// The SF Symbol name of `status`. Each status has a different symbol.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The symbol of the status concept: unknown for a status that
  ///   the agent did not report, in progress for a server that connects,
  ///   completed for a connected server, error for a failed server, and
  ///   disconnected for a closed server.
  static func symbolName(for status: MCPServerStatus) -> String {
    switch status {
    case .notReported: ItemStatus.unknown.systemImage
    case .connecting: ItemStatus.inProgress.systemImage
    case .connected: ItemStatus.completed.systemImage
    case .failed: SharedSymbol.error
    case .closed: SharedSymbol.disconnected
    }
  }

  public var body: some View {
    let label = Self.label(for: status)
    let reason = Self.reason(of: status)
    HStack(spacing: editorStyle.spacing.xs) {
      Image(systemName: Self.symbolName(for: status))
        .font(editorTheme.font(for: .ui, style: .caption))
        .fontWeight(editorStyle.symbolWeight)
        .foregroundStyle(color(for: status))
      Text(label)
        .font(editorTheme.font(for: .ui, style: .caption))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .help(reason ?? label)
    .valueElement(label: Text(label), value: Text(reason ?? ""), identifier: Self.identifier(for: status))
  }

  /// The name of `status` in an accessibility identifier.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The name, such as `not-reported`.
  private static func identifierName(for status: MCPServerStatus) -> String {
    switch status {
    case .notReported: "not-reported"
    case .connecting: "connecting"
    case .connected: "connected"
    case .failed: "failed"
    case .closed: "closed"
    }
  }

  /// The localized name of `status` that the user sees and that VoiceOver
  /// reads.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The name, such as `Not reported`.
  private static func label(for status: MCPServerStatus) -> String {
    switch status {
    case .notReported: String(localized: "Not reported", bundle: .module)
    case .connecting: String(localized: "Connecting", bundle: .module)
    case .connected: String(localized: "Connected", bundle: .module)
    case .failed: WorkStatusLabel.failed
    case .closed: String(localized: "Closed", bundle: .module)
    }
  }

  /// The reason of a failed status.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The reason that the agent gave, or `nil` for each other
  ///   status and for a failed status with no reason.
  private static func reason(of status: MCPServerStatus) -> String? {
    if case .failed(let reason) = status { reason } else { nil }
  }

  /// The color of the symbol for `status`, from the status roles of the
  /// EditorKit theme.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The color of the symbol.
  private func color(for status: MCPServerStatus) -> Color {
    switch status {
    case .notReported: editorTheme.statusPending
    case .connecting: editorTheme.statusRunning
    case .connected: editorTheme.statusSucceeded
    case .failed: editorTheme.statusFailed
    case .closed: editorTheme.statusCancelled
    }
  }
}

#Preview("MCP server states") {
  let statuses: [MCPServerStatus] = [
    .notReported, .connecting, .connected, .failed(reason: "The command was not found."), .closed,
  ]
  VStack(alignment: .leading) {
    ForEach(Array(statuses.enumerated()), id: \.offset) { _, status in
      ConnectionStatusChip(status: status)
    }
  }
}
