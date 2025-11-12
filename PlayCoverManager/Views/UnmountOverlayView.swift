import SwiftUI

/// Overlay view for unmount all flow - shows confirmation, progress, result, and errors
struct UnmountOverlayView: View {
    @Bindable var viewModel: LauncherViewModel
    @State private var windowSize: CGSize = .zero
    
    // Calculate overall UI scale factor based on window size
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 960.0
        let baseHeight: CGFloat = 640.0
        
        let widthScale = size.width / baseWidth
        let heightScale = size.height / baseHeight
        let scale = min(widthScale, heightScale)
        
        // Clamp between 1.0 and 2.0 for reasonable scaling
        return max(1.0, min(2.0, scale))
    }
    
    private var uiScale: CGFloat {
        calculateUIScale(for: windowSize)
    }
    
    var body: some View {
        Group {
            switch viewModel.unmountFlowState {
            case .idle:
                Color.clear
                    .frame(width: 0, height: 0)
                
            case .confirming(let volumeName):
                UnmountConfirmationView(
                    volumeName: volumeName,
                    onConfirm: { viewModel.confirmUnmount() },
                    onCancel: { viewModel.cancelUnmount() },
                    uiScale: uiScale
                )
                .id("confirming")
                
            case .storageChangeConfirming(let mountedCount):
                StorageChangeConfirmationView(
                    mountedCount: mountedCount,
                    onConfirm: { viewModel.confirmStorageLocationChange() },
                    onCancel: { viewModel.cancelStorageLocationChange() },
                    uiScale: uiScale
                )
                .id("storageChangeConfirming")
                
            case .processing(let status):
                UnmountProcessingView(status: status, uiScale: uiScale)
                    .id("processing-\(status)")  // Use status as part of id to prevent animation on status change
                
            case .ejectConfirming(let volumeName):
                UnmountEjectConfirmationView(
                    volumeName: volumeName,
                    onConfirm: { viewModel.confirmEject() },
                    onCancel: { viewModel.cancelEject() },
                    uiScale: uiScale
                )
                .id("ejectConfirming")
                
            case .success(let unmountedCount, let ejectedDrive):
                UnmountSuccessView(
                    unmountedCount: unmountedCount,
                    ejectedDrive: ejectedDrive,
                    onDismiss: { viewModel.completeUnmount() },
                    uiScale: uiScale
                )
                .id("success")
                
            case .error(let title, let message):
                UnmountErrorView(
                    title: title,
                    message: message,
                    onDismiss: { viewModel.dismissUnmountError() },
                    uiScale: uiScale
                )
                .id("error")
                
            case .runningAppsBlocking(let runningAppBundleIDs):
                RunningAppsBlockingView(
                    runningAppBundleIDs: runningAppBundleIDs,
                    onCancel: { viewModel.dismissUnmountError() },
                    onQuitAllAndRetry: {
                        // Retry ALL unmount flow after quitting all apps
                        viewModel.retryUnmountAll()
                    },
                    uiScale: uiScale
                )
                .id("runningAppsBlocking")
                
            case .forceUnmountOffering(let failedCount, let applyToPlayCoverContainer):
                ForceUnmountOfferingView(
                    failedCount: failedCount,
                    onForce: { viewModel.performForceUnmountAll(applyToPlayCoverContainer: applyToPlayCoverContainer) },
                    onCancel: { viewModel.dismissUnmountError() },
                    uiScale: uiScale
                )
                .id("forceOffering")
                
            case .forceEjectOffering(let volumeName, _):
                ForceEjectOfferingView(
                    volumeName: volumeName,
                    onForce: { viewModel.confirmForceEject() },
                    onCancel: { viewModel.cancelForceEject() },
                    uiScale: uiScale
                )
                .id("forceEjectOffering")
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .animation(.none, value: viewModel.unmountFlowState)  // Disable implicit animations
        .uiScale(uiScale)  // Inject UI scale into environment for all overlay child views
    }
}

// MARK: - Storage Change Confirmation View

private struct StorageChangeConfirmationView: View {
    let mountedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var uiScale: CGFloat = 1.0
    @State private var eventMonitor: Any?
    @State private var selectedButton: Int = 1  // 0=cancel, 1=confirm (default)
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.orange)
                
                Text("保存先を変更")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                VStack(spacing: 12 * uiScale) {
                    Text("保存先を変更するには、現在マウント中のすべてのディスクイメージをアンマウントする必要があります。")
                        .font(.system(size: 15 * uiScale))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400 * uiScale)
                    
                    if mountedCount > 0 {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text(LocalizedStringKey("マウント中: \(mountedCount) 個のコンテナ"))
                                .font(.system(size: 15 * uiScale))
                        }
                        .padding(8 * uiScale)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6 * uiScale))
                    }
                    
                    Text("すべてのアプリを終了してからアンマウントを実行してください。")
                        .font(.system(size: 12 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400 * uiScale)
                }
                
                HStack(spacing: 12 * uiScale) {
                    DialogButton(
                        title: "キャンセル",
                        action: onCancel,
                        isPrimary: false,
                        isSelected: selectedButton == 0,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.cancelAction)
                    
                    DialogButton(
                        title: "アンマウントして続行",
                        action: onConfirm,
                        isPrimary: true,
                        isSelected: selectedButton == 1,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53:  // Escape
                self.onCancel()
                return nil
            case 36:  // Return
                if self.selectedButton == 0 { self.onCancel() } else { self.onConfirm() }
                return nil
            case 123:  // Left arrow
                self.selectedButton = 0
                return nil
            case 124:  // Right arrow
                self.selectedButton = 1
                return nil
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardMonitor() {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor); eventMonitor = nil }
    }
}

