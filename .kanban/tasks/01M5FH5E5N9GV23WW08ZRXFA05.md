---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5fmnvfdaf15pz80wrp40rqq
  text: |-
    Research (implement step):
    - `RenderedPixels` keeps its bytes private. A PNG write, a PNG read and a diff need module access, so a new file in AgentViewKitTestSupport extends the type, and the stored values become internal.
    - `RenderedPixels(cachingDisplayOf:)` uses the scale of the window. An off-screen window takes the scale of the main screen (probe11: 300 points gave 600 pixels on this Retina screen). For a fixed 2x on each computer, the snapshot makes its own bitmap of 2 pixels for each point.
    - `ImageRenderer` draws nothing for a view with `accessibilityFocused` (each request card) and for an AppKit view (the EditorKit editor). The cache of the window shows no glass. Thus each glass part gets a Path B image, and the full view gets a Path A image.
    - The rim of a rounded glass in `ImageRenderer` changes after the first renders of the process (`RenderedPixels.isClose(to:at:)` doc). Path B images can thus differ near a glass edge between runs. To check in the 3 full runs.
    - ShimmerView and LiveSymbolEffect stop with Reduce Motion. Each variant pins Reduce Motion on, animations off, locale and time zone, so that the images do not change with the computer.
    - SwiftPM warns about an unhandled file in a test target. The PNG folder must be in `exclude:` of the AgentViewKitTests target. ManifestTests does not read that `exclude:` list.
    - AgentViewKitTestSupport must not link PackageFileSupport (ManifestTests reads its dependency list). The snapshot helper finds the package root from the `#filePath` of the test.
    - The tools of this session cannot show a PNG to the agent (the `files` read gives "invalid file data", and a sub agent has no image tool). The image check uses the Vision text recognition (OCR) of each PNG, the mean brightness, and a coarse text map of each image.
  timestamp: 2026-10-21T16:28:28.525050+00:00
- actor: claude-code
  id: 01m5fr82cha8c27ezjajc5fdwk
  text: |-
    Discoveries (AVK-13):
    - ImageRenderer (path B) has these limits. It draws an AppKit view (NSViewRepresentable) as a yellow placeholder, and the full PromptInputView is all placeholder. It draws nothing for a view with accessibilityFocused (the RequestDeck cards) and nothing for a ResponseView. It stops the process with "no current update to enqueue action to" for a full AgentThreadView. Thus path B renders only the glass parts of the kit with SwiftUI content: the composer field and accessory, the deck header glass, and the floating controls.
    - The window cache (path A) shows no glass, because the render server draws the glass. In path A, light and reduce-transparency give the same pixels.
    - The rim of a rounded glass in ImageRenderer changes between runs. Over 6 runs: at most 109 of 409,600 pixels (0.027%), up to 39 levels. A tolerance of 32 levels is not safe. Deviation: path B compares with a changed-pixel share, RenderedPixels.glassRimShare = 0.001. A Reduce Transparency change changes 3,050 to 21,679 pixels, so the share still finds real changes. Path A uses the exact compare (share 0).
    - Images to check by eye: the HostedSnapshotTests composer-idle and composer-running images are the same (no glass buttons in the cache). In the GlassSnapshotTests composer-field-running images, a wide blue band shows over the field (the .glassProminent tint of the Stop button). The path B images are stand-ins: placeholder text replaces the EditorKit editor. In the elicitation-form images, "This field is necessary." shows at once.
    - Mutation check: TerminalView header padding .m to .l gave 4 failures and wrote terminal-*.actual.png and terminal-*.diff.png to .build/snapshots/HostedSnapshotTests (2081 marked pixels). The code is put back.
  timestamp: 2026-10-21T17:30:51.153167+00:00
- actor: claude-code
  id: 01m5fr84qaewgg7kg41868rw8e
  text: |-
    step: implement
    outcome: changed
    evidence: ViewSnapshot, SnapshotStore, SnapshotVariant, RenderedPixels+PNG in Sources/AgentViewKitTestSupport; 52 reference PNGs in Tests/AgentViewKitTests/Snapshots/__Snapshots__/{HostedSnapshotTests,GlassSnapshotTests}; diff output in .build/snapshots/<suite>/; README "Snapshot images" section; 3 full runs (avk13-final1..3) pass: 1544 + 180 + 1 tests, 3 known issues (2 old, 1 withKnownIssue test); on-screen test windows 0; no frontmost app change.
    task: ^zrxfa05
  timestamp: 2026-10-21T17:30:53.546102+00:00
