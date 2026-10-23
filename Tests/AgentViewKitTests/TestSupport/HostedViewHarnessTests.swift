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

/// A focusable view that records Esc, as a request card does.
struct ExitRecordingView: View {
  /// The log that gets the Esc presses.
  let log: HostedEventLog

  var body: some View {
    Text("card")
      .focusable()
      .focusEffectDisabled()
      .onExitCommand { log.events.append("exit") }
  }
}

/// An AppKit view that records each mouse-down and mouse-up event.
final class MouseRecordingNSView: NSView {
  /// The log that gets the events.
  var log: HostedEventLog?

  override func mouseDown(with event: NSEvent) {
    log?.events.append("down")
  }

  override func mouseUp(with event: NSEvent) {
    log?.events.append("up")
  }
}

/// A SwiftUI view that shows a ``MouseRecordingNSView``.
struct MouseRecordingView: NSViewRepresentable {
  /// The log that gets the mouse events.
  let log: HostedEventLog

  func makeNSView(context: Context) -> MouseRecordingNSView {
    let view = MouseRecordingNSView()
    view.log = log
    return view
  }

  func updateNSView(_ view: MouseRecordingNSView, context: Context) {
    view.log = log
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

/// Two boxes of a known size, one above the other, with no space between
/// them.
struct SizedBoxesView: View {
  /// The width of each box, in points.
  static let boxWidth: CGFloat = 120

  /// The height of each box, in points.
  static let boxHeight: CGFloat = 30

  /// The size of each box, in points.
  static let boxSize = CGSize(width: boxWidth, height: boxHeight)

  /// The accessibility identifier of the top box.
  static let topIdentifier = "top-box"

  /// The accessibility identifier of the bottom box.
  static let bottomIdentifier = "bottom-box"

  var body: some View {
    VStack(spacing: 0) {
      box(Self.topIdentifier)
      box(Self.bottomIdentifier)
    }
  }

  /// One box that is an accessibility element.
  ///
  /// - Parameter identifier: The accessibility identifier of the box.
  /// - Returns: The box.
  private func box(_ identifier: String) -> some View {
    // A shape takes the full size that the frame gives it, so the element
    // has the size of the box.
    Rectangle()
      .frame(width: Self.boxSize.width, height: Self.boxSize.height)
      .accessibilityElement()
      .accessibilityLabel(identifier)
      .accessibilityIdentifier(identifier)
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct HostedViewHarnessTests {
  @Test func readsTheLabelOfMountedText() {
    let harness = HostedViewHarness(Text("hi"))
    defer { harness.close() }
    harness.render()

    let labelled = harness.accessibilityElements().filter { $0.label == "hi" }
    #expect(labelled.count == 1)
  }

  @Test func findsAnElementByIdentifier() {
    let harness = HostedViewHarness(Text("named").accessibilityIdentifier("named-text"))
    defer { harness.close() }
    harness.render()

    let element = harness.element(identifier: "named-text")
    #expect(element?.label == "named")
    #expect(harness.element(identifier: "missing") == nil)
  }

  @Test func readsOnlyTheElementsUnderAContainer() {
    let harness = HostedViewHarness {
      VStack {
        VStack {
          Text("inside")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("container")
        Text("outside")
      }
    }
    defer { harness.close() }
    harness.render()

    let labels = harness.elements(under: "container").compactMap(\.label)
    #expect(labels.contains("inside"))
    #expect(!labels.contains("outside"))
    #expect(harness.elements(under: "missing").isEmpty)
  }

  @Test func readsTheFrameOfAnElement() throws {
    let harness = HostedViewHarness(SizedBoxesView())
    defer { harness.close() }
    harness.render()

    let top = try #require(harness.frame(identifier: SizedBoxesView.topIdentifier))
    let bottom = try #require(harness.frame(identifier: SizedBoxesView.bottomIdentifier))
    #expect(top.size == SizedBoxesView.boxSize)
    #expect(bottom.size == SizedBoxesView.boxSize)
    // The frame is in screen points, where y grows up.
    #expect(top.minY == bottom.maxY)
    #expect(harness.frame(identifier: "missing") == nil)
  }

  @Test func measuresTheFrameHeightOfAnElementInAHostedView() throws {
    let height = try HostedViewHarness.frameHeight(
      of: SizedBoxesView(), identifier: SizedBoxesView.topIdentifier)

    #expect(height == SizedBoxesView.boxHeight)
  }

  @Test func frameHeightThrowsForAMissingIdentifier() {
    #expect(throws: HostedViewHarnessError.noElement(identifier: "absent")) {
      try HostedViewHarness.frameHeight(of: SizedBoxesView(), identifier: "absent")
    }
  }

  @Test func readsTheElementsOfAMenuButton() {
    let harness = HostedViewHarness(
      Menu("Options", systemImage: "gear") {
        Button("One") {}
      }
      .accessibilityIdentifier("options-menu"))
    defer { harness.close() }
    harness.render()

    #expect(harness.accessibilityElements().contains { $0.identifier == "options-menu" })
    #expect(harness.element(identifier: "options-menu") != nil)
  }

  @Test func pressRunsTheButtonAction() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness {
      Button("Go") { log.events.append("go") }
        .accessibilityIdentifier("go-button")
    }
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: "go-button")

    #expect(log.events == ["go"])
  }

  @Test func pressThrowsForAMissingIdentifier() {
    let harness = HostedViewHarness(Text("none"))
    defer { harness.close() }
    harness.render()

    #expect(throws: HostedViewHarnessError.noElement(identifier: "absent")) {
      try harness.press(identifier: "absent")
    }
  }

  @Test func sendKeyReachesTheFocusedView() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.render()

    try harness.sendKey("k", modifiers: .command)
    try harness.sendKey(.escape)

    #expect(log.events == ["cmd+k", "\u{1B}"])
  }

