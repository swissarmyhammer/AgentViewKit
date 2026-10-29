/// The paths of the nested integration package, relative to the root of the
/// root package (plan.md §11 decision 21).
///
/// The source scans of the test code read ``testsPath`` next to the test
/// targets of the root package, so that each rule of the test code holds in
/// both packages. A scan reads only these paths, and never the whole
/// `IntegrationTests/` folder, because its `.build` folder holds the
/// checkouts of the dependencies.
enum IntegrationPackage {
  /// The test targets of the integration package: the hosted, snapshot,
  /// pixel, focus-ring and review gallery tests, with their helpers.
  static let testsPath = "IntegrationTests/Tests"

  /// The manifest of the integration package.
  static let manifestPath = "IntegrationTests/Package.swift"
}
