import SwiftUI

/// Simple alert view following UnmountOverlayView pattern
/// All alerts displayed at QuickLauncherView.overlay() level for consistent positioning
struct SimpleAlertView: View {
    let title: String
    let message: String
    let icon: String
    let iconColor: Color
    let buttons: [SimpleAlertButton]
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        // UnmountOverlayView pattern: full-screen ZStack with centered content
        ZStack {
            // Background overlay - tap to dismiss if cancel button exists
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss on background tap if cancel button exists
                    if let cancelButton = buttons.first(where: { $0.isCancel }) {
                        cancelButton.action()
                    }
                }
            
            // Alert content
            VStack(spacing: 20 * uiScale) {
                Image(systemName: icon)
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400 * uiScale)
                
                HStack(spacing: 12 * uiScale) {
                    ForEach(buttons.indices, id: \.self) { index in
                        let button = buttons[index]
                        AlertButton(button: button, uiScale: uiScale)
                    }
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 400 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func buttonBackground(for button: SimpleAlertButton) -> some View {
        if button.isPrimary {
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.9)],
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
}

struct SimpleAlertButton {
    let title: String
    let isPrimary: Bool
    let isDefault: Bool
    let isCancel: Bool
    let action: () -> Void
    
    init(_ title: String, isPrimary: Bool = false, isDefault: Bool = false, isCancel: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.isDefault = isDefault
        self.isCancel = isCancel
        self.action = action
    }
}

// MARK: - Alert Button with Hover Effect
private struct AlertButton: View {
    let button: SimpleAlertButton
    let uiScale: CGFloat
    @State private var isHovered = false
    
    var body: some View {
        Button(action: button.action) {
            Text(button.title)
                .font(.system(size: 15 * uiScale, weight: .medium))
                .foregroundStyle(button.isPrimary ? .white : .primary)
                .frame(minWidth: 120 * uiScale, minHeight: 44 * uiScale)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .keyboardShortcut(button.isDefault ? .defaultAction : (button.isCancel ? .cancelAction : .init(.end)))
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        if button.isPrimary {
            ZStack {
                if isHovered {
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8 * uiScale)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8 * uiScale)
                            .strokeBorder(Color.primary.opacity(isHovered ? 0.4 : 0.2), lineWidth: 1 * uiScale)
                    }
                
                if isHovered {
                    RoundedRectangle(cornerRadius: 8 * uiScale)
                        .fill(Color.primary.opacity(0.05))
                }
            }
        }
    }
}
