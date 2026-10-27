import EditorDiff
import EditorSwiftUI
import SwiftUI

/// The layout of the diff renderer that the kit installs (plan.md §4.1,
/// decision 12).
public nonisolated enum DiffLayout: Sendable, Hashable {
  /// One column. The removed lines of a change stand above its added lines.
  case inline

  /// Two columns: the old text on the left and the new text on the right.
  case sideBySide

  /// The EditorKit layout of this layout.
  var documentLayout: DiffDocument.Layout {
    switch self {
    case .inline: .inline
    case .sideBySide: .sideBySide
    }
  }
}

extension EnvironmentValues {
  /// The layout of the diff renderer that the kit installs.
  ///
  /// The default is ``DiffLayout/inline``. A renderer that a host installs
  /// with ``SwiftUI/View/diffRenderer(_:)`` can read the value too.
  @Entry public var diffLayout: DiffLayout = .inline
}

extension View {
  /// Sets the layout of each diff in this view.
  ///
  /// - Parameter layout: The layout of the diff renderer.
  /// - Returns: A view that gives `layout` to its subtree.
  public func diffLayout(_ layout: DiffLayout) -> some View {
    environment(\.diffLayout, layout)
  }
}

extension DiffView {
  /// The accessibility identifier of the row that shows when EditorKit cannot
  /// read the patch.
  public static let unreadablePatchIdentifier = "diff-patch-unreadable"
}

/// The default diff renderer: the EditorKit `DiffView` (plan.md §4.1,
/// decision 12).
///
/// The renderer parses the patch with `EditorDiff`, and keeps only the
/// selected file. It applies the ``SwiftUI/EnvironmentValues/diffLayout``. The
/// EditorKit `DiffView` reads the EditorKit theme of the environment. When
/// EditorKit cannot read the patch, a row shows the line where the parse
/// stopped.
///
/// Each line of the patch stands on one row, with no soft wrap: the inline
/// layout takes the EditorKit wrap mode `.none`, so a line wider than the
/// view scrolls sideways, and the text, the line-number gutters and the line
/// colors keep one row for each line (finding of ^8q34yt8). The side-by-side
/// layout keeps one row for each line already.
///
/// The renderer adds no accessibility identifier. The EditorKit `DiffView`
/// puts its own identifiers on its AppKit views: `editor.diff` on the root,
/// and `editor.diff.old` and `editor.diff.new` on the two columns of the
/// side-by-side layout.
struct EditorKitDiffRenderer: View {
  /// The full patch text.
  let patch: String

  /// The path of the file to show, or `nil` to show each file.
  let file: String?

  @Environment(\.diffLayout) private var layout

  var body: some View {
    switch Self.diff(of: patch, file: file) {
    case .success(let diff):
      EditorSwiftUI.DiffView(patch: diff)
        .diffLayout(layout.documentLayout)
        .diffWrapMode(.none)
    case .failure(let error):
      let text = String(
        localized: "Cannot read the patch at line \(Self.line(of: error))", bundle: .module)
      Label(text, systemImage: SharedSymbol.error)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier(DiffView.unreadablePatchIdentifier)
    }
  }

  /// The parsed patch, with only the file at `file`.
  ///
  /// A file matches when its new path, or the old path of a deleted file, is
  /// `file`. This is the path that ``DiffSummary`` gives. When no file
  /// matches, the result has each file of the patch.
  ///
  /// - Parameters:
  ///   - patch: The full patch text.
  ///   - file: The path of the file to keep, or `nil` to keep each file.
  /// - Returns: The parsed patch, or the parse error.
  static func diff(of patch: String, file: String?) -> Result<UnifiedDiff, UnifiedDiffError> {
    let parsed: UnifiedDiff
    do {
      parsed = try UnifiedDiff.parse(patch)
    } catch {
      return .failure(error)
    }
    guard let file else { return .success(parsed) }
    let kept = parsed.files.filter { ($0.newPath ?? $0.oldPath) == file }
    return .success(kept.isEmpty ? parsed : UnifiedDiff(files: kept))
  }

  /// The 1-based line of the patch where the parse stopped.
  ///
  /// - Parameter error: The parse error.
  /// - Returns: The line of the error.
  static func line(of error: UnifiedDiffError) -> Int {
    switch error {
    case .malformedHunkHeader(let line), .hunkLineCountMismatch(let line), .unexpectedLine(let line):
      line
    }
  }
}

#Preview("Small diff") {
  EditorKitDiffRenderer(patch: PreviewFixtures.smallPatch, file: nil)
}

#Preview("Large diff") {
  EditorKitDiffRenderer(patch: PreviewFixtures.largePatch, file: nil)
}

#Preview("Diff that only adds") {
  EditorKitDiffRenderer(patch: PreviewFixtures.addedOnlyPatch, file: nil)
}

#Preview("Diff that only removes") {
  EditorKitDiffRenderer(patch: PreviewFixtures.removedOnlyPatch, file: nil)
}
