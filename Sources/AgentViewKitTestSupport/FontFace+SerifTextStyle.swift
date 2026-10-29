import AppKit
import EditorTheme

extension FontFace {
  /// The system serif face with a fixed `body` size: the point size of the
  /// system font at `style`.
  ///
  /// A test theme uses it to draw a font role larger than the default faces,
  /// in a design that no default face has. The size is fixed, so the face
  /// scales it to each text style: a caption of the role is larger than a
  /// default caption, as its body text is larger than default body text.
  ///
  /// - Parameter style: The system text style whose point size the face takes
  ///   at `body`.
  /// - Returns: The face.
  public nonisolated static func serif(sizedAs style: NSFont.TextStyle) -> FontFace {
    FontFace(design: .serif, size: NSFont.preferredFont(forTextStyle: style).pointSize)
  }
}
