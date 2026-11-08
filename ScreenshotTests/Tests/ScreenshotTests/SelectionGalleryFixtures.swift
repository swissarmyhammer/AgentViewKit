@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The selection and the focus of the items of the kit, for the review
/// gallery (^r3sm8nh, EditorKit `style.md`, "Selection and focus").
///
/// Each image shows the same items: an ``AgentRowList`` whose current row
/// is selected, a focused ``AttachmentChip``, an ``AttachmentView`` chip that
/// the inspector shows, a user message, and the permission card of a
/// ``RequestDeck``. A selected item shows the soft accent fill, a focused
/// item with a surface shows the stronger accent fill and no ring, and a
/// focused message, which has no surface, shows the focus ring of its scope.
/// The permission card, a card that takes the keyboard focus itself, shows
/// the same fill and no ring. In a window that is not key, the fills are the
/// inactive grey.
///
/// A window holds one focus, so each image lands the focus on one item. The
/// settle of each image lands it through the command system of the window,
/// as a `nav.*` move does. The capture window is the key window, so the
/// images set the active state of the window (`\.appearsActive`) for each
/// image, as EditorKit's `SelectableItemHostedTests` does: the image of a
/// window that is not key sets it to `false`. The images are for a person to
/// look at; no test reads their pixels.
@MainActor
enum SelectionGalleryFixtures {
  /// The item that holds the focus of the window in an image.
  enum FocusTarget {
    /// The focused row of the list, ``focusedRowID``.
    case row
    /// The ``AttachmentChip``.
    case chip
    /// The user message.
    case message
    /// The permission card of the deck.
    case permission
  }

  /// One image of the gallery.
  struct Shot {
    /// The name of the image, such as `item-focus-row`.
    let name: String
    /// The item that holds the focus.
    let focus: FocusTarget
    /// Whether the window of the items appears active.
    let appearsActive: Bool
  }

  /// The images of the gallery: the focus on each item in a key window, and
  /// the focus on a row in a window that is not key.
  static let shots = [
    Shot(name: "item-focus-row", focus: .row, appearsActive: true),
    Shot(name: "item-focus-chip", focus: .chip, appearsActive: true),
    Shot(name: "item-focus-message", focus: .message, appearsActive: true),
    Shot(name: "item-focus-permission", focus: .permission, appearsActive: true),
    Shot(name: "item-focus-row-not-key", focus: .row, appearsActive: false),
  ]

  /// The ids of the rows of the list, in list order. Each row shows its id.
  static let rowIDs = ["Drafts", "Inbox", "Archive"]

  /// The id of the row that the focus lands on in a row image.
  static let focusedRowID = rowIDs[0]

  /// The id of the current row of the list, which shows the selection.
  static let currentRowID = rowIDs[1]

  /// The scope of the list.
  static let listScope = AgentRowListScope(list: FocusSegment(kind: "selectionGalleryList"), rowKind: "galleryRow")

  /// The name of the file of the focused chip.
  static let chipFileName = "notes.bin"

  /// The name of the file of the selected attachment view. The type of the
  /// file has no preview, so the view shows the chip.
  static let selectedFileName = "report.bin"

  /// The height of the list, in points: the three rows with room below them.
  static let listHeight: CGFloat = 140

  /// The height of the image, in points: the list, the chips, the message
  /// and the permission card.
  static let height: CGFloat = 460

  /// The size of the image: the narrow width of a card.
  static let size = CGSize(width: SnapshotFixtures.narrowWidth, height: height)

  /// The section of the page of the images.
  private static let suite = "HostedSnapshotTests"

