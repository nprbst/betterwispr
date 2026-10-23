import Foundation
import Testing
@testable import BetterWisprCore

@Test func vsCodeClaudePanelAndTerminalTitlesAreRecognized() {
    #expect(ClaudePrompt.isClaudeCodePanel(description: "Message input", classes: ["messageInput_cKsPxg"]))
    #expect(!ClaudePrompt.isClaudeCodePanel(description: "Message input", classes: ["monaco-editor"]))
    #expect(!ClaudePrompt.isClaudeCodePanel(description: "Editor content", classes: ["messageInput_x"]))

    let claude = "Terminal 1, 2.1.301 Run the command: Toggle Screen Reader Accessibility Mode for an optimized screen reader experience"
    let shell = "Terminal 2, zsh Run the command: Toggle Screen Reader Accessibility Mode"
    #expect(ClaudePrompt.terminalTitle(claude) == "2.1.301")
    #expect(ClaudePrompt.terminalTitle(shell) == "zsh")
    #expect(ClaudePrompt.terminalTitle("Editor content") == nil)
    #expect(ClaudePrompt.isClaudeCodeProcessTitle("2.1.301"))
    #expect(ClaudePrompt.isClaudeCodeProcessTitle("claude"))
    #expect(!ClaudePrompt.isClaudeCodeProcessTitle("zsh"))
    #expect(!ClaudePrompt.isClaudeCodeProcessTitle("2.1"))
    #expect(!ClaudePrompt.isClaudeCodeProcessTitle(nil))
}

@Test func ghosttyTitleMustCarryClaudeCodesSpinnerGlyph() {
    #expect(ClaudePrompt.isClaudeCodeWindowTitle("✳ Kelly-starter.zip contents"))
    #expect(ClaudePrompt.isClaudeCodeWindowTitle("✶ Reviewing the diff"))
    #expect(!ClaudePrompt.isClaudeCodeWindowTitle("…/git/github.com/nprbst"))
    #expect(!ClaudePrompt.isClaudeCodeWindowTitle("duckdb -ui"))
    #expect(!ClaudePrompt.isClaudeCodeWindowTitle("✳"))
    #expect(!ClaudePrompt.isClaudeCodeWindowTitle(nil))
}

@Test func onlyForegroundProgramsUnderTheAppCount() {
    let table = [
        ClaudePrompt.ProcessEntry(pid: 10, parent: 1, command: "ghostty", device: nil, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 11, parent: 10, command: "login", device: nil, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 12, parent: 11, command: "zsh", device: nil, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 13, parent: 12, command: "claude", device: 4, isForeground: true),
        ClaudePrompt.ProcessEntry(pid: 20, parent: 1, command: "Code", device: nil, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 21, parent: 20, command: "claude", device: nil, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 22, parent: 20, command: "zsh", device: 4, isForeground: true),
    ]
    #expect(ClaudePrompt.foregroundProcesses(under: 10, in: table).map(\.command) == ["claude"])
    // The extension's own claude has no terminal, so a VS Code shell alone doesn't count.
    #expect(ClaudePrompt.foregroundProcesses(under: 20, in: table).map(\.command) == ["zsh"])
    #expect(ClaudePrompt.foregroundProcesses(under: 99, in: table).isEmpty)
}

@Test func aTerminalTabSendsOnlyWhenClaudeIsInFrontOnItsDevice() {
    let table = [
        ClaudePrompt.ProcessEntry(pid: 30, parent: 1, command: "zsh", device: 3, isForeground: false),
        ClaudePrompt.ProcessEntry(pid: 31, parent: 30, command: "claude", device: 3, isForeground: true),
        ClaudePrompt.ProcessEntry(pid: 40, parent: 1, command: "zsh", device: 4, isForeground: true),
        ClaudePrompt.ProcessEntry(pid: 41, parent: 1, command: "claude", device: nil, isForeground: false),
    ]
    #expect(ClaudePrompt.foregroundProcesses(onDevice: 3, in: table).map(\.command) == ["claude"])
    #expect(ClaudePrompt.foregroundProcesses(onDevice: 4, in: table).map(\.command) == ["zsh"])
    #expect(ClaudePrompt.foregroundProcesses(onDevice: 9, in: table).isEmpty)
}

@Test func sendToClaudeIsOffByDefaultAndKeepsItsWait() throws {
    let saved = #"{"autoPaste":true,"language":"auto","launchAtLogin":false,"saveHistory":true,"selectedModelID":"parakeet-v3","showCapsule":true,"silenceThreshold":0.002}"#
    let old = try JSONDecoder().decode(AppSettings.self, from: Data(saved.utf8))
    #expect(!old.sendToClaude && old.sendDelay == .milliseconds(ClaudePrompt.defaultDelay))
    var settings = AppSettings()
    settings.sendToClaude = true
    settings.sendDelayMilliseconds = 250
    let loaded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
    #expect(loaded.sendToClaude && loaded.sendDelay == .milliseconds(250))
    #expect(ClaudePrompt.delayChoices.contains(ClaudePrompt.defaultDelay))
}

@Test func aDictationThatAddsMoreIsSpacedFromTheTextBeforeIt() {
    #expect(TextJoin.continuing("This is a test.") == " This is a test.")
    #expect(TextJoin.continuing(", and more") == ", and more")
    #expect(TextJoin.continuing("\nNext line") == "\nNext line")
    #expect(TextJoin.continuing("").isEmpty)
    #expect(TextJoin.continuing("还有一件事。") == "还有一件事。")
    #expect(TextJoin.continuing("それから") == "それから")
}

@Test func onlyATextInputInClaudeDesktopTakesReturn() {
    #expect(ClaudePrompt.isTextInput(role: "AXTextArea"))
    #expect(ClaudePrompt.isTextInput(role: "AXTextField"))
    #expect(!ClaudePrompt.isTextInput(role: "AXButton"))
    #expect(!ClaudePrompt.isTextInput(role: nil))
}

@Test func anOutOfRangeSavedWaitIsClamped() {
    var settings = AppSettings()
    settings.sendDelayMilliseconds = -5
    #expect(settings.sendDelay == .zero)
    settings.sendDelayMilliseconds = 600_000
    #expect(settings.sendDelay == .seconds(5))
}

@Test func claudeCodeIsRecognizedFromNativeAndNpmInstalls() {
    #expect(ClaudePrompt.isClaudeCode(executable: "/Users/me/.local/share/claude/versions/2.1.308", arguments: ["claude"]))
    #expect(ClaudePrompt.isClaudeCode(executable: "/opt/homebrew/bin/claude", arguments: []))
    #expect(ClaudePrompt.isClaudeCode(executable: "/opt/homebrew/bin/node", arguments: ["node", "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js"]))
    #expect(ClaudePrompt.isClaudeCode(executable: "/usr/local/bin/node", arguments: ["claude"]))
    #expect(!ClaudePrompt.isClaudeCode(executable: "/bin/zsh", arguments: ["-zsh"]))
    #expect(!ClaudePrompt.isClaudeCode(executable: "/opt/homebrew/bin/node", arguments: ["node", "server.js", "claude"]))
}
