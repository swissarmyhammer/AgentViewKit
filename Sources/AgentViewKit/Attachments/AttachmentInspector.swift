import Observation
import Quartz
import SwiftUI

/// The attachment that the trailing inspector shows (plan.md §3.6).
///
/// A tap on an ``AttachmentView`` selects its attachment. The inspector is
/// open while the selection holds an attachment.
@MainActor @Observable
public final class InspectorSelection {
  /// The selected attachment, or `nil` when the inspector is closed.
  public private(set) var attachment: Attachment?

  /// Makes a selection.
  ///
  /// - Parameter attachment: The first selected attachment, or `nil`.
  public init(attachment: Attachment? = nil) {
    self.attachment = attachment
  }

  /// Selects an attachment, and so opens the inspector.
  ///
  /// - Parameter attachment: The attachment to show.
  public func select(_ attachment: Attachment) {
    self.attachment = attachment
  }

  /// Removes the selection, and so closes the inspector.
  public func clear() {
    attachment = nil
  }
}

extension EnvironmentValues {
  /// The selection that a tap on an attachment writes to, or `nil` when no
  /// inspector shows attachments.
  @Entry public var inspectorSelection: InspectorSelection?
}

extension View {
  /// Shows the selected attachment in a trailing inspector.
  ///
  /// The modifier gives `selection` to the environment of this view, so that
  /// a tap on an ``AttachmentView`` in this view opens the inspector.
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

  /// The top and bottom safe area insets around the inspector.
  @State private var outerInsets = VerticalInsets()

  /// The top and bottom safe area insets that the inspector gives its main
  /// content, before the padding of the modifier.
  @State private var innerInsets = VerticalInsets()

  func body(content: Content) -> some View {
    // The body reads the attachment itself, so that a new selection
    // evaluates the body again. A read in a binding closure is not tracked.
    let attachment = selection.attachment
    let missing = outerInsets.excess(over: innerInsets)
    content
      .environment(\.inspectorSelection, selection)
      .safeAreaPadding(.top, missing.top)
      .safeAreaPadding(.bottom, missing.bottom)
      // The padded view reads the safe area of its parent, so the padding of
      // the modifier is not in `innerInsets`.
      .onGeometryChange(for: VerticalInsets.self, of: VerticalInsets.init(safeAreaOf:)) {
        innerInsets = $0
      }
      .inspector(isPresented: isPresented(for: attachment)) {
        if let attachment {
          AttachmentInspector(attachment)
        }
      }
      .onGeometryChange(for: VerticalInsets.self, of: VerticalInsets.init(safeAreaOf:)) {
        outerInsets = $0
      }
  }

  /// A binding that is `true` while the selection holds an attachment. A
  /// write of `false` clears the selection.
  ///
  /// - Parameter attachment: The selected attachment that the body read.
  /// - Returns: The binding.
  private func isPresented(for attachment: Attachment?) -> Binding<Bool> {
    Binding(
      get: { attachment != nil },
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

/// The inspector content for one file (plan.md §3.6, §9 F).
///
/// The view shows the file name, a live QuickLook preview, and the actions
/// Open, Reveal in Finder, Share, Save, and pop-out Quick Look.
///
/// The view is a grouped form, as the inspectors of Xcode and Icon Composer
/// are (^bkhgxs5): one section holds the name and the actions, and one more
/// section holds the preview. The form has the system margins and row insets,
/// and no padding of its own, so the preview has the same leading and
/// trailing inset as the other rows. The form hides its own background, so
/// the background of the host shows around the rows.
///
/// The view is the scope of its attachment (`agentAttachment:<id>`, AVK-11).
/// Each action button runs the ``AgentAttachmentVerb`` command of that scope,
/// so the buttons, the context menu and the command palette run the same
/// commands. This is true in the built-in inspector of an ``AgentThreadView``
/// and in the inspector of a host
/// (``AttachmentInspectorMode/host(_:)``).
public struct AttachmentInspector: View {
  /// The start of the accessibility identifier of each action.
  public static let identifierPrefix = "inspector"

  /// The accessibility identifier of the file name.
  public static let nameIdentifier = "inspector-name"

  /// The accessibility identifier of the grouped form that holds the name,
  /// the preview and the actions.
  public static let formIdentifier = "inspector-form"

  /// The accessibility identifiers of the actions, in display order.
  public static var actionIdentifiers: [String] {
    AttachmentActions.identifiers(prefix: identifierPrefix)
  }

  /// The height of the preview row, in points. A row of a scrolling form
  /// has no height to fill, so the preview has a fixed height.
  static let previewHeight: CGFloat = 240

  /// The file to show.
  let attachment: Attachment

  /// Makes the inspector content for a file.
  ///
  /// - Parameter attachment: The file to show.
  public init(_ attachment: Attachment) {
    self.attachment = attachment
  }

  public var body: some View {
    Form {
      Section {
        Text(attachment.name)
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.middle)
          .accessibilityIdentifier(Self.nameIdentifier)
        AttachmentActions(attachment: attachment, identifierPrefix: Self.identifierPrefix)
      }
      Section {
        QuickLookPreview(url: attachment.url)
          .frame(maxWidth: .infinity)
          .frame(height: Self.previewHeight)
      }
    }
    .formStyle(.grouped)
    // A grouped form draws an opaque background of its own. A kit view is
    // transparent, so the background of the host shows around the rows.
    .scrollContentBackground(.hidden)
    .accessibilityIdentifier(Self.formIdentifier)
    .agentAttachmentScope(attachment)
  }
}

/// A live `QLPreviewView` of a file.
///
/// QuickLook can fail to make its view. Then this view is an empty view.
private struct QuickLookPreview: NSViewRepresentable {
  /// The file to show.
  let url: URL

  func makeNSView(context: Context) -> NSView {
    guard let preview = QLPreviewView(frame: .zero, style: .normal) else {
      return NSView()
    }
    preview.autostarts = true
    // `dismantleNSView` closes the view. A second close, when the window
    // closes, stops the process with a QuickLook assertion.
    preview.shouldCloseWithWindow = false
    preview.previewItem = url as NSURL
    return preview
  }

  func updateNSView(_ view: NSView, context: Context) {
    guard let preview = view as? QLPreviewView,
      (preview.previewItem as? NSURL) != url as NSURL
    else { return }
    preview.previewItem = url as NSURL
  }

  static func dismantleNSView(_ view: NSView, coordinator: ()) {
    (view as? QLPreviewView)?.close()
  }
}

#Preview("Attachment inspector") {
  if let attachment = PreviewFixtures.attachments.first {
    AttachmentInspector(attachment)
  }
}
