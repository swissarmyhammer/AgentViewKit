@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorStyle
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The status lines of the review gallery (AVK-10, D194): the header of a
/// thread in a repository, outside a repository, in an iCloud Drive app
/// container, in a long path, with the `full` preset, and for a child
/// session with its crumbs, each on the floating glass of the top bar.
///
/// The folders are below the real home folder of the user
/// (``UserHomeFolder/path``), which the line shows as `~`, also when the
/// test runs with a temporary `HOME`. No fixture reads the file system: the
/// models have fixed display names.
@MainActor
enum StatusLineGalleryFixtures {
  /// The width of the image, in points.
  static let width: CGFloat = 640

  /// The height of the image, in points: room for each header and its
  /// caption.
  static let height: CGFloat = 520

  /// The size of the image, in points.
  static let size = CGSize(width: width, height: height)

  /// The count of the staged files of the repository lines.
  static let stagedCount = 3

  /// The count of the modified files of the repository lines.
  static let modifiedCount = 2

  /// The count of the untracked files of the repository lines.
  static let untrackedCount = 1

  /// The count of the commits ahead of the upstream, for the repository
  /// lines.
  static let aheadCount = 1

  /// The count of the commits behind the upstream, for the repository
  /// lines.
  static let behindCount = 0

  /// The folder of the repository lines: a folder below the home folder, so
  /// that the line shows `~` rules and the repository root.
  static var repositoryFolder: String { UserHomeFolder.path + "/code/AgentViewKit/Sources/AgentViewKit" }

  /// The root of the repository of the repository lines.
  static var repositoryRoot: String { UserHomeFolder.path + "/code/AgentViewKit" }

  /// The folder of the line outside a repository.
  static var notesFolder: String { UserHomeFolder.path + "/Documents/notes" }

  /// The iCloud Drive container of the Testudo app.
  static var testudoContainer: String { UserHomeFolder.path + "/Library/Mobile Documents/iCloud~testudo~app" }

  /// A folder in the iCloud Drive container of the Testudo app: the line
  /// shows `iCloud Drive › Testudo › Agents`.
  static var iCloudFolder: String { testudoContainer + "/Documents/Agents" }

  /// The display names of the iCloud line: the name of the app container.
  static var iCloudDisplayNames: [String: String] { [testudoContainer: "Testudo"] }

  /// The display name of the root folder, as Finder shows it: the child
  /// session of the crumbs line has a folder outside the home folder.
  static let rootDisplayNames = ["/": "Macintosh HD"]

  /// A folder eight long names below the home folder: the line removes
  /// whole names from the middle.
  static var longFolder: String {
    UserHomeFolder.path
      + "/Engineering/Applications/Development/Repositories/Swissarmyhammer/AgentViewKit/Documentation/Architecture"
  }

  /// The git state of the repository lines: a branch, changes, and one
  /// commit ahead of the upstream.
  static var git: StatusLineGitSnapshot {
    StatusLineGitSnapshot(
      root: repositoryRoot, branch: "status-line",
      counts: .init(staged: stagedCount, modified: modifiedCount, untracked: untrackedCount), ahead: aheadCount,
      behind: behindCount)
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
      section("In an iCloud Drive app container") {
        fixtures.header(
          StatusLineView(
            session: .preview(cwd: AbsolutePath(rawValue: fixtures.iCloudFolder)), sessionTitle: "Plan the trip",
            model: StatusLineModel(
              fixedFolder: fixtures.iCloudFolder, git: nil, files: ["plan.md"],
              displayNames: fixtures.iCloudDisplayNames)))
      }
      section("A long path: whole names, one ellipsis") {
        fixtures.header(
          StatusLineView(
            session: .preview(cwd: AbsolutePath(rawValue: fixtures.longFolder)), sessionTitle: "Notes",
            model: StatusLineModel(fixedFolder: fixtures.longFolder, git: nil, files: ["notes.md"])))
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
              fixedFolder: fixtures.repositoryFolder, git: fixtures.git, files: fixtures.files,
              displayNames: fixtures.rootDisplayNames)))
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
