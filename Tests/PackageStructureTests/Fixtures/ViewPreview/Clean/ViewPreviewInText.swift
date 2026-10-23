// A fixture for ViewPreviewTests. The package build excludes this file.
// The forms are only in comments and string literals, so the scan must find
// no use. struct PlainRow: View { in this comment does not count.
/* #Preview { PlainRow() } in this block comment does not count. */
import Foundation

let declaration = "struct PlainRow: View {"
let preview = "#Preview(\"Row\") { PlainRow() }"
let source = """
  extension Badge: View {}
  #Preview { Badge() }
  """
