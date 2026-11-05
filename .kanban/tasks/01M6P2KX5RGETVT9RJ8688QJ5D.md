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
position_column: doing
position_ordinal: '9680'
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
- [ ] Text tests for each converted site with a fixed locale. Drive through accessibility; no mouse, no focus stealing.
- [ ] Full AVK suite green.