/// The prefixes of the names of the temporary folders that the tests make.
///
/// A test passes one to `TemporaryFolder(prefix:)`, so each folder that a
/// test of AgentViewKit leaves behind names the package it came from.
public enum TestFolderPrefix {
  /// The prefix of each temporary folder of the tests of AgentViewKit.
  public static let agentViewKit = "AgentViewKitTests"
}
