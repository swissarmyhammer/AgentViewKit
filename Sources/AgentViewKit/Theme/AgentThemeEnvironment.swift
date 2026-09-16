import SwiftUI

extension EnvironmentValues {
  /// The design tokens that the views of the kit read.
  ///
  /// The value is ``AgentTheme/default`` until a view sets a different
  /// theme with ``SwiftUI/View/agentTheme(_:)``.
  @Entry public var agentTheme: AgentTheme = .default
}

extension View {
  /// Sets the design tokens of the kit for this view and each view in it.
  ///
  /// - Parameter theme: The tokens to use.
  /// - Returns: A view that gives `theme` to its subtree.
  public func agentTheme(_ theme: AgentTheme) -> some View {
    environment(\.agentTheme, theme)
  }
}
