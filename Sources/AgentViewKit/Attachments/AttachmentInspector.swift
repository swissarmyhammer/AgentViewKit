import EditorInspector
import EditorSwiftUI
import Observation
import SwiftUI

/// The attachments that the trailing inspector shows (plan.md §3.6), in
/// selection order (card ^4138tmp).
///
/// A press on an ``AttachmentView`` changes the selection with the selection
/// model of EditorKit's lists: a click selects only its attachment
/// (``select(_:)``), a Command-click adds it or takes it out
/// (``toggle(_:)``), and a Shift-click adds each attachment from the anchor
/// to it, in transcript order (``extend(to:in:)``). The anchor is the
/// attachment of the last select or toggle. The inspector is open while the
/// selection holds an attachment, and it shows one block for each selected
/// attachment (``AttachmentInspector``).
@MainActor @Observable
public final class InspectorSelection {
  /// The selection, with its anchor.
  private var list: AttachmentSelectionList

  /// The selected attachments, in selection order. The inspector is closed
  /// while the list is empty.
  public var attachments: [Attachment] { list.files }

  /// Makes a selection, anchored at its last attachment.
  ///
  /// - Parameter attachments: The first selected attachments, in selection
  ///   order.
  public init(attachments: [Attachment] = []) {
    list = AttachmentSelectionList(files: attachments)
  }

  /// Selects only an attachment, and so opens the inspector.
  ///
  /// - Parameter attachment: The attachment to show.
  public func select(_ attachment: Attachment) {
    apply(.select, to: attachment) { [] }
  }

  /// Adds an attachment to the end of the selection, or takes it out when
  /// the selection holds it, as a Command-click does.
  ///
  /// - Parameter attachment: The attachment.
  public func toggle(_ attachment: Attachment) {
    apply(.toggle, to: attachment) { [] }
  }

  /// Adds each attachment of `order` from the anchor to `attachment` that
  /// the selection does not hold yet, in the order of `order`, as a
  /// Shift-click does. With no anchor, or when `order` does not hold the
  /// anchor or `attachment`, the extend adds only `attachment`.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that the range reaches to.
  ///   - order: The attachments that the range reads, in transcript order.
  public func extend(to attachment: Attachment, in order: [Attachment]) {
    apply(.extend, to: attachment) { order }
  }

  /// Removes the selection, and so closes the inspector.
  public func clear() {
    list = AttachmentSelectionList()
  }

  /// Applies one change of the selection model.
  ///
  /// - Parameters:
  ///   - change: The kind of the change.
  ///   - attachment: The attachment of the press.
  ///   - order: The attachments of the thread in transcript order.
  func apply(_ change: AttachmentSelectionChange, to attachment: Attachment, order: () -> [Attachment]) {
    list.apply(change, to: attachment, order: order)
  }
}

extension EnvironmentValues {
  /// The selection that a press on an attachment changes, or `nil` when no
  /// inspector shows attachments.
  @Entry public var inspectorSelection: InspectorSelection?
}

extension View {
  /// Shows the selected attachments in a trailing inspector, one block for
  /// each attachment.
  ///
  /// The modifier gives `selection` to the environment of this view, so that
  /// a press on an ``AttachmentView`` in this view opens the inspector. It
  /// gives a ``TranscriptFileOrder`` to the views in it too, unless the
  /// environment has one, so that a Shift-click extends the selection over
  /// the files in this view.
  /// ``AgentThreadView`` applies this modifier in the
  /// ``AttachmentInspectorMode/builtIn`` mode, the default. A window that has
  /// its own inspector gives the ``AttachmentInspectorMode/host(_:)`` mode
  /// with ``SwiftUI/View/agentAttachmentInspector(_:)``. Then the thread
  /// views apply no inspector, and the window shows the selected file in its
  /// own inspector.
  ///
  /// - Parameter selection: The selection to show.
  /// - Returns: A view with the inspector.
  public func attachmentInspector(selection: InspectorSelection) -> some View {
    modifier(AttachmentInspectorModifier(selection: selection))
  }
}

