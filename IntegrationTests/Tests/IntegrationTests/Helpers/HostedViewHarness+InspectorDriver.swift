import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import SwiftUI

// TODO(editorkit-b5): EditorKit has no `InspectorDriver` initializer that takes a
// `HostedViewHarness`. Both types are EditorKit's, so this helper is generic and belongs in
// EditorKit's test support; it is requested there, and this file goes when it lands.
extension HostedViewHarness {
  /// EditorKit's `InspectorDriver` over the window and the hosting view of the harness.
  var inspectorDriver: InspectorDriver {
    InspectorDriver(window: window, root: hostingView)
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
