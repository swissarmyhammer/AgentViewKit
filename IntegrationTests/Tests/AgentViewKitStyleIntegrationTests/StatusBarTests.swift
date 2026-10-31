import AgentViewKitStyle
import EditorStyle
import EditorTestSupport
import EditorTheme
import SwiftUI
import Testing

/// Checks the status bar through its public API: the message and its
/// severity, the color of the symbol, the action and the style of its button.
@Suite @MainActor struct StatusBarTests {
  /// A theme with the default role colors.
  static let theme = UIFamilyTheme()

  /// Makes a message of `severity`.
  ///
  /// - Parameter severity: The severity of the message.
  /// - Returns: The message.
  static func message(_ severity: StatusBar.Message.Severity) -> StatusBar.Message {
    StatusBar.Message(
      title: "Title", explanation: "Explanation", symbolName: SharedSymbol.information, identifier: "message",
      severity: severity)
  }

  /// Makes an action that takes a press.
  ///
  /// - Parameter hint: The accessibility hint of the action.
  /// - Returns: The action.
  static func action(hint: String? = nil) -> StatusBar.Action {
    StatusBar.Action(
      title: "Reload", systemImage: SharedSymbol.reload, identifier: "reload", isEnabled: true, hint: hint,
      perform: {})
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
      title: "Title", explanation: "Explanation", symbolName: SharedSymbol.information, identifier: "message")

    #expect(message.severity == .neutral)
    #expect(!message.isOngoing)
  }

  @Test func theSymbolColorComesFromTheSeverity() {
    let colors: [(StatusBar.Message.Severity, Color)] = [
      (.neutral, .secondary), (.information, Self.theme.severityInfo), (.warning, Self.theme.severityWarning),
      (.failure, Self.theme.severityError),
    ]

    for (severity, color) in colors {
      #expect(StatusBar.symbolColor(for: Self.message(severity), in: Self.theme) == color, "\(severity)")
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
      title: "Dismiss", systemImage: SharedSymbol.dismiss, identifier: "dismiss", isEnabled: true, perform: {})
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
    let titleOnly = StatusBar.Message(
      title: "Title", explanation: "", symbolName: SharedSymbol.information, identifier: "message")
    let withLine = StyleViewHost.fittingSize(of: StatusBar(message: Self.message(.neutral), action: nil))
    let without = StyleViewHost.fittingSize(of: StatusBar(message: titleOnly, action: nil))

    #expect(without.height < withLine.height)
  }

  @Test func aMessageKeepsItsAccessibilityLabelAndItsSymbolHelp() {
    let message = StatusBar.Message(
      title: "Title", explanation: "Explanation", symbolName: SharedSymbol.information, identifier: "message",
      accessibilityLabel: "Warning, Title", symbolHelp: "Warning")

    #expect(message.accessibilityLabel == "Warning, Title")
    #expect(message.symbolHelp == "Warning")
  }

  @Test func aStatusSymbolTakesTheSizeOfItsSymbol() {
    let size = StyleViewHost.fittingSize(
      of: StatusSymbolImage(name: SharedSymbol.error, color: .secondary).liveSymbolEffect(isActive: true))

    #expect(size.width > 0)
    #expect(size.height > 0)
  }
}
