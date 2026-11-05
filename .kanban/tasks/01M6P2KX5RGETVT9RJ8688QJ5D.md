---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6p7v6fvkfm8qwhb2gnbn7af
  text: |-
    ### Audit of Sources/ (grep: `+` on String/Text, `Text()+Text()`, `"\(a) \(b)"` with separators, `joined(separator:)`, hand plurals, plus generic catalog keys)

    Stencil: AVK does not depend on Stencil. It reaches the graph only through FoundationModelsExtras (`TemplateEngine`, Stencil 0.15.1 exact), which FoundationModelsSkills/Agents/MetadataRegistry use and which the AVK manifest explicitly does not depend on. Per instructions, Stencil is NOT added; the template sites are reported below for the user to decide.

    **FORMAT STRING (fix now: one catalog string, FormatStyles, named keys where a key would collide)**
    1. AgentViewKitStyle/Status/StatusBar.swift `Message.textLabel` — `"\(title), \(explanation)"` (not localized).
    2. Elicitation/ElicitationLayout.swift `ElicitationTabMarks.text` — `"\(requiredMark), \(answeredMark)"` (not localized; marks are English constants).
    3. Elicitation/ElicitationWhoAsks.swift `whoAsksAccessibilityLabel` — names `joined(", ")` → ListFormatStyle (.and, .narrow); `whoAsks` source suffix uses generic key `%@ · %@` → named key.
    4. Sessions/SessionTree.swift `SessionStateText.choiceLabel` — parts `joined(", ")` → ListFormatStyle.
    5. Sessions/SessionBreadcrumb.swift `accessibilityLabel(for:title:)` — parts `joined(", ")` → ListFormatStyle.
    6. Status/SessionNoticeBanner.swift `label(for:)` — parts `joined(", ")` → ListFormatStyle.
    7. Status/TaskListView.swift `entryLabel` — `"\(content), \(status), \(priority)"` (not localized).
    8. Status/ContextUsageView.swift `costText` — `"\(amount) \(unit)"` (not localized).
    9. Elicitation/URLDisplay.swift `warning(forHost:)` — two sentences joined with `+` (not localized).
    10. Elicitation/ElicitationURLConsentView.swift `waitingMessage` — `"Waiting for \(host) to finish"` (not localized).
    11. Code/CodeBlockView.swift `accessibilityLabel` — `"\(language ?? "plain text") code block"` (not localized).
    12. ACP/SupportedProtocolVersions.swift `refusalMessage` — three sentences with `+`, versions `joined(", ")` (not localized) → one catalog string with a list style.
    13. Sessions/PendingRequestCountBadge.swift `openQuestionsLabel` — hand-written plural (`count == 1 ? … : …`) → one catalog string with plural variations.
    14. HumanInTheLoop/RequestDeckLayout.swift `positionLabel` — a localized string interpolated into another (`"\(request), \(moreCount) more"`) → two whole catalog strings.
    15. Generic colliding keys `%@, %@` and `%@: %@` → named keys: Items/ToolCallView.swift `accessibilityLabel`, Items/CompactionEntryView.swift label, Items/ErrorView.swift label, Theme/EditorStatus+ACP.swift `summary`, Inspection/InspectionText.swift `step`.
    16. Catalog strings with a count and an English plural noun and no plural variation: `%lld of %lld items`, `Show all %lld lines`, `Showing the last %lld of %lld lines`, `Select %lld or fewer/more items.`, `The text must have %lld or fewer/more characters.` → plural variations.

    **TEMPLATE (needs Stencil, which AVK lacks — reported, not changed)**
    - T1. Items/ThreadExporter.swift `markdown(for:)`/`heading(for:)` — Markdown document: `"## " + title`, sections `+ "\n\n" +`, loops.
    - T2. Commands/AgentCommandTarget.swift `plainText(of:)`/`section` — copy text: `role + ":"`, loops over messages and texts.
    - T3. Inspection/TranscriptEntries+Inspectable.swift plan `Steps` field — steps `joined("\n")` (loop).
    - T4. Elicitation/ElicitationView.swift `fieldErrorText`/`errorText(of:)` — error sentences `joined(" ")` per field and across fields (loops).
    - T5. Chain paths with a custom separator (no Foundation list style for a chain): ElicitationWhoAsks.swift `whoAsks` (`" › "`), Sessions/SessionTree.swift `SessionPathText.label` (`", then "`), Sessions/SessionJumpList.swift `pathText` (`" › "`), Status/SessionTreeBanners.swift `message(for:)` explanation (`" › "`).

    **NOT DISPLAY TEXT (ids, keys, logs, wire, content, fixtures)**
    - Accessibility identifiers / row keys / counter keys: ElicitationFieldViews `+ "-control"` etc., SessionJumpList/SessionBreadcrumb/ToolCallView/ReasoningView/UserMessageView/ItemRow/ActivityTimeline/PendingRequestCountBadge identifiers, TranscriptRowKey, ParagraphView/EntryContentView/TaskListView/AttachmentActions keys, AgentRowList/AgentRowSection, MessageActions, AgentCommands/AgentAttachmentCommands/AgentCommandGroup command ids, AgentKeymap chords.
    - Logs: GrammarBundle, FileExport, AttachmentActions, SessionModel+Requests loggers; Identifier.description.
    - Wire/data: ElicitationFieldViews date `%04d-%02d-%02d`, ContentBlockFile digest and file name, FileReferenceSource insert/path/sortKey, SlashCommandSource insert, InlineCitation URL, CitationProse marker splice, TextMarker, MathMarkdownParser, StreamingMarkdownBalancer, ParagraphSplitter, CommandOutputView rows, ToolCallView argv join, SpeechInputButton transcript, EntryContentView text join, InspectionText.text block join, ScriptedWireAgent, BackgroundRunScript.
    - Location notation `path:line`: ToolCallLocationChips.Location.text (compiler-style notation, no wording).
    - Already one catalog string: DiffSummary.accessibilityLabel, ThreadMinimapView.statusSummary (list style), UsageRingView.detailText, ConversationView, OutputChrome, TaskListView.headerText, RequestDeck `+%lld`, ElicitationView rule message, ErrorView detail, SessionMessageView, PermissionView, RequestDeckWithdrawn.
    - Fixtures/demo: PreviewFixtures, AgentViewKitDemoSupport (DemoGallery, DemoNestedSession), AgentViewKitTestSupport.

    **EditorKit (report to editorkit-b5, not patched)**: EditorSwiftUI/PaletteComponents.swift `FocusSegment.paletteName` (words capitalized and `joined(" ")`); EditorSwiftUI/KeybindingsEditor.swift `conflictDescription` (entries `joined(", ")`); EditorCommandsUI/Accessibility.swift `paletteResultLabel` (parts `joined(", ")`).
  timestamp: 2026-11-05T16:14:35.003349+00:00
