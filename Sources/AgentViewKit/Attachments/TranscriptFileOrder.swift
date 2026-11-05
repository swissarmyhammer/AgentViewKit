import Foundation
import SwiftUI

/// The transcript order of the files that the file views of a thread show,
/// which an extend of the selection reads (card ^4138tmp).
///
/// Each file view (``InspectorSelectable``) places its file with the
/// position of its row in the transcript (``SwiftUI/EnvironmentValues/transcriptRowPosition``)
/// and its frame in that row (``TranscriptFileOrder/rowSpace``). The order
/// sorts the files by the row, then from the top of the row, then from its
/// leading edge, so the files of one row read as the row shows them. A view
/// outside each row, such as a chip in the composer slot, sorts after the
/// rows, by its frame in the window. A file that shows in two places holds
/// its first place.
///
/// A lazy list lets a row go when it scrolls away, and the transcript still
/// holds its files. So the file of a view in a row keeps its place when the
/// view goes away, and a range over rows out of sight still reaches it. The
/// file of a view outside each row leaves the order with its view.
///
/// The order sees only the rows that the thread showed: a row that never
/// showed has no frame and no place.
@MainActor final class TranscriptFileOrder {
  /// The name of the coordinate space of each row of a thread, in which a
  /// file view reads its frame.
  nonisolated static let rowSpace = "agentTranscriptRow"

  /// The key of a placed file: its row and URL for a view in a row, which
  /// outlives the view, and the view for a view outside each row.
  private enum Key: Hashable {
    /// A file of the row at a position of the transcript.
    case row(Int, URL)

    /// The file of one view outside each row.
    case view(UUID)
  }

  /// One placed file.
  private struct Place {
    /// The file.
    let file: Attachment

    /// The position of the row in the transcript, or `nil` outside each row.
    let row: Int?

    /// The frame of the view, in its row, or in the window outside each row.
    let frame: CGRect

    /// Whether this place comes before `other` in transcript order.
    ///
    /// - Parameter other: Another place.
    /// - Returns: `true` when the row of this place comes first, or the rows
    ///   are the same and this frame is higher, or on the same line and
    ///   nearer the leading edge.
    func precedes(_ other: Place) -> Bool {
      let mine = (row ?? Int.max, frame.minY, frame.minX)
      let theirs = (other.row ?? Int.max, other.frame.minY, other.frame.minX)
      return mine < theirs
    }
  }

  /// The placed files.
  private var places: [Key: Place] = [:]

  /// The files of the thread, in transcript order, each one time.
  var files: [Attachment] {
    var seen: Set<URL> = []
    return places.values.sorted { $0.precedes($1) }.map(\.file).filter { seen.insert($0.url).inserted }
  }

  /// Places the file of a view, or moves it.
  ///
  /// - Parameters:
  ///   - file: The file of the view.
  ///   - row: The position of the row of the view in the transcript, or
  ///     `nil` outside each row.
  ///   - frame: The frame of the view in its row, or in the window outside
  ///     each row.
  ///   - view: The id of the view.
  func place(_ file: Attachment, row: Int?, frame: CGRect, view: UUID) {
    places[Self.key(of: file, row: row, view: view)] = Place(file: file, row: row, frame: frame)
  }

  /// Takes out the file of a view outside each row when the view goes away.
  /// The file of a view in a row keeps its place.
  ///
  /// - Parameter view: The id of the view.
  func remove(view: UUID) {
    places[.view(view)] = nil
  }

  /// The key of the file of a view.
  ///
  /// - Parameters:
  ///   - file: The file.
  ///   - row: The position of the row of the view, or `nil`.
  ///   - view: The id of the view.
  /// - Returns: The key of the row and the file, or of the view outside
  ///   each row.
  private static func key(of file: Attachment, row: Int?, view: UUID) -> Key {
    guard let row else { return .view(view) }
    return .row(row, file.url)
  }
}

extension EnvironmentValues {
  /// The transcript order of the files of the thread of this view, or `nil`
  /// outside a thread and an inspector.
  @Entry var transcriptFileOrder: TranscriptFileOrder? = nil

  /// The position in the transcript of the row of this view, or `nil`
  /// outside each row. ``ConversationView`` sets it for each row.
  @Entry var transcriptRowPosition: Int? = nil
}
