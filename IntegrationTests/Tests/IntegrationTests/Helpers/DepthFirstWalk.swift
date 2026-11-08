import AppKit
import QuartzCore

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

  /// `root` and each layer below it, depth first.
  ///
  /// - Parameter root: The root layer.
  /// - Returns: The layers.
  static func layers(from root: CALayer) -> [CALayer] {
    nodes(from: root) { $0.sublayers ?? [] }
  }

  /// `root` and each view below it, depth first.
  ///
  /// - Parameter root: The root view.
  /// - Returns: The views.
  static func views(from root: NSView) -> [NSView] {
    nodes(from: root, children: \.subviews)
  }
}
