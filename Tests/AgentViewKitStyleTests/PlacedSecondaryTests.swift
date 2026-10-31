import AgentViewKitStyle
import SwiftUI
import Testing

/// Tests where text keeps the vibrant styles (`style.md`, rule 6).
@Suite struct PlacedSecondaryTests {
  @Test func textOutOfAnyBarIsContent() {
    #expect(!EnvironmentValues().showsVibrantText)
  }

  @Test func textOnChromeKeepsTheVibrantStyles() {
    var environment = EnvironmentValues()
    environment.isOnChrome = true
    #expect(environment.showsVibrantText)
  }
}
