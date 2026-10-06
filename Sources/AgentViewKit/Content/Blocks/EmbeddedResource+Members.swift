import Foundation
import FoundationModelsACP

/// The members of the resource of an ACP embedded resource.
///
/// ACP gives the resource of an embedded resource as raw JSON
/// (`EmbeddedResourceResource`): text contents or blob contents. These
/// properties read the members of that JSON value when a view shows the
/// resource. They keep no copy.
nonisolated extension FoundationModelsACP.EmbeddedResource {
  /// The member names of the resource.
  private enum MemberKey {
    /// The URI of the resource.
    static let uri = "uri"

    /// The MIME type of the resource.
    static let mimeType = "mimeType"

    /// The text contents of the resource.
    static let text = "text"

    /// The base64 blob contents of the resource.
    static let blob = "blob"
  }

  /// The URI of the resource, or `nil` when the resource has no `uri` string.
  var resourceURI: String? {
    stringMember(named: MemberKey.uri)
  }

  /// The MIME type of the resource, or `nil` when the resource has no
  /// `mimeType` string.
  var resourceMimeType: String? {
    stringMember(named: MemberKey.mimeType)
  }

  /// The text contents of the resource, or `nil` when the resource has no
  /// `text` string.
  var resourceText: String? {
    stringMember(named: MemberKey.text)
  }

  /// The bytes of the blob contents of the resource, or `nil` when the
  /// resource has no `blob` string or the string is not base64.
  var resourceBlob: Data? {
    stringMember(named: MemberKey.blob).flatMap { Data(base64Encoded: $0) }
  }

  /// A string member of the resource.
  ///
  /// - Parameter name: The member name.
  /// - Returns: The string, or `nil` when the resource is not an object or the
  ///   member is not a string.
  private func stringMember(named name: String) -> String? {
    guard case .object(let members) = resource, case .string(let value) = members[name] else { return nil }
    return value
  }
}
