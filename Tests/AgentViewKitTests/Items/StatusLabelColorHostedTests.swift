#if DEBUG
  @testable import AgentViewKit
  @testable import AgentViewKitTestSupport
  import SwiftUI
  import Testing

  /// A status label of the kit that shows a succeeded state: a symbol in the
  /// status color, and a title (^sbx2q4h).
  ///
  /// The type is `nonisolated` because the arguments of a test use its cases.
  nonisolated enum SucceededStatusLabel: String, CaseIterable, Sendable, CustomTestStringConvertible {
    /// The "Sent" label of a user message.
    case sent

    /// The "Exit code 0" label of command output and terminal output.
    case exitCodeZero = "exit-code-zero"

    /// The accessibility identifier of the label.
    @MainActor var identifier: String {
      switch self {
      case .sent: UserMessageView.sendStateIdentifier(for: rawValue)
      case .exitCodeZero: CommandOutputView.footerIdentifier
      }
    }

    var testDescription: String {
      rawValue
    }

    /// The label, with ``identifier`` on its accessibility element.
    @MainActor var view: AnyView {
      switch self {
      case .sent:
        AnyView(UserMessageView.SendStateLabel(state: .sent).accessibilityIdentifier(identifier))
      case .exitCodeZero:
        AnyView(
          OutputExitLabel(
            text: "Exit code \(CommandOutputView.successExitCode)",
            symbolName: CommandOutputView.ExitOutcome.success.symbolName, outcome: .success,
            identifier: identifier))
      }
    }
  }

  /// The two parts of a status label in an image: the symbol, and the title
  /// after it.
  ///
  /// The symbol is the first run of columns of the label that hold ink: a
  /// pixel that differs from the background of its column. The title is
  /// each column after the gap that ends that run.
  struct StatusLabelParts {
    /// The smallest contrast of a column with ink: the contrast of its ink
    /// pixel with the most common color of the column.
    static let inkContrast = 1.05

    /// The frame of the symbol, in points from the top leading corner of the
    /// image.
    let symbol: CGRect

    /// The frame of the title, in points from the top leading corner of the
    /// image.
    let title: CGRect

    /// Finds the parts of the label in `frame` of `pixels`.
    ///
    /// - Parameters:
    ///   - pixels: The image.
    ///   - frame: The frame of the label, in points from the top leading
    ///     corner of the image.
    /// - Returns: `nil` when the label holds no ink, or no ink after the
    ///   first run.
    init?(of pixels: RenderedPixels, in frame: CGRect) {
      let columns = RegionColors.columns(of: pixels, in: frame)
      let inked = columns.map { column in
        (RegionColors(of: pixels, in: column)?.contrast ?? 1) > Self.inkContrast
      }
      guard let start = inked.firstIndex(of: true),
        let gap = inked[start...].firstIndex(of: false),
        inked[gap...].contains(true)
      else { return nil }
      symbol = columns[start].union(columns[gap - 1])
      title = CGRect(x: columns[gap].minX, y: frame.minY, width: frame.maxX - columns[gap].minX, height: frame.height)
    }
  }

  /// Hosted tests of the colors of the status labels "Sent" and "Exit code 0"
  /// (^sbx2q4h).
  ///
  /// The status color belongs to the symbol only. The title takes a readable
  /// style, so that it contrasts with the window background as body text
  /// must. Each test reads the image of path A of ``ViewSnapshot``.
  @Suite(.serialized, .hostedSerially) @MainActor struct StatusLabelColorHostedTests {
    /// The size of each image, in points.
    static let size = CGSize(width: 320, height: 60)

    /// The image and the parts of `label` in `variant`, with the status
    /// color that the label draws in `variant`.
    ///
    /// - Parameters:
    ///   - label: The label to show.
    ///   - variant: The settings of the image.
    /// - Returns: The image, the parts of the label, and the succeeded color
    ///   of the default EditorKit theme in the color scheme of `variant`.
    /// - Throws: An issue when the image, the element or a part is missing.
    static func render(_ label: SucceededStatusLabel, in variant: SnapshotVariant) throws -> (
      pixels: RenderedPixels, parts: StatusLabelParts, succeeded: Color
    ) {
      let harness = ViewSnapshot.makeHarness(of: label.view, size: size, variant: variant)
      defer { harness.close() }
      harness.render()
      let pixels = try #require(ViewSnapshot.pixels(of: harness))
      let frame = try #require(harness.frame(identifier: label.identifier), "No element \(label.identifier).")
      let region = ThreadBarControlJumpHostedTests.windowSpaceFrame(of: frame, in: harness.window)
      let parts = try #require(StatusLabelParts(of: pixels, in: region), "No symbol and title in \(region).")
      return (pixels, parts, EditorThemeViewsTests.defaultThemeSucceeded(in: variant.colorScheme))
    }

    @Test(arguments: SucceededStatusLabel.allCases, [SnapshotVariant.light, .dark])
    func theSymbolHasTheStatusColor(label: SucceededStatusLabel, variant: SnapshotVariant) throws {
      let (pixels, parts, succeeded) = try Self.render(label, in: variant)

      let symbolHasTheColor = RegionColors.contains(succeeded, in: parts.symbol, of: pixels)
      #expect(symbolHasTheColor, "\(parts.symbol)")
    }

    @Test(arguments: SucceededStatusLabel.allCases, [SnapshotVariant.light, .dark])
    func theTitleDoesNotHaveTheStatusColor(label: SucceededStatusLabel, variant: SnapshotVariant) throws {
      let (pixels, parts, succeeded) = try Self.render(label, in: variant)

      let titleHasTheColor = RegionColors.contains(succeeded, in: parts.title, of: pixels)
      #expect(!titleHasTheColor, "\(parts.title)")
    }

    @Test(arguments: SucceededStatusLabel.allCases, [SnapshotVariant.light, .dark])
    func theTitleIsReadable(label: SucceededStatusLabel, variant: SnapshotVariant) throws {
      let (pixels, parts, _) = try Self.render(label, in: variant)

      let colors = try #require(RegionColors(of: pixels, in: parts.title))
      #expect(colors.contrast >= CompositedSnapshotTests.minimumTextContrast, "\(colors)")
    }
  }
#endif
