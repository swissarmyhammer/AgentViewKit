import AgentViewKitStyle
import EditorStyle
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

/// Checks the status bar through its public API: the message and its
/// severity, the tone of the symbol, the action and the style of its button.
@Suite @MainActor struct StatusBarTests {
  /// The accessibility identifier of the Reload button of the tests.
  static let actionIdentifier = "reload"

  /// Makes a message of `severity`.
  ///
  /// - Parameters:
  ///   - severity: The severity of the message.
  ///   - explanation: The explanation below the title. An empty explanation
  ///     shows no line.
  /// - Returns: The message.
  static func message(
    _ severity: StatusBar.Message.Severity, explanation: String = "Explanation"
  ) -> StatusBar.Message {
    StatusBar.Message(
      title: "Title", explanation: explanation, symbolName: EditorSymbol.severity(.information).systemImage,
      identifier: "message", severity: severity)
  }

  /// Makes the Reload button of the tests, which takes a press.
  ///
  /// - Parameter hint: The accessibility hint of the button.
  /// - Returns: The action.
  static func action(hint: String? = nil) -> StatusBar.Action {
    StatusBarFixtures.reloadAction(identifier: actionIdentifier, hint: hint)
  }

  /// A style that records the identifier of each action it styles.
  struct RecordingStyle: StatusBarActionStyle {
    /// The record of the styled actions.
    let record: StyleRecord<String>

    func makeBody(configuration: StatusBarActionConfiguration) -> some View {
      record.values.append(configuration.action.identifier)
      return configuration.button
    }
  }

  @Test func aMessageIsNeutralAndSettledByDefault() {
    let message = StatusBar.Message(
      title: "Title", explanation: "Explanation", symbolName: EditorSymbol.severity(.information).systemImage,
      identifier: "message")

    #expect(message.severity == .neutral)
    #expect(!message.isOngoing)
  }

  @Test func theSymbolToneComesFromTheSeverity() {
    let tones: [(StatusBar.Message.Severity, EditorSymbol.Tone)] = [
      (.neutral, .neutral), (.information, .information), (.warning, .warning), (.failure, .error),
    ]

    for (severity, tone) in tones {
      #expect(severity.tone == tone, "\(severity)")
    }
  }

  @Test func anActionHasNoHintByDefault() {
    #expect(Self.action().hint == nil)
  }

  @Test func anActionKeepsItsHint() {
    #expect(Self.action(hint: "Loads the board again.").hint == "Loads the board again.")
  }

  @Test func theBarStylesItsButtonWithTheStyleOfTheEnvironment() {
    let record = StyleRecord<String>()

    StyleViewHost.layOut(
      StatusBar(message: Self.message(.failure), action: Self.action())
        .statusBarActionStyle(RecordingStyle(record: record)))

    #expect(record.values.contains("reload"))
  }

  @Test func aBarWithNoActionStylesNoButton() {
    let record = StyleRecord<String>()

    StyleViewHost.layOut(
      StatusBar(message: Self.message(.neutral), action: nil)
        .statusBarActionStyle(RecordingStyle(record: record)))

    #expect(record.values.isEmpty)
  }

  @Test func aBarWithAnIdentifierStillStylesItsButton() {
    let record = StyleRecord<String>()

    StyleViewHost.layOut(
      StatusBar(message: Self.message(.failure), action: Self.action(), identifier: "bar")
        .statusBarActionStyle(RecordingStyle(record: record)))

    #expect(record.values.contains("reload"))
  }

  @Test func severalBarsStackInAControlStackWithAndWithoutAButton() {
    let one = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: nil))
    let stack = StyleViewHost.fittingSize(
      of: ControlStack(alignment: .leading) {
        StatusBar(message: Self.message(.neutral), action: nil, identifier: "neutral")
        StatusBar(message: Self.message(.failure), action: nil, identifier: "failure")
      })

    #expect(stack.height == 2 * one.height + EditorStyle.default.controlSpacing)
  }

  @Test func theDismissButtonShowsOnlyItsSymbol() {
    let titled = StatusBar.Action(
      title: "Dismiss", systemImage: EditorSymbol.action(.dismiss).systemImage, identifier: "dismiss",
      isEnabled: true, perform: {})
    let dismiss = StatusBar.Action.makeDismiss(identifier: "dismiss", perform: {})

    let iconOnly = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: dismiss))
    let withTitle = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: titled))

    #expect(iconOnly.width < withTitle.width)
  }

  @Test func theDefaultStyleShowsTheButton() {
    let withButton = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: Self.action()))
    let without = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: nil))

    #expect(withButton.width > without.width)
  }

  @Test func aBarWithNoExplanationShowsNoExplanationLine() {
    let titleOnly = Self.message(.neutral, explanation: "")
    let withLine = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: nil))
    let without = StyleViewHost.fittingSize(of: StatusBar(message: titleOnly, action: nil))

    #expect(without.height < withLine.height)
  }

  @Test func aMessageKeepsItsAccessibilityLabelAndItsSymbolHelp() {
    let message = StatusBar.Message(
      title: "Title", explanation: "Explanation", symbolName: EditorSymbol.severity(.information).systemImage,
      identifier: "message",
      accessibilityLabel: "Warning, Title", symbolHelp: "Warning")

    #expect(message.accessibilityLabel == "Warning, Title")
    #expect(message.symbolHelp == "Warning")
  }
}
