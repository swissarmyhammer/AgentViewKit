---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m52h6b3snyfpz4yv29m3c2f9
  text: 'Note from the step owner: ACPClient 6e2332b is CI green (run 38912283139). The first to-do item ("make sure that its CI is green") is true for 6e2332b. This card can use 6e2332b when its turn comes.'
  timestamp: 2026-10-16T14:17:26.905397+00:00
- actor: claude-code
  id: 01m534jypteeyyrtpj5t6849dy
  text: |-
    ### Design sent to the step owner (no code before the answer)
    - Design file: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/card39-design.md
    - Fact: AgentViewKit resolves ACPClient at e44c617, which is before 6e2332b. The design moves it to fdd66eb (and FoundationModelsACP to 47f65c0 or later).
    - Open questions Q1 to Q7 are in section 6 of the file. The withdrawn notice is proposed as a new card 39a.
  timestamp: 2026-10-16T19:56:23.130031+00:00
- actor: claude-code
  id: 01m534kttzxfyz4e92p5jw1c1j
  text: |-
    ### Accepted design (step owner)
    Design file: /private/tmp/claude-501/-Users-wballard-github-swissarmyhammer-AgentViewKit/43998bc3-6f4e-4bb7-909b-93c5172edb4f/scratchpad/card39-design.md (sections 1, 2, 4, 5A, 5B, 5D are card 39; section 3 and 5C are card 39a).
    Decisions:
    - Step 1: move the dependency to ACPClient fdd66eb, and FoundationModelsACP 47f65c0 or later. Then one full test run and Scripts/check-readme.sh, before the UI work. Keep ScriptedSession.sendInOrder; change only its doc comment (the model now keeps wire order).
    - Q1 yes: environment value elicitationRootAgentLabel, default the localized "root".
    - Q2 yes: with 4 or more names, show the root, "…", and the last two names. The accessibility label keeps the full path.
    - Q3 no: "Action required: <title>" does not change.
    - Q4: no headline change. Yes: localize ElicitationHeader.title(server:) in this card.
    - Q5 yes: the withdrawn notice is the new card 39a.
    - Q6 yes: card 39a changes Docs/decisions/accessibility.md:52 and :84.
    - Q7 no: ElicitationURLConsentView and elicitationHeaderOverride go to a separate card for later.
    Summary of card 39: the who-asks line in ElicitationHeader between the headline and the message (form, URL and waiting cards), text "root › planner › reviewer · runCode", no line when agentPath is empty and source is nil, callout, secondary, lineLimit 1, middle truncation, theme only, selectable; one accessibility element "Asked by root, planner, reviewer, from runCode" with identifier elicitation-who-asks; no line on permission cards. Public API: EnvironmentValues.elicitationRootAgentLabel, ElicitationView.whoAsksIdentifier, ElicitationHeader.whoAsks(agentPath:source:rootLabel:), ElicitationHeader.whoAsksAccessibilityLabel(agentPath:source:rootLabel:). Docs: ElicitationHeader, RequestDeck, README.md:449.
    Order: 39, then 39a, then D-1 (^t8fwhx2).
  timestamp: 2026-10-16T19:56:51.935058+00:00
- actor: claude-code
  id: 01m5350t6b8zdtfwnqzz4cctsn
  text: |-
    ### Step 1 (dependency) done
    - `swift package update FoundationModelsACPClient FoundationModelsACP`: ACPClient e44c617 -> fdd66eb. FoundationModelsACP fb55b2f -> d419cd3 (later than 47f65c0). No other pin changed.
    - Fact: Package.resolved is in .gitignore, so `git diff Package.resolved` shows nothing. I compared it with a copy from before the update. Only the two revision lines changed.
    - Build: no compile error and no compile warning. The full `swift test --skip-build` had 1 failure: ResolvedPinsTests.theGeneratedDemoProjectPinsTheRootACPRevisions. Cause: the generated demo project (git-ignored) had a copy of the old Package.resolved. Fix: `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` made the project again with the new pins. No tracked file changed. ResolvedPinsTests then passed (2 tests). The other results: 1266 tests in 147 suites passed (2 known issues), 126 of 127 tests in 16 suites passed before the fix.
    - Scripts/check-readme.sh passed.
  timestamp: 2026-10-16T20:03:57.259599+00:00
- actor: claude-code
  id: 01m5356zy6z2rdde8rk7dfc8f1
  text: |-
    ### Research for step 2
    - ACPClient fdd66eb: `PendingElicitation.agentPath` and `.source` read `request.meta` (the `_meta` of the `elicitation/create` params), keys "agentPath" and "source". A path that is not an array of strings gives []. An empty source gives nil. Thus the scripted agent can send them in the params JSON with no new helper.
    - ModelClient keeps the wire order with the wire arrival number. I changed only the doc comment of `ScriptedSession.sendInOrder(_:to:)` (Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift).
    - `ElicitationHeader` is in Sources/AgentViewKit/Elicitation/ElicitationView.swift. `ElicitationURLConsentView` uses it directly, so the line shows also on URL cards and waiting cards.
    - `HostedViewHarness.press(identifier:)` makes a render pass after the press.
    - README: the RequestDeck line is in the component list ("Human in the loop").
  timestamp: 2026-10-16T20:07:19.750374+00:00
