// A fixture for SelectionFillTests. The package build excludes this file.
// .background(.selection), SelectionShapeStyle() and
// .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
// are in this comment, so the scan must not report them.
import SwiftUI

/* Capsule().fill(isSelected ? Color.blue : .clear) is in a block comment, so
   the scan must not report it. */
struct SelectionFillsInText: View {
  let isSelected: Bool
  let selection: Int
  let fill: Color?

  var body: some View {
    VStack {
      Text(".background(.selection) and Rectangle().fill(isSelected ? .blue : .clear)")
      Text("""
        .fill(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear)) is in a multi-line literal.
        """)
      Text("row \(selection)")
        .foregroundStyle(isSelected ? .primary : .secondary)
        .background(fill ?? .clear)
        .selectionSurface(isSelected, radius: .small)
    }
  }
}
