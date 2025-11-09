import SwiftUI
import Observation

struct SetupWizardView: View {
    @Bindable var viewModel: SetupWizardViewModel
    let playCoverPaths: PlayCoverPaths?
    @Environment(SettingsStore.self) private var settingsStore
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Step indicator at top
                StepIndicator(currentStep: viewModel.currentStep)
                    .padding(.top, 40)
                    .padding(.horizontal, 60)
                
                Spacer()
                
                // Main content card
                VStack(spacing: 0) {
                    content
                }
                .frame(maxWidth: 600)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if viewModel.currentStep != .installPlayCover {
                        Button {
                            viewModel.back()
                        } label: {
                            Label("戻る", systemImage: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.continueAction(playCoverPaths: playCoverPaths)
                    } label: {
                        Label(buttonTitle, systemImage: buttonIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isBusy || !canContinue)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            }
        }
        .overlay {
            if let error = viewModel.error {
                if error.category == .permissionDenied {
                    KeyboardNavigableAlert(
                        title: error.title,
                        message: error.message,
                        buttons: [
                            AlertButton("OK", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                                viewModel.error = nil
                            },
                            AlertButton("システム設定を開く", style: .borderedProminent, keyEquivalent: .default) {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                    NSWorkspace.shared.open(url)
                                }
                                viewModel.error = nil
                            }
                        ],
                        icon: .warning
                    )
                } else if error.requiresAction {
                    KeyboardNavigableAlert(
                        title: error.title,
                        message: error.message,
                        buttons: [
                            AlertButton("OK", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                                viewModel.error = nil
                            },
                            AlertButton("設定を開く", style: .borderedProminent, keyEquivalent: .default) {
                                viewModel.openSettings()
                                viewModel.error = nil
                            }
                        ],
                        icon: .error
                    )
                } else {
                    KeyboardNavigableAlert(
                        title: error.title,
                        message: error.message,
                        buttons: [
                            AlertButton("OK", role: .cancel, style: .borderedProminent, keyEquivalent: .default) {
                                viewModel.error = nil
                            }
                        ],
                        icon: .error
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .installPlayCover:
            PlayCoverStepView(
                playCoverPaths: playCoverPaths ?? viewModel.detectedPlayCoverPaths,
                openPlayCoverWebsite: viewModel.openPlayCoverWebsite
            )
            
        case .selectStorage:
            StorageStepView(
                storageURL: viewModel.storageURL,
                chooseStorageDirectory: viewModel.chooseStorageDirectory
            )
            
        case .prepareDiskImage:
            DiskImageStepView(
                isBusy: viewModel.isBusy,
                statusMessage: viewModel.statusMessage,
                storageURL: viewModel.storageURL ?? settingsStore.diskImageDirectory
            )
            
        case .finished:
            FinishedStepView(message: viewModel.completionMessage)
        }
    }
    
    private var buttonTitle: String {
        switch viewModel.currentStep {
        case .installPlayCover:
            if playCoverPaths != nil || viewModel.detectedPlayCoverPaths != nil {
                return "次へ"
            } else {
                return "確認"
            }
        case .finished:
            return "完了"
        case .prepareDiskImage:
            return viewModel.isBusy ? "処理中(和点)" : "実行"
        default:
            return "次へ"
        }
    }
    
    private var buttonIcon: String {
        switch viewModel.currentStep {
        case .finished:
            return "checkmark"
        case .prepareDiskImage:
            return viewModel.isBusy ? "ellipsis" : "play.fill"
        default:
            return "chevron.right"
        }
    }
    
    private var canContinue: Bool {
        switch viewModel.currentStep {
        case .selectStorage:
            guard let url = viewModel.storageURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        default:
            return true
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let currentStep: SetupWizardViewModel.Step
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(SetupWizardViewModel.Step.allCases) { step in
                let isActive = step == currentStep
                let isPast = step.rawValue < currentStep.rawValue
                
                HStack(spacing: 8) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color.secondary.opacity(0.3)))
                            .frame(width: 32, height: 32)
                        
                        if isPast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text(step.stepNumber)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isActive ? .white : .secondary)
                        }
                    }
                    
