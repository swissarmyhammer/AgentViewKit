import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The window of one test: a sectioned list that opens its rows on one click, in
/// a real key window off the screen.
@MainActor private struct SectionBed {
  /// The section of the first rows.
  static let pinned = AgentRowSection(id: "pinned", title: "Pinned", items: ["pinnedRow"])

  /// The section of the last rows.
  static let recent = AgentRowSection(id: "recent", title: "Recent", items: ["recentOne", "recentTwo"])

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "sectionList"), rowKind: "sectionRow")

  /// The size of the window.
  static let size = CGSize(width: 300, height: 300)

  /// The most turns of the run loop that a move may take to land.
  static let landingTurns = 500

  /// The command system of the window.
  let system = CommandSystem()

  /// The id of each open, in order.
  let opened = ReportRecorder<String>()

  /// The id of each row that the list built, in order.
  let built = ReportRecorder<String>()

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts a compact list of `sections` and makes the window key.
  ///
  /// - Parameters:
  ///   - sections: The sections of the list.
  ///   - style: The style of the window.
  init(sections: [AgentRowSection<String>] = [pinned, recent], style: EditorStyle = .default) async {
    let reportOpen = opened.report
    let reportBuilt = built.report
    harness = HostedViewHarness(
      AnyView(
        AgentRowList(
          sections: sections, id: \.self, scope: Self.scope, openOn: .click, density: .compact,
          onOpen: { reportOpen($0) }
        ) { id in
          Text(id).accessibilityIdentifier(id).onAppear { reportBuilt(id) }
        }
        .environment(\.editorStyle, style)
        .commandSystem(system)),
      size: Self.size)
    harness.window.makeKeyAndOrderFront(nil)
    await RunLoopBlockFence.afterPendingBlocks()
  }

  /// The path of the scope of the row with `id`.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The path of the row.
  static func path(ofRow id: String) -> FocusPath {
    FocusPath.root(scope.list).appending(scope.rowSegment(for: id))
  }

  /// Gives the focus to the row with `id`.
  ///
  /// - Parameter id: The id of the row.
  func select(_ id: String) throws {
    try #require(waitForLiveBeacons([Self.path(ofRow: id)], in: system))
    try #require(system.geometry.requestFocus(at: Self.path(ofRow: id)))
    harness.render()
  }

  /// Sends one press of `key`, and lets the reveal of a stalled move land.
  ///
  /// - Parameter key: The key.
  func press(_ key: KeyEquivalent) async throws {
    try harness.sendKey(key)
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
  }

  /// Tells if the scope of the row with `id` holds the first responder.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: `true` while the row is selected.
  func isSelected(_ id: String) -> Bool {
    let responder = harness.window.firstResponder as? NSView
    let frame = responder.flatMap { WindowSpace.rect(of: $0) }
    return frame != nil && system.geometry.rect(of: Self.path(ofRow: id)) == frame
  }

  /// Clicks the center of the element with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier.
  func click(_ identifier: String) async throws {
    let frame = try #require(harness.frame(identifier: identifier))
    let point = harness.window.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
    try await harness.sendClick(atWindowPoint: point)
  }

  /// The frame of the header of `section`, or `nil` when it does not show.
  ///
  /// - Parameter section: The section.
  /// - Returns: The frame.
  func headerFrame(of section: AgentRowSection<String>) -> CGRect? {
    harness.frame(identifier: AgentRowSectionHeader.identifier(for: section.id))
  }

  /// Tells if the header of `section` stands inside the window.
  ///
  /// - Parameter section: The section.
  /// - Returns: `true` while the whole header shows.
  func showsHeader(of section: AgentRowSection<String>) -> Bool {
    headerFrame(of: section).map(harness.window.frame.contains) ?? false
  }

  /// Tells if the row with `id` stands inside the window.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: `true` while the whole row shows.
  func showsRow(_ id: String) -> Bool {
    harness.frame(identifier: id).map(harness.window.frame.contains) ?? false
  }

  /// Sends one press of `key` for each of `ids`, and waits until each press
  /// lands on its row: a move past the rows that the lazy stack made commits in
  /// a task of the nav controller, after the press returns.
  ///
  /// - Parameters:
  ///   - key: The key.
  ///   - ids: The id of the row each press lands on, in order.
  func walk(_ key: KeyEquivalent, through ids: some Sequence<String>) async throws {
    for id in ids {
      try await press(key)
      try #require(await landed(on: id), "the move never reached \(id)")
    }
  }

  /// Waits until the row with `id` is selected.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: `true` when it is selected within the limit of turns.
  private func landed(on id: String) async -> Bool {
    for _ in 0..<Self.landingTurns where !isSelected(id) {
      await RunLoopBlockFence.afterPendingBlocks()
      harness.render()
    }
    return isSelected(id)
  }
}

