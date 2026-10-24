import SwiftUI

/// The view of the binary contents of an embedded resource block
/// (plan.md §9 A2, §9 F).
///
/// An ``AttachmentView`` reads its file, so the view first writes the bytes
/// to their block file (``ContentBlockFile``). While the write runs, the view
/// shows a spinner. Then it shows the file in an ``AttachmentView``, as a
/// message attachment shows: the default renderer of the type, a press that
/// selects the file in the inspector of the environment, and the
/// ``AgentAttachmentVerb`` commands in the context menu. When the write fails,
/// the view shows the ``AttachmentChip`` of the resource.
struct BlobResourceView: View {
  /// The bytes of the resource.
  let data: Data

  /// The attachment of the block file of ``data``.
  let file: Attachment

  /// The state of the file write.
  @State private var write: PreviewLoadState<URL> = .loading

  @Environment(\.resourceFileReport) private var reportWrite

  var body: some View {
    content
      .task(id: file.url) { await writeFile() }
  }

  /// The spinner, the attachment view of the file, or the chip.
  @ViewBuilder private var content: some View {
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

  /// Writes the bytes to the block file, and records the state of the write.
  private func writeFile() async {
    show(.loading)
    show(await ContentBlockFile.write(data, named: file.name).map { .loaded($0) } ?? .failed)
  }

  /// Sets the state of the file write, and reports it through
  /// ``SwiftUI/EnvironmentValues/resourceFileReport``.
  ///
  /// - Parameter state: The new state of the file write.
  private func show(_ state: PreviewLoadState<URL>) {
    write = state
    reportWrite?(state)
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
