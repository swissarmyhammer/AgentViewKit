import SwiftUI

/// Shows the registration of the schema name of a structured value, or
/// ``StructuredItemView`` when the name has no registration (plan.md §3.6).
///
/// A structured thread item and a structured content block use this view.
/// Thus one ``SwiftUI/View/structuredItem(_:_:)`` registration shows a schema
/// name in both places.
struct RegisteredStructuredView: View {
  /// The structured value to show.
  let content: StructuredItemContent

  /// The id that keys the expanded state of the default view.
  let id: String

  @Environment(\.structuredItemRegistry) private var registry

  var body: some View {
    if let renderer = registry.resolve(schemaName: content.schemaName) {
      renderer(content)
    } else {
      StructuredItemView(content: content, id: id)
    }
  }
}
