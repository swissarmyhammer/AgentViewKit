import Testing

/// Tests of ``DepthFirstWalk``, the walk that the tests use for the layers and
/// the views of a window.
@Suite struct DepthFirstWalkTests {
  /// The children of each node of a small tree, with the root 1.
  static let children: [Int: [Int]] = [1: [2, 5], 2: [3, 4], 5: [6]]

  /// A production change that fails this test: the walk gives the children
  /// of a node before the node, or gives a sibling before the children of
  /// the first sibling.
  @Test func theWalkGivesEachNodeBeforeItsChildrenAndEachSubtreeInOrder() {
    let nodes = DepthFirstWalk.nodes(from: 1) { Self.children[$0] ?? [] }

    #expect(nodes == [1, 2, 3, 4, 5, 6])
  }
}
