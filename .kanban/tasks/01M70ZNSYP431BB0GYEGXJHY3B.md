---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m710b5wr8akgnxqgx4d7s80t
  text: |-
    Implementation notes.
    - New file Sources/AgentViewKit/Inspection/InspectionName.swift: the shared helper. firstWords(of:) gives the first 6 words (word ranges of Foundation, runs of spaces and line breaks become one space, an ellipsis when the text has more words). message(author:startedAt:text:) gives "author · time" when the entry has both, else the first words. plan(_:) gives the first words of the first step that is not complete, else the last step.
    - Inspection.objectName(_:title:) in InspectionLabel.swift now holds the "nil name gives the title" rule. .named(...) and the message and unknown inspections use it.
    - Names: user, agent and thought messages have no author in FoundationModelsACPClient, so they use the first words. The session message uses its senderSessionId as the author, with its start time. Plan: current step. Compaction: first words of the summary, else the status. Error: first words of the message, else the code. Unknown update: its type. Connection: the agent name (initializeResponse.info.name), else the state. Tool call, terminal, session, MCP server and attachment had names already; the tests now cover them.
    - The example "agent-1" on the card is the message id of the gallery fixture, not an author. The entries have no author field.
    - Permission request, elicitation, plan entry and "agent" have no AVK inspection (no Inspectable conformance), so there is no block to name.
    - Tests read the name through `@testable import EditorInspector` and `InspectorBlock.header(of:in:)`, the same text the name row shows. The en_US time has U+202F before "AM".
    - No hosted test or gallery fixture asserts the old block names; both nested packages build with no change.
  timestamp: 2026-11-09T20:35:08.824378+00:00
- actor: claude-code
  id: 01m710b90qdyvahy9swjj5gtr9
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Inspection/InspectionName.swift (new), Sources/AgentViewKit/Inspection/InspectionLabel.swift, Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift, Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, README.md, Tests/AgentViewKitTests/Inspection/InspectionNameTests.swift (new, 24 tests). Root `swift test`: 1098 tests in 125 suites pass, and 50 tests in 10 suites pass. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass. No windowed test or gallery was run.
    - next: /review. The peer regenerates the gallery images inspector-*-two.
  timestamp: 2026-11-09T20:35:12.023280+00:00
- actor: claude-code
  id: 01m710gaby8wzeevnped50g2jh
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (2cc5a8a8). 1 finding, 1 confirmed, 0 refuted. Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift:86 (completeness/invariant-propagation).
    - acceptance: items 2, 3 and 4 are checked. Tests/AgentViewKitTests/Inspection/InspectionNameTests.swift has a "two items have two names" test for each inspection type. Root `swift test` passed (1098 tests in 125 suites, 50 tests in 10 suites). Both nested `--build-tests` builds passed. No windowed test was run. Item 1 stays open until the finding is fixed: an empty agent name gives an empty connection name.
    - next: fix the finding (treat an empty agent name as absent, add a test), then /review again.
  timestamp: 2026-11-09T20:37:57.246887+00:00
- actor: claude-code
  id: 01m710wcp4aa7w58kgkp2j54h6
  text: |-
    Fix of the review finding (empty agent name).
    - New helper InspectionName.present(_:): it gives nil for a text that is nil, empty, or only spaces and line breaks.
    - Inspection.objectName now applies present(_:) before it uses the title. Thus each `.named` inspection (tool call, terminal, attachment, session, connection) and each objectName site (message, unknown update) can never show an empty name row.
    - The MCP server inspection now goes through objectName. The unknown-update closure is now `{ $0.model.type }`; objectName does the empty check. The session name is present(title) ?? session id. The connection name is present(agent name) ?? state. A message author that is not present is absent, so the name is the first words.
    - Not possible headless: a session with an empty title. SessionModel.title is internal(set), and only a subagent_update through a live connection sets it. The unit tests of present(_:) cover the rule, and the session site is one line.
    - Tests (InspectionNameTests): empty and blank agent name give the state name; empty MCP server name, empty tool call title, blank terminal command and blank attachment name give the title of the type; empty and blank sender give the first words; three tests of present(_:).
    - README: one sentence tells that an empty value is not a name.
  timestamp: 2026-11-09T20:44:32.836027+00:00
- actor: claude-code
  id: 01m710wfqsh186160kqrtc6138
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/Inspection/InspectionName.swift, Sources/AgentViewKit/Inspection/InspectionLabel.swift, Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift, Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift, README.md, Tests/AgentViewKitTests/Inspection/InspectionNameTests.swift (34 tests, 10 new). Root `swift test`: 1108 tests in 125 suites pass, and 50 tests in 10 suites pass. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass. No windowed test or gallery was run. The finding and acceptance item 1 are checked.
    - next: /review.
  timestamp: 2026-11-09T20:44:35.961853+00:00
position_column: doing
position_ordinal: '80'
title: Each inspection of an item has a name that tells the item
---
## Problem
The gallery images inspector-agent-message-{wide,narrow}-two show two blocks. Both blocks have the name "Agent Message". This name is the title of the type, because the message inspection gives no `name`. The user must tell two blocks apart by their names (peer editorkit-9f, batch gallery review on 2026-11-09).

## Work
- Give each AVK inspection of an item a `name` (EK `.named(..., name:)` or the equivalent) that tells the item. Look at Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift and ClientModels+Inspectable.swift.
- Message (user, agent, thought, session): the author and the time, for example "agent-1 · 6:15 AM", or the first words of its text when there is no author or time. Use one shared helper for the first words.
- Do the same for the other inspections: tool call (already named by its title, check it), terminal (already named by the command, check it), permission request, elicitation, plan, plan entry, compaction, error, unknown update, attachment, and the client models (session, connection, MCP server, agent and the rest). Each name comes from data of the item.
- Localize the new strings in Localizable.xcstrings.
- Update the docs (DocC and README) where they tell the block titles.

## Acceptance
- [x] Each inspection of an item gives a name that comes from the item.
- [x] A headless unit test: two items of one type (for example two agent messages) give two blocks with different names. Add this for each inspection type that can have two items.
- [x] The root `swift test` passes. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass.
- [x] Do NOT run windowed tests or the gallery. The peer tells when to regenerate the gallery.

## Review Findings (2026-11-09 14:35)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 6 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file
> - `Sources/AgentViewKit/Resources/Localizable.xcstrings` — no validator matches this file

- [x] `Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift:86` `completeness/invariant-propagation` — The connection name uses `initializeResponse?.info.name` with `??` only for nil. An agent that sends an empty name gives an empty name row. The unknown-update site handles the same case: it treats an empty type as nil so the title is used (TranscriptEntries+Inspectable.swift:304). The empty-value rule is applied at one site and not at the other. Treat an empty agent name as absent, the same way the unknown-update site does. For example, `name: { connection in connection.initializeResponse?.info.name.isEmpty == false ? connection.initializeResponse?.info.name : nil }` followed by the state summary. Add one test that gives an empty agent name and asserts the state summary is the name.