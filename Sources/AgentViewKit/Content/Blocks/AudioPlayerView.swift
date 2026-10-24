import FoundationModelsACP
import SwiftUI

/// The default view of a sound block (plan.md §9 A2, §9 F).
///
/// AVKit plays a file, so the view first writes the bytes of the sound to a
/// local file through a ``BlockFileWriteView``. Then it shows an AVKit player
/// with the controls only. While the write runs, the view shows a spinner.
/// When the write fails, the view shows a label.
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

  @Environment(\.audioFileReport) private var reportFile

  /// Makes the view of an ACP sound of a transcript entry.
  ///
  /// - Parameter audio: The ACP sound to play, as the entry holds it.
  public init(audio: FoundationModelsACP.AudioContent) {
    self.audio = audio
  }

  public var body: some View {
    BlockFileWriteView(id: audio, name: fileName, report: reportFile, bytes: decodedBytes) { file in
      content(of: file)
    }
  }

  /// The file name of the sound: ``fileStem`` with the extension of its MIME
  /// type.
  private var fileName: String {
    ContentBlockFile.fileName(uri: nil, mimeType: audio.mimeType.rawValue, stem: Self.fileStem)
  }

  /// The byte source of the sound: its base64 data, decoded.
  ///
  /// - Returns: The bytes, or `nil` for data that is not base64, which gives
  ///   the failed state.
  private func decodedBytes() -> Data? {
    Data(base64Encoded: audio.data)
  }

  /// The spinner, the player, or the failure label.
  ///
  /// - Parameter file: The state of the file write.
  @ViewBuilder private func content(of file: PreviewLoadState<URL>) -> some View {
    switch file {
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .loaded(let url):
      MediaPlayerPreview(url: url, height: PreviewLayout.audioPlayerHeight)
        .accessibilityLabel(String(localized: "Audio", bundle: .module))
    case .failed:
      Label(
        String(localized: "The audio cannot play", bundle: .module),
        systemImage: SharedSymbol.audioFailure
      )
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.failureIdentifier)
    }
  }
}

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets each state of the file write of the
  /// nearest ``AudioPlayerView``, or `nil`.
  ///
  /// The view calls the report in the same step as the change of its state.
  /// The write runs in a task, so a test waits for the report before it reads
  /// the view.
  @Entry var audioFileReport: ObservationReport<PreviewLoadState<URL>>? = nil
}

#Preview("Audio") {
  // A WAV file with no samples, as base64.
  let silentWAV = "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA="
  AudioPlayerView(audio: AudioContent(data: silentWAV, mimeType: MediaType(rawValue: "audio/wav")))
}
