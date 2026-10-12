import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// The height expectations of a view that takes a font from the EditorKit
/// theme in the environment.
///
/// ``DistinctRolesTheme`` has fonts that are much larger than the default
/// fonts. Thus an element whose font comes from a role of the theme is taller
/// with that theme than with no theme.
enum ThemeHeightExpectations {
  /// Expects that the element with `identifier` is taller when `view` has
  /// `theme` than when it has no theme.
  ///
  /// The function measures the element two times through
  /// ``HostedViewHarness/frameHeight(of:identifier:size:)``: one time in
  /// `view` with `theme`, and one time in `view` as it is.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - identifier: The accessibility identifier of the element to measure.
  ///   - theme: The EditorKit theme whose font makes the element taller.
  ///   - size: The size of the content.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`.
  static func expectThemeIncreasesHeight(
    of view: some View,
    identifier: String,
    theme: any EditorTheme.Theme = DistinctRolesTheme(),
    size: CGSize = HostedViewHarness<AnyView>.defaultSize,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let themed = try HostedViewHarness.frameHeight(
      of: view.editorTheme(theme), identifier: identifier, size: size)
    let unthemed = try HostedViewHarness.frameHeight(of: view, identifier: identifier, size: size)

    #expect(themed > unthemed, sourceLocation: sourceLocation)
  }
}
