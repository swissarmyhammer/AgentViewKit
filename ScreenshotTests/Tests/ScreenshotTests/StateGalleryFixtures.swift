@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The normal, the selected and the focused state of each view of the kit
/// that has a selection look or a focus look, for the review gallery
/// (^crz4q29, EditorKit `style.md`, "Selection and focus").
///
/// Each image shows one view in three columns, side by side: Normal,
/// Selected and Focused. A caption above each column names the state, and
/// the title of the image names the view. A view with no selection look or
/// no focus look shows a note in that column, which tells why. Each view
/// has a second image for a window that is not key, whose fills are the
/// inactive grey.
///
/// Each column has a command system of its own, so that the same view can
/// show in each column with the same scope path. The settle of each image
/// lands the focus on the scope of the Focused column through its command
/// system, as a `nav.*` move does, so the EditorKit beacon of that scope
/// holds the focus. The capture window is the key window, so the image of a
/// window that is not key sets the active state of the window
/// (`\.appearsActive`) to `false`, as EditorKit's `SelectableItemHostedTests`
/// does. The images are for a person to look at; no test reads their pixels.
@MainActor
enum StateGalleryFixtures {
  /// The state of one column.
  enum State: CaseIterable {
    /// No selection and no focus.
    case normal
    /// The selection, and no focus.
    case selected
    /// The focus, and no selection.
    case focused

    /// The caption above the column.
    var caption: String {
      switch self {
      case .normal: "Normal"
      case .selected: "Selected"
      case .focused: "Focused"
      }
    }
  }

  /// One column of an image: the view in one state, or a note when the view
  /// has no look for the state.
  struct Column {
    /// The state of the column.
    let state: State

    /// The view in the state, or `nil` when the view has no look for it.
    let content: AnyView?

    /// The note that the column shows in place of a view.
    let note: String?

    /// The path of the scope that takes the focus, for the Focused column.
    let focusPath: FocusPath?

    /// A column that shows `content`.
    ///
    /// - Parameters:
    ///   - state: The state of the column.
    ///   - focusPath: The path of the scope that takes the focus, or `nil`.
    ///   - content: The view in the state.
    /// - Returns: The column.
    @MainActor static func view(_ state: State, focus focusPath: FocusPath? = nil, _ content: some View) -> Column {
      Column(state: state, content: AnyView(content), note: nil, focusPath: focusPath)
    }

    /// A column that shows `note` in place of a view.
    ///
    /// - Parameters:
    ///   - state: The state of the column.
    ///   - note: Why the view has no look for the state.
    /// - Returns: The column.
    static func none(_ state: State, _ note: String) -> Column {
      Column(state: state, content: nil, note: note, focusPath: nil)
    }
  }

  /// One view of the gallery.
  struct Subject {
    /// The name of the image, such as `states-message`.
    let name: String

    /// The title of the image: the name of the view.
    let title: String

    /// The height of a column, in points: room for the view at its ideal
    /// height, which the column does not limit.
    let height: CGFloat

    /// The columns of the image, one for each ``State``, in that order.
    let columns: @MainActor (StateGalleryItems) -> [Column]
  }

  /// The note of a column of a view that has no selection.
  static let noSelection = "No selected look: the view has no selection."

  /// The note of a column of a view that has no scope of its own.
  static let noScope = "No focused look: the view has no command scope of its own, so the scope around it shows the focus."

  /// The width of one column, in points.
  static let columnWidth: CGFloat = 340

  /// The height of the title and of the captions above the columns, in
  /// points.
  static let headerHeight: CGFloat = 64

  /// The suffix of the name of the image of a window that is not key.
  static let notKeySuffix = "-not-key"

  /// The section of the page of the images.
  private static let suite = "HostedSnapshotTests"

