import SwiftUI

extension View {
  /// Makes this view an accessibility container with `identifier`.
  ///
  /// SwiftUI merges a container that has one child container into that
  /// child, and the outer identifier then replaces the inner identifier. A
  /// paragraph that holds only a ``CodeBlockView`` is such a container. The
  /// hidden background is a second child, so SwiftUI keeps the two
  /// containers apart. The background has no size of its own, and VoiceOver
  /// does not read it.
  ///
  /// - Parameter identifier: The accessibility identifier of the container.
  /// - Returns: A view that is a separate accessibility container.
  func contentContainer(identifier: String) -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .background { Color.clear.accessibilityHidden(true) }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(identifier)
  }
}
