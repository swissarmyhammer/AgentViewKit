import FoundationModelsACP
import SwiftUI

/// The default view of a sound block (plan.md §9 A2, §9 F).
///
/// AVKit plays a file, so the view first writes the bytes of the sound to a
/// local file. Then it shows an AVKit player with the controls only. While
/// the write runs, the view shows a spinner. When the write fails, the view
/// shows a label.
///
/// The view plays an ACP `AudioContent` that a transcript entry holds. The
/// view decodes the base64 data of the ACP value before the write. Data that
/// is not base64 shows the label.
public struct AudioPlayerView: View {
  /// The accessibility identifier of the label for a sound that cannot play.
  public static let failureIdentifier = "audio-block-failure"

  /// The file name stem of a sound.
  private static let fileStem = "audio"

  /// The ACP sound to play, as the transcript entry holds it.
  let audio: FoundationModelsACP.AudioContent

  /// The state of the file write.
  @State private var file: PreviewLoadState<URL> = .loading

  /// Makes the view of an ACP sound of a transcript entry.
  ///
  /// - Parameter audio: The ACP sound to play, as the entry holds it.
  public init(audio: FoundationModelsACP.AudioContent) {
    self.audio = audio
  }

  public var body: some View {
    content
      .task(id: audio) { await writeFile() }
  }

  /// Writes the bytes of the sound to a local file, and records the state of
  /// the write. Data that is not base64 gives the failed state.
  private func writeFile() async {
    file = .loading
    guard let data = Data(base64Encoded: audio.data) else {
      file = .failed
      return
    }
    let name = ContentBlockFile.fileName(uri: nil, mimeType: audio.mimeType.rawValue, stem: Self.fileStem)
    file = await ContentBlockFile.write(data, named: name).map { .loaded($0) } ?? .failed
  }

  /// The spinner, the player, or the failure label.
  @ViewBuilder private var content: some View {
    switch file {
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .loaded(let url):
      MediaPlayerPreview(url: url, height: PreviewLayout.audioPlayerHeight)
        .accessibilityLabel("Audio")
    case .failed:
      Label("The audio cannot play", systemImage: "speaker.slash")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.failureIdentifier)
    }
  }
}
