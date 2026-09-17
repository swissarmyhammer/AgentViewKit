import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

/// Records the last height that a measured view reports.
@MainActor
final class HeightRecorder {
  /// The last height, in points.
  var height: CGFloat = 0
}

/// A view that reports its height to a recorder.
struct MeasuredView<Content: View>: View {
  /// The recorder that gets the height.
  let recorder: HeightRecorder

  /// The view to measure.
  @ViewBuilder let content: Content

  var body: some View {
    content
      .fixedSize(horizontal: false, vertical: true)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.height
      } action: { height in
        recorder.height = height
      }
  }
}

/// The Dynamic Type probe of research R11 (plan.md §6, §14).
///
/// The probe measures the line height of a ``CodeBlockView`` and of a body
/// `Text` at the `.large` and `.accessibility3` sizes.
/// `Docs/decisions/dynamic-type.md` records the result. When a result
/// changes, update that file and the expected values here.
@Suite(.serialized, .hostedSerially) @MainActor struct DynamicTypeHostedTests {
  /// The size of the host window.
  static let hostSize = CGSize(width: 480, height: 800)

  /// The number of lines that the tall block has more than the short block.
  static let extraLines = 10

  /// The measured line height of a code block, in points, at each size.
  static let codeLineHeight: CGFloat = 18

  /// The measured line height of body text, in points, at each size.
  static let bodyLineHeight: CGFloat = 16

  /// The line height of a view at a Dynamic Type size: the height of the
  /// view with `extraLines` more lines, less the height of one line,
  /// divided by `extraLines`.
  ///
  /// - Parameters:
  ///   - size: The Dynamic Type size.
  ///   - makeView: The function that makes the view for a text.
  /// - Returns: The line height, in points.
  static func lineHeight(
    at size: DynamicTypeSize, _ makeView: @escaping (String) -> some View
  ) -> CGFloat {
    let short = height(of: makeView("line"), at: size)
    let tall = height(
      of: makeView(Array(repeating: "line", count: extraLines + 1).joined(separator: "\n")),
      at: size)
    return (tall - short) / CGFloat(extraLines)
  }

  /// The height of `view` at a Dynamic Type size.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - size: The Dynamic Type size.
  /// - Returns: The height, in points.
  static func height(of view: some View, at size: DynamicTypeSize) -> CGFloat {
    let recorder = HeightRecorder()
    let harness = HostedViewHarness(
      MeasuredView(recorder: recorder) { view }
        .dynamicTypeSize(size)
        .frame(maxHeight: .infinity, alignment: .top),
      size: hostSize)
    defer { harness.close() }
    harness.pump()
    return recorder.height
  }

  @Test func theCodeBlockLineHeightDoesNotScaleWithDynamicType() {
    let make = { (code: String) in CodeBlockView(code: code, language: nil) }
    let large = Self.lineHeight(at: .large, make)
    let largest = Self.lineHeight(at: .accessibility3, make)

    #expect(large == Self.codeLineHeight)
    #expect(largest == Self.codeLineHeight)
  }

  @Test func theBodyTextLineHeightDoesNotScaleWithDynamicType() {
    let make = { (text: String) in Text(text).font(.body) }
    let large = Self.lineHeight(at: .large, make)
    let largest = Self.lineHeight(at: .accessibility3, make)

    #expect(large == Self.bodyLineHeight)
    #expect(largest == Self.bodyLineHeight)
  }
}
