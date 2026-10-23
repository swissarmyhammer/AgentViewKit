@testable import AgentViewKit
import EditorSwiftUI
import Testing

@Suite @MainActor struct OwnModelSlotTests {
  @Test func aSlotMakesAReadOnlyModelThatHoldsTheText() {
    let slot = OwnModelSlot()

    let model = slot.model(text: "let x = 1")

    #expect(model.text == "let x = 1")
    #expect(model.isReadOnly)
  }

  @Test func anEditableSlotMakesAnEditableModelThatHoldsTheText() {
    let slot = OwnModelSlot(editable: true)

    let model = slot.model(text: "draft")

    #expect(model.text == "draft")
    #expect(!model.isReadOnly)
  }

  @Test func aSlotGivesTheSameModelAtEachReadAndKeepsItsText() {
    let slot = OwnModelSlot(editable: true)
    let model = slot.model(text: "first")

    let again = slot.model(text: "second")

    #expect(again === model)
    #expect(again.text == "first")
  }
}
