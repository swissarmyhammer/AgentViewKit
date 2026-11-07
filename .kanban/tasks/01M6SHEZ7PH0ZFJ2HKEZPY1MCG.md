---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6sk7x83j0r59gtev112d2ps
  text: |-
    Investigation (headless only, no XCUI run):

    - Window narrowed with CI logs: last green run 41937203012 = AVK 4909e9fc + EK main 4ed48835. First red run 42099514028 = AVK 1e54f712 + EK b43bc4ac, failing the same way. Same runner OS (27.2 26B123) and Xcode 27.2.
    - The card's EK suspects 1fe50719, 857ce5eb/ab2ddebf, 90a7528d, 06f0697f/931c93b6 all landed on Nov 6, AFTER the first red run (EK b43bc4ac, Nov 5 14:13 -0600). They cannot be the cause. The latest red run (42301616044) used EK 2046f955, which already has all of them.
    - Range to search: EK 4ed48835..b43bc4ac (includes f68bfd13 scrollbar strips beside the text, a4794850 multiline fields fit content, 471a0d5a AX parity, 8c61dfd7 leaf landing) and AVK 4909e9fc..1e54f712 (includes 47b24b1a: the prompt editor is content-sized and PromptInputView bounds it with EK .boundedHeight, which puts the text view in a scroll area).
    - The xcresult of run 42301616044 has only a screen recording. The composer is visible, nothing covers it, the editor is not focused (no caret), and the sign-in card is above it. The layout stays the same from about t=3s to t=5s.
    - In XCUI, the isHittable step ("Find the prompt-editor") takes 1.8 s in red runs and 0.11 s in the green run. So XCUI ran a long hit-point search, not one quick miss.
    - Hosted repro attempt: IntegrationTests/.../ACP/ACPComposerHitTestHostedTests.swift (ACPWindowReplica + in-memory DemoAgent, editor AX-frame centre -> window.accessibilityHitTest, answer must be the editor or under it). It PASSES on EK 2046f955. These variants also pass: with and without .commandSystem + .editorTheme(.system); window heights 900/700/600; narrow->wide; short->tall; a 10x10 or zero-width first layout; thread swapped in after a ProgressView; window moved; editor centre clipped by every AX ancestor frame (XCUI visible frame). Every ancestor frame contains the editor (AXTextArea 764x16 in an AXScrollArea 764x36, in prompt-field-surface, in thread-floating-controls).
    - Not reproducible headless: the remote hit test goes through the window server and NSApp to find the window under the point. The headless harness window is never ordered in (isVisible false), so a window-level difference (another app or panel window over the point, or key/visible-only state) cannot show in-process. Stopped per instructions; no bisect possible without a repro.
  timestamp: 2026-11-06T23:31:29.155802+00:00
- actor: claude-code
  id: 01m6sk802b8w2h6aq8acbyx5hk
  text: |-
    ### implement — stuck
    - evidence: 1 file — IntegrationTests/Tests/IntegrationTests/ACP/ACPComposerHitTestHostedTests.swift (commit ff241007 on worktree-agent-a3a8f52d44a209bfb); `swift test --filter ACPComposerHitTestHostedTests` 1 passed — does NOT reproduce
    - next: user decides how to reproduce (needs a visible window / XCUI-level read) or bisects the narrowed range EK 4ed48835..b43bc4ac × AVK 4909e9fc..1e54f712 in CI
  timestamp: 2026-11-06T23:31:32.043303+00:00
- actor: claude-code
  id: 01m6txdtrd16wnsf3pye67x550
  text: |-
    ### cause found — EK .boundedHeight
    - Headless repro failed: in-process accessibilityHitTest answers the editor (harness window is never on screen). The test (ff241007) was dropped.
    - First red CI is Nov 5 (run 42099514028, AVK 1e54f712, EK b43bc4ac), before EK's suspect cards, so those are ruled out.
    - CI probe (user-approved branch ci-probe/composer-bound, since deleted; run 42368775324): current main with only `.boundedHeight(editorHeightBound)` removed from PromptInputView.swift:252, with the editor's own 200 pt max frame restored. The Examples (AgentViewKitDemo) leg passed.
    - Cause: EditorStyle `.boundedHeight` (EK Sources/EditorStyle/BoundedHeight.swift) wraps the editor in a SwiftUI ScrollView whose height starts at contentHeight 0. A real window-server AX hit test (XCUI isHittable) then can't find the editor. AVK adopted the wrapper in 47b24b1a (^sy19jd4, Nov 5).
    - Sent to editorkit-b5 with the mechanism; waiting on their fix SHA. No AVK workaround.
    - next: when EK's fix lands, run AVK CI on it; once Examples is green, tick the subtasks and review.
  timestamp: 2026-11-07T11:48:43.405130+00:00
- actor: claude-code
  id: 01m6v16zqpm70vwpawsbgxhwf6
  text: |-
    ### done — fixed in EditorKit
    - evidence: AVK CI run 42372831389 (main 9c5128d1, EK main a0f6d417): Build & test ✅, Integration ✅, Examples (AgentViewKitDemo) ✅
    - AVK made no code change; it keeps `.boundedHeight`. EK a0f6d417 makes AccessibilityHitTestCorrection enter a scroll area that sits in a layer over the answer, and pins the case in the UI tests of its Composer example.
    - Closed without an AVK review because there is no AVK code delta to review.
  timestamp: 2026-11-07T12:54:53.430951+00:00
position_column: done
position_ordinal: ffffffc580
title: Demo composer editor is not hittable (CI red since Nov 4)
---
CI's Examples (AgentViewKitDemo) leg fails on every run since Nov 4 (last green AVK 4909e9fc): `ACPTabEndToEndTests.testASendOfHelloShowsTheReplyOfTheAgent` at Examples/AgentViewKitDemo/Tests/ACPTabEndToEndTests.swift:92 — `XCTAssertTrue failed - The composer editor is not hittable.` The session shows and the `prompt-editor` element exists, but XCUI's isHittable (an AX hit test at the element's centre) answers another element. Latest run: https://github.com/swissarmyhammer/AgentViewKit/actions/runs/42292592822

EK's suspects (editorkit-b5), most likely first: 1fe50719 ^bavw691 (.floatingGlass()/FloatingGlassContainer content gets .contentShape(.accessibility, shape) — the composer sits in floating glass), 857ce5eb+ab2ddebf ^zg9xtj7 (same on GlassBackground/CapsuleGlass), 90a7528d ^q48kgc3 (leaf-control AX hit search order), 06f0697f/931c93b6 ^7v6rvdx (ScopeFocusRing is a view-sized Canvas). AVK changes since 4909e9fc are suspects too.

User decision: find it headless — no XCUI run, no focus stealing.

- [x] Reproduce it: a headless in-process hit test does NOT reproduce it (the harness window is never on screen), so the user approved a CI probe instead; EK now pins the case with an out-of-process hit test in its Composer example's UI tests
- [x] Find the cause (AVK or EK; bisect EK pins if needed): EK's AccessibilityHitTestCorrection stopped its descent at the first scroll area, and `.boundedHeight` (adopted by AVK 47b24b1a) put one around the composer editor
- [x] Fix in AVK, or send EK the first bad SHA + the repro and take their fix: EK a0f6d417, no AVK change
- [x] CI's Examples leg green: run 42372831389 on AVK 9c5128d1 + EK a0f6d417, all three jobs green