import EditorTestSupport
import Foundation

/// The output and the exit status of one run of a script of the package.
///
/// The script tests run a script under `Scripts/` with `bash`, from the
/// package root, and read its result lines.
struct ScriptRun {
  /// The standard output and the standard error, in one text.
  let output: String

  /// The exit status of the script.
  let status: Int32

  /// Runs a script of the package with `/bin/bash`, from the package root.
  ///
  /// - Parameters:
  ///   - scriptPath: The script, relative to the package root.
  ///   - arguments: The arguments of the script.
  /// - Returns: The output and the exit status of the run.
  static func run(_ scriptPath: String, arguments: [String] = []) throws -> ScriptRun {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/bash")
    process.arguments = [try PackageFiles().file(scriptPath).path(percentEncoded: false)] + arguments
    process.currentDirectoryURL = PackageFiles().root
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ScriptRun(output: String(decoding: data, as: UTF8.self), status: process.terminationStatus)
  }
}