  /// The harness shows no window and takes no focus, also after a key goes
  /// to a SwiftUI focus target (AVK-12).
  @Test func aMountedViewThatGetsAKeyShowsNoWindowAndTakesNoFocus() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.render()

    try harness.sendKey(.escape)

    #expect(NSApp.windows.allSatisfy { !$0.isVisible })
    #expect(!harness.processHasFocus)
  }

  /// A window that only reports the key status does not take the focus. AppKit
  /// makes such a window for the Writing Tools affordance of a focused text
  /// view, on a timer, at a time that the tests do not control (^y2wzhsz).
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
    #expect(!harness.processHasFocus)
  }

  /// A key window gives its first key view the keyboard focus. The harness
  /// window is never the key window, so the harness does this step.
  @Test func theFirstFocusableViewGetsTheKeyboardFocusSoEscapeReachesIt() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(ExitRecordingView(log: log))
    defer { harness.close() }
    harness.render()

    try harness.sendKey(.escape)

    #expect(log.events == ["exit"])
  }

  @Test func clickSendsTheMouseEventsToTheViewUnderThePoint() throws {
    let log = HostedEventLog()
    let harness = HostedViewHarness(MouseRecordingView(log: log))
    defer { harness.close() }
    harness.render()
    let bounds = harness.hostingView.bounds

    try harness.click(at: harness.hostingView.convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil))

    #expect(log.events == ["down", "up"])
  }

  @Test func clickThrowsWhenNoViewIsUnderThePoint() {
    let harness = HostedViewHarness(Text("hi"))
    defer { harness.close() }
    harness.render()
    let outside = NSPoint(x: -HostedViewHarness<Text>.defaultSize.width, y: 0)

    #expect(throws: HostedViewHarnessError.noView(at: outside)) {
      try harness.click(at: outside)
    }
  }

  @Test func contextMenuReadsTheMenuOfTheViewUnderTheElement() throws {
    let harness = HostedViewHarness {
      Text("menu")
        .contextMenu {
          Button("Alpha") {}
          Divider()
          Button("Beta") {}
        }
        .accessibilityIdentifier("menu-text")
    }
    defer { harness.close() }
    harness.render()

    let menu = try harness.contextMenu(identifier: "menu-text")

    #expect(menu?.items.map(\.title) == ["Alpha", "", "Beta"])
  }

  @Test func contextMenuIsNilForAnElementWithNoMenu() throws {
    let harness = HostedViewHarness(Text("plain").accessibilityIdentifier("plain-text"))
    defer { harness.close() }
    harness.render()

    #expect(try harness.contextMenu(identifier: "plain-text") == nil)
  }

  @Test func contextMenuThrowsForAMissingIdentifier() {
    let harness = HostedViewHarness(Text("none"))
    defer { harness.close() }
    harness.render()

    #expect(throws: HostedViewHarnessError.noElement(identifier: "absent")) {
      try harness.contextMenu(identifier: "absent")
    }
  }

  @Test func typeSendsEachCharacter() {
    let log = HostedEventLog()
    let harness = HostedViewHarness(KeyRecordingView(log: log))
    defer { harness.close() }
    harness.render()

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
    harness.render()

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
    harness.render()

    #expect(harness.element(identifier: "first-row")?.label == "first")
    try harness.press(identifier: "row-button")
    #expect(log.events == ["go"])
  }

  @Test func incrementMovesASlider() throws {
    let level = HostedLevel()
    let harness = HostedViewHarness(SliderView(level: level))
    defer { harness.close() }
    harness.render()

    try harness.increment(identifier: "level")
    #expect(level.value > SliderView.lowerBound)
  }

  @Test func incrementThrowsForAMissingIdentifier() {
    let harness = HostedViewHarness(Text("hi"))
    defer { harness.close() }
    harness.render()

    #expect(throws: HostedViewHarnessError.noElement(identifier: "missing")) {
      try harness.increment(identifier: "missing")
    }
  }

  @Test func incrementThrowsForAnElementWithNoIncrementAction() {
    let harness = HostedViewHarness(Text("hi").accessibilityIdentifier("text"))
    defer { harness.close() }
    harness.render()

    #expect(throws: HostedViewHarnessError.incrementFailed(identifier: "text")) {
      try harness.increment(identifier: "text")
    }
  }

  @Test func readsWhetherAnElementIsEnabled() {
    let harness = HostedViewHarness {
      VStack {
        Button("On") {}
          .accessibilityIdentifier("enabled")
        Button("Off") {}
          .disabled(true)
          .accessibilityIdentifier("disabled")
      }
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: "enabled")?.isEnabled == true)
    #expect(harness.element(identifier: "disabled")?.isEnabled == false)
  }
}

