// A fixture for ViewPreviewTests. The package build excludes this file.
// The file declares two views and has no #Preview, so the scan must report it.
import SwiftUI

struct PlainRow: View {
  var body: some View { Text("Row") }
}

struct GenericCard<Content: View>: Sendable,
  View
{
  let content: Content

  var body: some View { content }
}