  /// The views of the gallery.
  static let subjects: [Subject] = [
    Subject(name: "states-message", title: "Message row (UserMessageView)", height: 130) { items in
      [
        .view(.normal, items.message()),
        .none(.selected, noSelection),
        .view(.focused, focus: items.messagePath, items.message()),
      ]
    },
    Subject(name: "states-tool-call", title: "Tool call card (ToolCallView)", height: 90) { items in
      [
        .view(.normal, items.toolCall()),
        .none(.selected, noSelection),
        .view(.focused, focus: items.toolCallPath, items.toolCall()),
      ]
    },
    Subject(name: "states-permission", title: "Permission request card (RequestDeck)", height: 160) { items in
      [
        .view(.normal, items.permission()),
        .none(.selected, noSelection),
        .view(.focused, focus: items.permissionPath, items.permission()),
      ]
    },
    Subject(name: "states-attachment-chip", title: "Attachment chip (AttachmentChip)", height: 60) { items in
      [
        .view(.normal, AttachmentChip(items.chipFile)),
        .none(.selected, noSelection),
        .view(.focused, focus: items.path(of: items.chipFile), AttachmentChip(items.chipFile)),
      ]
    },
    Subject(name: "states-attachment", title: "Attachment (AttachmentView)", height: 60) { items in
      [
        .view(.normal, AttachmentView(items.viewFile)),
        .view(.selected, AttachmentView(items.viewFile).inspectorShows(items.viewFile)),
        .view(.focused, focus: items.path(of: items.viewFile), AttachmentView(items.viewFile)),
      ]
    },
    Subject(name: "states-path-chip", title: "Path chip of a tool call (ToolCallLocationChips)", height: 60) { items in
      [
        .view(.normal, items.locationChips()),
        .view(.selected, items.locationChips().inspectorShows(items.locationFile)),
        .view(.focused, focus: items.path(of: items.locationFile), items.locationChips()),
      ]
    },
    Subject(name: "states-elicitation-tab", title: "Elicitation tab chip (ElicitationTabChip)", height: 60) { items in
      [
        .view(.normal, items.tabChip(isSelected: false)),
        .view(.selected, items.tabChip(isSelected: true)),
        .none(.focused, noScope),
      ]
    },
    Subject(name: "states-diff-chip", title: "Diff file chips (DiffView)", height: 340) { items in
      [
        .none(.normal, "The second chip of the Selected column is a normal chip."),
        .view(.selected, DiffView(patch: StateGalleryItems.twoFilePatch)),
        .none(.focused, noScope),
      ]
    },
    Subject(name: "states-row", title: "List row (AgentRowList)", height: 60) { items in
      [
        .view(.normal, items.rowList(.normal, current: nil)),
        .view(.selected, items.rowList(.selected, current: StateGalleryItems.rowID)),
        .view(.focused, focus: items.rowPath, items.rowList(.focused, current: nil)),
      ]
    },
    Subject(name: "states-bar-control", title: "Bar control (ScrollToBottomPill)", height: 60) { items in
      [
        .view(.normal, items.pill()),
        .none(.selected, noSelection),
        .view(.focused, focus: items.pillPath, items.pill()),
      ]
    },
  ]

  /// Records the image of each view of ``subjects``, in a key window and in
  /// a window that is not key, in each look, in `gallery`.
  ///
  /// - Parameter gallery: The review gallery of the package.
  /// - Throws: The error of a write of a file, of the landing of the focus,
  ///   or of a capture.
  static func record(in gallery: ReviewGallery) async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let items = try StateGalleryItems(in: directory)
    for subject in subjects {
      for appearsActive in [true, false] {
        for appearance in ReviewAppearance.allCases {
          try await record(subject, of: items, appearsActive: appearsActive, in: appearance, to: gallery)
        }
      }
    }
  }

  /// Records the image of `subject` in `appearance`. Each column has a new
  /// command system, so that no focus of an earlier window stays in it.
  ///
  /// - Parameters:
  ///   - subject: The view.
  ///   - items: The models of the views.
  ///   - appearsActive: Whether the window of the views appears active.
  ///   - appearance: The look.
  ///   - gallery: The review gallery of the package.
  /// - Throws: The error of the landing of the focus, or of a capture.
  private static func record(
    _ subject: Subject, of items: StateGalleryItems, appearsActive: Bool, in appearance: ReviewAppearance,
    to gallery: ReviewGallery
  ) async throws {
    let columns = subject.columns(items)
    let systems = columns.map { _ in CommandSystem() }
    let focus = zip(columns, systems).compactMap { column, system in column.focusPath.map { ($0, system) } }
    let name = subject.name + (appearsActive ? "" : notKeySuffix)
    let title = subject.title + (appearsActive ? "" : " — window not key")
    let size = CGSize(
      width: columnWidth * CGFloat(columns.count) + EditorStyle.default.tile.margin * CGFloat(columns.count + 1),
      height: subject.height + headerHeight + EditorStyle.default.tile.margin * 2)
    try await gallery.record(
      suite: suite, named: name, size: size, appearances: [appearance],
      settle: { mount in
        for (path, system) in focus {
          try #require(areBeaconsLive([path], in: system))
          try #require(system.geometry.requestFocus(at: path))
        }
        await RunLoopBlockFence.afterPendingBlocks()
        mount.render()
      },
      content: { _ in
        StateGallery(title: title, columns: Array(zip(columns, systems)))
          .environment(\.appearsActive, appearsActive)
      })
  }
}

