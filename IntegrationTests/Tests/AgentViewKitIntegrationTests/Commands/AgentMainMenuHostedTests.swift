@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the agent commands in the main menu of a window (D41).
///
/// Each test builds the real `NSMenu` of one top-level menu with the
/// EditorKit `NSMenuMirror`, at the path that has the focus, and opens it, as
/// AppKit does when the user opens the menu or presses a key equivalent. The
/// menu runs the same command as the context menu of the item.
///
/// A change that the test makes on the main actor is followed by one render
/// pass. A frame of the agent is followed by a wait for the model value that
/// the frame is certain to change, and then by one render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentMainMenuHostedTests {
  /// The virtual key code of the `C` key on an ANSI keyboard.
  static let cKeyCode: UInt16 = 0x08

  /// The modifiers of the Copy Message key equivalent:
  /// Control-Shift-Command.
  static let copyMessageModifiers: NSEvent.ModifierFlags = [.control, .shift, .command]

  /// Builds the `NSMenu` of `menuPath` at `path`, and fills it as AppKit
  /// does before the menu opens.
  ///
  /// - Parameters:
  ///   - menuPath: The top-level menu.
  ///   - path: The path that has the focus.
  ///   - system: The command system of the window.
  /// - Returns: The menu and its mirror. The menu holds its delegate weakly,
  ///   so the caller keeps the mirror.
  static func openMenu(
    _ menuPath: MenuPath, at path: FocusPath, in system: CommandSystem
  ) -> (menu: NSMenu, mirror: NSMenuMirror) {
    let mirror = NSMenuMirror(system: system, menuPath: menuPath) { path }
    let menu = NSMenu(title: menuPath.rawValue)
    menu.delegate = mirror
    mirror.menuNeedsUpdate(menu)
    return (menu, mirror)
  }

  /// The item of `verb` in `menu`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - menu: The menu.
  /// - Returns: The item, or `nil` when the menu does not show the verb.
  static func item(of verb: AgentCommandVerb, in menu: NSMenu) -> NSMenuItem? {
    menu.items.first { $0.title == verb.title }
  }

  /// Makes a key-down event of the `C` key with `modifiers`.
  ///
  /// - Parameter modifiers: The modifiers of the event.
  /// - Returns: The event.
  static func cKeyEvent(modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
    let characters = modifiers.contains(.shift) ? "C" : "c"
    return try #require(NSEvent.makeKeyEvent(characters: characters, keyCode: cKeyCode, modifiers: modifiers))
  }

  /// Shows a thread with one user message, and gives the focus to the row of
  /// the message.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  ///   - pasteboard: The pasteboard of the copy commands.
  /// - Returns: The harness and the path of the message that has the focus.
  static func focusMessage(
    of session: ScriptedSession, in system: CommandSystem, pasteboard: NSPasteboard
  ) async throws -> (harness: HostedViewHarness<some View>, path: FocusPath) {
    let harness = AgentCommandScopeHostedTests.mount(
      session: session, system: system, outerScope: false, pasteboard: pasteboard)
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
    let entry = try #require(session.model.transcript.first)
    let message = AgentCommandScopeHostedTests.path(of: session.model)
      .appending(AgentScopeKind.message(rowKey: entry.rowKey))
    try #require(system.geometry.requestFocus(at: message))
    let focused = AgentNavigationHostedTests.focusedItem(among: [message], in: system, window: harness.window)
    return (harness, try #require(focused))
  }

  // MARK: - Copy Message

  @Test func copyMessageInTheEditMenuCopiesTheFocusedMessage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let focused = try await Self.focusMessage(of: session, in: system, pasteboard: pasteboard)
      defer { focused.harness.close() }
      let edit = Self.openMenu(.edit, at: focused.path, in: system)
      let item = try #require(Self.item(of: .copyMessage, in: edit.menu))
      try #require(item.isEnabled)

      edit.menu.performActionForItem(at: edit.menu.index(of: item))

      #expect(pasteboard.string(forType: .string) == AgentCommandScopeHostedTests.message)
    }
  }

  @Test func copyMessageInTheEditMenuIsDisabledWithNoMessageFocused() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
    let thread = AgentCommandScopeHostedTests.path(of: session.model)

    let edit = Self.openMenu(.edit, at: thread, in: system)

    #expect(Self.item(of: .copyMessage, in: edit.menu)?.isEnabled == false)
  }

  @Test func theKeyEquivalentOfCopyMessageCopiesTheFocusedMessage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let focused = try await Self.focusMessage(of: session, in: system, pasteboard: pasteboard)
      defer { focused.harness.close() }
      let edit = Self.openMenu(.edit, at: focused.path, in: system)
      let event = try Self.cKeyEvent(modifiers: Self.copyMessageModifiers)

      try #require(edit.menu.performKeyEquivalent(with: event))

      #expect(pasteboard.string(forType: .string) == AgentCommandScopeHostedTests.message)
      let chord = try #require(KeyChordTranslator.chord(for: event))
      #expect(chord == AgentKeymap.defaultChords[.copyMessage]?.first)
      #expect(
        system.registry.resolveKey(chord.asSequence, mode: .cua, at: focused.path)
          == .command(AgentCommandVerb.copyMessage.id, scope: AgentCommandScopeHostedTests.path(of: session.model)))
    }
  }

  /// Command-C stays the Copy of the system Edit menu and of the text views:
  /// no agent row of the Edit menu takes it, and the scope binds no agent
  /// command to it.
  @Test func commandCDoesNotRunCopyMessage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let focused = try await Self.focusMessage(of: session, in: system, pasteboard: pasteboard)
      defer { focused.harness.close() }
      let edit = Self.openMenu(.edit, at: focused.path, in: system)
      let event = try Self.cKeyEvent(modifiers: .command)
      let chord = try #require(KeyChordTranslator.chord(for: event))

      #expect(!edit.menu.performKeyEquivalent(with: event))
      #expect(pasteboard.string(forType: .string) == nil)
      #expect(system.registry.resolveKey(chord.asSequence, mode: .cua, at: focused.path) == .unbound)
    }
  }

  // MARK: - Approve and Reject

  /// The option of ``ScriptedSession/permissionParams`` that `verb` selects.
  ///
  /// - Parameter verb: Approve Request or Reject Request.
  /// - Returns: The `optionId`.
  static func optionID(selectedBy verb: AgentCommandVerb) -> String {
    verb == .approvePending ? AgentCommandFixtures.allowOptionID : AgentCommandFixtures.rejectOptionID
  }

  @Test(arguments: [AgentCommandVerb.approvePending, .rejectPending])
  func theSessionMenuAnswersTheFocusedRequest(verb: AgentCommandVerb) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    // The deck is beside the thread view, so the outer scope puts the cards
    // in the scope of the thread.
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    let request = try await session.sendPermissionRequest(
      id: AgentCommandScopeHostedTests.agentRequestID, rendering: harness)
    let path = AgentCommandScopeHostedTests.path(of: session.model).appending(AgentScopeKind.request(request))
    let sessionMenu = Self.openMenu(.session, at: path, in: system)
    let item = try #require(Self.item(of: verb, in: sessionMenu.menu))
    try #require(item.isEnabled)

    sessionMenu.menu.performActionForItem(at: sessionMenu.menu.index(of: item))
    let result = await session.result(ofRequest: AgentCommandScopeHostedTests.agentRequestID)

    #expect(result?["outcome"]?["optionId"]?.stringValue == Self.optionID(selectedBy: verb))
  }
}
