/// The HTML text of the contact sheet of a ``ReviewGallery``.
///
/// The page is a table: a header row with the variants, then one row of
/// image cells for each screen, and the note of the screen under its row.
/// Each image links to its full PNG file in the same folder. The page has no
/// date and no clock value, so the same rows give the same text.
enum ReviewGalleryPage {
  /// One image of a row.
  struct Cell {
    /// The file name of the image, such as `thread--dark.png`.
    let fileName: String

    /// The name of the variant, such as `dark`.
    let variant: String

    /// Whether the image is in the folder.
    let exists: Bool
  }

  /// One screen of the page.
  struct Row {
    /// The title of the screen.
    let title: String

    /// The note under the row.
    let note: String

    /// The images of the screen, one for each variant, in column order.
    let cells: [Cell]
  }

  /// The title of the page.
  static let title = "AgentViewKit review gallery"

  /// The style sheet of the page. The colors follow the appearance of the
  /// browser, and each image keeps its own colors.
  static let style = """
    :root { color-scheme: light dark; --text: #1d1d1f; --muted: #6e6e73; --line: #d2d2d7; --page: #ffffff; }
    @media (prefers-color-scheme: dark) {
      :root { --text: #f5f5f7; --muted: #a1a1a6; --line: #424245; --page: #1d1d1f; }
    }
    body { margin: 16px; font: 14px -apple-system, system-ui, sans-serif; color: var(--text); background: var(--page); }
    table { border-collapse: collapse; width: 100%; table-layout: fixed; }
    th { text-align: left; color: var(--muted); font-weight: 600; padding: 8px; }
    td { vertical-align: top; padding: 8px; }
    figure { margin: 0; }
    img { width: 100%; height: auto; border: 1px solid var(--line); }
    figcaption { color: var(--muted); margin-top: 4px; }
    td.note { border-bottom: 1px solid var(--line); padding-bottom: 16px; }
    .missing { color: var(--muted); border: 1px dashed var(--line); padding: 24px; }
    """

  /// The whole page for `rows`.
  ///
  /// - Parameter rows: The screens, in order. Each row has the same number of
  ///   cells.
  /// - Returns: The HTML text.
  static func html(rows: [Row]) -> String {
    let variants = rows.first?.cells.map(\.variant) ?? []
    let header = variants.map { "<th>\(escaped($0))</th>" }.joined()
    let body = rows.map { row in rowHTML(row, columnCount: variants.count) }.joined(separator: "\n")
    return """
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(escaped(title))</title>
      <style>
      \(style)
      </style>
      </head>
      <body>
      <h1>\(escaped(title))</h1>
      <table>
      <thead><tr>\(header)</tr></thead>
      <tbody>
      \(body)
      </tbody>
      </table>
      </body>
      </html>

      """
  }

  /// The image row of one screen and the row of its note.
  ///
  /// - Parameters:
  ///   - row: The screen.
  ///   - columnCount: The number of columns of the table.
  /// - Returns: The HTML text of the two table rows.
  static func rowHTML(_ row: Row, columnCount: Int) -> String {
    let cells = row.cells.map { cellHTML($0, title: row.title) }.joined()
    return """
      <tr>\(cells)</tr>
      <tr><td class="note" colspan="\(columnCount)"><strong>\(escaped(row.title))</strong>: \(escaped(row.note))</td></tr>
      """
  }

  /// The table cell of one image, or of a missing image.
  ///
  /// - Parameters:
  ///   - cell: The image.
  ///   - title: The title of the screen, for the caption.
  /// - Returns: The HTML text of the cell.
  static func cellHTML(_ cell: Cell, title: String) -> String {
    let caption = escaped("\(title) — \(cell.variant)")
    let file = escaped(cell.fileName)
    guard cell.exists else {
      return #"<td><div class="missing">No image: \#(file)</div></td>"#
    }
    return #"""
      <td><figure><a href="\#(file)"><img src="\#(file)" alt="\#(caption)" loading="lazy"></a>\#
      <figcaption>\#(caption)</figcaption></figure></td>
      """#
  }

  /// `text` with the characters that HTML gives a meaning replaced by their
  /// character references, so that the text shows as it is.
  ///
  /// - Parameter text: The text.
  /// - Returns: The escaped text.
  static func escaped(_ text: String) -> String {
    text.reduce(into: "") { result, character in
      result += characterReferences[character] ?? String(character)
    }
  }

  /// The character reference of each character that HTML gives a meaning,
  /// in text and in a quoted attribute value.
  static let characterReferences: [Character: String] = [
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;",
  ]
}
