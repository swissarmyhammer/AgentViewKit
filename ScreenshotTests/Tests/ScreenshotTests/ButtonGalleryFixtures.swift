@testable import AgentViewKit
import EditorStyle
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The button families of the kit at a narrow and at a wide width, for the
/// review gallery (EditorKit `style.md`, "Buttons").
///
/// Each family is one of EditorKit's button components: the action button of
/// a bar (``StatusBar``), the action buttons of a request card
/// (``PermissionView`` and ``ElicitationFooter``), and the bare toolbar
/// buttons of a row of content (``OutputCapRow`` and ``MessageActions``). At
/// the narrow width a button with too little room shows its symbol alone, and
/// at the wide width it shows its whole caption: no caption is ever cut.
@MainActor
enum ButtonGalleryFixtures {
  /// The width of a narrow column, in points: the narrow docked panel of a
  /// host.
  static let narrowWidth: CGFloat = 240

  /// The width of a wide column, in points.
  static let wideWidth: CGFloat = 640

  /// The height of each image, in points.
  static let height: CGFloat = 640

  /// The size of the narrow image.
  static let narrowSize = CGSize(width: narrowWidth, height: height)

  /// The size of the wide image.
  static let wideSize = CGSize(width: wideWidth, height: height)

  /// The output of the capped row: more rows than its limit.
  static let cappedOutput = "one\ntwo\nthree\nfour"

  /// The row limit of the capped row.
  static let cappedRowLimit = 2

  /// The accessibility identifier of the text of the capped row.
  static let capIdentifier = "gallery-cap"

  /// The accessibility identifier of the Show All button of the capped row.
  static let showAllIdentifier = "gallery-show-all"

  /// The families, from the top: a bar with its button, a permission card
  /// with its answers, the footer of an elicitation form, the capped row of
  /// an output, and the action row of a message, the tile margin apart.
  ///
  /// - Returns: The stack of the families.
  /// - Throws: The issue of `#require` when the permission fixture holds no
  ///   request.
  static func gallery() throws -> some View {
    let style = EditorStyle.default
    let session = SessionModel.previewSample
    let message = try #require(PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self))
    let rows = CommandOutputView.VisibleRows(output: cappedOutput, limit: cappedRowLimit)
    let permissionCard = try SnapshotFixtures.permissionCard()
    return VStack(alignment: .leading, spacing: style.tile.margin) {
      StatusBar(
        message: PreviewFixtures.failedTurnStatusMessage, action: PreviewFixtures.statusAction(isEnabled: true))
      permissionCard
      ElicitationFooter(
        context: ElicitationFooterContext(canSubmit: true, submit: {}, decline: {}, cancel: {}))
      OutputCapRow(rows: rows, capIdentifier: capIdentifier, showAllIdentifier: showAllIdentifier, showAll: {})
      MessageActions(entry: message)
        .environment(\.sessionModel, session)
    }
    .padding(style.tile.margin)
    .frame(maxHeight: .infinity, alignment: .top)
  }
}
