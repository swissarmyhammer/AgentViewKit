import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The locations of a tool call as a row of chips that wraps.
///
/// Each location is a file path, so each chip shows the name of the file of
/// its path, with the line when there is one, and the full path in its help
/// tag and its accessibility label. A chip is not a content tile, so it keeps
/// the small padding of a chip. Its fill, and the selection surface and the
/// focus ring that a kit adds to it, have the ``corners`` of a chip.
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

    /// The name of the file of the path, the last component of the path.
    public var fileName: String {
      URL(filePath: path).lastPathComponent
    }

    /// The full text of the location: the path, and `:<line>` when there is
    /// a line.
    public var fullText: String {
      Self.text(path: path, line: line)
    }

    /// The short text of the location, which the chip shows: the file name,
    /// and `:<line>` when there is a line.
    public var shortText: String {
      Self.text(path: fileName, line: line)
    }

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

  /// The corners of a chip: the medium step of the radius scale, the
  /// corners of an attachment chip. The fill of the chip, the selection
  /// surface and the focus ring that a kit adds all have them.
  public static let corners = SurfaceCorners.rounded(.medium)

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

  public var body: some View {
    ChipFlowLayout(spacing: editorStyle.spacing.xs) {
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
    let configuration = ToolCallLocationChipConfiguration(
      location: location, chip: ToolCallLocationChip(location: location))
    if let chipStyle {
      chipStyle.makeBody(configuration: configuration)
    } else {
      PlainToolCallLocationChipStyle().makeBody(configuration: configuration)
    }
  }
}

/// One chip of a ``ToolCallLocationChips``: the document symbol and the
/// short text of its location, in a small fill with the corners of a chip.
///
/// The chip is one accessibility element: its label is the full text of the
/// location, and its identifier is the identifier of the location.
public struct ToolCallLocationChip: View {
  /// The location of the chip.
  let location: ToolCallLocationChips.Location

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the chip of a location.
  ///
  /// - Parameter location: The location of the chip.
  public init(location: ToolCallLocationChips.Location) {
    self.location = location
  }

  public var body: some View {
    Label(location.shortText, systemImage: SharedSymbol.document)
      .font(editorTheme.font(for: .ui, style: .caption))
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(.vertical, editorStyle.spacing.xs)
      .background(
        .quaternary, in: EditorSurface.shape(radius: ToolCallLocationChips.corners.radius(in: editorStyle)))
      .help(location.fullText)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(location.fullText)
      .accessibilityIdentifier(location.identifier)
  }
}

/// The render-time configuration of a chip of a ``ToolCallLocationChips``.
public struct ToolCallLocationChipConfiguration {
  /// The location of the chip.
  public let location: ToolCallLocationChips.Location

  /// The chip of the location, with no behaviour.
  public let chip: ToolCallLocationChip

  /// Makes the configuration of the chip of a location.
  ///
  /// - Parameters:
  ///   - location: The location of the chip.
  ///   - chip: The chip of the location, with no behaviour.
  public init(location: ToolCallLocationChips.Location, chip: ToolCallLocationChip) {
    self.location = location
    self.chip = chip
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

#Preview("Each location chip, with no style") {
  VStack(alignment: .leading) {
    ForEach(StylePreviewFixtures.locations) { location in
      ToolCallLocationChip(location: location)
    }
  }
  .padding()
}
