import AppKit
import Observation
import OSLog
import SwiftUI

/// The service that runs an attachment verb on files (AVK-11).
///
/// An ``AgentAttachmentCommand`` reads its files, the attachment of its
/// scope or every selected file (card ^zsr2pbf), and gives them to the
/// service of the scope with the run on several files. By default each
/// attachment scope uses its own ``AttachmentPresenter``, which calls the
/// workspace, the share picker, the save panel and Quick Look of the
/// system. A test gives a recording service with
/// ``SwiftUI/EnvironmentValues/attachmentFileService``, so that no system UI
/// opens.
protocol AttachmentFileService: AnyObject {
  /// Runs `verb` on one file: the action on a single file.
  ///
  /// - Parameters:
  ///   - verb: The verb to run.
  ///   - attachment: The file.
  /// - Returns: `true` when the service started the action.
  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool

  /// Runs `verb` on each of `attachments`, in order. The default runs the
  /// action on a single file for each file.
  ///
  /// - Parameters:
  ///   - verb: The verb to run.
  ///   - attachments: The files of the command, in order.
  /// - Returns: `true` when the service started the action on each file.
  func run(_ verb: AgentAttachmentVerb, on attachments: [Attachment]) -> Bool
}

extension AttachmentFileService {
  func run(_ verb: AgentAttachmentVerb, on attachments: [Attachment]) -> Bool {
    attachments.map { run(verb, on: $0) }.allSatisfy(\.self)
  }
}

extension EnvironmentValues {
  /// The service that the attachment scopes in this view give to their
  /// commands, or `nil` for the ``AttachmentPresenter`` of each scope.
  @Entry var attachmentFileService: (any AttachmentFileService)? = nil
}

/// The system service of one attachment scope.
///
/// Open and Reveal in Finder call `NSWorkspace`. Share shows the share
/// picker of the system at ``anchor``, the view of the scope. Save and Quick
/// Look write the state that the scope gives to `fileExporter` and to
/// `quickLookPreview`, as the buttons of the inspector did before AVK-11.
///
/// A run on several files (card ^zsr2pbf) opens each file, reveals all of
/// them in one Finder window, shares all of them with one picker, saves
/// each one in a save panel of its own, one after the other, and shows them
/// in one Quick Look panel, from the first file.
@MainActor @Observable
final class AttachmentPresenter: AttachmentFileService {
  /// The attachment that the file exporter saves, or `nil` when the exporter
  /// is closed.
  var exportedAttachment: Attachment?

  /// The file that the Quick Look panel shows, or `nil` when the panel is
  /// closed.
  var quickLookURL: URL?

  /// The files that the Quick Look panel browses, in order.
  var quickLookURLs: [URL] = []

  /// The files of a save that the file exporter saves after
  /// ``exportedAttachment``, in order.
  @ObservationIgnored private var pendingExports: [Attachment] = []

  /// The view that the share picker shows at, or `nil` before the scope
  /// mounts.
  @ObservationIgnored weak var anchor: NSView?

  /// The log of the actions that fail.
  @ObservationIgnored private let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentPresenter")

  /// Makes a presenter with no open panel.
  init() {}

  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool {
    run(verb, on: [attachment])
  }

  func run(_ verb: AgentAttachmentVerb, on attachments: [Attachment]) -> Bool {
    guard let first = attachments.first else { return false }
    switch verb {
    case .openAttachment:
      return attachments.map(open).allSatisfy(\.self)
    case .revealAttachment:
      NSWorkspace.shared.activateFileViewerSelecting(attachments.map(\.url))
      return true
    case .shareAttachment:
      return share(attachments)
    case .saveAttachment:
      exportedAttachment = first
      pendingExports = Array(attachments.dropFirst())
      return true
    case .quickLookAttachment:
      quickLookURLs = attachments.map(\.url)
      quickLookURL = first.url
      return true
    }
  }

  /// Ends the save of the shown file: the file exporter closed.
  func exportDidClose() {
    exportedAttachment = nil
  }

  /// Gives the file exporter the next file of the save, if any, after the
  /// panel of the last file closed. The scope calls it in the update after
  /// the close, so the exporter shows a new panel.
  func exportNextFile() {
    guard exportedAttachment == nil, !pendingExports.isEmpty else { return }
    exportedAttachment = pendingExports.removeFirst()
  }

  /// Opens the file in its default application: the action on a single
  /// file.
  ///
  /// - Parameter attachment: The attachment to open.
  /// - Returns: `true` when the workspace opened the file.
  private func open(_ attachment: Attachment) -> Bool {
    guard NSWorkspace.shared.open(attachment.url) else {
      logger.error("The workspace did not open \(attachment.url, privacy: .private).")
      return false
    }
    return true
  }

  /// Shows the share picker of the system for the files, at the view of the
  /// scope.
  ///
  /// - Parameter attachments: The attachments to share, in order.
  /// - Returns: `true` when the picker opened. `false` when the scope has no
  ///   view in a window.
  private func share(_ attachments: [Attachment]) -> Bool {
    let urls = attachments.map(\.url)
    guard let anchor, anchor.window != nil else {
      logger.error("The share picker has no view for \(urls, privacy: .private).")
      return false
    }
    NSSharingServicePicker(items: urls)
      .show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    return true
  }
}
