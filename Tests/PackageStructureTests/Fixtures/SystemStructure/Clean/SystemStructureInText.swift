// A fixture for SystemStructureTests. The package build excludes this file.
// .toolbarBackground(, .toolbarBackgroundVisibility(, .containerBackground(,
// .presentationBackground( and NSVisualEffectView are in this comment, so the
// scan must not report them.
import SwiftUI

/* .ultraThinMaterial, .thinMaterial, .regularMaterial, .thickMaterial,
   .ultraThickMaterial, .background(.bar) and .backgroundExtensionEffect() are
   in a block comment, so the scan must not report them. */
struct SystemStructureInText: View {
  /// The rows of the fixture. Each row has a property with the name `bar`.
  let rows: [Row]

  var body: some View {
    VStack {
      Text(".backgroundExtensionEffect()")
      Text(#".background(.regularMaterial)"#)
      Text("""
        .toolbarBackground(.bar) and NSVisualEffectView( are in a multi-line literal.
        """)
      Text(rows.map(\.bar).joined())  // .fill(.bar)
      Text(Place(count: rows.count).name)
    }
  }
}

/// A row of this fixture.
struct Row {
  /// The text of the bar of the row. It is not a fill style.
  let bar: String
}

/// The place of a view in this fixture. The case `bar` is not a fill style.
enum Place {
  case bar, content

  /// Makes the place from a count of rows.
  init(count: Int) {
    self = count > 0 ? .bar : .content
  }

  /// The name of the place.
  var name: String {
    switch self {
    case .bar: "bar"
    case .content: "content"
    }
  }
}
