import SwiftUI
import AppKit

// MARK: - Custom Button Styles

/// Modern button style with dynamic scaling
struct CustomButton: View {
    let title: String
    let action: () -> Void
    var isPrimary: Bool = false
    var isDestructive: Bool = false
    var icon: String? = nil
    var uiScale: CGFloat = 1.0
    var isEnabled: Bool = true
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6 * uiScale) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14 * uiScale, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14 * uiScale, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .frame(minWidth: 100 * uiScale, minHeight: 32 * uiScale)
            .padding(.horizontal, 16 * uiScale)
            .padding(.vertical, 8 * uiScale)
            .background(buttonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7 * uiScale))
            .shadow(
                color: shadowColor,
                radius: isHovered ? 6 * uiScale : 3 * uiScale,
                x: 0,
                y: isHovered ? 3 * uiScale : 1.5 * uiScale
            )
            .scaleEffect(isHovered && isEnabled ? 1.02 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            if isEnabled {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        if isPrimary {
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isDestructive {
            LinearGradient(
                colors: [
                    Color.red,
                    Color.red.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            RoundedRectangle(cornerRadius: 7 * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 7 * uiScale)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1 * uiScale)
                }
        }
    }
    
    private var foregroundColor: Color {
        if isPrimary || isDestructive {
            return .white
        }
        return .primary
    }
    
    private var shadowColor: Color {
        if isPrimary {
            return Color.accentColor.opacity(0.3)
        } else if isDestructive {
            return Color.red.opacity(0.3)
        }
        return .black.opacity(0.1)
    }
}

/// Large custom button for prominent actions
struct CustomLargeButton: View {
    let title: String
    let action: () -> Void
    var isPrimary: Bool = false
    var icon: String? = nil
    var uiScale: CGFloat = 1.0
    var isEnabled: Bool = true
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * uiScale) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16 * uiScale, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16 * uiScale, weight: .semibold))
            }
            .foregroundStyle(isPrimary ? .white : .primary)
            .frame(minWidth: 120 * uiScale, minHeight: 44 * uiScale)
            .padding(.horizontal, 24 * uiScale)
            .padding(.vertical, 12 * uiScale)
            .background(largeButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10 * uiScale))
            .shadow(
                color: isPrimary ? Color.accentColor.opacity(0.3) : .black.opacity(0.1),
                radius: isHovered ? 8 * uiScale : 4 * uiScale,
                x: 0,
                y: isHovered ? 4 * uiScale : 2 * uiScale
            )
            .scaleEffect(isHovered && isEnabled ? 1.02 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            if isEnabled {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }
    
    @ViewBuilder
    private var largeButtonBackground: some View {
        if isPrimary {
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            RoundedRectangle(cornerRadius: 10 * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 10 * uiScale)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1 * uiScale)
                }
        }
    }
}

// MARK: - Custom Picker

/// Modern picker with dynamic scaling
struct CustomPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    let content: Content
    var uiScale: CGFloat = 1.0
    
    @State private var isExpanded = false
    
    init(
        _ title: String,
        selection: Binding<SelectionValue>,
        uiScale: CGFloat = 1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._selection = selection
        self.uiScale = uiScale
        self.content = content()
    }
    
    var body: some View {
        Menu {
            content
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 14 * uiScale))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12 * uiScale))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 8 * uiScale)
            .background(
                RoundedRectangle(cornerRadius: 8 * uiScale)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8 * uiScale)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1 * uiScale)
            }
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Custom Toggle

/// Modern toggle with dynamic scaling
struct CustomToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            VStack(alignment: .leading, spacing: 6 * uiScale) {
                Text(title)
                    .font(.system(size: 14 * uiScale, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.large)
        }
        .padding(16 * uiScale)
        .background(
            RoundedRectangle(cornerRadius: 12 * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Custom Section Card

/// Modern section card container
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconGradient: [Color]
    let content: Content
    var uiScale: CGFloat = 1.0
    
    init(
        title: String,
        icon: String,
        iconGradient: [Color],
        uiScale: CGFloat = 1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconGradient = iconGradient
        self.uiScale = uiScale
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16 * uiScale) {
            // Header with icon gradient
            HStack(spacing: 12 * uiScale) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradient.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40 * uiScale, height: 40 * uiScale)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18 * uiScale, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                
                Text(title)
                    .font(.system(size: 20 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
            }
            
            Divider()
                .padding(.vertical, 4 * uiScale)
            
            content
        }
        .padding(24 * uiScale)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
        .shadow(color: .black.opacity(0.1), radius: 8 * uiScale, x: 0, y: 4 * uiScale)
    }
}

// MARK: - Custom Info Badge

/// Info badge for displaying additional information
struct InfoBadge: View {
    let text: String
    let color: Color
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 6 * uiScale) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12 * uiScale))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12 * uiScale)
        .background(
            RoundedRectangle(cornerRadius: 8 * uiScale)
                .fill(color.opacity(0.05))
        )
    }
}
