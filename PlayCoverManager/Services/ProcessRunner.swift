import Foundation

struct CommandResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { terminationStatus == 0 }
}

enum ProcessRunnerError: Error {
    case commandFailed(command: [String], exitCode: Int32, stderr: String)
}

final class ProcessRunner: Sendable {
    // Swift 6.2 optimization: Unified process execution logic
    // Extracts common logic to eliminate ~40 lines of duplication
    // nonisolated to allow calling from actor contexts
    nonisolated private func executeProcess(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL?, environment: [String: String]?) throws -> String {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        if let currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }
        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Get file handles and ensure they're closed after use
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        defer {
            // Automatically close file handles to prevent resource leaks
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutHandle.readDataToEndOfFile()
        let stderrData = stderrHandle.readDataToEndOfFile()
        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return stdoutString
        } else {
            throw ProcessRunnerError.commandFailed(command: [launchPath] + arguments, exitCode: process.terminationStatus, stderr: stderrString)
        }
    }
    
    // Swift 6.2 optimization: Serial actor for thread-safe async execution
    // Replaces DispatchQueue with structured concurrency
    private actor ProcessExecutor {
        private let runner: ProcessRunner
        
        init(runner: ProcessRunner) {
            self.runner = runner
        }
        
        func execute(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL?, environment: [String: String]?) throws -> String {
            try runner.executeProcess(launchPath, arguments, currentDirectoryURL: currentDirectoryURL, environment: environment)
        }
    }
    
    private var executor: ProcessExecutor!
    
    init() {
        self.executor = ProcessExecutor(runner: self)
    }
    
    /// Execute process asynchronously using Swift 6.2 structured concurrency
    /// Marked as @concurrent to explicitly run on concurrent executor (not caller's actor)
    @concurrent
    func run(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) async throws -> String {
        try await executor.execute(launchPath, arguments, currentDirectoryURL: currentDirectoryURL, environment: environment)
    }

    /// Execute process synchronously (use run() for async contexts)
    func runSync(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) throws -> String {
        try executeProcess(launchPath, arguments, currentDirectoryURL: currentDirectoryURL, environment: environment)
    }
}

extension ProcessRunnerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let exitCode, let stderr):
            let cmd = command.joined(separator: " ")
            let tail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Command failed (exit code: \(exitCode))\n\(cmd)\n\(tail)"
        }
    }
}
