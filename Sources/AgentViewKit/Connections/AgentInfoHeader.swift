import FoundationModelsACPClient
import SwiftUI

/// The header that names the agent of a `ConnectionModel` (plan.md §3.3
/// "Initialize and auth", §3.8 "Connection banner"), and the session after
/// it, as an "Agent › Session" breadcrumb (^2sg9taf).
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
/// The header follows the path control of the macOS HIG. The first segment
/// is the agent: its symbol, its name and its version line. When the host
/// gives a session title, a chevron in the `.secondary` style follows, and
/// then the title in the `.primary` style. With no session title, the header
/// shows the agent alone. Each text has one line, and the agent segment has
/// the higher layout priority, so a long session title truncates first. The
/// segments are text with no glass and no fill of their own: the one glass
/// is the surface that the host of the header gives, such as the floating
/// glass in the top bar of ``AgentThreadView``.
///
/// VoiceOver reads the header as one header element with the identifier
/// ``identifier``. Its label is "Agent, Session", or the name of the agent
/// alone, and its value is the version line.
///
/// The symbol and the chevron are each a ``DecorativeSymbolImage``: they have
/// the `.secondary` style, not the accent of the EditorKit theme (D113 answer
/// 5).
public struct AgentInfoHeader: View {
  /// The accessibility identifier of the header.
  public static let identifier = "agent-info-header"

  /// The symbol of the header.
  static let symbol = SharedSymbol.agent

  /// The connection model whose agent info the header shows.
  let connection: ConnectionModel

  /// The title of the session that the header shows after the agent, or
  /// `nil` for the agent alone.
  let sessionTitle: String?

  @Environment(\.agentTheme) private var theme

  /// Makes the header of the agent of a connection model.
  ///
  /// - Parameters:
  ///   - connection: The connection model of the agent.
  ///   - sessionTitle: The title of the session that the header shows after
  ///     the agent, such as the title of a tab, or `nil` for the agent alone.
  public init(connection: ConnectionModel, sessionTitle: String? = nil) {
    self.connection = connection
    self.sessionTitle = sessionTitle
  }

  public var body: some View {
    if let info = connection.initializeResponse?.info {
      let agent = info.title ?? info.name
      AgentBreadcrumb(agent: agent, version: info.version, sessionTitle: sessionTitle)
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(agent: agent, sessionTitle: sessionTitle))
        .accessibilityValue(AgentBreadcrumb.versionLine(of: info.version))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.identifier)
    }
  }

  /// The VoiceOver label of the header: "Agent, Session", or the name of the
  /// agent alone.
  ///
  /// - Parameters:
  ///   - agent: The name of the agent.
  ///   - sessionTitle: The title of the session, or `nil`.
  /// - Returns: The label.
  static func label(agent: String, sessionTitle: String?) -> String {
    guard let sessionTitle else { return agent }
    return String(localized: "\(agent), \(sessionTitle)", bundle: .module)
  }
}

/// The segments of an ``AgentInfoHeader``: the agent, and the session after
/// a chevron when the host gives a session title.
///
/// The row has no accessibility element of its own. The header makes it one
/// element, so only a test that shows the row alone reads the frames of the
/// segments, with ``agentIdentifier`` and ``sessionIdentifier``.
struct AgentBreadcrumb: View {
  /// The accessibility identifier of the name of the agent.
  static let agentIdentifier = "agent-info-agent"

  /// The accessibility identifier of the session title.
  static let sessionIdentifier = "agent-info-session"

  /// The layout priority of the agent segment over the session segment, so
  /// that the session title truncates first.
  static let agentPriority: Double = 1

  /// The name of the agent.
  let agent: String

  /// The version of the agent.
  let version: String

  /// The title of the session, or `nil` for the agent alone.
  let sessionTitle: String?

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
      agentSegment
        .layoutPriority(Self.agentPriority)
      if let sessionTitle {
        DecorativeSymbolImage(name: SharedSymbol.disclosure)
          .imageScale(.small)
        Text(sessionTitle)
          .font(.headline)
          .foregroundStyle(.primary)
          .lineLimit(1)
          .accessibilityIdentifier(Self.sessionIdentifier)
      }
      Spacer(minLength: theme.spacing.s)
    }
  }

  /// The version line of an agent, such as "Version 2.1.0".
  ///
  /// - Parameter version: The version of the agent.
  /// - Returns: The localized line.
  static func versionLine(of version: String) -> String {
    String(localized: "Version \(version)", bundle: .module)
  }

  /// The first segment: the symbol, the name and the version line of the
  /// agent. The name keeps its place before the version line.
  private var agentSegment: some View {
    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
      DecorativeSymbolImage(name: AgentInfoHeader.symbol)
      Text(agent)
        .font(.headline)
        .lineLimit(1)
        .layoutPriority(Self.agentPriority)
        .accessibilityIdentifier(Self.agentIdentifier)
      Text(Self.versionLine(of: version))
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

#Preview("Agent header") {
  AgentInfoHeader(connection: .previewSample)
}

#Preview("Agent › Session header") {
  AgentInfoHeader(connection: .previewSample, sessionTitle: "AgentViewKit")
}
