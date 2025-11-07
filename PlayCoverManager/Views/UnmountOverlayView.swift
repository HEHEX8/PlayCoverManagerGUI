import SwiftUI

/// Overlay view for unmount all flow - shows confirmation, progress, result, and errors
struct UnmountOverlayView: View {
    @Bindable var viewModel: LauncherViewModel
    
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
                    onCancel: { viewModel.cancelUnmount() }
                )
                .id("confirming")
                
            case .storageChangeConfirming(let mountedCount):
                StorageChangeConfirmationView(
                    mountedCount: mountedCount,
                    onConfirm: { viewModel.confirmStorageLocationChange() },
                    onCancel: { viewModel.cancelStorageLocationChange() }
                )
                .id("storageChangeConfirming")
                
            case .processing(let status):
                UnmountProcessingView(status: status)
                    .id("processing-\(status)")  // Use status as part of id to prevent animation on status change
                
            case .ejectConfirming(let volumeName):
                UnmountEjectConfirmationView(
                    volumeName: volumeName,
                    onConfirm: { viewModel.confirmEject() },
                    onCancel: { viewModel.cancelEject() }
                )
                .id("ejectConfirming")
                
            case .success(let unmountedCount, let ejectedDrive):
                UnmountSuccessView(
                    unmountedCount: unmountedCount,
                    ejectedDrive: ejectedDrive,
                    onDismiss: { viewModel.completeUnmount() }
                )
                .id("success")
                
            case .error(let title, let message):
                UnmountErrorView(
                    title: title,
                    message: message,
                    onDismiss: { viewModel.dismissUnmountError() }
                )
                .id("error")
                
            case .forceUnmountOffering(let failedCount, let applyToPlayCoverContainer):
                ForceUnmountOfferingView(
                    failedCount: failedCount,
                    onForce: { viewModel.performForceUnmountAll(applyToPlayCoverContainer: applyToPlayCoverContainer) },
                    onCancel: { viewModel.dismissUnmountError() }
                )
                .id("forceOffering")
            }
        }
        .animation(.none, value: viewModel.unmountFlowState)  // Disable implicit animations
    }
}

// MARK: - Storage Change Confirmation View

private struct StorageChangeConfirmationView: View {
    let mountedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text("保存先を変更")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Text("保存先を変更するには、現在マウント中のすべてのディスクイメージをアンマウントする必要があります。")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                if mountedCount > 0 {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("マウント中: \(mountedCount) 個のコンテナ")
                            .font(.callout)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                
                Text("すべてのアプリを終了してからアンマウントを実行してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            HStack(spacing: 12) {
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("アンマウントして続行", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:  // Escape
                onCancel()
                return nil
            case 36:  // Return
                onConfirm()
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

// MARK: - Confirmation View

private struct UnmountConfirmationView: View {
    let volumeName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "eject.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text("すべてアンマウントして終了")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("すべてのディスクイメージをアンマウントし、アプリを終了します。\n\n外部ドライブの場合、ドライブごと安全に取り外せる状態にします。")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("アンマウントして終了", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:  // Escape
                onCancel()
                return nil
            case 36:  // Return
                onConfirm()
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

// MARK: - Processing View

private struct UnmountProcessingView: View {
    let status: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(status)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 400)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
    }
}

// MARK: - Eject Confirmation View

private struct UnmountEjectConfirmationView: View {
    let volumeName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("外部ドライブをイジェクトしますか？")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("データの保存先が外部ドライブまたはネットワークドライブ（\(volumeName)）にあります。\n\nドライブをイジェクトしますか？")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button("イジェクトしない") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("イジェクト") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            
            Text("「イジェクトしない」を選択すると、イジェクトせずにアプリを終了します")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:  // Escape
                onCancel()
                return nil
            case 36:  // Return
                onConfirm()
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

// MARK: - Success View

private struct UnmountSuccessView: View {
    let unmountedCount: Int
    let ejectedDrive: String?
    let onDismiss: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: ejectedDrive != nil ? "checkmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            
            Text(ejectedDrive != nil ? "ドライブの取り外し完了" : "アンマウント完了")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let driveName = ejectedDrive {
                    Text("外部ドライブ「\(driveName)」を安全に取り外せる状態にしました。")
                        .multilineTextAlignment(.center)
                } else {
                    Text("ディスクイメージをアンマウントしました。")
                        .multilineTextAlignment(.center)
                }
                
                Text("アンマウントされたボリューム: \(unmountedCount) 個")
                    .font(.headline)
                    .padding(.top, 4)
                
                if unmountedCount > 1 {
                    Text("（PlayCoverコンテナと関連するアプリコンテナが含まれます）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 400)
            
            Button("終了", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53, 36:  // Escape or Return
                onDismiss()
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

// MARK: - Force Unmount Offering View

private struct ForceUnmountOfferingView: View {
    let failedCount: Int
    let onForce: () -> Void
    let onCancel: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text("アンマウントに失敗しました")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Text("\(failedCount) 個のコンテナをアンマウントできませんでした。")
                    .multilineTextAlignment(.center)
                
                Text("システムプロセス（cfprefsdなど）がファイルを使用している可能性があります。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("強制的にアンマウントを試行しますか？")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                
                Text("⚠️ 強制アンマウントはデータ損失のリスクがあります")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: 450)
            
            HStack(spacing: 12) {
                Button("キャンセル", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("強制アンマウント") {
                    onForce()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53:  // Escape
                onCancel()
                return nil
            case 36:  // Return
                onForce()
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

}

// MARK: - Error View

private struct UnmountErrorView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    @State private var eventMonitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 450)
                .foregroundStyle(.secondary)
            
            Button("OK", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(minWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20)
        .focusable()
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            cleanupKeyboardMonitor()
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53, 36:  // Escape or Return
                onDismiss()
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

}
