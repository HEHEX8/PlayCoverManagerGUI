import SwiftUI
import Observation

struct SetupWizardView: View {
    @Bindable var viewModel: SetupWizardViewModel
    let playCoverPaths: PlayCoverPaths?
    @Environment(SettingsStore.self) private var settingsStore
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
    
    // Scaled dimensions
    private var topPadding: CGFloat { 40 * uiScale }
    private var horizontalPadding: CGFloat { 60 * uiScale }
    private var bottomPadding: CGFloat { 40 * uiScale }
    private var cardMaxWidth: CGFloat { 600 * uiScale }
    private var cardCornerRadius: CGFloat { 20 * uiScale }
    private var cardShadowRadius: CGFloat { 8 * uiScale }
    private var buttonSpacing: CGFloat { 16 * uiScale }
    private var buttonFontSize: CGFloat { 15 * uiScale }
    private var buttonMinWidth: CGFloat { 100 * uiScale }
    private var buttonMinWidthLarge: CGFloat { 120 * uiScale }
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Step indicator at top
                StepIndicator(currentStep: viewModel.currentStep, uiScale: uiScale)
                    .padding(.top, topPadding)
                    .padding(.horizontal, horizontalPadding)
                
                Spacer()
                
                // Main content card with rich Liquid Glass
                VStack(spacing: 0) {
                    content
                }
                .frame(maxWidth: cardMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .shadow(color: .black.opacity(0.1), radius: cardShadowRadius, x: 0, y: 4 * uiScale)
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: buttonSpacing) {
                    if viewModel.currentStep != .installPlayCover {
                        CustomButton(
                            title: "戻る",
                            action: { viewModel.back() },
                            isPrimary: false,
                            icon: "chevron.left",
                            uiScale: uiScale
                        )
                        .frame(minWidth: buttonMinWidth)
                    }
                    
                    Spacer()
                    
                    CustomButton(
                        title: buttonTitle,
                        action: { viewModel.continueAction(playCoverPaths: playCoverPaths) },
                        isPrimary: true,
                        icon: buttonIcon,
                        uiScale: uiScale,
                        isEnabled: !viewModel.isBusy && canContinue
                    )
                    .frame(minWidth: buttonMinWidthLarge)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
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
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .installPlayCover:
            PlayCoverStepView(
                playCoverPaths: playCoverPaths ?? viewModel.detectedPlayCoverPaths,
                openPlayCoverWebsite: viewModel.openPlayCoverWebsite,
                uiScale: uiScale
            )
            
        case .selectStorage:
            StorageStepView(
                storageURL: viewModel.storageURL,
                chooseStorageDirectory: viewModel.chooseStorageDirectory,
                uiScale: uiScale
            )
            
        case .prepareDiskImage:
            DiskImageStepView(
                isBusy: viewModel.isBusy,
                statusMessage: viewModel.statusMessage,
                storageURL: viewModel.storageURL ?? settingsStore.diskImageDirectory,
                uiScale: uiScale
            )
            
        case .finished:
            FinishedStepView(message: viewModel.completionMessage, uiScale: uiScale)
        }
    }
    
    private var buttonTitle: String {
        switch viewModel.currentStep {
        case .installPlayCover:
            if playCoverPaths != nil || viewModel.detectedPlayCoverPaths != nil {
                return String(localized: "次へ")
            } else {
                return String(localized: "確認")
            }
        case .finished:
            return String(localized: "完了")
        case .prepareDiskImage:
            return viewModel.isBusy ? String(localized: "処理中(和点)") : "実行"
        default:
            return String(localized: "次へ")
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
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            ForEach(SetupWizardViewModel.Step.allCases) { step in
                let isActive = step == currentStep
                let isPast = step.rawValue < currentStep.rawValue
                
                HStack(spacing: 8 * uiScale) {
                    // Step circle
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color.secondary.opacity(0.3)))
                            .frame(width: 32 * uiScale, height: 32 * uiScale)
                        
                        if isPast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14 * uiScale, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text(step.stepNumber)
                                .font(.system(size: 14 * uiScale, weight: .semibold))
                                .foregroundStyle(isActive ? .white : .secondary)
                        }
                    }
                    
                    // Step title (only for active step)
                    if isActive {
                        Text(step.title)
                            .font(.system(size: 14 * uiScale, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                
                // Connector line
                if step != SetupWizardViewModel.Step.allCases.last {
                    Rectangle()
                        .fill(isPast ? Color.green : Color.secondary.opacity(0.3))
                        .frame(height: 2 * uiScale)
                        .frame(maxWidth: 40 * uiScale)
                }
            }
        }
    }
}

