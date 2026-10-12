import AgentViewKit
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The look of the Gallery tab: the values that a person changes to judge
/// how the kit views show the recorded sessions.
///
/// Each value goes to the environment of the kit views through
/// ``SwiftUI/View/galleryLook(_:)``. The colors come only from the EditorKit
/// theme, so the views show each change of the theme and of the appearance.
struct GalleryLook: Equatable {
  /// An EditorKit theme that the Gallery can set.
  enum ThemeChoice: String, CaseIterable, Identifiable {
    /// `SystemTheme`, which follows the system appearance.
    case system

    /// The fixed light preset `DefaultTheme.light`.
    case defaultLight

    /// The fixed dark preset `DefaultTheme.dark`.
    case defaultDark

    /// The choice itself, so that a picker can list the choices.
    var id: Self { self }

    /// The name of the choice in the picker.
    var title: String {
      switch self {
      case .system: "System"
      case .defaultLight: "Default Light"
      case .defaultDark: "Default Dark"
      }
    }

    /// The EditorKit theme of the choice.
    var theme: any Theme {
      switch self {
      case .system: SystemTheme()
      case .defaultLight: DefaultTheme.light
      case .defaultDark: DefaultTheme.dark
      }
    }
  }

  /// The appearance of the window.
  enum Appearance: String, CaseIterable, Identifiable {
    /// The appearance of the system.
    case system

    /// The light appearance.
    case light

    /// The dark appearance.
    case dark

    /// The appearance itself, so that a picker can list the appearances.
    var id: Self { self }

    /// The name of the appearance in the picker.
    var title: String { rawValue.capitalized }

    /// The color scheme of the appearance, or `nil` for the system
    /// appearance.
    var colorScheme: ColorScheme? {
      switch self {
      case .system: nil
      case .light: .light
      case .dark: .dark
      }
    }
  }

  /// The EditorKit theme of the kit views.
  var theme = ThemeChoice.system

  /// The appearance of the window.
  var appearance = Appearance.system

  /// Whether the kit views show the increased contrast, also when the system
  /// setting is off.
  var increasedContrast = false

  /// The density of the rows of the kit views.
  var density = AgentTheme.default.density

  /// The text size of the kit views.
  var textSize = DynamicTypeSize.large

  /// The layout tokens of the kit views: the default tokens with
  /// ``density``.
  var agentTheme: AgentTheme {
    var tokens = AgentTheme.default
    tokens.density = density
    return tokens
  }
}

extension View {
  /// Gives the values of a Gallery look to the environment of this view and
  /// each view in it.
  ///
  /// - Parameter look: The look.
  /// - Returns: A view with the look.
  func galleryLook(_ look: GalleryLook) -> some View {
    modifier(GalleryLookModifier(look: look))
  }
}

/// The modifier of ``SwiftUI/View/galleryLook(_:)``.
private struct GalleryLookModifier: ViewModifier {
  /// The look to give to the environment.
  let look: GalleryLook

  /// The contrast of the system. The modifier keeps it when the look does not
  /// ask for the increased contrast.
  @Environment(\.colorSchemeContrast) private var systemContrast

  func body(content: Content) -> some View {
    content
      .editorTheme(look.theme.theme)
      .agentTheme(look.agentTheme)
      .dynamicTypeSize(look.textSize)
      .environment(\._colorSchemeContrast, look.increasedContrast ? .increased : systemContrast)
      .preferredColorScheme(look.appearance.colorScheme)
  }
}

/// The controls of a Gallery look, in a form.
struct GalleryLookControls: View {
  /// The look that the controls change.
  @Binding var look: GalleryLook

  var body: some View {
    Form {
      Picker("Theme", selection: $look.theme) {
        ForEach(GalleryLook.ThemeChoice.allCases) { choice in
          Text(choice.title).tag(choice)
        }
      }
      Picker("Appearance", selection: $look.appearance) {
        ForEach(GalleryLook.Appearance.allCases) { appearance in
          Text(appearance.title).tag(appearance)
        }
      }
      Toggle("Increased Contrast", isOn: $look.increasedContrast)
      Picker("Density", selection: $look.density) {
        ForEach(AgentTheme.Density.allCases, id: \.self) { density in
          Text(density.rawValue.capitalized).tag(density)
        }
      }
      Picker("Text Size", selection: $look.textSize) {
        ForEach(DynamicTypeSize.allCases, id: \.self) { size in
          Text(String(describing: size)).tag(size)
        }
      }
    }
    .formStyle(.grouped)
  }
}
