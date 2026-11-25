import EditorCommands
import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The environment value that carries the header of a thread.
extension EnvironmentValues {
  /// The header that the nearest ``AgentThreadView`` shows above its
  /// transcript, or `nil`. Set it with ``SwiftUI/View/threadHeader(_:)`` or
  /// with ``SwiftUI/View/threadHeader(_:action:)``.
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
  /// ``SwiftUI/View/threadUnavailable(_:)``. When the thread view has a
  /// `headerContextMenuPath`, a right click on the header, on its text or
  /// on its empty space, shows the context menu of that path, the same menu
  /// as the status line. A button of the header keeps its own action.
  /// VoiceOver reads it as one
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
  /// For a header of one line of text and one command button, use
  /// ``SwiftUI/View/threadHeader(_:action:)``.
  ///
  /// - Parameter header: The view of the host.
  /// - Returns: A view whose thread views show the header.
  public func threadHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
    environment(\.threadHeader, AnyView(header()))
  }

  /// Shows a title of the host and the button of one EditorKit command
  /// above the transcript of the thread views in this view (TestudoApp
  /// D212), such as the header of the read-only tab of an external session:
  /// "Claude Code · read-only · Nov 21, 2026" and the button Continue in
  /// Testudo.
  ///
  /// The host gives the title, and localizes it. The button is an
  /// `EditorToolbarButton` of the command: the registry of the installed
  /// command system gives its title, its state and the reason when it is
  /// disabled, and a press runs the command at the scope of the thread. The
  /// host registers the command at that scope or at a scope above it. The
  /// kit writes no source name, no date and no button text.
  ///
  /// The header shows in the slot of ``SwiftUI/View/threadHeader(_:)``, with
  /// the same place, look and identifier
  /// ``AgentThreadLayout/headerIdentifier``. The title is one line at the
  /// leading edge, and the button is at the trailing edge. When the width is
  /// too small for the two, the title truncates at its tail and the button
  /// stays whole. VoiceOver reads the group of the header with the title
  /// text, and the button keeps its own label.
  ///
  /// ```swift
  /// AgentThreadView(session: external) { EmptyView() }
  ///   .threadHeader(
  ///     "\(source) · \(readOnly) · \(lastRecord.formatted(date: .abbreviated, time: .omitted))",
  ///     action: "app.continueInTestudo")
  /// ```
  ///
  /// - Parameters:
  ///   - title: The title of the host, already localized.
  ///   - command: The id of the EditorKit command of the button.
  /// - Returns: A view whose thread views show the header.
  public func threadHeader(_ title: String, action command: String) -> some View {
    threadHeader { ThreadHeaderBar(title: title, command: CommandID(command)) }
  }
}

/// The header of a title and one command button
/// (``SwiftUI/View/threadHeader(_:action:)``).
///
/// The title is one line that truncates at its tail, and it has a lower
/// layout priority than the button, so the button stays whole at a narrow
/// width. The button binds the command as the buttons of
/// ``MessageActions`` and of ``SideQuestionCard`` do.
struct ThreadHeaderBar: View {
  /// The title of the host.
  let title: String

  /// The id of the command of the button.
  let command: CommandID

  /// The style of the kit, which gives the space between the title and the
  /// button.
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Text(verbatim: title)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .layoutPriority(Self.titlePriority)
      Spacer(minLength: 0)
      EditorToolbarButton(command: command)
        .withoutSystemFocusEffect()
    }
  }

  /// The layout priority of the title: lower than the button, so the title
  /// gives its width first.
  static let titlePriority: Double = -1
}

/// The header of the host in the top bar of a thread.
///
/// The slot gives the view of the host the full width of the bar, at the
/// leading edge, and makes it one accessibility group with the identifier
/// ``AgentThreadLayout/headerIdentifier``. The slot draws no glass and adds
/// no padding (^rgsq3k4): the bar spaces its parts. The top bar shows the
/// context menu of the host path on its full frame, with the slot
/// (``HostPathContextMenu`` with its hit area), the same menu as on the
/// status line.
struct ThreadHeaderSlot: View {
  /// The view of the host.
  let header: AnyView

  var body: some View {
    header
      .editorButtonSurface(.content)
      .contentContainer(identifier: AgentThreadLayout.headerIdentifier)
  }
}
