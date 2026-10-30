#if DEBUG
  @testable import AgentViewKit
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// A view that a real window shows with Liquid Glass and vibrancy
  /// (^zbcys18), with the identifier of the element whose text the checks
  /// read.
  ///
  /// The type is `nonisolated` because the arguments of a test use its cases.
  nonisolated enum CompositedProbe: CaseIterable, Sendable, CustomTestStringConvertible {
    /// A `List` in the sidebar of a `NavigationSplitView`: vibrant row text on
    /// the glass of the sidebar.
    case sidebarList

    /// A grouped `Form` in a SwiftUI inspector: vibrant row text on the glass
    /// of the inspector.
    case inspectorForm

    /// A `.glass` button: a vibrant label on its own glass.
    case glassButton

    /// The identifier of the element whose text the checks read.
    var identifier: String {
      switch self {
      case .sidebarList: "composited-sidebar-row"
      case .inspectorForm: "composited-inspector-row"
      case .glassButton: "composited-glass-button"
      }
    }

    var testDescription: String {
      identifier
    }

    /// The view of the probe, with the identifier on the element to read.
    @MainActor var view: AnyView {
      switch self {
      case .sidebarList:
        AnyView(
          NavigationSplitView {
            List { Text("Row").accessibilityIdentifier(identifier) }
          } detail: {
            Text("Detail")
          })
      case .inspectorForm:
        AnyView(
          Color.clear.inspector(isPresented: .constant(true)) {
            Form { Section { Text("Name").accessibilityIdentifier(identifier) } }.formStyle(.grouped)
          })
      case .glassButton:
        AnyView(Button("Show Error") {}.buttonStyle(.glass).accessibilityIdentifier(identifier))
      }
    }
  }

  /// Tests of the text and the glyphs on Liquid Glass as the window server
  /// composites a real window (^zbcys18): vibrancy, the glass of a sidebar and
  /// of an inspector, and the controls that only the window server draws.
  ///
  /// Each test captures the view in a ``CaptureMount``, and reads the region
  /// of one element: its frame in the accessibility tree of the same view at
  /// the same size (``CaptureMount/windowFrame(of:in:size:)``).
  @Suite(.serialized, .hostedSerially) @MainActor struct CompositedSnapshotTests {
    /// The size of each probe image, in points.
    static let size = CGSize(width: 400, height: 300)

    /// The least WCAG contrast of text with its background (WCAG 1.4.3).
    static let minimumTextContrast = 4.5

    /// The least WCAG contrast of a glyph of a control with its background
    /// (WCAG 1.4.11).
    static let minimumGlyphContrast = 3.0

    /// The largest relative luminance of the background of a region that a
    /// person reads as dark. The dark window background is about 0.015, and
    /// the light one is 1.
    static let darkLuminance = 0.05

    /// The colors of the element with `identifier` in a capture of `view` in
    /// `look`.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the element.
    ///   - view: The view to show.
    ///   - size: The size of the image, in points.
    ///   - look: The look of the window.
    /// - Returns: The colors of the frame of the element.
    /// - Throws: An issue when the element is missing, or the error of the
    ///   capture.
    static func colors<Content: View>(
      of identifier: String, in view: Content, size: CGSize = size, look: ReviewAppearance
    ) async throws -> RegionColors {
      let region = try CaptureMount.windowFrame(of: identifier, in: view, size: size)
      let image = try await CaptureMount.capture(view, size: size, appearance: look)
      return try #require(try RegionColors(of: image, in: region))
    }

    @Test(arguments: CompositedProbe.allCases, ReviewAppearance.allCases)
    func theTextOnGlassIsReadable(probe: CompositedProbe, look: ReviewAppearance) async throws {
      let colors = try await Self.colors(of: probe.identifier, in: probe.view, look: look)

      #expect(colors.contrast >= Self.minimumTextContrast, "\(colors)")
    }

    @Test(arguments: [CompositedProbe.sidebarList, .inspectorForm])
    func theDarkTextOnGlassIsLightOnADarkBackground(probe: CompositedProbe) async throws {
      let colors = try await Self.colors(of: probe.identifier, in: probe.view, look: .dark)

      #expect(colors.background.luminance <= Self.darkLuminance, "\(colors)")
      #expect(colors.ink.luminance > colors.background.luminance, "\(colors)")
    }

    @Test(arguments: ReviewAppearance.allCases)
    func theComposerShowsTheGlyphOfTheMicAndSendButtons(look: ReviewAppearance) async throws {
      for identifier in [SpeechInputButton.identifier, DefaultPromptAccessory.submitIdentifier] {
        let colors = try await Self.colors(
          of: identifier, in: ReviewGalleryFixtures.deckThread, size: ReviewGalleryFixtures.threadSize, look: look)

        #expect(colors.contrast >= Self.minimumGlyphContrast, "\(identifier): \(colors)")
      }
    }

    /// A real window shows Liquid Glass: the glass changes the backdrop at the
    /// center of the window, and with no glass the center shows the backdrop.
    @Test func aRealWindowShowsLiquidGlass() async throws {
      let size = GlassRenderProbeTests.size
      let center = CaptureGeometry.pixel(at: CGPoint(x: size.width / 2, y: size.height / 2))
      let backdrop = CaptureGeometry.cgColor(of: GlassRenderProbeTests.backdrop)

      let withGlass = try await CaptureMount.capture(GlassOverBackdrop(glass: .regular), size: size)
      let withoutGlass = try await CaptureMount.capture(GlassOverBackdrop(glass: nil), size: size)

      #expect(try withoutGlass.shows(backdrop, atX: center.x, y: center.y))
      #expect(try !withGlass.shows(backdrop, atX: center.x, y: center.y))
    }
  }
#endif
