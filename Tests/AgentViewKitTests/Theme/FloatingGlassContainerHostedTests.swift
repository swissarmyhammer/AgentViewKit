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

/// A text that shows the glass namespace of the floating controls above it
/// (``SwiftUI/EnvironmentValues/floatingGlassNamespace``).
struct FloatingNamespaceProbe: View {
  /// The text of the probe when no container gives a namespace.
  static let noNamespace = "none"

  /// The accessibility identifier of the probe.
  let identifier: String

  @Environment(\.floatingGlassNamespace) private var namespace

  var body: some View {
    Text(namespace.map { String(describing: $0) } ?? Self.noNamespace)
      .accessibilityIdentifier(identifier)
  }
}

/// Tests for the one glass container of a group of floating controls
/// (D110 (c)).
///
/// The SDK gives no accessibility element for a `GlassEffectContainer`. So
/// the tests read the environment value that counts the containers that a
/// ``FloatingGlassContainer`` made above a view. A container in a container
/// makes no second container, so the count stays one.
///
/// The tests also read the glass namespace of the container (D113 answer 2).
/// A container in a container keeps the namespace of the outer container, so
/// that each glass of the group has its glass id in the same namespace.
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

  /// The accessibility identifier of the namespace probe in the outer
  /// container.
  static let outerProbe = "outer-namespace-probe"

  /// The accessibility identifier of the namespace probe in the inner
  /// container.
  static let innerProbe = "inner-namespace-probe"

  /// The text of the namespace probe with `identifier` in `harness`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the probe.
  ///   - harness: The harness that shows the probe.
  /// - Returns: The text, or `nil` when the probe is not in the tree.
  static func namespace(of identifier: String, in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: identifier)?.label
  }

  @Test func aViewOutOfAContainerHasNoGlassNamespace() {
    let harness = HostedViewHarness(FloatingNamespaceProbe(identifier: Self.outerProbe))
    defer { harness.close() }
    harness.render()

    #expect(Self.namespace(of: Self.outerProbe, in: harness) == FloatingNamespaceProbe.noNamespace)
  }

  @Test func aContainerInAContainerKeepsTheGlassNamespaceOfTheOuterContainer() throws {
    let harness = HostedViewHarness {
      FloatingGlassContainer(spacing: Self.spacing) {
        VStack {
          FloatingNamespaceProbe(identifier: Self.outerProbe)
          FloatingGlassContainer(spacing: Self.spacing) {
            FloatingNamespaceProbe(identifier: Self.innerProbe)
          }
        }
      }
    }
    defer { harness.close() }
    harness.render()

    let outer = try #require(Self.namespace(of: Self.outerProbe, in: harness))
    #expect(outer != FloatingNamespaceProbe.noNamespace)
    #expect(Self.namespace(of: Self.innerProbe, in: harness) == outer)
  }
}
