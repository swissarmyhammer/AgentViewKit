import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

/// Records the key presses of a hosted test view.
@Observable
final class HostedEventLog {
  /// Each recorded event, in order.
  var events: [String] = []
}

/// A focusable view that records each key press.
struct KeyRecordingView: View {
  /// The log that gets the key presses.
  let log: HostedEventLog

  /// Whether the view has the focus.
  @FocusState private var isFocused: Bool

  var body: some View {
    Text("keys")
      .focusable()
      .focused($isFocused)
      .onKeyPress { press in
        let command = press.modifiers.contains(.command) ? "cmd+" : ""
        log.events.append(command + press.characters)
        return .handled
      }
      .onAppear { isFocused = true }
  }
}

/// A hidden window that reports the key status, but is not the key window of
/// the application.
///
/// AppKit makes a window of this kind, `NSCampoLightweightUIHostWindow`, for
/// the Writing Tools affordance of a focused text view. Its class overrides
/// `isKeyWindow`. The window has no size, is never visible, and does not take
/// the focus: `NSApp.keyWindow` stays `nil` (^y2wzhsz).
final class KeyStatusReportingWindow: NSWindow {
  /// Makes a hidden borderless window. The test never orders it in.
  init() {
    super.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
    // ARC owns the window. The default value would release it a second time.
    isReleasedWhenClosed = false
  }

  override var isKeyWindow: Bool { true }
}

/// The AVK-12 rule at run time: a hosted test of the kit shows no window and
/// takes no focus from the user, also after a key goes to a SwiftUI focus
/// target. The test process sets no activation policy, as in EditorKit
/// (`HiddenTestWindowTests`), so these tests read the real focus state.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedFocusTests {
  @Test func aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.render()

    try harness.sendKey(.escape)

    #expect(NSApp.windows.allSatisfy { !$0.isVisible })
    #expect(!harness.testProcessHasFocus)
  }

  @Test func aWindowThatOnlyReportsTheKeyStatusTakesNoFocus() throws {
    let reporter = KeyStatusReportingWindow()
    defer { reporter.close() }
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.render()

    try harness.sendKey(.escape)

    try #require(NSApp.windows.contains { $0 === reporter && $0.isKeyWindow })
    #expect(NSApp.windows.allSatisfy { !$0.isVisible })
    #expect(!harness.testProcessHasFocus)
  }
}
