#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorStyle
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// A ``StatusLineText`` builds its text one time for each set of runs and
  /// colors, and not one time for each evaluation of its body (^2n9ymsh).
  ///
  /// The view is in an `NSHostingView` with no window, so the test shows no
  /// window and takes no focus.
  @MainActor @Suite struct StatusLineTextMemoTests {
    /// Runs in the primary color only. No other test uses their text, so
    /// the counter key of the test is its own.
    static let spans = [StatusLineSpan.text("Memo build count runs", .plain)]

    /// The text of ``spans`` with an accent color, so that the view reads a
    /// new environment value that no run uses.
    ///
    /// - Parameter accent: The accent color.
    /// - Returns: The view.
    static func text(accent: Color) -> some View {
      StatusLineText(spans: spans).environment(\.themeAccent, accent)
    }

    /// A production change that fails this test: the view builds its text
    /// in each evaluation of its body, and a new accent color evaluates the
    /// body again with the same runs and colors.
    @Test func aNewColorThatNoRunUsesBuildsNoNewText() {
      let key = StatusLineText.counterKey(for: Self.spans)
      let hosting = NSHostingView(rootView: Self.text(accent: .red))
      StyleViewHost.layOut(hosting)
      let builds = BodyEvaluationCounter.count(key)

      hosting.rootView = Self.text(accent: .blue)
      StyleViewHost.layOut(hosting)

      #expect(BodyEvaluationCounter.count(key) == builds)
    }
  }
#endif
