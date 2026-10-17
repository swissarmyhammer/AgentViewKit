---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5572vnc82q5w654gbc1kye8
  text: |-
    Research:
    - Package.swift has no `defaultLocalization`. The kit target has `resources: [.copy("Resources/Grammars")]`. GrammarBundle uses `Bundle.module` for the grammar folder.
    - 257 `String(localized:)` calls in Sources/AgentViewKit. No call has `bundle:`, `comment:`, `table:` or `defaultValue:`. So `, bundle: .module` goes last in each call. One doc comment in ElicitationValidator.swift names `String(localized:)`.
    - The test target has no resources, so `Bundle.module` in the tests is the kit bundle through `@testable import AgentViewKit` (many tests already use `@testable`).
    - RED: Tests/AgentViewKitTests/Infrastructure/StringCatalogTests.swift. 4 tests (5 cases) fail: no `Localizable.strings` in en.lproj, and lookups with a sentinel default give the sentinel.
    - Discovery: `Bundle.module.localizations.contains("en")` is already true without the catalog, so that check does not prove anything. A plain `String(localized: "Copy Thread", bundle: .module)` also gives "Copy Thread" without a catalog (the key is the fallback). The test therefore uses a sentinel `defaultValue:`, so the English text can come only from the catalog.
  timestamp: 2026-10-17T15:18:30.316904+00:00
- actor: claude-code
  id: 01m558qxkbnxec01bzjxt00zj5
  text: |-
    Implementation landed (not committed):
    - Package.swift: `defaultLocalization: "en"`, and `.process("Resources/Localizable.xcstrings")` beside `.copy("Resources/Grammars")`.
    - 269 `String(localized:)` calls in Sources/AgentViewKit now have `bundle: .module`, 12 of them multi-line `String(\n localized:)` calls that `rg 'String\(localized:'` does not show. A scratchpad script found the close paren and respected string literals and `\( )` interpolation.
    - 61 SwiftUI literal keys changed: `Text("x")` became `Text("x", bundle: .module)`; `Text("")` became `Text(verbatim: "")`; the literal of `Button`, `Label`, `TextField`, `ContentUnavailableView`, `.help`, `.accessibilityLabel/Hint/Value` became `String(localized: "x", bundle: .module)` (the existing pattern of the kit).
    - Lines that became longer than 100 characters were formatted with `swift format format --lines` (all rules off, so only the layout changed), then checked by hand.
    - Catalog: `xcodebuild -scheme AgentViewKit build SWIFT_EMIT_LOC_STRINGS=YES -skipMacroValidation -skipPackagePluginValidation`, then `xcstringstool sync` with only the AgentViewKit-t `*.stringsdata` files. 305 keys. A check script found a catalog key for each of the 329 localized literals of the kit.
    - DISCOVERY: `xcstringstool compile` does NOT compile an extracted entry that has no value, or an entry in the `new` state. With the plain sync output, the bundle got no `en.lproj` at all and the test stayed red. Each entry now has an explicit English value in the `translated` state (the value Xcode wrote, for example `Request %1$lld of %2$lld`). A second `xcstringstool sync` does not change the file, so the format is canonical. The compiled `en.lproj/Localizable.strings` has all 305 keys. A future sync adds new keys with no value; those keys still show the English key at run time, but they are not in the compiled table until they get a value.
    - Test: Tests/AgentViewKitTests/Infrastructure/StringCatalogTests.swift, 5 tests: the compiled table is in `Bundle.module`, two `localizedString(forKey:value:table:)` lookups with a sentinel default value, and two `String(localized:defaultValue:bundle: .module)` lookups with a sentinel default value. The first version expected the key as the value of the format key. The catalog value is positional, so the test now expects `Request %1$lld of %2$lld`.
  timestamp: 2026-10-17T15:47:29.003677+00:00
