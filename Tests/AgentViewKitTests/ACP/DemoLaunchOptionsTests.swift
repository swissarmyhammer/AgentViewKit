import Foundation
import Testing

@testable import AgentViewKitDemoSupport

/// The tests of the launch arguments of the demo app.
struct DemoLaunchOptionsTests {
  /// The working directory that the tests give with `--cwd`.
  static let workingDirectory = "/tmp/demo"

  @Test func launchOptionsReadTheKnownArgumentsAndIgnoreTheOthers() {
    let options = DemoLaunchOptions(arguments: [
      "app", "-NSDocumentRevisionsDebugMode", "YES", InMemoryDemoAgent.launchArgument,
      DemoLaunchOptions.cwdArgument, Self.workingDirectory,
    ])

    #expect(options.acpAgent == .inMemory)
    #expect(options.cwd == Self.workingDirectory)
  }

  @Test func launchOptionsWithNoArgumentsUseTheDefaults() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.cwdArgument])

    #expect(options.acpAgent == .foundationModels(.live))
    #expect(options.cwd == FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false))
    #expect(options.initialTab == .acp)
  }

  @Test func theAgentNameOfTheACPTabNamesTheAgentOfTheOptions() {
    let inMemory = DemoLaunchOptions(arguments: ["app", InMemoryDemoAgent.launchArgument])
    let foundationModels = DemoLaunchOptions(arguments: ["app"])

    #expect(inMemory.agentName == InMemoryDemoAgent.name)
    #expect(foundationModels.agentName == DemoLaunchOptions.foundationModelsAgentName)
  }

  @Test func theTabArgumentSelectsTheTabThatTheWindowOpensOn() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.tabArgument, DemoTab.gallery.rawValue])

    #expect(options.initialTab == .gallery)
  }

  @Test func thePrimaryScreenArgumentOpensTheWindowOnThePrimaryScreen() {
    let withArgument = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.primaryScreenArgument])
    let withoutArgument = DemoLaunchOptions(arguments: ["app"])

    #expect(DemoLaunchOptions.primaryScreenArgument == "--primary-screen")
    #expect(withArgument.opensOnPrimaryScreen)
    #expect(!withoutArgument.opensOnPrimaryScreen)
  }

  @Test func theFrameOnThePrimaryScreenFillsTheHeightOfASmallVisibleFrame() {
    // A 1440 x 900 screen with a 25-pt menu bar and a 60-pt Dock.
    let visibleFrame = CGRect(x: 0, y: 60, width: 1440, height: 815)

    let frame = DemoWindowLayout.primaryScreenFrame(visibleFrame: visibleFrame)

    #expect(frame == CGRect(x: 0, y: 60, width: 1100, height: 815))
  }

  @Test func theFrameOnThePrimaryScreenKeepsTheDefaultSizeAtTheTopLeftOfALargeVisibleFrame() {
    // A 2560 x 1440 screen with a 25-pt menu bar and no Dock.
    let visibleFrame = CGRect(x: 0, y: 0, width: 2560, height: 1415)

    let frame = DemoWindowLayout.primaryScreenFrame(visibleFrame: visibleFrame)

    #expect(frame == CGRect(x: 0, y: 515, width: 1100, height: 900))
  }

  @Test func aTabArgumentWithAnUnknownNameKeepsTheACPTab() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.tabArgument, "unknown-tab"])

    #expect(options.initialTab == .acp)
  }
}
