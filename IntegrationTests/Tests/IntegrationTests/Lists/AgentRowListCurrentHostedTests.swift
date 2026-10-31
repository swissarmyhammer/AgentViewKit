import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// Which init of ``AgentRowList`` a bed mounts.
private enum BedLayout: CaseIterable, Sendable {
  case flat
  case sectioned
}

/// Where a bed puts the context menu of a row.
private enum BedRowMenu {
  case none
  case onContent
  case aroundRow
}

/// The id of the current row of a bed, which a test changes after the mount.
@MainActor @Observable private final class BedCurrent {
  var id: String?

  init(id: String?) {
    self.id = id
  }
}

/// A context menu that reads the path of its scope from the environment, as
/// the `.itemContextMenu()` of a host does, and the item of its row.
private struct RowScopeMenu: ViewModifier {
  /// The item of the row.
  let item: String

  @Environment(\.commandScopePath) private var path

  func body(content: Content) -> some View {
    content.contextMenu {
      Button(Self.itemTitle(item)) {}
      Button(Self.scopeTitle(path?.segments.last?.id)) {}
    }
  }

  /// The title of the row of the menu that names the item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The title.
  static func itemTitle(_ item: String) -> String {
    "item \(item)"
  }

  /// The title of the row of the menu that names the last segment of the scope.
  ///
  /// - Parameter id: The id of the segment.
  /// - Returns: The title.
  static func scopeTitle(_ id: String?) -> String {
    "scope \(id ?? "none")"
  }
}

/// The list of a bed: three rows that open on a click, by the flat or the
/// sectioned init.
private struct BedList: View {
  let layout: BedLayout
  let density: AgentRowDensity
  let rowMenu: BedRowMenu
  let current: BedCurrent
  let open: (String) -> Void

  var body: some View {
    switch layout {
    case .flat:
      wrapped(
        AgentRowList(
          RowBed.ids, id: \.self, scope: RowBed.scope, openOn: .click, density: density, current: current.id,
          onOpen: open, row: content(of:)))
    case .sectioned:
      wrapped(
        AgentRowList(
          sections: RowBed.sections, id: \.self, scope: RowBed.scope, openOn: .click, density: density,
          current: current.id, onOpen: open, row: content(of:)))
    }
  }

  /// `list`, with the menu around each row when the bed asks for it.
  ///
  /// - Parameter list: The list.
  /// - Returns: The list.
  @ViewBuilder private func wrapped<Row: View>(_ list: AgentRowList<String, Row, EmptyView>) -> some View {
    switch rowMenu {
    case .none, .onContent: list
    case .aroundRow: list.wrappingRows { row, id in row.modifier(RowScopeMenu(item: id)) }
    }
  }

  /// The content of the row with `id`, with the menu on it when the bed asks
  /// for it.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The content.
  @ViewBuilder private func content(of id: String) -> some View {
    switch rowMenu {
    case .none, .aroundRow: Text(id).accessibilityIdentifier(id)
    case .onContent: Text(id).accessibilityIdentifier(id).modifier(RowScopeMenu(item: id))
    }
  }
}

/// The window of one test: three rows that open on a click, beside a scope that
/// stands for the tab of the host, in a real key window off the screen.
@MainActor private struct RowBed {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second", "third"]

  /// The same rows, in two sections.
  static let sections = [
    AgentRowSection(id: "top", title: "Top", items: Array(ids.prefix(1))),
    AgentRowSection(id: "rest", title: "Rest", items: Array(ids.dropFirst())),
  ]

  /// The size of the window.
  static let size = CGSize(width: 300, height: 300)

  /// The list of the bed.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "currentList"), rowKind: "currentRow")

  /// The path of the scope of the tab.
  static let tabPath = FocusPath.root(FocusSegment(kind: "currentTab"))

  /// The density of the list.
  let density: AgentRowDensity

  /// The command system of the window.
  let system = CommandSystem()

  /// The id of each open, in order.
  let opened = ReportRecorder<String>()

  /// The id of the current row.
  let current: BedCurrent

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Mounts the list and the tab, and makes the window key.
  ///
  /// - Parameters:
  ///   - layout: The init of the list.
  ///   - density: The density of the list.
  ///   - current: The id of the current row, or `nil`.
  ///   - rowMenu: Where the context menu of a row stands.
  init(
    layout: BedLayout = .flat, density: AgentRowDensity = .regular, current currentID: String? = nil,
    rowMenu: BedRowMenu = .none
  ) async throws {
    let current = BedCurrent(id: currentID)
    let report = opened.report
    self.density = density
    self.current = current
    harness = HostedViewHarness(
      AnyView(
        HStack {
          BedList(layout: layout, density: density, rowMenu: rowMenu, current: current) { report($0) }
          Color.clear.commandScope(segment: Self.tabPath.segments[0])
        }
        .commandSystem(system)),
      size: Self.size)
    harness.window.makeKeyAndOrderFront(nil)
    await RunLoopBlockFence.afterPendingBlocks()
    try #require(waitForLiveBeacons([Self.tabPath] + Self.ids.map(Self.path(ofRow:)), in: system))
  }

