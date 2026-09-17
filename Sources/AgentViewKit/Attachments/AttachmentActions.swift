import AppKit
import OSLog
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// The file actions of the inspector and of an artifact (plan.md §3.6):
/// Open, Reveal in Finder, Share, Save, and pop-out Quick Look.
struct AttachmentActions: View {
  /// One file action.
  enum Action: String, CaseIterable {
    /// Opens the file in its default application.
    case open
    /// Shows the file in the Finder.
    case reveal
    /// Shares the file.
    case share
    /// Saves a copy of the file.
    case save
    /// Shows the file in a Quick Look panel.
    case quickLook = "quicklook"

    /// The accessibility identifier of the action, such as
    /// `inspector-open`.
    ///
    /// - Parameter prefix: The start of the identifier.
    /// - Returns: The identifier.
    func identifier(prefix: String) -> String {
      "\(prefix)-\(rawValue)"
    }
  }

  /// The accessibility identifiers of each action, in display order.
  ///
  /// - Parameter prefix: The start of each identifier.
  /// - Returns: The identifiers.
  static func identifiers(prefix: String) -> [String] {
    Action.allCases.map { $0.identifier(prefix: prefix) }
  }

  /// The file of the actions.
  let attachment: Attachment

  /// The start of the accessibility identifier of each action.
  let identifierPrefix: String

  @State private var isExporting = false
  @State private var quickLookURL: URL?

  private let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentActions")

  var body: some View {
    HStack {
      Button("Open", systemImage: "arrow.up.forward.app", action: didTapOpen)
        .accessibilityIdentifier(Action.open.identifier(prefix: identifierPrefix))
      Button("Reveal in Finder", systemImage: "folder", action: didTapReveal)
        .accessibilityIdentifier(Action.reveal.identifier(prefix: identifierPrefix))
      ShareLink(item: attachment.url) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
      .accessibilityIdentifier(Action.share.identifier(prefix: identifierPrefix))
      Button("Save", systemImage: "square.and.arrow.down") { isExporting = true }
        .accessibilityIdentifier(Action.save.identifier(prefix: identifierPrefix))
      Button("Quick Look", systemImage: "eye") { quickLookURL = attachment.url }
        .accessibilityIdentifier(Action.quickLook.identifier(prefix: identifierPrefix))
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.glass)
    .fileExporter(
      isPresented: $isExporting,
      document: AttachmentDocument(url: attachment.url),
      contentType: attachment.type,
      defaultFilename: attachment.name,
      onCompletion: { FileExportLog.record($0, of: attachment.name, to: logger) }
    )
    .quickLookPreview($quickLookURL)
  }

  /// Opens the file in its default application.
  private func didTapOpen() {
    guard NSWorkspace.shared.open(attachment.url) else {
      logger.error("The workspace did not open \(attachment.url, privacy: .private).")
      return
    }
  }

  /// Shows the file in the Finder.
  private func didTapReveal() {
    NSWorkspace.shared.activateFileViewerSelecting([attachment.url])
  }
}

/// A document that writes a copy of a file, for the file exporter.
nonisolated struct AttachmentDocument: ExportOnlyDocument {
  /// The exporter does not read documents, so any data type is readable.
  static let readableContentTypes: [UTType] = [.data]

  /// The file to copy.
  let url: URL

  /// Makes a document for a file.
  ///
  /// - Parameter url: The file to copy.
  init(url: URL) {
    self.url = url
  }

  /// Reads the file into a file wrapper for the write.
  ///
  /// - Parameter configuration: The write configuration.
  /// - Returns: A file wrapper with the contents of the file.
  /// - Throws: The error of the read.
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    try FileWrapper(url: url, options: .immediate)
  }
}
