import AppKit
import CoreTransferable
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import os

/// The row of the files that the composer attaches to the next prompt
/// (plan.md §9 D).
///
/// The row shows one ``AttachmentChip`` for each attachment, with a remove
/// button that drops the attachment from the binding.
///
/// ``PromptInputView`` shows the row above its editor while the attachment
/// list is not empty. The composer also accepts a dropped file, a dropped
/// image, and a pasted image. See
/// ``SwiftUI/View/attachmentDropDestination(_:)``.
public struct AttachmentChips: View {
  /// The start of the accessibility identifier of each chip.
  public static let chipIdentifierPrefix = "attachment-chip-"

  /// The start of the accessibility identifier of each remove button.
  public static let removeIdentifierPrefix = "attachment-remove-"

  /// The file name, without the extension, of a dropped or pasted image.
  static let imageFileStem = "Image"

  /// The log of the row.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentChips")

  /// The attachments, in the order to show.
  @Binding var attachments: [Attachment]

  @Environment(\.agentTheme) private var theme

  /// Makes the row.
  ///
  /// - Parameter attachments: The attachments, in the order to show. A remove
  ///   button removes its attachment from this list.
  public init(attachments: Binding<[Attachment]>) {
    _attachments = attachments
  }

  /// The errors of ``writeImage(_:in:)``.
  public enum ImageError: Error, Equatable {
    /// The data is not in an image format that ImageIO can read.
    case unknownFormat
  }

