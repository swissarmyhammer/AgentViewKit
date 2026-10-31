import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The label of one changed file: the symbol of the change, the file name on
/// one line with middle truncation, and the added and the removed line counts.
///
/// The symbol has the symbol weight of `\.editorStyle` and the color of
/// `\.themeSecondary`. The counts use the `diffAddedText` and `diffRemovedText`
/// roles of the EditorKit theme. The text is the caption of the `ui` font role,
/// with monospaced digits. ``DiffFileChip`` wraps the label in its button, and a
/// view kit shows it in a row of its own.
///
/// The label draws no selection, no focus and no fill, and it has no padding of
/// its own (EditorKit `style.md`, rule 10).
public struct DiffFileLabel: View {
  /// The added and the removed line counts of a file.
  public struct Counts: Equatable, Sendable {
    /// The number of added lines.
    public let added: Int

    /// The number of removed lines.
    public let removed: Int

    /// Makes the counts of a file.
    ///
    /// - Parameters:
    ///   - added: The number of added lines.
    ///   - removed: The number of removed lines.
    public init(added: Int, removed: Int) {
      self.added = added
      self.removed = removed
    }
  }

  /// The change to the file, or `nil` when the change is not known.
  let operation: DiffSummary.Operation?

  /// The path of the file.
  let path: String

  /// The line counts of the file, or `nil` for no counts.
  let counts: Counts?

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeSecondary) private var themeSecondary

  /// Makes the label of one file.
  ///
  /// - Parameters:
  ///   - operation: The change to the file, or `nil` when the change is not
  ///     known: the label shows the ``SharedSymbol/document`` symbol.
  ///   - path: The path of the file. The label shows its last part.
  ///   - counts: The line counts of the file, or `nil` for no counts. A binary
  ///     file has no lines, so it shows no counts.
  public init(operation: DiffSummary.Operation?, path: String, counts: Counts?) {
    self.operation = operation
    self.path = path
    self.counts = counts
  }

  /// The symbol of a change.
  ///
  /// - Parameter operation: The change to the file, or `nil`.
  /// - Returns: The symbol of ``DiffFileChip/symbolName(for:)``, or the
  ///   ``SharedSymbol/document`` symbol with no operation.
  static func symbolName(for operation: DiffSummary.Operation?) -> String {
    operation.map(DiffFileChip.symbolName(for:)) ?? SharedSymbol.document
  }

  /// The counts that a file shows.
  ///
  /// - Parameters:
  ///   - counts: The counts of the file, or `nil`.
  ///   - operation: The change to the file, or `nil`.
  /// - Returns: `counts`, or `nil` for a binary file.
  static func shownCounts(_ counts: Counts?, for operation: DiffSummary.Operation?) -> Counts? {
    operation == .binary ? nil : counts
  }

  /// The name that a file shows.
  ///
  /// - Parameter path: The path of the file.
  /// - Returns: The last part of the path.
  static func name(ofPath path: String) -> String {
    URL(fileURLWithPath: path).lastPathComponent
  }

  public var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Image(systemName: Self.symbolName(for: operation))
        .symbolRenderingMode(.hierarchical)
        .fontWeight(editorStyle.symbolWeight)
        .foregroundStyle(themeSecondary)
      Text(Self.name(ofPath: path))
        .lineLimit(1)
        .truncationMode(.middle)
      if let shown = Self.shownCounts(counts, for: operation) {
        Text(verbatim: "+\(shown.added)")
          .foregroundStyle(editorTheme.diffAddedText)
        Text(verbatim: "\u{2212}\(shown.removed)")
          .foregroundStyle(editorTheme.diffRemovedText)
      }
    }
    .font(editorTheme.font(for: .ui, style: .caption))
    .monospacedDigit()
  }
}

#Preview("The label of a file with counts, of a binary file and of an unknown change") {
  VStack(alignment: .leading) {
    DiffFileLabel(
      operation: .modified, path: StylePreviewFixtures.fileName, counts: DiffFileLabel.Counts(added: 3, removed: 1))
    DiffFileLabel(operation: .binary, path: StylePreviewFixtures.fileName, counts: nil)
    DiffFileLabel(operation: nil, path: StylePreviewFixtures.fileName, counts: nil)
  }
  .padding()
}
