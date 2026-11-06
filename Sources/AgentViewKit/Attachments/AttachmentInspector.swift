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
/// selection holds an attachment, and it folds several into one form
/// (``AttachmentInspector``).
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
  /// Shows the selected attachments in a trailing inspector, folded into one
  /// form when there are several.
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
/// The view is an EditorKit `InspectorView` of its files, built from
/// EditorKit's field kinds only (^e4857xj). For one file it shows the file
/// name in the name row, the actions Open, Reveal in Finder, Share, Save,
/// and pop-out Quick Look in an EditorKit `InspectorActionRow` under the
/// name, and EditorKit's one-value preview of the file, a live QuickLook
/// preview at the preview height of the style, in its `.preview` row.
/// Several files fold into one form (card ^xbhtytm): the header names the
/// title and the count, a Files row of EditorKit's paths kind shows a path
/// chip for each file, in selection order, the same action row acts on
/// every file, and the preview row reads "Mixed" when the files differ. A
/// press on a chip opens its file, as the Open command does. Each action
/// runs on every file of the inspector, in selection order, and is
/// available only when it can run on each file. The context menu and the
/// keys of a selected file in a thread view also run each action on every
/// selected file (card ^zsr2pbf).
///
/// The rows take EditorKit's scheme ids, which ``nameIdentifier(of:)``,
/// ``filesIdentifier(of:)`` and ``previewIdentifier(of:)`` give:
/// `inspection:attachment/object:<object id>/name`,
/// `inspection:attachment/object:<object id>/field:attachment.files` and
/// `inspection:attachment/object:<object id>/field:attachment.preview`.
/// `attachment` is the explicit id of the inspection, ``viewIdentifier``.
/// The object id is the raw id of each attachment (``Identifier/rawValue``),
/// with each `%`, `/`, `.` and `+` escaped as `%XX` by EditorKit's
/// `InspectorScheme`; several files join their ids with `+`. For the
/// attachment with the id `draft/notes.md`, the name row is
/// `inspection:attachment/object:draft%2Fnotes%2Emd/name`. The form takes
/// the ``formIdentifier``. It has the system margins and row insets, no
/// padding of its own and no background, and it scrolls by itself unless
/// the host owns the scrolling (`.inspectorScrolling(.host)`).
///
/// The view is the scope of its first file (`agentAttachment:<id>`,
/// AVK-11), which gives every file of the view to the context of its
/// commands as their selection. Each action button runs the
/// ``AgentAttachmentVerb`` command of that scope on those files, so the
/// buttons, the context menu and the command palette run the same commands
/// on the same files. This is true
/// in the built-in inspector of an ``AgentThreadView`` and in the inspector
/// of a host (``AttachmentInspectorMode/host(_:)``).
public struct AttachmentInspector: View {
  /// The start of the accessibility identifier of each action.
  public static let identifierPrefix = "inspector"

  /// The accessibility identifier of the grouped form that holds the name,
  /// the actions, the Files row of several files and the preview.
  public static let formIdentifier = "inspector-form"

  /// The id of the `InspectorView` and of its inspection, `attachment`: the
  /// view part of the scheme id of each row. It is explicit, so it does not
  /// follow the name of a type.
  public static let viewIdentifier = "attachment"

  /// The group part of the scheme id of the Files row and of the preview
  /// row: the key that EditorKit gives the one group of the inspection,
  /// named "Attachment".
  static let groupIdentifier = "attachment"

  /// The field part of the scheme id of the Files row.
  static let filesFieldIdentifier = "files"

  /// The field part of the scheme id of the preview row.
  static let previewFieldIdentifier = "preview"

  /// The last part of the scheme id of the name row of a block.
  private static let namePart = "name"

  /// The accessibility identifiers of the actions, in display order.
  public static var actionIdentifiers: [String] {
    AttachmentActions.identifiers(prefix: identifierPrefix)
  }

