---
assignees:
- claude-code
depends_on:
- 01M443H1PVEMMXJ3E2VK9MXMEM
position_column: todo
position_ordinal: '8680'
title: Remove the FoundationModels tab from the demo app
---
## What
The demo app has a FoundationModels tab. Remove it before the target removal, so that the examples gate (`Scripts/test-examples.sh`) stays green. Source: update.md §7 item 2.

- [ ] Delete `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/FoundationModelsTabView.swift` and `Examples/AgentViewKitDemo/Tests/FoundationModelsTabEndToEndTests.swift`.
- [ ] Remove the tab from `DemoRootView.swift`. Remove the FoundationModels values from `Tests/DemoTestValues.swift`.
- [ ] Make the Xcode project again with `Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb`. Do not change `PACKAGE_PRODUCTS` here; the target removal task does that.

## Acceptance Criteria
- [ ] No file in `Examples/AgentViewKitDemo/` refers to the FoundationModels tab.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` builds the app and the ACP end-to-end test passes.

## Tests
- [ ] `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` passes with no change.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.