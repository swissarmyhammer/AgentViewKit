---
assignees:
- claude-code
position_column: todo
position_ordinal: a180
title: 'Demo UI test: XCUI finds no hit point for the composer editor (testASendOfHelloShowsTheReplyOfTheAgent)'
---
Found by the test step of ^32a58sq (2026-10-22). The test fails at HEAD without that card's change too.

`Scripts/test-examples.sh` fails `Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift` `testASendOfHelloShowsTheReplyOfTheAgent` with "Unable to find hit point for ScrollView" on the composer editor. The other three tests in that class and the Gallery test pass.

What the tester saw:
- XCUI reports the editor as disabled. Still, a coordinate click and then `app.typeText("hello")` puts "hello" in it and enables Send. So the app takes input, but the accessibility state or the hit point of the editor is wrong.
- A rough bisect, one run per commit, points to `471e0ac` (header and banners moved into `.safeAreaBar(edge: .top)`). This evidence is weak: the machine was under heavy load (load average about 9, and another project's UI tests ran), and some runs flipped between pass and fail on the same sources.
- The composer now sits in `.safeAreaBar(edge: .bottom)` in `Sources/AgentViewKit/Thread/AgentThreadView.swift`. ^ph0m0hf works on the same bars, so check this test when you work on that card.

Fix the cause in the kit, so that the editor reports itself as enabled and hittable. Do not weaken the UI test with a coordinate click.

Acceptance:
- `Scripts/test-examples.sh` passes, with `testASendOfHelloShowsTheReplyOfTheAgent` green on 3 runs in a row.
- If the cause is in the kit's accessibility, a hosted or headless test checks the editor's accessibility enabled state.
- `swift test` is green. #bug #avk-8