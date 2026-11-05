import Foundation
import Stencil
import os

/// A Stencil template of the kit: one file of the template folder
/// (`Resources/Templates`).
///
/// A template holds the layout of a text that the kit builds from a list:
/// the separators and the order of its parts. The words come from the string
/// catalog through the model of the template, so no template has a word of
/// its own and none needs a translation.
enum TextTemplate: String {
  /// The Markdown export of a transcript (``ThreadExporter``).
  case threadMarkdown = "thread-markdown"

  /// The Markdown of the content of one message (``ThreadExporter``).
  case messageMarkdown = "message-markdown"

  /// The copy text of a thread (`AgentCommandTarget.plainText(of:)`).
  case copyText = "copy-text"

  /// The steps of a plan in the inspector (`InspectionText.steps(of:)`).
  case planSteps = "plan-steps"

  /// The file name of the template in the template folder.
  var fileName: String { rawValue + ".stencil" }
}

/// The renderer of the text templates of the kit.
///
/// The renderer reads each ``TextTemplate`` from a folder, the bundled
/// template folder for the kit, and renders it with Stencil from a model:
/// a dictionary of plain values whose words come from the string catalog. A
/// template may include another template of the same folder by its file
/// name.
struct TextTemplates {
  /// The name of the template folder in the module bundle.
  static let folderName = "Templates"

  /// The templates of the module bundle.
  static let bundled = TextTemplates(folder: Bundle.module.url(forResource: folderName, withExtension: nil))

  /// The log of a template that does not render.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TextTemplates")

  /// The folder that holds the template files, or `nil` when the bundle has
  /// none.
  let folder: URL?

  /// Renders a template.
  ///
  /// The bundled templates always render, so a failure is a defect of the
  /// kit: the debug build stops, and the release build logs the failure and
  /// gives an empty text.
  ///
  /// - Parameters:
  ///   - template: The template.
  ///   - model: The values that the template reads, by name.
  /// - Returns: The text, or an empty text when the template does not render.
  func render(_ template: TextTemplate, model: [String: Any]) -> String {
    let environment = Environment(loader: TemplateFolderLoader(folder: folder))
    do {
      return try environment.renderTemplate(name: template.fileName, context: model)
    } catch {
      assertionFailure("The template \(template.fileName) does not render: \(error)")
      Self.logger.error(
        "The template \(template.fileName, privacy: .public) does not render: \(String(describing: error), privacy: .public); the text is empty"
      )
      return ""
    }
  }
}

/// The Stencil loader of the files of a template folder.
nonisolated struct TemplateFolderLoader: Loader {
  /// The folder of the template files, or `nil` for none.
  let folder: URL?

  /// Loads the template file with a name.
  ///
  /// - Parameters:
  ///   - name: The file name of the template in the folder.
  ///   - environment: The Stencil environment of the template.
  /// - Returns: The template.
  /// - Throws: `TemplateDoesNotExist` when the loader has no folder, or the
  ///   error of the read of the file.
  func loadTemplate(name: String, environment: Environment) throws -> Template {
    guard let folder else { throw TemplateDoesNotExist(templateNames: [name], loader: self) }
    let text = try String(contentsOf: folder.appending(path: name), encoding: .utf8)
    return environment.templateClass.init(templateString: text, environment: environment, name: name)
  }
}
