import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

extension PreviewTranscriptItem {
  /// The item of an update that the agent sends as JSON.
  ///
  /// - Parameter json: The JSON text of the update.
  /// - Returns: The item.
  static func decodedUpdate(_ json: String) throws -> PreviewTranscriptItem {
    .update(try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8)))
  }
}
