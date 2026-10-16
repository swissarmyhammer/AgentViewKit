---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m51bqt7e46pr3hpwnms89at2
  text: |-
    ## Design (task 28, AgentViewKit part)

    ### Facts that I checked
    - Package.resolved pins FoundationModelsACPClient at 7676d81 (branch main). The checkout in .build/checkouts is at 7676d81. Commit 904e541 is an ancestor of 7676d81.
    - `ClientCapabilities` (FoundationModelsACP, ACP v2, Models2.generated.swift) has 3 fields only: `auth`, `elicitation` and `meta` (`_meta`). It has no `terminal` field and no `fs` field.
    - `ACPClient.capabilities(for: .interactive)` returns `ACPClient.advertisedCapabilities`. `capabilities(for: .headless)` returns `ClientCapabilities()`.
    - `ConnectionModel.initialize(_:)` keeps `request.capabilities.elicitation` in `advertisedElicitation`. `refusedElicitationReason(for:)` uses it: no elicitation gives `noUserPresentReason`; a mode with no entry gives `unadvertisedElicitationModeReason`; the `.unknown` mode is always accepted.
    - Users of the kit value: `InitializeRequest.makeAgentViewKitRequest(info:terminalAuthRunner:)` only. Callers of that function: DemoAgent.makeInitializeRequest (terminalAuthRunner nil), ScriptedSession.open, InProcessAgentTests, the ACPQuickStart snippet and README.md. Tests: KitInitializeRequestTests (3 tests, JSON shape), and DemoAgentTests checks `capabilities.auth == nil`.

    ### (a) The fields, side by side
    | field | `ClientCapabilities.agentViewKit` today | `ACPClient.capabilities(for: .interactive)` | `capabilities(for: .headless)` |
    |---|---|---|---|
    | `elicitation.form` | `{}` | `{}` | not sent |
    | `elicitation.url` | `{}` | `{}` | not sent |
    | `auth` | nil | nil | nil |
    | `_meta` | nil | nil | nil |

    Difference: none. Today the two values are equal, field by field. The kit static value adds no field. `terminal`, `fs` and kit `_meta` do not exist in v2. The only field that the kit adds is `auth.terminal`, and `makeAgentViewKitRequest` adds it only when the host gives a `TerminalAuthRunner`. The doc of `advertisedCapabilities` tells a host with a terminal to add `auth.terminal` itself, so this addition agrees with the client.
    The problem is a risk of drift only: the kit writes its own literal of the elicitation modes. If the client adds or removes a mode, the kit literal does not change.

    ### (b) The change
    1. KitInitializeRequest.swift: set `public static let agentViewKit = ACPClient.capabilities(for: .interactive)`. Remove the literal. Keep the public name (doc links use it). Change the doc comment: the value comes from the client for a host with a UI; the kit shows each mode in a view (`ElicitationView` for form, `ElicitationURLConsentView` for URL); the value does not set `auth`.
    2. `makeAgentViewKitRequest` does not change: it starts from `agentViewKit` and adds `auth.terminal` when the host gives a runner. This is the one place for the kit-only field. No merge helper is necessary, because no other kit-only field exists.
    3. UserPresence parameter: my recommendation is no. Each kit host has a UI that shows the kit elicitation views. A host with no UI does not use the kit views. It can send `InitializeRequest(info:protocolVersion:capabilities: ACPClient.capabilities(for: .headless))` directly. A presence parameter adds public API that no kit, demo or test caller uses. Keep the kit interactive only, and write this in the doc comment.
    4. No change to README.md, the ACPQuickStart snippet or the demo: their text ("advertises only the capabilities that the kit views show") stays correct.
    5. No ARCHITECTURE.md exists. The change adds no new dependency: AgentViewKit already imports FoundationModelsACPClient in this file.

    ### (c) Tests (fixed order; no clock wait, poll, sleep or time limit), in KitInitializeRequestTests
    - T1 (unit): `ClientCapabilities.agentViewKit == ACPClient.capabilities(for: .interactive)`.
    - T2 (unit): `makeAgentViewKitRequest(info:terminalAuthRunner: nil).capabilities == ACPClient.capabilities(for: .interactive)`.
    - T3 (unit): with a `FakeTerminalAuthRunner`, the capabilities equal `capabilities(for: .interactive)` with `auth = AuthCapabilities(terminal: TerminalAuthCapabilities())`. Thus the only difference is `auth.terminal`.
    - Keep the 3 JSON shape tests. They check the wire form.
    - Optional elicitation test with the scripted agent: NOT REACHABLE. `ScriptedSession.open` always sends `makeAgentViewKitRequest`, which advertises form and URL. The client accepts `.unknown` modes. Thus no mode exists that the kit does not advertise, and the kit cannot show `unadvertisedElicitationModeReason`. The client already tests the cancel path (ElicitationUserPresenceTests: headless form and request scope, form-only client with a URL elicitation, interactive routing, new connection resets). I recommend no kit-level cancel test. A kit-level headless test is possible only with the presence parameter of (b)3.

    ### (d) Open questions
    1. Does the step owner want a `UserPresence` parameter on `makeAgentViewKitRequest` (headless kit host)? Recommendation: no.
    2. TDD: T1, T2 and T3 pass before the change, because the values are equal today. They are drift guards for a refactor with no behavior change. Is a guard test without a RED run acceptable? Alternative: show RED with a temporary edit of the kit literal (remove `url`), then make the change.
    3. Keep `ClientCapabilities.agentViewKit` as public API, or deprecate it in favor of `ACPClient.capabilities(for: .interactive)`? Recommendation: keep it (doc links in AgentAuthView, KitInitializeRequest and InProcessAgent use the kit names).
    4. Discovery: the doc of InProcessAgent links to `makeAgentViewKitRequest(info:)`, but the signature is `makeAgentViewKitRequest(info:terminalAuthRunner:)`. The DocC link can fail. Fix it in this change, or in a separate task?
    5. Order: ^q6mny1d edits the ElicitationView files. This change edits KitInitializeRequest.swift and its tests only. The two changes do not touch the same files; the dependency is an order only.
  timestamp: 2026-10-16T03:22:53.550290+00:00
