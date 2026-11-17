@testable import AgentViewKit
import AppKit
import EditorSwiftUI
import EditorTestSupport
import SwiftUI

/// The steps that the hosted tests of the text of an answer share
/// (``ResponseView``, AVK-9.7).
///
/// The text of each response is one EditorKit text element with the
/// identifier ``ResponseView/textIdentifier``. Its value is the Markdown text.
/// A test that reads the math or the citation chips of a response waits for
/// the syntax parse of the model of the response first: the parse runs off
/// the main actor and ends for certain, so the wait has no clock.
@MainActor enum ResponseTextChecks {
  /// The value of each response text element that `harness` shows, in view
  /// order.
  ///
  /// - Parameter harness: The harness that shows the responses.
  /// - Returns: The Markdown text of each response.
  static func texts(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements()
      .filter { $0.identifier == ResponseView.textIdentifier }
      .compactMap(\.value)
  }

  /// The model of the response `id` in `cache`. The view made it in its
  /// first render pass.
  ///
  /// - Parameters:
  ///   - id: The id of the response view.
  ///   - cache: The cache in the environment of the response view.
  /// - Returns: The model, or `nil` when the cache has no model for `id`.
  static func model(of id: String, in cache: CodeBlockModelCache) -> EditorModel? {
    let modelID = ResponseView.modelID(for: id)
    guard cache.contains(modelID) else { return nil }
    return cache.model(for: modelID, code: "")
  }

  /// Waits for the end of the syntax parse of `model`, then for the update
  /// that SwiftUI queued for it, and renders.
  ///
  /// - Parameters:
  ///   - model: The model of a response.
  ///   - harness: The harness that shows the response.
  static func renderParsed(_ model: EditorModel, in harness: HostedViewHarness<some View>) async {
    _ = await model.syntax?.ensureParsed(upTo: model.state.version)
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
  }

  /// The accessibility node with the label `label` under the hosting view of
  /// `harness`, such as the chip of a citation.
  ///
  /// - Parameters:
  ///   - label: The accessibility label.
  ///   - harness: The harness.
  /// - Returns: The node, or `nil` when no node has the label.
  static func node(labeled label: String, in harness: HostedViewHarness<some View>) -> NSObject? {
    accessibilitySubtree(of: harness.hostingView).first { accessibilityLabel(of: $0) == label }
  }
}
