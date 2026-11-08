/// The depth-first walk of a tree that the tests share, such as the layers or
/// the views of a window.
enum DepthFirstWalk {
  /// `root` and each node below it, depth first: a node comes before its
  /// children, and the subtree of a child comes before the next child.
  ///
  /// - Parameters:
  ///   - root: The root of the tree.
  ///   - children: The children of a node, in order.
  /// - Returns: The nodes of the tree.
  static func nodes<Node>(from root: Node, children: (Node) -> [Node]) -> [Node] {
    [root] + children(root).flatMap { nodes(from: $0, children: children) }
  }
}
