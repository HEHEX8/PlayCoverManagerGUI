//
//  UIScaleEnvironment.swift
//  PlayCoverManager
//
//  Created by AI Assistant on 2025-11-12.
//  Global UI Scale Environment for responsive scaling across entire app
//

import SwiftUI

/// Environment key for global UI scale factor
private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    /// Global UI scale factor that propagates to all child views
    /// 
    /// Usage:
    /// ```swift
    /// @Environment(\.uiScale) var uiScale
    /// 
    /// Text("Hello")
    ///     .font(.system(size: 16 * uiScale))
    /// ```
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

/// View modifier to inject UI scale into environment
struct UIScaleModifier: ViewModifier {
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .environment(\.uiScale, scale)
    }
}

extension View {
    /// Inject UI scale factor into the environment tree
    /// 
    /// This propagates the scale to all child views automatically
    /// 
    /// - Parameter scale: The scale factor (typically 1.0 to 2.0)
    /// - Returns: View with scale injected into environment
    func uiScale(_ scale: CGFloat) -> some View {
        modifier(UIScaleModifier(scale: scale))
    }
}
