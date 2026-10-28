import EditorCommandsUI
import SwiftUI

/// Writes the bytes of a content block to its block file, and shows each
/// state of the write (plan.md §9 A2, §9 F).
///
/// A view that needs a file URL for the bytes of a block, such as
/// ``AudioPlayerView`` and ``BlobResourceView``, shows its content in this
/// view. The view gets the bytes from its byte source when the task of `id`
/// starts, writes them through ``ContentBlockFile/write(_:named:)``, and keeps
/// the state of the write: ``PreviewLoadState/loading`` while the write runs,
/// then ``PreviewLoadState/loaded(_:)`` with the URL of the file, or
/// ``PreviewLoadState/failed`` when the source has no bytes or the write
/// fails.
///
/// The view calls `report` in the same step as each change of its state. The
/// write runs in a task, so a test waits for the report before it reads the
/// view.
struct BlockFileWriteView<ID: Equatable, Content: View>: View {
  /// The value whose change starts a new write.
  let id: ID

  /// The file name of the block file.
  let name: String

  /// The report that gets each state of the write, or `nil`.
  let report: ObservationReport<PreviewLoadState<URL>>?

  /// The byte source: the bytes to write, or `nil` when the block has no
  /// bytes to write.
  let bytes: () -> Data?

  /// The view of a state of the write.
  @ViewBuilder let content: (PreviewLoadState<URL>) -> Content

  /// The state of the write.
  @State private var state: PreviewLoadState<URL> = .loading

  var body: some View {
    content(state)
      .task(id: id) { await writeFile() }
  }

  /// Writes the bytes of the byte source to the block file, and records the
  /// state of the write.
  private func writeFile() async {
    show(.loading)
    guard let data = bytes() else {
      show(.failed)
      return
    }
    show(await ContentBlockFile.write(data, named: name).map { .loaded($0) } ?? .failed)
  }

  /// Sets the state of the write, and reports it through ``report``.
  ///
  /// - Parameter newState: The new state of the write.
  private func show(_ newState: PreviewLoadState<URL>) {
    state = newState
    report?(newState)
  }
}

#Preview("Block file write") {
  let archive = PreviewFixtures.archiveAttachment
  BlockFileWriteView(
    id: archive.name, name: archive.name, report: nil,
    bytes: { Data(count: PreviewFixtures.binaryResourceSize) }
  ) { state in
    switch state {
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .loaded(let url):
      Text(url.lastPathComponent)
    case .failed:
      Text(verbatim: "The write failed")
    }
  }
  .padding()
}
