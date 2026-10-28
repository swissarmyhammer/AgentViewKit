#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import SwiftUI

  /// The one mount of the diff tests: a hosted harness that shows a view with
  /// animations off, after one render pass.
  ///
  /// Each hosted test of the diff folder mounts its view here, so a fix to the
  /// mount reaches each of them. Only the view, or the patch, and the size
  /// differ between the tests.
  @MainActor enum DiffHarness {
    /// Makes a harness that shows `view` with animations off, after one render
    /// pass.
    ///
    /// - Parameters:
    ///   - view: The view to show.
    ///   - size: The size of the harness.
    /// - Returns: The harness.
    static func mount(_ view: some View, size: CGSize) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        view.transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// Makes a harness that shows the kit ``DiffView`` of `patch` in the inline
    /// layout, after one render pass.
    ///
    /// - Parameters:
    ///   - patch: The text of the patch to show.
    ///   - size: The size of the harness.
    /// - Returns: The harness.
    static func mountInline(patch: String, size: CGSize) -> HostedViewHarness<some View> {
      mount(DiffView(patch: patch).diffLayout(.inline), size: size)
    }
  }
#endif
