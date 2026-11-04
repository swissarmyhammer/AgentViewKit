import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI

// TODO(editorkit-b5): EditorKit has no `InspectorDriver` initializer that takes a
// `HostedViewHarness`, no row read or row check on a harness, and no row id of an object.
// They are generic, so they belong in EditorKit's `EditorInspectorTestSupport`. EK has
// accepted them, and this file goes when they land.
extension HostedViewHarness {
  /// EditorKit's `InspectorDriver` over the window and the hosting view of the harness.
  var inspectorDriver: InspectorDriver {
    InspectorDriver(window: window, root: hostingView)
  }

  /// The value that the inspector row of `identifier` shows: the text of its
  /// editor, the choice of its picker, `1` or `0` for a toggle, or the value it
  /// speaks.
  ///
  /// - Parameter identifier: The scheme id of the row.
  /// - Returns: The value, or `nil` when no row has the id.
  func rowValue(_ identifier: String) -> String? {
    inspectorDriver.value(of: identifier)
  }

  /// Whether the harness shows the inspector row of `identifier`.
  ///
  /// - Parameter identifier: The scheme id of the row.
  /// - Returns: `true` when an element carries the id.
  func showsRow(_ identifier: String) -> Bool {
    !inspectorDriver.elements(identifier).isEmpty
  }

  /// The scheme id of each row of the inspector block `block` that the harness shows, in
  /// the order of the accessibility tree.
  ///
  /// - Parameter block: The scheme id of the block, such as
  ///   `inspection:tool-toggles/object:tool-toggles-1`.
  /// - Returns: The id of each row of the block.
  func fieldIDs(inBlock block: String) -> [String] {
    let fields = InspectorScheme.identifier(of: "field:", inRow: block)
    return accessibilityElements().compactMap(\.identifier).filter { $0.hasPrefix(fields) }
  }
}

/// The scheme ids of the inspector rows that the hosted suites read.
enum InspectorRowID {
  /// The object id of `object` in the `InspectorView` of `view`: its
  /// `Identifiable` id, or, for an object with no identity of its own, the
  /// view and its position.
  ///
  /// - Parameters:
  ///   - object: The inspected object, alone in its block.
  ///   - view: The view id, which is the id of the inspection.
  /// - Returns: The escaped object id.
  static func object(_ object: some AnyObject, view: String) -> String {
    InspectorScheme.objectID(of: [object], key: view)
  }

  /// The scheme id of the row `group`.`field` of `object` in the
  /// `InspectorView` of `view`.
  ///
  /// - Parameters:
  ///   - view: The view id.
  ///   - object: The inspected object, alone in its block.
  ///   - group: The group part.
  ///   - field: The field part.
  /// - Returns: The id that the row carries.
  static func field(view: String, object: some AnyObject, group: String, field: String) -> String {
    InspectorDriver.field(view: view, object: self.object(object, view: view), group: group, field: field)
  }
}
