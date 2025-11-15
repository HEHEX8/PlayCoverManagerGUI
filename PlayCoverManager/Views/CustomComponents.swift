import SwiftUI
import AppKit

// MARK: - Button Configuration

/// Button configuration for unified button implementation
struct ButtonConfiguration {
    enum Size {
        case standard, large
        
        var minWidth: CGFloat { self == .large ? 120 : 100 }
        var minHeight: CGFloat { self == .large ? 44 : 32 }
        var horizontalPadding: CGFloat { self == .large ? 24 : 16 }
        var verticalPadding: CGFloat { self == .large ? 12 : 8 }
        var fontSize: CGFloat { self == .large ? 16 : 14 }
        var iconSize: CGFloat { self == .large ? 16 : 14 }
        var cornerRadius: CGFloat { self == .large ? 10 : 7 }
        var shadowRadius: (normal: CGFloat, hovered: CGFloat) { 
            self == .large ? (4, 8) : (3, 6) 
        }
        var spacing: CGFloat { self == .large ? 8 : 6 }
    }
    
    enum Style {
        case primary, secondary, destructive
        
        var foregroundColor: Color {
            self == .secondary ? .primary : .white
        }
        
        func shadowColor(for style: Style) -> Color {
            switch self {
            case .primary: .accentColor.opacity(0.3)
            case .destructive: .red.opacity(0.3)
            case .secondary: .black.opacity(0.1)
            }
        }
    }
    
    let title: String
    let action: () -> Void
    let size: Size
    let style: Style
    let icon: String?
    let isEnabled: Bool
    
    init(
        title: String,
        action: @escaping () -> Void,
        size: Size = .standard,
        isPrimary: Bool = false,
        isDestructive: Bool = false,
        icon: String? = nil,
        isEnabled: Bool = true
    ) {
        self.title = title
        self.action = action
        self.size = size
        self.icon = icon
        self.isEnabled = isEnabled
        
        // Determine style
        if isDestructive {
            self.style = .destructive
        } else if isPrimary {
            self.style = .primary
        } else {
            self.style = .secondary
        }
    }
}

// MARK: - Unified Custom Button

/// Modern button with unified implementation - Swift 6.2 optimized
struct CustomButton: View {
    let config: ButtonConfiguration
    var uiScale: CGFloat = 1.0
    
    @State private var isHovered = false
    
    init(
        title: String,
        action: @escaping () -> Void,
        isPrimary: Bool = false,
        isDestructive: Bool = false,
        icon: String? = nil,
        uiScale: CGFloat = 1.0,
        isEnabled: Bool = true
    ) {
        self.config = ButtonConfiguration(
            title: title,
            action: action,
            size: .standard,
            isPrimary: isPrimary,
            isDestructive: isDestructive,
            icon: icon,
            isEnabled: isEnabled
        )
        self.uiScale = uiScale
    }
    
