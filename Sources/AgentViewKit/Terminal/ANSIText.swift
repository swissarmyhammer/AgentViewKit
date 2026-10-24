// Research R7: terminal output (plan.md §9 C, §14).
//
// Decision: the kit does not use a third-party ANSI or VT parser in v1. This
// file is a small parser that the kit owns, so there is no license to check
// and no new package dependency.
//
// - The parser decodes the bytes as UTF-8. A byte that is not valid UTF-8
//   becomes U+FFFD, the replacement character.
// - The parser applies the SGR sequences (`ESC [ ... m`) for the foreground
//   color, the background color, and bold. It knows the 16 ANSI colors, the
//   256-color palette (`38;5;n`), and direct color (`38;2;r;g;b`).
// - The 16 ANSI colors and the default foreground come from the terminal
//   palette of the EditorKit theme (`Theme.terminalPalette`). The kit keeps
//   no palette of its own. The 256-color cube, the gray ramp and direct
//   color are not in the terminal palette, so the parser computes them.
// - When the palette sets no terminal background, the parser paints the
//   four ANSI grays (black, bright black, white and bright white) with
//   label-relative system colors instead, so that they contrast with the
//   window that shows through the block (^4rck1pf). The text colors and the
//   fills of the grays differ. `TerminalPalette+Contrast.swift` holds the
//   mapping and its reasons.
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

import EditorTheme
import Foundation
import SwiftUI

