import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The rows of terminal output that a read-only editor shows, with the color
/// runs of those rows.
///
/// ``TerminalView`` and ``CommandOutputView`` make one value for each body.
/// ``ANSIText`` parses the output with the terminal palette of the EditorKit
/// theme. The rows that show are the last rows of the parsed text, and each
/// run range is a UTF-8 byte range of the text of those rows, so that
/// `EditorModel.setColorRuns(_:)` and `EditorModel.addColorRuns(_:)` can
/// take the runs.
struct TerminalOutput: Equatable {
  /// The rows of the parsed text that show.
  let rows: CommandOutputView.VisibleRows
  /// The color runs of ``rows``, in document order.
  let colorRuns: [EditorColorRun]

  /// Parses `output` and keeps its last rows.
  ///
  /// - Parameters:
  ///   - output: The output text, with its escape sequences.
  ///   - palette: The terminal palette of the EditorKit theme.
  ///   - limit: The largest number of rows that show.
  init(output: String, palette: TerminalPalette, limit: Int) {
    let parsed = ANSIText.attributed(from: output, palette: palette)
    rows = CommandOutputView.VisibleRows(output: String(parsed.characters), limit: limit)
    let shown = 0..<rows.text.utf8.count
    colorRuns = EditorColorRun.runs(in: parsed, startingAt: -rows.hiddenByteCount)
      .compactMap { $0.clamped(to: shown) }
  }
}

extension EditorColorRun {
  /// This run, cut to `bounds`.
  ///
  /// - Parameter bounds: The UTF-8 byte range to keep.
  /// - Returns: The run with the same colors over the part of its range in
  ///   `bounds`, or `nil` when no byte of the run is in `bounds`.
  func clamped(to bounds: Range<Int>) -> EditorColorRun? {
    let kept = range.clamped(to: bounds)
    guard !kept.isEmpty else { return nil }
    return EditorColorRun(range: kept, foreground: foreground, background: background)
  }
}

extension EditorModel {
  /// Makes the model read-only, changes its text to `text`, and gives it the
  /// color runs `runs`.
  ///
  /// A change that only appends text adds the runs of the new text, so the
  /// style pass repaints only the new text. Any other change replaces each
  /// run. A change of the text replaces the whole text, which clears the
  /// runs (EditorKit), so the runs follow the text.
  ///
  /// - Parameters:
  ///   - text: The full text that the document must have.
  ///   - runs: The color runs of `text`, in document order.
  func syncReadOnly(to text: String, colorRuns runs: [EditorColorRun]) {
    let oldLength = self.text.utf8.count
    let oldRuns = colorRuns
    let appends = text.utf8.count > oldLength && text.utf8.starts(with: self.text.utf8)
    syncReadOnly(to: text)
    if appends, oldRuns == runs.compactMap({ $0.clamped(to: 0..<oldLength) }) {
      addColorRuns(runs.filter { $0.range.upperBound > oldLength })
    } else if colorRuns != runs {
      setColorRuns(runs)
    }
  }
}