// MARK: - Custom Button Styles for Unmount Dialogs

/// Modern button style for unmount dialogs with dynamic scaling
private struct DialogButton: View {
    let title: String
    let action: () -> Void
    var isPrimary: Bool = false
    var isSelected: Bool = false
    var uiScale: CGFloat = 1.0
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15 * uiScale, weight: .semibold))
                .foregroundStyle(isPrimary ? .white : .primary)
                .frame(minWidth: 120 * uiScale, minHeight: 36 * uiScale)
                .padding(.horizontal, 20 * uiScale)
                .padding(.vertical, 8 * uiScale)
                .background(buttonBackground)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8 * uiScale)
                            .strokeBorder(isPrimary ? Color.white.opacity(0.5) : Color.accentColor, lineWidth: 2 * uiScale)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                .shadow(
                    color: isPrimary ? Color.accentColor.opacity(0.3) : .black.opacity(0.1),
                    radius: isHovered ? 8 * uiScale : 4 * uiScale,
                    x: 0,
                    y: isHovered ? 4 * uiScale : 2 * uiScale
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
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

/// Warning/destructive button style for force actions
private struct DialogWarningButton: View {
    let title: String
    let action: () -> Void
    var isSelected: Bool = false
    var uiScale: CGFloat = 1.0
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15 * uiScale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 120 * uiScale, minHeight: 36 * uiScale)
                .padding(.horizontal, 20 * uiScale)
                .padding(.vertical, 8 * uiScale)
                .background(
                    LinearGradient(
                        colors: [
                            Color.orange,
                            Color.orange.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8 * uiScale)
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 2 * uiScale)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                .shadow(
                    color: Color.orange.opacity(0.4),
                    radius: isHovered ? 12 * uiScale : 6 * uiScale,
                    x: 0,
                    y: isHovered ? 4 * uiScale : 2 * uiScale
                )
                .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Confirmation View

private struct UnmountConfirmationView: View {
    let volumeName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var uiScale: CGFloat = 1.0
    @State private var eventMonitor: Any?
    @State private var selectedButton: Int = 1  // 0=cancel, 1=confirm (default)
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "eject.circle.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.orange)
                
                Text("すべてアンマウントして終了")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                Text("すべてのディスクイメージをアンマウントし、アプリを終了します。\n\n外部ドライブの場合、ドライブごと安全に取り外せる状態にします。")
                    .font(.system(size: 15 * uiScale))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400 * uiScale)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12 * uiScale) {
                    DialogButton(
                        title: "キャンセル",
                        action: onCancel,
                        isPrimary: false,
                        isSelected: selectedButton == 0,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.cancelAction)
                    
                    DialogButton(
                        title: "アンマウントして終了",
                        action: onConfirm,
                        isPrimary: true,
                        isSelected: selectedButton == 1,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53:  // Escape
                self.onCancel()
                return nil
            case 36:  // Return
                if self.selectedButton == 0 { self.onCancel() } else { self.onConfirm() }
                return nil
            case 123:  // Left arrow
                self.selectedButton = 0
                return nil
            case 124:  // Right arrow
                self.selectedButton = 1
                return nil
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardMonitor() {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor); eventMonitor = nil }
    }
}

// MARK: - Processing View