- actor: claude-code
  id: 01m51br0tepht6d6rcav7wbvnq
  text: |-
    ### implement — no-change
    - evidence: design on the card (comment "Design (task 28, AgentViewKit part)"). No product or test code changed. Card stays in todo; it depends on ^q6mny1d.
    - next: the step owner answers the open questions; then implement after ^q6mny1d.
  timestamp: 2026-10-16T03:23:00.302265+00:00
- actor: claude-code
  id: 01m51bsd08fxam1ps4m6xppf0h
  text: |-
    ### Decisions from the step owner on the design
    - The design is accepted.
    - (1) No UserPresence parameter on makeAgentViewKitRequest.
    - (2) Guard tests with no RED run are accepted (the values are equal today).
    - (3) Keep ClientCapabilities.agentViewKit public.
    - (4) Fix the DocC link in the InProcessAgent doc (makeAgentViewKitRequest(info:terminalAuthRunner:)) in this change.
    - Commit this change after part A of ^q6mny1d.
  timestamp: 2026-10-16T03:23:45.544452+00:00
- actor: claude-code
  id: 01m51c994ahk8cjs9e2ffs5tkn
  text: |-
    Implementation done (as the accepted design and decisions).
    - KitInitializeRequest.swift: `ClientCapabilities.agentViewKit = ACPClient.capabilities(for: .interactive)`. The literal is removed. The doc comment tells: the value comes from the client for a host with a UI; ElicitationView shows form, ElicitationURLConsentView shows URL; the kit is interactive only (no user presence parameter; a host with no UI sends `capabilities(for: .headless)` directly); the value does not set `auth`. `makeAgentViewKitRequest(info:terminalAuthRunner:)` did not change.
    - InProcessAgent.swift: the DocC link is now `makeAgentViewKitRequest(info:terminalAuthRunner:)`. A search of the full repo found no other link with the old signature `makeAgentViewKitRequest(info:)`.
    - KitInitializeRequestTests: 3 guard tests added (T1 agentViewKit == capabilities(for: .interactive); T2 runner nil gives capabilities(for: .interactive); T3 FakeTerminalAuthRunner adds only auth = AuthCapabilities(terminal: TerminalAuthCapabilities())). The 3 JSON shape tests stay. No RED run (decision 2). The tests use `ScriptedSession.clientInfo` as the info.
    - Test run: `swift test --filter KitInitializeRequestTests`: 6 tests in 1 suite passed, exit 0. One build-system warning only: "missing creator for mutated node" for the mlx-swift_Cmlx.bundle. This warning is not from the changed files.
    - The uncommitted part A of ^q6mny1d (Elicitation files) is not touched. No git command was run.
  timestamp: 2026-10-16T03:32:25.866904+00:00
