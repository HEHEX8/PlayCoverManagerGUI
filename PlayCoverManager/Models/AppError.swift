import Foundation

struct AppError: Identifiable, Equatable, Error {
    enum Category: Equatable {
        case environment
        case diskImage
        case installation
        case userCancelled
        case unknown
    }

    let id = UUID()
    let category: Category
    let title: String
    let message: String
    let underlying: Error?

    init(category: Category, title: String, message: String, underlying: Error? = nil) {
        self.category = category
        self.title = title
        self.message = message
        self.underlying = underlying
    }

    static func environment(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .environment, title: title, message: message, underlying: underlying)
    }

    static func diskImage(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .diskImage, title: title, message: message, underlying: underlying)
    }

    static func installation(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .installation, title: title, message: message, underlying: underlying)
    }

    static func unknown(_ title: String, message: String, underlying: Error? = nil) -> AppError {
        .init(category: .unknown, title: title, message: message, underlying: underlying)
    }
}
