// Research R7: terminal output (plan.md §9 C, §14).
//
// Decision: the kit does not use a third-party ANSI or VT parser in v1. This
// file is a small parser that the kit owns, so there is no license to check
// and no new package dependency.
//
// - The parser decodes the bytes as UTF-8. A byte that is not valid UTF-8
//   becomes U+FFFD, the replacement character.
// - The parser applies the SGR sequences (`ESC [ ... m`) for the foreground
//   color, the background color, and bold. It knows the 16 standard colors,
//   the 256-color palette (`38;5;n`), and direct color (`38;2;r;g;b`).
// - The parser removes all other escape sequences and gives no text for them:
//   CSI sequences (cursor movement, clear), OSC, DCS, SOS, PM, APC, the
//   two-byte escapes, and the C1 forms of CSI and OSC.
// - The parser keeps a newline and a tab, and removes the other C0 controls.
//   A carriage return before a newline has no effect. A carriage return
//   before other text removes the current line, as a terminal that writes
//   over the line does. This keeps a progress bar on one line.
// - Rejected: a full VT emulator (a screen grid with cursor movement). Agent
//   terminals show command output, not full-screen programs. If a later task
//   needs full VT emulation, it replaces this file.
// - Rejected: a third-party parser package. The parser above is small, and a
//   new dependency needs a license check and a record in
//   Docs/decisions/dependencies.md.

import Foundation
import SwiftUI

/// Converts the output bytes of a terminal to attributed text (plan.md §9 C).
///
/// See the file header for the research R7 decision. ``TerminalView`` shows
/// the characters of the result.
public nonisolated enum ANSIText {
  /// A color as 8-bit red, green, and blue channels in the sRGB space.
  public struct RGB: Sendable, Hashable {
    /// The red channel, from 0 to 255.
    public var red: Int
    /// The green channel, from 0 to 255.
    public var green: Int
    /// The blue channel, from 0 to 255.
    public var blue: Int

    /// Makes a color.
    ///
    /// - Parameters:
    ///   - red: The red channel, from 0 to 255.
    ///   - green: The green channel, from 0 to 255.
    ///   - blue: The blue channel, from 0 to 255.
    public init(red: Int, green: Int, blue: Int) {
      self.red = red
      self.green = green
      self.blue = blue
    }
  }

  /// The 16 standard colors, in SGR order: the eight normal colors, then the
  /// eight bright colors.
  ///
  /// The values are the terminal palette of Visual Studio Code. They are
  /// easy to read on a light and on a dark background.
  public static let standardPalette: [RGB] = [
    RGB(red: 0, green: 0, blue: 0),
    RGB(red: 205, green: 49, blue: 49),
    RGB(red: 13, green: 188, blue: 121),
    RGB(red: 229, green: 229, blue: 16),
    RGB(red: 36, green: 114, blue: 200),
    RGB(red: 188, green: 63, blue: 188),
    RGB(red: 17, green: 168, blue: 205),
    RGB(red: 229, green: 229, blue: 229),
    RGB(red: 102, green: 102, blue: 102),
    RGB(red: 241, green: 76, blue: 76),
    RGB(red: 35, green: 209, blue: 139),
    RGB(red: 245, green: 245, blue: 67),
    RGB(red: 59, green: 142, blue: 234),
    RGB(red: 214, green: 112, blue: 214),
    RGB(red: 41, green: 184, blue: 219),
    RGB(red: 255, green: 255, blue: 255),
  ]

  /// The 16 standard colors as SwiftUI colors, in the order of
  /// ``standardPalette``.
  public static let standardColors: [Color] = standardPalette.map { Color($0) }

  /// Converts the output bytes of a terminal to attributed text.
  ///
  /// - Parameter data: The output bytes. Bytes that are not valid UTF-8
  ///   become replacement characters.
  /// - Returns: The text with the SGR styles as attributes, and with no
  ///   escape sequences. A colored run has a SwiftUI `foregroundColor` or
  ///   `backgroundColor`. A bold run has the `stronglyEmphasized` inline
  ///   presentation intent.
  public static func attributed(from data: Data) -> AttributedString {
    var parser = Parser(scalars: Array(String(decoding: data, as: UTF8.self).unicodeScalars))
    parser.run()
    return parser.output.attributedString
  }

  /// The color of the 256-color palette at `index`.
  ///
  /// - Parameter index: The palette index.
  /// - Returns: The color, or `nil` when `index` is not from 0 to 255.
  static func paletteColor(_ index: Int) -> RGB? {
    switch index {
    case standardPalette.indices:
      return standardPalette[index]
    case Palette.cubeRange:
      let offset = index - Palette.cubeRange.lowerBound
      let side = Palette.cubeLevels.count
      return RGB(
        red: Palette.cubeLevels[offset / (side * side)],
        green: Palette.cubeLevels[(offset / side) % side],
        blue: Palette.cubeLevels[offset % side])
    case Palette.grayRange:
      let level =
        Palette.grayStart + Palette.grayStep * (index - Palette.grayRange.lowerBound)
      return RGB(red: level, green: level, blue: level)
    default:
      return nil
    }
  }
}

