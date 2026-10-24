import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The write of the bytes of a content block to its block file, which
/// ``AudioPlayerView`` and ``BlobResourceView`` share.
@Suite(.serialized, .hostedSerially) @MainActor struct BlockFileWriteViewHostedTests {
  /// The size of the view in the tests.
  static let hostSize = CGSize(width: 400, height: 200)

  /// The bytes of the block file in the tests.
  static let fileBytes = Data("written block bytes".utf8)

  /// The name of the block file in the tests.
  static let fileName = "written.bin"

  /// The accessibility identifier of the view of a loaded write.
  static let loadedIdentifier = "block-file-write-loaded"

  /// The accessibility identifier of the view of a failed write.
  static let failedIdentifier = "block-file-write-failed"

  @Test func aWriteOfBytesReportsTheBlockFileAndShowsTheLoadedContent() async throws {
    let writes = ReportRecorder<PreviewLoadState<URL>>()
    let harness = HostedViewHarness(
      Self.makeWriteView(report: writes.report) { Self.fileBytes }, size: Self.hostSize)
    defer { harness.close() }
    await harness.render { writes.values.contains(where: Self.isEnded) }

    let url = try #require(Self.loadedURL(in: writes.values))
    #expect(url == ContentBlockFile.url(of: Self.fileBytes, named: Self.fileName))
    #expect(try Data(contentsOf: url) == Self.fileBytes)
    #expect(harness.element(identifier: Self.loadedIdentifier) != nil)
  }

  @Test func aWriteWithNoBytesReportsTheFailedStateAndShowsTheFailedContent() async {
    let writes = ReportRecorder<PreviewLoadState<URL>>()
    let harness = HostedViewHarness(
      Self.makeWriteView(report: writes.report) { nil }, size: Self.hostSize)
    defer { harness.close() }
    await harness.render { writes.values.contains(where: Self.isEnded) }

    #expect(writes.values.contains(where: WireContentBlockViewHostedTests.isFailed))
    #expect(harness.element(identifier: Self.failedIdentifier) != nil)
  }

  @Test func aWriteReportsTheLoadingStateFirst() async {
    let writes = ReportRecorder<PreviewLoadState<URL>>()
    let harness = HostedViewHarness(
      Self.makeWriteView(report: writes.report) { Self.fileBytes }, size: Self.hostSize)
    defer { harness.close() }
    await harness.render { writes.values.contains(where: Self.isEnded) }

    #expect(writes.values.first.map(Self.isLoading) == true)
  }

  // MARK: - Helpers

  /// Makes the write view of the tests: a text with an identifier for each
  /// state of the write.
  ///
  /// - Parameters:
  ///   - report: The report that gets each state of the write.
  ///   - bytes: The byte source of the write.
  /// - Returns: The write view of ``fileName``.
  static func makeWriteView(
    report: ObservationReport<PreviewLoadState<URL>>, bytes: @escaping () -> Data?
  ) -> some View {
    BlockFileWriteView(id: fileName, name: fileName, report: report, bytes: bytes) { state in
      switch state {
      case .loading:
        ProgressView()
      case .loaded:
        Text("Loaded").accessibilityIdentifier(loadedIdentifier)
      case .failed:
        Text("Failed").accessibilityIdentifier(failedIdentifier)
      }
    }
  }

  /// The URL of the first loaded state among reported states.
  ///
  /// - Parameter states: The reported states.
  /// - Returns: The URL of the loaded state, or `nil` when no state loaded.
  static func loadedURL(in states: [PreviewLoadState<URL>]) -> URL? {
    states.lazy.compactMap { state -> URL? in
      if case .loaded(let url) = state { url } else { nil }
    }.first
  }

  /// Tells whether a state of a file write is the loading state.
  ///
  /// - Parameter state: The reported state.
  /// - Returns: `true` for ``PreviewLoadState/loading``.
  static func isLoading(_ state: PreviewLoadState<URL>) -> Bool {
    if case .loading = state { true } else { false }
  }

  /// Tells whether a state of a file write ends the write.
  ///
  /// - Parameter state: The reported state.
  /// - Returns: `true` for a loaded or a failed state.
  static func isEnded(_ state: PreviewLoadState<URL>) -> Bool {
    !isLoading(state)
  }
}
