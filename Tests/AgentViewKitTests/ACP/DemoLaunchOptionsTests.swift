import Foundation
import Testing

@testable import DemoSupport

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

  @Test func aTabArgumentWithAnUnknownNameKeepsTheACPTab() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.tabArgument, "unknown-tab"])

    #expect(options.initialTab == .acp)
  }
}
