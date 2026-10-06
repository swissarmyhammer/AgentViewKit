import AppKit
import FoundationModelsACP
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
///
/// The view shows a kit ``ResourceLink``, or an ACP `ResourceLink` that a
/// transcript entry holds.
public struct LinkView: View {
  /// The accessibility identifier of the card.
  public static let cardIdentifier = "link-card"

  /// The largest width of the card, in points.
  private static let maximumCardWidth: CGFloat = 400

  /// The link to show: a kit link of a thread message, or an ACP link that
  /// a transcript entry holds.
  let source: BlockSource<ResourceLink, FoundationModelsACP.ResourceLink>

  /// The loaded first icon of the link, or `nil`.
  @State private var icon: NSImage?

  @Environment(\.openURL) private var openURL

  /// Makes the view of a resource link.
  ///
  /// - Parameter link: The link to show.
  public init(link: ResourceLink) {
    self.source = .record(link)
  }

  /// Makes the view of an ACP resource link of a transcript entry.
  ///
  /// - Parameter link: The ACP link to show, as the entry holds it.
  public init(link: FoundationModelsACP.ResourceLink) {
    self.source = .wire(link)
  }

  /// The name, the URI, and the source of the first icon of the link.
  private var parts: (name: String, uri: String, iconSource: String?) {
    switch source {
    case .record(let link): (link.name, link.uri, link.icons.first?.src)
    case .wire(let link): (link.name, link.uri, link.icons?.first?.src)
    }
  }

  public var body: some View {
    let (name, uri, iconSource) = parts
    if let url = URL(string: uri) {
      Button {
        openURL(url)
      } label: {
        LinkCard(name: name, url: url, icon: icon)
          .allowsHitTesting(false)
          .frame(maxWidth: Self.maximumCardWidth, alignment: .leading)
      }
      .buttonStyle(.plain)
      .help(uri)
      .accessibilityLabel(name)
      .accessibilityHint(uri)
      .accessibilityIdentifier(Self.cardIdentifier)
      .task(id: iconSource) {
        icon = await Self.loadIcon(from: iconSource)
      }
    } else {
      VStack(alignment: .leading) {
        Text(name)
        Text(uri)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// Loads the image of an icon.
  ///
  /// - Parameter iconSource: The URI of the icon, or `nil`.
  /// - Returns: The image, or `nil` when there is no icon, when its source
  ///   is not a URL, or when the load fails.
  private static func loadIcon(from iconSource: String?) async -> NSImage? {
    guard let source = iconSource.flatMap({ URL(string: $0) }),
      let (data, _) = try? await URLSession.shared.data(from: source)
    else { return nil }
    return NSImage(data: data)
  }
}

/// An `LPLinkView` card with metadata that the kit makes.
private struct LinkCard: NSViewRepresentable {
  /// The name of the resource.
  let name: String

  /// The URL of the link.
  let url: URL

  /// The icon to show, or `nil`.
  let icon: NSImage?

  func makeNSView(context: Context) -> LPLinkView {
    context.coordinator.remember(name: name, url: url, icon: icon)
    return LPLinkView(metadata: metadata)
  }

  func updateNSView(_ view: LPLinkView, context: Context) {
    guard !context.coordinator.shows(name: name, url: url, icon: icon) else { return }
    context.coordinator.remember(name: name, url: url, icon: icon)
    view.metadata = metadata
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// Keeps the name, the URL and the icon that the card shows, so that an
  /// update with the same values does not make the metadata again.
  final class Coordinator {
    /// The name that the card shows.
    private var name: String?

    /// The URL that the card shows.
    private var url: URL?

    /// The icon that the card shows.
    private var icon: NSImage?

    /// Tells whether the card shows a name, a URL and an icon.
    ///
    /// - Parameters:
    ///   - name: The name of the resource.
    ///   - url: The URL of the link.
    ///   - icon: The icon, or `nil`.
    /// - Returns: `true` when the card shows the same name, the same URL and
    ///   the same icon object.
    func shows(name: String, url: URL, icon: NSImage?) -> Bool {
      self.name == name && self.url == url && self.icon === icon
    }

    /// Records the name, the URL and the icon that the card shows.
    ///
    /// - Parameters:
    ///   - name: The name of the resource.
    ///   - url: The URL of the link.
    ///   - icon: The icon, or `nil`.
    func remember(name: String, url: URL, icon: NSImage?) {
      self.name = name
      self.url = url
      self.icon = icon
    }
  }

  /// The metadata of the card: the URL, the name, and the icon.
  private var metadata: LPLinkMetadata {
    let metadata = LPLinkMetadata()
    metadata.originalURL = url
    metadata.url = url
    metadata.title = name
    metadata.iconProvider = icon.map { NSItemProvider(object: $0) }
    return metadata
  }
}
