import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the panels of the system service of an attachment scope over
/// several files (``AttachmentPresenter``, card ^zsr2pbf).
///
/// Save and Quick Look write the state that the scope gives to its file
/// exporter and its Quick Look panel, so a test reads that state and opens
/// no panel. Open, Reveal in Finder and Share call the system, and no test
/// runs them.
@Suite @MainActor struct AttachmentPresenterTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// Three files, in transcript order.
  static let files = ["first.txt", "second.txt", "third.txt"].map {
    Attachment(url: URL(filePath: "/tmp/avk-presenter/\($0)"))
  }

  @Test func theSaveOfSeveralFilesExportsTheFirstFile() {
    let presenter = AttachmentPresenter()

    _ = presenter.run(.saveAttachment, on: Self.files)

    #expect(presenter.exportedAttachment == Self.files[0])
  }

  /// The file exporter saves one file. When its panel closes, the next file
  /// of the save shows in a panel of its own.
  @Test func eachClosedExportGivesTheNextFileOfTheSave() {
    let presenter = AttachmentPresenter()
    _ = presenter.run(.saveAttachment, on: Self.files)
    var exported: [Attachment] = []

    while let file = presenter.exportedAttachment {
      exported.append(file)
      presenter.exportDidClose()
      presenter.exportNextFile()
    }

    #expect(exported == Self.files)
  }

  @Test func quickLookOfSeveralFilesShowsTheFirstFileWithEachFileToBrowse() {
    let presenter = AttachmentPresenter()

    _ = presenter.run(.quickLookAttachment, on: Self.files)

    #expect(presenter.quickLookURL == Self.files[0].url)
    #expect(presenter.quickLookURLs == Self.files.map(\.url))
  }
}
