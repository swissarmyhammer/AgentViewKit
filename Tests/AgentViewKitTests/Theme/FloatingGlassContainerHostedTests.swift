@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// A text that shows the number of the glass containers of floating controls
/// above it (``SwiftUI/EnvironmentValues/floatingGlassContainerCount``).
struct FloatingContainerProbe: View {
  /// The accessibility identifier of the probe.
  static let identifier = "floating-container-probe"

  @Environment(\.floatingGlassContainerCount) private var containerCount

  var body: some View {
    Text(String(containerCount))
      .accessibilityIdentifier(Self.identifier)
  }
}

/// Tests for the one glass container of a group of floating controls
/// (D110 (c)).
///
/// The SDK gives no accessibility element for a `GlassEffectContainer`. So
/// the tests read the environment value that counts the containers that a
/// ``FloatingGlassContainer`` made above a view. A container in a container
/// makes no second container, so the count stays one.
@Suite(.serialized, .hostedSerially) @MainActor struct FloatingGlassContainerHostedTests {
  /// The spacing of the containers of the tests.
  static let spacing: CGFloat = 8

  /// The number of containers that the probe in `harness` shows.
  ///
  /// - Parameter harness: The harness that shows the probe.
  /// - Returns: The count, or `nil` when the probe is not in the tree.
  static func containerCount(in harness: HostedViewHarness<some View>) -> Int? {
    harness.element(identifier: FloatingContainerProbe.identifier)?.label.flatMap { Int($0) }
  }

  @Test func aViewOutOfAContainerHasNoContainerAboveIt() {
    let harness = HostedViewHarness(FloatingContainerProbe())
    defer { harness.close() }
    harness.render()

    #expect(Self.containerCount(in: harness) == 0)
  }

  @Test func theContentOfAContainerHasOneContainerAboveIt() {
    let harness = HostedViewHarness {
      FloatingGlassContainer(spacing: Self.spacing) {
        FloatingContainerProbe()
      }
    }
    defer { harness.close() }
    harness.render()

    #expect(Self.containerCount(in: harness) == 1)
  }

  @Test func aContainerInAContainerMakesNoSecondContainer() {
    let harness = HostedViewHarness {
      FloatingGlassContainer(spacing: Self.spacing) {
        FloatingGlassContainer(spacing: Self.spacing) {
          FloatingContainerProbe()
        }
      }
    }
    defer { harness.close() }
    harness.render()

    #expect(Self.containerCount(in: harness) == 1)
  }
}
