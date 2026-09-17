import SwiftUI

/// The default view of a sound block (plan.md §9 A2, §9 F).
///
/// AVKit plays a file, so the view first writes the bytes of the sound to a
/// local file. Then it shows an AVKit player with the controls only. While
/// the write runs, the view shows a spinner. When the write fails, the view
/// shows a label.
public struct AudioPlayerView: View {
  /// The accessibility identifier of the label for a sound that cannot play.
  public static let failureIdentifier = "audio-block-failure"

  /// The sound to play.
  let audio: AudioContent

  /// The state of the file write.
  @State private var file: PreviewLoadState<URL> = .loading

  /// Makes the view of a sound.
  ///
  /// - Parameter audio: The sound to play.
  public init(audio: AudioContent) {
    self.audio = audio
  }

  public var body: some View {
    content
      .task(id: audio) {
        file = .loading
        let name = ContentBlockFile.fileName(uri: nil, mimeType: audio.mimeType, stem: "audio")
        file = await ContentBlockFile.write(audio.data, named: name).map { .loaded($0) } ?? .failed
      }
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
