import EditorStyle
import EditorSwiftUI
import SwiftUI

/// The button of a ``StatusBar``: an EditorKit `EditorButton` in the action
/// look, with the title and the symbol of its ``StatusBar/Action``, disabled
/// when the action takes no press, with the accessibility identifier and the
/// hint of the action.
///
/// The button hides its caption and keeps its symbol when the bar has no room
/// for the caption, and its title stays its accessibility label and its
/// tooltip then (EditorKit `style.md`, "Buttons"). It shows only its symbol
/// when the action asks for it (``StatusBar/Action/isIconOnly``). Its look
/// comes from `\.editorStyle.buttons` and from the surface it stands on: the
/// glass style in content, and the bordered style on a glass surface
/// (`.editorButtonSurface(_:)`). A ``StatusBarActionStyle`` can add more
/// around it, such as a focus scope.
public struct StatusBarActionButton: View {
  /// The action of the button.
  let action: StatusBar.Action

  /// Whether the captions of the buttons here show when they have room.
  @Environment(\.editorButtonCaptions) private var captions

  /// Makes the button of an action.
  ///
  /// - Parameter action: The action of the button.
  public init(action: StatusBar.Action) {
    self.action = action
  }

  public var body: some View {
    EditorButton(action.title, systemImage: action.systemImage, look: .action, action: action.perform)
      .editorButtonCaptions(action.isIconOnly ? .hidden : captions)
      .disabled(!action.isEnabled)
      .accessibilityIdentifier(action.identifier)
      .modifier(AccessibilityHint(hint: action.hint))
  }
}

/// The accessibility hint of a button, when it has one.
private struct AccessibilityHint: ViewModifier {
  /// The hint, or `nil` for no hint.
  let hint: String?

  func body(content: Content) -> some View {
    if let hint {
      content.accessibilityHint(hint)
    } else {
      content
    }
  }
}

/// The render-time configuration of the button of a ``StatusBar``, as a
/// `ButtonStyleConfiguration` is the configuration of a button.
public struct StatusBarActionConfiguration {
  /// The action of the button.
  public let action: StatusBar.Action

  /// The button of the action, with no button style.
  public let button: StatusBarActionButton

  /// Makes the configuration of the button of an action.
  ///
  /// - Parameters:
  ///   - action: The action of the button.
  ///   - button: The button of the action, with no button style.
  public init(action: StatusBar.Action, button: StatusBarActionButton) {
    self.action = action
    self.button = button
  }
}

/// The look of the button of a ``StatusBar``: a style protocol that mirrors
/// `ButtonStyle`, as the jump label style of EditorKit does.
///
/// A view kit sets its style with ``SwiftUI/View/statusBarActionStyle(_:)``
/// where it shows a bar. AgentViewKit gives the button the button style of
/// its place and the focus scope of a bar control this way. With no style in
/// the environment, a bar uses ``GlassStatusBarActionStyle``.
@MainActor
public protocol StatusBarActionStyle {
  /// The view that the style makes.
  associatedtype Body: View

  /// Makes the button of a bar.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The styled button.
  @ViewBuilder func makeBody(configuration: StatusBarActionConfiguration) -> Body
}

/// The default look of the button of a ``StatusBar``: the button of the action
/// as it is, in the action look of EditorKit's `EditorButton`. A bar is
/// content, and the content scrolls under the bars of a view, so its button
/// keeps the glass style there (EditorKit `style.md`, rule 4).
public struct GlassStatusBarActionStyle: StatusBarActionStyle {
  /// Makes the default style.
  public init() {}

  /// Shows the button of the action as it is.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The button, in the action look of its surface.
  public func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button
  }
}

extension EnvironmentValues {
  /// The style of the button of each ``StatusBar`` in this view, or `nil`
  /// for ``GlassStatusBarActionStyle``.
  @Entry var statusBarActionStyle: ErasedStyle<StatusBarActionConfiguration>? = nil
}

extension View {
  /// Sets the style of the button of each ``StatusBar`` in this view.
  ///
  /// - Parameter style: The style of the button.
  /// - Returns: A view whose bars show their buttons with `style`.
  public func statusBarActionStyle<Style: StatusBarActionStyle>(_ style: Style) -> some View {
    environment(\.statusBarActionStyle, ErasedStyle(style.makeBody(configuration:)))
  }
}

/// A style that stands the button on a glass surface, where the action look
/// is bordered, to show a style of the environment in the preview.
private struct GlassSurfaceStatusBarActionStyle: StatusBarActionStyle {
  func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button.editorButtonSurface(.glass)
  }
}

#Preview("The default style, and a style of the environment") {
  VStack(alignment: .leading) {
    StatusBar(message: StylePreviewFixtures.failureStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
    StatusBar(message: StylePreviewFixtures.failureStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
      .statusBarActionStyle(GlassSurfaceStatusBarActionStyle())
  }
  .padding()
}

#Preview("The button with no style, enabled and disabled") {
  HStack {
    StatusBarActionButton(action: StylePreviewFixtures.statusAction(isEnabled: true))
    StatusBarActionButton(action: StylePreviewFixtures.statusAction(isEnabled: false))
  }
  .padding()
}
