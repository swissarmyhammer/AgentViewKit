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

# The AgentViewKit products that the app links. `AgentViewKit` gives the views and the model.
# `AgentViewKitACP` gives `ACPThreadSource`, `ACPThreadActions`, and `ACPSessionList`.
PACKAGE_PRODUCTS = %w[AgentViewKit AgentViewKitACP].freeze

# The package target that compiles into the app: the in-memory agent, the ACP session model,
# and the launch options. It is not a product, so the app compiles its files.
SHARED_SOURCES = %w[../../Sources/DemoSupport].freeze

# The packages whose modules `Sources/DemoSupport` imports. `Package.swift` depends on the same
# packages, so the build uses one copy of each.
REMOTE_PACKAGES = {
  'git@github.com:swissarmyhammer/FoundationModelsACP.git' => %w[FoundationModelsACP],
  'git@github.com:swissarmyhammer/FoundationModelsACPClient.git' => %w[FoundationModelsACPClient]
}.freeze

ExampleXcodeproj.generate(
  root: File.expand_path('..', __dir__),
  app_name: 'AgentViewKitDemo',
  package_products: PACKAGE_PRODUCTS,
  shared_sources: SHARED_SOURCES,
  remote_packages: REMOTE_PACKAGES
)
