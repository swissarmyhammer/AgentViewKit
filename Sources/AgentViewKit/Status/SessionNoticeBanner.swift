import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The banners of the notices of a `SessionModel` (plan.md §3.2
/// "Notices"; the owner decision of 2026-10-04 in
/// `Docs/decisions/acp-client-kit.md`).
///
/// The view shows one banner for each notice in `SessionModel.notices`,
/// in arrival order. Each banner shows a symbol and a tint for the severity,
/// the title, and the description when the agent gave one. The Dismiss button
/// of a banner calls `SessionModel.dismissNotice(_:)`, which removes the
/// notice from the model and thus removes the banner. With no notices, the
/// view is empty.
///
/// A notice is not in the transcript, so the banners are not rows of the
/// conversation. ``AgentThreadView`` shows them above the conversation.
/// Notices are stable ACP since schema alpha.8.
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

  @Environment(\.editorStyle) private var editorStyle

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
      VStack(spacing: editorStyle.tile.margin) {
        ForEach(notices) { notice in
          NoticeBanner(notice: notice) { session.dismissNotice(notice.id) }
        }
      }
      .padding(editorStyle.tile.margin)
    }
  }
}

/// The banner of one notice in ``SessionNoticeBanner``.
struct NoticeBanner: View {
  /// The notice to show.
  let notice: SessionNotice

  /// The closure that the Dismiss button calls.
  let dismiss: () -> Void

  /// The name of a severity.
  ///
  /// - Parameter severity: The severity of a notice.
  /// - Returns: The name of the severity. A severity that the kit does not
  ///   know gives its wire value.
  static func severityLabel(_ severity: NoticeSeverity) -> String {
    switch severity {
    case .info: String(localized: "Information", bundle: .module)
    case .warning: String(localized: "Warning", bundle: .module)
    case .error: String(localized: "Error", bundle: .module)
    case .unknown(let wireValue):
      String(localized: "Unknown severity: \(wireValue)", bundle: .module)
    }
  }

  /// The SF Symbol name of a severity.
  ///
  /// - Parameter severity: The severity of a notice.
  /// - Returns: The symbol name.
  static func symbolName(for severity: NoticeSeverity) -> String {
    switch severity {
    case .info: SharedSymbol.information
    case .warning: SharedSymbol.warning
    case .error: SharedSymbol.error
    case .unknown: ItemStatus.unknown.systemImage
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
    NoticeRow(
      severity: notice.severity, title: notice.title, description: notice.description,
      label: Self.label(for: notice), identifier: SessionNoticeBanner.identifier(for: notice.id),
      dismissIdentifier: SessionNoticeBanner.dismissIdentifier(for: notice.id), dismiss: dismiss)
  }
}

/// One row of a notice: the symbol and the tint of a severity, a title, an
/// optional description, and a Dismiss button.
///
/// The row is content, so it has no fill and no glass. A separator stroke
/// marks its edge (`.inlineEdge(radius:)`, D113). Only its
/// Dismiss button has a button style of its own, which comes from the place
/// of the row (``RequestDeckPlace/style(of:)``): the `.glass` style in
/// content, and the `.bordered` style on the glass of a ``RequestDeck`` in a
/// bar of floating controls.
///
/// The text is one accessibility element with the label of the row, and the
/// Dismiss button is its sibling. ``NoticeBanner`` and the notice of a request
/// that the agent withdraws (``WithdrawnNoticeRow``) show this row.
struct NoticeRow: View {
  /// The SF Symbol name of the Dismiss button.
  static let dismissSymbol = SharedSymbol.dismiss

  /// The severity, which gives the symbol and the tint.
  let severity: NoticeSeverity

  /// The title, in the headline font.
  let title: String

  /// The description below the title, or `nil` for no description.
  let description: String?

  /// The accessibility label of the text.
  let label: String

  /// The accessibility identifier of the text.
  let identifier: String

  /// The accessibility identifier of the Dismiss button.
  let dismissIdentifier: String

  /// The closure that the Dismiss button calls.
  let dismiss: () -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    HStack(alignment: .top, spacing: editorStyle.spacing.m) {
      StatusSymbolImage(
        name: NoticeBanner.symbolName(for: severity),
        color: editorTheme.tint(for: severity)
      )
        .help(NoticeBanner.severityLabel(severity))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        Text(title)
          .font(editorTheme.font(for: .ui, style: .headline))
        if let description {
          Text(description)
            .font(editorTheme.font(for: .ui, style: .callout))
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }
      // The text is the element of the row, and the button is its sibling.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label)
      .accessibilityIdentifier(identifier)
      Spacer(minLength: editorStyle.spacing.s)
      Button(
        String(localized: "Dismiss", bundle: .module), systemImage: Self.dismissSymbol,
        action: dismiss
      )
        .labelStyle(.iconOnly)
        .requestActionStyle(.secondary)
        .accessibilityIdentifier(dismissIdentifier)
        .agentControlScope(dismissIdentifier)
    }
    .contentTile()
    .inlineEdge(radius: editorStyle.radii.l)
  }
}

#Preview("Notice") {
  let notice = Notice(
    severity: .warning, title: "The context is almost full",
    description: "The agent compacts the context before the next prompt.")
  SessionNoticeBanner(session: .preview(transcript: [.update(.notice(notice))]))
}
