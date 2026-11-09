import EditorStyle
import SwiftUI

/// The SF Symbol of a label, in the symbol column of the style (EditorStyle
/// `.symbolColumn()`).
///
/// The column has one width for each symbol, so the text of labels with
/// symbols of different widths starts at one x. The symbol takes the font, the
/// weight and the color of the label that contains it.
struct SymbolColumnImage: View {
  /// The SF Symbol name.
  let name: String

  var body: some View {
    Image(systemName: name)
      .symbolColumn()
  }
}

extension Label where Title == Text, Icon == SymbolColumnImage {
  /// Makes a label of a text, with its SF Symbol in the symbol column of the
  /// style (``SymbolColumnImage``).
  ///
  /// - Parameters:
  ///   - title: The text of the label, which the label shows as written.
  ///   - name: The SF Symbol name.
  init(_ title: String, columnSymbol name: String) {
    self.init {
      Text(title)
    } icon: {
      SymbolColumnImage(name: name)
    }
  }
}
