// A fixture for SelectionFillTests. The package build excludes this file.
import SwiftUI

struct SelectionFills: View {
  let isSelected: Bool

  var body: some View {
    VStack {
      Text("row").background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))
      Text("row").background(.selection)
      Capsule().fill(isSelected ? Color.blue : .clear)
      Text("row")
        .background(
          isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
          in: Rectangle())
      Rectangle().fill(SelectionShapeStyle())
    }
  }
}
