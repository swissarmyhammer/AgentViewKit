# AgentViewKit benchmarks

This package measures the streaming paths of plan.md §8. It gives the numbers
for research R1 (the cost of Textual when a response streams) and research R4
(the observation granularity of a FoundationModels stream). It records the
numbers as a committed baseline, and `Scripts/check-benchmarks.sh` fails when a
change makes a path slower than the baseline permits.

This is a **separate SwiftPM package** that depends on AgentViewKit by path, as
`../EditorKit/Benchmarks` is. The root package does not get the benchmark
dependencies, and `swift test` does not build the benchmarks.

## Run them

From the repository root:

```bash
# Each scenario, with a report.
swift package --package-path Benchmarks --disable-sandbox benchmark

# One scenario.
swift package --package-path Benchmarks --disable-sandbox benchmark \
    --filter "Streaming chunk, paragraph split on"

# The gate.
./Scripts/check-benchmarks.sh
```

The streaming scenarios mount SwiftUI views in an off-screen window. The
window server is not available in the sandbox of a package plugin, and a
SwiftUI render in the sandbox stops the process. Thus each command uses
`--disable-sandbox`.

The full suite takes about 50 seconds on the development machine (Apple
silicon, 32 cores, Darwin 27, Swift 6.4, release build).

## The scenarios

| Scenario | What it measures |
| --- | --- |
| Streaming chunk, paragraph split on | One chunk of a 2,000-line message through `ResponseView`: the append, the coalescer flush, the split, and one render of the hosted view |
| Streaming chunk, paragraph split off | The same chunk through one Textual `StructuredText` of the full message |
| Observation, SessionThreadSource over 1,000 chunks | One stream of 1,000 chunks from a fake `LanguageModel` through `SessionThreadSource`, with an observer of `thread.items` and an observer of the streaming message |
| Tail source, Snapshot.transcriptEntries | The same stream with no source. The reader takes the response text from each `ResponseStream.Snapshot` |
| Tail source, SessionPropertyValues.history | The reader takes the response text from `session.properties.history` at each observation change |
| Tail source, session.transcript | The reader takes the response text from `session.transcript` at each observation change |

### The streaming corpus

`StreamingCorpus.swift` makes a message of 2,000 lines: 100 sections of 20
lines, each with a heading, two prose paragraphs with inline Markdown, a list,
and a fenced Swift block. A model that streams at 50 tokens per second gives
2 tokens (8 characters) in one coalescer interval (33 ms). One benchmark chunk
is the text of one interval.

One iteration is one chunk. Before each measured chunk, the workbench streams
the chunks between two samples and renders them, outside the measurement.
Thus the percentiles hold chunks from the start, the middle, and the end of
the message, at the same places on each run.

### The count metrics

| Metric | What it counts |
| --- | --- |
| Body evaluations per chunk | The body evaluations of probe views that read the same observed values as the views of the kit: `settledParagraphs` and `tail` with the split, `text` with no split |
| Paragraphs parsed per chunk | The paragraphs that Textual parses for the chunk: the new settled paragraphs and the tail with the split, each paragraph with no split |
| Items invalidations per stream | The changes of an observer of `thread.items` |
| Streaming invalidations per stream | The changes of an observer of `thread.streaming[id]` |
| Tail updates per stream | The updates that one tail source gives |

`BodyEvaluationCounter` exists only in debug builds, and the benchmarks build
in release mode. Thus the benchmarks count probe views.
`Tests/AgentViewKitTests/Streaming/ParagraphReuseTests.swift` counts each
`ParagraphView` in a debug build, and proves that a settled paragraph does not
evaluate again.

`FakeLanguageModel.swift` and `ChangeCounter.swift` in
`Benchmarks/AgentViewKitBenchmarks/` are symbolic links to the files in
`DemoSupport` and in `AgentViewKitTestSupport`. A package can use only the
products of another package, so this package compiles the same files. Edit
the files in the root package. `BenchmarkSymlinkTests` in
`PackageStructureTests` fails when a link points at a file that moved.

## The gates

Each scenario checks its own gates, and stops with an error when a gate
fails. `Scripts/check-benchmarks.sh` fails on such an error.

| Scenario | Gate |
| --- | --- |
| Streaming chunk, paragraph split on | The p90 cost of one chunk is less than **4 ms** |
| Streaming chunk, paragraph split on | A chunk that settles no paragraph does not evaluate the settled paragraph list |
| Both streaming scenarios | Each chunk that changes the text evaluates the view of the text (the render did the update) |
| Observation, SessionThreadSource | The items observer changes at most **2 times for each transcript entry** (the insert and the final replace), for any number of chunks |
| All observation scenarios | The reader gets the full response text |

## R1: Textual streaming cost

### The numbers

The baseline run (`Baselines/`):

| Scenario | p90 wall clock | p90 paragraphs parsed per chunk | p90 body evaluations per chunk |
| --- | --- | --- | --- |
| Split on | **3.30 ms** (the gate reads 3.18 ms) | 1 | 1 |
| Split off | **86.2 ms** | 449 | 1 |

With the split, one chunk costs the same at the start and at the end of the
message. With no split, the cost of one chunk grows with the message: at 500
paragraphs, one chunk parses 500 paragraphs and costs about 100 ms, which is
three coalescer intervals.

The first run of this benchmark failed the gate: the p90 was **46 ms** with the
split. Two costs grew with the message:

1. `StreamingMessage` split the full text again for each flush. At 500
   paragraphs the split took 1.2 ms. `ParagraphSplitter.split(_:resumingAt:)`
   now starts at the first line that is not settled, and the flush takes
   0.03 ms at each point of the message.