/// Binds a trailing inspector to an ``InspectorSelection``.
///
/// The `inspector(isPresented:content:)` of SwiftUI does not give the main
/// content the top and bottom safe area that a bar of the host around the
/// modified view adds, such as a `.safeAreaBar(edge: .top)` (^786dxt8). The
/// modifier measures the safe area around the inspector and the safe area in
/// it, and adds the difference to the main content as safe area padding. So
/// the content is laid out below the bar of the host, and a list scrolls under
/// that bar with a content inset that counts it.
private struct AttachmentInspectorModifier: ViewModifier {
  /// The selection to show.
  let selection: InspectorSelection

  /// The transcript order of the environment, which a thread view gives.
  @Environment(\.transcriptFileOrder) private var ambientOrder

  /// The transcript order of the files in this view when the environment
  /// has none.
  @State private var ownOrder = TranscriptFileOrder()

  /// The top and bottom safe area insets around the inspector.
  @State private var outerInsets = VerticalInsets()

  /// The top and bottom safe area insets that the inspector gives its main
  /// content, before the padding of the modifier.
  @State private var innerInsets = VerticalInsets()

  func body(content: Content) -> some View {
    // The body reads the attachments itself, so that a new selection
    // evaluates the body again. A read in a binding closure is not tracked.
    let attachments = selection.attachments
    let missing = outerInsets.excess(over: innerInsets)
    content
      .environment(\.inspectorSelection, selection)
      .environment(\.transcriptFileOrder, ambientOrder ?? ownOrder)
      .safeAreaPadding(.top, missing.top)
      .safeAreaPadding(.bottom, missing.bottom)
      // The padded view reads the safe area of its parent, so the padding of
      // the modifier is not in `innerInsets`.
      .onGeometryChange(for: VerticalInsets.self, of: VerticalInsets.init(safeAreaOf:)) {
        innerInsets = $0
      }
      .inspector(isPresented: isPresented(for: attachments)) {
        if !attachments.isEmpty {
          AttachmentInspector(attachments)
        }
      }
      .onGeometryChange(for: VerticalInsets.self, of: VerticalInsets.init(safeAreaOf:)) {
        outerInsets = $0
      }
  }

  /// A binding that is `true` while the selection holds an attachment. A
  /// write of `false` clears the selection.
  ///
  /// - Parameter attachments: The selected attachments that the body read.
  /// - Returns: The binding.
  private func isPresented(for attachments: [Attachment]) -> Binding<Bool> {
    Binding(
      get: { !attachments.isEmpty },
      set: { isPresented in
        if !isPresented {
          selection.clear()
        }
      }
    )
  }
}

/// The top and bottom safe area insets of a view, in points.
private nonisolated struct VerticalInsets: Equatable, Sendable {
  /// The top inset.
  var top: CGFloat = 0

  /// The bottom inset.
  var bottom: CGFloat = 0

  /// Makes the insets with the given values.
  ///
  /// - Parameters:
  ///   - top: The top inset.
  ///   - bottom: The bottom inset.
  init(top: CGFloat = 0, bottom: CGFloat = 0) {
    self.top = top
    self.bottom = bottom
  }

  /// Makes the top and bottom safe area insets of a view.
  ///
  /// - Parameter proxy: The geometry of the view.
  init(safeAreaOf proxy: GeometryProxy) {
    self.init(top: proxy.safeAreaInsets.top, bottom: proxy.safeAreaInsets.bottom)
  }

  /// The part of each inset that is more than the inset of `other`.
  ///
  /// - Parameter other: The insets to subtract.
  /// - Returns: The excess at each edge, never less than zero.
  func excess(over other: VerticalInsets) -> VerticalInsets {
    VerticalInsets(top: max(0, top - other.top), bottom: max(0, bottom - other.bottom))
  }
}

