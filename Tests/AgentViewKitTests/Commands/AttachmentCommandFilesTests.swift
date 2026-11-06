import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the files that a command at the scope of a file view acts on
/// through the file selection (``AttachmentCommandFiles``, card ^zsr2pbf).
///
/// A command on a selected file acts on every selected file, in transcript
/// order. A command on a file that the selection does not hold acts on that
/// file alone, as in the Finder: the read gives no files, so the scope adds
/// no selection to the context of the command.
@Suite struct AttachmentCommandFilesTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The files of the thread, in transcript order.
  static let transcript = ["first.txt", "second.txt", "third.txt", "fourth.txt"].map {
    Attachment(url: URL(filePath: "/tmp/avk-command-files/\($0)"))
  }

  /// A file that the transcript order does not hold.
  static let unplaced = Attachment(url: URL(filePath: "/tmp/avk-command-files/unplaced.txt"))

  @Test func theFilesOfASelectedFileAreTheSelectionInTranscriptOrder() {
    let selection = [Self.transcript[2], Self.transcript[0], Self.transcript[1]]

    let files = AttachmentCommandFiles.files(at: Self.transcript[0], selection: selection, order: Self.transcript)

    #expect(files == Array(Self.transcript[0...2]))
  }

  @Test func aFileOutsideTheSelectionHasNoFiles() {
    let selection = [Self.transcript[0], Self.transcript[2]]

    let files = AttachmentCommandFiles.files(at: Self.transcript[1], selection: selection, order: Self.transcript)

    #expect(files.isEmpty)
  }

  /// A selected file that the transcript order does not hold, such as a
  /// file whose view went away, comes after the placed files, in selection
  /// order.
  @Test func aSelectedFileOutsideTheTranscriptOrderComesLast() {
    let selection = [Self.unplaced, Self.transcript[3], Self.transcript[1]]

    let files = AttachmentCommandFiles.files(at: Self.transcript[1], selection: selection, order: Self.transcript)

    #expect(files == [Self.transcript[1], Self.transcript[3], Self.unplaced])
  }

  /// The selection names a file by its URL. The file of the scope stands in
  /// the files with its own fields, so the context of the command holds the
  /// segment of the scope (an image names its block file with an id of its
  /// own).
  @Test func theFileOfTheScopeStandsInTheFilesWithItsOwnFields() {
    let scopeFile = Attachment(
      id: AttachmentID("block-file"), url: Self.transcript[1].url, type: .plainText, name: "second.txt", size: 1)
    let selection = [Self.transcript[0], Self.transcript[1]]

    let files = AttachmentCommandFiles.files(at: scopeFile, selection: selection, order: Self.transcript)

    #expect(files.map(\.id) == [Self.transcript[0].id, scopeFile.id])
  }
}
