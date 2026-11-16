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

  /// The bundled icon with a name, as a template image that takes the
  /// color of the text.
  ///
  /// - Parameter name: The name, such as `swift`.
  /// - Returns: The image, or `nil` when the kit has no icon with the name.
  public static func image(named name: String) -> NSImage? {
    if let image = cache[name] { return image }
    guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: folderName),
      let image = NSImage(contentsOf: url)
    else { return nil }
    image.isTemplate = true
    cache[name] = image
    return image
  }
}
