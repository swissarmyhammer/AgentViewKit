import FoundationModelsACPClient
import SwiftUI

/// A dot and a label that show the `MCPServerStatus` of an MCP server
/// (plan.md §12).
///
/// The chip shows the status of the client model directly. The kit keeps no
/// status of its own. The chip is one accessibility element. Its label is the
/// name of the status. For `failed(reason:)` with a reason, its value is the
/// reason, and the reason is also the help tag.
public struct ConnectionStatusChip: View {
  /// The start of the accessibility identifier of each chip.
  public static let identifierPrefix = "connection-chip-"

  /// The status to show.
  let status: MCPServerStatus

  @Environment(\.agentTheme) private var theme

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

  public var body: some View {
    let label = Self.label(for: status)
    let reason = Self.reason(of: status)
    HStack(spacing: theme.spacing.xs) {
      Circle()
        .fill(color(for: status))
        .frame(width: theme.spacing.s, height: theme.spacing.s)
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

  /// The name of `status` that the user sees and that VoiceOver reads.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The name, such as `Not reported`.
  private static func label(for status: MCPServerStatus) -> String {
    switch status {
    case .notReported: "Not reported"
    case .connecting: "Connecting"
    case .connected: "Connected"
    case .failed: "Failed"
    case .closed: "Closed"
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

  /// The color of the dot for `status`, from the status colors of the theme.
  ///
  /// - Parameter status: The status of the server.
  /// - Returns: The color of the dot.
  private func color(for status: MCPServerStatus) -> Color {
    let colors = theme.statusColors
    return switch status {
    case .notReported: colors.pending
    case .connecting: colors.running
    case .connected: colors.completed
    case .failed: colors.failed
    case .closed: colors.cancelled
    }
  }
}
