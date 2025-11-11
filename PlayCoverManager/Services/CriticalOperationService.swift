//
//  CriticalOperationService.swift
//  PlayCoverManager
//
//  Critical operation tracking service
//  Prevents app termination during important operations like installation/uninstallation
//

import Foundation
import Observation

@Observable
@MainActor
final class CriticalOperationService {
    static let shared = CriticalOperationService()
    
    private(set) var isOperationInProgress = false
    private(set) var currentOperationDescription: String?
    
    private init() {}
    
    /// Mark the start of a critical operation
    func beginOperation(_ description: String) {
        isOperationInProgress = true
        currentOperationDescription = description
        Logger.lifecycle("Critical operation started: \(description)")
    }
    
    /// Mark the end of a critical operation
    func endOperation() {
        let description = currentOperationDescription ?? "unknown"
        isOperationInProgress = false
        currentOperationDescription = nil
        Logger.lifecycle("Critical operation ended: \(description)")
    }
}
