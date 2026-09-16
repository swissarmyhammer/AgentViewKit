import AgentViewKit
import Foundation
import SwiftUI
import Testing

@Suite struct ANSITextTests {
  /// The escape character that starts each control sequence.
  static let escape = "\u{1B}"
  /// The index of red in the standard palette.
  static let redIndex = 1
  /// The index of green in the standard palette.
  static let greenIndex = 2
  /// The index of blue in the standard palette.
  static let blueIndex = 4
  /// The index of bright red in the standard palette.
  static let brightRedIndex = 9
  /// The index of a color in the 6 x 6 x 6 cube of the 256-color palette.
  static let cubeIndex = 196
  /// The index of a gray in the gray ramp of the 256-color palette.
  static let grayIndex = 244
  /// The level of each channel in the direct color test.
  static let directRed = 10
  static let directGreen = 20
  static let directBlue = 30

  /// The attributed text of `text` as UTF-8 bytes.
  ///
  /// - Parameter text: The terminal text.
  /// - Returns: The attributed text.
  static func attributed(_ text: String) -> AttributedString {
    ANSIText.attributed(from: Data(text.utf8))
  }

  /// The styles of one run.
  struct RunStyle {
    /// The SwiftUI foreground color of the run.
    let foregroundColor: Color?
    /// The SwiftUI background color of the run.
    let backgroundColor: Color?
    /// The inline presentation intent of the run.
    let inlinePresentationIntent: InlinePresentationIntent?
  }

  /// The runs of `text`, as pairs of the run text and the run styles.
  ///
  /// - Parameter text: The attributed text.
  /// - Returns: The pairs, in order.
  static func runs(_ text: AttributedString) -> [(String, RunStyle)] {
    text.runs.map { run in
      let characters = String(text[run.range].characters)
      let style = RunStyle(
        foregroundColor: run.attributes[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self],
        backgroundColor: run.attributes[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self],
        inlinePresentationIntent: run.inlinePresentationIntent)
      return (characters, style)
    }
  }

  // MARK: - SGR

  @Test func redTextIsRed() throws {
    let text = Self.attributed("\(Self.escape)[31mred\(Self.escape)[0m")

    #expect(String(text.characters) == "red")
    let run = try #require(Self.runs(text).first?.1)
    #expect(run.foregroundColor == ANSIText.standardColors[Self.redIndex])
    #expect(run.foregroundColor == Color(ANSIText.RGB(red: 205, green: 49, blue: 49)))
  }

  @Test func resetEndsTheColor() {
    let text = Self.attributed("\(Self.escape)[31mred\(Self.escape)[0m plain")
    let runs = Self.runs(text)

    #expect(runs.map(\.0) == ["red", " plain"])
    #expect(runs.last?.1.foregroundColor == nil)
  }

