import AgentViewKitTestSupport
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
}
