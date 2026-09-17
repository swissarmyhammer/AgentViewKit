# frozen_string_literal: true

# xcodeproj_generator.rb: the shared generator for the Xcode project of an example app.
#
# This file follows the shape of `../EditorKit/Examples/Scripts/xcodeproj_generator.rb`.
# An example is an Xcode project, not a SwiftPM executable, because SwiftPM cannot build a
# `.app` bundle.
#
# The project has two targets:
#
# - The application `<AppName>`. It compiles `<AppName>/` (the `@main` type and the scene),
#   `<AppName>Feature/` (the views), and each shared source directory that the example names.
#   An Xcode target can link a package PRODUCT only. A shared directory, such as
#   `Sources/DemoSupport`, is a package target that is not a product, so its files compile
#   into the application module.
# - The UI test bundle `<AppName>UITests`. It compiles `Tests/` and tests the application
#   through `XCUIApplication`.
#
# The `Scripts/generate_xcodeproj.rb` of an example names what is its own: the name, the
# package products it links, the shared source directories, and the remote packages whose
# modules the shared sources import. It then calls `ExampleXcodeproj.generate`.
#
# The generator requires the `xcodeproj` gem. Install it with `gem install xcodeproj`.
# `Scripts/test-examples.sh` at the repository root runs the generator of each example
# before it builds and tests it. The `.xcodeproj` is git-ignored, so a clean checkout has
# none.

require 'fileutils'
require 'xcodeproj'