- actor: claude-code
  id: 01m558r53h290p2vn2tecttjd2
  text: |-
    ### implement — changed
    - evidence: 67 paths — Package.swift; Sources/AgentViewKit/Resources/Localizable.xcstrings (new, 305 keys); Tests/AgentViewKitTests/Infrastructure/StringCatalogTests.swift (new); 64 files in Sources/AgentViewKit (bundle: .module). TDD: RED 4 tests / 5 issues (no catalog), GREEN 5/5. `swift build --build-tests`: 0 warnings from the package sources (only the known mlx-swift_Cmlx "missing creator for mutated node" build-graph warning, which shows on a no-op build too). `swift test`: 1324 tests in 155 suites passed (2 known issues from the existing withKnownIssue negative tests), plus 127 PackageStructureTests and 1 ReadmeSnippetsTests. `Scripts/check-readme.sh`: passed. Demo app: `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` and `xcodebuild -project ... -scheme AgentViewKitDemo build`: BUILD SUCCEEDED, and the app holds AgentViewKit_AgentViewKit.bundle/en.lproj/Localizable.strings. `Scripts/test-examples.sh` (UI tests) was NOT run, as the caller instructed.
    - next: /review
  timestamp: 2026-10-17T15:47:36.689543+00:00
- actor: claude-code
  id: 01m558spxqcnzbghb2h2a4mdmz
  text: |-
    ### commit — changed
    - evidence: ee5f3af feat(localization): add a String Catalog to the AgentViewKit target (^jnw13v0)
    - next: none. The commit is local. It is not pushed.
  timestamp: 2026-10-17T15:48:27.703012+00:00
- actor: claude-code
  id: 01m559bcmnxmxfw3qnhmrvg6r1
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit ee5f3af). Counts: 5 findings, 5 confirmed, 8 refuted. Findings at Sources/AgentViewKit/Content/CommandOutputView.swift:222, Sources/AgentViewKit/Diff/DiffSummary.swift:160, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:488, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:494, Sources/AgentViewKit/Items/EntryTimingView.swift:137. The engine did not review Localizable.xcstrings (no validator matches it).
    - extra check, String(localized:): 310 calls (this count includes calls that start with `String(` on one line and `localized:` on the next line). All 310 have `bundle: .module`. All have the arguments in a valid order (localized, defaultValue, table, bundle, locale, comment).
    - extra check, SwiftUI literal keys: two ternary string literal keys are still `LocalizedStringKey` values that look up the main bundle of the host app. (1) Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift: `Button(showsTerminal ? "Hide Terminal" : "Show Terminal", systemImage: ...)`. (2) Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift: `Button(dateTime ? "Set Date and Time" : "Set Date")`. The engine finding at ElicitationFieldViews.swift:488 covers (2). The engine does not cover (1), because the change did not touch that line. Thus the acceptance item "No SwiftUI string literal key in the kit looks up the main bundle" is not satisfied. All `Text("...")` literal keys have `bundle: .module`.
    - extra check, catalog: 305 catalog keys and 301 source keys. Each source key has a catalog entry with an English value. The 4 catalog keys with no kit-bundle source call are "Hide Terminal", "Show Terminal", "Set Date", "Set Date and Time". These are the main-bundle ternary keys above. Each `%lld` agrees with an `Int` argument. Each `%@` agrees with a `String` argument.
    - extra check, test: StringCatalogTests.swift is certain. It has no sleep, poll, retry or time limit.
    - next: implement the 5 findings and the PermissionView.swift ternary key, then run /review again.
  timestamp: 2026-10-17T15:58:06.997908+00:00
- actor: claude-code
  id: 01m559c5qwzdd89mz5jyvnqqgh
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 67 paths
    - test: green — swift test, 1324 passed; check-readme.sh passed; demo xcodebuild BUILD SUCCEEDED (from the implement run)
    - commit: ee5f3af
    - review: findings — CommandOutputView.swift:222, DiffSummary.swift:160, ElicitationFieldViews.swift:488, ElicitationFieldViews.swift:494, EntryTimingView.swift:137; extra: PermissionView.swift ternary Button key ("Hide Terminal" / "Show Terminal") still uses the main bundle
  timestamp: 2026-10-17T15:58:32.700445+00:00
