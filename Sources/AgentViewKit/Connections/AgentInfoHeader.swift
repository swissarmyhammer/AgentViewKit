import FoundationModelsACPClient
import SwiftUI

/// The header that names the agent of a `ConnectionModel` (update.md §4.3
/// "Initialize and auth", §9.4).
///
/// The body reads `ConnectionModel.initializeResponse` directly, and keeps no
/// copy of it. The agent sends its name and its version in the `info` member
/// of the `initialize` answer, so the host does not give a name:
///
/// - The name is the `title` of the agent info. When the agent gives no
///   title, the name is the `name` of the agent info.
/// - The version line is the `version` of the agent info.
///
/// Before `initialize` succeeds, the header shows nothing.
///
/// The name text has the accessibility identifier ``nameIdentifier``, and the
/// version text has ``versionIdentifier``.
public struct AgentInfoHeader: View {
  /// The accessibility identifier of the header.
  public static let identifier = "agent-info-header"

  /// The accessibility identifier of the name text.
  public static let nameIdentifier = "agent-info-name"

  /// The accessibility identifier of the version text.
  public static let versionIdentifier = "agent-info-version"

  /// The symbol of the header.
  static let symbol = "cpu"

  /// The connection model whose agent info the header shows.
  let connection: ConnectionModel

  @Environment(\.agentTheme) private var theme

  /// Makes the header of the agent of a connection model.
  ///
  /// - Parameter connection: The connection model of the agent.
  public init(connection: ConnectionModel) {
    self.connection = connection
  }

  public var body: some View {
    if let info = connection.initializeResponse?.info {
      HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
        Image(systemName: Self.symbol)
          .foregroundStyle(theme.accent)
          .fontWeight(theme.symbolWeight)
          .accessibilityHidden(true)
        Text(info.title ?? info.name)
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier(Self.nameIdentifier)
        Text(String(localized: "Version \(info.version)"))
          .font(.callout)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(Self.versionIdentifier)
        Spacer(minLength: theme.spacing.s)
      }
      .padding(.horizontal, theme.spacing.m)
      .padding(.vertical, theme.spacing.s)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(Self.identifier)
    }
  }
}