// MARK: - PlayCover Detection Step

private struct PlayCoverStepView: View {
    let playCoverPaths: PlayCoverPaths?
    let openPlayCoverWebsite: () -> Void
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32 * uiScale) {
            // Icon and title
            VStack(spacing: 16 * uiScale) {
                Image(systemName: playCoverPaths != nil ? "checkmark.circle.fill" : "app.dashed")
                    .font(.system(size: 80 * uiScale))
                    .foregroundStyle(playCoverPaths != nil ? .green : .secondary)
                
                Text("PlayCover の検出")
                    .font(.system(size: 28 * uiScale, weight: .bold))
            }
            .padding(.top, 40 * uiScale)
            
            // Status card
            if let paths = playCoverPaths {
                // PlayCover detected
                VStack(spacing: 16 * uiScale) {
                    HStack(spacing: 12 * uiScale) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40 * uiScale))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 6 * uiScale) {
                            Text("PlayCover が見つかりました")
                                .font(.system(size: 17 * uiScale, weight: .semibold))
                            Text(paths.applicationURL.path)
                                .font(.system(size: 12 * uiScale, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(20 * uiScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12 * uiScale))
                    
                    Text("PlayCover Manager は PlayCover を補完するアプリです。\n\nディスクイメージの管理と IPA インストールを簡単にします。")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 450 * uiScale)
                }
            } else {
                // PlayCover not detected
                VStack(spacing: 16 * uiScale) {
                    HStack(spacing: 12 * uiScale) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40 * uiScale))
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 6 * uiScale) {
                            Text("PlayCover が見つかりません")
                                .font(.system(size: 17 * uiScale, weight: .semibold))
                            Text("PlayCover.app を /Applications にインストールしてください")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20 * uiScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12 * uiScale))
                    
                    CustomButton(
                        title: "PlayCover サイトを開く",
                        action: openPlayCoverWebsite,
                        isPrimary: false,
                        icon: "arrow.up.forward.app",
                        uiScale: uiScale
                    )
                }
            }
        }
        .padding(.horizontal, 40 * uiScale)
        .padding(.bottom, 40 * uiScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Storage Selection Step

private struct StorageStepView: View {
    let storageURL: URL?
    let chooseStorageDirectory: () -> Void
    var uiScale: CGFloat = 1.0
    
    private var pathExists: Bool {
        guard let url = storageURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    var body: some View {
        VStack(spacing: 32 * uiScale) {
            // Icon and title
            VStack(spacing: 16 * uiScale) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 80 * uiScale))
                    .foregroundStyle(.blue)
                
                Text("保存先の選択")
                    .font(.system(size: 28 * uiScale, weight: .bold))
            }
            .padding(.top, 40 * uiScale)
            
            // Content
            VStack(spacing: 20 * uiScale) {
                if let url = storageURL {
                    // Storage selected - validate path existence
                    VStack(spacing: 12 * uiScale) {
                        if pathExists {
                            // Path exists - show green checkmark
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32 * uiScale))
                                    .foregroundStyle(.green)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text("保存先")
                                        .font(.system(size: 12 * uiScale))
                                        .foregroundStyle(.secondary)
                                    Text(url.path)
                                        .font(.system(size: 15 * uiScale, design: .monospaced))
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(20 * uiScale)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12 * uiScale))
                        } else {
                            // Path doesn't exist - show warning
                            VStack(spacing: 8 * uiScale) {
                                HStack(spacing: 12 * uiScale) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 32 * uiScale))
                                        .foregroundStyle(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                                        Text("パスが存在しません")
                                            .font(.system(size: 12 * uiScale))
                                            .foregroundStyle(.secondary)
                                        Text(url.path)
                                            .font(.system(size: 15 * uiScale, design: .monospaced))
                                            .lineLimit(2)
                                            .truncationMode(.middle)
                                    }
                                }
                                .padding(20 * uiScale)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12 * uiScale))
                                
                                Text("ドライブが接続されていないか、パスが無効です。\n別の保存先を選択してください。")
                                    .font(.system(size: 12 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                } else {
                    // No storage selected
                    Text("ディスクイメージの保存先を選択してください")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Select button
                CustomButton(
                    title: storageURL == nil ? "保存先を選択" : "保存先を変更",
                    action: chooseStorageDirectory,
                    isPrimary: false,
                    icon: "folder.badge.gearshape",
                    uiScale: uiScale
                )
                .frame(minWidth: 160 * uiScale)
                
                // Info
                VStack(spacing: 8 * uiScale) {
                    HStack(spacing: 6 * uiScale) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.blue)
                        Text("外部ストレージの使用を推奨")
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("ディスクイメージは大容量になる場合があります。\n十分な空き容量のあるドライブを選択してください。")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20 * uiScale)
            }
        }
        .padding(.horizontal, 40 * uiScale)
        .padding(.bottom, 40 * uiScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Disk Image Preparation Step

private struct DiskImageStepView: View {
    let isBusy: Bool
    let statusMessage: String
    let storageURL: URL?
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32 * uiScale) {
            // Icon and title
            VStack(spacing: 16 * uiScale) {
                if isBusy {
                    ProgressView()
                        .scaleEffect(1.5 * uiScale)
                } else {
                    Image(systemName: "gear.circle.fill")
                        .font(.system(size: 80 * uiScale))
                        .foregroundStyle(.purple)
                }
                
                Text(isBusy ? "準備中..." : "ディスクイメージの準備")
                    .font(.system(size: 28 * uiScale, weight: .bold))
            }
            .padding(.top, 40 * uiScale)
            
            // Content
            VStack(spacing: 20 * uiScale) {
                if isBusy {
                    // Processing
                    Text(statusMessage)
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    // Ready to execute
                    VStack(spacing: 16 * uiScale) {
                        Text("PlayCover 用のディスクイメージを作成します")
                            .font(.system(size: 17 * uiScale, weight: .semibold))
                        
                        VStack(spacing: 12 * uiScale) {
                            InfoRow(icon: "doc.fill", title: String(localized: "ファイル名"), value: "io.playcover.PlayCover.asif", uiScale: uiScale)
                            
                            if let url = storageURL {
                                InfoRow(icon: "folder.fill", title: String(localized: "保存先"), value: url.path, uiScale: uiScale)
                            }
                        }
                        .padding(20 * uiScale)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 12 * uiScale))
                        
                        Text("実行すると、ディスクイメージの作成とマウントを行います。")
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .padding(.horizontal, 40 * uiScale)
        .padding(.bottom, 40 * uiScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Finished Step

private struct FinishedStepView: View {
    let message: String
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32 * uiScale) {
            // Icon and title
            VStack(spacing: 16 * uiScale) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80 * uiScale))
                    .foregroundStyle(.green)
                
                Text("セットアップ完了")
                    .font(.system(size: 28 * uiScale, weight: .bold))
            }
            .padding(.top, 40 * uiScale)
            
            // Message
            VStack(spacing: 16 * uiScale) {
                Text(message)
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .multilineTextAlignment(.center)
                
                Text("「完了」ボタンをクリックして PlayCover Manager を起動します。")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 450 * uiScale)
        }
        .padding(.horizontal, 40 * uiScale)
        .padding(.bottom, 40 * uiScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Views

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var uiScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            Image(systemName: icon)
                .font(.system(size: 16 * uiScale))
                .foregroundStyle(.secondary)
                .frame(width: 24 * uiScale)
            
            VStack(alignment: .leading, spacing: 2 * uiScale) {
                Text(title)
                    .font(.system(size: 12 * uiScale))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15 * uiScale, design: .monospaced))
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