2. The settled paragraphs were in a `VStack`. Each chunk changes the height of
   the tail, and the stack placed each settled paragraph again: 0.1 ms for
   each paragraph. In a scroll view, the settled paragraphs are now in a
   `LazyVStack`, which places only the paragraphs on screen
   (`EnvironmentValues.lazyResponseParagraphs`, set by `ConversationView`).
   A lazy stack shows its content only in a scroll view, so a `ResponseView`
   outside a scroll view keeps the `VStack`.

After the two changes, the render of one chunk is 1.5 ms to 4 ms at each point
of the message. Most of it is the Textual parse and layout of the tail, and
the Core Animation commit of the frame.

### The decision

**The tail stays on Textual, with the paragraph split and the balancer. The kit
does not add a lighter tail renderer** (plan.md §11 decision 9). The split is
necessary: with no split, the cost of one chunk grows past the coalescer
interval. With the split, the resumed split, and the lazy stack, the p90 cost
of one chunk is 3.2 ms to 3.3 ms, under the 4 ms gate.

The gate has a margin of about 20 % on the development machine. The benchmark
window has a fixed size (`sizingOptions = []`), as the window of an app has.
If a slower machine fails the 4 ms gate, measure the tail render first: it is
the largest part of the cost.

## R4: observation granularity

### The numbers

The baseline run, for one stream of 1,000 chunks:

| Tail source | p90 tail updates | p90 wall clock |
| --- | --- | --- |
| `Snapshot.transcriptEntries` | 970 | 14.2 ms |
| `SessionPropertyValues.history` | 692 | 15.6 ms |
| `session.transcript` | 690 | 15.6 ms |

| Observer, through `SessionThreadSource` | p90 invalidations per stream |
| --- | --- |
| `thread.items` | 3 (2 entries: the prompt and the response) |
| `thread.streaming[id]` | 3 |

- The stream gives one snapshot for almost each chunk. The two observed
  values change together: `session.properties.history` does not give a finer
  or a coarser granularity than `session.transcript`. An observer of either
  one gets fewer updates only because the changes between two main actor
  passes count as one.
- The first run of this benchmark found a leak: the items observer changed
  3 to 9 times for the same stream. Before the first snapshot opened the
  stream, the observation of `session.transcript` replaced the response item
  for each chunk. `SessionThreadSource` now keeps the response items of a turn
  while the turn streams, and replaces them one time at the end. The items
  observer now changes 3 times on each run.
- The streaming observer changes 3 times per stream, because
  `StreamingMessage` coalesces the chunks of one 33 ms interval.

### The decision

**`SessionThreadSource` takes the streaming tail from
`ResponseStream.Snapshot.transcriptEntries`**, as it does now:

- The snapshot source costs the least, and it gives each text in order, with
  the entry id of the response.
- `SessionPropertyValues.history` has the same granularity as
  `session.transcript`, and it gives no new data. The source does not use it.
- The source observes `session.transcript` only for entry boundaries: a new
  entry, a changed entry that does not stream, and a removed entry. A view
  reads `thread.items`, which changes only at entry boundaries, and the tail
  row reads `thread.streaming[id]`.

A note for later work: the full `SessionThreadSource` stream costs about
110 ms at p90, against 14 ms for the snapshots alone. The observation path
maps the full transcript at each change. The cost does not reach the views,
but a future change can make the observation path incremental.

## The gate policy

`BenchmarkPolicy.swift` holds each number of the policy, which is the policy
of `../EditorKit/Benchmarks`:

- **Instructions**: the primary gate. Tolerance **25 %** at p50 and p90.
- **Wall clock**: the secondary gate. Tolerance **75 %** at p50 and p90.
- **Throughput**: recorded, not gated.
- **Large counts** (paragraphs parsed, the tail updates of the snapshot
  source): tolerance **25 %**.
- **The two comparison scenarios** (`Tail source, SessionPropertyValues.history`
  and `Tail source, session.transcript`): recorded, not gated, in every
  metric. Each of them does one unit of work for each observation tick of
  the SDK, so its count, its instructions, and its wall clock change with the
  machine: the CI runner gave 3 times the count of the recording machine. A
  change in the kit cannot move these numbers; they are the reference of the
  R4 decision.
- **Small counts** (body evaluations, items and streaming invalidations): an
  absolute tolerance of **2**, because a change of one main actor pass moves
  a count of 3 by one.

## The baseline-update flow

The baseline is committed as two artifacts from the same run:

| Path | Purpose |
| --- | --- |
| `Benchmarks/Baselines/*.p90.json` | The baseline that a reader can review: the p90 of each metric of each scenario |
| `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/` | The baseline that `benchmark baseline check` reads |

Record both again, from the repository root:

```bash
swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory benchmark baseline update main

swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory \
    benchmark thresholds update main --path Benchmarks/Baselines
```

Then run `./Scripts/check-benchmarks.sh` and commit both paths in the same
change.

Record the baseline again for an intentional regression (and tell why in the
change), for an improvement past a threshold, for a new scenario, or for a
new recording machine. Do not record the baseline again to make a failed gate
pass.

## Adding a scenario

1. Put the scenario in the file for its area, or add a file with a
   `register…` function and call it from `Main.swift`.
2. Use `BenchmarkPolicy.configuration(iterations:countMetrics:)`. Do not
   write a threshold of your own.
3. Build the workload outside the measurement. Only the path under test goes
   between `startMeasurement()` and `stopMeasurement()`.
4. Record the baseline in the same change.