private struct UnmountProcessingView: View {
    let status: String
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16 * uiScale) {
                ProgressView()
                    .scaleEffect(1.2 * uiScale)
                
                Text(status)
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .padding(32 * uiScale)
            .frame(minWidth: 400 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Eject Confirmation View

private struct UnmountEjectConfirmationView: View {
    let volumeName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var uiScale: CGFloat = 1.0
    @State private var eventMonitor: Any?
    @State private var selectedButton: Int = 1  // 0=cancel, 1=eject (default)
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.blue)
                
                Text("外部ドライブをイジェクトしますか？")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                Text("データの保存先が外部ドライブまたはネットワークドライブ（\(volumeName)）にあります。\n\nドライブをイジェクトしますか？")
                    .font(.system(size: 15 * uiScale))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400 * uiScale)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12 * uiScale) {
                    DialogButton(
                        title: "イジェクトしない",
                        action: onCancel,
                        isPrimary: false,
                        isSelected: selectedButton == 0,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.cancelAction)
                    
                    DialogButton(
                        title: "イジェクト",
                        action: onConfirm,
                        isPrimary: true,
                        isSelected: selectedButton == 1,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.defaultAction)
                }
                
                Text("「イジェクトしない」を選択すると、イジェクトせずにアプリを終了します")
                    .font(.system(size: 12 * uiScale))
                    .foregroundStyle(.tertiary)
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53:  // Escape
                self.onCancel()
                return nil
            case 36:  // Return
                if self.selectedButton == 0 { self.onCancel() } else { self.onConfirm() }
                return nil
            case 123:  // Left arrow
                self.selectedButton = 0
                return nil
            case 124:  // Right arrow
                self.selectedButton = 1
                return nil
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardMonitor() {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor); eventMonitor = nil }
    }
}

// MARK: - Success View

private struct UnmountSuccessView: View {
    let unmountedCount: Int
    let ejectedDrive: String?
    let onDismiss: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: ejectedDrive != nil ? "checkmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.green)
                
                Text(ejectedDrive != nil ? "ドライブの取り外し完了" : "アンマウント完了")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                VStack(spacing: 8 * uiScale) {
                    if let driveName = ejectedDrive {
                        Text("外部ドライブ「\(driveName)」を安全に取り外せる状態にしました。")
                            .font(.system(size: 15 * uiScale))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("ディスクイメージをアンマウントしました。")
                            .font(.system(size: 15 * uiScale))
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("アンマウントされたボリューム: \(unmountedCount) 個")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .padding(.top, 4 * uiScale)
                    
                    if unmountedCount > 1 {
                        Text("（PlayCoverコンテナと関連するアプリコンテナが含まれます）")
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 400 * uiScale)
                
                DialogButton(
                    title: "終了",
                    action: onDismiss,
                    isPrimary: true,
                    isSelected: true,
                    uiScale: uiScale
                )
                .keyboardShortcut(.defaultAction)
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Force Unmount Offering View

private struct ForceUnmountOfferingView: View {
    let failedCount: Int
    let onForce: () -> Void
    let onCancel: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.orange)
                
                Text("アンマウントに失敗しました")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                VStack(spacing: 12 * uiScale) {
                    Text("\(failedCount) 個のコンテナをアンマウントできませんでした。")
                        .font(.system(size: 15 * uiScale))
                        .multilineTextAlignment(.center)
                    
                    Text("システムプロセス（cfprefsdなど）がファイルを使用している可能性があります。")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("強制的にアンマウントを試行しますか？")
                        .font(.system(size: 15 * uiScale, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 8 * uiScale)
                    
                    Text("⚠️ 強制アンマウントはデータ損失のリスクがあります")
                        .font(.system(size: 12 * uiScale))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: 450 * uiScale)
                
                HStack(spacing: 12 * uiScale) {
                    DialogButton(
                        title: "キャンセル",
                        action: onCancel,
                        isPrimary: false,
                        isSelected: false,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.cancelAction)
                    
                    DialogWarningButton(
                        title: "強制アンマウント",
                        action: onForce,
                        isSelected: true,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Force Eject Offering View

private struct ForceEjectOfferingView: View {
    let volumeName: String
    let onForce: () -> Void
    let onCancel: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.orange)
                
                Text("ドライブのイジェクトに失敗")
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                VStack(spacing: 12 * uiScale) {
                    Text("「\(volumeName)」をイジェクトできませんでした。")
                        .font(.system(size: 15 * uiScale))
                        .multilineTextAlignment(.center)
                    
                    Text("ドライブ上のボリュームが使用中の可能性があります。")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("強制的にイジェクトを試行しますか？")
                        .font(.system(size: 15 * uiScale, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 8 * uiScale)
                    
                    Text("⚠️ 強制イジェクトはデータ損失のリスクがあります")
                        .font(.system(size: 12 * uiScale))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: 450 * uiScale)
                
                HStack(spacing: 12 * uiScale) {
                    DialogButton(
                        title: "キャンセル",
                        action: onCancel,
                        isPrimary: false,
                        isSelected: false,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.cancelAction)
                    
                    DialogWarningButton(
                        title: "強制イジェクト",
                        action: onForce,
                        isSelected: true,
                        uiScale: uiScale
                    )
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View

private struct UnmountErrorView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.orange)
                
                Text(title)
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 15 * uiScale))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 450 * uiScale)
                    .foregroundStyle(.secondary)
                
                DialogButton(
                    title: "OK",
                    action: onDismiss,
                    isPrimary: true,
                    isSelected: true,
                    uiScale: uiScale
                )
                .keyboardShortcut(.defaultAction)
            }
            .padding(32 * uiScale)
            .frame(minWidth: 500 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
