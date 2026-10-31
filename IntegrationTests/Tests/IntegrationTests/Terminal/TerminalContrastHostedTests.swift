@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import EditorTestSupport
import EditorTheme
import SwiftUI
import Testing

/// Hosted tests of the contrast of the ANSI grays in terminal output
/// (^4rck1pf).
///
/// Under the default EditorKit theme, the terminal palette sets no
/// background, so the frame of terminal output has no fill and the window
/// background shows through. The ANSI black and white colors (SGR 30, 90, 37
/// and 97, and the fills 40, 100, 47 and 107) must then contrast with that
/// window background in each appearance. A theme that sets a terminal
/// background keeps its fill and its own palette.
///
/// Each test mounts a ``CommandOutputView`` in the hidden window of
/// ``HostedViewHarness``, reads the color runs that the editor gets, and
/// resolves each run color as the editor paints it: as an `NSColor`, in the
/// appearance of the window.
@Suite(.serialized, .hostedSerially) @MainActor struct TerminalContrastHostedTests {
  /// The appearances of the tests: Light and Dark only (EditorKit `style.md`
  /// rule 9).
  nonisolated static let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]

  /// The command in the header.
  static let command = "ls"

  /// The output with one character in each ANSI gray as a text color: black
  /// (SGR 30), bright black (90), white (37) and bright white (97).
  static let grayText = ["30", "90", "37", "97"]
    .map { "\(ANSIFixtures.escape)[\($0)mx" }.joined()

  /// The output with one character on each ANSI gray as a fill: black
  /// (SGR 40), bright black (100), white (47) and bright white (107).
  static let grayFills = ["40", "100", "47", "107"]
    .map { "\(ANSIFixtures.escape)[\($0)mx" }.joined()

  /// The number of ANSI grays in ``grayText`` and ``grayFills``.
  static let grayCount = 4

  /// The ANSI color numbers of the grays, in the order of ``grayText`` and
  /// ``grayFills``.
  static let grayIndices = [
    TerminalPalette.Entry.black, .brightBlack, .white, .brightWhite,
  ].map(\.rawValue)

  /// The smallest contrast ratio that text must have with the color behind
  /// it: the WCAG minimum for large text and for the parts of a control.
  static let minimumTextContrast = 3.0

  /// The smallest contrast ratio that a fill must have with the window
  /// background, so that a reader can see where the fill is.
  static let minimumFillContrast = 1.1

  /// Mounts command output with `output` in a window with the appearance
  /// `appearance`, and gives the color runs of its editor.
  ///
  /// - Parameters:
  ///   - output: The output, with its escape sequences.
  ///   - appearance: The appearance of the window.
  ///   - theme: The EditorKit theme. The default is the theme of an
  ///     environment that sets none.
  /// - Returns: The color runs and the appearance that the window resolves.
  static func colorRuns(
    of output: String, in appearance: NSAppearance.Name,
    theme: any Theme = EnvironmentValues().editorTheme
  ) -> (runs: [EditorColorRun], appearance: NSAppearance) {
    let model = EditorModel("")
    let harness = HostedViewHarness(
      CommandOutputView(command: command, output: output, exitCode: nil, model: model)
        .editorTheme(theme))
    defer { harness.close() }
    harness.window.appearance = NSAppearance(named: appearance)
    harness.render()
    return (model.colorRuns, harness.window.effectiveAppearance)
  }

  @Test(arguments: appearances)
  func underTheDefaultThemeEachGrayTextContrastsWithTheWindowBackground(
    appearance: NSAppearance.Name
  ) throws {
    let (runs, resolved) = Self.colorRuns(of: Self.grayText, in: appearance)

    let window = ResolvedColor(.windowBackgroundColor, in: resolved)
    for run in try Self.runs(of: runs, coveringEachGrayOf: Self.grayCount) {
      let text = try ResolvedColor(NSColor(#require(run.foreground)), in: resolved)
      #expect(text.over(window).contrast(with: window) >= Self.minimumTextContrast, "\(run.range)")
    }
  }

  /// The run that covers each one-byte gray character of the output, in
  /// order. Two grays with the same color can share one run.
  ///
  /// - Parameters:
  ///   - runs: The color runs of the editor.
  ///   - count: The number of gray characters at the start of the text.
  /// - Returns: One run for each gray character.
  /// - Throws: An error when a gray character has no run.
  static func runs(of runs: [EditorColorRun], coveringEachGrayOf count: Int) throws
    -> [EditorColorRun]
  {
    try (0..<count).map { offset in
      try #require(runs.first { $0.range.contains(offset) }, "gray \(offset)")
    }
  }

  @Test(arguments: appearances)
  func underTheDefaultThemeEachGrayFillShowsAndKeepsItsTextLegible(
    appearance: NSAppearance.Name
  ) throws {
    let (runs, resolved) = Self.colorRuns(of: Self.grayFills, in: appearance)

    let window = ResolvedColor(.windowBackgroundColor, in: resolved)
    for run in try Self.runs(of: runs, coveringEachGrayOf: Self.grayCount) {
      let fill = try ResolvedColor(NSColor(#require(run.background)), in: resolved).over(window)
      let text = try ResolvedColor(NSColor(#require(run.foreground)), in: resolved).over(fill)
      #expect(fill.contrast(with: window) >= Self.minimumFillContrast, "\(run.range)")
      #expect(text.contrast(with: fill) >= Self.minimumTextContrast, "\(run.range)")
    }
  }

  @Test func aThemeWithATerminalBackgroundKeepsItsGrayTextColors() {
    let (runs, _) = Self.colorRuns(of: Self.grayText, in: .aqua, theme: DistinctRolesTheme())

    #expect(
      runs
        == Self.grayIndices.enumerated().map { offset, index in
          ANSIFixtures.ansiRun(offset..<(offset + 1), index)
        })
    #expect(runs.allSatisfy { $0.background == nil })
  }

  @Test func aThemeWithATerminalBackgroundKeepsItsGrayFills() {
    let palette = ANSIFixtures.palette
    let (runs, _) = Self.colorRuns(of: Self.grayFills, in: .aqua, theme: DistinctRolesTheme())

    #expect(
      runs
        == Self.grayIndices.enumerated().map { offset, index in
          EditorColorRun(
            range: offset..<(offset + 1), foreground: palette[.foreground],
            background: palette.ansiColor(index))
        })
  }
}

/// An sRGB color with its opacity, resolved in one appearance, for the
/// contrast checks of ``TerminalContrastHostedTests``.
struct ResolvedColor {
  /// The red channel, from 0 to 1.
  let red: Double
  /// The green channel, from 0 to 1.
  let green: Double
  /// The blue channel, from 0 to 1.
  let blue: Double
  /// The opacity, from 0 to 1.
  let alpha: Double

  /// The WCAG constants of the relative luminance of an sRGB color.
  private enum Luminance {
    /// The red weight.
    static let red = 0.2126
    /// The green weight.
    static let green = 0.7152
    /// The blue weight.
    static let blue = 0.0722
    /// The channel value at and below which the sRGB curve is linear.
    static let linearLimit = 0.04045
    /// The divisor of the linear part of the curve.
    static let linearDivisor = 12.92
    /// The offset of the power part of the curve.
    static let offset = 0.055
    /// The divisor of the power part of the curve.
    static let divisor = 1.055
    /// The exponent of the power part of the curve.
    static let exponent = 2.4
    /// The flare that the WCAG contrast ratio adds to each luminance.
    static let flare = 0.05
  }

  /// Resolves `color` in `appearance`.
  ///
  /// - Parameters:
  ///   - color: The color, which can be a dynamic system color.
  ///   - appearance: The appearance to resolve it in.
  init(_ color: NSColor, in appearance: NSAppearance) {
    var resolved = color
    appearance.performAsCurrentDrawingAppearance {
      resolved = color.usingColorSpace(.sRGB) ?? color
    }
    self.init(
      red: Double(resolved.redComponent), green: Double(resolved.greenComponent),
      blue: Double(resolved.blueComponent), alpha: Double(resolved.alphaComponent))
  }

  /// Makes a color from its channels.
  ///
  /// - Parameters:
  ///   - red: The red channel.
  ///   - green: The green channel.
  ///   - blue: The blue channel.
  ///   - alpha: The opacity.
  init(red: Double, green: Double, blue: Double, alpha: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  /// This color drawn over `backdrop`, as an opaque color.
  ///
  /// - Parameter backdrop: The opaque color behind this color.
  /// - Returns: The opaque color that shows.
  func over(_ backdrop: ResolvedColor) -> ResolvedColor {
    func mix(_ top: Double, _ bottom: Double) -> Double { top * alpha + bottom * (1 - alpha) }
    return ResolvedColor(
      red: mix(red, backdrop.red), green: mix(green, backdrop.green),
      blue: mix(blue, backdrop.blue), alpha: 1)
  }

  /// The WCAG relative luminance of this opaque color.
  var luminance: Double {
    func linear(_ channel: Double) -> Double {
      channel <= Luminance.linearLimit
        ? channel / Luminance.linearDivisor
        : pow((channel + Luminance.offset) / Luminance.divisor, Luminance.exponent)
    }
    return Luminance.red * linear(red) + Luminance.green * linear(green)
      + Luminance.blue * linear(blue)
  }

  /// The WCAG contrast ratio of this opaque color and `other`, from 1 to 21.
  ///
  /// - Parameter other: The other opaque color.
  /// - Returns: The ratio of the lighter luminance to the darker one.
  func contrast(with other: ResolvedColor) -> Double {
    let lighter = max(luminance, other.luminance) + Luminance.flare
    let darker = min(luminance, other.luminance) + Luminance.flare
    return lighter / darker
  }
}
