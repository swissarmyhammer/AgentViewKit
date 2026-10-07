---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4aa3v1vpk9kwdgrmyahdzr2
  text: |-
    Research:
    - At pin be7e615, `ACPClient.advertisedCapabilities` is `ClientCapabilities(elicitation: ElicitationCapabilities(form: ElicitationFormCapabilities(), url: ElicitationUrlCapabilities()))`, and `ACPClient.supportedProtocolVersion` is `.v2`. The kit value has the same contents, but the kit states it from its own views.
    - `ClientCapabilities.encode` omits a nil field. Thus no `auth` key goes on the wire when `auth` is nil.
    - The README snippets come from `README.md` through `Scripts/extract-readme-snippets.sh`. Thus the change goes into `README.md`, and the script writes `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift`.
    - Name decision: the review rule "factory methods begin with make" applies. The factory is `InitializeRequest.makeAgentViewKitRequest(info:)` and not `InitializeRequest.agentViewKit(info:)`.
    - The test compares the demo request with the factory. For this, `ACPDemoSession` gets a named `clientInfo` constant, and `ScriptedSession` gets a named `clientInfo` constant.
  timestamp: 2026-10-07T04:31:58.523121+00:00
- actor: claude-code
  id: 01m4aakfg2bysh0ps5wxm719h7
  text: |-
    Implementation landed.
    - RED: `KitInitializeRequestTests.theInitializeFrameOfTheTestHelperAdvertisesOnlyTheKitCapabilities` failed at `capabilities["elicitation"]`, because `ScriptedSession.open` sent no capabilities. The demo test passed at once, because `ACPClient.advertisedCapabilities` has the same contents as `ClientCapabilities.agentViewKit`. It guards that the demo uses the kit factory.
    - GREEN: `ScriptedSession.open`, `ACPDemoSession.initializeRequest` and the README `ACPQuickStart` snippet call `InitializeRequest.makeAgentViewKitRequest(info:)`.
    - Not changed: `Tests/AgentViewKitTests/ACP/ProtocolVersionTests.swift` has its own private `initializeRequest(version:)` helper with no capabilities. The test changes the protocol version, and the card scope is `Sources/` and `Examples/`.
    - Gates: `swift test` passed (1387 tests in 127 suites, 78 tests in 12 suites, 1 test in 1 suite; no new warning). `Scripts/check-readme.sh` passed. `Scripts/test-examples.sh AgentViewKitDemo` passed (TEST SUCCEEDED, 2 tests). The known unstable tests ^zcktrsh and ^vhp5fv7 did not fail. The examples log has two `appintentsmetadataprocessor` warnings ("Metadata extraction skipped, no AppIntents.framework dependency found") from the Xcode build tool, not from the code of this change.
  timestamp: 2026-10-07T04:40:30.978379+00:00
- actor: claude-code
  id: 01m4aakhq72c0n2ekvkztz3s0r
  text: |-
    ### implement — changed
    - evidence: 6 files — Sources/AgentViewKit/ACP/KitInitializeRequest.swift (new), Sources/DemoSupport/ACPDemoSession.swift, Sources/AgentViewKitTestSupport/ScriptedSession.swift, README.md, Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift (generated), Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift (new). Commands: swift test --filter KitInitializeRequestTests (red, then green); swift test (green); Scripts/extract-readme-snippets.sh; Scripts/check-readme.sh (pass); Scripts/test-examples.sh AgentViewKitDemo (pass).
    - next: /review
  timestamp: 2026-10-07T04:40:33.255264+00:00
- actor: claude-code
  id: 01m4ab3cqctjh69nq3fpretpye
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (commit 59b8152) — 1 finding (1 confirmed, 0 refuted): Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift:30 `test-integrity/no-test-cheating`
    - next: /implement — fix the finding in the dated `## Review Findings (2026-10-06 23:44)` section
  timestamp: 2026-10-07T04:49:12.428338+00:00
- actor: claude-code
  id: 01m4ab3ea5nrasd45nfja9ec2h
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ClientCapabilities.agentViewKit and InitializeRequest.makeAgentViewKitRequest(info:) (new); the demo, the README snippet and ScriptedSession use it; KitInitializeRequestTests (new)
    - test: green — swift test, 1387 passed; README and demo UI gates passed
    - commit: 59b8152
    - review: findings — Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift:30
  timestamp: 2026-10-07T04:49:14.053944+00:00
- actor: claude-code
  id: 01m4achn77btpnbtpgsbwzv7qm
  text: |-
    ### implement — changed
    - evidence: KitInitializeRequestTests.swift: the demo test checks the real properties of the demo request (info name and version as named constants, protocolVersion, elicitation form and url, no auth) through one shared helper, expectOnlyKitCapabilities(in:sourceLocation:); swift test --filter KitInitializeRequestTests passed; full swift test after rm -rf .build passed (1387 tests in 127 suites)
    - next: review
  timestamp: 2026-10-07T05:14:28.455923+00:00