/// The models of the views of the gallery, the views in their states, and
/// the path of the scope of each view that takes the focus.
@MainActor
struct StateGalleryItems {
  /// The id of the one row of the list.
  static let rowID = "Inbox"

  /// The scope of the list of the column of `state`.
  ///
  /// A list with no current row shows the selection on the focused row,
  /// and it reads the focused path of the window. Each column has a list
  /// scope of its own, so the focus of the Focused column shows no
  /// selection in the other columns.
  ///
  /// - Parameter state: The state of the column.
  /// - Returns: The scope.
  static func listScope(_ state: StateGalleryFixtures.State) -> AgentRowListScope {
    AgentRowListScope(list: FocusSegment(kind: "stateGalleryList-\(state)"), rowKind: "galleryRow")
  }

  /// A patch that changes two files, so that the diff shows a selected chip
  /// and a normal chip.
  static let twoFilePatch = PreviewFixtures.smallPatch + "\n" + """
    --- a/Sources/Search/SearchQuery.swift
    +++ b/Sources/Search/SearchQuery.swift
    @@ -1,3 +1,3 @@
     struct SearchQuery {
    -  let text: String
    +  let terms: [String]
     }
    """

  /// The line of the location of the path chip.
  static let locationLine = 12

  /// The accessibility identifier of the path chip.
  static let locationIdentifier = "state-gallery-location"

  /// The file of the attachment chip.
  let chipFile: AgentViewKit.Attachment

  /// The file of the attachment view. The type of the file has no preview,
  /// so the view shows the chip.
  let viewFile: AgentViewKit.Attachment

  /// The file of the path chip.
  let locationFile: AgentViewKit.Attachment

  /// The preview session of the message.
  let messageSession: SessionModel

  /// The user message.
  let messageEntry: UserMessageEntry

  /// The preview session of the tool call.
  let toolCallSession: SessionModel

  /// The tool call.
  let toolCallEntry: ToolCallEntry

  /// The preview session of the permission card, which holds one request.
  let permissionSession: SessionModel

  /// The request of the permission card.
  let permissionRequest: PendingPermissionRequest

  /// The preview session of the bar control.
  let barSession: SessionModel

  /// Writes the files of the attachments in `directory`, and opens the
  /// sessions of the message, the tool call, the permission card and the
  /// bar control.
  ///
  /// - Parameter directory: The directory of the files.
  /// - Throws: The error of a write, or an issue when a session holds no
  ///   entry of its kind.
  init(in directory: TemporaryFolder) throws {
    chipFile = try AttachmentFixtures.attachment(named: "notes.bin", in: directory)
    viewFile = try AttachmentFixtures.attachment(named: "report.bin", in: directory)
    locationFile = Attachment(url: directory.url.appending(path: "SearchIndex.swift"))
    messageSession = PreviewFixtures.MessageSample.user.session
    messageEntry = try #require(PreviewFixtures.firstEntry(in: messageSession, as: UserMessageEntry.self))
    toolCallSession = .preview(transcript: [.toolCall(title: "Read Package.swift", kind: .read, status: .completed)])
    toolCallEntry = try #require(PreviewFixtures.firstEntry(in: toolCallSession, as: ToolCallEntry.self))
    permissionSession = SnapshotFixtures.permissionSession
    permissionRequest = try #require(permissionSession.pendingPermissions.first)
    barSession = .previewSample
  }

  // MARK: - Views

  /// The user message, in the scope of its session.
  func message() -> some View {
    UserMessageView(entry: messageEntry).agentCommandScope(session: messageSession)
  }

  /// The tool call card, in the scope of its session.
  func toolCall() -> some View {
    ToolCallView(entry: toolCallEntry).agentCommandScope(session: toolCallSession)
  }

  /// The deck of the permission card, in the scope of its session.
  func permission() -> some View {
    RequestDeck(session: permissionSession).agentCommandScope(session: permissionSession)
  }