- actor: claude-code
  id: 01m5frf26aapt5jswspkacdk8g
  text: |-
    ### test - green
    - evidence: run-watched.sh full1 (swift build --build-tests, then swift test --skip-build): 1544 tests in 194 suites passed, 0 failures, 0 skipped, 3 known issues. Exit 0.
    - windows: 0 on-screen test windows. 531 samples. The only frontmost app entry is the start state (Calendar); no change.
    - warnings: a rebuild after touch of the changed files gave 0 warnings from them. The only warning is the SwiftPM bundle message "missing creator for mutated node" (mlx-swift_Cmlx.bundle), not from a changed file.
    - known issues (all on purpose): SnapshotStoreTests theCheckOfAViewThatChangedRecordsAnIssue (new; proves that verify records an issue for a changed view), HostedLayoutExpectationsTests aWrappedTextWithAFixedVerticalSizeFails, ThemeHeightExpectationsTests aViewThatIgnoresTheThemeFails (both existed before). None hides a real failure.
    - no new reference PNG recorded. No commit. Card stays in doing.
    - next: review
  timestamp: 2026-10-21T17:34:40.330380+00:00
- actor: claude-code
  id: 01m5frpnseegjwa1ff7zprmsnq
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 9578e76). 7 findings, rule `code-hygiene/magic-numbers-swift`: Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:37, :40, :43, :46, :49, :52, :55.
    - next: Replace the magic numbers in SnapshotFixtures.swift with named constants. Remove this cause from all of the file, not only from these lines. Then run the review again.
  timestamp: 2026-10-21T17:38:49.774762+00:00
- actor: claude-code
  id: 01m5frq345b1yymcn38gvgjy5x
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — ViewSnapshot, SnapshotStore, SnapshotVariant, RenderedPixels+PNG, snapshot tests, 56 reference PNGs
    - test: green — run-watched.sh full1, 1544 passed, 0 failed, 3 known issues; on-screen test windows 0
    - commit: 9578e76
    - review: findings — Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:37, :40, :43, :46, :49, :52, :55
  timestamp: 2026-10-21T17:39:03.429820+00:00
- actor: claude-code
  id: 01m5fryr1j1a5ekkdr5vchakdt
  text: |-
    Implement (findings of rule `code-hygiene/magic-numbers-swift`):
    - Cause: each image size used numeric literals as arguments of `CGSize(width:height:)`. swiftlint `no_magic_numbers` reports a literal in a call argument, but not a literal in a `static let`.
    - Change in SnapshotFixtures.swift: two shared widths (`wideWidth` 480, `narrowWidth` 420) and one height for each image (`threadHeight`, `composerHeight`, `cardHeight`, `bannerHeight`, `codeBlockHeight`, `terminalHeight`, `elicitationHeight`), each a documented `static let ...: CGFloat`, as in the other test files. Each size now uses only these names. The values did not change. The only other literal in the file is `index: 0`, which the rule permits.
    - The 56 reference PNGs did not change (git status shows no PNG change). No PNG was recorded.
  timestamp: 2026-10-21T17:43:14.226386+00:00
- actor: claude-code
  id: 01m5fryvg2kw371k9f64g7t2s0
  text: |-
    ### implement — changed
    - evidence: 1 file — Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift. 7 findings checked. run-watched.sh zrx-snap (--filter HostedSnapshotTests|GlassSnapshotTests): 14 tests in 2 suites passed, 0 failures. run-watched.sh zrx-full: 1544 tests in 194 suites passed + 180 tests in 26 suites + 1 test, 0 failures, 3 known issues (all on purpose, as before). On-screen test windows 0 in both runs; no frontmost app change. Build warnings: only the SwiftPM "missing creator for mutated node" message (mlx-swift_Cmlx.bundle), not from the changed file. No PNG changed. No commit.
    - next: review
  timestamp: 2026-10-21T17:43:17.762234+00:00
