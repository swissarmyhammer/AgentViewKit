import OSLog
import SwiftUI

/// Writes the result of a file exporter to the log.
///
/// ``AttachmentActions`` and ``MessageActions`` save files through
/// `fileExporter`, and both record a failed save in the same way.
enum FileExportLog {
  /// Writes an error entry when the save failed. A save that succeeded
  /// writes nothing.
  ///
  /// - Parameters:
  ///   - result: The result of the file exporter.
  ///   - name: The name of the saved file.
  ///   - logger: The log of the view that saved the file.
  static func record(_ result: Result<URL, any Error>, of name: String, to logger: Logger) {
    guard case .failure(let error) = result else { return }
    logger.error("The save of \(name, privacy: .private) failed: \(error)")
  }
}

/// A document that the file exporter writes and never reads.
///
/// A conforming type gives only ``FileDocument/fileWrapper(configuration:)``.
/// The read initializer always fails.
nonisolated protocol ExportOnlyDocument: FileDocument {}

nonisolated extension ExportOnlyDocument {
  /// The exporter never reads a document, so this initializer always
  /// fails.
  ///
  /// - Parameter configuration: The read configuration.
  /// - Throws: `CocoaError.featureUnsupported`.
  init(configuration: ReadConfiguration) throws {
    throw CocoaError(.featureUnsupported)
  }
}
