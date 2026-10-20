import SwiftUI

/// The columns of the Gallery tab of the demo app: a sidebar, a detail, and
/// a Look button in the toolbar that shows the look controls.
///
/// The Gallery tab of the demo app shows its content in this view. The
/// package tests host the same view, because the demo app is not a target of
/// the package.
///
/// The look controls show in a popover of the button, not in an inspector.
/// The detail holds an `AgentThreadView`, and that view has its own
/// attachment inspector. A second inspector of the split view makes the
/// minimum width of the detail column equal to the width of the window, so
/// the window cannot get narrower. In a window that cannot get wider, the
/// column then sets a new minimum size in each constraint pass, and AppKit
/// stops the app with an `NSGenericException`.
public struct GalleryColumns<Sidebar: View, Detail: View, LookControls: View>: View {
  /// The sidebar column.
  let sidebar: Sidebar

  /// The detail column.
  let detail: Detail

  /// The controls of the look of the kit views.
  let lookControls: LookControls

  /// Whether the popover with the look controls shows.
  @State private var showsLookControls = false

  /// Makes the columns.
  ///
  /// - Parameters:
  ///   - sidebar: The sidebar column.
  ///   - detail: The detail column.
  ///   - lookControls: The controls of the look of the kit views.
  public init(
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder detail: () -> Detail,
    @ViewBuilder lookControls: () -> LookControls
  ) {
    self.sidebar = sidebar()
    self.detail = detail()
    self.lookControls = lookControls()
  }

  public var body: some View {
    NavigationSplitView {
      sidebar
    } detail: {
      detail
    }
    .toolbar {
      ToolbarItem {
        Button("Look", systemImage: GalleryColumnsLayout.lookSymbol) {
          showsLookControls.toggle()
        }
        .accessibilityIdentifier(GalleryColumnsLayout.lookButtonIdentifier)
        .popover(isPresented: $showsLookControls) {
          lookControls
            .frame(width: GalleryColumnsLayout.lookWidth)
        }
      }
    }
  }
}

/// The identifiers and the sizes of ``GalleryColumns``. A generic type has no
/// stored static property, so they are in this namespace.
public enum GalleryColumnsLayout {
  /// The accessibility identifier of the button that shows the look
  /// controls.
  public static let lookButtonIdentifier = "demo-gallery-look"

  /// The symbol of the button that shows the look controls.
  public static let lookSymbol = "paintpalette"

  /// The width of the popover with the look controls.
  public static let lookWidth: CGFloat = 300
}

#Preview("Gallery columns") {
  GalleryColumns {
    Text(verbatim: "Sidebar")
  } detail: {
    Text(verbatim: "Detail")
  } lookControls: {
    Text(verbatim: "Look controls")
  }
}
