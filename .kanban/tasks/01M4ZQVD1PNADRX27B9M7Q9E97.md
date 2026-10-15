---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m4zyg8n0fjsnps585aj8jzm5
  text: |-
    ### Decisions from the step owner (after T0)
    - ExampleGateTimeLimitTests.swift:53: remove the .timeLimit trait. If the subject of the test is the value of the CI example time limit, check that value as data, with no trait.
    - Replace the 3 Task.sleep, the 39 waitUntil polls, the 327 pump(until: waitTimeout) and the 273 harness.pump() calls with waits on events (withObservationTracking on the models, gates, fixed orders). Do it in several commits by area, each with one full run.
    - If a wait has no event (for example a SwiftUI or AppKit render that the test must let happen), report that kind of wait with an example to the step owner BEFORE you change it. Do not invent a time bound.
    - The 9 XCUITest waitFor…Existence(timeout:) calls can stay (XCUITest drives the app in another process). Add no new ones.
  timestamp: 2026-10-15T14:12:20.256310+00:00
depends_on:
- 01M4ZQV6P05Y91E6AAAPVJE3W3
position_column: todo
position_ordinal: '8480'
title: 'Mail step 7 T4: Remove time limits and clock waits from the tests, align the docs, run the full suite, push, and report'
---
1. Remove the .timeLimit trait and each sleep, clock wait and poll in the tests. Use a wait on an event, a gate or a fixed order. A clock may only measure and print time.
2. Make the docs and comments agree with the new ACPAgent behavior (no turn words; state changes with no prompt open; an idle with no stop reason; more than one open prompt; cancel while idle with pending requests; the announcement only for the idle that ends a user prompt).
3. One full test run. Run the examples check if the CI runs it.
4. The final commit and the push. Report the head and the CI result.
5. Final report: the list of commits, and the check of mailbox.md row 7: "AgentViewKit builds and passes its tests against the mains that steps 1 to 6 checked, and elicitation-plan tasks 47 and 48 are done."

If a test hangs, take a `sample <pid>` of the test process first, then stop only that process id (never pkill or a pattern kill). Delete no test without a decision. Write all text in STE. #mail-step-7