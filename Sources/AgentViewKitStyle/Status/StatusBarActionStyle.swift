import SwiftUI

/// The button of a ``StatusBar``: the title and the symbol of its
/// ``StatusBar/Action``, disabled when the action takes no press, with the
/// accessibility identifier and the hint of the action.
///
/// The button has no button style of its own. A ``StatusBarActionStyle``
/// gives it one, and can add more around it, such as a focus scope.
public struct StatusBarActionButton: View {
  /// The action of the button.
  let action: StatusBar.Action

  /// Makes the button of an action.
  ///
  /// - Parameter action: The action of the button.
  public init(action: StatusBar.Action) {
    self.action = action
  }

  public var body: some View {
    Button(action.title, systemImage: action.systemImage, action: action.perform)
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

/// The default look of the button of a ``StatusBar``: the `.glass` button
/// style. A bar is content, and the content scrolls under the bars of a view,
/// so its button keeps the glass style (TestudoApp `features/style.md`, rule
/// 4).
public struct GlassStatusBarActionStyle: StatusBarActionStyle {
  /// Makes the default style.
  public init() {}

  /// Gives the button the `.glass` style.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The button in the `.glass` style.
  public func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button.buttonStyle(.glass)
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

/// A style that puts a border around the button, to show a style of the
/// environment in the preview.
private struct BorderedStatusBarActionStyle: StatusBarActionStyle {
  func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    configuration.button.buttonStyle(.bordered)
  }
}

#Preview("The default style, and a style of the environment") {
  VStack(alignment: .leading) {
    StatusBar(message: StylePreviewFixtures.failureStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
    StatusBar(message: StylePreviewFixtures.failureStatusMessage, action: StylePreviewFixtures.statusAction(isEnabled: true))
      .statusBarActionStyle(BorderedStatusBarActionStyle())
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