  /// Records each image of ``shots`` in each look in `gallery`.
  ///
  /// - Parameter gallery: The review gallery of the package.
  /// - Throws: The error of a write of a file, of the landing of the focus,
  ///   or of a capture.
  static func record(in gallery: ReviewGallery) async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let items = try SelectionGalleryItems(in: directory)
    for shot in shots {
      for appearance in ReviewAppearance.allCases {
        try await record(shot, of: items, in: appearance, to: gallery)
      }
    }
  }

  /// Records the image of `shot` in `appearance`, with a command system of
  /// its own, so that no focus of an earlier window stays in it.
  ///
  /// - Parameters:
  ///   - shot: The image.
  ///   - items: The items of the image.
  ///   - appearance: The look.
  ///   - gallery: The review gallery of the package.
  /// - Throws: The error of the landing of the focus, or of a capture.
  private static func record(
    _ shot: Shot, of items: SelectionGalleryItems, in appearance: ReviewAppearance, to gallery: ReviewGallery
  ) async throws {
    let system = CommandSystem()
    let path = items.path(of: shot.focus)
    try await gallery.record(
      suite: suite, named: shot.name, size: size, appearances: [appearance],
      settle: { mount in
        try #require(areBeaconsLive([path], in: system))
        try #require(system.geometry.requestFocus(at: path))
        await RunLoopBlockFence.afterPendingBlocks()
        mount.render()
      },
      content: { _ in
        SelectionGallery(items: items)
          .environment(\.appearsActive, shot.appearsActive)
          .commandSystem(system)
      })
  }
}

/// The models of the items of the gallery, and the path of the scope of
/// each item that takes the focus.
@MainActor
struct SelectionGalleryItems {
  /// The file of the focused chip.
  let chipFile: AgentViewKit.Attachment

  /// The file that the inspector shows.
  let selectedFile: AgentViewKit.Attachment

  /// The preview session of the message.
  let session: SessionModel

  /// The user message.
  let message: UserMessageEntry

  /// The preview session of the permission card, which holds one request.
  let permissionSession: SessionModel

  /// The request of the permission card.
  let permission: PendingPermissionRequest

  /// Writes the files of the chips in `directory`, and opens the sessions of
  /// the message and of the permission card.
  ///
  /// - Parameter directory: The directory of the files.
  /// - Throws: The error of a write, or an issue when the session holds no
  ///   user message or the permission session holds no request.
  init(in directory: TemporaryFolder) throws {
    chipFile = try AttachmentFixtures.attachment(named: SelectionGalleryFixtures.chipFileName, in: directory)
    selectedFile = try AttachmentFixtures.attachment(
      named: SelectionGalleryFixtures.selectedFileName, in: directory)
    session = PreviewFixtures.MessageSample.user.session
    message = try #require(PreviewFixtures.firstEntry(in: session, as: UserMessageEntry.self))
    permissionSession = SnapshotFixtures.permissionSession
    permission = try #require(permissionSession.pendingPermissions.first)
  }

  /// The path of the scope of `target`.
  ///
  /// - Parameter target: The item that takes the focus.
  /// - Returns: The path.
  func path(of target: SelectionGalleryFixtures.FocusTarget) -> FocusPath {
    switch target {
    case .row:
      let scope = SelectionGalleryFixtures.listScope
      return FocusPath.root(scope.list).appending(scope.rowSegment(for: SelectionGalleryFixtures.focusedRowID))
    case .chip:
      return FocusPath.root(AgentScopeKind.attachment(chipFile.id))
    case .message:
      return FocusPath.root(AgentCommandTarget.segment(for: session))
        .appending(AgentScopeKind.message(rowKey: message.id.rowKey))
    case .permission:
      return FocusPath.root(AgentCommandTarget.segment(for: permissionSession))
        .appending(AgentScopeKind.request(permission.id))
    }
  }
}

/// The items of one image: the list, the two chips side by side, the
/// message and the deck of the permission card, with the space between two
/// blocks of the tile.
private struct SelectionGallery: View {
  /// The models of the items.
  let items: SelectionGalleryItems

  var body: some View {
    VStack(alignment: .leading, spacing: EditorStyle.default.tile.margin) {
      AgentRowList(
        SelectionGalleryFixtures.rowIDs, id: \.self, scope: SelectionGalleryFixtures.listScope,
        current: SelectionGalleryFixtures.currentRowID
      ) { id in
        Text(id)
      }
      .frame(height: SelectionGalleryFixtures.listHeight)
      HStack(spacing: EditorStyle.default.tile.margin) {
        AttachmentChip(items.chipFile)
        AttachmentView(items.selectedFile)
          .environment(\.inspectorSelection, InspectorSelection(attachments: [items.selectedFile]))
      }
      UserMessageView(entry: items.message)
        .agentCommandScope(session: items.session)
      RequestDeck(session: items.permissionSession)
        .agentCommandScope(session: items.permissionSession)
    }
    .padding(EditorStyle.default.tile.margin)
  }
}
