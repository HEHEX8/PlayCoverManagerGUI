import Foundation

extension AppError: LocalizedError {
    var errorDescription: String? { title }
    var failureReason: String? { message }
}
