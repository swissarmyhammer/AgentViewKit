# Recorded sessions

This directory holds recorded sessions of FoundationModelsACPAgent. The
Gallery tab of the demo app shows them, so that you can see how the kit views
look with real session data.

Most of the files come from SWE-bench runs of FoundationModelsACPAgent. Each
of these directories is one instance directory of
`../FoundationModelsACPAgent/bench/preds.<run>.transcripts/`, copied as it
is:

| Directory | Run |
|---|---|
| `django__django-13710` | `no-otel-1011` |
| `django__django-14155` | `code-context-1008` |
| `django__django-14608` | `no-otel-1011` |
| `django__django-14672` | `no-otel-1011` |
| `stub-model-kinds` | stub model, see "The stub model sessions" |

Each directory is one transcript location of the agent: `.gitattributes`, and
one directory for each session with `index.md`, `session-history.json`, and
`transcript.jsonl`. This is the recording format of FoundationModelsRouter
49627d2 and later:

- The frontmatter of `index.md` is the Router `SessionRecord` of the session.
  The agent lists a session from it with
  `RouterSessionDirectory.recordedSessions(in:)`, and leaves out a session
  whose `firstActivityAt` is not set.
- Each line of `transcript.jsonl` is one Router `TranscriptEvent`, written
  through the Extras `JSONLFile`.
- Each date is ISO 8601 text in UTC with milliseconds, for example
  `2026-10-12T05:53:33.925Z`. The Router reads no other form of a date.

The sessions were recorded in the format before that, with `sessions.jsonl`,
`session.json`, and dates in whole seconds or in seconds as a number. On
2026-10-22 they were rewritten once to the new format, with the Router and
Extras types. Each `firstActivityAt` is the time of the first `prompt` event
of the transcript, and each `updatedAt` is the time of the last one. The
stub model sessions record no `prompt` event, so both dates are the
`updatedAt` of their old `sessions.jsonl` line, which has whole seconds.

Do not edit these files. The sessions are replaced over time, and no test
reads their content.

## The stub model sessions

The SWE-bench sessions have no attachments, no compaction, and no stop
reason other than `end_turn`. The `stub-model-kinds` directory has three
sessions that have them. The agent made them with its stub model, so no
model loaded and nothing downloaded:

| Session title | Kind |
|---|---|
| Attachments | A user message with a `resource_link` block and a `resource` block |
| Compaction | A compaction entry from the `/compact` command |
| Cancelled | A prompt whose work ended with the stop reason `cancelled` |

To record these sessions again:

1. Make an empty root directory, for example `/tmp/stub-run`. Make the
   directories `work`, `transcripts`, and `config/acp-agent` in it.
2. Write `config/acp-agent/config.yaml` with the text
   `transcripts:` and `  location: "<root>/transcripts"`.
3. In `work`, start `../FoundationModelsACPAgent/.build/release/acp-agent acp`
   with these environment variables:
   - `XDG_CONFIG_HOME=<root>/config`
   - `ACP_AGENT_STUB_MODEL=1`
   - `ACP_AGENT_STUB_CHUNK_DELAY_MS=500`
4. Send `initialize` with protocol version 2. Then, for each session, send
   `session/new` with the `work` directory as `cwd`, and then:
   - Attachments: one `session/prompt` with a text block, a `resource_link`
     block to a file in `work`, and a `resource` block with text.
   - Compaction: one `session/prompt` with text, and then one
     `session/prompt` with the text `/compact`.
   - Cancelled: one `session/prompt` with text, and `session/cancel` 1.5
     seconds after the prompt result.
5. After the idle `state_update` of each session, send `session/close`, so
   that the agent writes `session-history.json`.
6. Copy `<root>/transcripts` into this directory with `cp -Rp`.

## The scripted sessions of the Gallery

FoundationModelsACPAgent cannot make some entry kinds and states, or makes
them only in the live work of a prompt that a resume does not replay. The
Gallery shows these from `InMemoryDemoACPAgent` of `DemoSupport`
(`DemoGallery` and `DemoConnectionState`), next to the recorded sessions.
They are not in this directory.

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
transcript location in a temporary directory. Each session directory holds
its own record, so the copy writes no file of its own. Then it runs
FoundationModelsACPAgent in the process of
the app, through the package, with that copy as its transcript location, so
that a restore never changes the files in this directory. The tab starts no
`acp-agent` program, writes no configuration file, and sets no
`XDG_CONFIG_HOME`. The agent uses its stub model, so no model loads. When the
recorded `cwd` of a session is missing on the computer, the agent replays the
session with no tools and writes nothing for it.