- actor: claude-code
  id: 01m6p8ndqrqwgaen2rd4y8tfkb
  text: |-
    Implementation landed for every FORMAT STRING site (1–16 of the audit list, with these refinements):
    - New `StatusTitleText.label(title:explanation:)` (AgentViewKitStyle, key `status-title.label`) is the one label of a status text: StatusBar.Message.textLabel, ErrorView and CompactionEntryView use it (removes the generic `%@, %@` there; an empty detail no longer gives a trailing comma).
    - New internal `FormatStyle.spokenParts(locale:)` = `.list(type: .and, width: .narrow)` — CLDR en narrow list gives "a, b, c", so English labels are unchanged. Used by who-asks label, `SessionStateText.choiceLabel`, `SessionBreadcrumb.accessibilityLabel`, notice banner label; each takes `locale:` and the views pass `\.locale` of the environment.
    - Plurals: `%lld open questions` has one/other variations (hand ternary and `1 open question` key removed); `%lld of %lld items` uses a substitution on the second argument ("1 of 1 item"). Other count strings ("N or more items", "Show all N lines"…) are English-correct for every reachable count and were left.
    - Named keys: `tool-call.label`, `status.summary`, `inspection.plan-step`, `task-list.entry-label`, `elicitation-tab.marks`, `context-usage.cost-in-unit`, `url-display.*-warning`, `acp.protocol-version-refusal`. Removed dead keys `, `, `%@, %@`, `%@: %@`, `%@, %lld more`, `1 open question`.
    - Not changed by design: `%@ · %@` and `%@: %lld` have one site each (no collision); the visible who-asks chain is a template site (T5).
    - Discovery: SessionListView row label appends the open-questions Text through SwiftUI's `accessibilityLabel { label; Text(...) }` builder — system composition, not code concatenation; left as is.
    - TDD note: most conversions keep the English output byte-for-byte, so their tests are characterization tests (fixed en_US locale) that passed before and after; RED was seen as compile failures for the new APIs (`StatusTitleText`, `locale:` params). The plural RED ("1 of 1 item") was not run on its own because the test target did not compile until the APIs existed.
    - Hosted: new `IntegrationTests/.../Accessibility/SpokenListLabelsHostedTests.swift` reads the who-asks line, notice banner and crumb labels through accessibility in en_US. Other converted spoken labels were already read through accessibility by existing hosted tests (RequestDeckHostedTests, CodeBlockViewHostedTests, ElicitationURLConsentViewHostedTests, SessionEntryRowsHostedTests, StatusTitleLineHostedTests, PendingRequestCountBadgeHostedTests, ConversationViewHostedTests).
    - Root `swift test`: 996 tests / 111 suites + 50 / 10 Style tests passed, no AVK warnings.
  timestamp: 2026-11-05T16:28:54.392090+00:00
