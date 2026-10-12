# Recorded sessions

This directory holds recorded sessions of FoundationModelsACPAgent. The
Gallery tab of the demo app shows them, so that you can see how the kit views
look with real session data.

The files come from SWE-bench runs of FoundationModelsACPAgent. Each
directory is one instance directory of
`../FoundationModelsACPAgent/bench/preds.<run>.transcripts/`, copied as it
is:

| Directory | Run |
|---|---|
| `django__django-13710` | `no-otel-1011` |
| `django__django-14155` | `code-context-1008` |
| `django__django-14608` | `no-otel-1011` |
| `django__django-14672` | `no-otel-1011` |

Each directory is one transcript location of the agent: `sessions.jsonl`,
`.gitattributes`, and one directory for each session with `session.json`,
`session-history.json`, and `transcript.jsonl`.

Do not edit these files. The sessions are replaced over time, and no test
reads their content.

## Replace the sessions

1. Remove the directories that you replace.
2. Copy whole instance directories from
   `../FoundationModelsACPAgent/bench/preds.<run>.transcripts/` into this
   directory, for example with `cp -Rp`. Do not trim or change a file.
3. Two directories must not have a session directory with the same name.
4. Change the table above.
5. Build the demo app again. The Xcode project holds this directory as a
   folder reference, so you do not make the project again.

At each start, the Gallery tab copies all the directories into one
transcript location in a temporary directory. It joins the lines of each
`sessions.jsonl`. Then it starts `acp-agent` with that copy, so that a
restore never changes the files in this directory.
