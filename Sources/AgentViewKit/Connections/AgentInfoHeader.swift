import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The header that names the agent of a `ConnectionModel` (plan.md §3.3
/// "Initialize and auth", §3.8 "Connection banner"), and the path to the
/// shown session after it, as an "Agent › Session › Child" breadcrumb
/// (^2sg9taf). The model is parent and child all the way down: the path has
/// one crumb for each session from the root to the shown session.
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
/// gives a session, a chevron in the `.secondary` style and a crumb follow
/// for each session on the path from the root to it. Each crumb is a
/// dropdown with the siblings at its level (``SessionBreadcrumb``). With no
/// session, the header shows the agent alone. Each text has one line. When
/// the path does not fit the width, the middle crumbs collapse into one "..."
/// dropdown. That is a rule of the width, and not of the number of sessions.
/// The agent segment has the higher layout priority, so a long title
/// truncates first. The
/// segments are text with no glass and no fill of their own: the one glass
/// is the surface that the host of the header gives, such as the floating
/// glass in the top bar of ``AgentThreadView``.
///
/// The header has no padding around it (^rgsq3k4): the host spaces it, and
/// the host that puts it on glass insets it in the glass, as the top bar of
/// ``AgentThreadView`` does with the spacing steps of the style.
///
/// VoiceOver reads the header as one header element with the identifier
/// ``identifier``. Its label names the path, such as "Agent, Reviewer,
/// Linter", or the name of the agent alone, and its value is the version
/// line. With a session, the header is a container, so each dropdown stays
/// reachable.
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

  /// The session that the header shows after the agent, or `nil` for the
  /// agent alone.
  let session: SessionModel?

  /// Called with the id of the session that the user chooses in a dropdown.
  let select: (SessionId) -> Void

  /// Makes the header of the agent of a connection model.
  ///
  /// - Parameters:
  ///   - connection: The connection model of the agent.
  ///   - session: The session that the header shows after the agent, or
  ///     `nil` for the agent alone. The crumbs are its ancestors and the
  ///     session itself. The header reads the model and keeps no copy.
  ///   - select: Called with the id of the session that the user chooses in
  ///     a dropdown. Which session a window shows is the state of the view,
  ///     so the host changes it. The default does nothing.
  public init(
    connection: ConnectionModel, session: SessionModel? = nil, select: @escaping (SessionId) -> Void = { _ in }
  ) {
    self.connection = connection
    self.session = session
    self.select = select
  }

  public var body: some View {
    if let info = connection.initializeResponse?.info {
      let agent = info.title ?? info.name
      let path = session?.path ?? []
      AgentBreadcrumb(agent: agent, version: info.version, path: path, select: select)
        .accessibilityElement(children: path.isEmpty ? .ignore : .contain)
        .accessibilityLabel(Self.label(agent: agent, path: path.map(\.displayTitle)))
        .accessibilityValue(AgentBreadcrumb.versionLine(of: info.version))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.identifier)
    }
  }

  /// The VoiceOver label of the header: the agent and the titles of the path,
  /// such as "Agent, Reviewer, Linter", or the name of the agent alone.
  ///
  /// - Parameters:
  ///   - agent: The name of the agent.
  ///   - path: The titles of the sessions from the root to the shown session.
  /// - Returns: The label.
  static func label(agent: String, path: [String]) -> String {
    SessionPathText.label([agent] + path)
  }
}

/// The segments of an ``AgentInfoHeader``: the agent, and the crumbs of the
/// path after it.
///
/// The row tries the full path first, then the path with the middle crumbs
/// collapsed, and last the collapsed path with truncated text, whatever fits
/// the width first (`ViewThatFits`).
///
/// The row has no accessibility element of its own. The header makes it one
/// element (or one container, with a path), so only a test that shows the row
/// alone reads the frames of the segments, with ``agentIdentifier``.
struct AgentBreadcrumb: View {
  /// The accessibility identifier of the name of the agent.
  static let agentIdentifier = "agent-info-agent"

  /// The layout priority of the agent segment over the crumbs, so that the
  /// crumbs truncate first.
  static let agentPriority: Double = 1

  /// The name of the agent.
  let agent: String

  /// The version of the agent.
  let version: String

  /// The sessions from the root to the shown session, or none for the agent
  /// alone.
  let path: [SessionModel]

  /// Called with the id of the session that the user chooses.
  let select: (SessionId) -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    ViewThatFits(in: .horizontal) {
      row(collapsed: false).fixedSize(horizontal: true, vertical: false)
      row(collapsed: true).fixedSize(horizontal: true, vertical: false)
      row(collapsed: true)
    }
  }

  /// The row of the agent and the crumbs.
  private func row(collapsed: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.s) {
      agentSegment
        .layoutPriority(Self.agentPriority)
      SessionBreadcrumb(path: path, collapsed: collapsed, select: select)
      Spacer(minLength: editorStyle.spacing.s)
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
    HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.s) {
      DecorativeSymbolImage(name: AgentInfoHeader.symbol)
      Text(agent)
        .font(editorTheme.font(for: .ui, style: .headline))
        .lineLimit(1)
        .layoutPriority(Self.agentPriority)
        .accessibilityIdentifier(Self.agentIdentifier)
      Text(Self.versionLine(of: version))
        .font(editorTheme.font(for: .ui, style: .callout))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

#Preview("Agent header") {
  AgentInfoHeader(connection: .previewSample)
}

#Preview("Agent › Session header") {
  AgentInfoHeader(connection: .previewSample, session: ConnectionModel.previewSample.openSessions.first)
}
