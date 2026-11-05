---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6phftrhcswema6cprq78rk3
  text: Duplicate of ^sy19jd4. The EK-adoption card already changed DiffLongLineHostedTests to expect EK's diff wrapping (local main d758c6d8), so these 3 failures pass once a branch merges onto main. Closed on the coordinator's call.
  timestamp: 2026-11-05T19:03:08.305193+00:00
position_column: done
position_ordinal: ffffffb080
title: 'DiffLongLineHostedTests fail after EditorKit 8141595: diff lines wrap onto several fragments'
---
Found while working ^3b8m474. After `swift package update` (EditorKit 2b0d42e2 → 8141595), `IntegrationTests` `DiffLongLineHostedTests.theLongLineLaysOutOnOneLineFragment` and `eachLineOfTheDiffLaysOutOnOneLineFragment` fail every time (3 issues: `fragments.count == 1` false for the long `func find(` line of `PreviewFixtures.smallPatch` at 480 pt). They fail the same way at AVK c905c28e, so they come from the EK update, not from AVK code. EK range candidates: EditorText `EditorTextView`/`WrapMap` (^sajf9s2, ^d111z3q "multiline fields wrap and fit their content"), Preview `PreviewField`/`PreviewValue` (content-sized previews), and the headless harness (^djfeppg). Decide whether the AVK diff must turn wrapping off, or EK's diff view lost its no-wrap setting, and fix it on the right side.

- [ ] Find the EK commit that makes diff lines wrap.
- [ ] Fix (AVK diff setup or an EK report), `DiffLongLineHostedTests` green.