import SwiftUI
import JianPinEngine

struct ContentView: View {

    @ObservedObject var processor: ContactProcessor
    @State private var hasCheckedDuplicates = false
    @State private var isCheckingDuplicates = false
    @State private var mergeDone = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 图标
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
                .padding(.bottom, 24)

            // 标题（只有一行）
            Text("一键添加联系人拼音")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
                .padding(.bottom, 4)

            Text("解决 iPhone 通讯录排序错乱")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            // 主操作区域
            Group {
                switch processor.state {
                case .idle, .denied:
                    idleView
                case .requestingPermission, .processing:
                    processingView
                case .paused:
                    pausedView
                case .completed(let result):
                    completedView(result)
                case .error(let message):
                    errorView(message)
                }
            }

            Spacer(minLength: 0)

            // 底部提示
            if case .completed = processor.state {
                VStack(spacing: 4) {
                    Text("已同步到 iCloud，请等待 1-5 分钟后查看手机")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("确保 Mac 与 iPhone 使用同一 Apple ID 且开启通讯录同步")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 20)
            } else if case .denied = processor.state {
                EmptyView()
            } else {
                VStack(spacing: 4) {
                    Text("仅本地读取通讯录，不上传任何数据")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("需 Mac 与 iPhone 同一 iCloud 账号，已开启通讯录同步")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Button(action: start) {
                Label("开始整理", systemImage: "play.fill")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if case .denied = processor.state {
                Text("请在 系统设置 → 隐私与安全性 → 通讯录 中授权")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 16) {
            // 环形进度
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: processor.progress.fractionCompleted)
                    .stroke(Color.accentColor, style: .init(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: processor.progress.fractionCompleted)

                Text("\(Int(processor.progress.fractionCompleted * 100))%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Text("已处理 \(processor.progress.processed)/\(processor.progress.total) 位")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .animation(.default, value: processor.progress.processed)

            Button(action: { processor.pause() }) {
                Text("暂停")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Paused

    private var pausedView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: processor.progress.fractionCompleted)
                    .stroke(Color.accentColor, style: .init(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "pause.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }

            Text("已暂停 · \(processor.progress.processed)/\(processor.progress.total)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button(action: resume) {
                Text("继续")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Completed

    private func completedView(_ result: ContactProcessor.ProcessResult) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("已整理 \(result.updated) 位联系人")
                .font(.system(size: 17, weight: .medium))

            if result.skipped > 0 {
                Text("\(result.skipped) 位已跳过（已有拼音）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            if !result.failed.isEmpty {
                Text("\(result.failed.count) 位处理失败")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 16) {
                Button(action: undo) {
                    Label("撤销操作", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: reset) {
                    Label("重新整理", systemImage: "arrow.clockwise")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if !mergeDone {
                duplicateSection
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { processor.reset() }) {
                Text("重试")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Actions

    private func start() {
        Task {
            await processor.start()
        }
    }

    private func resume() {
        Task {
            await processor.resume()
        }
    }

    private func undo() {
        Task {
            _ = await processor.undo()
        }
    }

    private func reset() {
        processor.reset()
        hasCheckedDuplicates = false
        isCheckingDuplicates = false
        mergeDone = false
    }

    // MARK: - Duplicates

    private var duplicateSection: some View {
        VStack(spacing: 10) {
            Divider()
                .padding(.horizontal, -16)

            if isCheckingDuplicates {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("正在查找重复联系人...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else if hasCheckedDuplicates && processor.duplicateGroups.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("没有发现重复联系人")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else if processor.duplicateGroups.isEmpty {
                Button(action: findDuplicates) {
                    Label("查找重复联系人", systemImage: "person.2")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                let total = processor.duplicateGroups.reduce(0) { $0 + $1.count }
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("发现 \(processor.duplicateGroups.count) 组重复联系人（共 \(total) 条）")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Button(action: mergeAll) {
                        Label("一键合并", systemImage: "arrow.triangle.merge")
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                }
            }
        }
    }

    private func findDuplicates() {
        isCheckingDuplicates = true
        hasCheckedDuplicates = true
        Task {
            await processor.findDuplicates()
            await MainActor.run {
                isCheckingDuplicates = false
            }
        }
    }

    private func mergeAll() {
        Task {
            _ = await processor.mergeAllDuplicates()
            await MainActor.run {
                mergeDone = true
            }
        }
    }
}