                    // Step title (only for active step)
                    if isActive {
                        Text(step.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                
                // Connector line
                if step != SetupWizardViewModel.Step.allCases.last {
                    Rectangle()
                        .fill(isPast ? Color.green : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
            }
        }
    }
}

// MARK: - PlayCover Detection Step

private struct PlayCoverStepView: View {
    let playCoverPaths: PlayCoverPaths?
    let openPlayCoverWebsite: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon and title
            VStack(spacing: 16) {
                Image(systemName: playCoverPaths != nil ? "checkmark.circle.fill" : "app.dashed")
                    .font(.system(size: 80))
                    .foregroundStyle(playCoverPaths != nil ? .green : .secondary)
                
                Text("PlayCover の検出")
                    .font(.title.bold())
            }
            .padding(.top, 40)
            
            // Status card
            if let paths = playCoverPaths {
                // PlayCover detected
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PlayCover が見つかりました")
                                .font(.headline)
                            Text(paths.applicationURL.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    
                    Text("PlayCover Manager は PlayCover を補完するアプリです。\n\nディスクイメージの管理と IPA インストールを簡単にします。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 450)
                }
            } else {
                // PlayCover not detected
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PlayCover が見つかりません")
                                .font(.headline)
                            Text("PlayCover.app を /Applications にインストールしてください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        openPlayCoverWebsite()
                    } label: {
                        Label("PlayCover サイトを開く", systemImage: "arrow.up.forward.app")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Storage Selection Step

private struct StorageStepView: View {
    let storageURL: URL?
    let chooseStorageDirectory: () -> Void
    
    private var pathExists: Bool {
        guard let url = storageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon and title
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                Text("保存先の選択")
                    .font(.title.bold())
            }
            .padding(.top, 40)
            
            // Content
            VStack(spacing: 20) {
                if let url = storageURL {
                    // Storage selected - validate path existence
                    VStack(spacing: 12) {
                        if pathExists {
                            // Path exists - show green checkmark
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("保存先")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(url.path)
                                        .font(.system(.body, design: .monospaced))
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Path doesn't exist - show warning
                            VStack(spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("パスが存在しません")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(url.path)
                                            .font(.system(.body, design: .monospaced))
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                
                                Text("ドライブが接続されていないか、パスが無効です。\n別の保存先を選択してください。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                } else {
                    // No storage selected
                    Text("ディスクイメージの保存先を選択してください")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Select button
                Button {
                    chooseStorageDirectory()
                } label: {
                    Label(storageURL == nil ? "保存先を選択" : "保存先を変更", systemImage: "folder.badge.gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 160)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                // Info
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("外部ストレージの使用を推奨")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("ディスクイメージは大容量になる場合があります。\n十分な空き容量のあるドライブを選択してください。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Disk Image Preparation Step

private struct DiskImageStepView: View {
    let isBusy: Bool
    let statusMessage: String
    let storageURL: URL?
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon and title
            VStack(spacing: 16) {
                if isBusy {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: "gear.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.purple)
                }
                
                Text(isBusy ? "準備中..." : "ディスクイメージの準備")
                    .font(.title.bold())
            }
            .padding(.top, 40)
            
            // Content
            VStack(spacing: 20) {
                if isBusy {
                    // Processing
                    Text(statusMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    // Ready to execute
                    VStack(spacing: 16) {
                        Text("PlayCover 用のディスクイメージを作成します")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            InfoRow(icon: "doc.fill", title: "ファイル名", value: "io.playcover.PlayCover.asif")
                            
                            if let url = storageURL {
                                InfoRow(icon: "folder.fill", title: "保存先", value: url.path)
                            }
                        }
                        .padding(20)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        
                        Text("実行すると、ディスクイメージの作成とマウントを行います。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Finished Step

private struct FinishedStepView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 32) {
            // Icon and title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                
                Text("セットアップ完了")
                    .font(.title.bold())
            }
            .padding(.top, 40)
            
            // Message
            VStack(spacing: 16) {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("「完了」ボタンをクリックして PlayCover Manager を起動します。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 450)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Views

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            
            Spacer()
        }
    }
}

// MARK: - Extension

extension SetupWizardViewModel.Step {
    var stepNumber: String {
        switch self {
        case .installPlayCover: return "1"
        case .selectStorage: return "2"
        case .prepareDiskImage: return "3"
        case .finished: return "✓"
        }
    }
}
