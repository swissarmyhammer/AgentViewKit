import Foundation

/// The builtin languages of the `languages` module (D194 (g)).
///
/// The detect lists come from the language modules of starship. The symbol
/// of a language is a bundled icon (``StatusLineIcons``), so the name of the
/// icon is the name of the language.
nonisolated public enum StatusLineLanguages {
  /// The builtin languages, in the order of the starship modules.
  public static let builtin: [LanguagesModule.Language] = [
    language("c", extensions: ["c", "h"]),
    language("cpp", extensions: ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "ipp", "tpp"]),
    language("csharp", extensions: ["cs", "csx"], files: ["global.json", "Directory.Build.props"]),
    language("dart", extensions: ["dart"], files: ["pubspec.yaml", "pubspec.lock"], folders: [".dart_tool"]),
    language("docker", files: ["Dockerfile", "docker-compose.yml", "compose.yaml"]),
    language("elixir", extensions: ["ex", "exs"], files: ["mix.exs"]),
    language("go", extensions: ["go"], files: ["go.mod", "go.sum", "go.work"]),
    language("haskell", extensions: ["hs", "cabal", "hs-boot"], files: ["stack.yaml", "cabal.project"]),
    language("html", extensions: ["html", "htm"]),
    language("css", extensions: ["css", "scss", "sass", "less"]),
    language("java", extensions: ["java", "class", "gradle", "jar", "jsp"], files: ["pom.xml", "build.gradle"]),
    language(
      "javascript", extensions: ["js", "mjs", "cjs", "jsx"], files: ["package.json", ".node-version"],
      folders: ["node_modules"]),
    language("kotlin", extensions: ["kt", "kts"]),
    language("lua", extensions: ["lua"], files: [".lua-version"]),
    language("nix", extensions: ["nix"], files: ["flake.nix", "shell.nix"]),
    language("objc", extensions: ["m", "mm"]),
    language("php", extensions: ["php"], files: ["composer.json", ".php-version"]),
    language(
      "python", extensions: ["py", "ipynb"],
      files: ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile", ".python-version"]),
    language("ruby", extensions: ["rb"], files: ["Gemfile", ".ruby-version"]),
    language("rust", extensions: ["rs"], files: ["Cargo.toml"]),
    language("scala", extensions: ["scala", "sbt", "sc"], files: ["build.sbt"]),
    language("shell", extensions: ["sh", "bash", "zsh"]),
    language("swift", extensions: ["swift"], files: ["Package.swift"]),
    language("typescript", extensions: ["ts", "mts", "cts", "tsx"], files: ["tsconfig.json"]),
    language("zig", extensions: ["zig"], files: ["build.zig"]),
  ]

  /// Makes a builtin language with its bundled icon.
  private static func language(
    _ name: String, extensions: [String] = [], files: [String] = [], folders: [String] = []
  ) -> LanguagesModule.Language {
    LanguagesModule.Language(
      name: name, symbol: .icon(name), detectExtensions: extensions, detectFiles: files, detectFolders: folders)
  }
}