extension Color {
  /// Makes a SwiftUI color from an 8-bit sRGB color.
  ///
  /// - Parameter rgb: The color.
  public nonisolated init(_ rgb: ANSIText.RGB) {
    self.init(
      .sRGB,
      red: Double(rgb.red) / ANSIText.Palette.channelMaximum,
      green: Double(rgb.green) / ANSIText.Palette.channelMaximum,
      blue: Double(rgb.blue) / ANSIText.Palette.channelMaximum)
  }
}

nonisolated extension ANSIText {
  /// The fixed values of the 256-color palette.
  enum Palette {
    /// The largest value of an 8-bit channel.
    static let channelMaximum = 255.0
    /// The indices of the 6 x 6 x 6 color cube.
    static let cubeRange = 16...231
    /// The channel levels of the color cube.
    static let cubeLevels = [0, 95, 135, 175, 215, 255]
    /// The indices of the gray ramp.
    static let grayRange = 232...255
    /// The channel level of the first gray.
    static let grayStart = 8
    /// The channel difference between two grays.
    static let grayStep = 10
  }

  /// The SGR codes that the parser knows.
  enum SGR {
    static let reset = 0
    static let bold = 1
    static let normalIntensity = 22
    static let foreground = 30...37
    static let extendedForeground = 38
    static let defaultForeground = 39
    static let background = 40...47
    static let extendedBackground = 48
    static let defaultBackground = 49
    static let brightForeground = 90...97
    static let brightBackground = 100...107
    /// The first index of the bright colors in ``ANSIText/standardPalette``.
    static let brightOffset = 8
    /// The mode of an extended color that gives a palette index.
    static let paletteMode = 5
    /// The mode of an extended color that gives three channels.
    static let directMode = 2
  }

  /// The scalars that the parser acts on.
  enum Scalar {
    static let escape: Unicode.Scalar = "\u{1B}"
    static let bell: Unicode.Scalar = "\u{07}"
    static let newline: Unicode.Scalar = "\n"
    static let tab: Unicode.Scalar = "\t"
    static let carriageReturn: Unicode.Scalar = "\r"
    static let delete: Unicode.Scalar = "\u{7F}"
    static let csiIntroducer: Unicode.Scalar = "["
    static let oscIntroducer: Unicode.Scalar = "]"
    static let stringTerminatorFinal: Unicode.Scalar = "\\"
    static let sgrFinal: Unicode.Scalar = "m"
    static let parameterSeparators: Set<Unicode.Scalar> = [";", ":"]
    /// The C1 form of the CSI introducer.
    static let c1CSI: Unicode.Scalar = "\u{9B}"
    /// The C1 form of the OSC introducer.
    static let c1OSC: Unicode.Scalar = "\u{9D}"
    /// The C1 string terminator.
    static let c1StringTerminator: Unicode.Scalar = "\u{9C}"
    /// The second scalars of the escapes that start a string that ends with
    /// a string terminator: DCS, SOS, PM, and APC.
    static let stringIntroducers: Set<Unicode.Scalar> = ["P", "X", "^", "_"]
    /// The C1 forms of DCS, SOS, PM, and APC.
    static let c1StringIntroducers: Set<Unicode.Scalar> = ["\u{90}", "\u{98}", "\u{9E}", "\u{9F}"]
    /// The C0 controls, below the space.
    static let c0Controls: ClosedRange<UInt32> = 0x00...0x1F
    /// The C1 controls.
    static let c1Controls: ClosedRange<UInt32> = 0x80...0x9F
    /// The intermediate bytes of an escape sequence.
    static let intermediates: ClosedRange<UInt32> = 0x20...0x2F
    /// The final bytes of a CSI sequence.
    static let csiFinals: ClosedRange<UInt32> = 0x40...0x7E
    /// The final bytes of a two-byte escape.
    static let escapeFinals: ClosedRange<UInt32> = 0x30...0x7E
  }

  /// The style of a run of text.
  struct Style: Equatable {
    var foreground: RGB?
    var background: RGB?
    var isBold = false

    /// The SwiftUI attribute of the foreground color.
    typealias ForegroundKey = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
    /// The SwiftUI attribute of the background color.
    typealias BackgroundKey = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute

    /// The attributes of the style.
    var attributes: AttributeContainer {
      var container = AttributeContainer()
      if let foreground {
        container[ForegroundKey.self] = Color(foreground)
      }
      if let background {
        container[BackgroundKey.self] = Color(background)
      }
      if isBold {
        container.inlinePresentationIntent = .stronglyEmphasized
      }
      return container
    }
  }

  /// A run of text with one style.
  struct Run {
    var text: String.UnicodeScalarView
    var style: Style
  }

  /// The runs of the parsed text.
  struct Output {
    private(set) var runs: [Run] = []

    /// Adds `scalar` at the end with `style`.
    mutating func append(_ scalar: Unicode.Scalar, style: Style) {
      if let last = runs.indices.last, runs[last].style == style {
        runs[last].text.append(scalar)
      } else {
        runs.append(Run(text: String.UnicodeScalarView([scalar]), style: style))
      }
    }

    /// Removes the text after the last newline.
    mutating func removeCurrentLine() {
      while let last = runs.indices.last {
        if let newline = runs[last].text.lastIndex(of: Scalar.newline) {
          runs[last].text.removeSubrange(runs[last].text.index(after: newline)...)
          return
        }
        runs.removeLast()
      }
    }

    /// The runs as attributed text.
    var attributedString: AttributedString {
      var result = AttributedString()
      for run in runs where !run.text.isEmpty {
        result.append(AttributedString(String(run.text), attributes: run.style.attributes))
      }
      return result
    }
  }

  /// The state of one parse.
  struct Parser {
    /// The decoded scalars.
    let scalars: [Unicode.Scalar]
    /// The index of the next scalar to read.
    var position = 0
    /// The current style.
    var style = Style()
    /// Whether a carriage return came after the last text.
    var pendingCarriageReturn = false
    /// The parsed runs.
    var output = Output()

    init(scalars: [Unicode.Scalar]) {
      self.scalars = scalars
    }

    /// The next scalar, or `nil` at the end.
    var next: Unicode.Scalar? {
      position < scalars.count ? scalars[position] : nil
    }

    /// Parses all scalars.
    mutating func run() {
      while let scalar = next {
        position += 1
        switch scalar {
        case Scalar.escape:
          readEscape()
        case Scalar.c1CSI:
          readCSI()
        case Scalar.c1OSC:
          skipString(endsWithBell: true)
        case _ where Scalar.c1StringIntroducers.contains(scalar):
          skipString(endsWithBell: false)
        case Scalar.newline:
          pendingCarriageReturn = false
          output.append(scalar, style: style)
        case Scalar.carriageReturn:
          pendingCarriageReturn = true
        case Scalar.tab:
          appendText(scalar)
        case _ where isControl(scalar):
          continue
        default:
          appendText(scalar)
        }
      }
    }

    /// Whether `scalar` is a control that gives no text.
    func isControl(_ scalar: Unicode.Scalar) -> Bool {
      Scalar.c0Controls.contains(scalar.value) || Scalar.c1Controls.contains(scalar.value)
        || scalar == Scalar.delete
    }

    /// Adds a text scalar. A pending carriage return first removes the line.
    mutating func appendText(_ scalar: Unicode.Scalar) {
      if pendingCarriageReturn {
        output.removeCurrentLine()
        pendingCarriageReturn = false
      }
      output.append(scalar, style: style)
    }

    /// Reads the escape sequence after an escape scalar.
    mutating func readEscape() {
      guard let introducer = next else { return }
      position += 1
      switch introducer {
      case Scalar.csiIntroducer:
        readCSI()
      case Scalar.oscIntroducer:
        skipString(endsWithBell: true)
      case _ where Scalar.stringIntroducers.contains(introducer):
        skipString(endsWithBell: false)
      case _ where Scalar.intermediates.contains(introducer.value):
        while let scalar = next, Scalar.intermediates.contains(scalar.value) {
          position += 1
        }
        if let scalar = next, Scalar.escapeFinals.contains(scalar.value) {
          position += 1
        }
      case _ where Scalar.escapeFinals.contains(introducer.value):
        return
      default:
        // A scalar that cannot end the escape is read again as text.
        position -= 1
      }
    }

    /// Reads a CSI sequence after its introducer, and applies it when it is
    /// an SGR sequence.
    mutating func readCSI() {
      var body = String.UnicodeScalarView()
      while let scalar = next {
        position += 1
        if Scalar.csiFinals.contains(scalar.value) {
          if scalar == Scalar.sgrFinal {
            applySGR(String(body))
          }
          return
        }
        body.append(scalar)
      }
    }

    /// Skips a control string up to its terminator.
    ///
    /// - Parameter endsWithBell: Whether a bell also ends the string, as it
    ///   does for OSC.
    mutating func skipString(endsWithBell: Bool) {
      while let scalar = next {
        position += 1
        if scalar == Scalar.c1StringTerminator || (endsWithBell && scalar == Scalar.bell) {
          return
        }
        if scalar == Scalar.escape, next == Scalar.stringTerminatorFinal {
          position += 1
          return
        }
      }
    }

    /// Applies the parameters of an SGR sequence to ``style``.
    ///
    /// - Parameter body: The parameter text between the introducer and `m`.
    mutating func applySGR(_ body: String) {
      let codes = body.unicodeScalars
        .split(omittingEmptySubsequences: false) { Scalar.parameterSeparators.contains($0) }
        .map { Int(String($0)) ?? SGR.reset }
      var index = codes.startIndex
      while index < codes.endIndex {
        let code = codes[index]
        index += 1
        switch code {
        case SGR.reset:
          style = Style()
        case SGR.bold:
          style.isBold = true
        case SGR.normalIntensity:
          style.isBold = false
        case SGR.foreground:
          style.foreground = Self.standardColor(code, in: SGR.foreground)
        case SGR.brightForeground:
          style.foreground = Self.standardColor(code, in: SGR.brightForeground, offset: SGR.brightOffset)
        case SGR.defaultForeground:
          style.foreground = nil
        case SGR.background:
          style.background = Self.standardColor(code, in: SGR.background)
        case SGR.brightBackground:
          style.background = Self.standardColor(code, in: SGR.brightBackground, offset: SGR.brightOffset)
        case SGR.defaultBackground:
          style.background = nil
        case SGR.extendedForeground:
          if let color = Self.extendedColor(codes, at: &index) { style.foreground = color }
        case SGR.extendedBackground:
          if let color = Self.extendedColor(codes, at: &index) { style.background = color }
        default:
          continue
        }
      }
    }

    /// The standard color of an SGR color code.
    ///
    /// - Parameters:
    ///   - code: The SGR code, in `range`.
    ///   - range: The codes of the eight colors of the code.
    ///   - offset: The palette index of the first color of `range`.
    /// - Returns: The color.
    static func standardColor(_ code: Int, in range: ClosedRange<Int>, offset: Int = 0) -> RGB {
      standardPalette[code - range.lowerBound + offset]
    }

    /// Reads the color of an extended color code.
    ///
    /// - Parameters:
    ///   - codes: The SGR codes.
    ///   - index: The index of the mode after the `38` or `48` code. The
    ///     function moves it past the values that it reads.
    /// - Returns: The color, or `nil` when the values are missing or not
    ///   valid.
    static func extendedColor(_ codes: [Int], at index: inout Int) -> RGB? {
      guard index < codes.endIndex else { return nil }
      let mode = codes[index]
      index += 1
      let count = mode == SGR.paletteMode ? 1 : mode == SGR.directMode ? 3 : 0
      guard count > 0, codes.endIndex - index >= count else {
        index = codes.endIndex
        return nil
      }
      let values = Array(codes[index..<(index + count)])
      index += count
      if mode == SGR.paletteMode {
        return paletteColor(values[0])
      }
      let channels = 0...Int(Palette.channelMaximum)
      guard values.allSatisfy(channels.contains) else { return nil }
      return RGB(red: values[0], green: values[1], blue: values[2])
    }
  }
}
