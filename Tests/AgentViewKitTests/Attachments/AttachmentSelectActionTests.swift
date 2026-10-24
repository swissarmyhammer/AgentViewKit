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
  /// - Parameter selection: The value of the binding of the host.
  /// - Returns: The action, with ``threadSessionID`` as the session of the
  ///   thread view.
  static func hostAction(holding selection: AgentAttachmentSelection?) -> AttachmentSelectAction {
    let target = HostAttachmentTarget(selection: .constant(selection), sessionId: threadSessionID)
    return AttachmentSelectAction(hostTarget: target, selection: nil)
  }

  @Test func aFileThatTheInspectorSelectionShowsIsSelected() {
    let action = AttachmentSelectAction(
      hostTarget: nil, selection: InspectorSelection(attachment: Attachment(url: Self.shownURL)))

    #expect(action.isSelected(Self.shownFileWithOtherFields))
  }

  @Test func aFileThatTheInspectorSelectionDoesNotShowIsNotSelected() {
    let action = AttachmentSelectAction(
      hostTarget: nil, selection: InspectorSelection(attachment: Attachment(url: Self.shownURL)))

    #expect(!action.isSelected(Attachment(url: Self.otherURL)))
  }

  @Test func noFileIsSelectedWhileTheInspectorIsClosed() {
    let action = AttachmentSelectAction(hostTarget: nil, selection: InspectorSelection())

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  @Test func noFileIsSelectedWithNoInspector() {
    let action = AttachmentSelectAction(hostTarget: nil, selection: nil)

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  @Test func aFileThatTheHostInspectorShowsForTheThreadIsSelected() {
    let action = Self.hostAction(
      holding: AgentAttachmentSelection(attachment: Attachment(url: Self.shownURL), sessionId: Self.threadSessionID))

    #expect(action.isSelected(Self.shownFileWithOtherFields))
  }

  /// One host binding serves more than one thread view. A file that the
  /// user selected in another thread is not the selection of this thread.
  @Test func aFileThatTheHostInspectorShowsForAnotherThreadIsNotSelected() {
    let action = Self.hostAction(
      holding: AgentAttachmentSelection(attachment: Attachment(url: Self.shownURL), sessionId: Self.otherSessionID))

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }

  /// In the host mode, the binding of the host is the inspector: the
  /// inspector selection of the environment does not count.
  @Test func theHostTargetDecidesTheSelectionInTheHostMode() {
    let target = HostAttachmentTarget(selection: .constant(nil), sessionId: Self.threadSessionID)
    let action = AttachmentSelectAction(
      hostTarget: target, selection: InspectorSelection(attachment: Attachment(url: Self.shownURL)))

    #expect(!action.isSelected(Attachment(url: Self.shownURL)))
  }
}