/// The inspector content for one file or several (plan.md §3.6, §9 F).
///
/// The view shows one full block for each of its files, in selection order.
/// Each block is an EditorKit `InspectorView` of one file, built from
/// EditorKit's field kinds only (^e4857xj): the file name in the name row,
/// the actions Open, Reveal in Finder, Share, Save, and pop-out Quick Look in
/// an EditorKit `InspectorActionRow` under the name, and EditorKit's
/// one-value preview of the file, a live QuickLook preview at the preview
/// height of the style, in its `.preview` row. The view never folds several
/// files into one block. The context menu and the keys of the selected
/// files in a thread view run each action on every selected file (card
/// ^zsr2pbf); that is the selection of the thread, not this view.
///
/// The rows take EditorKit's scheme ids, which ``nameIdentifier(of:)`` and
/// ``previewIdentifier(of:)`` give for the block of each file:
/// `inspection:attachment/object:<object id>/name` and
/// `inspection:attachment/object:<object id>/field:attachment.preview`.
/// `attachment` is the explicit id of the inspection, ``viewIdentifier``.
/// The object id is the raw id of the file of the block
/// (``Identifier/rawValue``), with each `%`, `/`, `.` and `+` escaped as
/// `%XX` by EditorKit's `InspectorScheme`. For the attachment with the id
/// `draft/notes.md`, the name row is
/// `inspection:attachment/object:draft%2Fnotes%2Emd/name`.
///
/// Each block is a grouped form with the ``formIdentifier``. It has the
/// system margins and row insets, no padding of its own and no background.
/// The blocks of several files stack as EditorKit stacks the blocks of an
/// `InspectorView`: each block takes the height of its rows, and the stack
/// scrolls in a scroll view of its own, or in the scroll view of the host
/// when the host owns the scrolling (`.inspectorScrolling(.host)`), and each
/// block shows its name row. The block of one file scrolls by itself unless
/// the host owns the scrolling.
///
/// Each block is the scope of its file (`agentAttachment:<id>`, AVK-11).
/// Each action button of a block runs the ``AgentAttachmentVerb`` command
/// of that scope on the file of the block only, so the buttons, the context
/// menu and the command palette of a block run the same commands on the
/// same file. This is true in the built-in inspector of an
/// ``AgentThreadView`` and in the inspector of a host
/// (``AttachmentInspectorMode/host(_:)``).
public struct AttachmentInspector: View {
  /// The start of the accessibility identifier of each action. Each block
  /// has one button with each identifier.
  public static let identifierPrefix = "inspector"

  /// The accessibility identifier of the grouped form of each block, which
  /// holds the name, the actions and the preview of its file.
  public static let formIdentifier = "inspector-form"

  /// The id of the `InspectorView` of each block and of its inspection,
  /// `attachment`: the view part of the scheme id of each row. It is
  /// explicit, so it does not follow the name of a type.
  public static let viewIdentifier = "attachment"

  /// The group part of the scheme id of the preview row: the key that
  /// EditorKit gives the one group of the inspection, named "Attachment".
  static let groupIdentifier = "attachment"

  /// The field part of the scheme id of the preview row.
  static let previewFieldIdentifier = "preview"

  /// The last part of the scheme id of the name row of a block.
  private static let namePart = "name"

  /// The accessibility identifiers of the actions, in display order.
  public static var actionIdentifiers: [String] {
    AttachmentActions.identifiers(prefix: identifierPrefix)
  }

  /// The inspection of one file: one group, named as the inspection, with
  /// the preview of the file. Its id is ``viewIdentifier``.
  static var inspection: Inspection<InspectedAttachment> {
    .named(
      FieldLabel(localized: "Attachment", bundle: .module), id: viewIdentifier, name: { $0.attachment.name }
    ) {
      Field(FieldLabel(localized: "Preview", bundle: .module)) { PreviewValue.file($0.attachment.url) }
        .identifier(previewFieldIdentifier)
    }
  }

  /// The files to show, in selection order.
  let attachments: [Attachment]

  /// The object of the `InspectorView` of each block, which follow
  /// ``attachments``.
  @State private var files: [InspectedAttachment]

  /// Who scrolls the blocks.
  @Environment(\.inspectorScrolling) private var scrolling

  /// Makes the inspector content for a file.
  ///
  /// - Parameter attachment: The file to show.
  public init(_ attachment: Attachment) {
    self.init([attachment])
  }

  /// Makes the inspector content for several files: one block for each
  /// file.
  ///
  /// - Parameter attachments: The files to show, in selection order.
  public init(_ attachments: [Attachment]) {
    self.attachments = attachments
    _files = State(initialValue: attachments.map(InspectedAttachment.init))
  }

