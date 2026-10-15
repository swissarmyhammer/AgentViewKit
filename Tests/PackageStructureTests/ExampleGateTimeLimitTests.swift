import Foundation
import PackageFileSupport
import Testing

/// Holds the time limit of `Scripts/test-examples.sh` to its whole job: at the
/// limit, the script stops the command, each process of the command, the app
/// under test and the UI test runner.
///
/// XCUITest starts the app under test and the test runner through launchd. They
/// are not in the process group of `xcodebuild`, so the script finds them by the
/// path of their executable in the DerivedData directory of the example.
///
/// The script has a `--self-test` mode. It starts a command with a sleeping
/// child, a fake app and a fake test runner in a temporary DerivedData
/// directory, and one sleeping process outside that directory. Each fake
/// process is only `sleep`. The self-test runs the command with a time limit of
/// one second, and it fails when one of the four processes stays alive, or when
/// the process outside the directory stops.
@Suite struct ExampleGateTimeLimitTests {
  /// The gate script, relative to the package root.
  static let scriptPath = "Scripts/test-examples.sh"

  /// The line that the self-test writes when each check passes.
  static let passLine = "PASS self-test"

  /// The output and the exit status of one run of the script.
  struct ScriptRun {
    /// The standard output and the standard error, in one text.
    let output: String

    /// The exit status of the script.
    let status: Int32
  }

  /// Runs the gate script with `bash`, from the package root.
  ///
  /// - Parameter arguments: The arguments of the script.
  /// - Returns: The output and the exit status of the run.
  static func runScript(arguments: [String]) throws -> ScriptRun {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/bash")
    process.arguments = [try PackageFiles.file(scriptPath).path(percentEncoded: false)] + arguments
    process.currentDirectoryURL = PackageFiles.root
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ScriptRun(output: String(decoding: data, as: UTF8.self), status: process.terminationStatus)
  }

  @Test func theTimeLimitStopsTheCommandTheAppUnderTestAndTheTestRunner() throws {
    let run = try Self.runScript(arguments: ["--self-test"])

    #expect(run.status == 0, "\(run.output)")
    #expect(run.output.contains(Self.passLine), "\(run.output)")
  }
}
