import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The banners of the notices of a `SessionModel` (plan.md §3.2
/// "Notices"; the owner decision of 2026-10-04 in
/// `Docs/decisions/acp-client-kit.md`).
///
/// The view shows one glass banner for each notice in `SessionModel.notices`,
/// in arrival order. Each banner shows a symbol and a tint for the severity,
/// the title, and the description when the agent gave one. The Dismiss button
/// of a banner calls `SessionModel.dismissNotice(_:)`, which removes the
/// notice from the model and thus removes the banner. With no notices, the
/// view is empty.
///
/// A notice is not in the transcript, so the banners are not rows of the
/// conversation. ``AgentThreadView`` shows them above the conversation.
/// Notices are unstable ACP.
///
/// The accessibility label of each banner is the severity, the title and the
/// description, such as `Warning, Quota low, Half of the quota is used.`
public struct SessionNoticeBanner: View {
  /// The start of the accessibility identifier of the text of each banner.
  public static let identifierPrefix = "session-notice-"

  /// The start of the accessibility identifier of the Dismiss button of each
  /// banner.
  public static let dismissIdentifierPrefix = "session-notice-dismiss-"

  /// The session model whose notices the view shows.
  let session: SessionModel

  @Environment(\.agentTheme) private var theme

  /// Makes the banners of the notices of a session model.
  ///
  /// - Parameter session: The session model whose notices the view shows.
  public init(session: SessionModel) {
    self.session = session
  }

  /// The accessibility identifier of the text of the banner of a notice.
  ///
  /// - Parameter id: The local identity of the notice.
  /// - Returns: `session-notice-<id>`.
  public static func identifier(for id: SessionNotice.ID) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id.uuidString)
  }

  /// The accessibility identifier of the Dismiss button of the banner of a
  /// notice.
  ///
  /// - Parameter id: The local identity of the notice.
  /// - Returns: `session-notice-dismiss-<id>`.
  public static func dismissIdentifier(for id: SessionNotice.ID) -> String {
    AccessibilityIdentifier.make(prefix: dismissIdentifierPrefix, value: id.uuidString)
  }

  public var body: some View {
    let notices = session.notices
    if !notices.isEmpty {
      VStack(spacing: theme.spacing.s) {
        ForEach(notices) { notice in
          NoticeBanner(notice: notice) { session.dismissNotice(notice.id) }
        }
      }
      .padding(theme.spacing.m)
    }
  }
}

/// The banner of one notice in ``SessionNoticeBanner``.
private struct NoticeBanner: View {
  /// The notice to show.
  let notice: SessionNotice

  /// The closure that the Dismiss button calls.
  let dismiss: () -> Void

  @Environment(\.agentTheme) private var theme

  /// The name of a severity.
  ///
  /// - Parameter severity: The severity of a notice.
  /// - Returns: The name of the severity. A severity that the kit does not
  ///   know gives its wire value.
  private static func severityLabel(_ severity: Unstable.NoticeSeverity) -> String {
    switch severity {
    case .info: String(localized: "Information")
    case .warning: String(localized: "Warning")
    case .error: String(localized: "Error")
    case .unknown(let wireValue): String(localized: "Unknown severity: \(wireValue)")
    }
  }

  /// The SF Symbol name of a severity.
  ///
  /// - Parameter severity: The severity of a notice.
  /// - Returns: The symbol name.
  private static func symbolName(for severity: Unstable.NoticeSeverity) -> String {
    switch severity {
    case .info, .unknown: "info.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .error: "xmark.octagon.fill"
    }
  }

  /// The accessibility label of the banner of a notice.
  ///
  /// - Parameter notice: The notice.
  /// - Returns: The severity, the title and the description, separated by
  ///   commas. A notice with no description gives no description part.
  private static func label(for notice: SessionNotice) -> String {
    [severityLabel(notice.severity), notice.title, notice.description]
      .compactMap(\.self)
      .joined(separator: ", ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: theme.spacing.m) {
      Image(systemName: Self.symbolName(for: notice.severity))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(theme.statusColors.color(for: notice.severity))
        .fontWeight(theme.symbolWeight)
        .help(Self.severityLabel(notice.severity))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(notice.title)
          .font(.headline)
        if let description = notice.description {
          Text(description)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
      // The text is the element of the banner, and the button is its sibling.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Self.label(for: notice))
      .accessibilityIdentifier(SessionNoticeBanner.identifier(for: notice.id))
      Spacer(minLength: theme.spacing.s)
      Button(String(localized: "Dismiss"), systemImage: "xmark", action: dismiss)
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .accessibilityIdentifier(SessionNoticeBanner.dismissIdentifier(for: notice.id))
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
  }
}
