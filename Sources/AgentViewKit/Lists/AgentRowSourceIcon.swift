import EditorStyle
import EditorSwiftUI
import Foundation
import SwiftUI

/// The leading icon of a row that tells the source of its item, such as
/// Claude Code or Codex (TestudoApp D212).
///
/// A host puts the icon as the icon of the label of its row, in an
/// ``AgentRowList`` row or in a search result row:
///
/// ```swift
/// Label {
///   Text(session.title)
/// } icon: {
///   AgentRowSourceIcon(.image(name: "Codex", bundle: .main), name: "Codex")
/// }
/// ```
///
/// The icon stands in the symbol column of the style (EditorStyle
/// `.symbolColumn()`), so the title after it starts at the same x as the
/// title of a row of the kit with a symbol. A symbol source draws with
/// EditorKit's `EditorSymbolImage`. An image source draws at the size of a
/// symbol in the font of the row, which is the `ui` font of the theme in a
/// row of the kit, so the two sources have one size.
///
/// The icon is one accessibility element, and its label is the source name.
/// A host that combines the row element reads "<name>, <title>".
///
/// The kit writes no symbol name and no image of a source: the host gives the
/// `EditorSymbol` or the image of each source.
public struct AgentRowSourceIcon: View {
  /// The image of a source, which the host gives.
  public enum Source: Hashable, Sendable {
    /// A symbol of EditorKit, which draws in the tone of the symbol.
    case symbol(EditorSymbol)
    /// A named image of a bundle, such as an asset of the host. A `nil`
    /// bundle is the main bundle.
    case image(name: String, bundle: Bundle?)
  }

  /// The image of the source.
  let source: Source

  /// The localized name of the source, such as "Claude Code".
  let name: String

  /// Makes the icon of a source.
  ///
  /// - Parameters:
  ///   - source: The image of the source.
  ///   - name: The localized name of the source, which is the accessibility
  ///     label of the icon.
  public init(_ source: Source, name: String) {
    self.source = source
    self.name = name
  }

  /// The image of the source in the symbol column, as one element with the
  /// source name as its label.
  public var body: some View {
    image
      .symbolColumn()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(name)
  }

  /// The image of the source, with no frame.
  @ViewBuilder private var image: some View {
    switch source {
    case .symbol(let symbol):
      EditorSymbolImage(symbol)
    case .image(let imageName, let bundle):
      // The hidden symbol gives the image the size of a symbol in the font of
      // the row, and the image fits in it.
      Image(systemName: AgentSymbol.sizeTemplate)
        .hidden()
        .overlay {
          Image(imageName, bundle: bundle)
            .resizable()
            .scaledToFit()
        }
    }
  }
}
