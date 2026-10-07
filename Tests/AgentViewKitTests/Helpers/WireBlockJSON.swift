import Foundation

/// The JSON text of ACP content blocks and of the `session/update` values that
/// hold them. The hosted tests send these values from the scripted agent.
enum WireBlockJSON {
  /// A `session/update` value with one content block, such as an
  /// `agent_message_chunk`.
  ///
  /// - Parameters:
  ///   - kind: The `sessionUpdate` tag, such as `agent_message_chunk`.
  ///   - messageID: The `messageId` of the chunk.
  ///   - block: The JSON text of the content block.
  /// - Returns: The JSON text of the update.
  static func makeChunk(_ kind: String, messageID: String, block: String) -> String {
    #"{"sessionUpdate":"\#(kind)","messageId":"\#(messageID)","content":\#(block)}"#
  }

  /// A `tool_call_update` value for the call of `id`.
  ///
  /// - Parameters:
  ///   - id: The `toolCallId` of the call.
  ///   - fields: The other fields of the update, as JSON members.
  /// - Returns: The JSON text of the update.
  static func makeToolCallUpdate(id: String, fields: String) -> String {
    #"{"sessionUpdate": "tool_call_update", "toolCallId": "\#(id)", \#(fields)}"#
  }

  /// A `compaction_summary_chunk` value with one content block.
  ///
  /// - Parameters:
  ///   - compactionID: The `compactionId` of the compaction.
  ///   - block: The JSON text of the content block.
  /// - Returns: The JSON text of the update.
  static func makeCompactionSummaryChunk(compactionID: String, block: String) -> String {
    #"{"sessionUpdate":"compaction_summary_chunk","compactionId":"\#(compactionID)","content":\#(block)}"#
  }

  /// A text block.
  ///
  /// - Parameter text: The text of the block. Each line break becomes the
  ///   JSON escape `\n`.
  /// - Returns: The JSON text of the block.
  static func makeText(_ text: String) -> String {
    let escaped = text.replacingOccurrences(of: "\n", with: #"\n"#)
    return #"{"type":"text","text":"\#(escaped)"}"#
  }

  /// An image block.
  ///
  /// - Parameters:
  ///   - data: The bytes of the image. The block holds them as base64 text.
  ///   - mimeType: The MIME type of the image.
  /// - Returns: The JSON text of the block.
  static func makeImage(data: Data, mimeType: String) -> String {
    #"{"type":"image","mimeType":"\#(mimeType)","data":"\#(data.base64EncodedString())"}"#
  }

  /// A resource link block.
  ///
  /// - Parameters:
  ///   - name: The name of the resource.
  ///   - uri: The URI of the resource.
  /// - Returns: The JSON text of the block.
  static func makeResourceLink(name: String, uri: String) -> String {
    #"{"type":"resource_link","name":"\#(name)","uri":"\#(uri)"}"#
  }
}