  /// The inspection of the files: one group, named as the inspection, with
  /// the Files row of several files and the preview of the file. Its id is
  /// ``viewIdentifier``.
  ///
  /// The Files row is EditorKit's paths kind: a path chip for each file of
  /// the inspector, in selection order. Each object of one inspector holds
  /// the same files (``InspectedAttachment/files``), so the row folds to
  /// that list, and it shows only for several files. A press on a chip
  /// opens its file (``InspectedAttachment/open(_:)``).
  static var inspection: Inspection<InspectedAttachment> {
    .named(
      FieldLabel(localized: "Attachment", bundle: .module), id: viewIdentifier, name: { $0.attachment.name }
    ) {
      Field(FieldLabel(localized: "Files", bundle: .module)) { $0.files.map(\.url) }
        .identifier(filesFieldIdentifier)
        .visible { $0.files.count > 1 }
        .opening { $0.open($1) }
      Field(FieldLabel(localized: "Preview", bundle: .module)) { PreviewValue.file($0.attachment.url) }
        .identifier(previewFieldIdentifier)
    }
  }

  /// The files to show, in selection order.
  let attachments: [Attachment]

  /// The objects of the `InspectorView`, which follow ``attachments``.
  @State private var files: [InspectedAttachment]

  /// The service of the environment, which opens a chip of the Files row,
  /// or `nil` for the system default.
  @Environment(\.attachmentFileService) private var fileService

  /// Makes the inspector content for a file.
  ///
  /// - Parameter attachment: The file to show.
  public init(_ attachment: Attachment) {
    self.init([attachment])
  }

  /// Makes the inspector content for several files, folded into one form.
  ///
  /// - Parameter attachments: The files to show, in selection order.
  public init(_ attachments: [Attachment]) {
    self.attachments = attachments
    _files = State(initialValue: InspectedAttachment.objects(of: attachments, fileService: nil))
  }

  /// The scheme id of the name row of the inspector of `attachments`.
  ///
  /// The object id is the escaped raw id of each file, joined with `+`. For
  /// the attachment with the id `draft/notes.md` the id is
  /// `inspection:attachment/object:draft%2Fnotes%2Emd/name`.
  ///
  /// - Parameter attachments: The files of the inspector, in selection order.
  /// - Returns: `inspection:attachment/object:<object id>/name`.
  public static func nameIdentifier(of attachments: [Attachment]) -> String {
    let block = InspectorScheme.blockIdentifier(view: viewIdentifier, object: objectIdentifier(of: attachments))
    return InspectorScheme.identifier(of: namePart, inRow: block)
  }

  /// The scheme id of the Files row of the inspector of `attachments`, which
  /// shows for several files.
  ///
  /// The object id is the escaped raw id of each file, joined with `+`. For
  /// the attachments with the ids `draft/notes.md` and `plan` the id is
  /// `inspection:attachment/object:draft%2Fnotes%2Emd+plan/field:attachment.files`.
  ///
  /// - Parameter attachments: The files of the inspector, in selection order.
  /// - Returns:
  ///   `inspection:attachment/object:<object id>/field:attachment.files`.
  public static func filesIdentifier(of attachments: [Attachment]) -> String {
    InspectorScheme.rowIdentifier(
      view: viewIdentifier, object: objectIdentifier(of: attachments), group: groupIdentifier,
      field: filesFieldIdentifier)
  }

  /// The scheme id of the preview row of the inspector of `attachments`.
  ///
  /// The object id is the escaped raw id of each file, joined with `+`. For
  /// the attachment with the id `draft/notes.md` the id is
  /// `inspection:attachment/object:draft%2Fnotes%2Emd/field:attachment.preview`.
  ///
  /// - Parameter attachments: The files of the inspector, in selection order.
  /// - Returns:
  ///   `inspection:attachment/object:<object id>/field:attachment.preview`.
  public static func previewIdentifier(of attachments: [Attachment]) -> String {
    InspectorScheme.rowIdentifier(
      view: viewIdentifier, object: objectIdentifier(of: attachments), group: groupIdentifier,
      field: previewFieldIdentifier)
  }

