import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The controls of Jump to Session: the filter field is a kit one-line
/// field, which is the EditorKit `SingleLineField`, and each row is an
/// EditorKit `EditorPlainButton` (Docs/decisions/focus-audit.md, "Raw
/// controls").
///
/// Each test lays out the list in a window that is never ordered in
/// (``ControlProbe``), and reads the accessibility element of the field or
/// of a row. The layout tests read the frames of the rows of a list of long
/// paths at a narrow width (^vkcj2qh).
@MainActor @Suite struct SessionJumpListFieldTests {
  /// A jump list with no entries.
  static var list: SessionJumpList { SessionJumpList(agent: nil, entries: []) { _ in } }

  /// A production change that fails this test: the filter field is a
  /// system `TextField`, whose element is a text field, in place of the
  /// text view of an EditorKit field, whose element is a text area.
  @Test func theFilterFieldIsTheTextViewOfAnEditorKitField() async {
    let role = await ControlProbe.read(SessionJumpList.fieldIdentifier, in: Self.list, accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.textArea.rawValue)
  }

  /// A production change that fails this test: the filter field draws its
  /// text in a font that is not the `display` face of the theme, the face of
  /// the text that a person writes.
  @Test func theFilterFieldTakesTheDisplayFaceOfTheTheme() async throws {
    let frames = try #require(
      await ControlProbe.frames(of: SessionJumpList.fieldIdentifier, in: Self.list, enlarging: .display))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// The id of the child session of the row test.
  static let child = SessionId(rawValue: "child")

  /// The title of the child session of the row test.
  static let childTitle = "Child"

