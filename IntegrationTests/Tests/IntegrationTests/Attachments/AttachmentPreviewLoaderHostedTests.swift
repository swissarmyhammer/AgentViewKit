import AVFoundation
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// Hosted tests of the loader that the parts of an ``AttachmentPreview`` read
/// their files through.
///
/// The media player is not hosted: the SwiftUI `VideoPlayer` stops the test
/// process, because the runtime cannot demangle the superclass of its
/// `VideoPlayerView` (`AVPlayerView`) there.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentPreviewLoaderHostedTests {
  /// The renderers whose part reads its file and can be hosted: a text file
  /// and a document thumbnail.
  nonisolated static let loadingRenderers: [AttachmentView.Renderer] = [.text, .pdf]

  @Test(arguments: loadingRenderers)
  func eachPartReadsItsFileThroughTheLoaderOfTheEnvironment(renderer: AttachmentView.Renderer) async {
    let attachment = PreviewFixtures.logFileAttachment
    let reads = ReportRecorder<URL>()
    let loader = AttachmentPreviewLoader(
      text: { url in
        reads.report(url)
        return nil
      },
      thumbnail: { url, _ in
        reads.report(url)
        return .failed
      },
      player: { _ in AVPlayer() })
    let harness = HostedViewHarness(
      AttachmentPreview(attachment: attachment, renderer: renderer)
        .environment(\.attachmentPreviewLoader, loader))
    defer { harness.close() }

    await harness.render { !reads.values.isEmpty }

    #expect(reads.values == [attachment.url])
  }

  @Test func theDefaultLoaderReadsTheTextOfAFileOnDisk() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let url = try directory.write("build.log", contents: Data(PreviewFixtures.buildLogText.utf8))

    #expect(await EnvironmentValues().attachmentPreviewLoader.text(url) == PreviewFixtures.buildLogText)
  }
}
