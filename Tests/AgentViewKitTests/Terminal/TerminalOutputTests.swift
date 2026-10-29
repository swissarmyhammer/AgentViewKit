@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// Checks the color runs that ``TerminalOutput`` gives for the rows that
/// show, and the sync of a read-only editor model to a text with its runs.
/// The escape character, the palette and the runs come from ``ANSIFixtures``.
@Suite @MainActor struct TerminalOutputTests {
  /// A row limit that shows each row of the short outputs.
  static let largeRowLimit = 10
  /// A row limit that hides the first row of a three-row output.
  static let twoRowLimit = 2

  // MARK: - The runs of the rows that show

  @Test func theRunsCoverTheOutputWhenEachRowShows() {
    let escape = ANSIFixtures.escape
    let output = TerminalOutput(
      output: "\(escape)[31mred\(escape)[0m ok", palette: ANSIFixtures.palette,
      limit: Self.largeRowLimit)

    #expect(output.rows.text == "red ok")
    #expect(
      output.colorRuns == [
        ANSIFixtures.ansiRun(0..<3, ANSIFixtures.redIndex), ANSIFixtures.foregroundRun(3..<6),
      ])
  }

  @Test func theRunsOfACappedOutputStartAtTheFirstRowThatShows() {
    let escape = ANSIFixtures.escape
    let output = TerminalOutput(
      output: "\(escape)[31ma\(escape)[0m\n\(escape)[32mb\(escape)[0m\nc",
      palette: ANSIFixtures.palette, limit: Self.twoRowLimit)

    #expect(output.rows.text == "b\nc")
    #expect(
      output.colorRuns == [
        ANSIFixtures.ansiRun(0..<1, ANSIFixtures.greenIndex), ANSIFixtures.foregroundRun(1..<3),
      ])
  }

  @Test func theRunRangesCountUTF8Bytes() {
    let escape = ANSIFixtures.escape
    let output = TerminalOutput(
      output: "\(escape)[31mé\(escape)[0mx", palette: ANSIFixtures.palette,
      limit: Self.largeRowLimit)

    #expect(
      output.colorRuns == [
        ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex), ANSIFixtures.foregroundRun(2..<3),
      ])
  }

  // MARK: - The sync of a model

  @Test func aSyncSetsTheTextAndTheRuns() {
    let model = EditorModel.makeReadOnly("")
    let runs = [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex)]

    model.syncReadOnly(to: "ab", colorRuns: runs)

    #expect(model.text == "ab")
    #expect(model.colorRuns == runs)
  }

  @Test func aSyncThatAppendsTextAddsTheRunsOfTheNewText() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex)])
    let runs = [
      ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex),
      ANSIFixtures.ansiRun(2..<4, ANSIFixtures.greenIndex),
    ]

    model.syncReadOnly(to: "abcd", colorRuns: runs)

    #expect(model.text == "abcd")
    #expect(model.colorRuns == runs)
  }

  @Test func aSyncThatAppendsTextGrowsARunThatContinues() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex)])

    model.syncReadOnly(to: "abcd", colorRuns: [ANSIFixtures.ansiRun(0..<4, ANSIFixtures.redIndex)])

    #expect(model.colorRuns == [ANSIFixtures.ansiRun(0..<4, ANSIFixtures.redIndex)])
  }

  @Test func aSyncThatReplacesTheTextReplacesTheRuns() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "abcd", colorRuns: [ANSIFixtures.ansiRun(0..<4, ANSIFixtures.redIndex)])

    model.syncReadOnly(to: "xy", colorRuns: [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.greenIndex)])

    #expect(model.text == "xy")
    #expect(model.colorRuns == [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.greenIndex)])
  }

  @Test func aSyncWithTheSameTextAndNewRunsReplacesTheRuns() {
    let model = EditorModel.makeReadOnly("")
    model.syncReadOnly(to: "ab", colorRuns: [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.redIndex)])

    model.syncReadOnly(to: "ab", colorRuns: [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.greenIndex)])

    #expect(model.colorRuns == [ANSIFixtures.ansiRun(0..<2, ANSIFixtures.greenIndex)])
  }
}
