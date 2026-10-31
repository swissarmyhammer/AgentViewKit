import AgentViewKitStyle
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

/// The title line of a ``StatusBar``, read from the frames of the accessibility
/// elements of a bar in a window: the symbol, the title and the button share
/// one line, and the explanation goes below that line whatever its length.
///
/// The symbol of a bar is hidden from accessibility, so the tests of the symbol
/// show the ``StatusTitleLayout`` of the bar with a symbol that has an
/// identifier. The frames have the origin at the bottom, so the top of a frame
/// is its `maxY`.
@Suite(.serialized, .hostedSerially) @MainActor struct StatusTitleLineHostedTests {
  /// The largest difference, in points, between two lengths that a test counts
  /// as the same length: the snapping of a frame to the pixels of the screen.
  static let layoutTolerance: CGFloat = 1

  /// The size of the window of the tests.
  static let size = CGSize(width: 520, height: 420)

  /// The width of a bar that wraps its long texts.
  static let narrowWidth: CGFloat = 320

  /// The identifier of a whole bar.
  static let barIdentifier = "bar"

  /// The identifier of the text of a bar.
  static let textIdentifier = "text"

  /// The identifier of the symbol of a layout.
  static let symbolIdentifier = "symbol"

  /// The identifier of the button of a bar.
  static let buttonIdentifier = "button"

  /// A title that fits on one line of a bar.
  static let title = "The agent stopped"

  /// A title that wraps in a bar of ``narrowWidth``.
  static let longTitle = "The agent stopped because the package registry refused the credentials of the build service"

  /// An explanation that fits on one line of a bar.
  static let shortExplanation = "Reload the board."

  /// An explanation that wraps to several lines in each width of the tests.
  static let longExplanation = String(
    repeating: "The registry answered 401 Unauthorized for each of the three packages of the build. ", count: 4)

  /// The tile padding of the bar.
  static let padding = EditorStyle.default.tile.padding

  /// Makes a message with a neutral severity.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - explanation: The explanation.
  /// - Returns: The message.
  static func message(title: String = title, explanation: String) -> StatusBar.Message {
    StatusBar.Message(
      title: title, explanation: explanation, symbolName: SharedSymbol.error, identifier: textIdentifier)
  }

  /// A button of a bar. A press does nothing.
  static var action: StatusBar.Action {
    StatusBar.Action(
      title: "Reload", systemImage: SharedSymbol.reload, identifier: buttonIdentifier, isEnabled: true, perform: {})
  }

