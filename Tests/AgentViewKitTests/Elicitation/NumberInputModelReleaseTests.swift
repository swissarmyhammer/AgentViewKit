import AgentViewKitTestSupport
import AppKit
import EditorCore
import EditorSwiftUI
import SwiftUI
import Testing

/// The model of the stepper field of an ``ElicitationNumberField`` leaves
/// memory when the field leaves the view. The undo entries of the input go
/// off the window undo stack only when the model goes, so a submitted form
/// leaves no entry that ⌘Z undoes in an input that is gone (the hosted test
/// `aSubmittedFormTakesTheTypingOfItsNumberInputOffTheWindowUndoStack`).
///
/// Each test lays out the input in a hosting view with no window, removes it,
/// and reads a weak reference to its model.
@MainActor @Suite struct NumberInputModelReleaseTests {
  /// The id of the input of each test.
  static let identifier = "number-input"

  /// Tells whether the model of the view that `make` makes leaves memory
  /// when the view leaves the hosting view.
  ///
  /// - Parameter make: Makes the view over its model.
  /// - Returns: `true` when no reference keeps the model.
  static func releasesItsModel(_ make: (EditorModel) -> AnyView) -> Bool {
    weak var released: EditorModel?
    let hosting = NSHostingView(rootView: AnyView(EmptyView()))
    autoreleasepool {
      let model = EditorModel("")
      released = model
      hosting.rootView = make(model)
      StyleViewHost.layOut(hosting)
      hosting.rootView = AnyView(EmptyView())
      StyleViewHost.layOut(hosting)
    }
    return released == nil
  }

  /// The positive control of ``theStepperFieldReleasesItsModel()``: the
  /// EditorKit `NumberField` lets its model go. A change that fails this
  /// test: the probe keeps the model itself.
  @Test func theNumberFieldReleasesItsModel() {
    #expect(Self.releasesItsModel { AnyView(NumberField(model: $0, id: Self.identifier, value: .constant(1))) })
  }

  /// A change that fails this test: the EditorKit `StepperField` of the
  /// input keeps its model after the field leaves the view (EditorKit
  /// ^d6nf5zm), so the typing of a submitted form stays on the window undo
  /// stack.
  @Test func theStepperFieldReleasesItsModel() {
    #expect(
      Self.releasesItsModel {
        AnyView(
          StepperField(
            model: $0, id: Self.identifier, value: .constant(1), in: 0...1, step: 1, typedValues: .keep))
      })
  }
}
