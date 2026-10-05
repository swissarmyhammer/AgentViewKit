---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m461383rw1hmedcqezaqypth
  text: |-
    Picked up. The skip condition of this card applies.

    Evidence (2026-10-05):
    - `git ls-remote git@github.com:swissarmyhammer/FoundationModelsACPClient.git` gives `refs/heads/main` = `be7e615`.
    - `git branch -r --contains a65af8a` in ../FoundationModelsACPClient gives `origin/main`. Thus `a65af8a` ("refactor!: remove ACPSessionState, SessionEntry and SwiftUIACPClient") is pushed.
    - The card says: "If FoundationModelsACPClient `a65af8a` (or later) is pushed when this task starts, skip this task. The second pin move task does the move in one step." The second pin move task is ^sbncn28.

    Thus no file is changed. The three `Package.resolved` files stay at FoundationModelsACP `3b0a4fd` and FoundationModelsACPClient `144b168`. They agree now.

    Gap to know: the test `Tests/PackageStructureTests/ResolvedPinsTests.swift` is in the Tests section of this card. ^sbncn28 has the acceptance criterion "`ResolvedPinsTests` passes", but its description does not tell the agent to write the test. Because this card is skipped, the agent of ^sbncn28 must write `ResolvedPinsTests` (it reads the three `Package.resolved` files with `PackageFileSupport` and asserts the same revision for each in-family package). A comment on ^sbncn28 records this.
  timestamp: 2026-10-05T12:37:24.216880+00:00
- actor: claude-code
  id: 01m4613e1pfzy904cb4tv30sqc
  text: |-
    ### implement — no-change
    - evidence: the skip condition of the card applies. `git ls-remote` of FoundationModelsACPClient gives remote `main` = `be7e615`, and `git branch -r --contains a65af8a` gives `origin/main`. No file is changed. No build or test was run, because no code changed.
    - next: ^sbncn28 does the pin move in one step, and it must also write `ResolvedPinsTests` (comment added on ^sbncn28). A person decides whether to close this card.
  timestamp: 2026-10-05T12:37:30.294113+00:00
- actor: claude-code
  id: 01m46145k0gf15ch0prn0bke57
  text: |-
    ### finish iteration 1 — skipped
    - implement: no-change — the skip condition on the card is true: FoundationModelsACPClient `a65af8a` is on the remote `main` (remote `main` is `be7e615`).
    - test: not run (no change)
    - commit: none
    - review: not run (no change)
    - next: ^sbncn28 does the pin move and now also writes `ResolvedPinsTests`. This task closes as skipped.
  timestamp: 2026-10-05T12:37:54.400313+00:00
depends_on:
- 01M443HB3E33J2VKEYYF9NN7AX
position_column: done
position_ordinal: d780
title: 'First pin move: FoundationModelsACP acf7700 and FoundationModelsACPClient 108e2d6 in the three Package.resolved files'
---
## What
Move the pins to a pair that is consistent and still has the old client API. Source: update.md §7 item 3 ("Now").

**Do not run a plain `swift package update`.** It takes the newest `main` of the two packages, and that removes the old client API. Pin each package to the given revision.

If FoundationModelsACPClient `a65af8a` (or later) is pushed when this task starts, skip this task. The second pin move task does the move in one step.

- [ ] Move FoundationModelsACP from `3b0a4fd` to `acf7700` (alpha.3 with the trace context codec), and FoundationModelsACPClient from `144b168` to `108e2d6`, in the root `Package.resolved`.
- [ ] Do the same move in `Benchmarks/Package.resolved` and in the `Package.resolved` of `Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj`.
- [ ] Make sure that the graph resolves. It brings `swift-metrics`, `swift-otel` and swift-log 1.15.1 or later. The Router and Extras pins go away, because the targets that used them are removed.

## Acceptance Criteria
- [ ] The three `Package.resolved` files give the same revisions for FoundationModelsACP and FoundationModelsACPClient.
- [ ] `swift build --build-tests`, `swift test`, `Scripts/check-benchmarks.sh`, `Scripts/check-readme.sh` and `Scripts/test-examples.sh AgentViewKitDemo` pass.

## Tests
- [ ] Add `Tests/PackageStructureTests/ResolvedPinsTests.swift`: it reads the three `Package.resolved` files and asserts that each in-family package has the same revision in each file. Use `PackageFileSupport`.
- [ ] `swift test` passes.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.