---
assignees:
- claude-code
depends_on:
- 01M5DF7Y8PDWS7XF25WDBBYG9W
- 01M5DF9SKZ4BRGBD6BFG5XY664
- 01M5DFA593MWNN971T9F2GCJ20
- 01M5DFADQHSHCRAQW0709TVAPV
position_column: todo
position_ordinal: '9780'
title: AVK-8p Test each glass view with Reduce Transparency, Increase Contrast and the Tinted look
---
## Why

D110 (f) and AVK-8: each custom glass view is tested with Reduce Transparency, Increase Contrast and the Tinted look. AVK-8a decides the method for each setting. This card writes the tests.

## Glass views to test

- The composer field with `agentFloatingGlass()` (`Input/PromptInputView.swift`).
- The accessory cluster: Send, Stop, dictation (`Input/DefaultPromptAccessory.swift`, `Input/SpeechInputButton.swift`).
- The suggestion chips (`Input/SuggestionsView.swift`).
- The completion list and the no-commands note (`Input/EditorKitPromptEditor.swift`, after AVK-8k).
- The scroll-to-bottom pill (`Thread/ScrollToBottomPill.swift`, in the container of AVK-8l).

## What to do

- [ ] Add `Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift`. Use one parameterized `@Test` with the arguments (view, setting).
- [ ] Apply each setting with the method of AVK-8a, for example `.environment(\._accessibilityReduceTransparency, true)` and `.environment(\._colorSchemeContrast, .increased)`, and the Tinted method that AVK-8a records.
- [ ] For each pair, check the assertion that AVK-8a records. Examples: the setting reaches the view; the primary label keeps a vibrant style; with Reduce Transparency, no pixel of a unique backdrop color shows inside the glass shape.
- [ ] Add a test helper in `Sources/AgentViewKitTestSupport/` if two or more tests need the same setup.

## Acceptance

- Each glass view above has one test for each of the three settings: 5 views x 3 settings = 15 cases, or the count that AVK-8a records with a reason.
- All cases pass. A run of the suite two times gives the same result.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. Each wait waits for a certain event. #avk-8