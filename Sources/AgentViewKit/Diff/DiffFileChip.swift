import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The chip of one file of a ``DiffView``: a button that selects the file,
/// with its counts.
///
/// The chip shows the symbol of the change of the file, the file name, and
/// the added and the removed line counts when the diff has patch text. The
/// chip of the file that the renderer shows sits on the shared selection
/// surface of EditorKit. A chip is not a content tile, so it keeps the small
/// padding of a chip.
struct DiffFileChip: View {
  /// The file of the chip.
  let file: DiffSummary.FileSummary

  /// Whether the diff has patch text, so the chip shows the line counts.
  let hasPatch: Bool

  /// Whether the renderer shows the file.
  let isSelected: Bool

  /// The action that selects the file.
  let select: () -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Button(action: select) {
      HStack(spacing: editorStyle.spacing.s) {
        Image(systemName: DiffView.symbolName(for: file.operation))
          .symbolRenderingMode(.hierarchical)
          .fontWeight(editorStyle.symbolWeight)
          .foregroundStyle(.secondary)
        Text(URL(fileURLWithPath: file.path).lastPathComponent)
          .lineLimit(1)
          .truncationMode(.middle)
        if hasPatch {
          Text(verbatim: "+\(file.added)")
            .foregroundStyle(editorTheme.diffAddedText)
          Text(verbatim: "\u{2212}\(file.removed)")
            .foregroundStyle(editorTheme.diffRemovedText)
        }
      }
      .font(editorTheme.font(for: .ui, style: .caption))
      .monospacedDigit()
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(.vertical, editorStyle.spacing.xs)
      .selectableSurface(isSelected, radius: DiffView.fileChipRadius)
    }
    .buttonStyle(.plain)
    .help(file.path)
    .accessibilityLabel(hasPatch ? file.accessibilityLabel : file.changeAccessibilityLabel)
    .accessibilityValue(file.path)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(DiffView.identifier(for: file.path))
  }
}

#Preview("File chip, selected and not selected") {
  if let file = DiffSummary.parse(gitPatch: PreviewFixtures.smallPatch).first {
    HStack {
      DiffFileChip(file: file, hasPatch: true, isSelected: true) {}
      DiffFileChip(file: file, hasPatch: true, isSelected: false) {}
    }
  }
}
