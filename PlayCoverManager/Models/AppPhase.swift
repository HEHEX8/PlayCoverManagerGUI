import Foundation

enum AppPhase: Equatable {
    case checking
    case setup(SetupContext)
    case launcher
    case error(AppError)
    case terminating

    struct SetupContext: Equatable {
        var missingPlayCover: Bool
        var missingDiskImage: Bool
        var diskImageMountRequired: Bool
    }
}
