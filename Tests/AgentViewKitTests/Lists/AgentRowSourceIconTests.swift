import AgentViewKitTestSupport
import AppKit
import EditorStyle
import EditorSwiftUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The leading source icon of a row (``AgentRowSourceIcon``, TestudoApp
/// D212): its accessibility label, its width in the symbol column, and the
/// equality of its source.
@MainActor @Suite struct AgentRowSourceIconTests {
  /// The accessibility identifier that each test gives to the icon, so that
  /// the test finds the element of the icon.
  static let identifier = "sourceIcon"

  /// The size of the hosting view of the tests that read the accessibility
  /// tree.
  static let hostSize = CGSize(width: 120, height: 60)

  /// The width of the symbol column of the style of the width tests. It is
  /// not the default width, so that an icon with a width of its own fails.
  static let columnWidth: CGFloat = 40

  /// The source of a symbol, as a host gives it for Claude Code.
  nonisolated static let symbolSource = AgentRowSourceIcon.Source.symbol(.tool(.execute))

  /// The source of an image of the host, as a host gives it for Codex.
  nonisolated static let imageSource = AgentRowSourceIcon.Source.image(name: "CodexSourceIcon", bundle: nil)

  /// A production change that fails this test: the icon of a symbol source
  /// has no label, or a label that is not the source name.
  @Test func theLabelOfASymbolSourceIsTheSourceName() async {
    let label = await Self.label(of: AgentRowSourceIcon(Self.symbolSource, name: "Claude Code"))

    #expect(label == "Claude Code")
  }

  /// A production change that fails this test: the icon of an image source
  /// has no label, or a label that is not the source name.
  @Test func theLabelOfAnImageSourceIsTheSourceName() async {
    let label = await Self.label(of: AgentRowSourceIcon(Self.imageSource, name: "Codex"))

    #expect(label == "Codex")
  }

  /// A production change that fails this test: the icon of a source is not
  /// in the symbol column of the style, so the title after it starts at a
  /// different x than the title of a row with a kit symbol.
  @Test(
    "the icon has the width of the symbol column of the style",
    arguments: [symbolSource, imageSource])
  func theIconHasTheWidthOfTheSymbolColumn(_ source: AgentRowSourceIcon.Source) {
    var style = EditorStyle.default
    style.symbolColumnWidth = Self.columnWidth

    let size = StyleViewHost.size(
      of: AgentRowSourceIcon(source, name: "Source").editorStyle(style),
      proposedWidth: Self.hostSize.width)

    #expect(size.width == Self.columnWidth)
  }

  /// A production change that fails this test: two sources of the same
  /// symbol are not equal.
  @Test func twoSourcesOfOneSymbolAreEqual() {
    #expect(AgentRowSourceIcon.Source.symbol(.tool(.execute)) == Self.symbolSource)
  }

  /// A production change that fails this test: two images with different
  /// names are equal.
  @Test func twoImagesWithDifferentNamesAreNotEqual() {
    #expect(AgentRowSourceIcon.Source.image(name: "ClaudeSourceIcon", bundle: nil) != Self.imageSource)
  }

  /// A production change that fails this test: a symbol source and an image
  /// source are equal.
  @Test func aSymbolSourceIsNotEqualToAnImageSource() {
    #expect(Self.symbolSource != Self.imageSource)
  }

  /// The accessibility label of `icon`, read from a hosting view with no
  /// window, so the test shows no window and takes no focus.
  ///
  /// - Parameter icon: The icon to lay out.
  /// - Returns: The label, or `nil` when no single element has the
  ///   identifier of the icon, or the element has no label.
  static func label(of icon: AgentRowSourceIcon) async -> String? {
    let hosting = NSHostingView(rootView: icon.accessibilityIdentifier(identifier))
    hosting.frame = NSRect(origin: .zero, size: hostSize)
    hosting.layoutSubtreeIfNeeded()
    return await withAccessibilityTree {
      let elements = accessibilityElements(identifiedAs: identifier, under: hosting)
      return elements.count == 1 ? elements.first.flatMap(accessibilityLabel(of:)) : nil
    }
  }
}
