---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m44ey6s8cny3vfdczzbwj3mg
  text: |-
    Research:
    - The FoundationModels tab is in 4 files of `Examples/AgentViewKitDemo/`: `FoundationModelsTabView.swift`, `FoundationModelsTabEndToEndTests.swift`, `DemoRootView.swift` (the second `Tab`), and `Tests/DemoTestValues.swift`.
    - `DemoTestValues` has no FoundationModels constant. The FoundationModels value in that file is the helper `XCUIApplication.element(withIdentifierPrefix:)`. Only `FoundationModelsTabEndToEndTests` calls it. After the delete it is dead code, so it goes.
    - `DemoTab.foundationModels` and `DemoLaunchOptions.initialTab` are in `Sources/DemoSupport`. They stay; the target removal task (^yf9nn7ax blocks on this card) removes the FoundationModels demo support. With one `Tab`, the `TabView` still compiles: `initialTab` is `.acp` unless a FoundationModels launch argument is present.
    - `generate_xcodeproj.rb` names the FoundationModels product and the FoundationModelsACP packages, not the tab. The card says not to change `PACKAGE_PRODUCTS` here. The `.xcodeproj` is git-ignored; `Scripts/test-examples.sh` makes it again before each build.
    - This is a delete, so there is no new unit test. The RED check is the acceptance grep: `rg FoundationModelsTab Examples/AgentViewKitDemo` finds matches before the change. The guard is `ACPTabEndToEndTests` through `Scripts/test-examples.sh AgentViewKitDemo`.
  timestamp: 2026-10-04T22:00:50.216628+00:00
- actor: claude-code
  id: 01m44fx45djpnmtj1jevt2ga5t
  text: |-
    Implementation landed. The UI test gate is blocked by the machine, not by the change.

    - Deleted `FoundationModelsTabView.swift` and `FoundationModelsTabEndToEndTests.swift` (working tree only, not staged).
    - `DemoRootView.swift`: removed the FoundationModels `Tab`. The `TabView` now has the ACP tab only.
    - `Tests/DemoTestValues.swift`: removed `XCUIApplication.element(withIdentifierPrefix:)`. Only the deleted FoundationModels test called it.
    - RED check before the change: `rg -i 'FoundationModelsTab|foundationModels\b|withIdentifierPrefix' Examples/AgentViewKitDemo` found 5 files. After: `rg -i 'FoundationModelsTab|\.foundationModels|withIdentifierPrefix|apple\.intelligence' Examples/AgentViewKitDemo` finds 0 (exit 1).
    - `Scripts/test-examples.sh AgentViewKitDemo`: `generate_xcodeproj.rb` ran, and the build step gave `** BUILD SUCCEEDED **`. The UI test step failed. `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` stopped at `app.launch()` with "Failed to activate application ... (current state: Running Background)". The script exited with 1.
    - Cause: the screen of the build machine is locked. `ioreg -n Root -d1 -a` shows `CGSSessionScreenIsLocked = true`. A locked screen does not let XCUIApplication bring the app to the foreground. The failure is at launch, before the test touches the tab, so the change did not cause it.
    - Blocker: the acceptance items "the ACP end-to-end test passes" and "`Scripts/test-examples.sh AgentViewKitDemo` exits with 0" are not shown. A person must unlock the screen of the build machine, then run `Scripts/test-examples.sh AgentViewKitDemo` again.
    - Correction to the research comment: the short id of the blocked target removal task is ^f9nn7ax, not ^yf9nn7ax.
  timestamp: 2026-10-04T22:17:43.341086+00:00
- actor: claude-code
  id: 01m44fx7h2yfrykr623nca165m
  text: |-
    ### implement — stuck
    - evidence: 4 files — Examples/AgentViewKitDemo/AgentViewKitDemoFeature/DemoRootView.swift (edit), Examples/AgentViewKitDemo/Tests/DemoTestValues.swift (edit), Examples/AgentViewKitDemo/AgentViewKitDemoFeature/FoundationModelsTabView.swift (deleted), Examples/AgentViewKitDemo/Tests/FoundationModelsTabEndToEndTests.swift (deleted). `Scripts/test-examples.sh AgentViewKitDemo`: BUILD SUCCEEDED; UI test failed at launch because the screen is locked (CGSSessionScreenIsLocked = true); exit 1.
    - next: unlock the screen of the build machine, run `Scripts/test-examples.sh AgentViewKitDemo` again, and expect exit 0. Then `/review`.
  timestamp: 2026-10-04T22:17:46.786772+00:00
- actor: claude-code
  id: 01m44fy1mwpa98pdp7r2c1ajj1
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — the FoundationModels tab is removed and the demo build passes; the ACPTabEndToEndTests UI test cannot start because the screen is locked (CGSSessionScreenIsLocked = true)
    - test: not run
    - commit: 81f9c52
    - review: not run
    - next: unlock the screen, run Scripts/test-examples.sh AgentViewKitDemo, then run /finish 9bynj0m
  timestamp: 2026-10-04T22:18:13.532538+00:00
depends_on:
- 01M443H1PVEMMXJ3E2VK9MXMEM
position_column: doing
position_ordinal: '80'
title: Remove the FoundationModels tab from the demo app
---
## What
The demo app has a FoundationModels tab. Remove it before the target removal, so that the examples gate (`Scripts/test-examples.sh`) stays green. Source: update.md §7 item 2.

- [x] Delete `Examples/AgentViewKitDemo/AgentViewKitDemoFeature/FoundationModelsTabView.swift` and `Examples/AgentViewKitDemo/Tests/FoundationModelsTabEndToEndTests.swift`.
- [x] Remove the tab from `DemoRootView.swift`. Remove the FoundationModels values from `Tests/DemoTestValues.swift`.
- [x] Make the Xcode project again with `Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb`. Do not change `PACKAGE_PRODUCTS` here; the target removal task does that.

## Acceptance Criteria
- [x] No file in `Examples/AgentViewKitDemo/` refers to the FoundationModels tab.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` builds the app and the ACP end-to-end test passes.

## Tests
- [ ] `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` passes with no change.
- [ ] `Scripts/test-examples.sh AgentViewKitDemo` exits with 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.