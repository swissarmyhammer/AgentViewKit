import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

/// Records the actions of a hosted test view.
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

/// A view that shows two linked accessibility elements.
struct LinkedLabelsView: View {
  @Namespace private var namespace

  var body: some View {
    VStack {
      Text("question")
        .accessibilityIdentifier("question")
        .accessibilityLinkedGroup(id: "pair", in: namespace)
      Text("answer")
        .accessibilityIdentifier("answer")
        .accessibilityLinkedGroup(id: "pair", in: namespace)
    }
  }
}

@Suite(.serialized) @MainActor struct HostedViewHarnessTests {
  @Test func readsTheLabelOfMountedText() {
    let harness = HostedViewHarness(Text("hi"))
    defer { harness.close() }
    harness.pump()

    let labelled = harness.accessibilityElements().filter { $0.label == "hi" }
    #expect(labelled.count == 1)
  }

  @Test func findsAnElementByIdentifier() {
    let harness = HostedViewHarness(Text("named").accessibilityIdentifier("named-text"))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: "named-text")
    #expect(element?.label == "named")
    #expect(harness.element(identifier: "missing") == nil)
  }

  @Test func pressRunsTheButtonAction() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness {
      Button("Go") { log.events.append("go") }
        .accessibilityIdentifier("go-button")
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: "go-button")

    #expect(log.events == ["go"])
  }

  @Test func pressThrowsForAMissingIdentifier() {
    let harness = HostedViewHarness(Text("none"))
    defer { harness.close() }
    harness.pump()

    #expect(throws: HostedViewHarnessError.noElement(identifier: "absent")) {
      try harness.press(identifier: "absent")
    }
  }

  @Test func sendKeyReachesTheFocusedView() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.pump()

    try harness.sendKey("k", modifiers: .command)
    try harness.sendKey(.escape)

    #expect(log.events == ["cmd+k", "\u{1B}"])
  }

  @Test func typeSendsEachCharacter() {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.pump()

    harness.type("ab")

    #expect(log.events == ["a", "b"])
  }

  @Test func sendKeyThrowsForAnUnknownFunctionKey() {
    let harness = HostedViewHarness(Text("keys"))
    defer { harness.close() }

    #expect(throws: HostedViewHarnessError.unsupportedKey(String(KeyEquivalent.home.character))) {
      try harness.sendKey(.home)
    }
  }

  @Test func readsTheLinkedElements() throws {
    let harness = HostedViewHarness(LinkedLabelsView())
    defer { harness.close() }
    harness.pump()

    let question = try #require(harness.element(identifier: "question"))
    #expect(question.linkedElements.map(\.identifier).contains("answer"))
  }

  @Test func findsAndPressesAnElementInAListRow() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness {
      List {
        Text("first")
          .accessibilityIdentifier("first-row")
        Button("Go") { log.events.append("go") }
          .accessibilityIdentifier("row-button")
      }
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "first-row")?.label == "first")
    try harness.press(identifier: "row-button")
    #expect(log.events == ["go"])
  }
}
