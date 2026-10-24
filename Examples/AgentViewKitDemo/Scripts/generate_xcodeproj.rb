#!/usr/bin/env ruby
# frozen_string_literal: true

# generate_xcodeproj.rb: makes AgentViewKitDemo.xcodeproj again.
#
# The project shape is in `Examples/Scripts/xcodeproj_generator.rb`. This file names what is
# the demo's own. Run it after you add, remove, or rename a source file below
# `AgentViewKitDemo/`, `AgentViewKitDemoFeature/`, `Tests/`, or `Sources/DemoSupport/`.
# `Scripts/test-examples.sh` at the repository root runs it before each build. The
# `.xcodeproj` is git-ignored.
#
# Requires the `xcodeproj` gem (`gem install xcodeproj`).

require_relative '../../Scripts/xcodeproj_generator'

# The AgentViewKit product that the app links. `AgentViewKit` gives the session views. The
# in-process helper `InProcessAgent` is in FoundationModelsACPClient (`REMOTE_PACKAGES` below).
PACKAGE_PRODUCTS = %w[AgentViewKit].freeze

# The package target that compiles into the app: the in-memory agent, `DemoAgent` (which starts
# the agent and connects a `ConnectionModel`), and the launch options. It is not a product, so
# the app compiles its files.
SHARED_SOURCES = %w[../../Sources/DemoSupport].freeze

# The packages whose modules `Sources/DemoSupport` imports. FoundationModelsACPAgent is the
# agent of the ACP tab and of the Gallery tab, which runs in the app process. The app also
# imports the EditorKit theme modules `EditorSwiftUI`, `EditorTheme` and `EditorStyle`, to set
# the theme and the shared style of the kit views, and the EditorKit command modules `EditorCommands` and `EditorCommandsUI`,
# to mirror the agent commands into the menu bar with `EditorMenuCommands`.
# `Package.swift` depends on the same packages, so the build uses one copy of each.
REMOTE_PACKAGES = {
  'git@github.com:swissarmyhammer/FoundationModelsACP.git' => %w[FoundationModelsACP],
  'git@github.com:swissarmyhammer/FoundationModelsACPClient.git' => %w[FoundationModelsACPClient],
  'git@github.com:swissarmyhammer/FoundationModelsACPAgent.git' => %w[FoundationModelsACPAgent],
  'git@github.com:swissarmyhammer/EditorKit.git' => %w[EditorSwiftUI EditorTheme EditorStyle EditorCommands EditorCommandsUI]
}.freeze

# The directories that the app bundle holds as they are. `RecordedSessions` holds the recorded
# sessions of FoundationModelsACPAgent that the Gallery tab shows.
RESOURCES = %w[RecordedSessions].freeze

ExampleXcodeproj.generate(
  root: File.expand_path('..', __dir__),
  app_name: 'AgentViewKitDemo',
  package_products: PACKAGE_PRODUCTS,
  shared_sources: SHARED_SOURCES,
  remote_packages: REMOTE_PACKAGES,
  resources: RESOURCES
)
