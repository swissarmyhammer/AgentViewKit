#if DEBUG
  @testable import AgentViewKit
  import EditorTestSupport
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

  /// The two parts of a status label in a capture: the symbol, and the title
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

    /// Finds the parts of the label in `frame` of `image`.
    ///
    /// - Parameters:
    ///   - image: The capture.
    ///   - frame: The frame of the label, in points from the top leading
    ///     corner of the image.
    /// - Returns: `nil` when the label holds no ink, or no ink after the
    ///   first run.
    /// - Throws: A `CapturedImageError` when a column cannot be read.
    init?(of image: CapturedImage, in frame: CGRect) throws {
      let columns = RegionColors.columns(of: image, in: frame)
      let inked = try columns.map { column in
        (try RegionColors(of: image, in: column)?.contrast ?? 1) > Self.inkContrast
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
  /// must. Each test reads a capture of the label in a real window
  /// (``CaptureMount``).
  @Suite(.serialized, .hostedSerially) @MainActor struct StatusLabelColorHostedTests {
    /// The size of each image, in points.
    static let size = CGSize(width: 320, height: 60)

    /// The capture and the parts of `label` in `look`, with the status color
    /// that the label draws in `look`.
    ///
    /// - Parameters:
    ///   - label: The label to show.
    ///   - look: The look of the window.
    /// - Returns: The capture, the parts of the label, and the succeeded color
    ///   of the default EditorKit theme in the color scheme of `look`.
    /// - Throws: An issue when the element or a part is missing, or the error
    ///   of the capture.
    static func capture(_ label: SucceededStatusLabel, in look: ReviewAppearance) async throws -> (
      image: CapturedImage, parts: StatusLabelParts, succeeded: CGColor
    ) {
      let region = try CaptureMount.windowFrame(of: label.identifier, in: label.view, size: size)
      let image = try await CaptureMount.capture(label.view, size: size, appearance: look)
      let parts = try #require(try StatusLabelParts(of: image, in: region), "No symbol and title in \(region).")
      let scheme: ColorScheme = look == .dark ? .dark : .light
      return (image, parts, CaptureGeometry.cgColor(of: EditorThemeViewsTests.defaultThemeSucceeded(in: scheme)))
    }

    @Test(arguments: SucceededStatusLabel.allCases, ReviewAppearance.allCases)
    func theSymbolHasTheStatusColor(label: SucceededStatusLabel, look: ReviewAppearance) async throws {
      let (image, parts, succeeded) = try await Self.capture(label, in: look)

      let symbolHasTheColor = try RegionColors.contains(succeeded, in: parts.symbol, of: image)
      #expect(symbolHasTheColor, "\(parts.symbol)")
    }

    @Test(arguments: SucceededStatusLabel.allCases, ReviewAppearance.allCases)
    func theTitleDoesNotHaveTheStatusColor(label: SucceededStatusLabel, look: ReviewAppearance) async throws {
      let (image, parts, succeeded) = try await Self.capture(label, in: look)

      let titleHasTheColor = try RegionColors.contains(succeeded, in: parts.title, of: image)
      #expect(!titleHasTheColor, "\(parts.title)")
    }

    @Test(arguments: SucceededStatusLabel.allCases, ReviewAppearance.allCases)
    func theTitleIsReadable(label: SucceededStatusLabel, look: ReviewAppearance) async throws {
      let (image, parts, _) = try await Self.capture(label, in: look)

      let colors = try #require(try RegionColors(of: image, in: parts.title))
      #expect(colors.contrast >= CompositedSnapshotTests.minimumTextContrast, "\(colors)")
    }
  }
#endif
