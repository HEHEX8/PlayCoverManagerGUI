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
    func run(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) async throws -> String {
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

                if process.terminationStatus == 0 {
                    continuation.resume(returning: stdoutString)
                } else {
                    continuation.resume(throwing: ProcessRunnerError.commandFailed(command: [launchPath] + arguments, exitCode: process.terminationStatus, stderr: stderrString))
                }
            }
        }
    }

    func runSync(_ launchPath: String, _ arguments: [String], currentDirectoryURL: URL? = nil, environment: [String: String]? = nil) throws -> String {
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

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        if process.terminationStatus == 0 {
            return stdoutString
        } else {
            throw ProcessRunnerError.commandFailed(command: [launchPath] + arguments, exitCode: process.terminationStatus, stderr: stderrString)
        }
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
