import Foundation

struct AppError: Identifiable, Equatable, Error {
    enum Category: Equatable {
        case environment
        case diskImage
        case installation
        case installationRetry  // Special case for automatic retry
        case userCancelled
        case permissionDenied
        case unknown
    }

    let id = UUID()
    let category: Category
    let title: String
    let message: String
    let underlying: Error?
    let requiresAction: Bool

    init(category: Category, title: String, message: String, underlying: Error? = nil, requiresAction: Bool = false) {
        self.category = category
        self.title = title
        self.message = message
        self.underlying = underlying
        self.requiresAction = requiresAction
    }

    static func environment(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .environment, title: title, message: message, underlying: underlying)
    }

    static func diskImage(_ title: String, message: String, underlying: Error? = nil, requiresAction: Bool = false) -> AppError {
        .init(category: .diskImage, title: title, message: message, underlying: underlying, requiresAction: requiresAction)
    }
    
    static func permissionDenied(_ title: String, message: String) -> AppError {
        .init(category: .permissionDenied, title: title, message: message, requiresAction: true)
    }

    static func installation(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .installation, title: title, message: message, underlying: underlying)
    }
    
    static var installationRetry: AppError {
        .init(category: .installationRetry, title: "Retry", message: "Automatic retry triggered")
    }

    static func unknown(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .unknown, title: title, message: message, underlying: underlying)
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        return lhs.category == rhs.category &&
               lhs.title == rhs.title &&
               lhs.message == rhs.message
    }
}
