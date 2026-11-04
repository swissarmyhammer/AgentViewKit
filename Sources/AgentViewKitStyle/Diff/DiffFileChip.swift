import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The chip of one file of a diff: a button that selects the file, with its
/// counts.
///
/// The chip shows the ``DiffFileLabel`` of the file, with the added and the
/// removed line counts when the diff has patch text. The chip of the file that the renderer shows sits on the
/// shared selection surface of EditorKit. A chip is not a content tile, so it
/// keeps the small padding of a chip. The diff view of AgentViewKit shows a
/// chip for each file of its patch, in a ``ChipFlowLayout``.
public struct DiffFileChip: View {
  /// The start of the accessibility identifier of each file chip.
  public static let identifierPrefix = "diff-file-"

  /// The radius step of a file chip: the small radius. The selected chip
  /// sits on the shared selection surface in this shape, and the focus ring
  /// of the chip button follows the same shape.
  public static let radius = EditorStyle.Radius.small

  /// The file of the chip.
  let file: DiffSummary.FileSummary

  /// Whether the diff has patch text, so the chip shows the line counts.
  let hasPatch: Bool

  /// Whether the renderer shows the file.
  let isSelected: Bool

  /// The action that selects the file.
  let select: () -> Void

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the chip of one file.
  ///
  /// - Parameters:
  ///   - file: The file of the chip.
  ///   - hasPatch: Whether the diff has patch text, so the chip shows the
  ///     line counts.
  ///   - isSelected: Whether the renderer shows the file.
  ///   - select: The action that selects the file.
  public init(file: DiffSummary.FileSummary, hasPatch: Bool, isSelected: Bool, select: @escaping () -> Void) {
    self.file = file
    self.hasPatch = hasPatch
    self.isSelected = isSelected
    self.select = select
  }

  /// The accessibility identifier of the chip of the file at `path`.
  ///
  /// - Parameter path: The path of the file.
  /// - Returns: `diff-file-<path>`.
  public static func identifier(for path: String) -> String {
    identifierPrefix + path
  }

  /// The line counts of the file, when the diff has patch text.
  private var counts: DiffFileLabel.Counts? {
    hasPatch ? DiffFileLabel.Counts(added: file.added, removed: file.removed) : nil
  }

  public var body: some View {
    Button(action: select) {
      DiffFileLabel(operation: file.operation, path: file.path, counts: counts)
        .padding(.horizontal, editorStyle.spacing.s)
        .padding(.vertical, editorStyle.spacing.xs)
        .selectableSurface(isSelected, radius: Self.radius)
    }
    .buttonStyle(.plain)
    .help(file.path)
    .accessibilityLabel(
      DiffFileLabel.shownCounts(counts, for: file.operation) == nil
        ? file.changeAccessibilityLabel : file.accessibilityLabel)
    .accessibilityValue(file.path)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(Self.identifier(for: file.path))
  }
}

extension EditorSymbol.FileKind {
  /// The EditorKit kind of a file of a diff: the one map from a change to its
  /// symbol.
  ///
  /// ``DiffFileLabel`` shows the symbol of the kind, and a view kit that
  /// shows a changed file reads the same kind, so the file shows one symbol.
  ///
  /// - Parameter operation: The change to the file.
  public init(_ operation: DiffSummary.Operation) {
    switch operation {
    case .added: self = .added
    case .deleted: self = .deleted
    case .modified: self = .modified
    case .renamed: self = .renamed
    case .copied: self = .copied
    case .binary: self = .binary
    case .unknown: self = .unknown
    }
  }
}

#Preview("File chip, selected and not selected") {
  if let file = DiffSummary.parse(gitPatch: StylePreviewFixtures.patch).first {
    HStack {
      DiffFileChip(file: file, hasPatch: true, isSelected: true) {}
      DiffFileChip(file: file, hasPatch: true, isSelected: false) {}
    }
    .padding()
  }
}