  @Test func anEmptySGRIsAReset() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[32mgo\(Self.escape)[m stop"))

    #expect(runs.map(\.0) == ["go", " stop"])
    #expect(runs.first?.1.foregroundColor == ANSIText.standardColors[Self.greenIndex])
    #expect(runs.last?.1.foregroundColor == nil)
  }

  @Test func boldSetsTheStrongIntent() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[1mbold\(Self.escape)[22mnormal"))

    #expect(runs.map(\.0) == ["bold", "normal"])
    #expect(runs.first?.1.inlinePresentationIntent == .stronglyEmphasized)
    #expect(runs.last?.1.inlinePresentationIntent == nil)
  }

  @Test func oneSequenceSetsBoldAndAColor() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[1;34mboth"))

    #expect(runs.first?.1.inlinePresentationIntent == .stronglyEmphasized)
    #expect(runs.first?.1.foregroundColor == ANSIText.standardColors[Self.blueIndex])
  }

  @Test func brightAndBackgroundColors() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[91;42mx\(Self.escape)[39;49my"))

    #expect(runs.first?.1.foregroundColor == ANSIText.standardColors[Self.brightRedIndex])
    #expect(runs.first?.1.backgroundColor == ANSIText.standardColors[Self.greenIndex])
    #expect(runs.last?.1.foregroundColor == nil)
    #expect(runs.last?.1.backgroundColor == nil)
  }

  @Test func the256ColorPalette() {
    let runs = Self.runs(
      Self.attributed(
        "\(Self.escape)[38;5;\(Self.redIndex)ma\(Self.escape)[38;5;\(Self.cubeIndex)mb"
          + "\(Self.escape)[38;5;\(Self.grayIndex)mc"))

    #expect(runs.map(\.0) == ["a", "b", "c"])
    #expect(runs[0].1.foregroundColor == ANSIText.standardColors[Self.redIndex])
    #expect(runs[1].1.foregroundColor == Color(ANSIText.RGB(red: 255, green: 0, blue: 0)))
    #expect(runs[2].1.foregroundColor == Color(ANSIText.RGB(red: 128, green: 128, blue: 128)))
  }

  @Test func directColor() {
    let runs = Self.runs(
      Self.attributed(
        "\(Self.escape)[48;2;\(Self.directRed);\(Self.directGreen);\(Self.directBlue)mz"))

    #expect(
      runs.first?.1.backgroundColor
        == Color(
          ANSIText.RGB(red: Self.directRed, green: Self.directGreen, blue: Self.directBlue)))
  }

  @Test func anExtendedColorWithMissingValuesIsIgnored() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[38;5mx\(Self.escape)[38;2;1my"))

    #expect(runs.map(\.0) == ["xy"])
    #expect(runs.first?.1.foregroundColor == nil)
  }

  @Test func unknownSGRCodesKeepTheStyle() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[31;4;7mx"))

    #expect(runs.first?.1.foregroundColor == ANSIText.standardColors[Self.redIndex])
  }

  @Test func thePaletteHasSixteenStandardColors() {
    #expect(ANSIText.standardColors.count == 16)
  }

  // MARK: - Strip

  @Test(arguments: [
    "\u{1B}[2J",  // clear screen
    "\u{1B}[H",  // cursor home
    "\u{1B}[10;20H",  // cursor position
    "\u{1B}[3A",  // cursor up
    "\u{1B}[?25l",  // hide cursor
    "\u{1B}[K",  // clear line
    "\u{1B}]0;title\u{07}",  // OSC with BEL
    "\u{1B}]8;;https://example.com\u{1B}\\",  // OSC with ST
    "\u{1B}P1$r\u{1B}\\",  // DCS
    "\u{1B}(B",  // character set
    "\u{1B}7",  // save cursor
    "\u{1B}=",  // keypad mode
    "\u{9B}2J",  // C1 CSI
    "\u{9D}0;title\u{07}",  // C1 OSC
    "\u{07}",  // bell
    "\u{08}",  // backspace
    "\u{1B}",  // escape at the end
  ])
  func aControlSequenceProducesNoText(sequence: String) {
    #expect(String(Self.attributed(sequence).characters) == "")
  }

  @Test func textAroundAStrippedSequenceStays() {
    let text = Self.attributed("a\(Self.escape)[5Cb\(Self.escape)]0;t\u{07}c")
    #expect(String(text.characters) == "abc")
  }

  @Test func anUnterminatedSequenceProducesNoText() {
    #expect(String(Self.attributed("ok\(Self.escape)[12").characters) == "ok")
    #expect(String(Self.attributed("ok\(Self.escape)]0;title").characters) == "ok")
  }

  @Test func newlinesAndTabsStay() {
    #expect(String(Self.attributed("a\tb\nc\r\nd").characters) == "a\tb\nc\nd")
  }

  @Test func aCarriageReturnOverwritesTheLine() {
    #expect(String(Self.attributed("first\n10%\r50%\r100%\ndone").characters) == "first\n100%\ndone")
  }

  @Test func aCarriageReturnRemovesStyledRunsOfTheLine() {
    let runs = Self.runs(Self.attributed("\(Self.escape)[31mold\(Self.escape)[0m\rnew"))

    #expect(runs.map(\.0) == ["new"])
    #expect(runs.first?.1.foregroundColor == nil)
  }

  @Test func aCarriageReturnAtTheEndKeepsTheLine() {
    #expect(String(Self.attributed("line\r").characters) == "line")
  }

  // MARK: - UTF-8

  @Test func invalidUTF8ShowsReplacementCharacters() {
    var data = Data("a".utf8)
    data.append(contentsOf: [0xFF, 0xFE])
    data.append(contentsOf: Data("b".utf8))

    let text = String(ANSIText.attributed(from: data).characters)

    #expect(text.hasPrefix("a"))
    #expect(text.hasSuffix("b"))
    #expect(text.contains("\u{FFFD}"))
  }

  @Test func aTruncatedMultibyteCharacterShowsAReplacementCharacter() {
    let euro = Data("€".utf8)
    let text = String(ANSIText.attributed(from: euro.dropLast()).characters)
    #expect(text == "\u{FFFD}")
  }

  @Test func emptyDataIsEmptyText() {
    #expect(ANSIText.attributed(from: Data()).characters.isEmpty)
  }

  @Test func multibyteTextStays() {
    #expect(String(Self.attributed("\(Self.escape)[35mé✓\(Self.escape)[0m").characters) == "é✓")
  }
}