- actor: claude-code
  id: 01m535qwekyttmdtb1pr8489kc
  text: |-
    ### implement — changed
    - evidence: files changed: Sources/AgentViewKit/Elicitation/ElicitationWhoAsks.swift (new: ElicitationView.whoAsksIdentifier, ElicitationHeader.whoAsks(agentPath:source:rootLabel:), ElicitationHeader.whoAsksAccessibilityLabel(agentPath:source:rootLabel:), the internal ElicitationWhoAsksLine view, EnvironmentValues.elicitationRootAgentLabel with the default String(localized: "root")); Sources/AgentViewKit/Elicitation/ElicitationView.swift (the line between the headline and the message, title(server:) localized, ElicitationHeader doc, elicitationHeader(_:) doc); Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift (doc); README.md (RequestDeck line); Tests/AgentViewKitTests/Helpers/ScriptedSessionRequests.swift (doc of sendInOrder(_:to:) only); Tests/AgentViewKitTests/Elicitation/ElicitationWhoAsksTests.swift (new, section 5A, 8 table rows for each function); Tests/AgentViewKitTests/HumanInTheLoop/ElicitationWhoAsksHostedTests.swift (new, section 5B, 6 hosted tests).
    - Package.resolved (git-ignored): ACPClient fdd66eb, FoundationModelsACP d419cd3. No other pin changed. The generated demo project was made again with its generator, so ResolvedPinsTests passes.
    - RED: the new tests failed with 21 issues before the code (the no-line tests and the title test passed, as expected). GREEN: `swift test --skip-build --filter ElicitationWhoAsks` 11 tests in 2 suites passed.
    - Full gate: `swift build --build-tests` no compile error or warning (the only line is the SwiftPM note "missing creator for mutated node" of the mlx-swift_Cmlx bundle, which was there before this card). `swift test --skip-build`: 1277 tests in 149 suites passed with 2 known issues (the same 2 as before), 127 tests in 16 suites passed, 1 test in 1 suite passed. `Scripts/check-readme.sh` passed.
    - Not done here (card 39a, ^f82081q): design section 3 and 5C.
    - next: /review
  timestamp: 2026-10-16T20:16:33.235437+00:00
- actor: claude-code
  id: 01m535rwpafvkkxcczjt28es1w
  text: |-
    ### test — green
    - evidence: the implement step ran the full suite one time after all changes: swift test --skip-build, 1277 tests in 149 suites passed, 2 known issues (the same 2 as before); 127 tests in 16 suites and 1 test in 1 suite passed; Scripts/check-readme.sh passed. No warning in Sources/ or Tests/. It was not run again (no repeat runs).
    - note: Package.resolved is git-ignored. The local pins are now ACPClient fdd66eb and FoundationModelsACP d419cd3; CI resolves branch main of both. The git-ignored demo Xcode project was made again with Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb, so that ResolvedPinsTests passes.
    - next: commit, review, push.
  timestamp: 2026-10-16T20:17:06.250569+00:00
depends_on:
- 01M51BCMH8VHWE68GXDERGVEFT
position_column: doing
position_ordinal: '80'
title: 'Elicitation task 39: show who asks on each deck card'
---
elicitation-plan.md task 39 (who asks). Before this card, the design card ^aqqthfk said that task 39 waits for phase 4. Write all text in STE.

## Data (ACPClient main 6e2332b, from the step owner)
- `PendingElicitation.agentPath: [String]`. It is empty when the agent sends no path. The agent adds no root, so the deck adds its own root label, for example "root › reviewer".
- `PendingElicitation.source: String?`: "runCode", or an MCP server name. MCP names come later from Multitool.
- New: `SessionModel.withdrawnRequests` and `ConnectionModel.withdrawnRequests: [WithdrawnRequest]` (id, request, reason), and `dismissWithdrawn(_:)`, for a request that the agent withdrew.
- The pending lists are now in wire order. The hosted deck tests can keep their one-by-one sends.

## To do
- [x] Update the ACPClient dependency to 6e2332b or later. First make sure that its CI is green.
- [x] Write the design for the "who asks" line on each card (agent path with the root label of the deck, and the source), and send it to the step owner before any code.
- [x] Decide whether the deck shows a short notice for a withdrawn request, or whether a new card does it. Tell the step owner.
- [x] Tests with the step 7 rules: fixed order; no clock wait, sleep, poll, retry or timeLimit; render() and event waits.

Do this card after cards 38, 40 and 41.

#elicitation-phase-6