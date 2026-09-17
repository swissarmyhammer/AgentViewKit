import AppKit
import LinkPresentation
import SwiftUI

/// The default view of a resource link block (plan.md §4, §9 A2, §9 F).
///
/// The view shows an `LPLinkView` card with the name of the resource. When
/// the link has icons, the view loads the first icon and shows it on the
/// card. The card does not get other metadata from the network. A press on
/// the card opens the link through the `openURL` action of the environment,
/// so the link opens in the browser of the user. A link with a URI that is
/// not a URL shows the name and the URI as text.
public struct LinkView: View {
  /// The accessibility identifier of the card.
  public static let cardIdentifier = "link-card"

  /// The largest width of the card, in points.
  private static let maximumCardWidth: CGFloat = 400

  /// The link to show.
  let link: ResourceLink

  /// The loaded first icon of the link, or `nil`.
  @State private var icon: NSImage?

  @Environment(\.openURL) private var openURL

  /// Makes the view of a resource link.
  ///
  /// - Parameter link: The link to show.
  public init(link: ResourceLink) {
    self.link = link
  }

  public var body: some View {
    if let url = URL(string: link.uri) {
      Button {
        openURL(url)
      } label: {
        LinkCard(link: link, url: url, icon: icon)
          .allowsHitTesting(false)
          .frame(maxWidth: Self.maximumCardWidth, alignment: .leading)
      }
      .buttonStyle(.plain)
      .help(link.uri)
      .accessibilityLabel(link.name)
      .accessibilityHint(link.uri)
      .accessibilityIdentifier(Self.cardIdentifier)
      .task(id: link.icons.first) {
        icon = await Self.loadIcon(link.icons.first)
      }
    } else {
      VStack(alignment: .leading) {
        Text(link.name)
        Text(link.uri)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// Loads the image of an icon.
  ///
  /// - Parameter icon: The icon, or `nil`.
  /// - Returns: The image, or `nil` when there is no icon, when its source
  ///   is not a URL, or when the load fails.
  private static func loadIcon(_ icon: ResourceIcon?) async -> NSImage? {
    guard let source = icon.flatMap({ URL(string: $0.src) }),
      let (data, _) = try? await URLSession.shared.data(from: source)
    else { return nil }
    return NSImage(data: data)
  }
}

/// An `LPLinkView` card with metadata that the kit makes.
private struct LinkCard: NSViewRepresentable {
  /// The link to show.
  let link: ResourceLink

  /// The URL of the link.
  let url: URL

  /// The icon to show, or `nil`.
  let icon: NSImage?

  func makeNSView(context: Context) -> LPLinkView {
    context.coordinator.remember(link: link, icon: icon)
    return LPLinkView(metadata: metadata)
  }

  func updateNSView(_ view: LPLinkView, context: Context) {
    guard !context.coordinator.shows(link: link, icon: icon) else { return }
    context.coordinator.remember(link: link, icon: icon)
    view.metadata = metadata
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// Keeps the link and the icon that the card shows, so that an update with
  /// the same values does not make the metadata again.
  final class Coordinator {
    /// The link that the card shows.
    private var link: ResourceLink?

    /// The icon that the card shows.
    private var icon: NSImage?

    /// Tells whether the card shows a link and an icon.
    ///
    /// - Parameters:
    ///   - link: The link.
    ///   - icon: The icon, or `nil`.
    /// - Returns: `true` when the card shows the same link and the same icon
    ///   object.
    func shows(link: ResourceLink, icon: NSImage?) -> Bool {
      self.link == link && self.icon === icon
    }

    /// Records the link and the icon that the card shows.
    ///
    /// - Parameters:
    ///   - link: The link.
    ///   - icon: The icon, or `nil`.
    func remember(link: ResourceLink, icon: NSImage?) {
      self.link = link
      self.icon = icon
    }
  }

  /// The metadata of the card: the URL, the name, and the icon.
  private var metadata: LPLinkMetadata {
    let metadata = LPLinkMetadata()
    metadata.originalURL = url
    metadata.url = url
    metadata.title = link.name
    metadata.iconProvider = icon.map { NSItemProvider(object: $0) }
    return metadata
  }
}
