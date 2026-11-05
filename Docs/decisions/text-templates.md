# Text templates

Status: decided. Source: user decision of 2026-11-05, task ^3b8m474, after
the text audit ^688qj5d. Date: 2026-11-05.

The kit builds some longer text from a list: a document, a copy text, the
lines of a field, a path of names, a run of sentences. No separator and no
order of parts is in code. Each one is in a Stencil template or in the
string catalog.

## The renderer

- `TextTemplates` (`Sources/AgentViewKit/Text/TextTemplates.swift`) is the
  one renderer. It reads each `TextTemplate` from the template folder of the
  module bundle (`Resources/Templates`, a `.copy` resource) and renders it
  with Stencil from a model: a dictionary of plain values.
- A template may include another file of its folder by name
  (`thread-markdown.stencil` includes `message-markdown.stencil`, so the
  sections of the export are the Markdown of the content that Copy gives).
- A template that does not render is a defect of the kit: the debug build
  stops on an assertion, and the release build logs it and gives an empty
  text.
- A test renders a site from a copy of the folder with one file edited, so
  it shows that the text comes from the file and not from code.

## The words of a template

The templates are not localized, and they hold no word. Each word comes from
the string catalog, and the site passes it in the model:

- The headings of the Markdown export are the sender names `User` and
  `Assistant`.
- The role line of the copy text is the catalog string `copy-text.role-line`
  (`%@:`) over the sender name, so a language can change the colon.
- Each plan step is the catalog string `inspection.plan-step` (`%1$@: %2$@`).

A template holds only layout: the Markdown heading mark `## `, the line
breaks and the blank lines.

## Which text is a template

| Site | Text | Choice | Why |
|---|---|---|---|
| T1 | `ThreadExporter.markdown(for:)`, both forms | Templates `thread-markdown`, `message-markdown` | A document in a file format: nested loops, a heading mark, blank lines and a closing line break. Layout, not language. |
| T2 | `AgentCommandTarget.plainText(of:)` | Template `copy-text` | A plain text document: a role line, then a line for each text, with a blank line between messages. |
| T3 | The `Steps` field of a plan in the inspector | Template `plan-steps` | One catalog step on each line: a document of lines. |
| T4 | `ElicitationView.fieldErrorText(title:validation:locale:)` and the error text of a form | Catalog: `“%1$@”: %2$@` for a field, and the sentence pattern `chain.sentences` (`%1$@ %2$@`) | The parts are sentences of the catalog, and the separator of two sentences depends on the language (none in Japanese or Chinese). A template is not localized, so it would fix one space for every language. |
| T5 | The visible who-asks line, `SessionJumpList.pathText(of:agent:locale:)`, the explanation of `WaitingDescendantBanner` | Catalog: the path pattern `chain.visible-path` (`%1$@ › %2$@`) | A path is a chain with one separator. A language can change the separator, or turn the order for a right-to-left script, in the pattern. A template would be a resource for one separator. |
| T5 | `SessionPathText.label(_:locale:)` | Catalog: the spoken path pattern `chain.spoken-path` (`%1$@, then %2$@`) inside `Path: %@` | The same chain, with words that VoiceOver reads, so it needs a translation. |

Foundation's list format has no form for a path or a run of sentences: its
patterns hold words such as "and". So `ChainText`
(`Sources/AgentViewKit/Text/ChainText.swift`) applies a two-part catalog
pattern to the parts one after the other, as a list format applies its own
patterns. Which parts the who-asks line shows (the root label, "…" and the
last names) stays a choice of the code; how the shown parts join is the
catalog's.
