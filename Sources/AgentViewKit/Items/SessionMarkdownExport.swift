import ACPMarkdown
import FoundationModelsACPClient
import OSLog
import Observation
import SwiftUI

/// A Markdown export of a session, ready for the save panel (D202).
///
/// ``AgentCommandVerb/exportMarkdown`` and the Export button of
/// ``MessageActions`` make the export in the same way:
///
/// - The text is `SessionModel.markdown(options:)`, with no thoughts, with the
///   labels of the string catalog of the kit (``MarkdownExportLabels``), and
///   with the name of the agent when the kit knows it.
/// - The default file name is `SessionModel.exportFileName`.
/// - The default folder is `SessionModel.exportFolder`.
struct SessionMarkdownExport: Equatable {
  /// The Markdown text of the session.
  let text: String

  /// The default name of the file, with its extension.
  let fileName: String

  /// The default folder of the save panel, or `nil` when the session has
  /// no working directory.
  let folder: URL?

  /// Makes the export of `session`.
  ///
  /// The call reads the session model one time and keeps no reference to
  /// it.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - agentName: The name of the agent, for the headings of the turns of
  ///     the agent, or `nil` for the catalog word.
  init(session: SessionModel, agentName: String?) {
    let options = SessionMarkdown.Options(
      includeThoughts: false, agentName: agentName, labels: MarkdownExportLabels.catalog)
    text = session.markdown(options: options)
    fileName = session.exportFileName
    folder = session.exportFolder
  }

  /// Tells if `session` has history to export: an entry of its transcript
  /// that came from the agent on the wire.
  ///
  /// A transcript with only local entries, such as a prompt that the agent
  /// did not get or an error of a request, gives no export.
  ///
  /// - Parameter session: The session model.
  /// - Returns: `true` when the transcript has a wire entry.
  static func hasHistory(_ session: SessionModel) -> Bool {
    session.transcript.contains { $0.id.origin == .wire }
  }
}

/// The export that waits for the save panel of a view.
///
/// The thread scope (``AgentCommandScope``) and a ``MessageActions`` row with
/// no scope each own one presenter, and show its export with
/// ``MarkdownExportPresentation``. The save panel clears the export when it
/// closes.
@Observable final class MarkdownExportPresenter {
  /// The export that the save panel shows, or `nil` when no save panel
  /// shows.
  private(set) var pending: SessionMarkdownExport?

  /// Shows the save panel for `export`.
  ///
  /// - Parameter export: The export to save.
  func present(_ export: SessionMarkdownExport) {
    pending = export
  }

  /// Clears the export after the save panel closes.
  func exportDidClose() {
    pending = nil
  }
}

/// Shows the save panel of a ``MarkdownExportPresenter``.
///
/// The panel is the `fileExporter` of SwiftUI, with the default file name
/// and the default folder (`fileDialogDefaultDirectory(_:)`) of the export.
/// The panel asks before it replaces a file. A save that fails goes to the
/// log through ``FileExportLog``.
struct MarkdownExportPresentation: ViewModifier {
  /// The presenter whose export the panel saves.
  let presenter: MarkdownExportPresenter

  /// The log of a save that fails.
  private let logger = Logger(subsystem: "AgentViewKit", category: "MarkdownExportPresentation")

  func body(content: Content) -> some View {
    // The body reads the export itself, so that a new value evaluates the
    // body again. A read in a binding closure is not tracked.
    let pending = presenter.pending
    content
      .fileExporter(
        isPresented: Binding(
          get: { pending != nil }, set: { if !$0 { presenter.exportDidClose() } }),
        document: pending.map { MarkdownDocument(text: $0.text) },
        contentType: MarkdownDocument.contentType,
        defaultFilename: pending?.fileName,
        onCompletion: { FileExportLog.record($0, of: pending?.fileName ?? "", to: logger) }
      )
      .fileDialogDefaultDirectory(pending?.folder)
  }
}
