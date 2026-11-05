import Foundation
import FoundationModelsACP
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

/// Tests for the read of the file that the inspector shows
/// (``AttachmentSelectAction/isSelected(_:)``, card ^dn1m56r).
///
/// A file view shows the selected state when the inspector of its
/// environment shows its file. The read compares the URL of the file, so two
/// attachments of one file with other ids or other sizes are the same file.
@Suite @MainActor struct AttachmentSelectActionTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The URL of the file that the inspector shows.
  static let shownURL = URL(filePath: "/tmp/avk-select/shown.txt")

  /// The URL of a file that the inspector does not show.
  static let otherURL = URL(filePath: "/tmp/avk-select/other.txt")

  /// The session id of the thread view of the host target.
  static let threadSessionID = SessionId(rawValue: "thread-a")

  /// The session id of another thread view that shares the host binding.
  static let otherSessionID = SessionId(rawValue: "thread-b")

  /// An attachment of ``shownURL`` with an id and a size of its own, as the
  /// block file of an image has.
  static var shownFileWithOtherFields: Attachment {
    Attachment(id: AttachmentID("block-file"), url: shownURL, type: .plainText, name: "shown.txt", size: 1)
  }

  /// The action of a host target whose binding holds `selection`.
  ///
  /// - Parameter selection: The value of the binding of the host, in
  ///   selection order.
  /// - Returns: The action, with ``threadSessionID`` as the session of the
  ///   thread view.
  static func hostAction(holding selection: [AgentAttachmentSelection]) -> AttachmentSelectAction {
    let target = HostAttachmentTarget(
      selection: .constant(selection), sessionId: threadSessionID, anchor: AttachmentSelectionAnchor())
    return AttachmentSelectAction(hostTarget: target, selection: nil, order: nil)
  }

  @Test func aFileThatTheInspectorSelectionShowsIsSelected() {
    let action = AttachmentSelectAction(
      hostTarget: nil, selection: InspectorSelection(attachments: [Attachment(url: Self.shownURL)]), order: nil)

    #expect(action.isSelected(Self.shownFileWithOtherFields))
  }

  @Test func aFileThatTheInspectorSelectionDoesNotShowIsNotSelected() {
    let action = AttachmentSelectAction(
      hostTarget: nil, selection: InspectorSelection(attachments: [Attachment(url: Self.shownURL)]), order: nil)

    #expect(!action.isSelected(Attachment(url: Self.otherURL)))
  }

  @Test func noFileIsSelectedWhileTheInspectorIsClosed() {
    let action = AttachmentSelectAction(hostTarget: nil, selection: InspectorSelection(), order: nil)

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  @Test func noFileIsSelectedWithNoInspector() {
    let action = AttachmentSelectAction(hostTarget: nil, selection: nil, order: nil)

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  @Test func aFileThatTheHostInspectorShowsForTheThreadIsSelected() {
    let action = Self.hostAction(
      holding: [AgentAttachmentSelection(attachment: Attachment(url: Self.shownURL), sessionId: Self.threadSessionID)])

    #expect(action.isSelected(Self.shownFileWithOtherFields))
  }

  /// One host binding serves more than one thread view. A file that the
  /// user selected in another thread is not the selection of this thread.
  @Test func aFileThatTheHostInspectorShowsForAnotherThreadIsNotSelected() {
    let action = Self.hostAction(
      holding: [AgentAttachmentSelection(attachment: Attachment(url: Self.shownURL), sessionId: Self.otherSessionID)])

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  /// In the host mode, the binding of the host is the inspector: the
  /// inspector selection of the environment does not count.
  @Test func theHostTargetDecidesTheSelectionInTheHostMode() {
    let target = HostAttachmentTarget(
      selection: .constant([]), sessionId: Self.threadSessionID, anchor: AttachmentSelectionAnchor())
    let action = AttachmentSelectAction(
      hostTarget: target, selection: InspectorSelection(attachments: [Attachment(url: Self.shownURL)]), order: nil)

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  /// A file that the host binding holds for the thread after other files is
  /// selected: the binding holds a list.
  @Test func aFileLaterInTheHostSelectionIsSelected() {
    let action = Self.hostAction(holding: [
      AgentAttachmentSelection(attachment: Attachment(url: Self.otherURL), sessionId: Self.threadSessionID),
      AgentAttachmentSelection(attachment: Attachment(url: Self.shownURL), sessionId: Self.threadSessionID),
    ])

    #expect(action.isSelected(Attachment(url: Self.shownURL)))
  }
}

/// Tests for the changes that the action makes to the binding of a host
/// (``HostAttachmentTarget``, card ^4138tmp).
///
/// One binding serves each thread view of the window. A select replaces the
/// whole list, and a toggle or an extend changes only the files of the thread
/// and keeps the files of the other threads where they are.
@Suite @MainActor struct HostAttachmentTargetTests {
  /// The attachment of the kit. FoundationModelsACP has a type of the same
  /// name.
  typealias Attachment = AgentViewKit.Attachment

  /// The value of a host binding, as a host keeps it.
  @MainActor final class HostState {
    /// The selections of the host, in selection order.
    var selection: [AgentAttachmentSelection] = []
  }

  /// Four files of the thread, in transcript order.
  static let files = (0..<4).map { Attachment(url: URL(filePath: "/tmp/avk-host/file-\($0).txt")) }

  /// The session id of the thread view of the target.
  static let threadSessionID = AttachmentSelectActionTests.threadSessionID

  /// The session id of another thread view that shares the binding.
  static let otherSessionID = AttachmentSelectActionTests.otherSessionID

  /// The selection of a file of another thread.
  static let otherThreadFile = AgentAttachmentSelection(
    attachment: Attachment(url: URL(filePath: "/tmp/avk-host/other.txt")), sessionId: otherSessionID)

  /// The state of the host.
  let state = HostState()

  /// The target of the thread view, on the binding of ``state``.
  let target: HostAttachmentTarget

  init() {
    let state = state
    target = HostAttachmentTarget(
      selection: Binding(get: { state.selection }, set: { state.selection = $0 }),
      sessionId: Self.threadSessionID, anchor: AttachmentSelectionAnchor())
  }

  /// The selections of the files of the thread at `indices` of ``files``.
  ///
  /// - Parameter indices: The positions in ``files``.
  /// - Returns: The selections.
  static func selections(_ indices: Int...) -> [AgentAttachmentSelection] {
    indices.map { AgentAttachmentSelection(attachment: files[$0], sessionId: threadSessionID) }
  }

  /// Applies `change` to the file at `index` of ``files``, with ``files`` as
  /// the transcript order.
  ///
  /// - Parameters:
  ///   - change: The change.
  ///   - index: The position of the file.
  func apply(_ change: AttachmentSelectionChange, _ index: Int) {
    target.apply(change, to: Self.files[index]) { Self.files }
  }

  @Test func aSelectReplacesTheFilesOfEachThread() {
    state.selection = [Self.otherThreadFile]

    apply(.select, 1)

    #expect(state.selection == Self.selections(1))
  }

  @Test func aToggleAddsTheFileAndKeepsTheOtherThreads() {
    state.selection = [Self.otherThreadFile]

    apply(.toggle, 2)

    #expect(state.selection == [Self.otherThreadFile] + Self.selections(2))
  }

  @Test func aToggleOfASelectedFileTakesItOut() {
    apply(.select, 1)
    apply(.toggle, 2)

    apply(.toggle, 1)

    #expect(state.selection == Self.selections(2))
  }

  @Test func anExtendAddsTheRangeInTranscriptOrder() {
    apply(.select, 0)

    apply(.extend, 3)

    #expect(state.selection == Self.selections(0, 1, 2, 3))
  }

  /// The binding of the host holds no anchor, so the target keeps the
  /// anchor of its thread: a second extend reaches from that anchor, and not
  /// from the last file of the list.
  @Test func anExtendReachesFromTheAnchorOfTheThread() {
    apply(.select, 1)
    apply(.extend, 2)

    apply(.extend, 0)

    #expect(state.selection == Self.selections(1, 2, 0))
  }
}