# Generates the `.xcodeproj` of one example from its source directories.
module ExampleXcodeproj
  # The Swift language version of each build configuration.
  SWIFT_VERSION = '6.0'

  # The default actor isolation of each target. The package targets use
  # `.defaultIsolation(MainActor.self)`, and the shared sources compile into the application,
  # so the application uses the same default.
  DEFAULT_ACTOR_ISOLATION = 'MainActor'

  # The bundle identifier prefix of each target.
  BUNDLE_ID_PREFIX = 'org.agentviewkit.examples.'

  # The `platform` argument of `new_target` is `:osx`, not `:macos`. `:macos` gives a target
  # with no SDK.
  MACOS_PLATFORM = :osx

  # The macOS deployment floor. It is the `.macOS("27.0")` platform of `Package.swift`.
  DEPLOYMENT_TARGET = '27.0'

  # The path from the directory of an example to the AgentViewKit package root.
  PACKAGE_RELATIVE_PATH = '../..'

  # The suffix of the directory that holds the views of an example.
  FEATURE_SUFFIX = 'Feature'

  # The suffix of the UI test target.
  UI_TESTS_SUFFIX = 'UITests'

  # The directory, below the example, that holds the UI tests.
  TESTS_DIRECTORY = 'Tests'

  # The signing identity of each target: sign to run locally. The examples need no team.
  CODE_SIGN_IDENTITY = '-'

  # The `PRODUCT_BUNDLE_IDENTIFIER` for a target named `name`.
  def self.bundle_id(name)
    "#{BUNDLE_ID_PREFIX}#{name}"
  end

  # Generates `<root>/<app_name>.xcodeproj`. The call deletes and makes the project again each
  # time, so it is safe to run after a source file is added, removed, or renamed.
  #
  # - root: the directory of the example.
  # - app_name: the name of the app. It is the group, the source directory, the product name,
  #   and the scheme.
  # - package_products: the AgentViewKit products that the app links.
  # - shared_sources: the directories, relative to `root`, whose Swift files also compile into
  #   the app.
  # - remote_packages: a hash from a repository URL to the products of that package that the
  #   app links. Each package follows its `main` branch, as `Package.swift` does.
  def self.generate(root:, app_name:, package_products:, shared_sources: [], remote_packages: {})
    project_path = File.join(root, "#{app_name}.xcodeproj")
    FileUtils.rm_rf(project_path)
    project = Xcodeproj::Project.new(project_path)

    app_files = [app_name, "#{app_name}#{FEATURE_SUFFIX}", *shared_sources].flat_map do |directory|
      add_source_group(project, root, directory).files
    end
    app_target = add_app_target(project, app_name, app_files)
    add_package_products(project, app_target, add_local_package(project), package_products)
    remote_packages.each do |url, products|
      add_package_products(project, app_target, add_remote_package(project, url), products)
    end

    test_files = add_source_group(project, root, TESTS_DIRECTORY).files
    test_target = add_ui_test_target(project, app_name, app_target, test_files)

    save_scheme(project_path, app_name, app_target, test_target)
    project.save
    copy_package_pins(root, project_path)
    puts "Generated #{project_path}"
  end

  # The path of the pin file of a project, below the project directory.
  PROJECT_PINS_PATH = 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved'

  # Copies the `Package.resolved` of the package into the project, so that the app builds with
  # the same revision of each dependency as `swift build`.
  def self.copy_package_pins(root, project_path)
    pins = File.expand_path(File.join(PACKAGE_RELATIVE_PATH, 'Package.resolved'), root)
    destination = File.join(project_path, PROJECT_PINS_PATH)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(pins, destination)
  end

  # Adds a group for `directory`, relative to `root`. Its files are each `*.swift` file below
  # the directory, at any depth, as SwiftPM compiles them. `sort` makes the output stable.
  def self.add_source_group(project, root, directory)
    path = File.expand_path(directory, root)
    group = project.new_group(File.basename(directory), directory)
    Dir.glob(File.join(path, '**', '*.swift')).sort.each do |file|
      group.new_reference(file.delete_prefix("#{path}/"))
    end
    group
  end

  # The local package reference to the AgentViewKit checkout.
  #
  # Each object of the project comes from `project.new(Klass)`, because only that factory
  # gives the object its uuid.
  def self.add_local_package(project)
    package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    package.relative_path = PACKAGE_RELATIVE_PATH
    project.root_object.package_references << package
    package
  end

  # A remote package reference to `url` on its `main` branch.
  def self.add_remote_package(project, url)
    package = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package.repositoryURL = url
    package.requirement = { 'kind' => 'branch', 'branch' => 'main' }
    project.root_object.package_references << package
    package
  end

  # Adds each product in `products` of `package` as a dependency of `target`.
  def self.add_package_products(project, target, package, products)
    products.each do |product_name|
      dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
      dependency.package = package
      dependency.product_name = product_name
      target.package_product_dependencies << dependency
      build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
      build_file.product_ref = dependency
      target.frameworks_build_phase.files << build_file
    end
  end

  # The build settings that each target of an example has.
  def self.apply_common_settings(target, name)
    target.build_configuration_list.build_configurations.each do |config|
      settings = config.build_settings
      settings['SWIFT_VERSION'] = SWIFT_VERSION
      settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
      settings['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
      settings['GENERATE_INFOPLIST_FILE'] = 'YES'
      settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id(name)
      settings['PRODUCT_NAME'] = name
      settings['CODE_SIGN_STYLE'] = 'Manual'
      settings['CODE_SIGN_IDENTITY'] = CODE_SIGN_IDENTITY
      settings['DEVELOPMENT_TEAM'] = ''
    end
  end

  # The application target.
  def self.add_app_target(project, app_name, files)
    target = project.new_target(:application, app_name, MACOS_PLATFORM, DEPLOYMENT_TARGET, nil, :swift)
    apply_common_settings(target, app_name)
    target.build_configuration_list.build_configurations.each do |config|
      settings = config.build_settings
      settings['SWIFT_DEFAULT_ACTOR_ISOLATION'] = DEFAULT_ACTOR_ISOLATION
      settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
      settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
      settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
    end
    target.add_file_references(files)
    target
  end

  # The UI test bundle. `TEST_TARGET_NAME` names the app that the bundle drives.
  def self.add_ui_test_target(project, app_name, app_target, files)
    name = "#{app_name}#{UI_TESTS_SUFFIX}"
    target = project.new_target(:ui_test_bundle, name, MACOS_PLATFORM, DEPLOYMENT_TARGET, nil, :swift)
    apply_common_settings(target, name)
    target.build_configuration_list.build_configurations.each do |config|
      config.build_settings['TEST_TARGET_NAME'] = app_name
    end
    target.add_dependency(app_target)
    target.add_file_references(files)
    target
  end

  # The shared scheme. It builds and launches the app, and its test action runs the UI tests.
  def self.save_scheme(project_path, app_name, app_target, test_target)
    scheme = Xcodeproj::XCScheme.new
    scheme.add_build_target(app_target)
    scheme.set_launch_target(app_target)
    scheme.add_test_target(test_target)
    scheme.save_as(project_path, app_name, true)
  end
end
