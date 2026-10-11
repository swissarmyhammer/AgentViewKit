import SwiftUI

extension View {
  /// Makes this view one accessibility element with a label, a value and an
  /// identifier.
  ///
  /// The element ignores the accessibility of the children of this view. The
  /// views of the kit that show a status with a value, such as
  /// ``ConnectionStatusChip`` and ``ThreadMinimapView``, use this one rule.
  ///
  /// - Parameters:
  ///   - label: The label of the element.
  ///   - value: The value of the element.
  ///   - identifier: The accessibility identifier of the element.
  /// - Returns: The element.
  func valueElement(label: Text, value: Text, identifier: String) -> some View {
    accessibilityElement(children: .ignore)
      .accessibilityLabel(label)
      .accessibilityValue(value)
      // An element with no role does not give its value. The trait gives the
      // static text role.
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(identifier)
  }
}
