import AppKit
import FoundationModelsACP
import SwiftUI

/// The host command of a click on a module of the status line (D194 (k),
/// D193 (f)).
///
/// The host runs the same command as the context menu of the header, on the
/// focus: for example, the directory module shows the folder in the Files
/// view, the git modules show the Changes view, and the session module opens
/// Switch to Session.
public struct StatusLineActions {
  /// The function of the host: the module, and the working folder of the
  /// session, or `nil`.
  let run: @MainActor (StatusLineModuleID, AbsolutePath?) -> Void

  /// Makes the actions.
  ///
  /// - Parameter run: The function of the host.
  public init(_ run: @escaping @MainActor (StatusLineModuleID, AbsolutePath?) -> Void) {
    self.run = run
  }

  /// Runs the command of a module.
  @MainActor public func callAsFunction(_ module: StatusLineModuleID, folder: AbsolutePath?) {
    run(module, folder)
  }
}

extension EnvironmentValues {
  /// The status line definition of the thread views in this view.
  @Entry public var statusLineDefinition: StatusLineDefinition = StatusLines.defaultDefinition

  /// The host command of a click on a module of the status line, or `nil`
  /// when a click does nothing.
  @Entry public var statusLineActions: StatusLineActions? = nil

  /// The home folder that the `directory` module shows as `~`, or `nil` for
  /// the real home folder of the user (``UserHomeFolder/path``).
  @Entry public var statusLineHomeFolder: URL? = nil
}

extension View {
  /// Sets the status line of the thread views in this view (D194).
  ///
  /// A host decodes the `statusline` setting with
  /// ``StatusLineSetting/resolve(_:)`` and gives its definition here.
  ///
  /// - Parameter definition: The definition.
  /// - Returns: A view whose thread views show `definition`.
  public func statusLine(_ definition: StatusLineDefinition) -> some View {
    environment(\.statusLineDefinition, definition)
  }

  /// Sets the home folder that the `directory` module of the status line
  /// shows as `~`, for example the folder of a test that stands in for the
  /// home folder. With no value, the line uses the home folder of the user.
  ///
  /// - Parameter folder: The home folder, or `nil` for the home folder of
  ///   the user.
  /// - Returns: A view whose status lines use `folder` as the home folder.
  public func statusLineHomeFolder(_ folder: URL?) -> some View {
    environment(\.statusLineHomeFolder, folder)
  }

  /// Sets the host command of a click on a module of the status line.
  ///
  /// - Parameter action: The function of the host: the module, and the
  ///   working folder of the session.
  /// - Returns: A view whose status lines run `action` on a click.
  public func statusLineActions(
    _ action: @escaping @MainActor (StatusLineModuleID, AbsolutePath?) -> Void
  ) -> some View {
    environment(\.statusLineActions, StatusLineActions(action))
  }
}

/// The icons that the kit bundles for the `icon:` symbols: the language
/// icons of Simple Icons (CC0, `Resources/LanguageIcons`).
@MainActor public enum StatusLineIcons {
  /// The folder of the icons in the bundle of the kit.
  static let folderName = "LanguageIcons"

  private static var cache: [String: NSImage] = [:]

  /// The names of the bundled icons.
  public static var names: [String] {
    let urls = Bundle.module.urls(forResourcesWithExtension: "svg", subdirectory: folderName) ?? []
    return urls.map { $0.deletingPathExtension().lastPathComponent }.sorted()
  }

  /// The side of an icon in a line of text, in points: the size of the
  /// text, so that an icon is as tall as a capital letter and a little more.
  ///
  /// - Parameter pointSize: The point size of the font of the line.
  /// - Returns: The side of the icon.
  public static func side(forPointSize pointSize: CGFloat) -> CGFloat {
    (pointSize * 1.1).rounded()
  }

  /// The bundled icon with a name, as a template image that takes the
  /// color of the text, at a size for a line of text.
  ///
  /// - Parameters:
  ///   - name: The name, such as `swift`.
  ///   - side: The width and the height of the image, in points.
  /// - Returns: The image, or `nil` when the kit has no icon with the name.
  public static func image(named name: String, side: CGFloat = 14) -> NSImage? {
    let key = "\(name)@\(side)"
    if let image = cache[key] { return image }
    guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: folderName),
      let image = NSImage(contentsOf: url)
    else { return nil }
    // An SVG has the size of its view box; the line draws the icon at the
    // size of its text.
    image.size = NSSize(width: side, height: side)
    image.isTemplate = true
    cache[key] = image
    return image
  }
}
