import EditorCommands
import EditorCommandsUI
import EditorStyle
import SwiftUI

/// The scope of an ``AgentRowList``: the segment of the list and the segment
/// kind of its rows.
///
/// The list adds its segment to the path of the enclosing command scope, and
/// each row adds `<rowKind>:<id>` to the path of the list. Give each list of
/// one window its own list segment, for example with the id of its model, so
/// that two lists do not share one path.
public struct AgentRowListScope: Hashable, Sendable {
  /// The segment of the list, such as `sessionList:<id>`.
  public let list: FocusSegment

  /// The segment kind of each row, such as `session`.
  public let rowKind: String

  /// Makes the scope of a list.
  ///
  /// - Parameters:
  ///   - list: The segment of the list.
  ///   - rowKind: The segment kind of each row.
  public init(list: FocusSegment, rowKind: String) {
    self.list = list
    self.rowKind = rowKind
  }

  /// The segment of the row with `id`.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The segment `<rowKind>:<id>`.
  public func rowSegment(for id: String) -> FocusSegment {
    FocusSegment(kind: rowKind, id: id)
  }
}

/// A list of rows whose selection and keys come from the command scopes of
/// EditorKit, its `nav.*` commands and its jump mode (EditorKit ^7wt12an: no
/// SwiftUI `List`).
///
/// The rows stand in a `LazyVStack` inside a `ScrollView`, which paints
/// nothing, so the list is transparent. Each row is a command scope
/// (``AgentRowListScope/rowSegment(for:)``), so a jump session of the host
/// labels it, and a jump to it selects it. The selected row is the row whose
/// scope is the focused scope of the window (`FocusedValues.commandPath`). It
/// sits on the shared selectable surface
/// (`.selectableSurface(_:corners:)`), the one place where the list paints the
/// accent. A click selects a row. Each row has the tile padding of the style
/// (`editorStyle.tile.padding`), and the rows have the tile margin between
/// them.
///
/// The list registers the `nav.*` commands of EditorKit at its own scope, so
/// the keys work in each host: the Down Arrow and the Up Arrow select the next
/// row and the row before, and Esc moves the focus out of the rows to the
/// list, which clears the selection. A move past the last row that the lazy
/// stack made scrolls to the next row. Return and a double click open the
/// selected row with `onOpen`. The list routes each key that reaches it at
/// the focused scope, when that scope is the list or a scope in it
/// (``SwiftUI/View/agentRowListKeys(listPath:focusedPath:)``). When no
/// ancestor installs a command system, the list uses one of its own.
///
/// The row content gives its own accessibility elements, so VoiceOver reads
/// each row as the content tells.
public struct AgentRowList<Item, Row: View, Footer: View>: View {
  /// The items of the rows, in list order.
  let items: [Item]

  /// The id of an item, which is the id of the segment of its row.
  let id: KeyPath<Item, String>

  /// The scope of the list.
  let scope: AgentRowListScope

  /// The action that opens an item, or `nil` for a list whose rows do not
  /// open.
  let onOpen: ((Item) -> Void)?

  /// The builder of the content of a row.
  let row: (Item) -> Row

  /// The view after the last row, such as a "Load More" button.
  let footer: Footer

  @Environment(\.commandSystem) private var ambientSystem
  @Environment(\.commandScopePath) private var parentPath
  @Environment(\.editorStyle) private var editorStyle

  /// The path of the leaf-most focused command scope of the window, which
  /// tells the selected row and where a key routes.
  @FocusedValue(\.commandPath) private var focusedPath

  /// The target of the commands of the list.
  @State private var target = AgentRowListTarget()

  /// The system that the list uses when no ancestor installs one.
  @State private var standaloneSystem = CommandSystem()

  /// Makes a list of rows with a view after the last row.
  ///
  /// - Parameters:
  ///   - items: The items of the rows, in list order.
  ///   - id: The id of an item. Each item of the list has its own id.
  ///   - scope: The scope of the list.
  ///   - onOpen: The action that Return and a double click run on the
  ///     selected item, or `nil` for a list whose rows do not open.
  ///   - row: The builder of the content of a row.
  ///   - footer: The builder of the view after the last row.
  public init(
    _ items: [Item], id: KeyPath<Item, String>, scope: AgentRowListScope, onOpen: ((Item) -> Void)? = nil,
    @ViewBuilder row: @escaping (Item) -> Row, @ViewBuilder footer: () -> Footer
  ) {
    self.items = items
    self.id = id
    self.scope = scope
    self.onOpen = onOpen
    self.row = row
    self.footer = footer()
  }