  /// A production change that fails this test: a row of the list is a plain
  /// system `Button` in place of the EditorKit `EditorPlainButton`, so the
  /// path of the row does not take the caption style of the button tokens
  /// of the theme.
  @Test func aRowTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.announceChild(Self.child, title: Self.childTitle)
    let entry = try #require(session.model.jumpEntries.first)
    let row = SessionJumpRow(entry: entry, agent: nil) { _ in }

    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(
        of: SessionJumpList.rowIdentifier(for: entry.sessionId), in: row))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// A jump list with the entry of one child session, and the id of each
  /// session that a press of a row chooses.
  struct ChildList {
    /// The list.
    let list: SessionJumpList

    /// The entry of the child session.
    let entry: SessionPathEntry

    /// The ids that the list chose, in order.
    let chosen: ChosenSessions
  }

  /// The ids of the sessions that a jump list chose.
  @MainActor final class ChosenSessions {
    /// The ids, in order.
    var ids: [SessionId] = []
  }

  /// Opens a scripted session with one child, and makes the jump list of
  /// its entries.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The list, the entry of the child, and the record of the
  ///   chosen ids.
  static func childList(in session: ScriptedSession) async throws -> ChildList {
    try await session.announceChild(child, title: childTitle)
    let entry = try #require(session.model.jumpEntries.first)
    let chosen = ChosenSessions()
    let list = SessionJumpList(agent: nil, entries: [entry]) { chosen.ids.append($0) }
    return ChildList(list: list, entry: entry, chosen: chosen)
  }

  /// A production change that fails this test: the rows stand in a SwiftUI
  /// `List`, whose native table draws its own focus ring and selection fill,
  /// in place of EditorKit's `EditorSelectionList`.
  @Test func theRowsStandInNoNativeTable() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await Self.childList(in: session)

    let hasTable = await ControlProbe.laysOutATable(child.list)

    #expect(!hasTable)
  }

  /// A production change that fails this test: the selection list of the
  /// rows combines a row into an element that loses the identifier of the
  /// row, or the press of the row, so a person or a test cannot choose the
  /// session.
  @Test func aPressOnTheRowOfTheListChoosesItsSession() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await Self.childList(in: session)

    _ = await ControlProbe.read(
      SessionJumpList.rowIdentifier(for: child.entry.sessionId), in: child.list
    ) { try? performAccessibilityPress(on: $0) }

    #expect(child.chosen.ids == [child.entry.sessionId])
  }

  /// The width of the list of the layout tests: the least width of the list,
  /// so each long path is wider than its row.
  static let narrowWidth = SessionJumpList.minimumWidth

  /// The height of the window of the layout tests, in points: tall enough
  /// for each row of the fixture tree, so the lazy stack of the list makes
  /// each row.
  static let narrowHeight: CGFloat = 720

  /// The size of the window of the layout tests.
  static let narrowSize = CGSize(width: narrowWidth, height: narrowHeight)

  /// The most that a frame of a laid-out view differs from the size that
  /// its layout gives, in points: the layout rounds each frame to the pixel
  /// grid.
  static let layoutRounding: CGFloat = 1

  /// The frame of one row of the list, and the frame of its label.
  struct RowFrames {
    /// The frame of the row in the selection list.
    let row: CGRect

    /// The frame that the label of the row needs: the size of a
    /// ``SessionJumpRow`` at the width of the row, with no limit on its
    /// height, at the origin of the row.
    let label: CGRect

    /// Whether the label stands inside the row, to ``layoutRounding``.
    var holdsItsLabel: Bool {
      row.insetBy(dx: -layoutRounding, dy: -layoutRounding).contains(label)
    }
  }

  /// Lays out the jump list of ``SessionJumpListFixtures`` at
  /// ``narrowSize``, and reads the frame of each row and of its label.
  ///
  /// - Returns: The frames of each row, in the order of the entries.
  /// - Throws: An issue when the tree does not give each entry, or the list
  ///   does not show the row of an entry.
  static func narrowRowFrames() async throws -> [RowFrames] {
    let session = try await SessionJumpListFixtures.openSession()
    defer { session.close() }
    let entries = session.model.jumpEntries
    try #require(entries.count == SessionJumpListFixtures.children.count)
    let list = SessionJumpList(agent: SessionJumpListFixtures.agent, entries: entries) { _ in }
    let rows = await ControlProbe.host(list, size: narrowSize) { hosting in
      entries.map { rowFrame(of: SessionJumpList.rowIdentifier(for: $0.sessionId), under: hosting) }
    }
    return try zip(entries, rows).map { entry, row in
      let row = try #require(row)
      return RowFrames(row: row, label: CGRect(origin: row.origin, size: labelSize(of: entry, width: row.width)))
    }
  }

  /// The frame of the row of the selection list that holds the element
  /// `identifier`: the parent element of the element of the
  /// ``SessionJumpRow``.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element of the
  ///     ``SessionJumpRow``.
  ///   - hosting: The hosting view of the list.
  /// - Returns: The frame, or `nil` when no single element has the
  ///   identifier, or its row has no frame.
  static func rowFrame(of identifier: String, under hosting: NSView) -> CGRect? {
    let elements = accessibilityElements(identifiedAs: identifier, under: hosting, includingScrollAreas: true)
    guard elements.count == 1, let row = elements.first.flatMap(accessibilityParent(of:)) else { return nil }
    return accessibilityFrame(of: row)
  }

  /// The size of the ``SessionJumpRow`` of `entry` at `width`, with no limit
  /// on its height: the size that its path text and its state text need.
  ///
  /// - Parameters:
  ///   - entry: The path entry of the row.
  ///   - width: The width of the row, in points.
  /// - Returns: The size.
  static func labelSize(of entry: SessionPathEntry, width: CGFloat) -> CGSize {
    let row = SessionJumpRow(entry: entry, agent: SessionJumpListFixtures.agent) { _ in }
    return NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: width, height: .infinity))
  }

  /// The name of the selector through which an element answers its parent.
  static let parentSelector = "accessibilityParent"

  /// The parent element of `node`.
  ///
  /// A SwiftUI element answers the selector with no formal conformance, so
  /// the read goes through `perform`.
  ///
  /// - Parameter node: The element.
  /// - Returns: The parent, or `nil` when the element answers none.
  static func accessibilityParent(of node: NSObject) -> NSObject? {
    let selector = NSSelectorFromString(parentSelector)
    guard node.responds(to: selector) else { return nil }
    return node.perform(selector)?.takeUnretainedValue() as? NSObject
  }

  /// A production change that fails this test: the rows stand in a container
  /// that lays them out on top of each other, such as a `ZStack`, in place of
  /// the lazy stack of EditorKit's `EditorSelectionList`.
  ///
  /// A fixed row height that is too small does not fail this test: the
  /// stack puts each row frame after the frame before it. That change fails
  /// ``eachLabelFrameStaysInsideItsRowAtANarrowWidth()``.
  @Test func noTwoRowFramesOverlapAtANarrowWidth() async throws {
    let rows = try await Self.narrowRowFrames().map(\.row)

    let overlapping = rows.indices.flatMap { first in
      rows.indices.filter { $0 > first && rows[first].intersects(rows[$0]) }.map { (first, $0) }
    }

    #expect(overlapping.isEmpty, "rows that overlap: \(overlapping)")
  }

  /// A production change that fails this test: a row of the list has a
  /// fixed height that is less than the height of its label, so the label
  /// stands out of its row.
  @Test func eachLabelFrameStaysInsideItsRowAtANarrowWidth() async throws {
    let frames = try await Self.narrowRowFrames()

    let outside = frames.indices.filter { !frames[$0].holdsItsLabel }

    #expect(outside.isEmpty, "rows whose label stands out: \(outside)")
  }
}