- actor: claude-code
  id: 01m55abcj1fjk8mvcjkrhf6xhn
  text: |-
    Iteration 2 (review findings) landed. Not committed.
    - CommandOutputView.swift: `private static var copyTitle` gives the title and the help text of the Copy button.
    - DiffSummary.swift: the `txt` entry of `languageNames` is now `plainLanguage`, so a `.txt` file and a file with no extension give the one localized "Text" key. The catalog entry "Text" has the English value "Text" in the `translated` state, so the localized key is the correct single source. New test `aTextFileAndAFileWithNoExtensionHaveTheSameLanguageName`. This test passes before and after the change in English, because no translation exists yet. It holds the invariant for a future translation.
    - ElicitationFieldViews.swift: `static var removeDateTitle` (title and help text of the Remove Date button) and `static func setDateTitle(dateTime:)` ("Set Date and Time" / "Set Date" with `String(localized:bundle: .module)`).
    - PermissionView.swift: the ternary key `Button(showsTerminal ? "Hide Terminal" : "Show Terminal", ...)` is replaced by `private var terminalLinkTitle`, which gives `String(localized:bundle: .module)` for each branch.
    - EntryTimingView.swift: new internal helper `EntryTimingView.durationPhrase(_:locale:phrase:fallback:)`. `EntryTimingView.accessibilityLabel`, `ReasoningView.completedTitle` and `ReasoningView.accessibilityLabel` call it with their own literals. The localized keys did not change. EntryTimingTextTests now uses `@testable import` for the two new helper tests.
    - Kit-wide search: a scan of Sources/AgentViewKit for a ternary of string literals in a localized key (Text, Button, Label, Toggle, TextField, Picker, Section, Menu, Link, help, accessibilityLabel/Hint/Value, navigationTitle, alert, and the like) found only the two known sites (PermissionView and ElicitationFieldViews). Other `? "` matches are plain `String` values (StreamingMarkdownBalancer, FileReferenceSource, SpeechInputButton), not keys. The `??` calls such as `Text(name ?? x)` take the `StringProtocol` overload, so they are verbatim and not keys.
    - New guard test: Tests/PackageStructureTests/TernaryLocalizedKeyTests.swift (follows the FixedColorTests scan pattern). RED: `noKitViewGivesATernaryStringLiteralKey` failed with the two sites. GREEN after the fix.
    - Catalog sync: `xcodebuild -scheme AgentViewKit -destination 'platform=macOS' build SWIFT_EMIT_LOC_STRINGS=YES -skipMacroValidation -skipPackagePluginValidation`, then `xargs xcrun xcstringstool sync <catalog> --stringsdata < list` with the 179 AgentViewKit-t `*.stringsdata` files. Result: no change to Localizable.xcstrings. 305 catalog keys, 305 source keys, no stale key, no key without a source, each entry has an English value in the `translated` state. The four keys that had only main-bundle sources ("Hide Terminal", "Show Terminal", "Set Date", "Set Date and Time") now come from kit-bundle calls.
    - DISCOVERY (what did not work): `xcstringstool sync <catalog> --stringsdata a --stringsdata b ...` (the flag repeated for each file) marked all 305 keys `stale`. Give the flag one time, followed by all the files (`--stringsdata a b c`), for example with `xargs`. Then the sync is correct.
  timestamp: 2026-10-17T16:15:35.489470+00:00
- actor: claude-code
  id: 01m55abh5x64rd6gp7zq10kq0x
  text: |-
    ### implement — changed
    - evidence: 9 files — Sources/AgentViewKit/Content/CommandOutputView.swift, Sources/AgentViewKit/Diff/DiffSummary.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Sources/AgentViewKit/Items/EntryTimingView.swift, Sources/AgentViewKit/Items/ReasoningView.swift, Tests/AgentViewKitTests/Diff/DiffSummaryTests.swift, Tests/AgentViewKitTests/Items/EntryTimingTextTests.swift, Tests/PackageStructureTests/TernaryLocalizedKeyTests.swift (new). Localizable.xcstrings: sync gave no change (305 keys, 0 stale, 0 orphan, all `translated`). TDD: RED durationPhrase (no member), RED ternary scan (2 sites); GREEN both. `swift build --build-tests`: no warnings from the package (only the known mlx-swift_Cmlx "missing creator for mutated node" build-graph warning). `swift test`: 1327 tests in 155 suites passed with 2 known issues (the existing withKnownIssue tests), plus 129 PackageStructureTests and 1 ReadmeSnippetsTests passed. `Scripts/check-readme.sh`: passed. UI tests not run, as the caller instructed. All 5 review findings are checked.
    - next: /review
  timestamp: 2026-10-17T16:15:40.221696+00:00