  /// The accessibility identifier of the chip of an attachment.
  ///
  /// - Parameter id: The identifier of the attachment.
  /// - Returns: The identifier, such as `attachment-chip-file:///a.txt`.
  public static func chipIdentifier(for id: AttachmentID) -> String {
    AccessibilityIdentifier.make(prefix: chipIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the remove button of an attachment.
  ///
  /// - Parameter id: The identifier of the attachment.
  /// - Returns: The identifier, such as `attachment-remove-file:///a.txt`.
  public static func removeIdentifier(for id: AttachmentID) -> String {
    AccessibilityIdentifier.make(prefix: removeIdentifierPrefix, value: id.rawValue)
  }

  /// Adds the attachments of dropped or pasted items to a list.
  ///
  /// A file URL becomes ``Attachment/init(url:)``. Image data goes to a new
  /// file in `directory` (see ``writeImage(_:in:)``). The function ignores a
  /// URL that is not a file URL, data that is not an image, and a file that
  /// the list already holds.
  ///
  /// - Parameters:
  ///   - drops: The dropped or pasted items, in order.
  ///   - attachments: The list to add to.
  ///   - directory: The directory for the image files.
  /// - Returns: Whether the function added one or more attachments.
  @discardableResult
  public static func add(
    _ drops: [AttachmentDrop], to attachments: inout [Attachment],
    directory: URL = FileManager.default.temporaryDirectory
  ) -> Bool {
    var added = false
    for drop in drops {
      guard let attachment = attachment(for: drop, directory: directory),
        !attachments.contains(where: { $0.id == attachment.id })
      else { continue }
      attachments.append(attachment)
      added = true
    }
    return added
  }

  /// Writes image data to a new file and returns its attachment.
  ///
  /// The file is `Image.<extension>` in a new subdirectory of `directory`,
  /// so two images never have the same file. The extension comes from the
  /// image format of the data.
  ///
  /// - Parameters:
  ///   - data: The encoded image.
  ///   - directory: The directory for the new subdirectory.
  /// - Returns: The attachment of the new file.
  /// - Throws: ``ImageError/unknownFormat`` when ImageIO cannot read the
  ///   data, or the file system error when the write fails.
  public static func writeImage(_ data: Data, in directory: URL) throws -> Attachment {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let identifier = CGImageSourceGetType(source),
      let fileExtension = UTType(identifier as String)?.preferredFilenameExtension
    else { throw ImageError.unknownFormat }
    let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: imageFileStem).appendingPathExtension(fileExtension)
    try data.write(to: url, options: .atomic)
    return Attachment(url: url)
  }

  /// The attachment of one dropped or pasted item.
  ///
  /// - Parameters:
  ///   - drop: The item.
  ///   - directory: The directory for an image file.
  /// - Returns: The attachment, or `nil` when the item is not a file or an
  ///   image.
  private static func attachment(for drop: AttachmentDrop, directory: URL) -> Attachment? {
    switch drop {
    case .file(let url):
      guard url.isFileURL else {
        logger.debug("A dropped URL is not a file URL. The composer does not attach it.")
        return nil
      }
      return Attachment(url: url)
    case .image(let data):
      do {
        return try writeImage(data, in: directory)
      } catch {
        logger.error("The composer cannot attach an image: \(error.localizedDescription)")
        return nil
      }
    }
  }

  public var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: theme.spacing.s) {
        ForEach(attachments) { attachment in
          HStack(spacing: theme.spacing.xs) {
            AttachmentChip(attachment)
              .accessibilityElement(children: .combine)
              .accessibilityIdentifier(Self.chipIdentifier(for: attachment.id))
            Button {
              remove(attachment.id)
            } label: {
              Label(String(localized: "Remove"), systemImage: "xmark.circle.fill")
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Remove this attachment"))
            .accessibilityLabel(String(localized: "Remove \(attachment.name)"))
            .accessibilityIdentifier(Self.removeIdentifier(for: attachment.id))
          }
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  /// Removes an attachment from the binding.
  ///
  /// - Parameter id: The identifier of the attachment to remove.
  private func remove(_ id: AttachmentID) {
    attachments.removeAll { $0.id == id }
  }
}

/// One item that the user drops on, or pastes into, the composer.
public nonisolated enum AttachmentDrop: Transferable, Sendable, Hashable {
  /// A file, or a URL that ``AttachmentChips/add(_:to:directory:)`` ignores
  /// when it is not a file URL.
  case file(URL)

  /// Encoded image data, such as an image from a browser.
  case image(Data)

  /// A URL comes before the image data, so a dropped image file stays a
  /// file.
  public static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation(importing: { (url: URL) in AttachmentDrop.file(url) })
    DataRepresentation(importedContentType: .image) { data in AttachmentDrop.image(data) }
  }
}

extension View {
  /// Adds the files and the images that the user drops on the view or
  /// pastes into it to a list of attachments (plan.md §9 D).
  ///
  /// A dropped file becomes one attachment. A dropped or pasted image goes
  /// to a new temporary file first. ``PromptInputView`` applies this
  /// modifier to the full composer.
  ///
  /// - Parameter attachments: The list to add to.
  /// - Returns: The view that accepts drops and image pastes.
  public func attachmentDropDestination(_ attachments: Binding<[Attachment]>) -> some View {
    modifier(AttachmentDropDestination(attachments: attachments))
  }
}

/// The modifier of ``SwiftUI/View/attachmentDropDestination(_:)``.
private struct AttachmentDropDestination: ViewModifier {
  /// The list to add to.
  @Binding var attachments: [Attachment]

  func body(content: Content) -> some View {
    content
      .dropDestination(for: AttachmentDrop.self) { drops, _ in
        AttachmentChips.add(drops, to: &attachments)
      }
      .onPasteCommand(of: [.image]) { providers in
        Task { await paste(providers) }
      }
  }

  /// Adds the images of pasted items.
  ///
  /// - Parameter providers: The providers of the pasted items.
  private func paste(_ providers: [NSItemProvider]) async {
    for provider in providers {
      guard let data = await Self.imageData(of: provider) else { continue }
      AttachmentChips.add([.image(data)], to: &attachments)
    }
  }

  /// Loads the image data of a pasted item.
  ///
  /// - Parameter provider: The provider of the item.
  /// - Returns: The encoded image, or `nil` when the item has no image.
  private static func imageData(of provider: NSItemProvider) async -> Data? {
    await withCheckedContinuation { continuation in
      _ = provider.loadDataRepresentation(for: .image) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }
}
