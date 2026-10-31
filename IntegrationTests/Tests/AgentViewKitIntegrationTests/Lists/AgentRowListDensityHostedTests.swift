import EditorCommands
import EditorStyle
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The density of ``AgentRowList``: the distance from the top of one row to the
/// top of the next, which comes from the style of the window.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentRowListDensityHostedTests {
  /// The ids of the rows, in list order.
  static let ids = ["first", "second"]

  /// The list of a test.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "densityList"), rowKind: "densityRow")

  /// The frames of the two rows of a list of `density` under `style`.
  ///
  /// The content of a row reports the frame of the row, so a test reads the
  /// frame of the row by the identifier of its content.
  ///
  /// - Parameters:
  ///   - density: The density of the list.
  ///   - style: The style of the window.
  /// - Returns: The frame of each row.
  static func rowFrames(_ density: AgentRowDensity, style: EditorStyle = .default) throws -> [CGRect] {
    let harness = HostedViewHarness {
      AgentRowList(ids, id: \.self, scope: scope, density: density) { id in
        Text(id).accessibilityIdentifier(id)
      }
      .environment(\.editorStyle, style)
    }
    defer { harness.close() }
    return try ids.map { try #require(harness.frame(identifier: $0)) }
  }

  /// The distance from the top of the first row to the top of the second.
  ///
  /// - Parameter frames: The frames of the two rows.
  /// - Returns: The row step.
  static func step(_ frames: [CGRect]) -> CGFloat {
    abs(frames[0].midY - frames[1].midY)
  }

  /// A style whose steps differ from the default, so that a number of the view
  /// cannot pass for a value of the style.
  static var themedStyle: EditorStyle {
    var style = EditorStyle.default
    style.spacing.xs *= 2
    return style
  }

  @Test func aRegularRowKeepsTheTilePaddingAndTheTileMargin() throws {
    let frames = try Self.rowFrames(.regular)
    let tile = EditorStyle.default.tile

    #expect(Self.step(frames) == frames[0].height + tile.margin)
  }

  /// The regular row holds one line and twice the tile padding, so the compact
  /// row is that line with the extra small step above and below.
  @Test func aCompactRowTakesTheExtraSmallStepOfTheStyleForEachGap() throws {
    let regular = try Self.rowFrames(.regular)
    let style = EditorStyle.default
    let line = regular[0].height - 2 * style.tile.padding

    #expect(Self.step(try Self.rowFrames(.compact)) == line + 3 * style.spacing.xs)
  }

  @Test func aThemeChangesTheCompactStep() throws {
    let style = Self.themedStyle
    let base = EditorStyle.default.spacing.xs

    let change = Self.step(try Self.rowFrames(.compact, style: style)) - Self.step(try Self.rowFrames(.compact))

    #expect(change == 3 * (style.spacing.xs - base))
  }
}