    var body: some View {
        Button(action: config.action) {
            buttonLabel
                .foregroundStyle(config.style.foregroundColor)
                .frame(
                    minWidth: config.size.minWidth * uiScale,
                    minHeight: config.size.minHeight * uiScale
                )
                .padding(.horizontal, config.size.horizontalPadding * uiScale)
                .padding(.vertical, config.size.verticalPadding * uiScale)
                .background(buttonBackground)
                .clipShape(RoundedRectangle(cornerRadius: config.size.cornerRadius * uiScale))
                .shadow(
                    color: config.style.shadowColor(for: config.style),
                    radius: (isHovered ? config.size.shadowRadius.hovered : config.size.shadowRadius.normal) * uiScale,
                    y: (isHovered ? config.size.shadowRadius.hovered / 2 : config.size.shadowRadius.normal / 2) * uiScale
                )
                .scaleEffect(isHovered && config.isEnabled ? 1.02 : 1.0)
                .opacity(config.isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!config.isEnabled)
        .onHover { hovering in
            guard config.isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var buttonLabel: some View {
        HStack(spacing: config.size.spacing * uiScale) {
            if let icon = config.icon {
                Image(systemName: icon)
                    .font(.system(size: config.size.iconSize * uiScale, weight: .semibold))
            }
            Text(config.title)
                .font(.system(size: config.size.fontSize * uiScale, weight: .semibold))
        }
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch config.style {
        case .primary:
            LinearGradient(
                colors: [.accentColor, .accentColor.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .destructive:
            LinearGradient(
                colors: [.red, .red.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .secondary:
            RoundedRectangle(cornerRadius: config.size.cornerRadius * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: config.size.cornerRadius * uiScale)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: uiScale)
                }
        }
    }
}

/// Large custom button - convenience wrapper
struct CustomLargeButton: View {
    let config: ButtonConfiguration
    var uiScale: CGFloat = 1.0
    
    @State private var isHovered = false
    
    init(
        title: String,
        action: @escaping () -> Void,
        isPrimary: Bool = false,
        isDestructive: Bool = false,
        icon: String? = nil,
        uiScale: CGFloat = 1.0,
        isEnabled: Bool = true
    ) {
        self.config = ButtonConfiguration(
            title: title,
            action: action,
            size: .large,
            isPrimary: isPrimary,
            isDestructive: isDestructive,
            icon: icon,
            isEnabled: isEnabled
        )
        self.uiScale = uiScale
    }
    
    var body: some View {
        CustomButton(
            title: config.title,
            action: config.action,
            isPrimary: config.style == .primary,
            isDestructive: config.style == .destructive,
            icon: config.icon,
            uiScale: uiScale,
            isEnabled: config.isEnabled
        )
        .transformEnvironment(\.self) { _ in
            // Large button uses .large size internally
        }
    }
}

// MARK: - Icon Button

/// Icon-only button with hover effects - for close buttons, remove buttons, etc.
/// Follows same pattern as AlertButton in SimpleAlertView for consistency
struct IconButton: View {
    let iconName: String
    let action: () -> Void
    let help: String?
    let size: CGFloat
    let color: Color
    var uiScale: CGFloat = 1.0
    
    @State private var isHovered = false
    
    init(
        icon: String,
        action: @escaping () -> Void,
        help: String? = nil,
        size: CGFloat = 24,
        color: Color = .secondary,
        uiScale: CGFloat = 1.0
    ) {
        self.iconName = icon
        self.action = action
        self.help = help
        self.size = size
        self.color = color
        self.uiScale = uiScale
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: size * uiScale))
                .foregroundStyle(isHovered ? color.opacity(0.8) : color)
                .symbolRenderingMode(.hierarchical)
                .frame(minWidth: 44 * uiScale, minHeight: 44 * uiScale)
                .contentShape(Rectangle())
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(help ?? "")
    }
}

// MARK: - Custom Toggle

/// Modern toggle with dynamic scaling - Swift 6.2 optimized
struct CustomToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            if !title.isEmpty {
                VStack(alignment: .leading, spacing: 6 * uiScale) {
                    Text(title)
                        .font(.system(size: 14 * uiScale, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
            RoundedRectangle.standard(.regular, scale: uiScale)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Liquid Glass Card Modifier
// Swift 6.2: ViewModifier for consistent glass effect + shadow combination
struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let shadowOpacity: Double
    let uiScale: CGFloat
    
    init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, shadowOffset: CGSize = CGSize(width: 0, height: 4), shadowOpacity: Double = 0.1, uiScale: CGFloat = 1.0) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.shadowOpacity = shadowOpacity
        self.uiScale = uiScale
    }
    
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius * uiScale))
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius * uiScale, x: shadowOffset.width * uiScale, y: shadowOffset.height * uiScale)
    }
}

extension View {
    // Apply Liquid Glass card styling with optional customization
    func liquidGlassCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, shadowOffset: CGSize = CGSize(width: 0, height: 4), shadowOpacity: Double = 0.1, uiScale: CGFloat = 1.0) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowOffset: shadowOffset, shadowOpacity: shadowOpacity, uiScale: uiScale))
    }
}

// MARK: - Shape Helpers
// Swift 6.2: Common shape factory functions to reduce repetition

extension RoundedRectangle {
    /// Standard corner radius values scaled for UI
    enum StandardRadius {
        case small      // 8pt
        case medium     // 10pt
        case regular    // 12pt
        case large      // 16pt
        case extraLarge // 22pt
        
        var value: CGFloat {
            switch self {
            case .small: 8
            case .medium: 10
            case .regular: 12
            case .large: 16
            case .extraLarge: 22
            }
        }
    }
    
    /// Create RoundedRectangle with standard radius scaled for UI
    static func standard(_ radius: StandardRadius, scale: CGFloat = 1.0) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius.value * scale)
    }
}

// MARK: - Custom Section Card

