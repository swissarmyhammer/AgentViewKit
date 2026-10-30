import AgentViewKit
import AgentViewKitTestSupport
import EditorTheme
import Foundation
import SwiftUI
import Testing

/// Checks the parse of terminal output into attributed text. The escape
/// character, the palette and the shared ANSI color numbers come from
/// ``ANSIFixtures``.
@Suite struct ANSITextTests {
  /// The ANSI color number of blue.
  static let blueIndex = 4
  /// The ANSI color number of bright red.
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
    ANSIText.attributed(from: Data(text.utf8), palette: ANSIFixtures.palette)
  }

  /// The color of ANSI color `index` in ``ANSIFixtures/palette``.
  ///
  /// - Parameter index: The ANSI color number, from 0 to 15.
  /// - Returns: The color.
  static func ansiColor(_ index: Int) -> Color? {
    ANSIFixtures.palette.ansiColor(index)
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
    let escape = ANSIFixtures.escape
    let text = Self.attributed("\(escape)[31mred\(escape)[0m")

    #expect(String(text.characters) == "red")
    let run = try #require(Self.runs(text).first?.1)
    #expect(run.foregroundColor == Self.ansiColor(ANSIFixtures.redIndex))
  }

  @Test func resetGivesTheTerminalForeground() {
    let escape = ANSIFixtures.escape
    let text = Self.attributed("\(escape)[31mred\(escape)[0m plain")
    let runs = Self.runs(text)

    #expect(runs.map(\.0) == ["red", " plain"])
    #expect(runs.last?.1.foregroundColor == ANSIFixtures.palette[.foreground])
    #expect(runs.last?.1.backgroundColor == nil)
  }

  @Test func textWithNoSGRHasTheTerminalForeground() {
    let runs = Self.runs(Self.attributed("plain"))

    #expect(runs.first?.1.foregroundColor == ANSIFixtures.palette[.foreground])
  }

  @Test func theColorsComeFromThePaletteOfTheTheme() {
    let palette = ThemeRoleDefaults.terminalPalette
    let text = ANSIText.attributed(from: "\(ANSIFixtures.escape)[31mred", palette: palette)

    #expect(Self.runs(text).first?.1.foregroundColor == palette.ansiColor(ANSIFixtures.redIndex))
  }

  @Test func anEmptySGRIsAReset() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(Self.attributed("\(escape)[32mgo\(escape)[m stop"))

    #expect(runs.map(\.0) == ["go", " stop"])
    #expect(runs.first?.1.foregroundColor == Self.ansiColor(ANSIFixtures.greenIndex))
    #expect(runs.last?.1.foregroundColor == ANSIFixtures.palette[.foreground])
  }

  @Test func boldSetsTheStrongIntent() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(Self.attributed("\(escape)[1mbold\(escape)[22mnormal"))

    #expect(runs.map(\.0) == ["bold", "normal"])
    #expect(runs.first?.1.inlinePresentationIntent == .stronglyEmphasized)
    #expect(runs.last?.1.inlinePresentationIntent == nil)
  }

  @Test func oneSequenceSetsBoldAndAColor() {
    let runs = Self.runs(Self.attributed("\(ANSIFixtures.escape)[1;34mboth"))

    #expect(runs.first?.1.inlinePresentationIntent == .stronglyEmphasized)
    #expect(runs.first?.1.foregroundColor == Self.ansiColor(Self.blueIndex))
  }

  @Test func brightAndBackgroundColors() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(Self.attributed("\(escape)[91;42mx\(escape)[39;49my"))

    #expect(runs.first?.1.foregroundColor == Self.ansiColor(Self.brightRedIndex))
    #expect(runs.first?.1.backgroundColor == Self.ansiColor(ANSIFixtures.greenIndex))
    #expect(runs.last?.1.foregroundColor == ANSIFixtures.palette[.foreground])
    #expect(runs.last?.1.backgroundColor == nil)
  }

  @Test func the256ColorPalette() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(
      Self.attributed(
        "\(escape)[38;5;\(ANSIFixtures.redIndex)ma\(escape)[38;5;\(Self.cubeIndex)mb"
          + "\(escape)[38;5;\(Self.grayIndex)mc"))

    #expect(runs.map(\.0) == ["a", "b", "c"])
    #expect(runs[0].1.foregroundColor == Self.ansiColor(ANSIFixtures.redIndex))
    #expect(runs[1].1.foregroundColor == Color(ANSIText.RGB(red: 255, green: 0, blue: 0)))
    #expect(runs[2].1.foregroundColor == Color(ANSIText.RGB(red: 128, green: 128, blue: 128)))
  }

  @Test func directColor() {
    let runs = Self.runs(
      Self.attributed(
        "\(ANSIFixtures.escape)[48;2;\(Self.directRed);\(Self.directGreen);\(Self.directBlue)mz"))

    #expect(
      runs.first?.1.backgroundColor
        == Color(
          ANSIText.RGB(red: Self.directRed, green: Self.directGreen, blue: Self.directBlue)))
  }

  @Test func anExtendedColorWithMissingValuesIsIgnored() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(Self.attributed("\(escape)[38;5mx\(escape)[38;2;1my"))

    #expect(runs.map(\.0) == ["xy"])
    #expect(runs.first?.1.foregroundColor == ANSIFixtures.palette[.foreground])
  }

  @Test func unknownSGRCodesKeepTheStyle() {
    let runs = Self.runs(Self.attributed("\(ANSIFixtures.escape)[31;4;7mx"))

    #expect(runs.first?.1.foregroundColor == Self.ansiColor(ANSIFixtures.redIndex))
  }

  /// `TerminalEntry.text` is already decoded text, so the parser reads a
  /// string with no byte decode (plan.md §3.7 "Terminals").
  @Test func textThatIsAlreadyDecodedGivesTheSameRunsAsItsBytes() {
    let escape = ANSIFixtures.escape
    let text = "\(escape)[31mred\(escape)[0m plain"

    let fromText = ANSIText.attributed(from: text, palette: ANSIFixtures.palette)

    #expect(String(fromText.characters) == "red plain")
    #expect(fromText == Self.attributed(text))
  }

  // MARK: - Strip

  @Test(arguments: [
    "\(ANSIFixtures.escape)[2J",  // clear screen
    "\(ANSIFixtures.escape)[H",  // cursor home
    "\(ANSIFixtures.escape)[10;20H",  // cursor position
    "\(ANSIFixtures.escape)[3A",  // cursor up
    "\(ANSIFixtures.escape)[?25l",  // hide cursor
    "\(ANSIFixtures.escape)[K",  // clear line
    "\(ANSIFixtures.escape)]0;title\u{07}",  // OSC with BEL
    "\(ANSIFixtures.escape)]8;;https://example.com\(ANSIFixtures.escape)\\",  // OSC with ST
    "\(ANSIFixtures.escape)P1$r\(ANSIFixtures.escape)\\",  // DCS
    "\(ANSIFixtures.escape)(B",  // character set
    "\(ANSIFixtures.escape)7",  // save cursor
    "\(ANSIFixtures.escape)=",  // keypad mode
    "\u{9B}2J",  // C1 CSI
    "\u{9D}0;title\u{07}",  // C1 OSC
    "\u{07}",  // bell
    "\u{08}",  // backspace
    ANSIFixtures.escape,  // escape at the end
  ])
  func aControlSequenceProducesNoText(sequence: String) {
    #expect(String(Self.attributed(sequence).characters) == "")
  }

  @Test func textAroundAStrippedSequenceStays() {
    let escape = ANSIFixtures.escape
    let text = Self.attributed("a\(escape)[5Cb\(escape)]0;t\u{07}c")
    #expect(String(text.characters) == "abc")
  }

  @Test func anUnterminatedSequenceProducesNoText() {
    let escape = ANSIFixtures.escape
    #expect(String(Self.attributed("ok\(escape)[12").characters) == "ok")
    #expect(String(Self.attributed("ok\(escape)]0;title").characters) == "ok")
  }

  @Test func newlinesAndTabsStay() {
    #expect(String(Self.attributed("a\tb\nc\r\nd").characters) == "a\tb\nc\nd")
  }

  @Test func aCarriageReturnOverwritesTheLine() {
    #expect(String(Self.attributed("first\n10%\r50%\r100%\ndone").characters) == "first\n100%\ndone")
  }

  @Test func aCarriageReturnRemovesStyledRunsOfTheLine() {
    let escape = ANSIFixtures.escape
    let runs = Self.runs(Self.attributed("\(escape)[31mold\(escape)[0m\rnew"))

    #expect(runs.map(\.0) == ["new"])
    #expect(runs.first?.1.foregroundColor == ANSIFixtures.palette[.foreground])
  }

  @Test func aCarriageReturnAtTheEndKeepsTheLine() {
    #expect(String(Self.attributed("line\r").characters) == "line")
  }

  // MARK: - UTF-8

  @Test func invalidUTF8ShowsReplacementCharacters() {
    var data = Data("a".utf8)
    data.append(contentsOf: [0xFF, 0xFE])
    data.append(contentsOf: Data("b".utf8))

    let text = String(ANSIText.attributed(from: data, palette: ANSIFixtures.palette).characters)

    #expect(text.hasPrefix("a"))
    #expect(text.hasSuffix("b"))
    #expect(text.contains("\u{FFFD}"))
  }

  @Test func aTruncatedMultibyteCharacterShowsAReplacementCharacter() {
    let euro = Data("€".utf8)
    let text = String(
      ANSIText.attributed(from: euro.dropLast(), palette: ANSIFixtures.palette).characters)
    #expect(text == "\u{FFFD}")
  }

  @Test func emptyDataIsEmptyText() {
    #expect(ANSIText.attributed(from: Data(), palette: ANSIFixtures.palette).characters.isEmpty)
  }

  @Test func multibyteTextStays() {
    let escape = ANSIFixtures.escape
    #expect(String(Self.attributed("\(escape)[35mé✓\(escape)[0m").characters) == "é✓")
  }
}