  /// The path of the scope of the row with `id`.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The path of the row.
  static func path(ofRow id: String) -> FocusPath {
    FocusPath.root(scope.list).appending(scope.rowSegment(for: id))
  }

  /// Gives the focus to the scope at `path`, and lets the window publish it.
  ///
  /// - Parameter path: The path of the scope.
  func focus(_ path: FocusPath) async throws {
    try #require(system.geometry.requestFocus(at: path))
    await settle()
  }

  /// Makes the row with `id` the current row.
  ///
  /// - Parameter id: The id of the row, or `nil`.
  func setCurrent(_ id: String?) async {
    current.id = id
    await settle()
  }

  /// Lets the updates of SwiftUI land, and renders.
  func settle() async {
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
  }

  /// Tells if the scope at `path` holds the first responder of the window.
  ///
  /// - Parameter path: The path of the scope.
  /// - Returns: `true` while the scope has the focus.
  func holdsFocus(_ path: FocusPath) -> Bool {
    let responder = harness.window.firstResponder as? NSView
    let frame = responder.flatMap { WindowSpace.rect(of: $0) }
    return frame != nil && system.geometry.rect(of: path) == frame
  }

  /// Tells if VoiceOver hears the row with `id` as selected.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: `true` when the element of the row has the selected trait.
  func reportsSelected(_ id: String) throws -> Bool {
    try #require(harness.element(identifier: id)).isSelected
  }

  /// A point in the top inset of the row with `id`, outside its content, in
  /// window coordinates.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The point.
  func topInsetPoint(ofRow id: String) throws -> NSPoint {
    let row = try #require(system.geometry.rect(of: Self.path(ofRow: id)))
    let inset = density.rowInsets(in: .default).top / 2
    return NSPoint(x: row.midX, y: harness.window.frame.height - (row.minY + inset))
  }
}

/// The densities of a test that runs for each of them.
private nonisolated let densities: [AgentRowDensity] = [.regular, .compact]

/// `current:` of ``AgentRowList``: the row the host names wears the selection,
/// with no move of the focus. One row of a list wears the fill, and the ring of
/// the focus stands on the focused row.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListCurrentHostedTests {
  @Test(arguments: BedLayout.allCases, densities)
  fileprivate func theCurrentRowReportsSelected(layout: BedLayout, density: AgentRowDensity) async throws {
    let bed = try await RowBed(layout: layout, density: density, current: RowBed.ids[1])
    defer { bed.harness.close() }

    #expect(try bed.reportsSelected(RowBed.ids[1]))
  }

  @Test(arguments: BedLayout.allCases, densities)
  fileprivate func theOtherRowsDoNotReportSelected(layout: BedLayout, density: AgentRowDensity) async throws {
    let bed = try await RowBed(layout: layout, density: density, current: RowBed.ids[1])
    defer { bed.harness.close() }

    #expect(try !bed.reportsSelected(RowBed.ids[0]))
    #expect(try !bed.reportsSelected(RowBed.ids[2]))
  }

  @Test func theCurrentRowLeavesTheFocusOnTheTab() async throws {
    let bed = try await RowBed()
    defer { bed.harness.close() }
    try await bed.focus(RowBed.tabPath)

    await bed.setCurrent(RowBed.ids[1])

    #expect(try bed.reportsSelected(RowBed.ids[1]))
    #expect(bed.holdsFocus(RowBed.tabPath))
  }

  @Test func theCurrentRowLeavesTheFocusOnAnotherRow() async throws {
    let bed = try await RowBed(current: RowBed.ids[1])
    defer { bed.harness.close() }

    try await bed.focus(RowBed.path(ofRow: RowBed.ids[0]))

    #expect(bed.holdsFocus(RowBed.path(ofRow: RowBed.ids[0])))
    #expect(try bed.reportsSelected(RowBed.ids[1]))
  }

  /// One row of a list is the selection: the focused row keeps the ring and
  /// leaves the fill and the trait to the current row.
  @Test func theFocusedRowIsNotSelectedWhileAnotherRowIsCurrent() async throws {
    let bed = try await RowBed(current: RowBed.ids[1])
    defer { bed.harness.close() }

    try await bed.focus(RowBed.path(ofRow: RowBed.ids[0]))

    #expect(try !bed.reportsSelected(RowBed.ids[0]))
  }

  @Test func aFocusedCurrentRowReportsSelected() async throws {
    let bed = try await RowBed(current: RowBed.ids[1])
    defer { bed.harness.close() }

    try await bed.focus(RowBed.path(ofRow: RowBed.ids[1]))

    #expect(try bed.reportsSelected(RowBed.ids[1]))
    #expect(bed.holdsFocus(RowBed.path(ofRow: RowBed.ids[1])))
  }

  @Test func theMarkFollowsTheCurrentID() async throws {
    let bed = try await RowBed(current: RowBed.ids[0])
    defer { bed.harness.close() }

    await bed.setCurrent(RowBed.ids[2])

    #expect(try !bed.reportsSelected(RowBed.ids[0]))
    #expect(try bed.reportsSelected(RowBed.ids[2]))
  }

  @Test func anIDOfNoRowMarksNoRow() async throws {
    let bed = try await RowBed(current: "gone")
    defer { bed.harness.close() }

    #expect(try RowBed.ids.allSatisfy { try !bed.reportsSelected($0) })
  }

  /// The default stays: with no current row the selection follows the focus.
  @Test func byDefaultTheFocusedRowIsSelected() async throws {
    let bed = try await RowBed()
    defer { bed.harness.close() }

    try await bed.focus(RowBed.path(ofRow: RowBed.ids[1]))

    #expect(try bed.reportsSelected(RowBed.ids[1]))
  }

  /// The content of a row of a host is often one element of its own, as a
  /// session row is, so the trait of the surface must reach that element.
  @Test func aRowThatIsOneElementReportsSelected() throws {
    let harness = HostedViewHarness {
      AgentRowList(RowBed.ids, id: \.self, scope: RowBed.scope, current: RowBed.ids[1]) { id in
        Text(id).accessibilityElement(children: .combine).accessibilityIdentifier(id)
      }
    }
    defer { harness.close() }

    #expect(try #require(harness.element(identifier: RowBed.ids[1])).isSelected)
  }

  @Test func aClickLeavesTheMarkToTheHost() async throws {
    let bed = try await RowBed(current: RowBed.ids[1])
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.topInsetPoint(ofRow: RowBed.ids[0]))
    await bed.settle()

    #expect(bed.opened.values == [RowBed.ids[0]])
    #expect(try bed.reportsSelected(RowBed.ids[1]))
  }
}

