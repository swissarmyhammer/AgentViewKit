import EditorTestSupport
import Foundation
import Testing

/// The source scan of the diff views: no diff source has the old placeholder
/// text of the renderer.
///
/// The hosted tests of the default renderer are in
/// `DiffRendererDefaultHostedTests` of the IntegrationTests package.
@Suite struct DiffRendererDefaultSourceScanTests {
  @Test func noDiffSourceHasTheOldPlaceholderText() throws {
    let directory = try PackageFiles().file("Sources/AgentViewKit/Diff")
    let files = swiftFiles(under: directory)
    #expect(!files.isEmpty)
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      #expect(!text.contains("not installed"), "\(file.lastPathComponent) has the old placeholder text")
    }
  }
}