- actor: claude-code
  id: 01m5fs10qcyh1ea3wba9s3g31y
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit e977f12). 0 findings, 0 confirmed, 0 refuted. 1 file reviewed. All 7 items in the earlier Review Findings section are checked.
    - next: The task moved to done. No more work is necessary.
  timestamp: 2026-10-21T17:44:28.652531+00:00
- actor: claude-code
  id: 01m5fs19mvn77zcsmc96dc6qed
  text: |-
    ### finish iteration 2 — clean
    - implement: changed — SnapshotFixtures.swift named constants; 7 findings checked
    - test: green — run-watched.sh full run, 1725 passed, 0 failed, 3 known issues; on-screen test windows 0; 0 PNG changes
    - commit: e977f12
    - review: clean — 0 findings; card moved to done
  timestamp: 2026-10-21T17:44:37.787058+00:00
depends_on:
- 01M5FH4Z521FC705TKY8NT2787
position_column: done
position_ordinal: ffffa380
title: AVK-13 PNG snapshot images of the real views, with reference images and diffs
---
Source: the user, 2026-10-21: "i want you to actually test the view, not just the model. and i want you to have images to look at cause lots of my feedback is going to be 'this is ugly'". Depends on AVK-12 (the hidden-window harness).

Do:
- Add a small helper in Sources/AgentViewKitTestSupport, for example `ViewSnapshot`, with two render paths:
  - Path A (all views except the glass parts): mount the real view in the hidden-window `HostedViewHarness`, `render()`, then `RenderedPixels(cachingDisplayOf:)`, then write a PNG. This path draws AppKit-backed views (ScrollView, List, TextEditor, the EditorKit editor) and views with `.accessibilityFocused`.
  - Path B (glass parts in isolation: composer field, request deck in the bar, floating controls): `RenderedPixels(rendering:)` (`ImageRenderer`). Say in the doc comment that this is a glass look and maybe not the exact system Liquid Glass.
- Variants for each view: light, dark (set `window.appearance` aqua/darkAqua and `.environment(\.colorScheme)`), Reduce Transparency, Increase Contrast (the private environment keys that the repo already uses).
- Reference images next to the tests, for example `Tests/AgentViewKitTests/__Snapshots__/<Suite>/<view>-<variant>.png`. Compare with the existing tolerance (`RenderedPixels.isClose`). On a change, write `<name>.actual.png` and `<name>.diff.png` to one known folder (for example `.build/snapshots/`), and attach them with Swift Testing `Attachment`. A record mode with an environment variable (for example `AVK_SNAPSHOT_RECORD=1`) writes the reference images.
- Snapshot tests for: the thread (with messages, a tool call, a code block), the composer (idle and running), a permission request card, the request deck in the bar, a session notice, a status banner, a code block, the terminal output, an elicitation form. Light, dark, Reduce Transparency, Increase Contrast for each.
- Use no new package dependency unless the structure tests (ManifestTests, ResolvedPinsTests) permit it; the kit helper is preferred.
- Make each snapshot deterministic: fixed size, fixed scale 2x, sRGB color space, fixed data, fixed dates, no animation.
- Document in the README (Testing section) where the images are and how to record them.

Acceptance:
- The reference PNGs are in the repo, and a person can open them.
- A test fails, and writes the actual and diff PNGs, when a view's look changes (show this with one mutation, then put it back).
- 3 full `swift test` runs one after the other pass, with no window on the screen and no focus change.
- No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-13

## Review Findings (2026-10-21 12:35)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 12 file(s) reviewed, 61 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule: `.kanban/` (from .reviewignore).

> 56 file(s) not reviewed — the PNG reference images under `Tests/AgentViewKitTests/Snapshots/__Snapshots__/` are not UTF-8 text, so there is nothing to review.

> 1 file(s) not reviewed — no validator matched: `README.md`.

- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:37` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:40` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:43` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:46` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:49` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:52` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
- [x] `Tests/AgentViewKitTests/Snapshots/SnapshotFixtures.swift:55` `code-hygiene/magic-numbers-swift` — Magic numbers should be replaced by named constants.
