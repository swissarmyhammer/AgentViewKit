import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI

// The harness's `inspectorDriver` and the driver's `fieldIDs(inBlock:)` come from
// EditorKit's `EditorInspectorTestSupport`. The row read, the row check and the row
// ids below are the ones the AVK hosted suites share.
extension HostedViewHarness {
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
