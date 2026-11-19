import AppKit
import EditorCommands
import EditorCommandsUI
import Testing

@testable import AgentViewKit

/// The commands of one ``AgentRowList`` of two rows that open, registered in a
/// command system with no window.
@MainActor private final class KeysBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The path of the scope of the list.
  static let listPath = FocusPath.root(FocusSegment(kind: "keysList"))

  /// The segment kind of each row.
  static let rowKind = "keysRow"

  /// The path of the second row, which has the focus in each test.
  static let rowPath = listPath.appending(FocusSegment(kind: rowKind, id: ids[1]))

  /// The command system of the list.
  let system = CommandSystem()

  /// The target of the list.
  let target = AgentRowListTarget()

  /// The id of each row that the list opened, in order.
  private(set) var opened: [String] = []

  /// Registers the open command and the `nav.*` commands of the list.
  init() {
    target.rowKind = Self.rowKind
    target.listPath = Self.listPath
    target.rowIDs = Self.ids
    target.open = { [weak self] id in self?.opened.append(id) }
    AgentRowListRegistration.register(
      target, nav: NavModeController(system: system, scroller: target), at: Self.listPath,
      into: &system.registry)
  }

  /// Sends `chord` to the list as its key handler does, with the focus on
  /// the second row.
  ///
  /// - Parameters:
  ///   - chord: The chord of the key.
  ///   - firstResponder: The first responder of the window of the list.
  /// - Returns: `true` when the list took the key.
  func press(_ chord: KeyChord, firstResponder: NSResponder?) -> Bool {
    AgentRowListKeys.perform(
      chord, listPath: Self.listPath, focusedPath: Self.rowPath, firstResponder: firstResponder,
      in: system)
  }
}

/// The text view of a field in edit in a row.
@MainActor private func editingTextView() -> NSTextView {
  let textView = NSTextView()
  textView.isEditable = true
  return textView
}

/// An ``AgentRowList`` does not take the keys of a text field in edit in a
/// row, such as a rename field (D197 b). With no field in edit, it takes them
/// as before.
@MainActor struct AgentRowListKeysTests {
  @Test func returnWithAFieldInEditDoesNotOpenTheRow() {
    let bed = KeysBed()

    _ = bed.press(KeyChord.return, firstResponder: editingTextView())

    #expect(bed.opened.isEmpty)
  }

  /// `nav.drillOut` takes each Escape that reaches it, so a key that the
  /// list does not take did not run it.
  @Test func escapeWithAFieldInEditDoesNotDrillOut() {
    let bed = KeysBed()

    #expect(!bed.press(KeyChord.escape, firstResponder: editingTextView()))
  }

  @Test func returnWithNoFieldInEditOpensTheRow() {
    let bed = KeysBed()

    _ = bed.press(KeyChord.return, firstResponder: nil)

    #expect(bed.opened == [KeysBed.ids[1]])
  }

  @Test func escapeWithNoFieldInEditDrillsOut() {
    let bed = KeysBed()

    #expect(bed.press(KeyChord.escape, firstResponder: nil))
  }

  /// A text view that does not edit, such as a selectable label in a row,
  /// leaves Return to the list.
  @Test func returnWithAReadOnlyTextViewOpensTheRow() {
    let bed = KeysBed()
    let label = NSTextView()
    label.isEditable = false

    _ = bed.press(KeyChord.return, firstResponder: label)

    #expect(bed.opened == [KeysBed.ids[1]])
  }
}
