// A fixture for ViewPreviewTests. The package build excludes this file.
// No type of the file conforms to View. A generic constraint and a where
// clause are not conformances, so the scan must not report the file.
import SwiftUI

struct Harness<Content: View> {
  let content: Content
}

struct Boxed<Item>: Sendable where Item: View {
  let item: Item
}

struct Dimmed: ViewModifier {
  func body(content: Content) -> some View { content.disabled(true) }
}
