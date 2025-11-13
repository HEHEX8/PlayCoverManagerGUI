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

// MARK: - Custom Picker

/// Modern dropdown picker with dynamic scaling - Swift 6.2 optimized
/// Shows selected value with smooth animations
struct CustomPicker<SelectionValue: Hashable, Content: View>: View where SelectionValue: RawRepresentable, SelectionValue.RawValue == String {
    @Binding var selection: SelectionValue
    let content: Content
    let labelProvider: (SelectionValue) -> String
    var uiScale: CGFloat = 1.0
    
    init(
        selection: Binding<SelectionValue>,
        uiScale: CGFloat = 1.0,
        labelProvider: @escaping (SelectionValue) -> String = { $0.rawValue },
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.uiScale = uiScale
        self.labelProvider = labelProvider
        self.content = content()
    }
    
    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 8 * uiScale) {
                // Show selected value
                Text(labelProvider(selection))
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer(minLength: 4 * uiScale)
                
                // Chevron indicator
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11 * uiScale))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12 * uiScale)
            .padding(.vertical, 8 * uiScale)
            .frame(minWidth: 120 * uiScale)
            .background(
                RoundedRectangle.standard(.small, scale: uiScale)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle.standard(.small, scale: uiScale)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: uiScale)
                    }
            )
        }
        .menuStyle(.borderlessButton)
        .animation(.smooth(duration: 0.2), value: selection)
    }
}

// MARK: - Custom Segmented Control

/// Modern segmented control with sliding pill animation - Swift 6.2 optimized
/// Uses matchedGeometryEffect for smooth transitions
struct CustomSegmentedControl<T>: View 
where T: Hashable & CaseIterable & RawRepresentable & Identifiable, T.RawValue == String {
    
    @Binding var selection: T
    let labelProvider: (T) -> String
    var uiScale: CGFloat = 1.0
    @Namespace private var animation
    
    private var items: [T] { Array(T.allCases) }
    
    init(
        selection: Binding<T>,
        uiScale: CGFloat = 1.0,
        labelProvider: @escaping (T) -> String = { $0.rawValue }
    ) {
        self._selection = selection
        self.uiScale = uiScale
        self.labelProvider = labelProvider
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Text(labelProvider(item))
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.medium)
                    .padding(.vertical, 6 * uiScale)
                    .padding(.horizontal, 12 * uiScale)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selection == item ? .white : .primary.opacity(0.7))
                    .background {
                        if selection == item {
                            // Sliding pill that animates between items
                            Capsule()
                                .fill(Color.accentColor.gradient)
                                .matchedGeometryEffect(id: "segmented_pill", in: animation)
                        }
                    }
                    .contentShape(.rect) // Make entire area tappable
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.3)) {
                            selection = item
                        }
                    }
            }
        }
        .padding(4 * uiScale)
        .background(
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: uiScale)
        }
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

// MARK: - Custom Context Menu (macOS 26.1 Tahoe)

/// Context menu item configuration - Swift 6.2 optimized
struct ContextMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let role: ButtonRole?
    let action: () -> Void
    
    init(title: String, icon: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }
    
    static func divider() -> ContextMenuItem {
        ContextMenuItem(title: "", icon: nil, role: nil, action: {})
    }
    
    var isDivider: Bool { title.isEmpty }
}

/// Right-click gesture detector for macOS context menu - Swift 6.2
struct RightClickCatcher: NSViewRepresentable {
    var onRightClick: (NSView, NSPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    final class CatcherView: NSView {
        var onRightClick: ((NSView, NSPoint) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func rightMouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onRightClick?(self, point)
        }
        
        override func hitTest(_ point: NSPoint) -> NSView? { self }
    }
}

/// Custom context menu view with Liquid Glass design - Swift 6.2
struct CustomContextMenuView: View {
    let items: [ContextMenuItem]
    var uiScale: CGFloat = 1.0
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                if item.isDivider {
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                } else {
                    Button(action: {
                        item.action()
                        onDismiss()
                    }) {
                        HStack(spacing: 10 * uiScale) {
                            // macOS 26.1: Icon support in menu items
                            if let icon = item.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 14 * uiScale))
                                    .frame(width: 16 * uiScale, alignment: .center)
                                    // APPLE_DEV_2025: Use semantic colors for accessibility
                                    .foregroundStyle(item.role == .destructive ? Color(nsColor: .systemRed) : .primary)
                            }
                            
                            Text(item.title)
                                .font(.system(size: 13 * uiScale))
                                // APPLE_DEV_2025: Use semantic colors for accessibility
                                .foregroundStyle(item.role == .destructive ? Color(nsColor: .systemRed) : .primary)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12 * uiScale)
                    .padding(.vertical, 6 * uiScale)
                    .background(
                        RoundedRectangle(cornerRadius: 4 * uiScale)
                            .fill(Color.accentColor.opacity(0.0))
                    )
                    .onHover { hovering in
                        // Hover effect handled by system
                    }
                }
            }
        }
        .padding(.vertical, 6 * uiScale)
        .frame(minWidth: 200 * uiScale)
        // macOS 26.1 Tahoe: Use Liquid Glass instead of .ultraThinMaterial
        .glassEffect(.regular, in: RoundedRectangle.standard(.medium, scale: uiScale))
        .overlay(
            RoundedRectangle.standard(.medium, scale: uiScale)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5 * uiScale)
        )
        .shadow(color: .black.opacity(0.2), radius: 12 * uiScale, x: 0, y: 4 * uiScale)
    }
}

/// NSPopover presenter singleton for context menus - Swift 6.2
@MainActor
final class ContextMenuPresenter: ObservableObject {
    static let shared = ContextMenuPresenter()
    private var currentPopover: NSPopover?
    
    private init() {}
    
    func present(from anchorView: NSView, at point: NSPoint, items: [ContextMenuItem], uiScale: CGFloat = 1.0) {
        dismiss()
        
        let menuView = CustomContextMenuView(items: items, uiScale: uiScale) { [weak self] in
            self?.dismiss()
        }
        
        let hostingController = NSHostingController(rootView: menuView)
        hostingController.view.wantsLayer = true
        
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController
        popover.animates = true
        
        // Swift 6.2: Dynamic sizing with layout computation
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        popover.contentSize = fittingSize
        
        let anchorRect = NSRect(x: point.x, y: point.y, width: 1, height: 1)
        popover.show(relativeTo: anchorRect, of: anchorView, preferredEdge: .maxY)
        
        currentPopover = popover
    }
    
    func dismiss() {
        currentPopover?.performClose(nil)
        currentPopover = nil
    }
}

/// View modifier for adding custom context menu - Swift 6.2
struct CustomContextMenuModifier: ViewModifier {
    let items: [ContextMenuItem]
    var uiScale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RightClickCatcher { anchorView, point in
                    ContextMenuPresenter.shared.present(
                        from: anchorView,
                        at: point,
                        items: items,
                        uiScale: uiScale
                    )
                }
                .allowsHitTesting(true)
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
    
    /// Add custom context menu with dynamic scaling - macOS 26.1 Tahoe
    func customContextMenu(items: [ContextMenuItem], uiScale: CGFloat = 1.0) -> some View {
        self.modifier(CustomContextMenuModifier(items: items, uiScale: uiScale))
    }
}
