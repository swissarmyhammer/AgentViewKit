import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A right click on the text of an agent answer shows the item menu of the
/// message, not the text menu of AppKit (D108, D193 (f)).
///
/// The text of an answer is a read-only EditorKit `EditorView`
/// (``RenderedMarkdownView``) with `.editorTextMenu(.ancestor)`. Its text
/// view gives the menu of the nearest view above it that has one: the
/// context menu of the message scope. Each test registers two host commands
/// at the thread path, Inspect and Inspect in New Pane, as TestudoApp does.
/// The context menu of the message then shows them with Copy Message.
///
/// The area that the menu covers is under test, so a read hit-tests the
/// center of the text (`HostedViewHarness.contextMenu(identifier:)`). The
/// read makes a right mouse-down that it never posts, so the window stays
/// off the screen and not key. Each suite whose name ends in
/// `PointerHostedTests` holds such a hit test.
@Suite(.serialized, .hostedSerially) @MainActor struct AnswerTextContextMenuPointerHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 480, height: 400)

  /// The text of the answer.
  static let answer = "The parser reads each line of the file."

  /// The context menu group of the host commands.
  static let hostGroup = 9

  /// The host command that inspects the message.
  static let inspect = ThreadHeaderContextMenuHostedTests.HostCommand(
    id: "host.inspect", title: "Inspect", group: hostGroup)

  /// The host command that inspects the message in a new pane.
  static let inspectInNewPane = ThreadHeaderContextMenuHostedTests.HostCommand(
    id: "host.inspectInNewPane", title: "Inspect in New Pane", group: hostGroup)

  /// The titles of the item menu of a message.
  static let itemMenuTitles: Set<String> = [
    AgentCommandVerb.copyMessage.title, inspect.title, inspectInNewPane.title,
  ]

  /// The start of the title of the Look Up item of the AppKit text menu.
  static let lookUpPrefix = "Look Up"

  /// The title of the Font submenu of the AppKit text menu.
  static let fontTitle = "Font"

  /// Mounts a thread with one agent answer, with the host commands at the
  /// thread path.
  ///
  /// - Returns: The harness, after one render pass.
  static func mountAnswer() -> HostedViewHarness<some View> {
    let session = SessionModel.preview(transcript: [.agent(answer)])
    let system = CommandSystem()
    let log = CommandRunLog()
    let threadPath = AgentCommandScopeHostedTests.path(of: session)
    for command in [inspect, inspectInNewPane] {
      let id = command.id
      let definition = command.definition { _ in RunRecordingCommand(id: id, log: log) }
      system.registry.register(definition, at: threadPath)
    }
    let harness = HostedViewHarness(size: size) {
      AgentThreadView(session: session)
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The titles of the menu that a right click on the text of the answer
  /// shows.
  ///
  /// - Parameter harness: The mount of the answer.
  /// - Returns: The titles of the items, top to bottom.
  /// - Throws: An error when no element has the identifier of the text, or
  ///   when no view under the text gives a menu.
  static func menuTitles(in harness: HostedViewHarness<some View>) throws -> [String] {
    let menu = try #require(try harness.contextMenu(identifier: ResponseView.textIdentifier))
    return menu.items.map(\.title)
  }

  /// A production change that fails this test: the editor of the answer
  /// keeps the text menu of AppKit (`.system`), so the item menu does not
  /// show.
  @Test func aRightClickOnTheAnswerTextShowsTheItemMenu() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(in: harness)

    #expect(Self.itemMenuTitles.isSubset(of: titles))
  }

  /// A production change that fails this test: the editor of the answer
  /// adds the text menu of AppKit, so Look Up and Font show.
  @Test func aRightClickOnTheAnswerTextShowsNoItemOfTheTextMenu() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(in: harness)

    #expect(!titles.contains { $0.hasPrefix(Self.lookUpPrefix) || $0 == Self.fontTitle })
  }
}
