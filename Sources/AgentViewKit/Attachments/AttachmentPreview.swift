import AVKit
import QuickLookThumbnailing
import SwiftUI
import Textual
import UniformTypeIdentifiers

/// The sizes of the default attachment and content block views.
enum PreviewLayout {
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

// MARK: - Loader

/// Reads the files that the parts of an ``AttachmentPreview`` show.
///
/// The default loader, ``files``, reads each file at its URL. A `#Preview`
/// gives a loader that holds its files in memory, so that the canvas reads no
/// file on disk.
struct AttachmentPreviewLoader {
  /// Reads the text of a text file. The result is `nil` when the file cannot
  /// be read.
  let text: @MainActor (URL) async -> String?

  /// Makes the thumbnail of a document at the scale of a display.
  let thumbnail: @MainActor (URL, CGFloat) async -> PreviewLoadState<NSImage>

  /// Makes the player of an audio or a movie file.
  let player: @MainActor (URL) -> AVPlayer

  /// The loader that reads each file at its URL.
  static let files = AttachmentPreviewLoader(
    text: AttachmentTextLoader.text(of:), thumbnail: ThumbnailPreview.thumbnail(of:scale:),
    player: AVPlayer.init(url:))
}

extension EnvironmentValues {
  /// The loader that the parts of an ``AttachmentPreview`` read their files
  /// through.
  @Entry var attachmentPreviewLoader = AttachmentPreviewLoader.files
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
  @Environment(\.attachmentPreviewLoader) private var loader

  var body: some View {
    LoadStateView(attachment: attachment, state: state) { image in
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight)
        .accessibilityLabel(attachment.name)
    }
    .task(id: attachment.url) {
      state = await loader.thumbnail(attachment.url, displayScale)
    }
  }

  /// Makes the QuickLook thumbnail of a file. ``AttachmentPreviewLoader/files``
  /// uses it.
  ///
  /// - Parameters:
  ///   - url: The location of the file.
  ///   - scale: The scale of the display.
  /// - Returns: The thumbnail, or ``PreviewLoadState/failed`` when QuickLook
  ///   cannot make one.
  static func thumbnail(of url: URL, scale: CGFloat) async -> PreviewLoadState<NSImage> {
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
  @Environment(\.attachmentPreviewLoader) private var loader

  var body: some View {
    LoadStateView(attachment: attachment, state: state) { text in
      AttachmentTextContent(text: text, type: attachment.type, filename: attachment.name)
    }
    .task(id: attachment.url) {
      state = await loader.text(attachment.url).map { .loaded($0) } ?? .failed
    }
  }
}

/// Shows text by its type (plan.md §4.1, §4.2).
///
/// A source type shows in a ``CodeBlockView``. A markdown type shows as
/// Markdown through Textual. A fenced code block in the markdown shows in a
/// ``CodeBlockView`` through ``EditorKitCodeBlockStyle``. Other text shows as
/// plain text through Textual.
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
        .textual.codeBlockStyle(EditorKitCodeBlockStyle())
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
///
/// ``AudioPlayerView`` uses this view for a sound block.
struct MediaPlayerPreview: View {
  /// The media file.
  let url: URL

  /// The height of the player.
  let height: CGFloat

  @State private var player: AVPlayer?
  @Environment(\.attachmentPreviewLoader) private var loader

  var body: some View {
    VideoPlayer(player: player)
      .frame(height: height)
      .task(id: url) {
        player = loader.player(url)
      }
      .onDisappear {
        player?.pause()
      }
  }
}

// The previews read no file on disk: the image is in a `data:` URL, and the
// loader of the previews holds each other file in memory.

#Preview("An image") {
  AttachmentPreview(attachment: PreviewFixtures.wideImageAttachment, renderer: .image)
    .padding()
}

#Preview("A text file") {
  AttachmentPreview(attachment: PreviewFixtures.logFileAttachment, renderer: .text)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("A long text file") {
  ScrollView {
    AttachmentPreview(attachment: PreviewFixtures.longLogFileAttachment, renderer: .text)
      .padding()
  }
  .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
}

#Preview("An audio file") {
  AttachmentPreview(attachment: PreviewFixtures.audioAttachment, renderer: .audio)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("A video file") {
  AttachmentPreview(attachment: PreviewFixtures.videoAttachment, renderer: .movie)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("A kind of file with no preview") {
  AttachmentPreview(attachment: PreviewFixtures.archiveAttachment, renderer: .chip)
    .padding()
}

#Preview("A file that is missing") {
  // The loader holds no text for the source file, so the load fails and the
  // chip shows.
  AttachmentPreview(attachment: PreviewFixtures.sourceFileAttachment, renderer: .code)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("A file that is still loading") {
  AttachmentPreview(attachment: PreviewFixtures.logFileAttachment, renderer: .text)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.pendingAttachmentPreviewLoader)
    .padding()
}

#Preview("Thumbnail of a wide image") {
  ThumbnailPreview(attachment: PreviewFixtures.wideImageAttachment)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("Thumbnail of a tall image") {
  ThumbnailPreview(attachment: PreviewFixtures.tallImageAttachment)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}

#Preview("Thumbnail of a very small image") {
  ThumbnailPreview(attachment: PreviewFixtures.smallImageAttachment)
    .environment(\.attachmentPreviewLoader, PreviewFixtures.attachmentPreviewLoader)
    .padding()
}
