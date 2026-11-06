#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// Tests that the accessibility frame of each bar container of a thread
  /// holds the elements in it after the thread widens (^ydh96hy): the
  /// ``AgentInfoHeader`` in the top bar, and the floating controls of the
  /// bottom bar (``AgentThreadLayout/floatingControlsIdentifier``).
  ///
  /// XCUI and VoiceOver place an element of another process by its frame, so
  /// a container whose frame misses its rows sends a test, or the cursor of
  /// VoiceOver, to the wrong place. The tests read the frames through the
  /// accessibility tree alone. An accessibility hit test inside the process
  /// still resolves each element under its container when the frame is
  /// wrong, so it cannot show the defect; the frames do.
  ///
  /// A host pane can lay the thread out narrow first, such as a split view
  /// that opens, and then give it its width. Each test mounts the thread
  /// in ``narrowSize``, renders it, widens the window to ``wideSize``, and
  /// renders it again.
  ///
  /// On macOS 27, SwiftUI gives an accessibility element that holds Liquid
  /// Glass the frame of the glass from its first layout. Both bars stand on
  /// EditorKit `.floatingGlass()`, which sets the accessibility shape of the
  /// glass to its content (EditorKit ^bavw691), so the frame follows the
  /// layout.
  ///
  /// The agent of the tests has no auth method, so the bottom bar holds the
  /// composer alone, as in a host whose user has signed in. A login prompt
  /// in the bar evaluates its body again when the width changes, which
  /// updates the frame and hides the defect.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadBarAccessibilityFrameHostedTests {
    /// The size that the thread lays out in first: narrow enough that the
    /// crumb of the header wraps.
    static let narrowSize = CGSize(width: 120, height: 800)

    /// The size that the window widens to, which shows the header on one
    /// line.
    static let wideSize = CGSize(width: 640, height: 800)

    /// Opens a scripted session whose agent gives its info and no auth
    /// method.
    ///
    /// - Returns: The scripted session.
    static func openSignedInSession() async throws -> ScriptedSession {
      try await ScriptedSession.open {
        $0.results["initialize"] = ScriptedSession.makeInitializeResult(
          info: ScriptedSession.agentInfo, authMethods: "[]")
      }
    }

    /// Shows the thread of a session in ``narrowSize``, and then widens the
    /// window to ``wideSize``.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness, after a render pass in each size.
    static func mountWidenedThread(_ session: ScriptedSession) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: narrowSize) {
        AgentThreadView(session: session.model, connection: session.connection)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      harness.window.setContentSize(wideSize)
      harness.render()
      return harness
    }

    /// The elements under a container whose accessibility frame is outside
    /// the frame of the container, each as its role, its identifier and its
    /// frame.
    ///
    /// The walk leaves out the rows of a scroll area, which the frame of the
    /// area holds, and each element with no area, which has no point to
    /// place. A frame may stand out of the container by
    /// ``ThreadBottomBarHostedTests/edgeTolerance``, which layout gives when
    /// it rounds an edge to a pixel.
    ///
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the container.
    ///   - harness: The harness that shows the thread.
    /// - Returns: The elements outside the container; empty when each one is
    ///   inside it.
    /// - Throws: An issue when no element, or no frame, has `identifier`.
    static func elementsOutside(
      containerIdentifiedAs identifier: String, in harness: HostedViewHarness<some View>
    ) throws -> [String] {
      let container = try #require(accessibilityElements(identifiedAs: identifier, under: harness.hostingView).first)
      let tolerance = ThreadBottomBarHostedTests.edgeTolerance
      let bounds = try #require(accessibilityFrame(of: container)).insetBy(dx: -tolerance, dy: -tolerance)
      let isOutsideScrollArea = { accessibilityRole(of: $0) != NSAccessibility.Role.scrollArea.rawValue }
      return accessibilitySubtree(of: container, descendingInto: isOutsideScrollArea).dropFirst()
        .compactMap { element in
          guard let frame = accessibilityFrame(of: element), !frame.isNull, !frame.isEmpty,
            !bounds.contains(frame)
          else { return nil }
          return "\(accessibilityRole(of: element) ?? "") \(accessibilityIdentifier(of: element) ?? "") \(frame)"
        }
    }

    /// A production change that fails this test: the header glass gives the
    /// header its glass frame from the first layout again (EditorKit
    /// ^bavw691), so the frame keeps the narrow wrapped shape of the header.
    @Test func theFrameOfTheHeaderHoldsEachElementOfItsRowAfterTheThreadWidens() async throws {
      let session = try await Self.openSignedInSession()
      defer { session.close() }
      let harness = Self.mountWidenedThread(session)
      defer { harness.close() }

      let outside = try Self.elementsOutside(containerIdentifiedAs: AgentInfoHeader.identifier, in: harness)

      #expect(outside.isEmpty, "\(outside)")
    }

    /// A production change that fails this test: the composer glass gives the
    /// floating controls the glass frame from the first layout again
    /// (EditorKit ^bavw691), so the frame keeps the narrow width.
    @Test func theFrameOfTheFloatingControlsHoldsEachControlAfterTheThreadWidens() async throws {
      let session = try await Self.openSignedInSession()
      defer { session.close() }
      let harness = Self.mountWidenedThread(session)
      defer { harness.close() }

      let outside = try Self.elementsOutside(
        containerIdentifiedAs: AgentThreadLayout.floatingControlsIdentifier, in: harness)

      #expect(outside.isEmpty, "\(outside)")
    }
  }
#endif
