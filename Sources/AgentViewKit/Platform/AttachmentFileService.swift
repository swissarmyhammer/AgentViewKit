import AppKit
import Observation
import OSLog
import SwiftUI

/// The service that runs an attachment verb on a file (AVK-11).
///
/// An ``AgentAttachmentCommand`` reads the attachment of its scope and gives
/// it to the service of the scope. By default each attachment scope uses its
/// own ``AttachmentPresenter``, which calls the workspace, the share picker,
/// the save panel and Quick Look of the system. A test gives a recording
/// service with ``SwiftUI/EnvironmentValues/attachmentFileService``, so that
/// no system UI opens.
protocol AttachmentFileService: AnyObject {
  /// Runs `verb` on `attachment`.
  ///
  /// - Parameters:
  ///   - verb: The verb to run.
  ///   - attachment: The attachment of the scope.
  /// - Returns: `true` when the service started the action.
  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool
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
@MainActor @Observable
final class AttachmentPresenter: AttachmentFileService {
  /// The attachment that the file exporter saves, or `nil` when the exporter
  /// is closed.
  var exportedAttachment: Attachment?

  /// The file that the Quick Look panel shows, or `nil` when the panel is
  /// closed.
  var quickLookURL: URL?

  /// The view that the share picker shows at, or `nil` before the scope
  /// mounts.
  @ObservationIgnored weak var anchor: NSView?

  /// The log of the actions that fail.
  @ObservationIgnored private let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentPresenter")

  /// Makes a presenter with no open panel.
  init() {}

  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool {
    switch verb {
    case .openAttachment: return open(attachment)
    case .revealAttachment:
      NSWorkspace.shared.activateFileViewerSelecting([attachment.url])
      return true
    case .shareAttachment: return share(attachment)
    case .saveAttachment:
      exportedAttachment = attachment
      return true
    case .quickLookAttachment:
      quickLookURL = attachment.url
      return true
    }
  }

  /// Opens the file in its default application.
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

  /// Shows the share picker of the system for the file, at the view of the
  /// scope.
  ///
  /// - Parameter attachment: The attachment to share.
  /// - Returns: `true` when the picker opened. `false` when the scope has no
  ///   view in a window.
  private func share(_ attachment: Attachment) -> Bool {
    guard let anchor, anchor.window != nil else {
      logger.error("The share picker has no view for \(attachment.url, privacy: .private).")
      return false
    }
    NSSharingServicePicker(items: [attachment.url])
      .show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    return true
  }
}
