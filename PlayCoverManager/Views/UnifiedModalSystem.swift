import SwiftUI

/// Unified Modal System - Based on UnmountOverlayView's perfect pattern
/// All modals, alerts, sheets must use this system for consistent behavior:
/// - Always centered on screen
/// - Independent of scroll position
/// - No background tap dismissal
/// - Consistent animations
///
/// Usage:
/// ```swift
/// @State private var showModal = false
///
/// var body: some View {
///     YourView()
///         .unifiedModal(isPresented: $showModal) {
///             YourModalContent()
///                 .padding(32)
///                 .frame(minWidth: 500)
///                 .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
///         }
/// }
/// ```

// MARK: - Unified Modal Modifier

extension View {
    /// Present a modal using UnmountOverlayView's proven pattern
    /// Modal content will be centered on screen, independent of scroll position
    func unifiedModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                // Full-screen ZStack container (UnmountOverlayView pattern)
                ZStack {
                    // Background dimming overlay
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        // Background tap disabled - no dismissal
                    
                    // Modal content - naturally centered by ZStack
                    content()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented.wrappedValue)
    }
}

// MARK: - Standard Modal Container

/// Pre-built modal container following UnmountOverlayView styling
/// Use this for consistent appearance across all modals
struct StandardModalContainer<Content: View>: View {
    let content: Content
    var minWidth: CGFloat = 500
    var uiScale: CGFloat = 1.0
    
    init(
        minWidth: CGFloat = 500,
        uiScale: CGFloat = 1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.minWidth = minWidth
        self.uiScale = uiScale
    }
    
    var body: some View {
        content
            .padding(32 * uiScale)
            .frame(minWidth: minWidth * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
    }
}

// MARK: - Standard Alert (Simplified KeyboardNavigableAlert)

/// Standard alert dialog following UnmountOverlayView pattern
struct StandardAlert: View {
    let title: String
    let message: String
    let icon: AlertIcon?
    let buttons: [AlertButton]
    var uiScale: CGFloat = 1.0
    
    @State private var selectedButtonIndex: Int
    @State private var eventMonitor: Any?
    
    init(
        title: String,
        message: String,
        icon: AlertIcon? = nil,
        buttons: [AlertButton],
        uiScale: CGFloat = 1.0,
        defaultButtonIndex: Int? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.buttons = buttons
        self.uiScale = uiScale
        _selectedButtonIndex = State(initialValue: defaultButtonIndex ?? max(0, buttons.count - 1))
    }
    
    var body: some View {
        // UnmountOverlayView pattern: ZStack with full-screen frame
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                // Background tap disabled
            
            // Alert content
            VStack(spacing: 20 * uiScale) {
                // Icon (optional)
                if let icon = icon {
                    Image(systemName: icon.systemName)
                        .font(.system(size: 64 * uiScale))
                        .foregroundStyle(icon.color)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                    .multilineTextAlignment(.center)
                
                // Message
                Text(message)
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400 * uiScale)
                
                // Buttons
                HStack(spacing: 12 * uiScale) {
                    ForEach(Array(buttons.enumerated()), id: \.offset) { index, button in
                        makeButton(for: button, at: index)
                    }
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 400 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    @ViewBuilder
    private func makeButton(for button: AlertButton, at index: Int) -> some View {
        let isSelected = selectedButtonIndex == index
        let isPrimary = button.style == .borderedProminent || button.style == .destructive
        let isDestructive = button.style == .destructive
        
        Button(button.title) {
            button.action()
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPrimary ? .white : .primary)
        .padding(.horizontal, 20 * uiScale)
        .padding(.vertical, 8 * uiScale)
        .frame(minWidth: 120 * uiScale, minHeight: 36 * uiScale)
        .background(buttonBackground(isPrimary: isPrimary, isDestructive: isDestructive))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8 * uiScale)
                    .strokeBorder(isPrimary ? Color.white.opacity(0.5) : Color.accentColor, lineWidth: 2 * uiScale)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
        .applyKeyboardShortcut(button.keyEquivalent)
    }
    
    @ViewBuilder
    private func buttonBackground(isPrimary: Bool, isDestructive: Bool) -> some View {
        if isPrimary {
            LinearGradient(
                colors: [
                    isDestructive ? Color.red : Color.accentColor,
                    isDestructive ? Color.red.opacity(0.9) : Color.accentColor.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            RoundedRectangle(cornerRadius: 8 * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8 * uiScale)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1 * uiScale)
                }
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53:  // Escape - trigger cancel button
                if let cancelIndex = buttons.firstIndex(where: { $0.role == .cancel }) {
                    buttons[cancelIndex].action()
                    return nil
                }
                return event
                
            case 36:  // Return - trigger selected button
                buttons[self.selectedButtonIndex].action()
                return nil
                
            case 123:  // Left arrow
                if self.selectedButtonIndex > 0 {
                    self.selectedButtonIndex -= 1
                }
                return nil
                
            case 124:  // Right arrow
                if self.selectedButtonIndex < buttons.count - 1 {
                    self.selectedButtonIndex += 1
                }
                return nil
                
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - View Extension for Standard Alert

extension View {
    func standardAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        icon: AlertIcon? = nil,
        buttons: [AlertButton],
        uiScale: CGFloat = 1.0,
        defaultButtonIndex: Int? = nil
    ) -> some View {
        ZStack {
            self
            
            if isPresented.wrappedValue {
                StandardAlert(
                    title: title,
                    message: message,
                    icon: icon,
                    buttons: buttons,
                    uiScale: uiScale,
                    defaultButtonIndex: defaultButtonIndex
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented.wrappedValue)
    }
}

// MARK: - Button Helper Extension

private extension View {
    @ViewBuilder
    func applyKeyboardShortcut(_ keyEquivalent: AlertButton.KeyEquivalent) -> some View {
        switch keyEquivalent {
        case .none:
            self
        case .default:
            self.keyboardShortcut(.defaultAction)
        case .cancel:
            self.keyboardShortcut(.cancelAction)
        }
    }
}