  /// The object part of the scheme id of each row of the inspector of
  /// `attachments`: the raw id of each file, escaped by EditorKit's
  /// `InspectorScheme` and joined with `+`.
  ///
  /// - Parameter attachments: The files of the inspector, in selection order.
  /// - Returns: The object id.
  private static func objectIdentifier(of attachments: [Attachment]) -> String {
    InspectorScheme.objectID(of: attachments.map(InspectedAttachment.init), key: viewIdentifier)
  }

  public var body: some View {
    InspectorView(files, Self.inspection, id: Self.viewIdentifier)
      .actions {
        AttachmentActions(identifierPrefix: Self.identifierPrefix)
      }
      .accessibilityIdentifier(Self.formIdentifier)
      .agentAttachmentScope(files: attachments)
      .onChange(of: attachments) {
        files = InspectedAttachment.objects(of: attachments, fileService: fileService)
      }
      .onChange(of: fileService.map(ObjectIdentifier.init), initial: true) {
        for file in files {
          file.fileService = fileService
        }
      }
  }
}

/// One file of an ``AttachmentInspector``, as an object of its EditorKit
/// `InspectorView`.
///
/// Its id is the raw id of its attachment, a `String`, so the object part
/// of the scheme id of each row is that text, escaped, and names the file
/// from run to run. An ``AttachmentID`` would describe itself as
/// `Attachment(<raw id>)`, a debug description.
@Observable
final class InspectedAttachment: Identifiable {
  /// The file.
  let attachment: Attachment

  /// The files of the inspector that shows the file, in selection order.
  /// Each object of one inspector holds the same files, so the Files row,
  /// which reads them, folds to one list.
  let files: [Attachment]

  /// The service that opens the file of a chip of the Files row: the
  /// ``SwiftUI/EnvironmentValues/attachmentFileService`` of the inspector,
  /// or `nil` for the system default, a new ``AttachmentPresenter``.
  ///
  /// The inspection is static, so its rows cannot read the environment of
  /// the view. The ``AttachmentInspector`` writes the service of its
  /// environment here, as `InspectedClientModel` takes a service for its
  /// path rows.
  @ObservationIgnored var fileService: (any AttachmentFileService)?

  /// The raw id of the attachment.
  var id: String { attachment.id.rawValue }

  /// Makes the object of a file in an inspector of `files`.
  ///
  /// - Parameters:
  ///   - attachment: The file.
  ///   - files: The files of the inspector, in selection order.
  ///   - fileService: The service that opens a chip of the Files row, or
  ///     `nil` for the system default.
  init(_ attachment: Attachment, files: [Attachment], fileService: (any AttachmentFileService)?) {
    self.attachment = attachment
    self.files = files
    self.fileService = fileService
  }

  /// Makes the object of a file in an inspector of that file alone, which
  /// opens a chip with the system default.
  ///
  /// - Parameter attachment: The file.
  convenience init(_ attachment: Attachment) {
    self.init(attachment, files: [attachment], fileService: nil)
  }

  /// The objects of an inspector of `attachments`, one for each file.
  ///
  /// - Parameters:
  ///   - attachments: The files of the inspector, in selection order.
  ///   - fileService: The service that opens a chip of the Files row, or
  ///     `nil` for the system default.
  /// - Returns: The objects, in selection order.
  static func objects(
    of attachments: [Attachment], fileService: (any AttachmentFileService)?
  ) -> [InspectedAttachment] {
    attachments.map { InspectedAttachment($0, files: attachments, fileService: fileService) }
  }

  /// Opens the file of a chip of the Files row, as the Open command of an
  /// attachment does: runs ``AgentAttachmentVerb/openAttachment`` on the
  /// file of ``files`` at `url` with ``fileService``, or with the system
  /// default. A service that cannot open the file logs the failure.
  ///
  /// - Parameter url: The URL of the chip.
  func open(_ url: URL) {
    let file = files.first { $0.url == url } ?? Attachment(url: url)
    _ = (fileService ?? AttachmentPresenter()).run(.openAttachment, on: file)
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