/// The tests of the direct render pass of ``HostedViewHarness``.
///
/// Each test changes an observable model in a fixed order, calls
/// ``HostedViewHarness/render()``, ``HostedViewHarness/render(when:)`` or an
/// action of the harness, and reads the accessibility tree at once. No test
/// turns the run loop or waits on a clock.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedViewHarnessRenderTests {
  @Test func aModelChangeShowsInTheAccessibilityTreeAfterOneRenderPass() {
    let model = HostedCaption()
    let harness = HostedViewHarness(CaptionView(model: model))
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: CaptionView.captionIdentifier)?.label == HostedCaption.initialText)

    model.text = HostedCaption.changedText
    harness.render()

    #expect(harness.element(identifier: CaptionView.captionIdentifier)?.label == HostedCaption.changedText)
  }

  @Test func pressShowsTheResultOfTheButtonActionInTheAccessibilityTree() throws {
    let model = HostedCaption()
    let harness = HostedViewHarness(CaptionView(model: model))
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: CaptionView.buttonIdentifier)

    #expect(model.text == HostedCaption.changedText)
    #expect(harness.element(identifier: CaptionView.captionIdentifier)?.label == HostedCaption.changedText)
  }

  @Test func renderWhenShowsTheChangeOfATaskThatRunsAfterTheWaitStarts() async {
    let model = HostedCaption()
    let harness = HostedViewHarness(CaptionView(model: model))
    defer { harness.close() }
    harness.render()
    // The task runs on the main actor when the wait suspends, so the change
    // comes after the wait starts.
    let writer = Task { @MainActor in model.text = HostedCaption.changedText }

    await harness.render(when: { model.text == HostedCaption.changedText })

    #expect(harness.element(identifier: CaptionView.captionIdentifier)?.label == HostedCaption.changedText)
    await writer.value
  }
}

/// Holds the text of a hosted caption.
@Observable
final class HostedCaption {
  /// The text before a change.
  static let initialText = "before"

  /// The text after a change.
  static let changedText = "after"

  /// The text that the caption shows.
  var text = initialText
}

/// A caption that shows the text of a ``HostedCaption``, and a button that
/// changes the text.
struct CaptionView: View {
  /// The accessibility identifier of the caption.
  static let captionIdentifier = "caption"

  /// The accessibility identifier of the button.
  static let buttonIdentifier = "change-caption"

  /// The holder of the text.
  let model: HostedCaption

  var body: some View {
    VStack {
      Text(model.text)
        .accessibilityIdentifier(Self.captionIdentifier)
      Button("Change") { model.text = HostedCaption.changedText }
        .accessibilityIdentifier(Self.buttonIdentifier)
    }
  }
}

/// Holds the value of a hosted slider.
@Observable
final class HostedLevel {
  /// The slider value. It starts at the lower bound of ``SliderView``.
  var value: Double = SliderView.lowerBound
}

/// A slider from ``lowerBound`` to ``upperBound``.
struct SliderView: View {
  /// The smallest value of the slider.
  static let lowerBound: Double = 0

  /// The largest value of the slider.
  static let upperBound: Double = 10

  /// The holder of the value.
  let level: HostedLevel

  var body: some View {
    Slider(
      value: Binding(get: { level.value }, set: { level.value = $0 }),
      in: Self.lowerBound...Self.upperBound
    ) {
      Text("Level")
    }
    .accessibilityIdentifier("level")
  }
}
