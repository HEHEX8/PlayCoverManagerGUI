import SwiftUI

/// Unified modal presentation system (UnmountOverlayView style)
/// Ensures all modals are centered on screen, independent of scroll position
/// Background tap does NOT dismiss the modal (user must use explicit buttons)
///
/// Usage: .modalPresenter(isPresented: $binding) { content }
///
/// This follows the pattern from UnmountOverlayView which works perfectly:
/// - ZStack with full-screen background overlay
/// - Modal content naturally centered
/// - No scroll dependency, no position() hacks needed
struct ModalPresenterModifier<ModalContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let modalContent: () -> ModalContent
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                // Modal content wrapped in ZStack with full-screen frame
                // Following UnmountOverlayView pattern exactly
                ZStack {
                    // Background dimming overlay
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        // Background tap disabled - no dismissal by clicking outside
                    
                    // Modal content - naturally centered in ZStack
                    // Content should define its own size (minWidth, padding, etc.)
                    // and will be centered automatically by ZStack
                    modalContent()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    /// Present a modal view centered on screen, independent of scroll position
    /// - Parameters:
    ///   - isPresented: Binding to control modal visibility
    ///   - content: The modal view builder
    /// - Returns: Modified view with modal presentation capability
    ///
    /// The modal content will be centered automatically.
    /// Your modal should define its own size constraints (minWidth, padding, etc.)
    /// Do NOT use .frame(maxWidth: .infinity) on the modal content itself.
    func modalPresenter<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(ModalPresenterModifier(isPresented: isPresented, modalContent: content))
    }
}