- actor: claude-code
  id: 01m55acxehd3hg29e5q9admm5p
  text: |-
    ### commit — changed
    - evidence: 3ee4bc8 fix(localization): use one source for the titles and the Text key in the kit bundle (^jnw13v0)
    - next: /review. The commit is local. It is not pushed.
  timestamp: 2026-10-17T16:16:25.553229+00:00
position_column: doing
position_ordinal: '80'
title: Add a String Catalog to the AgentViewKit target
---
Request from swissarmyhammer-96 (elicitation-plan.md, section "AgentViewKit", "Known gaps": the kit has no string catalog of its own).

## Work
- Package.swift: set `defaultLocalization: "en"`. Add `Resources/Localizable.xcstrings` to the AgentViewKit target as a processed resource.
- Each `String(localized:)` call in `Sources/AgentViewKit` must use `bundle: .module`. Else the text is looked up in the main bundle of the host app. There are about 257 calls; no call has the bundle now.
- The SwiftUI calls with a string literal key (`Text("…")`, `Button("…", systemImage:)`, `Label("…", systemImage:)`, `TextField("…")`, and the like) also look up the main bundle. Change them to use the kit bundle too.
- Fill the catalog with the English source strings. Extract them with the build (`SWIFT_EMIT_LOC_STRINGS`, then `xcstringstool sync`). No translation now.
- Test: a test proves that `Bundle.module` contains the catalog and that one `String(localized:bundle: .module)` gives the English text. No sleep, poll, retry or time limit.
- The package build and tests, the README gate (`Scripts/check-readme.sh`) and the Examples gate (`Scripts/test-examples.sh`) must stay green.

## Acceptance
- [ ] `rg 'String\(localized:' Sources/AgentViewKit` shows no call without `bundle: .module`.
- [ ] No SwiftUI string literal key in the kit looks up the main bundle.
- [ ] The catalog has all the English source strings.
- [ ] The new test passes; `swift test` passes.
- [ ] The README gate and the Examples gate build. #elicitation #foundation

## Review Findings (2026-10-17 10:48)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 67 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `Sources/AgentViewKit/Resources/Localizable.xcstrings` — no validator matches this file

- [x] `Sources/AgentViewKit/Content/CommandOutputView.swift:222` `reuse/reuse` — The "Copy output" text is built twice in the same header, once for the button title and once for the help text. Each call repeats the same localized literal. Store the text in one private constant, such as `private static var copyTitle`, and use it for both the button and the help text.
- [x] `Sources/AgentViewKit/Diff/DiffSummary.swift:160` `completeness/invariant-propagation` — The word "Text" is now localized for extensionless files (`plainLanguage`), but the same word is still a fixed English literal for the ".txt" extension in `languageNames`. The same language name therefore shows in two forms, and only one of them is translated. Route the "txt" entry through the same localized key, or stop localizing `plainLanguage` so both paths use one source. Verify the choice against the String Catalog entry for "Text".
- [x] `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:488` `completeness/invariant-propagation` — The "Remove Date" button is localized in this change, but its sibling button in the same date field, "Set Date" / "Set Date and Time", is still a plain English literal. The same view therefore mixes localized and unlocalized user-facing labels. Localize the "Set Date" and "Set Date and Time" labels with `String(localized:bundle: .module)` and add their keys to Localizable.xcstrings, so the date field has one consistent localization contract.
- [x] `Sources/AgentViewKit/Elicitation/ElicitationFieldViews.swift:494` `reuse/reuse` — The "Remove Date" text is built twice in the same button. The button title and the help text repeat the same localized literal. Store the text in one `static var` on `ElicitationDateField`, and use it for both the title and the help text.
- [x] `Sources/AgentViewKit/Items/EntryTimingView.swift:137` `duplication/duplication` — The VoiceOver label repeats the map-then-fallback shape used in ReasoningView.swift:98 and ReasoningView.swift:117. The copies differ only by the literal text. Move the shape into one shared helper that takes a localized-phrase closure and a fallback closure. Call it here with this label's literals, and from ReasoningView with its own literals.