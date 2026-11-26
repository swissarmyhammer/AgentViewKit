#if DEBUG
  @testable import AgentViewKit
  import AppKit
  import EditorCommands
  import EditorStyle
  import EditorTestSupport
  import QuartzCore
  import SwiftUI
  import Testing

  @testable import EditorCommandsUI

  /// The focus ring of a button in a bar of a thread follows the bezel of the
  /// button (EditorKit style.md, "Selection and focus"), as the AppKit focus
  /// ring does.
  ///
  /// Each button of a bar is an EditorKit `EditorButton` in the focus scope of
  /// a bar control (`agentControlScope(_:corners:yieldsToHostScope:)`). The
  /// button tells the scope the shape of its bezel, and the scope draws its
  /// ring in that shape. The tests focus the scope with no press, and read
  /// state, never pixels: the shape that the button tells its scope, and the
  /// path of the layer that draws the band of the ring.
  @Suite(.serialized, .hostedSerially) @MainActor struct BarButtonFocusRingHostedTests {
    /// The bar controls that are EditorKit buttons with a bezel. The Remove
    /// button of an attachment chip is a bare button with no bezel, and the
    /// editor and the permission-mode picker are no buttons.
    nonisolated static let bezelButtons: [BarControl] = [
      .send, .stop, .signIn, .signOut, .dismiss, .reload, .showError, .dictation, .suggestion, .scrollPill,
    ]

    /// The floating glass actions (`floatingGlassAction(glassID:identifier:)`),
    /// whose bezel is a capsule.
    nonisolated static let floatingGlassActions: [BarControl] = [.suggestion, .scrollPill]

    /// The round buttons of the composer, whose bezel is a circle.
    nonisolated static let circleButtons: [BarControl] = [.send, .stop, .dictation]

    /// Shows a thread whose bars show `control`, and gives the focus to the
    /// scope of the control, with no press.
    ///
    /// - Parameters:
    ///   - control: The bar control.
    ///   - system: The command system of the window.
    /// - Returns: The shown control, after the render pass that draws the
    ///   ring.
    /// - Throws: The error of a scripted session, or an issue when the scope
    ///   takes no focus.
    static func focus(_ control: BarControl, system: CommandSystem) async throws -> ShownBarControl {
      let shown = try await ThreadBarControlJumpHostedTests.show(control, system: system)
      do {
        try #require(system.geometry.requestFocus(at: shown.path))
      } catch {
        shown.close()
        throw error
      }
      await RunLoopBlockFence.afterPendingBlocks()
      shown.harness.render()
      return shown
    }

    /// The shape that the control of the scope at `path` tells the scope.
    ///
    /// - Parameters:
    ///   - path: The path of the scope.
    ///   - system: The command system of the window.
    /// - Returns: The corners of the bezel of the control.
    /// - Throws: An issue when no beacon stands at `path`, or the control
    ///   tells no shape.
    static func reportedCorners(at path: FocusPath, in system: CommandSystem) throws -> ScopeFocusRingCorners {
      let probe = try #require(system.geometry.newestProbe(at: path) as? GeometryProbeView)
      return try #require(probe.focusIndicator.controlCorners)
    }

    /// The one view of the window that draws the band of a focus ring.
    ///
    /// - Parameter shown: The shown control.
    /// - Returns: The view of the band, and the layer that draws it.
    /// - Throws: An issue when no view, or more than one view, draws a band.
    static func band(in shown: ShownBarControl) throws -> (view: NSView, layer: CAShapeLayer) {
      let bands = DepthFirstWalk.views(from: shown.harness.hostingView)
        .filter { $0 is ScopeFocusRingBandView }
        .compactMap { view in
          (view.layer?.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.first { $0.path != nil }
            .map { (view: view, layer: $0) }
        }
      try #require(bands.count == 1, "\(bands.count) bands")
      return bands[0]
    }

    /// A production change that fails this test: the scope of a bar button
    /// asks for corners of its own, such as a capsule, so the ring cuts
    /// across the corners of a bezel with small corners.
    @Test(arguments: bezelButtons)
    func theRingOfABarButtonHasTheShapeOfItsBezel(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.focus(control, system: system)
      defer { shown.close() }
      let corners = try Self.reportedCorners(at: shown.path, in: system)
      let band = try Self.band(in: shown)

      let ring = ScopeFocusRing(isEnabled: true, corners: corners, style: .default)

      #expect(band.layer.path == ring.band(in: band.view.bounds.size)?.cgPath, "corners \(corners)")
    }

    /// A production change that fails this test: a floating glass action
    /// sets SwiftUI's `.buttonBorderShape(.capsule)`, which EditorKit cannot
    /// read, so the button tells its scope the corners of the automatic
    /// shape.
    @Test(arguments: floatingGlassActions)
    func theBezelOfAFloatingGlassActionIsACapsule(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.focus(control, system: system)
      defer { shown.close() }

      #expect(try Self.reportedCorners(at: shown.path, in: system) == .capsule)
    }

    /// A circle is the capsule of a square.
    ///
    /// A production change that fails this test: a round button of the
    /// composer shows its caption, or another shape than a circle.
    @Test(arguments: circleButtons)
    func theBezelOfARoundButtonIsACircle(_ control: BarControl) async throws {
      let system = CommandSystem()
      let shown = try await Self.focus(control, system: system)
      defer { shown.close() }
      let size = try Self.band(in: shown).view.bounds.size

      #expect(try Self.reportedCorners(at: shown.path, in: system) == .capsule)
      #expect(size.width == size.height, "size \(size)")
    }
  }
#endif
