import FoundationModelsACP

/// The wire type of an ACP content block.
///
/// The prompt capability tests and the hosted prompt editor tests share it.
public nonisolated enum ContentBlockWireType {
  /// The wire type of a block.
  ///
  /// - Parameter block: The block.
  /// - Returns: The `type` value of the block on the wire.
  public static func wireType(of block: FoundationModelsACP.ContentBlock) -> String {
    switch block {
    case .text: "text"
    case .image: "image"
    case .audio: "audio"
    case .resourceLink: "resource_link"
    case .resource: "resource"
    case .unknown(let type, _): type
    }
  }
}