- actor: claude-code
  id: 01m4acn8gzdcyzyvw4yw0md51q
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (commit 6ada59b) — 0 findings (0 confirmed, 0 refuted; 7 validator runs attempted, 0 failed). All prior review items are checked. The task moved to done.
    - next: none
  timestamp: 2026-10-07T05:16:26.527381+00:00
- actor: claude-code
  id: 01m4acn9jjgbb2kpst497701p1
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — the demo test checks the real request properties through expectOnlyKitCapabilities
    - test: green — swift test after a clean build, 1387 passed
    - commit: 6ada59b
    - review: clean — 0 findings
  timestamp: 2026-10-07T05:16:27.602402+00:00
position_column: done
position_ordinal: ff8180
title: The host InitializeRequest gives only the capabilities that the kit supports
---
## What
Rule: the agent streams to FoundationModelsACPClient over ACP. The client keeps an observable state. The kit views bind directly to that state and keep no state or logic of their own.

ACP v2 tells a client to advertise only the capabilities that it supports. At this time each host makes its own `InitializeRequest`:
- `Sources/DemoSupport/ACPDemoSession.swift:110` (`initializeRequest`) sends `ACPClient.advertisedCapabilities`.
- `Examples/ReadmeSnippets/Snippets/ACPQuickStart.swift:21` sends `ACPClient.advertisedCapabilities`.
- `Sources/AgentViewKitTestSupport/ScriptedSession.swift:134` sends no capabilities.
- The in-process helper does not exist yet. Task ^96pte46 adds it. That helper must use the request of this task.

`ACPClient.advertisedCapabilities` tells what the client models can do. It does not tell what the kit shows. The kit shows the form mode in `ElicitationView` and the URL mode in `ElicitationURLConsentView`. The kit has no terminal runner yet, so it must not send `auth.terminal`.

Name note: the review rule "factory methods begin with make" applies. The factory that this card first called `InitializeRequest.agentViewKit(info:)` is `InitializeRequest.makeAgentViewKitRequest(info:)`.

Subtasks:
- [x] Add `Sources/AgentViewKit/ACP/KitInitializeRequest.swift`. Add `ClientCapabilities.agentViewKit` and `InitializeRequest.makeAgentViewKitRequest(info:)`. The request sets `info`, `protocolVersion: ACPClient.supportedProtocolVersion` and `capabilities: .agentViewKit`.
- [x] In `ClientCapabilities.agentViewKit`, set `elicitation.form` because `ElicitationView` shows the form mode. Set `elicitation.url` because `ElicitationURLConsentView` shows the URL mode. In the doc comment, write the view that each value needs.
- [x] Do not set `auth`. Task ^83200vg and its host task add `auth.terminal` with the terminal runner.
- [x] Use `InitializeRequest.makeAgentViewKitRequest(info:)` in `ACPDemoSession.initializeRequest`, in `ACPQuickStart.swift` (through `README.md`) and in `ScriptedSession.open`. Run `Scripts/extract-readme-snippets.sh`.

Size: 4 source files: `KitInitializeRequest.swift` (new), `ACPDemoSession.swift`, `ACPQuickStart.swift`, `ScriptedSession.swift`.

## Acceptance Criteria
- [x] No file in `Sources/` or `Examples/` uses `ACPClient.advertisedCapabilities`.
- [x] The demo, the README snippet and the test helper make their `InitializeRequest` with `InitializeRequest.makeAgentViewKitRequest(info:)`.
- [x] The `initialize` frame on the wire has `params.info`, `params.capabilities.elicitation.form` and `params.capabilities.elicitation.url`. It has no `params.capabilities.auth`.

## Tests
- [x] Add `Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift`:
  - Open a `ScriptedSession`. Read the frame with `agent.messages(method: "initialize")`. Check `params.info.name`, `params.capabilities.elicitation.form == {}` and `params.capabilities.elicitation.url == {}`. Check that `params.capabilities.auth` is absent.
  - Check that `ACPDemoSession.initializeRequest` is equal to `InitializeRequest.makeAgentViewKitRequest(info:)` with the `info` of the demo.
- [x] Command: `swift test --filter KitInitializeRequestTests`. Then `swift test` and `Scripts/check-readme.sh` pass.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-10-06 23:44)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift:30` `test-integrity/no-test-cheating` — Trivial assertion that cannot fail: the test compares `ACPDemoSession.initializeRequest` with `InitializeRequest.makeAgentViewKitRequest(info: ACPDemoSession.clientInfo)`, but the property is literally defined as that exact factory call, so the assertion is x == x and proves nothing. Change the test to verify that the factory method produces the correct InitializeRequest structure by asserting on actual properties (protocol version, capabilities structure, etc.) rather than comparing the property to what it's defined to be.
