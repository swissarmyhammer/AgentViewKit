---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7y415w9vr7b47srms3tew9m
  text: |-
    ### implement — changed
    - New public modifier `AgentRowList.rowAccessibilityLabel(_:)`: the host gives a `Text` for each item, and the row element (the container with the row identifier) gets it as its accessibility label. With no label, the row element has no label of its own, as before. The content elements stay as they are.
    - Files: Sources/AgentViewKit/Lists/AgentRowList.swift (`rowLabel`, `AgentRowListRow.label`, `AgentRowClicks.label`, `OptionalAccessibilityLabel`, docs). swift format also wrapped long lines in this file, and the row content is now a named argument (OnlyOneTrailingClosureArgument, which was in the file before).
    - Tests: new unit suite AgentRowListRowLabelTests (3 tests, pass). New hosted suite AgentRowListRowLabelHostedTests (3 tests, compile only, not run).
    - evidence: swift test: 1556 tests in 178 suites and 54 tests in 11 suites passed. IntegrationTests swift build --build-tests: Build complete. swift format lint -s: 0 findings.
    - next: commit, push, send the sha to testudoapp-9a. Testudo must call `.rowAccessibilityLabel` on its lists.
  timestamp: 2026-11-21T03:57:33.961500+00:00
- actor: claude-code
  id: 01m7yyrjghe74nr0b26kj353qy
  text: |-
    Check of dda19651 against the card:
    - Item "the label that the app sets": met by `rowAccessibilityLabel(_:)`.
    - Item "or else the text of its content": NOT met. With no `rowAccessibilityLabel`, the row element has no label (the hosted test `aRowElementWithNoHostLabelHasNoLabel` asserts this).
    - Item "unit test and hosted test": met for the label path only.
    - Item "push and send the sha": out of scope for this step (the orchestrator does not let this step push).

    Probe (scratch NSHostingView with no window, AXEnhancedUserInterface on, macOS 27):
    - `.accessibilityElement(children: .contain)` plus `.accessibilityLabel { _ in content }` gives the container the joined text of the content ("Idle, Session A, Delete"), and the children stay as they are.
    - `.accessibilityElement(children: .combine)` gives the label, but it removes the child elements. Do not use it.
    - A label that the content sets on itself (for example in `wrappingRows`) comes back one time for each text leaf ("App label, App label, App label"). So the app label path stays `rowAccessibilityLabel(_:)`.
    - The content in the label closure does not run `onAppear` a second time.
  timestamp: 2026-11-21T11:44:43.537811+00:00
- actor: claude-code
  id: 01m7yz98hvnyqp1gccpqy88zdg
  text: |-
    ### implement — changed
    - Fallback label: with no `rowAccessibilityLabel`, the row element (`agent-row-<list>/<id>`) now has the text of its content as its label, joined with commas (`.accessibilityLabel { _ in content }` in `AgentRowClicks.labeled(_:content:)`). The child elements stay as they are. `OptionalAccessibilityLabel` is removed (it had no other caller).
    - Docs: `AgentRowList`, `rowAccessibilityLabel(_:)`, `rowLabel` and the two `label` properties tell the fallback.
    - RED: unit test `aRowElementWithNoRowLabelHasTheTextOfItsContent` failed (label was nil). GREEN: it passes. New unit test `aRowElementWithARowLabelHasThatLabel`. Both read the accessibility tree of an NSHostingView with no window (`withAccessibilityTree`), so they show no window.
    - Hosted test `aRowElementWithNoHostLabelHasNoLabel` is now `aRowElementWithNoHostLabelHasTheTextOfItsContent` (compile only).
    - Other hosted tests that read row labels (ActivityTimeline, PendingRequestCountBadge) read content elements with their own identifiers; the change does not touch those elements.
    - evidence: swift test: 1563 tests in 179 suites and 54 tests in 11 suites passed, 0 warnings. IntegrationTests swift build --build-tests: Build complete. swift format lint -s on the 3 files: 0 findings.
    - files: Sources/AgentViewKit/Lists/AgentRowList.swift, Tests/AgentViewKitTests/Lists/AgentRowListRowLabelTests.swift, IntegrationTests/Tests/IntegrationTests/Lists/AgentRowListRowLabelHostedTests.swift
    - next: review. The push and the sha message to testudoapp-9a are still open; this step does not push.
  timestamp: 2026-11-21T11:53:50.395890+00:00
- actor: claude-code
  id: 01m7yzmxamvs1j5c5exxwgcfw1
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (2dd59b39). 0 findings, 0 confirmed, 0 refuted. 7 validator runs, 0 failed. 3 files reviewed. 6 .kanban files not reviewed (.reviewignore).
    - next: none. The task is in done.
  timestamp: 2026-11-21T12:00:12.116531+00:00
- actor: claude-code
  id: 01m7z2vh995t8qbw5dbavzw503
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 3 files (a row with no host label has the text of its content as its label)
    - test: green — swift test passed, 0 failures; IntegrationTests build passed (not run)
    - commit: 2dd59b39
    - review: clean — 0 findings
  timestamp: 2026-11-21T12:56:14.889300+00:00
position_column: done
position_ordinal: ffffffff8b80
title: The row container of AgentRowList has the label of the row (Testudo)
---
Request from testudoapp-9a (2026-11-20), proven with a hosted accessibility snapshot in Testudo.

Now: the row element of `AgentRowList` (`agent-row-<list>/<id>`) is an AXGroup container (`children: .contain`, `AgentRowClicks`) with no label. The name of the row is only on its child element, for example "Idle, Session …, other · 1 hits". A label that the app sets with `wrappingRows` stays on the child. VoiceOver and XCUITest read the row as unnamed. The Testudo search and import UI tests read `row.label`.

Do:
- Give the row container the label of the row: the label that the app sets, or else the text of its content.
- Add a unit test, and a hosted test (compile only; the hosted suites are not run locally).
- Push when `swift test` passes, and send the sha to testudoapp-9a.