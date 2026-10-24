import SwiftUI

/// The view of the binary contents of an embedded resource block
/// (plan.md §9 A2, §9 F).
///
/// An ``AttachmentView`` reads its file, so the view first writes the bytes
/// to their block file (``ContentBlockFile``) through a
/// ``BlockFileWriteView``. While the write runs, the view shows a spinner.
/// Then it shows the file in an ``AttachmentView``, as a
/// message attachment shows: the default renderer of the type, a press that
/// selects the file in the inspector of the environment, and the
/// ``AgentAttachmentVerb`` commands in the context menu. When the write fails,
/// the view shows the ``AttachmentChip`` of the resource.
struct BlobResourceView: View {
  /// The bytes of the resource.
  let data: Data

  /// The attachment of the block file of ``data``.
  let file: Attachment

  @Environment(\.resourceFileReport) private var reportWrite

  var body: some View {
    BlockFileWriteView(id: file.url, name: file.name, report: reportWrite, bytes: resourceBytes) { write in
      content(of: write)
    }
  }

  /// The byte source of the resource: its bytes, as the block holds them.
  ///
  /// - Returns: ``data``.
  private func resourceBytes() -> Data? {
    data
  }

  /// The spinner, the attachment view of the file, or the chip.
  ///
  /// - Parameter write: The state of the file write.
  @ViewBuilder private func content(of write: PreviewLoadState<URL>) -> some View {
    switch write {
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .loaded:
      AttachmentView(file)
    case .failed:
      AttachmentChip(file)
    }
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets each state of the file write of the
  /// nearest ``BlobResourceView``, or `nil`.
  ///
  /// The view calls the report in the same step as the change of its state.
  /// The write runs in a task, so a test waits for the report before it reads
  /// the view.
  @Entry var resourceFileReport: ObservationReport<PreviewLoadState<URL>>? = nil
}

#Preview("Blob resource") {
  let archive = PreviewFixtures.archiveAttachment
  let data = Data(count: PreviewFixtures.binaryResourceSize)
  BlobResourceView(data: data, file: ContentBlockFile.attachment(of: data, named: archive.name, type: archive.type))
    .padding()
}