  public var body: some View {
    let system = ambientSystem ?? standaloneSystem
    let path = parentPath?.appending(scope.list) ?? .root(scope.list)
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: editorStyle.tile.margin) {
          ForEach(items, id: id) { item in
            rowView(for: item, at: path.appending(scope.rowSegment(for: item[keyPath: id])), in: system)
          }
          footer
        }
        .padding(editorStyle.tile.margin)
      }
      .background(AgentRowListMount(target: target, values: values(system: system, path: path, proxy: proxy)))
    }
    .commandScope(segment: scope.list)
    .scopeFocusRing(radius: AgentRowListLayout.radius)
    .agentRowListKeys(listPath: path, focusedPath: focusedPath)
    .commandSystem(system)
  }

  /// The row of `item`, selected while its scope is the focused scope.
  ///
  /// - Parameters:
  ///   - item: The item of the row.
  ///   - rowPath: The path of the scope of the row.
  ///   - system: The system that the list registers in, whose geometry
  ///     gives the focus to the row on a click.
  /// - Returns: The row.
  private func rowView(for item: Item, at rowPath: FocusPath, in system: CommandSystem) -> some View {
    AgentRowListRow(
      segment: scope.rowSegment(for: item[keyPath: id]), isSelected: focusedPath == rowPath,
      select: { _ = system.geometry.requestFocus(at: rowPath) }, open: opener(of: item)
    ) {
      row(item)
    }
    .id(item[keyPath: id])
  }

  /// The action that opens `item`, or `nil` for a list whose rows do not
  /// open.
  ///
  /// - Parameter item: The item of a row.
  /// - Returns: The action.
  private func opener(of item: Item) -> (() -> Void)? {
    onOpen.map { open in { open(item) } }
  }

  /// The values that the mount writes to the target of the list.
  ///
  /// - Parameters:
  ///   - system: The system that the list registers in.
  ///   - path: The path of the scope of the list.
  ///   - proxy: The proxy of the scroll view of the list.
  /// - Returns: The values.
  private func values(system: CommandSystem, path: FocusPath, proxy: ScrollViewProxy) -> AgentRowListMount.Values {
    let ids = items.map { $0[keyPath: id] }
    let open = onOpen.map { open in
      { (rowID: String) in
        if let item = items.first(where: { $0[keyPath: id] == rowID }) {
          open(item)
        }
      }
    }
    return AgentRowListMount.Values(
      system: system, path: path, rowKind: scope.rowKind, rowIDs: ids, open: open, proxy: proxy)
  }
}

extension AgentRowList where Footer == EmptyView {
  /// Makes a list of rows.
  ///
  /// - Parameters:
  ///   - items: The items of the rows, in list order.
  ///   - id: The id of an item. Each item of the list has its own id.
  ///   - scope: The scope of the list.
  ///   - onOpen: The action that Return and a double click run on the
  ///     selected item, or `nil` for a list whose rows do not open.
  ///   - row: The builder of the content of a row.
  public init(
    _ items: [Item], id: KeyPath<Item, String>, scope: AgentRowListScope, onOpen: ((Item) -> Void)? = nil,
    @ViewBuilder row: @escaping (Item) -> Row
  ) {
    self.init(items, id: id, scope: scope, onOpen: onOpen, row: row) { EmptyView() }
  }
}

/// The fixed values of ``AgentRowList``.
///
/// A generic view type cannot hold a stored static property, so the values
/// are in this separate type.
enum AgentRowListLayout {
  /// The radius step of the selectable surface of a row, and of the focus
  /// ring of a row and of the list.
  static let radius = EditorStyle.Radius.small

  /// The number of taps of a double click, which opens a row.
  static let openTapCount = 2
}

/// One row of an ``AgentRowList``: the content in the command scope of the
/// row, on the selectable surface while its scope is the focused scope of the
/// window.
///
/// The row is focusable, as the rows of the EditorKit TodoList example are,
/// so a `nav.*` move and a jump focus the row itself, and not a control in
/// it. Without Keyboard Navigation, SwiftUI gives a focusable view no AppKit
/// responder, so the beacon of the scope takes the first responder. Thus the
/// list, and not the `@FocusState` of the row, knows the selection: it reads
/// the focused path of the window and passes `isSelected`. A click selects
/// the row through the geometry of the command system, as a `nav.*` move
/// does. The system focus effect is off: the selectable surface shows the
/// selection, which is the focus.
struct AgentRowListRow<Content: View>: View {
  /// The segment of the scope of the row.
  let segment: FocusSegment

  /// Whether the scope of the row is the focused scope, which makes it the
  /// selected row.
  let isSelected: Bool

  /// The action that gives the focus to the scope of the row.
  let select: () -> Void

  /// The action that opens the row, or `nil` for a row that does not open.
  let open: (() -> Void)?

  /// The content of the row.
  @ViewBuilder let content: Content

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    content
      .padding(editorStyle.tile.padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .selectableSurface(isSelected, radius: AgentRowListLayout.radius)
      .focusable()
      .focusEffectDisabled()
      .onTapGesture(count: AgentRowListLayout.openTapCount) { open?() }
      .simultaneousGesture(TapGesture().onEnded { select() })
      .commandScope(segment: segment)
      .navScrollable(.vertical)
      .scopeFocusRing(radius: AgentRowListLayout.radius)
  }
}

#Preview("Rows") {
  AgentRowList(
    PreviewFixtures.suggestions, id: \.self,
    scope: AgentRowListScope(list: FocusSegment(kind: "previewList"), rowKind: "previewRow")
  ) { suggestion in
    Text(suggestion)
  }
}
