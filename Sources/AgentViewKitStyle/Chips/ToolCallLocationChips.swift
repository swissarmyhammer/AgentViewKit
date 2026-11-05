import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The locations of a tool call as a row of chips that wraps.
///
/// Each location is a file path, so each chip is the EditorKit `PathChip` of
/// its path: the document symbol, the name of the file with the line when
/// there is one, and the folder of the path, with the full path in its help
/// tag. The row is a compound view of AgentViewKit around the chip of
/// EditorKit, which keeps the look of a chip. A selection surface and a
/// focus ring that a kit adds to a chip have the corners of the chip
/// (`SurfaceCorners.pathChip`).
///
/// The chips take their behaviour from the ``ToolCallLocationChipStyle`` of
/// the environment. By default a chip has no behaviour of its own. A kit that
/// selects the file of a chip, or gives the chip a command scope, sets its
/// own style with ``SwiftUI/View/toolCallLocationChipStyle(_:)``:
/// AgentViewKit selects the file for its inspector and gives the chip the
/// scope of the file.
public struct ToolCallLocationChips: View {
  /// One location of a tool call: a file path, and the line in the file when
  /// the source gives one.
  public struct Location: Hashable, Sendable, Identifiable {
    /// The path of the file.
    public let path: String

    /// The line in the file, or `nil` when the source gave none.
    public let line: Int?

    /// The accessibility identifier of the chip of the location. It is the
    /// identity of the chip, so it stays the same when the call hides
    /// another location.
    public let identifier: String

    /// Makes a location.
    ///
    /// - Parameters:
    ///   - path: The path of the file.
    ///   - line: The line in the file, or `nil` when the source gave none.
    ///   - identifier: The accessibility identifier of the chip of the
    ///     location.
    public init(path: String, line: Int?, identifier: String) {
      self.path = path
      self.line = line
      self.identifier = identifier
    }

    /// The identity of the location: the identifier of its chip.
    public var id: String { identifier }

    /// The text of a location: the path, and `:<line>` when there is a line.
    ///
    /// - Parameters:
    ///   - path: The path text to show.
    ///   - line: The line in the file, if the source gave one.
    /// - Returns: `<path>`, or `<path>:<line>` when there is a line.
    public static func text(path: String, line: Int?) -> String {
      guard let line else { return path }
      return "\(path):\(line)"
    }
  }

  /// The locations to show.
  let locations: [Location]

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.toolCallLocationChipStyle) private var chipStyle

  /// Makes the chips of the locations of a tool call.
  ///
  /// - Parameter locations: The locations to show, in order.
  public init(locations: [Location]) {
    self.locations = locations
  }

  /// A chip for each location, in a flow layout that wraps the chips to the next line.
  public var body: some View {
    EditorChipRows(spacing: editorStyle.spacing.xs) {
      ForEach(locations) { location in
        chip(location)
      }
    }
  }

  /// The chip of `location`, in the style of the environment, or in
  /// ``PlainToolCallLocationChipStyle`` when the environment has no style.
  ///
  /// - Parameter location: The location of the chip.
  /// - Returns: The chip with its behaviour.
  @ViewBuilder
  private func chip(_ location: Location) -> some View {
    let configuration = ToolCallLocationChipConfiguration(location: location)
    if let chipStyle {
      chipStyle.makeBody(configuration: configuration)
    } else {
      PlainToolCallLocationChipStyle().makeBody(configuration: configuration)
    }
  }
}

/// The render-time configuration of a chip of a ``ToolCallLocationChips``.
public struct ToolCallLocationChipConfiguration {
  /// The location of the chip.
  public let location: ToolCallLocationChips.Location

  /// Makes the configuration of the chip of a location.
  ///
  /// - Parameter location: The location of the chip.
  public init(location: ToolCallLocationChips.Location) {
    self.location = location
  }

  /// The chip of the location, with no behaviour: the EditorKit `PathChip`
  /// of its path and its line, with the identifier of the location as its
  /// accessibility identifier.
  public var chip: some View {
    PathChip(location.path, line: location.line)
      .accessibilityIdentifier(location.identifier)
  }
}

/// The behaviour of a chip of a ``ToolCallLocationChips``: a style protocol
/// that mirrors `ButtonStyle`, as ``StatusBarActionStyle`` does.
///
/// A kit sets its style with ``SwiftUI/View/toolCallLocationChipStyle(_:)``
/// where it shows the chips. With no style in the environment, a chip uses
/// ``PlainToolCallLocationChipStyle``.
@MainActor
public protocol ToolCallLocationChipStyle {
  /// The view that the style makes.
  associatedtype Body: View

  /// Makes a chip.
  ///
  /// - Parameter configuration: The location and its chip.
  /// - Returns: The chip with its behaviour.
  @ViewBuilder func makeBody(configuration: ToolCallLocationChipConfiguration) -> Body
}

/// The default behaviour of a location chip: none. The chip shows its
/// location and takes no click.
public struct PlainToolCallLocationChipStyle: ToolCallLocationChipStyle {
  /// Makes the default style.
  public init() {}

  /// Gives the chip no behaviour.
  ///
  /// - Parameter configuration: The location and its chip.
  /// - Returns: The chip.
  public func makeBody(configuration: ToolCallLocationChipConfiguration) -> some View {
    configuration.chip
  }
}

extension EnvironmentValues {
  /// The style of each chip of each ``ToolCallLocationChips`` in this view,
  /// or `nil` for ``PlainToolCallLocationChipStyle``.
  @Entry var toolCallLocationChipStyle: ErasedStyle<ToolCallLocationChipConfiguration>? = nil
}

extension View {
  /// Sets the style of each chip of each ``ToolCallLocationChips`` in this
  /// view.
  ///
  /// - Parameter style: The style of the chips.
  /// - Returns: A view whose location chips have `style`.
  public func toolCallLocationChipStyle<Style: ToolCallLocationChipStyle>(_ style: Style) -> some View {
    environment(\.toolCallLocationChipStyle, ErasedStyle(style.makeBody(configuration:)))
  }
}

#Preview("Location chips") {
  ToolCallLocationChips(locations: StylePreviewFixtures.locations)
    .frame(width: StylePreviewFixtures.narrowWidth)
    .padding()
}
