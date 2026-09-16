---
comments:
- actor: claude-code
  id: 01m2n5p3ymgrga65fwhtvh4a8f
  text: |-
    Research (implement start):
    - EditorKit links tree-sitter grammars for JSON and Markdown only (`GrammarRegistry`).
    - `TextMateGrammarRegistry` is an immutable struct made from a `[LanguageID: TextMateGrammar]` table. Thus "register" means: build that table one time. GrammarBundle keeps it in a `static let`.
    - `TextMateGrammar(data:)` reads plist data only. It ignores `include` and `repository`. Most real grammars put all top-level rules behind `include`, so the EditorKit decoder gives no rules for them. GrammarBundle therefore reads JSON grammars and resolves `include` (`#name`, `$self`, `$base`) itself, and makes `TextMateRule` values with `TextMateGrammar(scopeName:patterns:)`. An include of an external scope is skipped.
    - The fallback scanner uses only `match` rules inside a `begin`/`end` region. The resolver keeps only `match` rules in a region.
    - No EditorView path paints TextMate captures. `.editorSyntax(_:)` accepts tree-sitter ids only, and `editorMarks` paints backgrounds only. I sent a request to the editorkit-14 session for an EditorView TextMate hook. This task does not wait for it; a follow-up task wires CodeBlockView when the API exists.
    - Grammar source: npm `tm-grammars` 1.32.20 (shikijs/textmate-grammars-themes, MIT), which has JSON copies of the upstream grammars with the upstream URL, commit, and license. The 12 files are about 1.1 MB. YAML and TOML come from the TextMate bundles, which have the permissive TextMate bundle license ("Permission to copy, use, modify, sell and distribute this software is granted").
  timestamp: 2026-09-16T13:14:49.684672+00:00
- actor: claude-code
  id: 01m2n7rk9jqc3sf32w89mhqkgk
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck. Partial work is on the local branch `wip/3t64xef` (commit 7dcdd59). It is not on main.
    - The branch has: `GrammarBundle` (a registry in a `static let`, `register()`, `languageID(forFenceTag:)`), `TextMateIncludeResolver` (resolves `#name`, `$self`, `$base`), 12 grammar JSON files (1.1 MB) with `LICENSES.md`, the `.copy("Resources/Grammars")` resource in Package.swift, `CodeBlockView` calls `register()` in `onAppear`, and `GrammarBundleTests`.
    - test: red. `swift test --filter GrammarBundleTests`: registration, tag mapping, license list, and size pass. `eachGrammarHighlightsAKeyword` fails for 9 of 12 languages (swift, python, typescript, javascript, shell, yaml, toml, html, css).
    - BLOCKER: EditorKit `TextMateFallback` cannot scan real TextMate grammars. Measured at EditorKit 6e85137: (1) Swift `Regex` cannot compile 443 bundled patterns (333 use lookbehind, 87 use nested character classes); (2) the scanner stops at the first `begin` rule that matches anywhere on a line and skips the later rules; (3) a region has no nested begin/end rules, no `\G`, and no end back references. Thus simple lines such as `import Foundation`, `const x = 1;`, `if true` give no `keyword` capture. The kit cannot correct the regex engine or the scanner.
    - EditorKit tasks: ^5ssynck (the TextMate tokenizer rewrite: ICU regex, rule selection, region stack, `\G`, include/repository, JSON decoding) must be done before this task can pass. ^mrs23b3 (`EditorView.editorSyntax(textMate:)`) is in progress; CodeBlockView must use it when it lands.
    - next: when EditorKit ^5ssynck is on EditorKit main, run `swift package update EditorKit`, merge `wip/3t64xef`, delete `TextMateIncludeResolver` if EditorKit resolves `include` itself (then load with `TextMateGrammar(contentsOf:)`), wire `CodeBlockView` to `editorSyntax(textMate:)` for `GrammarBundle.registry` grammars, and run the tests again.
    - The task stays in doing so that the next batch does not pick it again.
  timestamp: 2026-09-16T13:51:08.082216+00:00
- actor: claude-code
  id: 01m2nawxwn6gyqx9s9845nnj1a
  text: |-
    ### orchestrator — EditorKit status
    - EditorKit main now has `EditorSlotComposing.editorSyntax(textMate: TextMateGrammar)` and `EditorModel.textMateGrammar` (commits ee0c4bf, 3d66248; origin/main 56b9ce9). A tree-sitter coordinator wins when both are set.
    - The scanner rewrite (EditorKit ^5ssynck) is not done. The EditorKit owner must decide when it runs. Until then, real tm-grammars files give few keyword captures.
    - next: when ^5ssynck is on EditorKit main, run `swift package update EditorKit`, merge `wip/3t64xef`, and use `.editorSyntax(textMate:)` in CodeBlockView for a language with no tree-sitter grammar.
  timestamp: 2026-09-16T14:45:55.733805+00:00
depends_on:
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: doing
position_ordinal: '80'
title: 'GrammarBundle: TextMate grammars for the top agent languages, registered with EditorKit (plan §4.1, §11#13, research R2)'
---
## What
Create `Sources/AgentViewKit/Grammars/GrammarBundle.swift` and the resource folder `Sources/AgentViewKit/Resources/Grammars/`, per plan.md §4.1 and decision 13. This task settles research R2 with a decision recorded in `GrammarBundle.swift`.

- Pick MIT or equivalent TextMate grammars for Swift, Python, TypeScript, JavaScript, Rust, Go, shell, YAML, TOML, HTML, CSS, and SQL. Record each source URL, commit, and license in `Resources/Grammars/LICENSES.md`.
- `GrammarBundle.register()`: loads each grammar once into EditorKit's `TextMateGrammarRegistry` (`../EditorKit/Sources/EditorText/Syntax/TextMateFallback.swift`) and maps common fence tags (`ts`, `js`, `sh`, `bash`, `yml`) to the grammar ids.
- `GrammarBundle.languageID(forFenceTag:) -> LanguageID?`.
- `CodeBlockView` calls `register()` on first use.

## Acceptance Criteria
- [ ] Every listed language registers and a sample file highlights at least one token (assert a `.keyword` capture exists).
- [ ] `languageID(forFenceTag: "ts")` returns the TypeScript id.
- [ ] `LICENSES.md` lists every grammar and a test asserts the list matches the resource folder.
- [ ] The resource bundle adds less than 2 MB.

## Tests
- [ ] `Tests/AgentViewKitTests/Grammars/GrammarBundleTests.swift`: registration, tag mapping, license list, bundle size.
- [ ] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.