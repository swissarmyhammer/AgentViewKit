import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import AuthenticationServices
import Foundation
import Testing

@Suite @MainActor struct FakesTests {
  // MARK: - Pasteboard

  @Test func fakePasteboardRecordsCopiesInOrder() {
    let pasteboard = FakePasteboard()
    let kitPasteboard: any AgentViewKit.Pasteboard = pasteboard

    kitPasteboard.copyText("first")
    kitPasteboard.copyText("second")

    #expect(pasteboard.copies == ["first", "second"])
    #expect(pasteboard.contents == "second")
    pasteboard.reset()
    #expect(pasteboard.copies.isEmpty)
    #expect(pasteboard.contents == nil)
  }

  @Test func systemPasteboardConformsAndWritesAString() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let kitPasteboard: any AgentViewKit.Pasteboard = pasteboard

    kitPasteboard.copyText("copied")

    #expect(pasteboard.string(forType: .string) == "copied")
  }

  // MARK: - Announcer

  @Test func recordingAnnouncerRecordsAnnouncementsInOrder() {
    let announcer = RecordingAnnouncer()
    let kitAnnouncer: any Announcer = announcer

    kitAnnouncer.announce("Turn complete", priority: .medium)
    kitAnnouncer.announce("Action required", priority: .high)

    #expect(
      announcer.announcements == [
        .init(message: "Turn complete", priority: .medium),
        .init(message: "Action required", priority: .high),
      ])
    announcer.reset()
    #expect(announcer.announcements.isEmpty)
  }

  // MARK: - Focus

  @Test func recordingFocusReporterRecordsMovesInOrder() {
    let reporter = RecordingFocusReporter()
    let kitReporter: any FocusReporter = reporter

    kitReporter.focusMoved(to: "permission-card")
    kitReporter.focusMoved(to: "elicitation-form")

    #expect(reporter.moves == ["permission-card", "elicitation-form"])
    reporter.reset()
    #expect(reporter.moves.isEmpty)
  }

  // MARK: - Web authentication

  static let authorizationURL = URL(string: "https://auth.example.com/authorize")!
  static let callbackURL = URL(string: "agentviewkit://callback?code=1")!

  @Test func fakeWebAuthSessionReturnsTheScriptedURL() async throws {
    let factory = FakeWebAuthSession(script: .callback(Self.callbackURL))
    let kitFactory: any WebAuthSessionFactory = factory

    let session = kitFactory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit")
    session.prefersEphemeralWebBrowserSession = true
    let url = try await session.start()

    #expect(url == Self.callbackURL)
    #expect(
      factory.calls == [
        .makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit"),
        .start(ephemeral: true),
      ])
    #expect(factory.sessions.count == 1)
  }

  @Test func fakeWebAuthSessionThrowsCancelled() async {
    let factory = FakeWebAuthSession(script: .cancelled)
    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit")

    await #expect(throws: ASWebAuthenticationSessionError(.canceledLogin)) {
      try await session.start()
    }
    #expect(factory.calls.last == .start(ephemeral: false))
  }

  @Test func fakeWebAuthSessionThrowsFailedToStart() async {
    let factory = FakeWebAuthSession(script: .failsToStart)
    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit")

    await #expect(throws: WebAuthSessionError.failedToStart) {
      try await session.start()
    }
  }

  @Test func fakeWebAuthSessionWaitsUntilCancel() async throws {
    let factory = FakeWebAuthSession(script: .waitsForCancel)
    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit")
    let scripted = try #require(factory.sessions.first)

    let start = Task { try await session.start() }
    while !scripted.isWaiting {
      await Task.yield()
    }
    session.cancel()
    session.cancel()

    await #expect(throws: ASWebAuthenticationSessionError(.canceledLogin)) {
      try await start.value
    }
    #expect(
      factory.calls == [
        .makeSession(url: Self.authorizationURL, callbackScheme: "agentviewkit"),
        .start(ephemeral: false),
        .cancel,
        .cancel,
      ])
    factory.reset()
    #expect(factory.calls.isEmpty)
    #expect(factory.sessions.isEmpty)
  }

  // MARK: - Process launcher

  @Test func fakeProcessLauncherRecordsTheLaunchAndFeedsOutput() async throws {
    let chunks = [Data("Open this URL\n".utf8), Data("Signed in\n".utf8)]
    let launcher = FakeProcessLauncher(scriptedOutput: chunks, scriptedExitStatus: 3)
    let kitLauncher: any ProcessLauncher = launcher

    let process = try kitLauncher.launch(
      program: "/usr/local/bin/agent",
      arguments: ["--login"],
      environment: ["AGENT_AUTH": "terminal"]
    )
    var received: [Data] = []
    for await chunk in process.output {
      received.append(chunk)
    }

    #expect(received == chunks)
    #expect(process.exitStatus == 3)
    #expect(
      launcher.calls == [
        .launch(program: "/usr/local/bin/agent", arguments: ["--login"], environment: ["AGENT_AUTH": "terminal"])
      ])
  }

  @Test func fakeProcessLauncherCanKeepTheOutputOpenUntilFinishOutput() async throws {
    let chunks = [Data("Type yes\n".utf8)]
    let launcher = FakeProcessLauncher(scriptedOutput: chunks, keepsOutputOpen: true)

    let process = try launcher.launch(program: "/bin/agent", arguments: [], environment: [:])
    var iterator = process.output.makeAsyncIterator()
    let first = await iterator.next()
    try process.write(Data("yes\n".utf8))
    let scripted = try #require(launcher.processes.first)
    scripted.finishOutput()
    let end = await iterator.next()

    #expect(first == chunks.first)
    #expect(end == nil)
    #expect(scripted.writes == [Data("yes\n".utf8)])
    #expect(!scripted.isTerminated)
  }

  @Test func fakeProcessLauncherRecordsWritesAndTerminateInOrder() throws {
    let launcher = FakeProcessLauncher()

    let process = try launcher.launch(program: "/bin/agent", arguments: [], environment: [:])
    try process.write(Data("y\n".utf8))
    process.terminate()

    #expect(throws: FakeProcessLauncher.ProcessStoppedError()) {
      try process.write(Data("n\n".utf8))
    }
    #expect(
      launcher.calls == [
        .launch(program: "/bin/agent", arguments: [], environment: [:]),
        .write(Data("y\n".utf8)),
        .terminate,
        .write(Data("n\n".utf8)),
      ])
    let scripted = try #require(launcher.processes.first)
    #expect(scripted.writes == [Data("y\n".utf8)])
    #expect(scripted.isTerminated)
  }

  @Test func fakeProcessLauncherThrowsTheScriptedLaunchError() {
    let launcher = FakeProcessLauncher()
    launcher.launchError = .init(message: "not found")

    #expect(throws: FakeProcessLauncher.LaunchError(message: "not found")) {
      try launcher.launch(program: "/bin/missing", arguments: [], environment: [:])
    }
    #expect(launcher.calls == [.launch(program: "/bin/missing", arguments: [], environment: [:])])
    #expect(launcher.processes.isEmpty)
    launcher.reset()
    #expect(launcher.calls.isEmpty)
  }
}