  /// The path chip of ``locationFile``.
  func locationChips() -> some View {
    ToolCallLocationChips(locations: [
      ToolCallLocationChips.Location(
        path: locationFile.url.path, line: Self.locationLine, identifier: Self.locationIdentifier)
    ])
  }

  /// The tab chip of the first field of the sample form.
  ///
  /// - Parameter isSelected: Whether the layout shows the field of the tab.
  func tabChip(isSelected: Bool) -> some View {
    let field = PreviewFixtures.fieldContext(PreviewFixtures.ElicitationFields.packageName, answers: .constant([:]))
    return ElicitationTabChip(field: field, isSelected: isSelected) {}
  }

  /// The list of one row, ``rowID``, for the column of `state`.
  ///
  /// - Parameters:
  ///   - state: The state of the column.
  ///   - current: The current row, which shows the selection, or `nil`.
  func rowList(_ state: StateGalleryFixtures.State, current: String?) -> some View {
    AgentRowList([Self.rowID], id: \.self, scope: Self.listScope(state), current: current) { id in
      Text(id)
    }
  }

  /// The scroll-to-bottom pill, a bar control, in the scope of its session.
  func pill() -> some View {
    ScrollToBottomPill(newItemCount: 3) {}.agentCommandScope(session: barSession)
  }

  // MARK: - Paths

  /// The path of the scope of the message.
  var messagePath: FocusPath {
    FocusPath.root(AgentCommandTarget.segment(for: messageSession))
      .appending(AgentScopeKind.message(rowKey: messageEntry.id.rowKey))
  }

  /// The path of the scope of the tool call.
  var toolCallPath: FocusPath {
    FocusPath.root(AgentCommandTarget.segment(for: toolCallSession))
      .appending(AgentScopeKind.toolCall(toolCallEntry.toolCallId.rawValue))
  }

  /// The path of the scope of the permission card.
  var permissionPath: FocusPath {
    AgentCommandTarget.requestPath(in: permissionSession, request: permissionRequest)
  }

  /// The path of the scope of the row of the Focused column.
  var rowPath: FocusPath {
    let scope = Self.listScope(.focused)
    return FocusPath.root(scope.list).appending(scope.rowSegment(for: Self.rowID))
  }

  /// The path of the scope of the bar control.
  var pillPath: FocusPath {
    FocusPath.root(AgentCommandTarget.segment(for: barSession))
      .appending(AgentScopeKind.control(ScrollToBottomPill.identifier))
  }

  /// The path of the scope of a view of `file` with no enclosing scope.
  ///
  /// - Parameter file: The file of the view.
  /// - Returns: The path.
  func path(of file: AgentViewKit.Attachment) -> FocusPath {
    FocusPath.root(AgentScopeKind.attachment(file.id))
  }
}

extension View {
  /// This view with an inspector that shows `file`, so a view of the file
  /// shows its selection.
  ///
  /// - Parameter file: The file that the inspector shows.
  /// - Returns: The view.
  fileprivate func inspectorShows(_ file: AgentViewKit.Attachment) -> some View {
    environment(\.inspectorSelection, InspectorSelection(attachments: [file]))
  }
}

/// One image: the title of the view, then a column for each state, each
/// with its caption above it and its own command system.
private struct StateGallery: View {
  /// The title of the image.
  let title: String

  /// The columns, each with its command system.
  let columns: [(StateGalleryFixtures.Column, CommandSystem)]

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    let margin = editorStyle.tile.margin
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      Text(verbatim: title).font(.headline)
      HStack(alignment: .top, spacing: margin) {
        ForEach(Array(columns.enumerated()), id: \.offset) { _, pair in
          column(pair.0, system: pair.1)
        }
      }
    }
    .padding(margin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// One column: the caption of its state, then its view or its note.
  ///
  /// - Parameters:
  ///   - column: The column.
  ///   - system: The command system of the column.
  /// - Returns: The column view.
  private func column(_ column: StateGalleryFixtures.Column, system: CommandSystem) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.m) {
      Text(verbatim: column.state.caption).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
      Group {
        if let content = column.content {
          content.commandSystem(system).fixedSize(horizontal: false, vertical: true)
        } else if let note = column.note {
          Text(verbatim: note).font(.callout).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .frame(width: StateGalleryFixtures.columnWidth, alignment: .topLeading)
  }
}