- actor: claude-code
  id: 01m51c9bag17mxt0vg9bgq1ggm
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKit/ACP/KitInitializeRequest.swift, Sources/AgentViewKit/ACP/InProcessAgent.swift, Tests/AgentViewKitTests/ACP/KitInitializeRequestTests.swift; `swift test --filter KitInitializeRequestTests`: 6 passed, 0 failed.
    - next: /test, then /review. Commit after part A of ^q6mny1d.
  timestamp: 2026-10-16T03:32:28.112938+00:00
- actor: claude-code
  id: 01m51vbwxr2q0taa8pk1w2n9cj
  text: |-
    ### review — clean
    - evidence: review sha b998f83~1..b998f83 — 0 findings (0 confirmed, 0 refuted, 7 attempted, 0 failed). The engine reviewed 3 files. An ignore rule (.reviewignore) excluded 2 files in .kanban/.
    - next: None. The task is in done.
  timestamp: 2026-10-16T07:56:00.312800+00:00
- actor: claude-code
  id: 01m51vcc82fxhcamazzafd43py
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 3 files (KitInitializeRequest.swift, InProcessAgent.swift, KitInitializeRequestTests.swift)
    - test: green — swift test, 1350 passed, 0 failed, 0 skipped (one full run shared with ^q6mny1d, ^qx7c4q3 and ^fzn2beh); check-readme passed
    - commit: b998f83
    - review: clean — 0 findings; card moved to done
  timestamp: 2026-10-16T07:56:16.002540+00:00
depends_on:
- 01M50NQYCATQ3K3VYGNQ6MNY1D
position_column: done
position_ordinal: ffcd80
title: 'Elicitation task 28 (AgentViewKit part): make ClientCapabilities.agentViewKit come from ACPClient.capabilities(for: .interactive)'
---
elicitation-plan.md task 28. ACPClient 904e541 made the elicitation capability an explicit client setting: `ACPClient.UserPresence` and `capabilities(for:)`. An elicitation of a mode that the client did not advertise now gets cancel at once, with the reason in `_meta`.

Left in AgentViewKit: `ClientCapabilities.agentViewKit` (KitInitializeRequest.swift) is a second advertiser. Make it come from `ACPClient.capabilities(for: .interactive)`, so that the two cannot drift. Keep the fields that only AgentViewKit adds, if any, on top of that value.

Work:
1. A short design first (on this card, and in the report to the step owner): what the kit value has today, what capabilities(for: .interactive) gives, and the fields that only the kit adds.
2. The change, with a fixed-order test: the kit value equals capabilities(for: .interactive) plus the kit fields; an elicitation of a mode that the kit does not advertise gets cancel at once (if a kit-level test can show it with the scripted agent).
Same test rules as mail step 7 (no clock wait, poll, sleep or time limit; event waits; a hosted wait must be for a certain event). Write all text in STE. #elicitation-phase-2