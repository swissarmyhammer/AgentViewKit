@testable import AgentViewKit
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// Checks the color runs that ``TerminalOutput`` gives for the rows that
/// show, and the sync of a read-only editor model to a text with its runs.
@Suite @MainActor struct TerminalOutputTests {
  /// The escape character that starts each control sequence.
  static let escape = "\u{1B}"
  /// The terminal palette of the tests. Each of its colors is different.
  static let palette = DistinctRolesTheme.Role.terminalPalette
  /// A row limit that shows each row of the short outputs.
  static let largeRowLimit = 10
  /// A row limit that hides the first row of a three-row output.
  static let twoRowLimit = 2
  /// The ANSI color number of red.
  static let redIndex = 1
  /// The ANSI color number of green.
  static let greenIndex = 2

  /// A run with the text color of ANSI color `index`.
  ///
  /// - Parameters:
  ///   - range: The UTF-8 byte range of the run.
  ///   - index: The ANSI color number.
  /// - Returns: The run.
  static func ansiRun(_ range: Range<Int>, _ index: Int) -> EditorColorRun {
    EditorColorRun(range: range, foreground: palette.ansiColor(index))
  }

  /// A run with the terminal foreground.
  ///
  /// - Parameter range: The UTF-8 byte range of the run.
  /// - Returns: The run.
  static func foregroundRun(_ range: Range<Int>) -> EditorColorRun {
    EditorColorRun(range: range, foreground: palette[.foreground])
  }

  // MARK: - The runs of the rows that show

  @Test func theRunsCoverTheOutputWhenEachRowShows() {
    let output = TerminalOutput(
      output: "\(Self.escape)[31mred\(Self.escape)[0m ok", palette: Self.palette,
      limit: Self.largeRowLimit)

    #expect(output.rows.text == "red ok")
    #expect(output.colorRuns == [Self.ansiRun(0..<3, Self.redIndex), Self.foregroundRun(3..<6)])
  }

  @Test func theRunsOfACappedOutputStartAtTheFirstRowThatShows() {
    let output = TerminalOutput(
      output: "\(Self.escape)[31ma\(Self.escape)[0m\n\(Self.escape)[32mb\(Self.escape)[0m\nc",
      palette: Self.palette, limit: Self.twoRowLimit)

    #expect(output.rows.text == "b\nc")
    #expect(output.colorRuns == [Self.ansiRun(0..<1, Self.greenIndex), Self.foregroundRun(1..<3)])
  }

  @Test func theRunRangesCountUTF8Bytes() {
    let output = TerminalOutput(
      output: "\(Self.escape)[31mé\(Self.escape)[0mx", palette: Self.palette,
      limit: Self.largeRowLimit)

    #expect(output.colorRuns == [Self.ansiRun(0..<2, Self.redIndex), Self.foregroundRun(2..<3)])
  }

  // MARK: - The sync of a model

  @Test func aSyncSetsTheTextAndTheRuns() {
    let model = EditorModel.makeReadOnly("")
    let runs = [Self.ansiRun(0..<2, Self.redIndex)]

    model.syncReadOnly(to: "ab", colorRuns: runs)

    #expect(model.text == "ab")
    #expect(model.colorRuns == runs)
  }

  @Test func aSyncThatAppendsTextAddsTheRunsOfTheNewText() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [Self.ansiRun(0..<2, Self.redIndex)])
    let runs = [Self.ansiRun(0..<2, Self.redIndex), Self.ansiRun(2..<4, Self.greenIndex)]

    model.syncReadOnly(to: "abcd", colorRuns: runs)

    #expect(model.text == "abcd")
    #expect(model.colorRuns == runs)
  }

  @Test func aSyncThatAppendsTextGrowsARunThatContinues() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [Self.ansiRun(0..<2, Self.redIndex)])

    model.syncReadOnly(to: "abcd", colorRuns: [Self.ansiRun(0..<4, Self.redIndex)])

    #expect(model.colorRuns == [Self.ansiRun(0..<4, Self.redIndex)])
  }

  @Test func aSyncThatReplacesTheTextReplacesTheRuns() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "abcd", colorRuns: [Self.ansiRun(0..<4, Self.redIndex)])

    model.syncReadOnly(to: "xy", colorRuns: [Self.ansiRun(0..<2, Self.greenIndex)])

    #expect(model.text == "xy")
    #expect(model.colorRuns == [Self.ansiRun(0..<2, Self.greenIndex)])
  }

  @Test func aSyncWithTheSameTextAndNewRunsReplacesTheRuns() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [Self.ansiRun(0..<2, Self.redIndex)])

    model.syncReadOnly(to: "ab", colorRuns: [Self.ansiRun(0..<2, Self.greenIndex)])

    #expect(model.colorRuns == [Self.ansiRun(0..<2, Self.greenIndex)])
  }
}
