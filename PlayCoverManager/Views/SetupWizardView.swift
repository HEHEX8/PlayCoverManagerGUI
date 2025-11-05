import SwiftUI
import Observation

struct SetupWizardView: View {
    @Bindable var viewModel: SetupWizardViewModel
    let playCoverPaths: PlayCoverPaths?
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        HStack(spacing: 24) {
            List {
                ForEach(SetupWizardViewModel.Step.allCases) { step in
                    Label(step.title, systemImage: icon(for: step))
                        .foregroundStyle(step == viewModel.currentStep ? Color.accentColor : Color.secondary)
                        .listRowBackground(step == viewModel.currentStep ? Color.accentColor.opacity(0.1) : Color.clear)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 220)

            VStack(alignment: .leading, spacing: 16) {
                Text(viewModel.currentStep.title)
                    .font(.title2)
                Text(viewModel.currentStep.description)
                    .foregroundStyle(.secondary)

                content
                Spacer()
                HStack {
                    if viewModel.currentStep != .installPlayCover {
                        Button("戻る") { viewModel.back() }
                    }
                    Spacer()
                    Button(action: { viewModel.continueAction(playCoverPaths: playCoverPaths) }) {
                        Text(buttonTitle)
                    }
                    .disabled(viewModel.isBusy)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .alert(item: $viewModel.error) { error in
            if error.category == .permissionDenied {
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    primaryButton: .default(Text("システム設定を開く")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("OK"))
                )
            } else if error.requiresAction {
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    primaryButton: .default(Text("設定を開く")) {
                        viewModel.openSettings()
                    },
                    secondaryButton: .cancel(Text("OK"))
                )
            } else {
                Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .installPlayCover:
            VStack(alignment: .leading, spacing: 12) {
                Text("PlayCover.app が \(PlayCoverPaths.defaultApplicationURL.path) に存在する必要があります。")
                Button("PlayCover サイトを開く", action: viewModel.openPlayCoverWebsite)
                    .keyboardShortcut("o", modifiers: [.command])
            }
        case .selectStorage:
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if let storageURL = viewModel.storageURL {
                        LabeledContent("現在の保存先") {
                            Text(storageURL.path)
                                .font(.system(.body, design: .monospaced))
                        }
                    } else {
                        Text("保存先が未設定です。")
                            .foregroundStyle(.secondary)
                    }
                    Button("保存先を選択", action: viewModel.chooseStorageDirectory)
                        .keyboardShortcut("s", modifiers: [.command])
                    Text("外部ストレージを推奨しますが必須ではありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        case .prepareDiskImage:
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isBusy {
                    ProgressView(viewModel.statusMessage)
                }
                Text("io.playcover.PlayCover.asif を作成・マウントします。")
                    .font(.body)
                if let dir = viewModel.storageURL ?? settingsStore.diskImageDirectory {
                    Text("保存先: \(dir.path)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        case .finished:
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.completionMessage)
                    .font(.headline)
            }
        }
    }

    private var buttonTitle: String {
        switch viewModel.currentStep {
        case .finished:
            return "完了"
        case .prepareDiskImage:
            return viewModel.isBusy ? "処理中…" : "実行"
        default:
            return "次へ"
        }
    }

    private func icon(for step: SetupWizardViewModel.Step) -> String {
        switch step {
        case .installPlayCover:
            return "1.circle"
        case .selectStorage:
            return "2.circle"
        case .prepareDiskImage:
            return "3.circle"
        case .finished:
            return "checkmark.circle"
        }
    }
}

