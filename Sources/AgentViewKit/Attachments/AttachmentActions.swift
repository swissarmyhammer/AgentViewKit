import EditorStyle
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The file actions of the inspector and of an artifact (plan.md §3.6):
/// Open, Reveal in Finder, Share, Save, and pop-out Quick Look.
///
/// Each button runs the ``AgentAttachmentVerb`` command of the nearest
/// attachment scope (``SwiftUI/View/agentAttachmentScope(_:)``, AVK-11). Thus
/// a button, the context menu of the attachment and the command palette run
/// the same command. A button is disabled when its verb cannot run on the
/// attachment. With the group ``AgentCommandGroup/attachment`` off, the view
/// shows no button.
struct AttachmentActions: View {
  /// The accessibility identifiers of each action, in display order.
  ///
  /// - Parameter prefix: The start of each identifier.
  /// - Returns: The identifiers.
  static func identifiers(prefix: String) -> [String] {
    AgentAttachmentVerb.allCases.map { $0.identifier(prefix: prefix) }
  }

  /// The file of the actions.
  let attachment: Attachment

  /// The start of the accessibility identifier of each action.
  let identifierPrefix: String

  @Environment(\.agentAttachmentTarget) private var target
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  private let logger = Logger(subsystem: "AgentViewKit", category: "AttachmentActions")

  var body: some View {
    if !groupsOff.contains(.attachment) {
      ControlStack(.horizontal) {
        ForEach(AgentAttachmentVerb.allCases, id: \.self) { verb in
          Button(verb.title, systemImage: verb.icon) { didTap(verb) }
            .help(verb.title)
            .disabled(!verb.availability(for: attachment).isAvailable)
            .accessibilityIdentifier(verb.identifier(prefix: identifierPrefix))
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
    }
  }

  /// Runs the command of `verb` in the scope of the attachment, and writes a
  /// log entry when no command ran.
  ///
  /// - Parameter verb: The verb of the button.
  private func didTap(_ verb: AgentAttachmentVerb) {
    let ran = target?.perform(verb) ?? false
    if !ran {
      logger.error("The command \(verb.id.rawValue) did not run for \(attachment.url, privacy: .private).")
    }
  }
}

nonisolated extension AgentAttachmentVerb {
  /// The accessibility identifier of the button of the verb, such as
  /// `inspector-open`.
  ///
  /// - Parameter prefix: The start of the identifier.
  /// - Returns: The identifier.
  func identifier(prefix: String) -> String {
    "\(prefix)-\(identifierSuffix)"
  }

  /// The end of the accessibility identifier of the button of the verb.
  private var identifierSuffix: String {
    switch self {
    case .openAttachment: "open"
    case .revealAttachment: "reveal"
    case .shareAttachment: "share"
    case .saveAttachment: "save"
    case .quickLookAttachment: "quicklook"
    }
  }
}

/// A document that writes a copy of a file, for the file exporter.
nonisolated struct AttachmentDocument: ExportOnlyDocument {
  /// The exporter does not read documents, so any data type is readable.
  static let readableContentTypes: [UTType] = [.data]

  /// The file to copy.
  let url: URL

  /// Makes a document for a file.
  ///
  /// - Parameter url: The file to copy.
  init(url: URL) {
    self.url = url
  }

  /// Reads the file into a file wrapper for the write.
  ///
  /// - Parameter configuration: The write configuration.
  /// - Returns: A file wrapper with the contents of the file.
  /// - Throws: The error of the read.
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    try FileWrapper(url: url, options: .immediate)
  }
}

// MARK: - Previews

/// The actions of one file of the previews, in the attachment scope of the
/// file.
///
/// The scope runs each press through the recording service of the previews,
/// so that a press in the canvas opens no application, no Finder window and
/// no panel.
private struct AttachmentActionsPreview: View {
  /// The file of the actions.
  let attachment: Attachment

  /// The start of the accessibility identifier of each action.
  let identifierPrefix: String

  var body: some View {
    AttachmentActions(attachment: attachment, identifierPrefix: identifierPrefix)
      .agentAttachmentScope(attachment)
      .environment(\.attachmentFileService, PreviewFixtures.attachmentFileService)
      .padding()
  }
}

#Preview("A local file: each action is available") {
  AttachmentActionsPreview(attachment: PreviewFixtures.localFileAttachment, identifierPrefix: "preview-local")
}

#Preview("A web page: only Open and Share are available") {
  AttachmentActionsPreview(attachment: PreviewFixtures.webAttachment, identifierPrefix: "preview-web")
}

#Preview("A missing file: no action is available") {
  AttachmentActionsPreview(attachment: PreviewFixtures.sourceFileAttachment, identifierPrefix: "preview-missing")
}