- actor: claude-code
  id: 01m6pb0etpb509203c560p3r40
  text: |-
    ### Template sites need a decision (Stencil is not an AVK dependency, so it was not added)
    - T1 Items/ThreadExporter.swift `markdown(for:)`, `heading(for:)` — Markdown export.
    - T2 Commands/AgentCommandTarget.swift `plainText(of:)`, `section(role:texts:)` — copy text.
    - T3 Inspection/TranscriptEntries+Inspectable.swift plan `Steps` field (`joined("\n")`).
    - T4 Elicitation/ElicitationView.swift `fieldErrorText`, `errorText(of:)` (sentences `joined(" ")`).
    - T5 chain paths: ElicitationWhoAsks.swift `whoAsks` (" › "), SessionTree.swift `SessionPathText.label` (", then "), SessionJumpList.swift `pathText` (" › "), SessionTreeBanners.swift `message(for:)` (" › ").
    Stencil reaches the graph only through FoundationModelsExtras `TemplateEngine` (Stencil 0.15.1 exact); the AVK manifest says the kit does not depend on Extras. Options: add Extras (or Stencil) to AgentViewKit, or accept these as they are.

    ### EditorKit sites for editorkit-b5 (not patched)
    - EditorSwiftUI/PaletteComponents.swift `FocusSegment.paletteName` — `joined(separator: " ")` of capitalized words.
    - EditorSwiftUI/KeybindingsEditor.swift `conflictDescription(for:)` — entries `joined(separator: ", ")`.
    - EditorCommandsUI/Accessibility.swift `paletteResultLabel` — parts `joined(separator: ", ")`.

    Integration run: 961 tests / 131 suites passed (EK 73033d2, before b707d51a). The 5 known issues are the intended `withKnownIssue` checks in FontRoleExpectationsTests. The run waited about 35 minutes on the machine UI test gate held by a SnapshotViewKit run.

    ### implement — changed
    - evidence: commit 2275d7b3; 36 files (25 Sources incl. both catalogs and 3 new files, 9 Tests, 1 IntegrationTests, ARCHITECTURE.md). `swift test`: 996 tests / 111 suites + 50 / 10 passed. `swift test --package-path IntegrationTests`: 961 / 131 passed. Zero AVK warnings.
    - next: /review. User decision on the template sites (T1–T5) and the EK report.
  timestamp: 2026-11-05T17:09:53.110369+00:00
position_column: done
position_ordinal: ffffffae80
title: Audit AVK for text built in code; move it to format strings or templates
---
User direction (2026-11-05): text assembled in code is wrong. "swift damned well has format strings", "there are certainly template libraries that can be used too … in fact we are using template libraries for our skills" (Stencil is in the graph via FoundationModelsSkills).

## Rule
- **Short display text:** ONE localized catalog format string with Foundation `FormatStyle`s interpolated (Date, Duration, number, list). Separators, order and wording live in the catalog.
- **Longer or structured text** (multi-part summaries, descriptions, anything with conditions or loops, and any text sent to an agent): a template, using Stencil like the skills packages do, rendered from a model. Never concatenate in code.
- If an EK view assembles text by hand, report it to editorkit-b5; don't patch EK.

## What
- Grep Sources/ for string building:
  - `+` on String or Text;
  - `"\(a) \(b)"` with literal separators;
  - `joined(separator:)` for display text;
  - `Text(...) + Text(...)`;
  - hand-written plurals.
- Classify each as a format string, a template, or fine (an id or key, not display text).
- Fix the display cases, adding catalog entries with comments and removing dead strings.
- The timing line is card ^b59f4y; skip it here.

## Tests
- [x] Text tests for each converted site with a fixed locale. Drive through accessibility; no mouse, no focus stealing.
- [x] Full AVK suite green.