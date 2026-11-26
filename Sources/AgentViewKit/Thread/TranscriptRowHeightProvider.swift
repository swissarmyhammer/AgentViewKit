import CoreGraphics
import FoundationModelsACPClient
import SwiftUI

/// The heights that the static form of a row takes (``TranscriptStaticRow``).
///
/// The static form of a row has the height of the real row, so no row moves
/// when it changes from one form to the other. A provider gives that height.
/// A row whose provider knows no height for it shows its real form.
///
/// The provider of a thread is ``TranscriptStaticRowHeights``: the exact
/// height of the cache of the rows (``TranscriptRowHeights``, card
/// ^9h7bm9j), else the height that the real row had at its last layout
/// (``TranscriptMeasuredRowHeights``).
@MainActor protocol TranscriptRowHeightProvider: AnyObject {
  /// Tells if the provider knows a height of the row of `id`.
  ///
  /// - Parameter id: The id of the entry of the row.
  /// - Returns: `true` when the provider can give a height of the row.
  func knowsHeight(of id: TranscriptEntry.ID) -> Bool

  /// The height of the row of `id` at `width`.
  ///
  /// - Parameters:
  ///   - id: The id of the entry of the row.
  ///   - width: The width of the row, in points.
  /// - Returns: The height in points, or `nil` when the provider knows no
  ///   height of the row at that width.
  func height(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat?
}

/// The size that the real row of each entry had at its last layout: the
/// provider of the height of a static row whose height the cache of the
/// rows does not give exactly (``TranscriptStaticRowHeights``).
///
/// ``TranscriptStaticRow`` records the size of each real row each time that
/// it changes. The record is not observable, so a new size does not make a
/// row evaluate its body again. A row reads the record when the rows start
/// or stop to move.
@MainActor final class TranscriptMeasuredRowHeights: TranscriptRowHeightProvider {
  /// The largest difference between two widths that the record takes as
  /// one width, in points. A layout gives a width with a fraction of a
  /// point of float error.
  static let widthTolerance: CGFloat = 0.5

  /// The last size of the real row of each entry.
  private var sizes: [TranscriptEntry.ID: CGSize] = [:]

  /// Makes an empty record.
  init() {}

  /// Records the size of the real row of `id` at its last layout.
  ///
  /// - Parameters:
  ///   - size: The size of the real row.
  ///   - id: The id of the entry of the row.
  func record(_ size: CGSize, for id: TranscriptEntry.ID) {
    sizes[id] = size
  }

  func knowsHeight(of id: TranscriptEntry.ID) -> Bool {
    sizes[id] != nil
  }

  func height(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
    guard let size = sizes[id], abs(size.width - width) <= Self.widthTolerance else { return nil }
    return size.height
  }
}

extension EnvironmentValues {
  /// The heights of the static rows of the thread, or `nil` outside a
  /// thread, where no row shows its static form.
  ///
  /// ``ConversationView`` sets it for its rows.
  @Entry var staticRowHeights: TranscriptStaticRowHeights? = nil
}
