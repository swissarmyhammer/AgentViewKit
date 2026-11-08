#if DEBUG
  @testable import AgentViewKit
  import EditorCommands
  import EditorCommandsUI
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// The focus look of a scope around a ``DiffView`` (style.md, "Selection
  /// and focus").
  ///
  /// The selected file chip of a diff has no command scope of its own: it
  /// shows the selection only. Thus the chip tells no scope around the diff,
  /// such as the scope of a tool call, that it shows the focus of that scope.
  @Suite(.serialized, .hostedSerially) @MainActor struct DiffViewFocusLookHostedTests {
    /// The path of the scope around the diff, as a tool call puts one.
    static let scopePath = FocusPath.root(FocusSegment(kind: "diffHost"))

    /// The diff has no patch text, so it shows its file chips and no editor:
    /// no focusable view of the diff takes the focus from the beacon.
    ///
    /// A production change that fails this test: a file chip of the diff
    /// reports an item surface to the scope around the diff, so the scope
    /// loses its ring and each chip shows the focus fill of the scope.
    @Test func aFocusedScopeAroundADiffShowsItsRing() async throws {
      let window = try await CommandWindow(size: DiffViewHostedTests.tallSize, beacons: [Self.scopePath]) {
        DiffView(diff: DiffViewHostedTests.structuredDiff)
          .commandScope(segment: Self.scopePath.segments[0])
      }
      defer { window.harness.close() }

      try #require(window.system.geometry.requestFocus(at: Self.scopePath))
      await RunLoopBlockFence.afterPendingBlocks()
      window.harness.render()

      #expect(try window.system.showsFocusRing(at: Self.scopePath))
    }
  }
#endif
