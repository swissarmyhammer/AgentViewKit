import AVKit
import QuickLookThumbnailing
import SwiftUI
import Textual
import UniformTypeIdentifiers

/// The sizes of the default attachment views.
private enum PreviewLayout {
  /// The largest height of an image or a document thumbnail, in points.
  static let maximumPreviewHeight: CGFloat = 240

  /// The size of the thumbnail that QuickLook makes, in points.
  static let thumbnailSize = CGSize(width: maximumPreviewHeight, height: maximumPreviewHeight)

  /// The height of an audio player, which shows the controls only.
  static let audioPlayerHeight: CGFloat = 44

  /// The height of a movie player, in points.
  static let moviePlayerHeight: CGFloat = 240
}

/// The default view of one renderer (plan.md §3.6).
///
/// ``AttachmentView`` selects the renderer. A view that cannot load its file
/// shows the ``AttachmentChip`` in its place.
struct AttachmentPreview: View {
  /// The attached file.
  let attachment: Attachment

  /// The renderer to use.
  let renderer: AttachmentView.Renderer

  var body: some View {
    switch renderer {
    case .image:
      ImagePreview(attachment: attachment)
    case .pdf:
      ThumbnailPreview(attachment: attachment)
    case .text, .code:
      TextFilePreview(attachment: attachment)
    case .audio:
      MediaPlayerPreview(url: attachment.url, height: PreviewLayout.audioPlayerHeight)
    case .movie:
      MediaPlayerPreview(url: attachment.url, height: PreviewLayout.moviePlayerHeight)
    case .chip:
      AttachmentChip(attachment)
    }
  }
}

// MARK: - Load state

/// The state of a value that a preview loads from its file.
enum PreviewLoadState<Value> {
  /// The load did not end yet.
  case loading
  /// The load gave the value.
  case loaded(Value)
  /// The load failed.
  case failed
}

/// Shows a spinner, the loaded value, or the chip of the file.
private struct LoadStateView<Value, Content: View>: View {
  /// The attached file, for the chip.
  let attachment: Attachment

  /// The state of the load.
  let state: PreviewLoadState<Value>

  /// The view of a loaded value.
  @ViewBuilder let content: (Value) -> Content

  var body: some View {
    switch state {
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .loaded(let value):
      content(value)
    case .failed:
      AttachmentChip(attachment)
    }
  }
}

// MARK: - Image

/// A preview of an image file.
private struct ImagePreview: View {
  /// The image file.
  let attachment: Attachment

  var body: some View {
    AsyncImage(url: attachment.url) { phase in
      LoadStateView(attachment: attachment, state: Self.state(of: phase)) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
          .accessibilityLabel(attachment.name)
      }
    }
  }

  /// The load state of an image phase.
  ///
  /// - Parameter phase: The phase of the image load.
  /// - Returns: The matching load state.
  private static func state(of phase: AsyncImagePhase) -> PreviewLoadState<Image> {
    switch phase {
    case .success(let image):
      .loaded(image)
    case .failure:
      .failed
    case .empty:
      .loading
    @unknown default:
      .loading
    }
  }
}

// MARK: - Document thumbnail

/// A QuickLook thumbnail of a document, such as a PDF file.
private struct ThumbnailPreview: View {
  /// The document file.
  let attachment: Attachment

  @State private var state: PreviewLoadState<NSImage> = .loading
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    LoadStateView(attachment: attachment, state: state) { image in
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
        .accessibilityLabel(attachment.name)
    }
    .task(id: attachment.url) {
      state = await Self.thumbnail(of: attachment.url, scale: displayScale)
    }
  }

  /// Makes the thumbnail of a file.
  ///
  /// - Parameters:
  ///   - url: The location of the file.
  ///   - scale: The scale of the display.
  /// - Returns: The thumbnail, or ``PreviewLoadState/failed`` when QuickLook
  ///   cannot make one.
  private static func thumbnail(of url: URL, scale: CGFloat) async -> PreviewLoadState<NSImage> {
    let request = QLThumbnailGenerator.Request(
      fileAt: url, size: PreviewLayout.thumbnailSize, scale: scale,
      representationTypes: .thumbnail)
    guard
      let representation = try? await QLThumbnailGenerator.shared
        .generateBestRepresentation(for: request)
    else { return .failed }
    return .loaded(representation.nsImage)
  }
}

// MARK: - Text

/// The text of a text file or a source file.
private struct TextFilePreview: View {
  /// The text file.
  let attachment: Attachment

  @State private var state: PreviewLoadState<String> = .loading

  var body: some View {
    LoadStateView(attachment: attachment, state: state) { text in
      AttachmentTextContent(text: text, type: attachment.type, filename: attachment.name)
    }
    .task(id: attachment.url) {
      state = await AttachmentTextLoader.text(of: attachment.url).map { .loaded($0) } ?? .failed
    }
  }
}

/// Shows text by its type (plan.md §4.1, §4.2).
///
/// A source type shows in a ``CodeBlockView``. A markdown type shows as
/// Markdown through Textual. Other text shows as plain text through Textual.
struct AttachmentTextContent: View {
  /// The markdown type.
  static let markdown = UTType(importedAs: "net.daringfireball.markdown")

  /// The text to show.
  let text: String

  /// The type of the text.
  let type: UTType

  /// The file name for the code block header, or `nil`.
  let filename: String?

  var body: some View {
    if AttachmentView.renderer(for: type) == .code {
      CodeBlockView(code: text, language: type.preferredFilenameExtension, filename: filename)
    } else if type.conforms(to: Self.markdown) {
      StructuredText(markdown: text)
    } else {
      StructuredText(text, parser: PlainTextParser())
    }
  }
}

/// A Textual parser that keeps the text as it is.
private struct PlainTextParser: MarkupParser {
  /// Gives the text with no attributes.
  ///
  /// - Parameter input: The text.
  /// - Returns: The text as an attributed string.
  func attributedString(for input: String) throws -> AttributedString {
    AttributedString(input)
  }
}

/// Reads the start of a text file for a preview.
nonisolated enum AttachmentTextLoader {
  /// The largest number of bytes that a preview reads: 256 KiB.
  static let byteLimit = 262_144

  /// Reads at most ``byteLimit`` bytes of a file as UTF-8 text.
  ///
  /// The read occurs off the main actor.
  ///
  /// - Parameter url: The location of the file.
  /// - Returns: The text, or `nil` when the file cannot be read.
  @concurrent
  static func text(of url: URL) async -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    guard let data = try? handle.read(upToCount: byteLimit) else { return nil }
    return String(decoding: data, as: UTF8.self)
  }
}

// MARK: - Media

/// An AVKit player for an audio or a movie file.
private struct MediaPlayerPreview: View {
  /// The media file.
  let url: URL

  /// The height of the player.
  let height: CGFloat

  @State private var player: AVPlayer?

  var body: some View {
    VideoPlayer(player: player)
      .frame(height: height)
      .task(id: url) {
        player = AVPlayer(url: url)
      }
      .onDisappear {
        player?.pause()
      }
  }
}
