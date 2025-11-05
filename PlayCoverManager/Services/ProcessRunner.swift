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

final class ProcessRunner {
    func run(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
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

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                process.waitUntilExit()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
                let result = CommandResult(terminationStatus: process.terminationStatus, stdout: stdoutString, stderr: stderrString)

                if result.succeeded {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: ProcessRunnerError.commandFailed(command: [launchPath] + arguments, exitCode: result.terminationStatus, stderr: result.stderr))
                }
            }
        }
    }
}
