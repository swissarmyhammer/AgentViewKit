import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import EditorTheme
import SwiftUI
import Testing

/// The expectations of a view that takes a font from one role of the
/// EditorKit theme in the environment.
///
/// Each expectation mounts the view one time with an ``EnlargedRoleTheme`` for
/// each ``FontRole``. Only the theme that enlarges the role of the view makes
/// its text larger. So an expectation fails when the view reads no role, and
/// also when it reads another role.
enum FontRoleExpectations {
  /// The largest change of the height of an element that the expectations
  /// take as no change, in points.
  ///
  /// The frame of an element is rounded to the pixel grid at its origin. A
  /// text of another role in the same view, such as a caption of the chrome,
  /// grows with the theme of that role and moves the element to another
  /// origin, so its height can round differently by a part of a point. An
  /// enlarged role makes a text many points taller, so the expectations still
  /// tell the roles apart.
  static let layoutRounding: CGFloat = 1

  /// Expects that the text of the element with `identifier` draws in `role`:
  /// the element is taller, by more than ``layoutRounding``, when `view` has
  /// the theme that enlarges `role` than when it has no theme, and the same
  /// height, within ``layoutRounding``, when it has the theme that enlarges
  /// another role.
  ///
  /// The function measures the element through
  /// ``HostedViewHarness/frameHeight(of:identifier:size:)``: one time in
  /// `view` as it is, and one time in `view` with each ``EnlargedRoleTheme``.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - identifier: The accessibility identifier of the element to measure.
  ///   - role: The role that the text must draw in.
  ///   - size: The size of the content.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`.
  @MainActor
  static func expectText(
    of view: some View,
    identifier: String,
    drawsIn role: FontRole,
    size: CGSize = HostedViewHarness<AnyView>.defaultSize,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let unthemed = try HostedViewHarness.frameHeight(of: view, identifier: identifier, size: size)
    for candidate in FontRole.allCases {
      let themed = try HostedViewHarness.frameHeight(
        of: view.editorTheme(EnlargedRoleTheme(enlargedRole: candidate)), identifier: identifier, size: size)
      if candidate == role {
        #expect(
          themed - unthemed > layoutRounding, "The text does not draw in the \(role) role.",
          sourceLocation: sourceLocation)
      } else {
        #expect(
          abs(themed - unthemed) <= layoutRounding, "The text draws in the \(candidate) role.",
          sourceLocation: sourceLocation)
      }
    }
  }

  /// Expects that the EditorKit editor in `view` draws its text in `role`:
  /// the text view of the editor draws in the size of
  /// ``EnlargedRoleTheme/enlargedFont`` when `view` has the theme that
  /// enlarges `role`, and in another size when it has the theme that enlarges
  /// another role.
  ///
  /// - Parameters:
  ///   - view: The view that holds one EditorKit editor.
  ///   - role: The role that the editor text must draw in.
  ///   - size: The size of the content.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An issue when the view shows no text view, or when the text
  ///   view has no font.
  @MainActor
  static func expectEditor(
    in view: some View,
    drawsIn role: FontRole,
    size: CGSize = HostedViewHarness<AnyView>.defaultSize,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let enlargedSize = EnlargedRoleTheme.enlargedFont.resolve(in: EnvironmentValues().fontResolutionContext).pointSize
    for candidate in FontRole.allCases {
      let drawnSize = try editorPointSize(
        in: view.editorTheme(EnlargedRoleTheme(enlargedRole: candidate)), size: size,
        sourceLocation: sourceLocation)
      if candidate == role {
        #expect(drawnSize == enlargedSize, "The editor does not draw in the \(role) role.", sourceLocation: sourceLocation)
      } else {
        #expect(drawnSize != enlargedSize, "The editor draws in the \(candidate) role.", sourceLocation: sourceLocation)
      }
    }
  }

  /// Mounts `view`, makes one ``HostedViewHarness/render()`` pass, and gives
  /// the size of the font of its first text view. The harness closes before
  /// the function returns.
  ///
  /// - Parameters:
  ///   - view: The view that holds one EditorKit editor.
  ///   - size: The size of the content.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The point size of the font of the text view.
  /// - Throws: An issue when the view shows no text view, or when the text
  ///   view has no font.
  @MainActor
  private static func editorPointSize(
    in view: some View, size: CGSize, sourceLocation: SourceLocation
  ) throws -> CGFloat {
    let harness = HostedViewHarness(view, size: size)
    defer { harness.close() }
    harness.render()
    let textView = try #require(harness.views(of: NSTextView.self).first, sourceLocation: sourceLocation)
    return try #require(textView.font, sourceLocation: sourceLocation).pointSize
  }
}
