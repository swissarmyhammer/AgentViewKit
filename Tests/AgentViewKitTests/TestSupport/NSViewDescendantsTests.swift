@testable import AgentViewKitTestSupport
import AppKit
import Testing

/// Tests of the one walk of an AppKit view tree that the test support and the
/// hosted tests share.
@Suite @MainActor struct NSViewDescendantsTests {
  @Test func theDescendantsOfAViewAreItsSubviewTreeInDepthFirstOrder() {
    let root = NSView()
    let first = NSView()
    let nested = NSView()
    let second = NSView()
    root.addSubview(first)
    first.addSubview(nested)
    root.addSubview(second)

    let order = root.descendants.map(ObjectIdentifier.init)

    #expect(order == [first, nested, second].map(ObjectIdentifier.init))
  }

  @Test func aViewWithNoSubviewHasNoDescendant() {
    #expect(NSView().descendants.isEmpty)
  }

  @Test func aViewIsOfAnyClassThatItIsOrThatItSubclasses() {
    let button = NSButton()

    #expect(button.isKind(ofAny: [NSTextField.self, NSButton.self]))
    #expect(button.isKind(ofAny: [NSControl.self]))
    #expect(!button.isKind(ofAny: [NSTextField.self]))
    #expect(!button.isKind(ofAny: []))
  }

  @Test func hidingDescendantsOfAClassHidesThatClassAndItsSubclassesOnly() {
    let root = NSView()
    let control = NSControl()
    let nestedButton = NSButton()
    let plain = NSView()
    root.addSubview(control)
    control.addSubview(nestedButton)
    root.addSubview(plain)

    root.hideDescendants(of: [NSControl.self])

    #expect(control.isHidden)
    #expect(nestedButton.isHidden)
    #expect(!plain.isHidden)
    #expect(!root.isHidden)
  }

  @Test func hidingDescendantsOfNoClassHidesNoView() {
    let root = NSView()
    let child = NSButton()
    root.addSubview(child)

    root.hideDescendants(of: [])

    #expect(!child.isHidden)
  }
}