/// `.wrappingRows(_:)` of ``AgentRowList``: a context menu around the row covers
/// the area that a click covers, inset included.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListRowMenuHostedTests {
  /// The gap that the wrapper closes: a menu on the content of a row stops at
  /// the content, so the point of the other tests lands outside it.
  @Test func aMenuOnTheContentLeavesTheInsetBare() async throws {
    let bed = try await RowBed(rowMenu: .onContent)
    defer { bed.harness.close() }

    #expect(try bed.harness.contextMenu(at: bed.topInsetPoint(ofRow: RowBed.ids[0])) == nil)
  }

  @Test(arguments: BedLayout.allCases, densities)
  fileprivate func theMenuCoversTheInset(layout: BedLayout, density: AgentRowDensity) async throws {
    let bed = try await RowBed(layout: layout, density: density, rowMenu: .aroundRow)
    defer { bed.harness.close() }
    let id = RowBed.ids[1]

    let titles = try bed.harness.contextMenu(at: bed.topInsetPoint(ofRow: id))?.items.map(\.title) ?? []

    #expect(titles.contains(RowScopeMenu.itemTitle(id)))
  }

  /// A menu that reads `\.commandScopePath`, as `.itemContextMenu()` does,
  /// stands inside the scope of the row.
  @Test func theWrapperStandsInTheScopeOfTheRow() async throws {
    let bed = try await RowBed(rowMenu: .aroundRow)
    defer { bed.harness.close() }
    let id = RowBed.ids[0]

    let titles = try bed.harness.contextMenu(at: bed.topInsetPoint(ofRow: id))?.items.map(\.title) ?? []

    #expect(titles.contains(RowScopeMenu.scopeTitle(RowBed.scope.rowSegment(for: id).id)))
  }

  @Test func aClickOnTheInsetStillOpensAWrappedRow() async throws {
    let bed = try await RowBed(rowMenu: .aroundRow)
    defer { bed.harness.close() }

    try await bed.harness.sendClick(atWindowPoint: bed.topInsetPoint(ofRow: RowBed.ids[0]))
    await bed.settle()

    #expect(bed.opened.values == [RowBed.ids[0]])
  }

  @Test func aWrappedRowStaysACurrentRow() async throws {
    let bed = try await RowBed(current: RowBed.ids[1], rowMenu: .aroundRow)
    defer { bed.harness.close() }

    #expect(try bed.reportsSelected(RowBed.ids[1]))
  }
}
