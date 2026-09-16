import SwiftUI

/// A dot and a label that show a ``ConnectionState`` (plan.md §12).
///
/// The chip is one accessibility element. Its label is the name of the
/// state. For ``ConnectionState/error(_:)``, its value is the error text, and
/// the text is also the help tag.
public struct ConnectionStatusChip: View {
  /// The start of the accessibility identifier of each chip.
  public static let identifierPrefix = "connection-chip-"

  /// The state to show.
  let state: ConnectionState

  @Environment(\.agentTheme) private var theme

  /// Makes a chip.
  ///
  /// - Parameter state: The state to show.
  public init(state: ConnectionState) {
    self.state = state
  }

  /// The accessibility identifier of a chip that shows a state of `kind`.
  ///
  /// - Parameter kind: The kind of the state.
  /// - Returns: `connection-chip-<kind>`, such as
  ///   `connection-chip-needs-auth`.
  public static func identifier(for kind: ConnectionState.Kind) -> String {
    identifierPrefix + kind.rawValue
  }

  public var body: some View {
    let kind = state.kind
    HStack(spacing: theme.spacing.xs) {
      Circle()
        .fill(color(for: kind))
        .frame(width: theme.spacing.s, height: theme.spacing.s)
      Text(kind.label)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .help(state.errorMessage ?? kind.label)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(kind.label)
    .accessibilityValue(state.errorMessage ?? "")
    // An element with no role does not give its value. The trait gives the
    // static text role.
    .accessibilityAddTraits(.isStaticText)
    .accessibilityIdentifier(Self.identifier(for: kind))
  }

  /// The color of the dot for a state of `kind`, from the status colors of
  /// the theme.
  ///
  /// - Parameter kind: The kind of the state.
  /// - Returns: The color of the dot.
  private func color(for kind: ConnectionState.Kind) -> Color {
    let colors = theme.statusColors
    return switch kind {
    case .disconnected: colors.pending
    case .connected: colors.completed
    case .needsAuth: theme.accent
    case .authenticating: colors.running
    case .expired: colors.cancelled
    case .error: colors.failed
    }
  }
}
