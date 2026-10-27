#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import SwiftUI
  import Testing

  /// A view that the composited image of path C of ``ViewSnapshot`` draws
  /// with Liquid Glass and vibrancy (^zbcys18), with the identifier of the
  /// element whose text the checks read.
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

  /// Tests for path C of ``ViewSnapshot``: the image that Core Animation
  /// composites for the hidden window, with Liquid Glass, vibrancy and the
  /// controls that only the render server draws (^zbcys18).
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

    /// The colors of the element with `identifier` in the composited image of
    /// `view` in `variant`.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the element.
    ///   - view: The view to show.
    ///   - size: The size of the image, in points.
    ///   - variant: The settings of the image.
    /// - Returns: The colors of the frame of the element.
    /// - Throws: An issue when the image or the element is missing.
    static func colors(
      of identifier: String, in view: some View, size: CGSize = size, variant: SnapshotVariant
    ) throws -> RegionColors {
      let harness = ViewSnapshot.makeHarness(of: view, size: size, variant: variant)
      defer { harness.close() }
      harness.render()
      let pixels = try #require(ViewSnapshot.compositedPixels(of: harness))
      let frame = try #require(harness.frame(identifier: identifier), "No element \(identifier).")
      let region = ThreadBarControlJumpHostedTests.windowSpaceFrame(of: frame, in: harness.window)
      return try #require(RegionColors(of: pixels, in: region))
    }

    @Test(arguments: CompositedProbe.allCases, [SnapshotVariant.light, .dark])
    func theTextOnGlassIsReadable(probe: CompositedProbe, variant: SnapshotVariant) throws {
      let colors = try Self.colors(of: probe.identifier, in: probe.view, variant: variant)

      #expect(colors.contrast >= Self.minimumTextContrast, "\(colors)")
    }

    @Test(arguments: [CompositedProbe.sidebarList, .inspectorForm])
    func theDarkTextOnGlassIsLightOnADarkBackground(probe: CompositedProbe) throws {
      let colors = try Self.colors(of: probe.identifier, in: probe.view, variant: .dark)

      #expect(colors.background.luminance <= Self.darkLuminance, "\(colors)")
      #expect(colors.ink.luminance > colors.background.luminance, "\(colors)")
    }

    @Test(arguments: [SnapshotVariant.light, .dark])
    func theComposerShowsTheGlyphOfTheMicAndSendButtons(variant: SnapshotVariant) throws {
      for identifier in [SpeechInputButton.identifier, DefaultPromptAccessory.submitIdentifier] {
        let colors = try Self.colors(
          of: identifier, in: ReviewGalleryFixtures.deckThread, size: ReviewGalleryFixtures.threadSize,
          variant: variant)

        #expect(colors.contrast >= Self.minimumGlyphContrast, "\(identifier): \(colors)")
      }
    }

    @Test func theCompositedImageShowsLiquidGlass() async throws {
      let bounds = CGRect(origin: .zero, size: GlassRenderProbeTests.size)
      let center = [CGPoint(x: bounds.midX, y: bounds.midY)]

      let withGlass = try #require(
        await ViewSnapshot.compositedPixels(of: GlassOverBackdrop(glass: .regular), size: bounds.size, variant: .light))
      let withoutGlass = try #require(
        await ViewSnapshot.compositedPixels(of: GlassOverBackdrop(glass: nil), size: bounds.size, variant: .light))

      #expect(!withGlass.isClose(to: withoutGlass, at: center))
    }

    @Test func aCompositedImageLeavesTheWindowAsItWas() throws {
      let harness = ViewSnapshot.makeHarness(of: CompositedProbe.sidebarList.view, size: Self.size, variant: .dark)
      defer { harness.close() }
      harness.render()
      let layer = try #require(harness.hostingView.layer)
      let superlayer = layer.superlayer
      let cachedBefore = try #require(ViewSnapshot.pixels(of: harness))

      let first = try #require(ViewSnapshot.compositedPixels(of: harness))
      let second = try #require(ViewSnapshot.compositedPixels(of: harness))

      #expect(first.changedPixelCount(comparedWith: second) == 0)
      #expect(layer.superlayer === superlayer)
      #expect(try #require(ViewSnapshot.pixels(of: harness)).changedPixelCount(comparedWith: cachedBefore) == 0)
    }
  }
#endif
