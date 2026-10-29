import EditorTestSupport
import Foundation
import Testing

/// The source scan of the content block views: no source file uses a web
/// view.
///
/// The hosted tests of the content block views are in
/// `WireContentBlockViewHostedTests` of the IntegrationTests package.
@Suite struct WireContentBlockViewSourceScanTests {
  // MARK: - Web views

  @Test func noSourceFileUsesAWebView() throws {
    let files = try swiftFiles(under: PackageFiles().file("Sources"))
    #expect(!files.isEmpty)
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      #expect(!text.contains("import WebKit"), "\(file.lastPathComponent) imports WebKit.")
      #expect(!text.contains("WKWebView"), "\(file.lastPathComponent) uses WKWebView.")
    }
  }
}