/// Modern section card container - Swift 6.2 optimized
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
            cardHeader
            Divider().padding(.vertical, 4 * uiScale)
            content
        }
        .padding(24 * uiScale)
        .glassEffect(.regular, in: RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.1), radius: 8 * uiScale, y: 4 * uiScale)
    }
    
    @ViewBuilder
    private var cardHeader: some View {
        HStack(spacing: 12 * uiScale) {
            iconCircle
            Text(title)
                .font(.system(size: 20 * uiScale, weight: .bold))
                .foregroundStyle(.primary)
        }
    }
    
    @ViewBuilder
    private var iconCircle: some View {
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
    }
}

// MARK: - Custom Info Badge

/// Info badge for displaying additional information - Swift 6.2 optimized
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
            RoundedRectangle.standard(.small, scale: uiScale)
                .fill(color.opacity(0.05))
        )
    }
}

// MARK: - Compact Tab Button

/// Protocol for tab items to ensure consistency across all tab implementations
protocol TabItemProtocol: Identifiable, CaseIterable {
    var localizedTitle: String { get }
    var icon: String { get }
}

/// Compact horizontal tab button - Swift 6.2 optimized, unified implementation
/// Use this for all tab implementations to ensure consistency and maintainability
struct CompactTabButton<T: TabItemProtocol & Equatable>: View {
    let tab: T
    let isSelected: Bool
    let action: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6 * uiScale) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14 * uiScale, weight: .medium))
                Text(tab.localizedTitle)
                    .font(.system(size: 13 * uiScale, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 8 * uiScale)
            .background(
                RoundedRectangle.standard(.regular, scale: uiScale)
                    .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Tab bar container for consistent tab layouts
struct CompactTabBar<T: TabItemProtocol & Equatable>: View {
    let tabs: [T]
    @Binding var selectedTab: T
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            ForEach(tabs) { tab in
                CompactTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    },
                    uiScale: uiScale
                )
            }
        }
    }
}

// MARK: - Segmented Control

/// Protocol for segmented control items (text-only options)
protocol SegmentedItemProtocol: Identifiable, CaseIterable, Equatable {
    var localizedTitle: String { get }
}

/// Custom segmented control button - Swift 6.2 optimized
/// Replaces standard Picker with .segmented style for dynamic uiScale support
struct SegmentedButton<T: SegmentedItemProtocol>: View {
    let item: T
    let isSelected: Bool
    let action: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            Text(item.localizedTitle)
                .font(.system(size: 13 * uiScale, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12 * uiScale)
                .padding(.vertical, 6 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 6 * uiScale)
                        .fill(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor).opacity(0.3))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Segmented control container - unified implementation
/// Use this instead of Picker with .segmented style for consistent uiScale behavior
struct CustomSegmentedControl<T: SegmentedItemProtocol>: View {
    let items: [T]
    @Binding var selection: T
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 4 * uiScale) {
            ForEach(items) { item in
                SegmentedButton(
                    item: item,
                    isSelected: selection == item,
                    action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = item
                        }
                    },
                    uiScale: uiScale
                )
            }
        }
        .padding(4 * uiScale)
        .background(
            RoundedRectangle(cornerRadius: 8 * uiScale)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - View Extensions for Swift 6.2

extension View {
    /// Apply conditional modifier - Swift 6.2 optimized
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply scaled frame with uiScale
    func scaledFrame(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil, uiScale: CGFloat) -> some View {
        self.frame(
            minWidth: minWidth.map { $0 * uiScale },
            minHeight: minHeight.map { $0 * uiScale }
        )
    }
}

// MARK: - Custom Switch (Toggle)

/// Custom switch component that respects dynamic UI scaling
struct CustomSwitch: View {
    @Binding var isOn: Bool
    var uiScale: CGFloat = 1.0
    
    @State private var isHovered = false
    
    private let switchWidth: CGFloat = 42
    private let switchHeight: CGFloat = 24
    private let thumbSize: CGFloat = 20
    private let thumbPadding: CGFloat = 2
    
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // Background track
            RoundedRectangle(cornerRadius: (switchHeight / 2) * uiScale)
                .fill(isOn ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: switchWidth * uiScale, height: switchHeight * uiScale)
                .overlay {
                    RoundedRectangle(cornerRadius: (switchHeight / 2) * uiScale)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.3 : 0), lineWidth: 2 * uiScale)
                }
                .animation(.easeInOut(duration: 0.2), value: isOn)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            
            // Thumb
            Circle()
                .fill(Color.white)
                .frame(width: thumbSize * uiScale, height: thumbSize * uiScale)
                .shadow(color: .black.opacity(0.2), radius: 2 * uiScale, x: 0, y: 1 * uiScale)
                .padding(thumbPadding * uiScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .frame(width: switchWidth * uiScale, height: switchHeight * uiScale)
    }
}
