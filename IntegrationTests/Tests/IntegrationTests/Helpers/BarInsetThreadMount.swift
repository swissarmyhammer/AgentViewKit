@testable import AgentViewKit
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The frames of a thread that ``BarInsetThreadMount/measure(insets:size:composer:read:)``
/// mounted, after one layout pass of the window.
///
/// All frames are in screen points, with y up.
@MainActor struct BarInsetThreadFrames {
  /// The session model of the thread.
  let session: SessionModel

  /// The screen frame of the hosting view.
  let view: CGRect

  /// The accessibility frame of the header glass (``AgentInfoHeader``).
  let header: CGRect

  /// Gives the accessibility frame of the element with an identifier, or
  /// `nil` when no element has it.
  let frameOfIdentifier: (String) -> CGRect?

  /// Requires the accessibility frame of the element with `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The frame of the element.
  /// - Throws: An issue when no element has `identifier`.
  func frame(identifier: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> CGRect {
    try #require(frameOfIdentifier(identifier), "no element \(identifier)", sourceLocation: sourceLocation)
  }

  /// Gives the space from the leading edge of the hosting view to the
  /// leading edge of `frame`.
  ///
  /// - Parameter frame: A frame in screen points.
  /// - Returns: The space, in points.
  func leading(of frame: CGRect) -> CGFloat {
    frame.minX - view.minX
  }
}

/// The mount that the bar inset suites share: a thread of the preview
/// connection with a header and a composer, with or without `.barInsets()`,
/// rendered one time.
///
/// The composer and the size of the window are parameters, because the
/// suites measure different surfaces: ``ThreadBarInsetsHostedTests`` measures
/// a plain composer that fills the bottom bar, and
/// ``ThreadRowAlignmentHostedTests`` measures the composer glass in a window
/// that is tall enough to show each row of the transcript.
@MainActor enum BarInsetThreadMount {
  /// Mounts the first open session of ``ConnectionModel/previewSample`` in a
  /// window, renders it one time, and reads its frames before the window
  /// closes.
  ///
  /// - Parameters:
  ///   - insets: The bar inset that the host gives, or `nil` for a host that
  ///     writes no `.barInsets()`.
  ///   - size: The size of the window.
  ///   - composer: The builder of the view in the composer slot.
  ///   - read: The reads of the frames that the caller compares.
  /// - Returns: The value that `read` gives.
  /// - Throws: An issue when the session, the hosting view or the header is
  ///   not there, or the error that `read` throws.
  static func measure<Composer: View, Result>(
    insets: EdgeInsets?, size: CGSize, @ViewBuilder composer: @escaping () -> Composer,
    read: (BarInsetThreadFrames) throws -> Result
  ) throws -> Result {
    let connection = ConnectionModel.previewSample
    let session = try #require(connection.openSessions.first)
    let harness = HostedViewHarness(size: size) {
      let thread = AgentThreadView(session: session, connection: connection, composer: composer)
        .transaction { $0.disablesAnimations = true }
      if let insets {
        thread.barInsets(insets)
      } else {
        thread
      }
    }
    defer { harness.close() }
    harness.render()

    let frames = BarInsetThreadFrames(
      session: session, view: harness.screenFrame(of: harness.hostingView),
      header: try #require(harness.frame(identifier: AgentInfoHeader.identifier)),
      frameOfIdentifier: { harness.frame(identifier: $0) })
    return try read(frames)
  }
}
