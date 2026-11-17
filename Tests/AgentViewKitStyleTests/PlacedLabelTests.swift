import AppKit
import EditorSwiftUI
import SwiftUI
import Testing

@testable import AgentViewKitStyle

/// The text of a ``PlacedLabel``: in content the theme role gives the color,
/// and on glass and chrome each run with no color of its own gets the system
/// label color of the role (EditorKit `style.md`, rule 6).
@Suite @MainActor struct PlacedLabelTests {
  /// The text of the tests.
  static let words = AttributedString("Run the tests")

  /// The AppKit color of each run of `text`.
  static func appKitColors(of text: AttributedString) -> [NSColor?] {
    text.runs.map { $0[AttributeScopes.AppKitAttributes.ForegroundColorAttribute.self] }
  }

  @Test func inContentTheTextKeepsItsColors() {
    #expect(PlacedLabel.text(Self.words, textColor: .secondary, isVibrant: false) == Self.words)
  }

  @Test func onGlassTheSecondaryTextHasTheSecondaryLabelColor() {
    let text = PlacedLabel.text(Self.words, textColor: .secondary, isVibrant: true)

    #expect(Self.appKitColors(of: text) == [.secondaryLabelColor])
  }

  @Test func onGlassThePrimaryTextHasTheLabelColor() {
    let text = PlacedLabel.text(Self.words, textColor: .primary, isVibrant: true)

    #expect(Self.appKitColors(of: text) == [.labelColor])
  }

  @Test func onGlassARunWithAColorOfItsOwnKeepsIt() {
    var named = AttributedString("Error")
    named.foregroundColor = .red
    let text = PlacedLabel.text(named + Self.words, textColor: .secondary, isVibrant: true)

    #expect(Self.appKitColors(of: text) == [nil, .secondaryLabelColor])
  }

  @Test func theStatusExplanationIsAPlacedLabel() {
    let layout = StatusTitleLayout(
      title: "Offline", explanation: "The agent stopped.", identifier: "status",
      symbol: { EmptyView() }, action: { EmptyView() })

    #expect(String(describing: type(of: layout.body)).contains("PlacedLabel"))
  }
}
