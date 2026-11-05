import EditorDiff
import Foundation

nonisolated extension FileDiff.Operation {
  /// The word that tells the operation, such as "Added".
  ///
  /// An operation that the view kit does not know gives "Changed". A view
  /// kit that names a change in its own words reads it for an operation it
  /// does not know, as SnapshotViewKit does.
  public var label: String {
    switch self {
    case .add: String(localized: "Added", bundle: .module)
    case .delete: String(localized: "Deleted", bundle: .module)
    case .modify: String(localized: "Modified", bundle: .module)
    case .rename: String(localized: "Renamed", bundle: .module)
    case .copy: String(localized: "Copied", bundle: .module)
    case .binary: String(localized: "Binary", bundle: .module)
    case .unknown: String(localized: "Changed", bundle: .module)
    }
  }
}
