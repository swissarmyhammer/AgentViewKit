import AppKit
import SwiftUI

/// A compact view of a file: the type icon, the name, and the size
/// (plan.md §3.6).
///
/// ``AttachmentView`` shows the chip for a type that has no other default
/// view, and for a file that a preview cannot load.
public struct AttachmentChip: View {
  /// The side of the type icon, in points.
  private static let iconSide: CGFloat = 28

  /// The attached file.
  let attachment: Attachment

  @Environment(\.agentTheme) private var theme

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
    HStack(spacing: theme.spacing.s) {
      Image(nsImage: NSWorkspace.shared.icon(for: attachment.type))
        .resizable()
        .frame(width: Self.iconSide, height: Self.iconSide)
        .accessibilityHidden(true)
      VStack(alignment: .leading) {
        Text(attachment.name)
          .lineLimit(1)
          .truncationMode(.middle)
        if let sizeText = Self.sizeText(attachment.size) {
          Text(sizeText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
  }
}
