import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI
import UniformTypeIdentifiers

/// A titled panel for a file or a document that the agent made
/// (plan.md §3.6, §9 F).
///
/// An artifact with a URL shows its file in an ``AttachmentView`` and the
/// file actions of the inspector. The panel is then the scope of its file
/// (`agentAttachment:<id>`, AVK-11), and each action button runs the command
/// of that scope. An artifact with inline text only shows the text by its
/// type, and has no file actions, because it has no file.
///
/// The panel is content, so it has no fill and no glass. A separator stroke
/// marks its edge (`.inlineEdge(radius:)`, D113).
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

  /// The corners of the panel: the medium radius of `\.editorStyle`. The
  /// edge of the panel and the focus ring of its scope both have them.
  static let corners = SurfaceCorners.rounded(.medium)

  /// The artifact to show.
  let artifact: ArtifactPayload

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the panel of an artifact.
  ///
  /// - Parameter artifact: The artifact to show.
  public init(artifact: ArtifactPayload) {
    self.artifact = artifact
  }

  public var body: some View {
    let attachment = Self.attachment(of: artifact)
    ContentTileStack {
      HStack(spacing: editorStyle.spacing.s) {
        Label(artifact.title, systemImage: SharedSymbol.artifact)
          .font(editorTheme.font(for: .ui, style: .headline))
          .lineLimit(1)
          .accessibilityIdentifier(Self.titleIdentifier)
        Spacer(minLength: editorStyle.spacing.s)
        if let attachment {
          AttachmentActions(attachment: attachment, identifierPrefix: Self.identifierPrefix)
        }
      }
    } body: {
      if let attachment {
        AttachmentView(attachment)
      } else if let inlineText = artifact.inlineText {
        AttachmentTextContent(
          text: inlineText, type: UTType(artifact.type) ?? .plainText, filename: nil)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier(Self.inlineTextIdentifier)
      }
    }
    .contentTile()
    .inlineEdge(radius: Self.corners.radius(in: editorStyle))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.identifier)
    .agentAttachmentScope(attachment, focusRingCorners: Self.corners)
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

#Preview("Artifact") {
  ArtifactView(
    artifact: ArtifactPayload(
      id: "release-notes", title: "Release notes", type: UTType.plainText.identifier,
      inlineText: "Version 2.4.0 adds a dark theme, and each invoice now shows the currency of the customer."))
}
