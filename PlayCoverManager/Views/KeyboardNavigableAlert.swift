import SwiftUI
import AppKit

/// Reusable keyboard-navigable alert component
/// Supports arrow key navigation, Enter to confirm, Escape to cancel
struct KeyboardNavigableAlert: View {
    let title: String
    let message: String
    let buttons: [AlertButton]
    let icon: AlertIcon?
    
    @State private var selectedButtonIndex: Int
    @State private var eventMonitor: Any?
    @Environment(\.uiScale) var uiScale
    
    init(
        title: String,
        message: String,
        buttons: [AlertButton],
        icon: AlertIcon? = nil,
        defaultButtonIndex: Int? = nil
    ) {
        self.title = title
        self.message = message
        self.buttons = buttons
        self.icon = icon
        
        // Default to last button (usually the primary action)
        _selectedButtonIndex = State(initialValue: defaultButtonIndex ?? max(0, buttons.count - 1))
    }
    
    var body: some View {
        VStack(spacing: 20 * uiScale) {
            // Icon (optional)
            if let icon = icon {
                Image(systemName: icon.systemName)
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(icon.color)
            }
            
            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(.body)
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
        .shadow(color: .black.opacity(0.3), radius: 20 * uiScale)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            // Track alert size for animations (macOS 26 API)
        }
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    @ViewBuilder
    private func makeButton(for button: AlertButton, at index: Int) -> some View {
        let isSelected = selectedButtonIndex == index
        let tintColor: Color = button.style == .destructive ? .red : (isSelected ? .blue : .gray)
        
        if button.style == .borderedProminent || button.style == .destructive {
            Button(button.title) {
                button.action()
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6 * uiScale)
                        .strokeBorder(Color.blue, lineWidth: 2 * uiScale)
                }
            }
            .applyKeyboardShortcut(button.keyEquivalent)
        } else {
            Button(button.title) {
                button.action()
            }
            .buttonStyle(.bordered)
            .tint(tintColor)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6 * uiScale)
                        .strokeBorder(Color.blue, lineWidth: 2 * uiScale)
                }
            }
            .applyKeyboardShortcut(button.keyEquivalent)
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

// MARK: - Alert Button

struct AlertButton {
    let title: String
    let role: ButtonRole
    let style: ButtonStyle
    let keyEquivalent: KeyEquivalent
    let action: () -> Void
    
    init(
        _ title: String,
        role: ButtonRole = .normal,
        style: ButtonStyle = .bordered,
        keyEquivalent: KeyEquivalent = .none,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.style = style
        self.keyEquivalent = keyEquivalent
        self.action = action
    }
    
    enum ButtonRole {
        case normal
        case cancel
        case destructive
    }
    
    enum ButtonStyle {
        case bordered
        case borderedProminent
        case destructive
    }
    
    enum KeyEquivalent {
        case none
        case `default`
        case cancel
    }
}

// MARK: - Alert Icon

struct AlertIcon {
    let systemName: String
    let color: Color
    
    static let info = AlertIcon(systemName: "info.circle.fill", color: .blue)
    static let warning = AlertIcon(systemName: "exclamationmark.triangle.fill", color: .orange)
    static let error = AlertIcon(systemName: "xmark.circle.fill", color: .red)
    static let success = AlertIcon(systemName: "checkmark.circle.fill", color: .green)
    static let question = AlertIcon(systemName: "questionmark.circle.fill", color: .blue)
}

// MARK: - View Extension for Easy Usage

extension View {
    func keyboardNavigableAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        buttons: [AlertButton],
        icon: AlertIcon? = nil,
        defaultButtonIndex: Int? = nil
    ) -> some View {
        self.modalPresenter(isPresented: isPresented) {
            KeyboardNavigableAlert(
                title: title,
                message: message,
                buttons: buttons,
                icon: icon,
                defaultButtonIndex: defaultButtonIndex
            )
        }
    }
}

// MARK: - Helper Extension

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
