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
/// the title, and the description when the agent gave one. A notice with an
/// empty title, or with a sentence in its title and no description, takes the
/// name of its severity as its title, and the text of the agent goes below it
/// (``NoticeBanner/lines(severity:title:description:)``). The Dismiss button
/// of a banner calls `SessionModel.dismissNotice(_:)`, which removes the
/// notice from the model and thus removes the banner. With no notices, the
/// view is empty.
///
/// A notice is not in the transcript, so the banners are not rows of the
/// conversation. ``AgentThreadView`` shows them above the conversation. The
/// banners stand one tile margin apart, and the view has no margin around
/// them (^rgsq3k4): the layout that holds the view spaces it, as the top
/// bar of ``AgentThreadView`` does with the tile margin.
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

  /// The longest text, in characters, that a notice with no description keeps
  /// on its title line. The titles of the kit are shorter, and a longer text
  /// is a sentence that an agent put in the title.
  static let longestTitleLength = 60

  /// What the bar of a notice shows.
  struct Lines: Equatable {
    /// The title line.
    let title: String

    /// The explanation below the title line, or an empty text for none.
    let explanation: String
  }

  /// The title line and the explanation of a notice.
  ///
  /// The agent gives the title and the description, and each bar has a title
  /// line. An empty title takes the name of the severity as its title. So does
  /// a long title with no description, which is a sentence, and the sentence
  /// is then the explanation.
  ///
  /// - Parameters:
  ///   - severity: The severity of the notice.
  ///   - title: The title of the notice.
  ///   - description: The description of the notice, or `nil`.
  /// - Returns: The lines of the bar.
  static func lines(severity: NoticeSeverity, title: String, description: String?) -> Lines {
    let title = Self.trimmed(title)
    let description = Self.trimmed(description ?? "")
    if title.isEmpty {
      return Lines(title: severityLabel(severity), explanation: description)
    }
    if description.isEmpty, title.count > longestTitleLength {
      return Lines(title: severityLabel(severity), explanation: title)
    }
    return Lines(title: title, explanation: description)
  }

  /// A text with no white space at its ends.
  ///
  /// - Parameter text: The text of a notice.
  /// - Returns: The trimmed text.
  private static func trimmed(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The accessibility label of the banner of a notice.
  ///
  /// - Parameter notice: The notice.
  /// - Returns: The severity, the title and the description, separated by
  ///   commas. A notice with no description, or with an empty title, gives no
  ///   part for it.
  private static func label(for notice: SessionNotice) -> String {
    [severityLabel(notice.severity), notice.title, notice.description]
      .compactMap { $0.map(trimmed) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  var body: some View {
    let lines = Self.lines(severity: notice.severity, title: notice.title, description: notice.description)
    NoticeRow(
      severity: notice.severity, title: lines.title, description: lines.explanation,
      label: Self.label(for: notice), identifier: SessionNoticeBanner.identifier(for: notice.id),
      dismissIdentifier: SessionNoticeBanner.dismissIdentifier(for: notice.id), dismiss: dismiss)
  }
}

extension StatusBar.Message.Severity {
  /// The severity of the bar of a notice.
  ///
  /// - Parameter severity: The severity of the notice. A severity that the kit
  ///   does not know informs, as the tint of the theme has it
  ///   (`Theme.tint(for:)`).
  init(notice severity: NoticeSeverity) {
    switch severity {
    case .info, .unknown: self = .information
    case .warning: self = .warning
    case .error: self = .failure
    }
  }
}

/// One row of a notice: a dismissible ``StatusBar`` with the symbol and the
/// tint of a severity, a title line and an explanation.
///
/// The bar gives the layout, the edge and the accessibility elements. The kit
/// style of a bar button (``AgentStatusBarActionStyle``) gives the Dismiss
/// button its button style and its scope. ``NoticeBanner`` and the notice of a request that the agent withdraws
/// (``WithdrawnNoticeRow``) show this row.
struct NoticeRow: View {
  /// The severity, which gives the symbol and the tint.
  let severity: NoticeSeverity

  /// The title, in the headline font.
  let title: String

  /// The explanation below the title line. An empty explanation shows no line.
  let description: String

  /// The accessibility label of the text.
  let label: String

  /// The accessibility identifier of the text.
  let identifier: String

  /// The accessibility identifier of the Dismiss button.
  let dismissIdentifier: String

  /// The closure that the Dismiss button calls.
  let dismiss: () -> Void

  var body: some View {
    StatusBar(
      message: StatusBar.Message(
        title: title, explanation: description, symbolName: NoticeBanner.symbolName(for: severity),
        identifier: identifier, severity: StatusBar.Message.Severity(notice: severity), accessibilityLabel: label,
        symbolHelp: NoticeBanner.severityLabel(severity)),
      action: .makeDismiss(identifier: dismissIdentifier, perform: dismiss)
    )
    .statusBarActionStyle(AgentStatusBarActionStyle())
  }
}

#Preview("Notice") {
  let notice = Notice(
    severity: .warning, title: "The context is almost full",
    description: "The agent compacts the context before the next prompt.")
  SessionNoticeBanner(session: .preview(transcript: [.update(.notice(notice))]))
}

#Preview("A sentence in the title of a notice") {
  let notice = Notice(
    severity: .warning,
    title: "The workspace index is out of date, so the agent can miss the files that you changed today.")
  SessionNoticeBanner(session: .preview(transcript: [.update(.notice(notice))]))
}