  /// Shows `view` at the top of a window, at `width`.
  ///
  /// - Parameters:
  ///   - view: The view.
  ///   - width: The width of the view.
  /// - Returns: The harness, after one render pass. The caller closes it.
  static func mount<Content: View>(_ view: Content, width: CGFloat) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      VStack {
        view.frame(width: width)
        Spacer()
      }
    }
    harness.render()
    return harness
  }

  /// Shows a bar with a button.
  ///
  /// - Parameters:
  ///   - message: The text of the bar.
  ///   - width: The width of the bar.
  /// - Returns: The harness. The caller closes it.
  static func mountBar(
    _ message: StatusBar.Message, width: CGFloat = narrowWidth
  ) -> HostedViewHarness<some View> {
    mount(StatusBar(message: message, action: action, identifier: barIdentifier), width: width)
  }

  /// Shows the layout of a bar with a symbol that has an identifier, and with a
  /// button.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - explanation: The explanation.
  /// - Returns: The harness. The caller closes it.
  static func mountLayout(title: String, explanation: String) -> HostedViewHarness<some View> {
    let layout = StatusTitleLayout(
      title: title, explanation: explanation, textLabel: title, identifier: textIdentifier
    ) {
      StatusSymbolImage(name: SharedSymbol.error, color: .secondary)
        .accessibilityIdentifier(symbolIdentifier)
    } action: {
      StatusBarActionButton(action: action).buttonStyle(.glass)
    }
    return mount(layout, width: narrowWidth)
  }

  /// The distance of the vertical centers of two frames.
  ///
  /// - Parameters:
  ///   - first: A frame.
  ///   - second: A frame.
  /// - Returns: The distance, in points.
  static func centerDistance(_ first: CGRect, _ second: CGRect) -> CGFloat {
    abs(first.midY - second.midY)
  }

  /// The distance of the top of the button of a bar from the top of the bar.
  ///
  /// - Parameter message: The text of the bar.
  /// - Returns: The distance, in points.
  /// - Throws: An issue when the bar or its button does not show.
  static func buttonTopInset(of message: StatusBar.Message) throws -> CGFloat {
    let harness = mountBar(message)
    defer { harness.close() }
    let bar = try #require(harness.frame(identifier: barIdentifier))
    let button = try #require(harness.frame(identifier: buttonIdentifier))
    return bar.maxY - button.maxY
  }

  /// The height that an explanation adds to a bar below its title line.
  ///
  /// - Parameter action: The button of the bar, or `nil`.
  /// - Returns: The height of a bar with ``longExplanation``, less the height
  ///   of a bar with no explanation.
  static func explanationHeight(action: StatusBar.Action?) -> CGFloat {
    let long = StatusBar(message: message(explanation: longExplanation), action: action)
    let none = StatusBar(message: message(explanation: ""), action: action)
    return StyleViewHost.size(of: long, width: narrowWidth).height
      - StyleViewHost.size(of: none, width: narrowWidth).height
  }

  @Test func theSymbolIsCenteredOnTheTitleLineAboveAMultiLineExplanation() throws {
    let harness = Self.mountLayout(title: Self.title, explanation: Self.longExplanation)
    defer { harness.close() }

    let title = try #require(harness.frame(identifier: Self.textIdentifier))
    let symbol = try #require(harness.frame(identifier: Self.symbolIdentifier))

    #expect(Self.centerDistance(symbol, title) <= Self.layoutTolerance)
  }

  @Test func theButtonIsCenteredOnTheTitleLineAboveAMultiLineExplanation() throws {
    let harness = Self.mountBar(Self.message(explanation: Self.longExplanation))
    defer { harness.close() }

    let title = try #require(harness.frame(identifier: Self.textIdentifier))
    let button = try #require(harness.frame(identifier: Self.buttonIdentifier))

    #expect(Self.centerDistance(button, title) <= Self.layoutTolerance)
  }

  @Test func theSymbolAndTheButtonStayCenteredOnALongTitleThatWraps() throws {
    let harness = Self.mountLayout(title: Self.longTitle, explanation: Self.longExplanation)
    defer { harness.close() }

    let title = try #require(harness.frame(identifier: Self.textIdentifier))
    let symbol = try #require(harness.frame(identifier: Self.symbolIdentifier))
    let button = try #require(harness.frame(identifier: Self.buttonIdentifier))

    #expect(title.height > symbol.height)
    #expect(Self.centerDistance(symbol, title) <= Self.layoutTolerance)
    #expect(Self.centerDistance(button, title) <= Self.layoutTolerance)
  }

  @Test func aLongExplanationDoesNotMoveTheButtonDownTheBar() throws {
    let short = try Self.buttonTopInset(of: Self.message(explanation: Self.shortExplanation))
    let long = try Self.buttonTopInset(of: Self.message(explanation: Self.longExplanation))

    #expect(abs(long - short) <= Self.layoutTolerance)
  }

  @Test func theButtonOfABarStandsOnTheTilePaddingAtTheTop() throws {
    let inset = try Self.buttonTopInset(of: Self.message(explanation: Self.longExplanation))

    #expect(abs(inset - Self.padding) <= Self.layoutTolerance)
  }

  @Test func aLongExplanationWrapsAtTheWidthOfTheBarAndNotBesideTheButton() {
    let withButton = Self.explanationHeight(action: Self.action)
    let withNoButton = Self.explanationHeight(action: nil)

    #expect(abs(withButton - withNoButton) <= Self.layoutTolerance)
  }

  @Test func aLongTitleWraps() {
    let short = StatusBar(message: Self.message(explanation: ""), action: Self.action)
    let long = StatusBar(message: Self.message(title: Self.longTitle, explanation: ""), action: Self.action)

    let shortHeight = StyleViewHost.size(of: short, width: Self.narrowWidth).height
    let longHeight = StyleViewHost.size(of: long, width: Self.narrowWidth).height

    #expect(longHeight > shortHeight)
  }

  @Test func aBarWithNoExplanationIsOnlyItsTitleLine() throws {
    let harness = Self.mountBar(Self.message(explanation: ""))
    defer { harness.close() }

    let bar = try #require(harness.frame(identifier: Self.barIdentifier))
    let button = try #require(harness.frame(identifier: Self.buttonIdentifier))

    #expect(abs(bar.height - (button.height + 2 * Self.padding)) <= Self.layoutTolerance)
  }

  @Test func theTextOfABarIsOneElementWithTheTitleAndTheExplanation() throws {
    let harness = Self.mountBar(Self.message(explanation: Self.shortExplanation))
    defer { harness.close() }

    let label = harness.element(identifier: Self.textIdentifier)?.label

    #expect(label == "\(Self.title), \(Self.shortExplanation)")
  }

  @Test func theExplanationIsNoElementOfItsOwn() throws {
    let harness = Self.mountBar(Self.message(explanation: Self.shortExplanation))
    defer { harness.close() }

    #expect(!harness.accessibilityElements().contains { $0.label == Self.shortExplanation })
  }
}
