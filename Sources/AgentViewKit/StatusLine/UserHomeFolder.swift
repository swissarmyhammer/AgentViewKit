import Foundation

/// The real home folder of the user.
///
/// In a sandboxed app, `NSHomeDirectory()` and `HOME` give the container
/// folder of the app, not the home folder of the user. The user database
/// (`getpwuid(getuid())`) gives the real home folder. The status line shows
/// the real home folder as `~`, and the folder walk keeps out of the
/// protected folders of the real home folder.
nonisolated public enum UserHomeFolder {
  /// The path of the real home folder: the folder of the user database, or
  /// `NSHomeDirectory()` when the user database has no entry.
  public static var path: String {
    path(userDatabase: userDatabasePath, process: NSHomeDirectory())
  }

  /// The home folder of the user database, or `nil` when the user database
  /// has no entry for the user.
  static var userDatabasePath: String? {
    guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return nil }
    return String(cString: directory)
  }

  /// The home folder to use.
  ///
  /// - Parameters:
  ///   - userDatabase: The home folder of the user database, or `nil`.
  ///   - process: The home folder of the process (`NSHomeDirectory()`). In
  ///     a sandboxed app, this is the container folder of the app.
  /// - Returns: `userDatabase`, or `process` when `userDatabase` is `nil`.
  static func path(userDatabase: String?, process: String) -> String {
    userDatabase ?? process
  }
}
