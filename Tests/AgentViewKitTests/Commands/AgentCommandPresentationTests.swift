import EditorCommands
import EditorCommandsUI
import Testing

@testable import AgentViewKit

/// Tests for the shared definition of a kit command:
/// ``AgentCommandPresentation`` and
/// `CommandDefinition.init(_:target:isVisible:make:)`.
///
/// Each test makes a definition with no registry and no view. No test waits,
/// and no test shows a window.
@MainActor struct AgentCommandPresentationTests {
  /// The title of the presentation of the tests.
  static let title = "Close"

  /// The button title of the presentation of the tests.
  static let buttonTitle = "Close Card"

  /// Makes the presentation of the Close verb of a side card, with `key`
  /// and `buttonTitle`.
  ///
  /// - Parameters:
  ///   - key: The key of the presentation, or `nil`.
  ///   - buttonTitle: The button title of the presentation, or `nil`.
  /// - Returns: The presentation.
  static func makePresentation(
    key: KeyChord? = nil, buttonTitle: String? = nil
  ) -> AgentCommandPresentation {
    let verb = SideCardVerb.closeSideCard
    return AgentCommandPresentation(
      id: verb.id, title: title, buttonTitle: buttonTitle, icon: verb.icon, menu: verb.menu,
      contextMenu: verb.contextMenu, key: key)
  }

  /// Makes a definition of `presentation` whose command is a Close command
  /// of a side card target.
  ///
  /// - Parameters:
  ///   - presentation: The presentation.
  ///   - target: The target of the definition.
  /// - Returns: The definition.
  static func makeDefinition(
    _ presentation: AgentCommandPresentation, for target: SideCardTarget
  ) -> CommandDefinition {
    CommandDefinition(presentation, target: target) { target, _ in
      SideCardCommand(verb: .closeSideCard, target: target)
    }
  }

  /// Makes a definition for a target that goes away when the call returns.
  ///
  /// - Returns: The definition.
  static func makeDefinitionOfAGoneTarget() -> CommandDefinition {
    makeDefinition(makePresentation(), for: SideCardTarget())
  }

  @Test func theDefinitionHasTheIdAndTheTitleOfThePresentation() {
    let definition = Self.makeDefinition(Self.makePresentation(), for: SideCardTarget())

    #expect(definition.id == SideCardVerb.closeSideCard.id)
    #expect(AgentAttachmentCommandsTests.staticText(of: definition.title) == Self.title)
  }

  @Test func theDefinitionHasTheButtonTitleOfThePresentation() {
    let presentation = Self.makePresentation(buttonTitle: Self.buttonTitle)

    let definition = Self.makeDefinition(presentation, for: SideCardTarget())

    let buttonTitle = definition.buttonTitle.flatMap(AgentAttachmentCommandsTests.staticText(of:))
    #expect(buttonTitle == Self.buttonTitle)
  }

  @Test func theDefinitionHasTheIconAndThePlacesOfThePresentation() {
    let presentation = Self.makePresentation()

    let definition = Self.makeDefinition(presentation, for: SideCardTarget())

    #expect(definition.icon == presentation.icon)
    #expect(definition.menu == presentation.menu)
    #expect(definition.contextMenu == presentation.contextMenu)
  }

  @Test func theKeyOfThePresentationIsTheCuaKeyOfTheDefinition() {
    let definition = Self.makeDefinition(Self.makePresentation(key: .escape), for: SideCardTarget())

    #expect(definition.keys == [KeymapMode.cua: KeyChord.escape])
  }

  @Test func aPresentationWithNoKeyGivesNoKey() {
    let definition = Self.makeDefinition(Self.makePresentation(), for: SideCardTarget())

    #expect(definition.keys.isEmpty)
  }

  @Test func theCommandGetsTheTargetOfTheDefinition() {
    let target = SideCardTarget()
    let definition = Self.makeDefinition(Self.makePresentation(), for: target)

    let command = definition.make(nil) as? SideCardCommand

    #expect(command?.target === target)
  }

  /// The definition holds its target weakly, so a registry that outlives a
  /// scope does not keep the target of the scope.
  @Test func theDefinitionDoesNotKeepItsTarget() throws {
    let definition = Self.makeDefinitionOfAGoneTarget()

    let command = try #require(definition.make(nil) as? SideCardCommand)

    #expect(command.target == nil)
  }
}
