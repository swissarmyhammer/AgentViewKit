---
depends_on:
- 01M21ACHJYSF8G8R7HY3M70Z7F
position_column: todo
position_ordinal: a180
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