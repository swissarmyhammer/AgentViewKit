import EditorStyle
import SwiftUI

/// The environment value that carries the header of a thread.
extension EnvironmentValues {
  /// The header that the nearest ``AgentThreadView`` shows above its
  /// transcript, or `nil`. Set it with ``SwiftUI/View/threadHeader(_:)``.
  @Entry var threadHeader: AnyView? = nil
}

/// The header slot of the thread view.
extension View {
  /// Shows a view of the host above the transcript of the thread views in
  /// this view (TestudoApp D208 (i)), such as "Shared by Ann · Updated
  /// today".
  ///
  /// The kit gives the slot, and the host gives the view, its text and its
  /// strings. The modifier sets an environment value that
  /// ``AgentThreadView`` reads. Thus it chains with the other modifiers of
  /// the thread, such as ``SwiftUI/View/threadUnavailable(_:)``,
  /// ``SwiftUI/View/sideCards(_:)`` and
  /// ``SwiftUI/View/transcriptSearchHits(_:)``, in each order. Apply it on
  /// the thread view: each thread view in this view shows the header. It
  /// works on each thread, read-only or not.
  ///
  /// The header shows in the top bar of the thread, below the status line
  /// and above the banners, at the full width of the bar. It is content
  /// with no glass (D110), and its buttons use the styles of content. The
  /// header stays while the thread shows the unavailable message of
  /// ``SwiftUI/View/threadUnavailable(_:)``. VoiceOver reads it as one
  /// group with the identifier ``AgentThreadLayout/headerIdentifier``, and
  /// each view of the host keeps its own label.
  ///
  /// ```swift
  /// AgentThreadView(session: shared) { EmptyView() }
  ///   .threadHeader {
  ///     Text("Shared by \(owner) · Updated \(updated, format: .relative(presentation: .named))")
  ///   }
  /// ```
  ///
  /// - Parameter header: The view of the host.
  /// - Returns: A view whose thread views show the header.
  public func threadHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
    environment(\.threadHeader, AnyView(header()))
  }
}

/// The header of the host in the top bar of a thread.
///
/// The slot gives the view of the host the full width of the bar, at the
/// leading edge, and makes it one accessibility group with the identifier
/// ``AgentThreadLayout/headerIdentifier``. The slot draws no glass and adds
/// no padding (^rgsq3k4): the bar spaces its parts.
struct ThreadHeaderSlot: View {
  /// The view of the host.
  let header: AnyView

  var body: some View {
    header
      .editorButtonSurface(.content)
      .contentContainer(identifier: AgentThreadLayout.headerIdentifier)
  }
}
