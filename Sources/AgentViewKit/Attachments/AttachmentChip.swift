import AppKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// A compact view of a file: the type icon, the name, and the size
/// (plan.md §3.6).
///
/// ``AttachmentView`` shows the chip for a type that has no other default
/// view, and for a file that a preview cannot load.
///
/// The chip is the scope of its attachment (`agentAttachment:<id>`, AVK-11),
/// also in the composer: its context menu and the command palette show the
/// ``AgentAttachmentVerb`` commands for the file. In an ``AttachmentView``,
/// the chip uses the scope of the view.
///
/// The chip has a surface of its own, so it shows the focus of its scope as
/// the stronger accent fill in its own shape, and the scope draws no ring
/// (EditorKit style.md, "Selection and focus"). That fill, or the fill of the
/// selection of an ``AttachmentView`` around the chip, replaces the base fill
/// of the chip.
public struct AttachmentChip: View {
  /// The side of the type icon, in points at the default theme font. The icon
  /// stands beside the two lines of text, so it scales with them.
  private static let iconSide: CGFloat = 28

  /// The corners of the chip: the medium radius of `\.editorStyle`. The base
  /// fill of the chip and the fill of its selection and its focus both have
  /// them. The chip reports them (``AttachmentSurfaceCornersKey``), so the
  /// selectable surface of an ``AttachmentView`` that shows the chip has them
  /// too.
  static let corners = SurfaceCorners.rounded(.medium)

  /// The attached file.
  let attachment: Attachment

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.placedSecondary) private var placedSecondary
  @ThemeFontScale(.ui) private var fontScale

  /// Makes the chip of a file.
  ///
  /// - Parameter attachment: The attached file.
  public init(_ attachment: Attachment) {
    self.attachment = attachment
  }

  /// The size of a file as text, such as `16 bytes`.
  ///
  /// - Parameter size: The size in bytes, or `nil`.
  /// - Returns: The formatted size, or `nil` when the size is not known.
  public static func sizeText(_ size: Int?) -> String? {
    size.map { Int64($0).formatted(.byteCount(style: .file)) }
  }

  public var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Image(nsImage: NSWorkspace.shared.icon(for: attachment.type))
        .resizable()
        .frame(width: Self.iconSide * fontScale, height: Self.iconSide * fontScale)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        Text(attachment.name)
          .lineLimit(1)
          .truncationMode(.middle)
        if let sizeText = Self.sizeText(attachment.size) {
          Text(sizeText)
            .font(editorTheme.font(for: .ui, style: .caption))
            .foregroundStyle(placedSecondary)
        }
      }
    }
    .padding(.horizontal, editorStyle.spacing.m)
    .padding(.vertical, editorStyle.spacing.xs)
    .modifier(AttachmentChipFill())
    .agentAttachmentScope(attachment, focusLook: .fill(Self.corners))
    .preference(key: AttachmentSurfaceCornersKey.self, value: Self.corners)
  }
}

/// The base fill of an ``AttachmentChip``: the quaternary fill of the theme
/// in the corners of the chip, while no fill of the selection or the focus of
/// the chip shows (`\.isItemStateFillShown`). The state fill replaces the
/// base fill, so the two fills do not stack.
private struct AttachmentChipFill: ViewModifier {
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.themeFill) private var themeFill
  @Environment(\.isItemStateFillShown) private var isStateFillShown

  func body(content: Content) -> some View {
    content.background {
      if !isStateFillShown {
        SurfaceFill(themeFill.quaternary, radius: AttachmentChip.corners.radius(in: editorStyle))
      }
    }
  }
}

#Preview("Attachment chip") {
  HStack {
    ForEach(PreviewFixtures.attachments) { attachment in
      AttachmentChip(attachment)
    }
  }
}
