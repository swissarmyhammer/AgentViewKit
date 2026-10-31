import AVKit
import EditorTheme
import QuickLookThumbnailing
import SwiftUI
import Textual
import UniformTypeIdentifiers

/// The sizes of the default attachment and content block views, at the default
/// theme font. A view scales each one with its ``ThemeFontScale``.
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

  /// Makes the thumbnail of a document at a scale: the scale of the display,
  /// times the scale of the theme font of the preview.
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

  @ThemeFontScale(.display) private var fontScale

  var body: some View {
    AsyncImage(url: attachment.url) { phase in
      LoadStateView(attachment: attachment, state: Self.state(of: phase)) { image in
        image
          .resizable()
          .scaledToFit()
          .frame(maxHeight: PreviewLayout.maximumPreviewHeight * fontScale)
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
  @ThemeFontScale(.display) private var fontScale

  var body: some View {
    LoadStateView(attachment: attachment, state: state) { image in
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxHeight: PreviewLayout.maximumPreviewHeight * fontScale)
        .accessibilityLabel(attachment.name)
    }
    .task(id: attachment.url) {
      state = await loader.thumbnail(attachment.url, displayScale * fontScale)
    }
  }

  /// Makes the QuickLook thumbnail of a file. ``AttachmentPreviewLoader/files``
  /// uses it.
  ///
  /// - Parameters:
  ///   - url: The location of the file.
  ///   - scale: The scale of the bitmap over ``PreviewLayout/thumbnailSize``.
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

  /// The height of the player at the default theme font.
  let height: CGFloat

  @State private var player: AVPlayer?
  @Environment(\.attachmentPreviewLoader) private var loader
  @ThemeFontScale(.display) private var fontScale

  /// The height of a player under a theme font.
  ///
  /// The system draws the controls of a player, and they do not shrink with
  /// the theme font. So a smaller font keeps the height, and a larger font
  /// scales it, so that the player keeps its place among the text.
  ///
  /// - Parameters:
  ///   - height: The height at the default theme font.
  ///   - fontScale: The ``ThemeFontScale`` of the player.
  /// - Returns: The height of the frame of the player.
  static func frameHeight(_ height: CGFloat, fontScale: CGFloat) -> CGFloat {
    height * max(fontScale, 1)
  }

  var body: some View {
    VideoPlayer(player: player)
      .frame(height: Self.frameHeight(height, fontScale: fontScale))
      .task(id: url) {
        player = loader.player(url)
      }
      .onDisappear {
        player?.pause()
      }
  }
}

// MARK: - Previews

/// One part of an attachment preview in the canvas, with padding.
///
/// The part reads its files through a loader of the previews, so that it
/// reads no file on disk: the image is in a `data:` URL, and the loader holds
/// each other file in memory.
private struct AttachmentPreviewSample<Content: View>: View {
  /// The loader that the part reads its files through.
  let loader: AttachmentPreviewLoader

  /// The part.
  let content: Content

  var body: some View {
    content
      .environment(\.attachmentPreviewLoader, loader)
      .padding()
  }
}

extension AttachmentPreviewSample where Content == AttachmentPreview {
  /// Makes the sample of the preview of a file.
  ///
  /// - Parameters:
  ///   - attachment: The file.
  ///   - renderer: The renderer of the preview.
  ///   - loader: The loader that the preview reads the file through. The
  ///     default holds each file of the previews in memory.
  init(
    attachment: Attachment, renderer: AttachmentView.Renderer,
    loader: AttachmentPreviewLoader = PreviewFixtures.attachmentPreviewLoader
  ) {
    self.init(loader: loader, content: AttachmentPreview(attachment: attachment, renderer: renderer))
  }
}

extension AttachmentPreviewSample where Content == ThumbnailPreview {
  /// Makes the sample of the thumbnail of a file.
  ///
  /// - Parameter attachment: The file. The loader of the previews holds it
  ///   in memory.
  init(thumbnailOf attachment: Attachment) {
    self.init(loader: PreviewFixtures.attachmentPreviewLoader, content: ThumbnailPreview(attachment: attachment))
  }
}

#Preview("An image") {
  AttachmentPreviewSample(attachment: PreviewFixtures.wideImageAttachment, renderer: .image)
}

#Preview("A text file") {
  AttachmentPreviewSample(attachment: PreviewFixtures.logFileAttachment, renderer: .text)
}

#Preview("A long text file") {
  ScrollView {
    AttachmentPreviewSample(attachment: PreviewFixtures.longLogFileAttachment, renderer: .text)
  }
}

#Preview("An audio file") {
  AttachmentPreviewSample(attachment: PreviewFixtures.audioAttachment, renderer: .audio)
}

#Preview("A video file") {
  AttachmentPreviewSample(attachment: PreviewFixtures.videoAttachment, renderer: .movie)
}

#Preview("A kind of file with no preview") {
  AttachmentPreviewSample(attachment: PreviewFixtures.archiveAttachment, renderer: .chip)
}

#Preview("A file that is missing") {
  // The loader holds no text for the source file, so the load fails and the
  // chip shows.
  AttachmentPreviewSample(attachment: PreviewFixtures.sourceFileAttachment, renderer: .code)
}

#Preview("A file that is still loading") {
  AttachmentPreviewSample(
    attachment: PreviewFixtures.logFileAttachment, renderer: .text,
    loader: PreviewFixtures.pendingAttachmentPreviewLoader)
}

#Preview("Thumbnail of a wide image") {
  AttachmentPreviewSample(thumbnailOf: PreviewFixtures.wideImageAttachment)
}

#Preview("Thumbnail of a tall image") {
  AttachmentPreviewSample(thumbnailOf: PreviewFixtures.tallImageAttachment)
}

#Preview("Thumbnail of a very small image") {
  AttachmentPreviewSample(thumbnailOf: PreviewFixtures.smallImageAttachment)
}
