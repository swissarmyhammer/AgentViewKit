@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The status lines of the review gallery (AVK-10, D194): the header of a
/// thread in a repository, outside a repository, with the `full` preset, and
/// for a child session with its crumbs, each on the floating glass of the
/// top bar.
@MainActor
enum StatusLineGalleryFixtures {
  /// The size of the image, in points.
  static let size = CGSize(width: 640, height: 500)

  /// The folder of the repository lines: a folder below the home folder, so
  /// that the line shows `~` rules and the repository root.
  static var repositoryFolder: String { NSHomeDirectory() + "/code/AgentViewKit/Sources/AgentViewKit" }

  /// The root of the repository of the repository lines.
  static var repositoryRoot: String { NSHomeDirectory() + "/code/AgentViewKit" }

  /// The folder of the line outside a repository.
  static var notesFolder: String { NSHomeDirectory() + "/Documents/notes" }

  /// The git state of the repository lines: a branch, changes, and one
  /// commit ahead of the upstream.
  static var git: StatusLineGitSnapshot {
    StatusLineGitSnapshot(
      root: repositoryRoot, branch: "status-line", counts: .init(staged: 3, modified: 2, untracked: 1), ahead: 1,
      behind: 0)
  }

  /// The files of the repository lines: Swift first, then Python and shell.
  static let files = ["a.swift", "b.swift", "c.swift", "tool.py", "build.sh"]

  /// The model config option of the `full` line.
  static var modelOptions: [SessionConfigOption] {
    let json = #"""
      [{"configId":"model","name":"Model","category":"model","type":"select","currentValue":"qwen",
        "options":[{"value":"qwen","name":"Qwen3 4B"}]}]
      """#
    return (try? JSONDecoder().decode([SessionConfigOption].self, from: Data(json.utf8))) ?? []
  }

  /// The image: one header for each case, with a caption.
  ///
  /// - Parameter child: The child session of the crumbs line.
  /// - Returns: The image.
  static func gallery(child: SessionModel) -> some View {
    StatusLineGallery(child: child)
  }

  /// The header of the thread in the repository, as the top bar of
  /// ``AgentThreadView`` shows it.
  static var repositoryHeader: some View {
    header(
      StatusLineView(
        session: .preview(cwd: AbsolutePath(rawValue: repositoryFolder)), sessionTitle: "Status line",
        model: StatusLineModel(fixedFolder: repositoryFolder, git: git, files: files)))
  }

  /// One header on the floating glass, with the inset of the top bar.
  static func header(_ line: some View) -> some View {
    FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      line
        .padding(.horizontal, EditorStyle.default.spacing.m)
        .padding(.vertical, EditorStyle.default.spacing.s)
        .floatingGlass()
    }
  }
}

/// The captions and the headers of the image.
private struct StatusLineGallery: View {
  let child: SessionModel

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    let fixtures = StatusLineGalleryFixtures.self
    VStack(alignment: .leading, spacing: editorStyle.spacing.m) {
      section("In a repository (default)") { fixtures.repositoryHeader }
      section("A session titled like its folder: no session text") {
        fixtures.header(
          StatusLineView(
            session: .preview(cwd: AbsolutePath(rawValue: fixtures.repositoryFolder)), sessionTitle: "AgentViewKit",
            model: StatusLineModel(fixedFolder: fixtures.repositoryFolder, git: fixtures.git, files: fixtures.files)))
      }
      section("Outside a repository (default)") {
        fixtures.header(
          StatusLineView(
            session: .preview(cwd: AbsolutePath(rawValue: fixtures.notesFolder)), sessionTitle: "Notes",
            model: StatusLineModel(fixedFolder: fixtures.notesFolder, git: nil, files: ["todo.md"])))
      }
      section("The full preset") {
        fixtures.header(
          StatusLineView(
            session: .preview(
              cwd: AbsolutePath(rawValue: fixtures.repositoryFolder), configOptions: fixtures.modelOptions),
            sessionTitle: "Status line",
            model: StatusLineModel(fixedFolder: fixtures.repositoryFolder, git: fixtures.git, files: fixtures.files))
        )
        .statusLine(StatusLines.named("full") ?? StatusLines.defaultDefinition)
      }
      section("A child session, with its crumbs") {
        fixtures.header(
          StatusLineView(
            session: child, sessionTitle: "Agents",
            model: StatusLineModel(
              fixedFolder: fixtures.repositoryFolder, git: fixtures.git, files: fixtures.files)))
      }
    }
    .padding(editorStyle.tile.margin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      Text(title).font(editorTheme.font(for: .ui, style: .headline))
      content()
    }
  }
}