/// Converts the output bytes of a terminal to attributed text (plan.md §9 C).
///
/// See the file header for the research R7 decision. ``TerminalView`` and
/// ``CommandOutputView`` show the characters of the result, and give its
/// colors to the editor as color runs.
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

  /// Converts the output bytes of a terminal to attributed text.
  ///
  /// - Parameters:
  ///   - data: The output bytes. Bytes that are not valid UTF-8 become
  ///     replacement characters.
  ///   - palette: The terminal palette of the EditorKit theme
  ///     (`Theme.terminalPalette`). The 16 ANSI colors and the default
  ///     foreground come from it. When it sets no terminal background, the
  ///     four ANSI grays come from `TerminalPalette.textColors` and
  ///     `TerminalPalette.fillColors` instead.
  /// - Returns: The text with the SGR styles as attributes, and with no
  ///   escape sequences. Each run has a SwiftUI `foregroundColor`: its SGR
  ///   color, or the palette foreground when no SGR color applies. A run
  ///   with an SGR background color has a SwiftUI `backgroundColor`. A run
  ///   with no SGR background has no background, so the background of the
  ///   view shows. A bold run has the `stronglyEmphasized` inline
  ///   presentation intent.
  public static func attributed(from data: Data, palette: TerminalPalette) -> AttributedString {
    attributed(from: String(decoding: data, as: UTF8.self), palette: palette)
  }

  /// Converts the output text of a terminal to attributed text.
  ///
  /// Use this function for text that is already decoded, such as the
  /// computed `text` of a `TerminalEntry` (plan.md §3.7 "Terminals"). The
  /// function does not decode bytes.
  ///
  /// - Parameters:
  ///   - text: The output text, with its escape sequences.
  ///   - palette: The terminal palette of the EditorKit theme.
  /// - Returns: The text with the SGR styles as attributes, and with no
  ///   escape sequences, as ``attributed(from:palette:)-(Data,_)`` gives it.
  public static func attributed(from text: String, palette: TerminalPalette) -> AttributedString {
    var parser = Parser(
      scalars: Array(text.unicodeScalars), textColors: palette.textColors,
      fillColors: palette.fillColors)
    parser.run()
    return parser.output.attributedString(defaultForeground: palette[.foreground])
  }

  /// The color of the 256-color palette at `index`.
  ///
  /// - Parameters:
  ///   - index: The palette index.
  ///   - palette: The terminal palette. Indices 0 to 15 are its ANSI colors.
  /// - Returns: The color, or `nil` when `index` is not from 0 to 255.
  static func paletteColor(_ index: Int, in palette: TerminalPalette) -> Color? {
    palette.ansiColor(index) ?? computedColor(index).map { Color($0) }
  }

  /// The color of the 256-color palette at `index`, for an index after the
  /// 16 ANSI colors: the 6 x 6 x 6 color cube and the gray ramp.
  ///
  /// - Parameter index: The palette index.
  /// - Returns: The color, or `nil` when `index` is not in the cube or the
  ///   gray ramp.
  static func computedColor(_ index: Int) -> RGB? {
    switch index {
    case Palette.cubeRange:
      let offset = index - Palette.cubeRange.lowerBound
      let side = Palette.cubeSide
      return RGB(
        red: Palette.cubeLevel(offset / (side * side)),
        green: Palette.cubeLevel((offset / side) % side),
        blue: Palette.cubeLevel(offset % side))
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
  /// The fixed values of the 256-color palette after the 16 ANSI colors.
  enum Palette {
    /// The largest value of an 8-bit channel.
    static let channelMaximum = 255.0
    /// The bit mask of an 8-bit channel.
    static let channelMask = 0xFF
    /// The indices of the 6 x 6 x 6 color cube.
    static let cubeRange = 16...231
    /// The number of levels on each side of the color cube.
    static let cubeSide = 6
    /// The channel level of the second cube level. The first level is zero.
    static let cubeBase = 55
    /// The channel difference between two cube levels after the first.
    static let cubeStep = 40

    /// The channel level of the color cube at `step`.
    ///
    /// - Parameter step: The level, from zero to ``cubeSide`` minus one.
    /// - Returns: The channel level.
    static func cubeLevel(_ step: Int) -> Int {
      step == 0 ? 0 : cubeBase + cubeStep * step
    }
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
    /// The ANSI color number of the first bright color.
    static let brightOffset = 8
    /// The mode of an extended color that gives a palette index.
    static let paletteMode = 5
    /// The mode of an extended color that gives three channels.
    static let directMode = 2
    /// The number of values after the palette mode: one index.
    static let paletteValueCount = 1
    /// The number of values after the direct mode: three channels.
    static let directValueCount = 3
    /// The number of values after each extended color mode, keyed by mode.
    static let valueCounts = [paletteMode: paletteValueCount, directMode: directValueCount]
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
    /// The SGR text color, or `nil` for the default foreground.
    var foreground: Color?
    /// The SGR background color, or `nil` for no background.
    var background: Color?
    /// Whether the run is bold.
    var isBold = false

    /// The SwiftUI attribute of the foreground color.
    typealias ForegroundKey = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
    /// The SwiftUI attribute of the background color.
    typealias BackgroundKey = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute

    /// The attributes of the style.
    ///
    /// - Parameter defaultForeground: The text color of a run with no SGR
    ///   text color: the foreground of the terminal palette.
    /// - Returns: The attributes.
    func attributes(defaultForeground: Color) -> AttributeContainer {
      var container = AttributeContainer()
      container[ForegroundKey.self] = foreground ?? defaultForeground
      if let background {
        container[BackgroundKey.self] = background
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
    ///
    /// - Parameter defaultForeground: The text color of a run with no SGR
    ///   text color.
    /// - Returns: The attributed text.
    func attributedString(defaultForeground: Color) -> AttributedString {
      var result = AttributedString()
      for run in runs where !run.text.isEmpty {
        result.append(
          AttributedString(
            String(run.text), attributes: run.style.attributes(defaultForeground: defaultForeground)))
      }
      return result
    }
  }

  /// The state of one parse.
  struct Parser {
    /// The decoded scalars.
    let scalars: [Unicode.Scalar]
    /// The terminal palette that gives the ANSI colors of the SGR text
    /// colors (`TerminalPalette.textColors`).
    let textColors: TerminalPalette
    /// The terminal palette that gives the ANSI colors of the SGR background
    /// colors (`TerminalPalette.fillColors`).
    let fillColors: TerminalPalette
    /// The index of the next scalar to read.
    var position = 0
    /// The current style.
    var style = Style()
    /// Whether a carriage return came after the last text.
    var pendingCarriageReturn = false
    /// The parsed runs.
    var output = Output()

    init(scalars: [Unicode.Scalar], textColors: TerminalPalette, fillColors: TerminalPalette) {
      self.scalars = scalars
      self.textColors = textColors
      self.fillColors = fillColors
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
          style.foreground = ansiColor(code, in: SGR.foreground, from: textColors)
        case SGR.brightForeground:
          style.foreground = ansiColor(
            code, in: SGR.brightForeground, offset: SGR.brightOffset, from: textColors)
        case SGR.defaultForeground:
          style.foreground = nil
        case SGR.background:
          style.background = ansiColor(code, in: SGR.background, from: fillColors)
        case SGR.brightBackground:
          style.background = ansiColor(
            code, in: SGR.brightBackground, offset: SGR.brightOffset, from: fillColors)
        case SGR.defaultBackground:
          style.background = nil
        case SGR.extendedForeground:
          if let color = extendedColor(codes, at: &index, in: textColors) { style.foreground = color }
        case SGR.extendedBackground:
          if let color = extendedColor(codes, at: &index, in: fillColors) { style.background = color }
        default:
          continue
        }
      }
    }

    /// The ANSI color of an SGR color code, from a terminal palette.
    ///
    /// - Parameters:
    ///   - code: The SGR code, in `range`.
    ///   - range: The codes of the eight colors of the code.
    ///   - offset: The ANSI color number of the first color of `range`.
    ///   - palette: ``textColors`` for a text color, or ``fillColors`` for a
    ///     background color.
    /// - Returns: The color.
    func ansiColor(
      _ code: Int, in range: ClosedRange<Int>, offset: Int = 0, from palette: TerminalPalette
    ) -> Color? {
      palette.ansiColor(code - range.lowerBound + offset)
    }

    /// Reads the color of an extended color code.
    ///
    /// - Parameters:
    ///   - codes: The SGR codes.
    ///   - index: The index of the mode after the `38` or `48` code. The
    ///     function moves it past the values that it reads.
    ///   - palette: The palette of the 16 ANSI colors: ``textColors`` for a
    ///     `38` code, or ``fillColors`` for a `48` code.
    /// - Returns: The color, or `nil` when the values are missing or not
    ///   valid.
    func extendedColor(_ codes: [Int], at index: inout Int, in palette: TerminalPalette) -> Color? {
      guard index < codes.endIndex else { return nil }
      let mode = codes[index]
      index += 1
      let count = SGR.valueCounts[mode] ?? 0
      guard count > 0, codes.endIndex - index >= count else {
        index = codes.endIndex
        return nil
      }
      let values = Array(codes[index..<(index + count)])
      index += count
      guard mode == SGR.directMode else {
        return values.first.flatMap { ANSIText.paletteColor($0, in: palette) }
      }
      let channels = 0...Palette.channelMask
      guard values.allSatisfy(channels.contains), let red = values.first, let blue = values.last,
        let green = values.dropFirst().first
      else { return nil }
      return Color(RGB(red: red, green: green, blue: blue))
    }
  }
}
