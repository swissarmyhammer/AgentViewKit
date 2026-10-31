import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The grouped form of an inspector (EditorKit `style.md`, "The inspector").
///
/// The form has the grouped style, with the system margins and row insets and
/// no padding of its own. It hides its scroll background, because a grouped
/// form draws an opaque background of its own and a kit view is transparent,
/// so the background of the host shows around the rows. Its rows take the `ui`
/// font role of the theme.
///
/// With a name, the first section holds the name, in the `ui` font role at the
/// headline style on one line with middle truncation, and the actions below
/// it. The content follows: the other sections of the form. A form with no
/// name is the shell alone, for a host that shows the same sections outside an
/// inspector.
///
/// The form takes plain values and views, so it knows no model. The host puts
/// its own accessibility identifier, command scope and focus ring on the form.
/// A preview in a section of the content takes
/// ``SwiftUI/View/inspectorPreviewFrame()``.
public struct InspectorForm<Actions: View, Content: View>: View {
  /// The name row of a form.
  private struct Name {
    /// The name of the item.
    let text: String

    /// The accessibility identifier of the row.
    let identifier: String
  }

  /// The name row, or `nil` for the shell alone.
  private let name: Name?

  /// The actions under the name.
  private let actions: Actions

  /// The other sections of the form.
  private let content: Content

  @Environment(\.editorTheme) private var editorTheme

  /// Makes the form of a named item.
  ///
  /// - Parameters:
  ///   - name: The name of the item.
  ///   - nameIdentifier: The accessibility identifier of the name row.
  ///   - actions: The actions under the name, such as an
  ///     ``InspectorActionRow``.
  ///   - content: The other sections of the form.
  public init(
    name: String, nameIdentifier: String, @ViewBuilder actions: () -> Actions, @ViewBuilder content: () -> Content
  ) {
    self.name = Name(text: name, identifier: nameIdentifier)
    self.actions = actions()
    self.content = content()
  }

  public var body: some View {
    Form {
      if let name {
        Section {
          Text(name.text)
            .font(editorTheme.font(for: .ui, style: .headline))
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityIdentifier(name.identifier)
          actions
        }
      }
      content
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

extension InspectorForm where Actions == EmptyView {
  /// Makes the shell of the form, with no name row.
  ///
  /// - Parameter content: The sections of the form.
  public init(@ViewBuilder content: () -> Content) {
    name = nil
    actions = EmptyView()
    self.content = content()
  }
}

/// The frame of a preview in an ``InspectorForm``.
struct InspectorPreviewFrame: ViewModifier {
  /// The height of the preview, in points (EditorKit `style.md`, "The
  /// inspector"). A row of a scrolling form has no height to fill, so the
  /// preview has a fixed height. It is not a space between controls, and the
  /// theme has no token for it.
  static let height: CGFloat = 240

  func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .frame(height: Self.height, alignment: .top)
  }
}

extension View {
  /// Gives this view the frame of a preview in an ``InspectorForm``: the full
  /// width of its row at the fixed height of a preview, with short content at
  /// the top leading corner.
  ///
  /// - Returns: The view in the frame of a preview.
  public func inspectorPreviewFrame() -> some View {
    modifier(InspectorPreviewFrame())
  }
}

#Preview("A named form, with actions and a preview") {
  InspectorForm(name: StylePreviewFixtures.fileName, nameIdentifier: "name") {
    InspectorActionRow {
      Button(StylePreviewFixtures.fileName, systemImage: SharedSymbol.edit) {}
      Button(StylePreviewFixtures.fileName, systemImage: SharedSymbol.delete) {}
    }
  } content: {
    Section {
      Text(StylePreviewFixtures.fileName)
        .inspectorPreviewFrame()
    }
  }
}

#Preview("The shell alone") {
  InspectorForm {
    Section {
      Text(StylePreviewFixtures.fileName)
    }
  }
}
