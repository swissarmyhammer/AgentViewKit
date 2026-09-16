import SwiftUI
import UniformTypeIdentifiers

/// A titled panel for a file or a document that the agent made
/// (plan.md §3.6, §9 F).
///
/// An artifact with a URL shows its file in an ``AttachmentView`` and the
/// file actions of the inspector. An artifact with inline text only shows the
/// text by its type, and has no file actions, because it has no file.
public struct ArtifactView: View {
  /// The accessibility identifier of the panel.
  public static let identifier = "artifact"

  /// The accessibility identifier of the title.
  public static let titleIdentifier = "artifact-title"

  /// The accessibility identifier of the inline text.
  public static let inlineTextIdentifier = "artifact-inline-text"

  /// The start of the accessibility identifier of each action.
  public static let identifierPrefix = "artifact"

  /// The accessibility identifiers of the file actions, in display order.
  public static var actionIdentifiers: [String] {
    AttachmentActions.identifiers(prefix: identifierPrefix)
  }

  /// The artifact to show.
  let artifact: ArtifactPayload

  @Environment(\.agentTheme) private var theme

  /// Makes the panel of an artifact.
  ///
  /// - Parameter artifact: The artifact to show.
  public init(artifact: ArtifactPayload) {
    self.artifact = artifact
  }

  public var body: some View {
    let attachment = Self.attachment(of: artifact)
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      HStack(spacing: theme.spacing.s) {
        Label(artifact.title, systemImage: "doc.richtext")
          .font(.headline)
          .lineLimit(1)
          .accessibilityIdentifier(Self.titleIdentifier)
        Spacer(minLength: theme.spacing.s)
        if let attachment {
          AttachmentActions(attachment: attachment, identifierPrefix: Self.identifierPrefix)
        }
      }
      if let attachment {
        AttachmentView(attachment)
      } else if let inlineText = artifact.inlineText {
        AttachmentTextContent(
          text: inlineText, type: UTType(artifact.type) ?? .plainText, filename: nil)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier(Self.inlineTextIdentifier)
      }
    }
    .padding(theme.spacing.m)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
        .strokeBorder(.separator)
    )
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.identifier)
  }

  /// The attachment of an artifact file.
  ///
  /// - Parameter artifact: The artifact.
  /// - Returns: The attachment of ``ArtifactPayload/url`` with the type of
  ///   the artifact when that type is known, or `nil` when the artifact has
  ///   no URL.
  private static func attachment(of artifact: ArtifactPayload) -> Attachment? {
    guard let url = artifact.url else { return nil }
    var attachment = Attachment(url: url)
    if let type = UTType(artifact.type) {
      attachment.type = type
    }
    return attachment
  }
}
