---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7v3xcgep2014e2c7wq5rzfx
  text: 'Decision by testudoapp-9a (2026-11-19): yes. In the unavailable state, Next Prompt, Previous Prompt, Scroll to Bottom and Expand or Collapse All are not available, with the reason "The session is not available.". The session verbs (Go to Parent Session and the others that act on the session tree) stay available. Not blocked now.'
  timestamp: 2026-11-19T23:57:46.382531+00:00
- actor: claude-code
  id: 01m7v477223bqza3yzsha7q338
  text: |-
    ### implement — changed
    - One rule: the group property `AgentCommandGroup.readsSessionText` is replaced by the verb property `AgentCommandVerb.needsTranscript`, because the gate now cuts through the group `navigate`. `AgentCommandTarget.unavailableSessionReason(of:)` reads it. No other code (also no other repo) used the old name.
    - Gated (acts on the list): Next Prompt (`jumpToNext`), Previous Prompt (`jumpToPrevious`), Scroll to Bottom, Expand or Collapse All. "Jump to Next" and "Jump to Previous" are the same verbs as Next Prompt and Previous Prompt.
    - Not gated: Next Request and Previous Request act on the request deck, not on the list. Go to Parent Session, Open Child Session, Next Sibling Session, Previous Sibling Session and Jump to Session act on the session tree.
    - Tests in `ThreadUnavailableTests`: each list verb has the reason in the unavailable state (RED seen: 4 failures), each list verb is `.available` otherwise, Go to Parent Session and Open Child Session stay `.available` in the unavailable state.
    - Docs: ARCHITECTURE.md "Read-only thread", the doc comments of `AgentCommandGroup`, `AgentCommandTarget` and `ThreadUnavailable.swift`.
    - evidence: `swift test`: "Test run with 1550 tests in 177 suites passed" and "Test run with 54 tests in 11 suites passed". IntegrationTests `swift build --build-tests`: Build complete. Lint errors (new/HEAD): AgentCommandGroup.swift 1/1, AgentCommandTarget.swift 11/11, ThreadUnavailable.swift 0/0, ThreadUnavailableTests.swift 0/0.
    - next: review.
  timestamp: 2026-11-20T00:03:08.482256+00:00
position_column: doing
position_ordinal: '80'
title: Navigation verbs of a thread in the unavailable state (D208 i)
---
Found during ^rnrfc8w. While a thread shows the unavailable message of the host (`threadUnavailable(_:)`), no list shows. The verbs of the group `navigate` that act on the list stay available: Next Prompt, Previous Prompt, Scroll to Bottom and Expand or Collapse All. They run on a list that does not show, so the user sees no result.

Decide with the host (testudoapp-9a) if these verbs also get the reason "The session is not available." in the unavailable state. If yes: add them to the gate in `AgentCommandTarget.unavailableSessionReason(of:)`, add a unit test for each verb, and update ARCHITECTURE.md "Read-only thread". The session verbs (Go to Parent Session and the others) act on the session tree, not on the list.