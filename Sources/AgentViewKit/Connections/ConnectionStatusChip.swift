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

  @Environment(\.agentTheme) private var theme
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
    case .notReported: SharedSymbol.unknown
    case .connecting: SharedSymbol.inProgress
    case .connected: SharedSymbol.completed
    case .failed: SharedSymbol.error
    case .closed: SharedSymbol.disconnected
    }
  }

  public var body: some View {
    let label = Self.label(for: status)
    let reason = Self.reason(of: status)
    HStack(spacing: theme.spacing.xs) {
      Image(systemName: Self.symbolName(for: status))
        .font(.caption)
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(color(for: status))
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .help(reason ?? label)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(reason ?? "")
    // An element with no role does not give its value. The trait gives the
    // static text role.
    .accessibilityAddTraits(.isStaticText)
    .accessibilityIdentifier(Self.identifier(for: status))
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
    case .notReported: String(localized: "Not reported")
    case .connecting: String(localized: "Connecting")
    case .connected: String(localized: "Connected")
    case .failed: WorkStatusLabel.failed
    case .closed: String(localized: "Closed")
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
