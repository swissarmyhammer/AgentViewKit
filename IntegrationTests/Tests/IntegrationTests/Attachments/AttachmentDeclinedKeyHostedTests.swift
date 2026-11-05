import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The keys of the attachment commands, and what a command that cannot run
/// does to a key (EditorKit ^jaxzzkn, AVK ^zb5td6w).
///
/// The decisions for ``AgentAttachmentCommand``:
///
/// - A run that reaches the service holds the key, also when the service
///   cannot start the action (the workspace does not open the file, or the
///   share picker has no view). The user aimed the key at that attachment,
///   so it does not go on to another command of the chord.
/// - Where the command cannot run (no service, no attachment, or a file that
///   is gone), its availability is unavailable, so the key goes on to the
///   next binding of the chord.
///
/// Each test shows the bare scope of an attachment in the scope of a host,
/// binds Return to Open at the attachment, and binds Return to a recording
/// command of the host at the scope around it. It drives Return through
/// `CommandRegistry.performKey(_:mode:at:payload:)`, the key path of the
/// registry.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentDeclinedKeyHostedTests {
  /// The segment of the scope of the host around the attachment.
  static let hostSegment = FocusSegment(kind: "attachmentHost")

  /// The size of the window.
  static let size = CGSize(width: 300, height: 200)

  /// One window: the scope of an attachment in the scope of a host, with
  /// Return bound at both.
  struct Bed {
    /// The harness that shows the window.
    let harness: HostedViewHarness<AnyView>

    /// The command system of the window.
    let system: CommandSystem

    /// The path of the scope of the attachment.
    let path: FocusPath

    /// The runs of the recording command of the host.
    let fallbacks: CommandRunLog
  }

  /// Mounts the scope of `attachment` with `service`, and binds Return to
  /// Open at the attachment and to the recording command of the host around
  /// it.
  ///
  /// - Parameters:
  ///   - attachment: The attachment of the scope.
  ///   - service: The service that runs the commands.
  /// - Returns: The bed.
  static func mount(
    _ attachment: AgentViewKit.Attachment, service: RecordingAttachmentFileService
  ) -> Bed {
    let system = CommandSystem()
    let harness = HostedViewHarness(
      AnyView(
        Color.clear.agentAttachmentScope(attachment)
          .environment(\.attachmentFileService, service)
          .commandScope(segment: hostSegment)
          .commandSystem(system)),
      size: size)
    harness.render()
    let path = FocusPath.root(hostSegment).appending(AgentScopeKind.attachment(attachment.id))
    let fallbacks = FallbackKeyBinding.bind(
      KeyChord.return, to: AgentAttachmentVerb.openAttachment.id, at: path, fallbackAt: .root(hostSegment),
      in: system)
    return Bed(harness: harness, system: system, path: path, fallbacks: fallbacks)
  }

  @Test func returnThatTheServiceCannotOpenStaysWithTheAttachment() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let service = RecordingAttachmentFileService(startsAction: false)
    let bed = Self.mount(attachment, service: service)
    defer { bed.harness.close() }

    #expect(bed.system.registry.performKey(KeyChord.return.asSequence, mode: .cua, at: bed.path))

    #expect(service.calls == [.init(verb: .openAttachment, attachment: attachment)])
    #expect(bed.fallbacks.runs.isEmpty)
  }

  @Test func returnOnAnAttachmentWhoseFileIsGoneRunsTheNextBindingOfTheChord() throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    directory.remove()
    let service = RecordingAttachmentFileService()
    let bed = Self.mount(attachment, service: service)
    defer { bed.harness.close() }

    #expect(bed.system.registry.performKey(KeyChord.return.asSequence, mode: .cua, at: bed.path))

    #expect(service.calls.isEmpty)
    #expect(bed.fallbacks.runs.map(\.id) == [FallbackKeyBinding.fallbackID])
  }
}