  /// The scheme id of the name row of the block of `attachment`.
  ///
  /// The object id is the escaped raw id of the file. For the attachment
  /// with the id `draft/notes.md` the id is
  /// `inspection:attachment/object:draft%2Fnotes%2Emd/name`.
  ///
  /// - Parameter attachment: The file of the block.
  /// - Returns: `inspection:attachment/object:<object id>/name`.
  public static func nameIdentifier(of attachment: Attachment) -> String {
    let block = InspectorScheme.blockIdentifier(view: viewIdentifier, object: objectIdentifier(of: attachment))
    return InspectorScheme.identifier(of: namePart, inRow: block)
  }

  /// The scheme id of the preview row of the block of `attachment`.
  ///
  /// The object id is the escaped raw id of the file. For the attachment
  /// with the id `draft/notes.md` the id is
  /// `inspection:attachment/object:draft%2Fnotes%2Emd/field:attachment.preview`.
  ///
  /// - Parameter attachment: The file of the block.
  /// - Returns:
  ///   `inspection:attachment/object:<object id>/field:attachment.preview`.
  public static func previewIdentifier(of attachment: Attachment) -> String {
    InspectorScheme.rowIdentifier(
      view: viewIdentifier, object: objectIdentifier(of: attachment), group: groupIdentifier,
      field: previewFieldIdentifier)
  }

  /// The object part of the scheme id of each row of the block of
  /// `attachment`: the raw id of the file, escaped by EditorKit's
  /// `InspectorScheme`.
  ///
  /// - Parameter attachment: The file of the block.
  /// - Returns: The object id.
  private static func objectIdentifier(of attachment: Attachment) -> String {
    InspectorScheme.objectID(of: InspectedAttachment(attachment), key: viewIdentifier)
  }

  public var body: some View {
    content
      .onChange(of: attachments) {
        files = attachments.map(InspectedAttachment.init)
      }
  }

  /// The block of the one file, or the blocks of several files stacked.
  @ViewBuilder private var content: some View {
    if let file = files.first, files.count == 1 {
      block(of: file)
    } else {
      stacked
    }
  }

  /// The blocks of several files, stacked as EditorKit stacks the blocks of
  /// an `InspectorView`, each taking the height of its rows: in a scroll
  /// view of the view's own, or in the scroll view of the host. Each block
  /// shows its name row, also when the host hides the block headers
  /// (`.inspectorBlockHeader(.hidden)`), so each file is named.
  @ViewBuilder private var stacked: some View {
    let stack = VStack(spacing: 0) {
      ForEach(files) { file in
        block(of: file)
      }
    }
    .inspectorScrolling(.host)
    .inspectorBlockHeader(.automatic)
    switch scrolling {
    case .form: ScrollView { stack }
    case .host: stack
    }
  }

  /// The block of one file: the EditorKit `InspectorView` of the file with
  /// the action row, in the scope of the file, so each action acts on that
  /// file only.
  ///
  /// - Parameter file: The object of the file.
  /// - Returns: The block.
  private func block(of file: InspectedAttachment) -> some View {
    InspectorView(file, Self.inspection, id: Self.viewIdentifier)
      .actions {
        AttachmentActions(identifierPrefix: Self.identifierPrefix)
      }
      .accessibilityIdentifier(Self.formIdentifier)
      .agentAttachmentScope(file.attachment)
  }
}

/// One file of an ``AttachmentInspector``, as the object of the EditorKit
/// `InspectorView` of its block.
///
/// Its id is the raw id of its attachment, a `String`, so the object part
/// of the scheme id of each row is that text, escaped, and names the file
/// from run to run. An ``AttachmentID`` would describe itself as
/// `Attachment(<raw id>)`, a debug description.
@Observable
final class InspectedAttachment: Identifiable {
  /// The file.
  let attachment: Attachment

  /// The raw id of the attachment.
  var id: String { attachment.id.rawValue }

  /// Makes the object of a file.
  ///
  /// - Parameter attachment: The file.
  init(_ attachment: Attachment) {
    self.attachment = attachment
  }
}

#Preview("Attachment inspector") {
  if let attachment = PreviewFixtures.attachments.first {
    AttachmentInspector(attachment)
  }
}

#Preview("Attachment inspector of several files") {
  AttachmentInspector(PreviewFixtures.attachments)
}
