import FoundationModelsACP
import Observation
import SwiftUI

/// Holds the answer of one field of a form test. The binding of the field
/// reads and writes ``value``.
///
/// The unit tests and the hosted tests of the field views share this box.
@Observable
public final class AnswerBox {
  /// The current answer.
  public var value: JSONValue?

  /// Makes a box.
  ///
  /// - Parameter value: The first answer.
  public init(_ value: JSONValue? = nil) {
    self.value = value
  }

  /// A binding to ``value``.
  public var binding: Binding<JSONValue?> {
    Binding(get: { self.value }, set: { self.value = $0 })
  }
}
