import Foundation
import Testing

@testable import AgentViewKit

/// Tests for the ordered selection of files of an inspector
/// (``AttachmentSelectionList``, card ^4138tmp).
///
/// A plain select replaces the selection, a toggle (Command-click, Add to
/// Selection) adds a file or takes it out, and an extend (Shift-click,
/// Extend Selection) adds each file from the anchor to the file, in
/// transcript order.
@Suite struct AttachmentSelectionListTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// Five files, in transcript order.
  static let files = (0..<5).map { Attachment(url: URL(filePath: "/tmp/avk-list/file-\($0).txt")) }

  /// The URLs of the files of `list`, in selection order.
  ///
  /// - Parameter list: The selection.
  /// - Returns: The URLs.
  static func urls(of list: AttachmentSelectionList) -> [URL] {
    list.files.map(\.url)
  }

  /// The URLs of the files at `indices` of ``files``.
  ///
  /// - Parameter indices: The positions in ``files``.
  /// - Returns: The URLs.
  static func urls(_ indices: Int...) -> [URL] {
    indices.map { files[$0].url }
  }

  /// A selection after `changes`, applied in order on the files at the
  /// given positions, with ``files`` as the transcript order.
  ///
  /// - Parameter changes: Each change and the position of its file.
  /// - Returns: The selection.
  static func list(after changes: (AttachmentSelectionChange, Int)...) -> AttachmentSelectionList {
    var list = AttachmentSelectionList()
    for (change, index) in changes {
      list.apply(change, to: files[index]) { files }
    }
    return list
  }

  @Test func aSelectHoldsOnlyTheFile() {
    let list = Self.list(after: (.select, 1))

    #expect(Self.urls(of: list) == Self.urls(1))
  }

  @Test func aSelectReplacesTheSelection() {
    let list = Self.list(after: (.select, 1), (.toggle, 3), (.select, 2))

    #expect(Self.urls(of: list) == Self.urls(2))
  }

  @Test func aToggleAddsTheFileAtTheEnd() {
    let list = Self.list(after: (.select, 3), (.toggle, 1))

    #expect(Self.urls(of: list) == Self.urls(3, 1))
  }

  @Test func aToggleOfASelectedFileTakesItOut() {
    let list = Self.list(after: (.select, 3), (.toggle, 1), (.toggle, 3))

    #expect(Self.urls(of: list) == Self.urls(1))
  }

  @Test func anExtendAddsTheRangeFromTheAnchorInTranscriptOrder() {
    let list = Self.list(after: (.select, 1), (.extend, 3))

    #expect(Self.urls(of: list) == Self.urls(1, 2, 3))
  }

  @Test func anExtendUpTheTranscriptAddsTheRangeInTranscriptOrder() {
    let list = Self.list(after: (.select, 3), (.extend, 1))

    #expect(Self.urls(of: list) == Self.urls(3, 1, 2))
  }

  /// An extend keeps the anchor, so a second extend reaches from the same
  /// file and adds only what is new.
  @Test func anExtendKeepsTheAnchor() {
    let list = Self.list(after: (.select, 2), (.extend, 3), (.extend, 0))

    #expect(Self.urls(of: list) == Self.urls(2, 3, 0, 1))
  }

  @Test func aToggleMovesTheAnchor() {
    let list = Self.list(after: (.select, 0), (.toggle, 3), (.extend, 4))

    #expect(Self.urls(of: list) == Self.urls(0, 3, 4))
  }

  @Test func anExtendWithNoAnchorAddsOnlyTheFile() {
    let list = Self.list(after: (.extend, 2))

    #expect(Self.urls(of: list) == Self.urls(2))
  }

  /// A file that the transcript order does not hold, such as a file of a row
  /// that went away, makes no range: the extend adds the file alone.
  @Test func anExtendToAFileOutOfTheOrderAddsOnlyTheFile() {
    var list = Self.list(after: (.select, 0))
    let outside = Attachment(url: URL(filePath: "/tmp/avk-list/outside.txt"))

    list.apply(.extend, to: outside) { Self.files }

    #expect(Self.urls(of: list) == Self.urls(0) + [outside.url])
  }

  /// The list compares the URL of a file, so another attachment of a
  /// selected file, with another id, is the same file.
  @Test func aToggleOfAnotherAttachmentOfASelectedFileTakesItOut() {
    var list = Self.list(after: (.select, 1))
    let sameFile = Attachment(
      id: AttachmentID("block-file"), url: Self.files[1].url, type: .plainText, name: "file-1.txt")

    list.apply(.toggle, to: sameFile) { Self.files }

    #expect(list.files.isEmpty)
  }

  @Test func aListMadeFromFilesAnchorsAtTheLastFile() {
    var list = AttachmentSelectionList(files: [Self.files[0], Self.files[2]])

    list.apply(.extend, to: Self.files[4]) { Self.files }

    #expect(Self.urls(of: list) == Self.urls(0, 2, 3, 4))
  }
}
