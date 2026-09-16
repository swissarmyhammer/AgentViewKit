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
  /// ``AgentThreadView`` applies this modifier.
  ///
  /// - Parameter selection: The selection to show.
  /// - Returns: A view with the inspector.
  public func attachmentInspector(selection: InspectorSelection) -> some View {
    modifier(AttachmentInspectorModifier(selection: selection))
  }
}

/// Binds a trailing inspector to an ``InspectorSelection``.
private struct AttachmentInspectorModifier: ViewModifier {
  /// The selection to show.
  let selection: InspectorSelection

  func body(content: Content) -> some View {
    // The body reads the attachment itself, so that a new selection
    // evaluates the body again. A read in a binding closure is not tracked.
    let attachment = selection.attachment
    content
      .environment(\.inspectorSelection, selection)
      .inspector(isPresented: isPresented(for: attachment)) {
        if let attachment {
          AttachmentInspector(attachment)
        }
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

/// The inspector content for one file (plan.md §3.6, §9 F).
///
/// The view shows the file name, a live QuickLook preview, and the actions
/// Open, Reveal in Finder, Share, Save, and pop-out Quick Look.
public struct AttachmentInspector: View {
  /// The start of the accessibility identifier of each action.
  public static let identifierPrefix = "inspector"

  /// The accessibility identifier of the file name.
  public static let nameIdentifier = "inspector-name"

  /// The accessibility identifiers of the actions, in display order.
  public static var actionIdentifiers: [String] {
    AttachmentActions.identifiers(prefix: identifierPrefix)
  }

  /// The file to show.
  let attachment: Attachment

  @Environment(\.agentTheme) private var theme

  /// Makes the inspector content for a file.
  ///
  /// - Parameter attachment: The file to show.
  public init(_ attachment: Attachment) {
    self.attachment = attachment
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      Text(attachment.name)
        .font(.headline)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityIdentifier(Self.nameIdentifier)
      QuickLookPreview(url: attachment.url)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      AttachmentActions(attachment: attachment, identifierPrefix: Self.identifierPrefix)
    }
    .padding(theme.spacing.m)
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
