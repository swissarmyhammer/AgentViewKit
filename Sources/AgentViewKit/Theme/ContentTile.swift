import EditorStyle
import SwiftUI

/// The padding of a content tile: the tile padding of `\.editorStyle` on
/// each edge of the content (card ^ey6v778).
///
/// A content tile is a view that shows one block of content, with a border
/// or with none: a card, a banner, a request card, a tool call, terminal
/// output, a code block, a diff, an artifact. Its padding, the gap between
/// its parts and the margin to its neighbours are the tile tokens of
/// EditorKit (`EditorStyle.tile`), so a theme or a host that sets them
/// changes each tile of the kit.
///
/// A tile with a border and a tile with no border use the same padding. The
/// modifier draws no border and no fill: a tile opts into its edge with
/// `.inlineEdge(radius:)`, and the content behind the tile shows through it.
struct ContentTile: ViewModifier {
  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    content.padding(editorStyle.tile.padding)
  }
}

/// The layout of a content tile: the header, then the parts of the body,
/// with the tile gap of `\.editorStyle` between each two.
///
/// The parts of the body stack in the same column as the header, so the gap
/// also falls between two parts of the body. The layout pads nothing; the
/// tile puts `.contentTile()` around it.
struct ContentTileStack<Header: View, TileBody: View>: View {
  /// The header row of the tile.
  let header: Header

  /// The parts of the body of the tile.
  let tileBody: TileBody

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the layout of a tile.
  ///
  /// - Parameters:
  ///   - header: The header row of the tile.
  ///   - body: The parts of the body of the tile, from the top.
  init(@ViewBuilder header: () -> Header, @ViewBuilder body: () -> TileBody) {
    self.header = header()
    self.tileBody = body()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.tile.gap) {
      header
      tileBody
    }
  }
}

extension View {
  /// Pads this content tile with the tile padding of `\.editorStyle`.
  ///
  /// Each content tile, with a border or with none, takes its padding from
  /// this modifier. The modifier draws no border and no fill.
  ///
  /// - Returns: The padded tile.
  func contentTile() -> some View {
    modifier(ContentTile())
  }
}

#Preview("A tile with an edge, and a tile with none") {
  VStack(alignment: .leading, spacing: EditorStyle.default.tile.margin) {
    ContentTileStack {
      Text(PreviewFixtures.lintCommand)
    } body: {
      Text(PreviewFixtures.lintOutput)
    }
    .contentTile()
    .inlineEdge(radius: EditorStyle.default.radii.l)
    ContentTileStack {
      Text(PreviewFixtures.lintCommand)
    } body: {
      Text(PreviewFixtures.lintOutput)
    }
    .contentTile()
  }
}