/// The sections of ``AgentRowList``: a header above the rows of each section
/// that has rows, in one lazy stack whose rows act as the rows of a flat list.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListSectionsHostedTests {
  /// The role that `.isHeader` gives a text; a plain text is `AXStaticText`.
  static let headingRole = "AXHeading"

  /// The rows of a section that does not fit in the window.
  ///
  /// - Parameters:
  ///   - id: The id of the section.
  ///   - count: The number of rows.
  /// - Returns: The section.
  static func longSection(_ id: String, count: Int) -> AgentRowSection<String> {
    AgentRowSection(id: id, title: id, items: (0..<count).map { "\(id)\($0)" })
  }

  @Test func eachHeaderStandsAboveTheRowsOfItsSection() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }

    let tops = [
      try #require(bed.headerFrame(of: SectionBed.pinned)),
      try #require(bed.harness.frame(identifier: SectionBed.pinned.items[0])),
      try #require(bed.headerFrame(of: SectionBed.recent)),
      try #require(bed.harness.frame(identifier: SectionBed.recent.items[0])),
    ].map(\.midY)

    #expect(tops == tops.sorted(by: >))
  }

  @Test func anEmptySectionShowsNoHeader() async throws {
    let empty = AgentRowSection<String>(id: "pinned", title: "Pinned", items: [])
    let bed = await SectionBed(sections: [empty, SectionBed.recent])
    defer { bed.harness.close() }

    #expect(bed.headerFrame(of: empty) == nil)
  }

  @Test func theSectionAfterAnEmptySectionKeepsItsHeader() async throws {
    let empty = AgentRowSection<String>(id: "pinned", title: "Pinned", items: [])
    let bed = await SectionBed(sections: [empty, SectionBed.recent])
    defer { bed.harness.close() }

    #expect(bed.headerFrame(of: SectionBed.recent) != nil)
  }

  @Test func voiceOverHearsTheHeaderAsAHeading() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }

    let header = bed.harness.element(identifier: AgentRowSectionHeader.identifier(for: SectionBed.pinned.id))

    #expect(header?.role == Self.headingRole)
    #expect(header?.label == SectionBed.pinned.title)
  }

  /// The header stands where the content of a row stands, so the two read as
  /// one column, and the inset of that column comes from the style. The content
  /// of a row reports the frame of the row, which starts at the edge of the list.
  @Test func theHeaderLinesUpWithTheContentOfARow() async throws {
    var style = EditorStyle.default
    style.spacing.s *= 2
    let bed = await SectionBed(style: style)
    defer { bed.harness.close() }

    let header = try #require(bed.headerFrame(of: SectionBed.pinned))
    let row = try #require(bed.harness.frame(identifier: SectionBed.pinned.items[0]))

    #expect(header.minX == row.minX + style.spacing.s)
  }

  @Test func theDownArrowCrossesIntoTheNextSection() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }
    try bed.select(SectionBed.pinned.items[0])

    try await bed.press(.downArrow)

    #expect(bed.isSelected(SectionBed.recent.items[0]))
  }

  @Test func theUpArrowCrossesBackIntoTheSectionBefore() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }
    try bed.select(SectionBed.recent.items[0])

    try await bed.press(.upArrow)

    #expect(bed.isSelected(SectionBed.pinned.items[0]))
  }

  /// The first row of the next section is past what the lazy stack made, so
  /// the move reveals it across the header.
  @Test func theDownArrowRevealsTheFirstRowOfTheNextSection() async throws {
    let first = Self.longSection("first", count: 40)
    let second = Self.longSection("second", count: 40)
    let bed = await SectionBed(sections: [first, second])
    defer { bed.harness.close() }
    try bed.select(first.items[0])

    try await bed.walk(.downArrow, through: first.items.dropFirst() + second.items.prefix(1))

    #expect(bed.isSelected(second.items[0]))
  }

  @Test func theDownArrowShowsTheHeaderOfTheNextSection() async throws {
    let first = Self.longSection("first", count: 40)
    let second = Self.longSection("second", count: 40)
    let bed = await SectionBed(sections: [first, second])
    defer { bed.harness.close() }
    try bed.select(first.items[0])

    try await bed.walk(.downArrow, through: first.items.dropFirst() + second.items.prefix(1))

    #expect(bed.showsHeader(of: second))
    #expect(bed.showsRow(second.items[0]))
  }

  @Test func theUpArrowShowsTheHeaderOfTheSectionItLandsIn() async throws {
    let first = Self.longSection("first", count: 2)
    let second = Self.longSection("second", count: 40)
    let bed = await SectionBed(sections: [first, second])
    defer { bed.harness.close() }
    try bed.select(first.items[0])
    let rows = first.items + second.items.prefix(31)
    try await bed.walk(.downArrow, through: rows.dropFirst())

    try await bed.walk(.upArrow, through: rows.dropLast().reversed().prefix(30))

    #expect(bed.showsHeader(of: second))
    #expect(bed.showsRow(second.items[0]))
  }

  @Test func theUpArrowShowsTheHeaderOfTheFirstRowOfTheList() async throws {
    let first = Self.longSection("first", count: 40)
    let bed = await SectionBed(sections: [first])
    defer { bed.harness.close() }
    try bed.select(first.items[0])
    let rows = first.items.prefix(31)
    try await bed.walk(.downArrow, through: rows.dropFirst())

    try await bed.walk(.upArrow, through: rows.dropLast().reversed())

    #expect(bed.showsHeader(of: first))
    #expect(bed.showsRow(first.items[0]))
  }

  @Test func oneClickOpensARowOfTheSecondSection() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }

    try await bed.click(SectionBed.recent.items[1])

    #expect(bed.opened.values == [SectionBed.recent.items[1]])
  }

  @Test func returnOpensASelectedRowOfTheSecondSection() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }
    try bed.select(SectionBed.recent.items[0])

    try await bed.press(.return)

    #expect(bed.opened.values == [SectionBed.recent.items[0]])
  }

  @Test func aClickOnAHeaderOpensNothing() async throws {
    let bed = await SectionBed()
    defer { bed.harness.close() }

    try await bed.click(AgentRowSectionHeader.identifier(for: SectionBed.recent.id))

    #expect(bed.opened.values.isEmpty)
  }

  @Test func theRowsStayLazy() async throws {
    let first = Self.longSection("first", count: 200)
    let second = Self.longSection("second", count: 200)
    let bed = await SectionBed(sections: [first, second])
    defer { bed.harness.close() }

    #expect(bed.built.values.contains(first.items[0]))
    #expect(!bed.built.values.contains(second.items[0]))
  }
}
