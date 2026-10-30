#if DEBUG
  import EditorTestSupport
  import Foundation

  /// The images that the snapshot suites generate for the review gallery.
  ///
  /// An integration run only generates images: nothing records a reference
  /// image and nothing compares a capture with an earlier one. A suite writes
  /// each capture here, as `<suite>/<name>-<look>.png`, and the gallery page
  /// (``ReviewGalleryScreenTests``) shows every image of the folder. The
  /// folder is under `.build`, so no run puts an image in the repository.
  enum GeneratedImages {
    /// The folder of the generated images, in the build folder of the
    /// integration package.
    static let root = URL(filePath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appending(path: ".build/generated-images/__Snapshots__", directoryHint: .isDirectory)

    /// Writes `image` for the gallery.
    ///
    /// - Parameters:
    ///   - image: The capture.
    ///   - suite: The name of the suite, the folder of the image.
    ///   - name: The name of the view, such as `composer-field`.
    ///   - look: The look of the window.
    /// - Throws: The error of the write.
    static func write(_ image: CapturedImage, suite: String, named name: String, in look: ReviewAppearance) throws {
      let folder = root.appending(path: suite, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try image.pngData().write(to: folder.appending(path: "\(name)-\(look).png"))
    }

    /// Generates every image of the snapshot suites.
    ///
    /// The suites run in any order beside the gallery page, so the page test
    /// calls this before it lists the images; the page then shows every
    /// image of the run, whichever suite ran first.
    ///
    /// - Throws: The error of a capture or of a write.
    @MainActor static func generateAll() async throws {
      for look in ReviewAppearance.allCases {
        try await HostedSnapshotTests().theThread(look: look)
        try await HostedSnapshotTests().theButtonsOfTheBottomBarBelowTheTranscript(look: look)
        try await HostedSnapshotTests().theIdleComposer(look: look)
        try await HostedSnapshotTests().theComposerWhileTheAgentRuns(look: look)
        try await HostedSnapshotTests().thePermissionRequestCard(look: look)
        try await HostedSnapshotTests().theRequestDeckInTheBar(look: look)
        try await HostedSnapshotTests().theSessionNotice(look: look)
        try await HostedSnapshotTests().theStatusBanner(look: look)
        try await HostedSnapshotTests().theCodeBlock(look: look)
        try await HostedSnapshotTests().theTerminalOutput(look: look)
        try await HostedSnapshotTests().theElicitationForm(look: look)
        try await HostedSnapshotTests().theAttachmentInspector(look: look)
        try await GlassSnapshotTests().theHeaderOfTheThread(look: look)
        try await GlassSnapshotTests().theComposer(look: look)
        try await GlassSnapshotTests().theComposerWhileTheAgentRuns(look: look)
        try await GlassSnapshotTests().theRequestDeckInTheBar(look: look)
        try await GlassSnapshotTests().theFloatingControlsOfTheThread(look: look)
      }
    }
  }
#endif
