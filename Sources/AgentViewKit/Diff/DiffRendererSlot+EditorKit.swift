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
/// selected file. It applies the ``SwiftUI/EnvironmentValues/diffLayout`` and
/// the EditorKit theme of the ``AgentTheme``. When EditorKit cannot read the
/// patch, a row shows the line where the parse stopped.
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
  @Environment(\.agentTheme) private var theme

  var body: some View {
    switch Self.diff(of: patch, file: file) {
    case .success(let diff):
      EditorSwiftUI.DiffView(patch: diff)
        .diffLayout(layout.documentLayout)
        .editorTheme(theme.editorTheme)
    case .failure(let error):
      let text = String(localized: "Cannot read the patch at line \(Self.line(of: error))")
      Label(text, systemImage: "exclamationmark.triangle")
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
