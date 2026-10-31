import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// One row of a completion list: the label in the `ui` font role, and an
/// optional detail in the caption of that role, in the `.secondary` style.
///
/// A selected row sits on the shared selection surface of EditorKit, in the
/// small radius, which also gives the row its content shape. The row has no
/// glass and no padding around its surface: the list gives the space around its
/// rows (EditorKit `style.md`, rule 10), for example with
/// `.scrollContentMargins(\.spacing.xs)`.
public struct CompletionRow: View {
  /// The radius step of the selection surface: the small radius of a row in a
  /// list.
  public static let radius = EditorStyle.Radius.small

  /// The text of the row.
  let label: String

  /// The text after the label, or `nil` for no detail.
  let detail: String?

  /// Whether the row is the selected row.
  let isSelected: Bool

  /// The accessibility identifier of the row.
  let identifier: String

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes one row of a completion list.
  ///
  /// - Parameters:
  ///   - label: The text of the row.
  ///   - detail: The text after the label, or `nil` for no detail.
  ///   - isSelected: Whether the row is the selected row.
  ///   - identifier: The accessibility identifier of the row.
  public init(label: String, detail: String?, isSelected: Bool, identifier: String) {
    self.label = label
    self.detail = detail
    self.isSelected = isSelected
    self.identifier = identifier
  }

  public var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Text(label)
        .lineLimit(1)
      Spacer(minLength: editorStyle.spacing.s)
      if let detail {
        Text(detail)
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, editorStyle.spacing.s)
    .padding(.vertical, editorStyle.spacing.xs)
    .selectableSurface(isSelected, radius: Self.radius)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(label)
    .accessibilityValue(detail ?? "")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(identifier)
  }
}

#Preview("Rows of a completion list, selected and not selected") {
  VStack(alignment: .leading, spacing: .zero) {
    CompletionRow(
      label: StylePreviewFixtures.fileName, detail: StylePreviewFixtures.tileHeader, isSelected: true,
      identifier: "preview-completion-selected")
    CompletionRow(
      label: StylePreviewFixtures.fileName, detail: nil, isSelected: false, identifier: "preview-completion-row")
  }
  .frame(width: StylePreviewFixtures.narrowWidth)
  .padding()
}
