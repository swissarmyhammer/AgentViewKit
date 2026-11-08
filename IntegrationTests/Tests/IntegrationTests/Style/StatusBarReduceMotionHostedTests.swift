import AgentViewKitStyle
import AppKit
import EditorSwiftUI
import EditorTestSupport
import QuartzCore
import SwiftUI
import Testing

/// Hosted tests of the live symbol of a ``StatusBar``: the bar of an ongoing
/// message animates its symbol, and Reduce Motion stops it.
///
/// SwiftUI draws a settled symbol as one image layer, and a symbol whose
/// effect runs as a drawing layer of its own, so the tests read the classes of
/// the layers the bar realizes, and no pixel of a capture. A bar that only
/// removed its symbol effects under Reduce Motion kept the drawing layer of the
/// running effect on macOS 27 (card ^1qhzmsh).
@Suite(.serialized, .hostedSerially) @MainActor struct StatusBarReduceMotionHostedTests {
  /// The size of each hosted window.
  static let size = CGSize(width: 360, height: 80)

  /// A message of the bar, with the symbol of work that runs, which has the
  /// layers that the live effect animates.
  ///
  /// - Parameter isOngoing: Whether the message tells of work that goes on.
  /// - Returns: The message.
  static func message(isOngoing: Bool) -> StatusBar.Message {
    StatusBar.Message(
      title: "Replaying", explanation: "The agent sends the history again.",
      symbolName: EditorSymbol.status(.inProgress).systemImage, identifier: "message", isOngoing: isOngoing)
  }

  /// Mounts the bar of a message and gives the class name of each layer it
  /// realizes, depth first.
  ///
  /// - Parameters:
  ///   - isOngoing: Whether the message tells of work that goes on.
  ///   - reduceMotion: Whether Reduce Motion is on.
  /// - Returns: The class names.
  /// - Throws: An error when the hosting view has no layer.
  static func layerClasses(isOngoing: Bool, reduceMotion: Bool) async throws -> [String] {
    let bar = StatusBar(message: message(isOngoing: isOngoing), action: nil)
      .environment(\._accessibilityReduceMotion, reduceMotion)
    let harness = HostedViewHarness(bar, size: size)
    defer { harness.close() }
    let layer = try #require(harness.hostingView.layer)
    await harness.render { layer.sublayers?.isEmpty == false }
    let layers = DepthFirstWalk.nodes(from: layer) { $0.sublayers ?? [] }
    return layers.map { String(describing: type(of: $0)) }
  }

  /// A production change that fails this test: the probe of the Reduce
  /// Motion test reads no difference, so the test below would pass with the
  /// effect running.
  @Test func theBarOfAnOngoingMessageRealizesOtherLayers() async throws {
    let settled = try await Self.layerClasses(isOngoing: false, reduceMotion: false)
    let live = try await Self.layerClasses(isOngoing: true, reduceMotion: false)

    #expect(live != settled, "live: \(live), settled: \(settled)")
  }

  /// A production change that fails this test: the symbol of an ongoing
  /// message keeps its live effect under Reduce Motion.
  @Test func reduceMotionStopsTheSymbolOfAnOngoingMessage() async throws {
    let settled = try await Self.layerClasses(isOngoing: false, reduceMotion: true)
    let reduced = try await Self.layerClasses(isOngoing: true, reduceMotion: true)

    #expect(reduced == settled, "reduced: \(reduced), settled: \(settled)")
  }
}
